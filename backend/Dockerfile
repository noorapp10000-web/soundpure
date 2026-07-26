FROM python:3.11-slim

# Install system deps
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsndfile1 \
    libsndfile1-dev \
    git \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install CPU-only PyTorch first (smaller, faster to install)
RUN pip install --no-cache-dir \
    torch==2.2.2 torchaudio==2.2.2 \
    --index-url https://download.pytorch.org/whl/cpu

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Pre-download Demucs model so first request is fast
RUN python3 -c "from demucs.pretrained import get_model; get_model('htdemucs_ft'); print('Demucs model cached')" \
    || echo "Demucs model will be downloaded on first request"

EXPOSE 8000

COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

CMD ["/bin/sh", "/app/start.sh"]
