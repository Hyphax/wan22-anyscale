FROM anyscale/ray:2.44.0-slim-py312-cu125

# run as root so apt/pip can work
USER root
ENV DEBIAN_FRONTEND=noninteractive PIP_DEFAULT_TIMEOUT=120

# system deps (build tools + libs used by cv/video pkgs)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git git-lfs ffmpeg build-essential python3-dev pkg-config \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
 && rm -rf /var/lib/apt/lists/* \
 && git lfs install

# app code
WORKDIR /app
RUN git clone https://github.com/Wan-Video/Wan2.2.git

# upgrade pip toolchain
RUN python -m pip install --upgrade pip setuptools wheel

# pre-install CUDA wheels (stable set for WAN 2.2 on L4/A10G)
# Note: uses cu121 wheels which are widely available
RUN pip install --no-cache-dir --extra-index-url https://download.pytorch.org/whl/cu121 \
    torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 xformers==0.0.27.post2

# rest of WAN requirements + API server deps
RUN pip install --no-cache-dir -r /app/Wan2.2/requirements.txt \
    && pip install --no-cache-dir "huggingface_hub[cli]" fastapi uvicorn accelerate

# preload model weights to avoid cold starts
RUN huggingface-cli download Wan-AI/Wan2.2-TI2V-5B --local-dir /models/Wan2.2-TI2V-5B

# serve app
COPY serve_app.py /app/serve_app.py
ENV HF_HUB_ENABLE_HF_TRANSFER=1

EXPOSE 8000
CMD ["python", "-m", "serve_app"]
