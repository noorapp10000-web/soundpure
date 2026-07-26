# SoundPure 🎵

AI-powered audio enhancement app — removes ALL noise and keeps only the human voice.

## Run & Operate

- **Backend** lives on Railway (not Replit). Push to `main` on GitHub to auto-redeploy.
- **Flutter APK** is built automatically via GitHub Actions on every push to `main`.
- APK releases are published at: https://github.com/noorapp10000-web/soundpure/releases

## Stack

- **Flutter** (Dart ≥ 3.3) — Android/iOS mobile app
- **Python FastAPI** — audio processing backend, deployed on Railway
- **AI pipeline**: Demucs htdemucs_ft → noisereduce → Wiener filter → Spectral subtraction → Butterworth EQ

## Where things live

- `flutter_app/` — Flutter mobile app source
  - `lib/core/constants.dart` — backend URL and config constants
  - `lib/services/api_service.dart` — HTTP client (Dio) for backend
- `backend/` — Python FastAPI backend
  - `main.py` — API routes
  - `processor/pipeline.py` — 7-stage AI audio pipeline
  - `railway.toml` — Railway deployment config
  - `start.sh` — startup script (fixes $PORT expansion on Railway)
  - `Dockerfile` — container definition
- `.github/workflows/` — GitHub Actions (APK build + GitHub Release)

## Backend API

Live at: `https://soundpure-backend-production.up.railway.app`

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| POST | `/upload` | Upload audio → `{ job_id }` |
| GET | `/status/{job_id}` | Poll processing status |
| GET | `/download/{job_id}` | Download enhanced audio |

## Architecture decisions

- Railway `startCommand` uses `sh /app/start.sh` instead of inline `$PORT` to avoid
  Railway running commands without shell variable expansion (was causing FAILED deployments).
- Demucs `htdemucs_ft` model is pre-downloaded in the Docker build step to avoid
  cold-start delays (~280 MB model).
- GitHub Actions uses `secrets.GITHUB_TOKEN` (built-in) for creating releases — no extra PAT needed for CI.

## User preferences

- Language: Arabic UI throughout the Flutter app
- Push to GitHub → Railway auto-redeploys backend, GitHub Actions builds APK

## Gotchas

- Railway healthcheck timeout is 300s (Demucs model download on cold start can be slow).
- Any change to the backend must be pushed to GitHub — Railway deploys from the repo.
- APK is unsigned (debug key) — for Play Store, a keystore needs to be set up.
