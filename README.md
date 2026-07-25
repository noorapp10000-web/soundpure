# SoundPure 🎵
**AI-powered audio enhancement — removes ALL noise, keeps only the human voice**

---

## Architecture

```
Flutter App (Android / iOS)
        ↓  upload audio
Python FastAPI Backend (Railway)
        ↓  5-stage AI pipeline
  1. Demucs htdemucs_ft  — vocal separation
  2. noisereduce × 2     — spectral gating (stationary + non-stationary)
  3. Wiener filter        — residual noise removal
  4. Spectral subtraction — wind / air / hiss removal
  5. Butterworth EQ       — human voice frequency enhancement
        ↓  download enhanced file
Flutter App (plays & saves result)
```

---

## Deploy Backend to Railway

### 1. Create a Railway account
Go to [railway.app](https://railway.app) and sign up.

### 2. Create a new project from this repo
```
New Project → Deploy from GitHub repo → select your repo
Railway auto-detects the Dockerfile in /backend
```

### 3. Set the root directory
In Railway project settings → **Root Directory** → set to `backend`

### 4. Get your Railway URL
`Settings → Domains → Generate Domain`  
You'll get something like: `https://soundpure-production.up.railway.app`

### 5. Update the Flutter app
Open `flutter_app/lib/core/constants.dart` and replace:
```dart
const String kApiBaseUrl = 'https://YOUR-APP.up.railway.app';
```
with your actual Railway URL.

---

## Run Flutter App

### Prerequisites
- Flutter SDK ≥ 3.3.0
- Android Studio / Xcode

### Steps
```bash
cd flutter_app
flutter pub get
flutter run
```

### Build release APK
```bash
flutter build apk --release
```

### Build iOS IPA
```bash
flutter build ios --release
```

---

## Backend API Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check + model list |
| POST | `/upload` | Upload audio file → `{ job_id }` |
| GET | `/status/{job_id}` | Poll processing status |
| GET | `/download/{job_id}` | Download enhanced audio |

### Status object
```json
{
  "job_id": "uuid",
  "status": "pending | processing | completed | failed",
  "progress": 75,
  "stage": "🔇 تطبيق فلتر Wiener...",
  "original_format": ".mp3",
  "error": null
}
```

---

## Supported Audio Formats

Input: **MP3, WAV, M4A, AAC, OGG, FLAC, WMA, OPUS, MP4**  
Output: **Same as input**, re-encoded at maximum quality

---

## Processing Pipeline (detailed)

| Stage | Model | What it removes |
|-------|-------|----------------|
| 1 | **Demucs htdemucs_ft** | Music, drums, instruments, background |
| 2 | **noisereduce (non-stationary)** | Variable background noise |
| 3 | **noisereduce (stationary)** | Constant hum, AC buzz, electrical noise |
| 4 | **Wiener filter** | Residual mathematical noise |
| 5 | **Spectral subtraction** | Wind, air, distant ambient sounds |
| 6 | **Butterworth EQ** | Non-voice frequencies outside 80Hz–8kHz |
| 7 | **Normalization** | Level adjustment to −3 dB peak |

---

## Notes

- **Processing time**: 2–10 minutes depending on file length and Railway tier
- **Max file size**: 500 MB
- **First request**: slightly slower (Demucs downloads ~280 MB model on cold start)
- **Demucs model**: `htdemucs_ft` — Meta's fine-tuned hybrid transformer, best-in-class for vocals
