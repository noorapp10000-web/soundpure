"""
SoundPure – Audio Enhancement API
Runs on Railway. Exposes:
  POST /upload          → { job_id }
  GET  /status/{id}     → JobStatus JSON
  GET  /download/{id}   → enhanced audio file
  GET  /health          → { status, version }
"""

from __future__ import annotations

import asyncio
import logging
import os
import uuid
from pathlib import Path
from typing import Dict

import aiofiles
from fastapi import BackgroundTasks, FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse

from processor import AudioPipeline, JobStatus

# ── Logging ────────────────────────────────────────────────────────────── #
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("main")

# ── App ────────────────────────────────────────────────────────────────── #
app = FastAPI(
    title="SoundPure Audio Enhancement API",
    version="1.0.0",
    description="Multi-model AI audio enhancement: Demucs + Spectral Gating + Wiener + EQ",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── State ──────────────────────────────────────────────────────────────── #
UPLOAD_DIR = Path("/tmp/soundpure_jobs")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

jobs: Dict[str, JobStatus] = {}
pipeline = AudioPipeline()

SUPPORTED_EXTS = {
    ".mp3", ".wav", ".m4a", ".aac",
    ".ogg", ".flac", ".wma", ".opus",
    ".mp4", ".webm", ".3gp",
}

MAX_UPLOAD_BYTES = 500 * 1024 * 1024  # 500 MB

# ── Routes ─────────────────────────────────────────────────────────────── #


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "version": "1.0.0",
        "models": ["demucs-htdemucs_ft", "noisereduce", "wiener", "spectral-subtraction"],
    }


@app.post("/upload")
async def upload_audio(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
):
    if not file.filename:
        raise HTTPException(400, "No filename provided")

    raw_ext = Path(file.filename).suffix.lower()
    if not raw_ext:
        raw_ext = ".mp3"

    # Map video containers to audio
    if raw_ext in {".mp4", ".webm", ".3gp"}:
        original_format = ".m4a"
    elif raw_ext in SUPPORTED_EXTS:
        original_format = raw_ext
    else:
        raise HTTPException(
            415,
            f"Unsupported format '{raw_ext}'. Supported: {', '.join(sorted(SUPPORTED_EXTS))}",
        )

    # Read and size-check
    content = await file.read()
    if len(content) > MAX_UPLOAD_BYTES:
        raise HTTPException(413, "File too large. Max 500 MB.")
    if len(content) == 0:
        raise HTTPException(400, "Empty file.")

    job_id = str(uuid.uuid4())
    job_dir = UPLOAD_DIR / job_id
    job_dir.mkdir(parents=True, exist_ok=True)

    input_path = job_dir / f"input{raw_ext}"
    async with aiofiles.open(input_path, "wb") as f:
        await f.write(content)

    jobs[job_id] = JobStatus(
        job_id=job_id,
        status="pending",
        progress=0,
        stage="في قائمة الانتظار...",
        original_format=original_format,
        input_path=str(input_path),
    )

    background_tasks.add_task(
        pipeline.process,
        job_id,
        jobs,
        str(input_path),
        str(job_dir),
        original_format,
    )

    logger.info("Job %s created for file %s (%d bytes)", job_id, file.filename, len(content))
    return {"job_id": job_id}


@app.get("/status/{job_id}")
async def get_status(job_id: str):
    if job_id not in jobs:
        raise HTTPException(404, "Job not found")
    j = jobs[job_id]
    return {
        "job_id": j.job_id,
        "status": j.status,
        "progress": j.progress,
        "stage": j.stage,
        "original_format": j.original_format,
        "output_path": j.output_path,
        "error": j.error,
    }


@app.get("/download/{job_id}")
async def download_result(job_id: str):
    if job_id not in jobs:
        raise HTTPException(404, "Job not found")

    j = jobs[job_id]

    if j.status == "failed":
        raise HTTPException(500, f"Processing failed: {j.error}")

    if j.status != "completed":
        raise HTTPException(409, f"Job not ready yet. Status: {j.status}")

    if not j.output_path or not os.path.exists(j.output_path):
        raise HTTPException(500, "Output file missing – please re-upload")

    ext = Path(j.output_path).suffix
    media_type_map = {
        ".mp3":  "audio/mpeg",
        ".wav":  "audio/wav",
        ".m4a":  "audio/mp4",
        ".aac":  "audio/aac",
        ".ogg":  "audio/ogg",
        ".flac": "audio/flac",
        ".opus": "audio/opus",
        ".wma":  "audio/x-ms-wma",
    }
    media_type = media_type_map.get(ext, "application/octet-stream")

    return FileResponse(
        j.output_path,
        media_type=media_type,
        filename=f"soundpure_enhanced{ext}",
        headers={"Content-Disposition": f'attachment; filename="soundpure_enhanced{ext}"'},
    )
