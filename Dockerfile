FROM anyscale/ray:2.44.0-slim-py312-cu125

# run as root
USER root
ENV DEBIAN_FRONTEND=noninteractive PIP_DEFAULT_TIMEOUT=120

# system deps (build tools + video libs)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git git-lfs ffmpeg build-essential python3-dev pkg-config \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 ninja-build cmake \
 && rm -rf /var/lib/apt/lists/* && git lfs install

# code
WORKDIR /app
RUN git clone --depth 1 https://github.com/Wan-Video/Wan2.2.git

# toolchain
RUN python -m pip install --upgrade pip setuptools wheel

# GPU wheels known-good for WAN 2.2; base has CUDA 12.x (cu125). cu121 wheels work fine on 12.x.
RUN pip install --no-cache-dir --extra-index-url https://download.pytorch.org/whl/cu121 \
    torch==2.4.0 torchvision==0.19.0 torchaudio==2.4.0 xformers==0.0.27.post2

# remove troublesome packages from requirements (flash_attn) before install
RUN sed -i '/flash[-_]*attn/d' /app/Wan2.2/requirements.txt

# install remaining deps + server
RUN pip install --no-cache-dir -r /app/Wan2.2/requirements.txt \
    && pip install --no-cache-dir "huggingface_hub[cli]" fastapi uvicorn accelerate

# preload 5B weights to avoid cold start

# api
COPY serve_app.py /app/serve_app.py
ENV HF_HUB_ENABLE_HF_TRANSFER=1

EXPOSE 8000
CMD ["python", "-m", "serve_app"]

