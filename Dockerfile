FROM anyscale/ray:2.44.0-slim-py312-cu125

# system deps
RUN apt-get update && apt-get install -y git ffmpeg && rm -rf /var/lib/apt/lists/*

# app code
WORKDIR /app
RUN git clone https://github.com/Wan-Video/Wan2.2.git

# python deps
RUN pip install --no-cache-dir -r /app/Wan2.2/requirements.txt \
    && pip install --no-cache-dir "huggingface_hub[cli]" fastapi uvicorn

# cache a smaller WAN 2.2 variant (fits L4 VRAM)
RUN huggingface-cli download Wan-AI/Wan2.2-TI2V-5B --local-dir /models/Wan2.2-TI2V-5B

# serve app
COPY serve_app.py /app/serve_app.py
ENV HF_HUB_ENABLE_HF_TRANSFER=1
EXPOSE 8000
CMD ["python", "-m", "serve_app"]
