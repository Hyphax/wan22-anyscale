FROM anyscale/ray:2.44.0-slim-py312-cu125

# run as root
USER root
ENV DEBIAN_FRONTEND=noninteractive PIP_DEFAULT_TIMEOUT=120

# Make sure /app is importable regardless of working dir
ENV PYTHONPATH=/app:${PYTHONPATH}

# ---- System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    git git-lfs ffmpeg build-essential python3-dev pkg-config \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 ninja-build cmake \
 && rm -rf /var/lib/apt/lists/* && git lfs install

WORKDIR /app

# ---- Get WAN 2.2 code (shallow)
RUN git clone --depth 1 https://github.com/Wan-Video/Wan2.2.git

# ---- Toolchain
RUN python -m pip install --upgrade pip setuptools wheel

# ---- Preinstall stable GPU wheels (PyTorch + xformers)
# cu121 wheels work fine with CUDA 12 drivers in the base image
RUN pip install --no-cache-dir --extra-index-url https://download.pytorch.org/whl/cu121 \
    torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 xformers==0.0.27.post2

# ---- Remove problematic deps and disable optional flash attention
RUN sed -i '/flash[-_]*attn/d' /app/Wan2.2/requirements.txt
ENV WAN_DISABLE_FLASH_ATTN=1
ENV DISABLE_FLASH_ATTN=1
ENV USE_FLASH_ATTENTION=0

# ---- Install remaining deps + API server deps (pin fastapi/uvicorn for stability)
RUN pip install --no-cache-dir -r /app/Wan2.2/requirements.txt \
    && pip install --no-cache-dir "huggingface_hub[cli]" fastapi==0.111.0 uvicorn==0.30.1 accelerate

# ---- Our Serve app (Ray Serve imports this via import_path: serve_app:app)
COPY serve_app.py /app/serve_app.py

# Helpful envs
ENV HF_HUB_ENABLE_HF_TRANSFER=1
ENV PYTHONUNBUFFERED=1

EXPOSE 8000
# Ray Serve on Anyscale uses import_path; CMD is effectively ignored but harmless
CMD ["python", "-m", "serve_app"]
