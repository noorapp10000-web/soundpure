#!/bin/sh
# Railway startup script — expands $PORT properly before passing to uvicorn
set -e
exec uvicorn main:app --host 0.0.0.0 --port "${PORT:-8000}" --workers 1
