"""
Audio Enhancement Pipeline
Stages:
  1. FFmpeg: Any format → WAV 44100Hz stereo
  2. Demucs htdemucs_ft: AI vocal separation
  3. noisereduce: Multi-pass spectral gating
  4. Wiener filter: Residual noise removal
  5. Spectral subtraction: Wind / air / hiss removal
  6. Butterworth EQ: Boost human voice band (80 Hz – 8 kHz)
  7. Normalize: Peak −3 dB
  8. FFmpeg: WAV → original format at max quality
"""

from __future__ import annotations

import asyncio
import logging
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Optional

import numpy as np
import noisereduce as nr
import soundfile as sf
from scipy.signal import butter, filtfilt, wiener, stft, istft

logger = logging.getLogger("pipeline")


@dataclass
class JobStatus:
    job_id: str
    status: str          # pending | processing | completed | failed
    progress: int        # 0‑100
    stage: str
    original_format: str
    input_path: str
    output_path: Optional[str] = None
    error: Optional[str] = None


class AudioPipeline:
    """Stateless pipeline – one instance shared across requests."""

    # ------------------------------------------------------------------ #
    #  Public entry point                                                  #
    # ------------------------------------------------------------------ #

    async def process(
        self,
        job_id: str,
        jobs: Dict[str, JobStatus],
        input_path: str,
        job_dir: str,
        original_format: str,
    ) -> None:
        try:
            self._update(jobs, job_id, "processing", 2, "🔄 بدء المعالجة...")

            # 1 ── Format conversion
            self._update(jobs, job_id, "processing", 5, "🔄 تحويل الصيغة إلى WAV عالي الجودة...")
            wav_path = await self._to_wav(input_path, job_dir)

            # 2 ── Demucs vocal separation (best-effort — may be skipped on low-RAM hosts)
            self._update(jobs, job_id, "processing", 10, "🤖 تحميل نموذج Demucs (htdemucs_ft)...")
            try:
                vocals_path = await self._demucs_separate(wav_path, job_dir, job_id, jobs)
            except Exception as demucs_err:
                # Demucs killed by OOM or failed — fall back to spectral-only pipeline
                logger.warning(
                    "Demucs skipped for job=%s (%s). "
                    "Continuing with spectral-only pipeline.",
                    job_id, demucs_err,
                )
                self._update(
                    jobs, job_id, "processing", 48,
                    "⚠️ Demucs غير متاح على هذا الخادم — سيتم استخدام المرشحات الطيفية فقط",
                )
                vocals_path = wav_path  # process raw converted WAV instead

            # 3 ── Load audio as mono float32
            self._update(jobs, job_id, "processing", 50, "📊 تحليل الصوت...")
            audio, sr = sf.read(vocals_path, dtype="float32")
            if audio.ndim > 1:
                audio = audio.mean(axis=1)

            # 4 ── Multi-pass spectral gating (noisereduce)
            self._update(jobs, job_id, "processing", 54, "🔇 إزالة الضوضاء – المرور الأول (Spectral Gating)...")
            audio = self._spectral_gate(audio, sr)

            # 5 ── Wiener filter
            self._update(jobs, job_id, "processing", 65, "🔇 إزالة الضوضاء – فلتر Wiener...")
            audio = self._wiener(audio)

            # 6 ── Spectral subtraction (air / wind / hiss)
            self._update(jobs, job_id, "processing", 73, "💨 إزالة صوت الهواء والسياق البعيد...")
            audio = self._spectral_subtract(audio, sr)

            # 7 ── Butterworth EQ
            self._update(jobs, job_id, "processing", 82, "🎚️ تحسين ترددات الصوت البشري...")
            audio = self._eq_voice(audio, sr)

            # 8 ── Normalize + save enhanced WAV
            self._update(jobs, job_id, "processing", 90, "📏 تطبيع مستوى الصوت...")
            audio = self._normalize(audio)
            # Guard: replace any NaN/inf that filters may produce on silent audio
            if not np.all(np.isfinite(audio)):
                logger.warning("Non-finite samples in job=%s — replacing with zeros", job_id)
                audio = np.nan_to_num(audio, nan=0.0, posinf=0.0, neginf=0.0).astype(np.float32)
            enhanced_wav = os.path.join(job_dir, "enhanced.wav")
            sf.write(enhanced_wav, audio, sr, subtype="PCM_24")

            # 9 ── Convert back to original format
            self._update(jobs, job_id, "processing", 95, "🎵 تحويل الملف للصيغة الأصلية...")
            output_path = await self._from_wav(enhanced_wav, job_dir, original_format)

            self._update(
                jobs, job_id, "completed", 100,
                "✅ اكتملت المعالجة بنجاح!",
                output_path=output_path,
            )

        except Exception as exc:
            logger.error("Pipeline error job=%s: %s", job_id, exc, exc_info=True)
            self._update(jobs, job_id, "failed", 0, f"❌ خطأ: {exc}", error=str(exc))

    # ------------------------------------------------------------------ #
    #  Helper: update job in-place                                         #
    # ------------------------------------------------------------------ #

    @staticmethod
    def _update(
        jobs: Dict[str, JobStatus],
        job_id: str,
        status: str,
        progress: int,
        stage: str,
        output_path: Optional[str] = None,
        error: Optional[str] = None,
    ) -> None:
        if job_id not in jobs:
            return
        j = jobs[job_id]
        j.status = status
        j.progress = progress
        j.stage = stage
        if output_path:
            j.output_path = output_path
        if error:
            j.error = error

    # ------------------------------------------------------------------ #
    #  Stage 1 – FFmpeg: any format → WAV                                 #
    # ------------------------------------------------------------------ #

    async def _to_wav(self, src: str, job_dir: str) -> str:
        dst = os.path.join(job_dir, "converted.wav")
        # If source is already a WAV, skip conversion to avoid FFmpeg
        # "same as input" error when src and dst resolve to the same file.
        if src.lower().endswith(".wav") and os.path.abspath(src) == os.path.abspath(dst):
            return src
        cmd = [
            "ffmpeg", "-y",
            "-i", src,
            "-ar", "44100",
            "-ac", "2",
            "-acodec", "pcm_s24le",
            dst,
        ]
        await self._run(cmd, "FFmpeg conversion to WAV")
        return dst

    # ------------------------------------------------------------------ #
    #  Stage 2 – Demucs htdemucs_ft vocal separation                      #
    # ------------------------------------------------------------------ #

    async def _demucs_separate(
        self,
        wav_path: str,
        job_dir: str,
        job_id: str,
        jobs: Dict[str, JobStatus],
    ) -> str:
        self._update(jobs, job_id, "processing", 18,
                     "🤖 Demucs يفصل الصوت البشري عن كل الخلفية...")

        cmd = [
            "python3", "-m", "demucs",
            "--name", "htdemucs_ft",
            "--two-stems", "vocals",
            "--clip-mode", "rescale",
            "--device", "cpu",   # explicit CPU — no CUDA available on Railway
            "--segment", "10",   # 10-second chunks → ~70 % less peak RAM
            "-o", job_dir,
            wav_path,
        ]
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        self._update(jobs, job_id, "processing", 28,
                     "🤖 Demucs يعالج... (النموذج الأقوى – يأخذ وقتاً)")

        try:
            # 15-minute hard timeout keeps Railway from OOM-killing the container
            stdout, stderr = await asyncio.wait_for(
                proc.communicate(), timeout=900
            )
        except asyncio.TimeoutError:
            proc.kill()
            await proc.communicate()
            raise RuntimeError("Demucs timed out after 15 minutes")

        if proc.returncode != 0:
            combined = (stderr.decode(errors="replace") +
                        stdout.decode(errors="replace"))[-600:]
            raise RuntimeError(f"Demucs failed (exit {proc.returncode}): {combined}")

        self._update(jobs, job_id, "processing", 48,
                     "✅ اكتمل فصل الصوت البشري!")

        # Locate vocals.wav inside the output tree
        for root, _, files in os.walk(job_dir):
            for fname in files:
                if "vocals" in fname and fname.endswith(".wav"):
                    return os.path.join(root, fname)

        raise RuntimeError("vocals.wav not found after Demucs run")

    # ------------------------------------------------------------------ #
    #  Stage 3 – Multi-pass spectral gating (noisereduce)                 #
    # ------------------------------------------------------------------ #

    @staticmethod
    def _spectral_gate(audio: np.ndarray, sr: int) -> np.ndarray:
        # Pass 1 – non-stationary (voice activity-aware)
        out = nr.reduce_noise(
            y=audio, sr=sr,
            stationary=False,
            prop_decrease=0.90,
            n_std_thresh_stationary=1.5,
            time_mask_smooth_ms=60,
            freq_mask_smooth_hz=150,
            n_jobs=-1,
        )
        # Pass 2 – stationary residual (constant background hum / hiss)
        out = nr.reduce_noise(
            y=out, sr=sr,
            stationary=True,
            prop_decrease=0.80,
            n_jobs=-1,
        )
        return out.astype(np.float32)

    # ------------------------------------------------------------------ #
    #  Stage 4 – Wiener filter                                            #
    # ------------------------------------------------------------------ #

    @staticmethod
    def _wiener(audio: np.ndarray) -> np.ndarray:
        out = wiener(audio, mysize=29)
        return out.astype(np.float32)

    # ------------------------------------------------------------------ #
    #  Stage 5 – Spectral subtraction (wind / air / distant noise)        #
    # ------------------------------------------------------------------ #

    @staticmethod
    def _spectral_subtract(audio: np.ndarray, sr: int, alpha: float = 2.5) -> np.ndarray:
        n_fft = 2048
        hop   = 512

        _, _, Zxx = stft(audio, sr, nperseg=n_fft, noverlap=n_fft - hop)
        mag   = np.abs(Zxx)
        phase = np.angle(Zxx)

        # Estimate noise profile from quietest 8 % of frames
        frame_power = np.mean(mag ** 2, axis=0)
        thresh = np.percentile(frame_power, 8)
        noise_frames = mag[:, frame_power <= thresh * 3.0]

        if noise_frames.shape[1] > 0:
            noise_profile = np.mean(noise_frames, axis=1, keepdims=True)
            # Over-subtraction with spectral floor (avoids musical noise)
            mag_clean = np.maximum(mag - alpha * noise_profile, 0.08 * mag)
        else:
            mag_clean = mag

        _, out = istft(mag_clean * np.exp(1j * phase), sr,
                       nperseg=n_fft, noverlap=n_fft - hop)

        # Trim / pad to match original length
        if len(out) > len(audio):
            out = out[: len(audio)]
        elif len(out) < len(audio):
            out = np.pad(out, (0, len(audio) - len(out)))

        return out.astype(np.float32)

    # ------------------------------------------------------------------ #
    #  Stage 6 – Butterworth bandpass EQ for human voice                  #
    # ------------------------------------------------------------------ #

    @staticmethod
    def _eq_voice(audio: np.ndarray, sr: int) -> np.ndarray:
        nyq = sr / 2.0

        def bfilter(data: np.ndarray, lo: float, hi: float, order: int = 6) -> np.ndarray:
            b, a = butter(order, [lo / nyq, hi / nyq], btype="band")
            return filtfilt(b, a, data).astype(np.float32)

        def hpfilter(data: np.ndarray, cutoff: float, order: int = 5) -> np.ndarray:
            b, a = butter(order, cutoff / nyq, btype="high")
            return filtfilt(b, a, data).astype(np.float32)

        def lpfilter(data: np.ndarray, cutoff: float, order: int = 5) -> np.ndarray:
            b, a = butter(order, cutoff / nyq, btype="low")
            return filtfilt(b, a, data).astype(np.float32)

        # Remove sub-bass rumble and DC offset
        audio = hpfilter(audio, 80)

        # Hard cut above 8 kHz (reduce breath / sibilance artefacts)
        audio = lpfilter(audio, 8000)

        # Slight presence boost 2 kHz–5 kHz (voice clarity / intelligibility)
        presence = bfilter(audio, 2000, 5000)
        audio = audio + 0.15 * presence

        return audio

    # ------------------------------------------------------------------ #
    #  Stage 7 – Peak normalize to −3 dB                                  #
    # ------------------------------------------------------------------ #

    @staticmethod
    def _normalize(audio: np.ndarray) -> np.ndarray:
        peak = np.max(np.abs(audio))
        if peak > 1e-9:
            audio = audio * (0.707 / peak)   # 0.707 ≈ −3 dB
        return audio.astype(np.float32)

    # ------------------------------------------------------------------ #
    #  Stage 8 – FFmpeg: enhanced WAV → original format                   #
    # ------------------------------------------------------------------ #

    async def _from_wav(self, wav_path: str, job_dir: str, fmt: str) -> str:
        if fmt.lower() == ".wav":
            return wav_path

        out = os.path.join(job_dir, f"output{fmt}")

        codec_map = {
            ".mp3":  ["-codec:a", "libmp3lame", "-qscale:a", "0", "-b:a", "320k"],
            ".m4a":  ["-codec:a", "aac",         "-b:a", "256k"],
            ".aac":  ["-codec:a", "aac",         "-b:a", "256k"],
            ".ogg":  ["-codec:a", "libvorbis",   "-qscale:a", "10"],
            ".flac": ["-codec:a", "flac"],
            ".wma":  ["-codec:a", "wmav2",       "-b:a", "320k"],
            ".opus": ["-codec:a", "libopus",     "-b:a", "192k"],
        }
        extra = codec_map.get(fmt.lower(),
                              ["-codec:a", "libmp3lame", "-b:a", "320k"])

        cmd = ["ffmpeg", "-y", "-i", wav_path] + extra + [out]
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        await proc.communicate()

        if proc.returncode == 0 and os.path.exists(out):
            return out

        # Fallback: return the WAV
        logger.warning("Format conversion to %s failed, returning WAV", fmt)
        return wav_path

    # ------------------------------------------------------------------ #
    #  Utility: run subprocess and raise on failure                       #
    # ------------------------------------------------------------------ #

    @staticmethod
    async def _run(cmd: list, label: str) -> None:
        proc = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        _, stderr = await proc.communicate()
        if proc.returncode != 0:
            raise RuntimeError(f"{label} failed: {stderr.decode()[-400:]}")
