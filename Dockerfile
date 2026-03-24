# syntax=docker/dockerfile:1
FROM runpod/pytorch:2.2.0-py3.10-cuda12.1.1-devel-ubuntu22.04

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TOKENIZERS_PARALLELISM=false

WORKDIR /workspace

# System deps for Pillow, CairoSVG (cairo + pango + fonts)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    libcairo2 \
    libcairo2-dev \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libfontconfig1 \
    fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

# Copy source
COPY . /workspace

# Core Python deps
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# ─── Bake models into image (no network volume needed) ────────────────────────

# OmniSVG 1.1 4B weights (7.7GB)
RUN mkdir -p /workspace/models/OmniSVG1.1_4B && \
    wget -q --show-progress -O /workspace/models/OmniSVG1.1_4B/pytorch_model.bin \
        "https://huggingface.co/OmniSVG/OmniSVG1.1_4B/resolve/main/pytorch_model.bin"

# config.yaml from original OmniSVG repo (token schema)
RUN wget -q -O /workspace/config.yaml \
        "https://huggingface.co/OmniSVG/OmniSVG/resolve/main/config.yaml"

# Qwen2.5-VL-3B-Instruct (7.5GB)
# HF_TOKEN set as env var on RunPod endpoint (optional, avoids rate limits)
RUN pip install --no-cache-dir huggingface_hub && \
    python -c "import os; from huggingface_hub import snapshot_download; \
    snapshot_download('Qwen/Qwen2.5-VL-3B-Instruct', \
        local_dir='/workspace/models/Qwen2.5-VL-3B-Instruct', \
        token=os.environ.get('HF_TOKEN'))"

# Point env vars to baked-in models
ENV WEIGHT_PATH=/workspace/models/OmniSVG1.1_4B \
    WEIGHT_PATH_4B=/workspace/models/OmniSVG1.1_4B \
    CONFIG_PATH=/workspace/config.yaml \
    QWEN_LOCAL_DIR=/workspace/models/Qwen2.5-VL-3B-Instruct \
    QWEN_MODEL_4B=/workspace/models/Qwen2.5-VL-3B-Instruct \
    SVG_TOKENIZER_CONFIG=/workspace/config.yaml \
    ENABLE_DUMMY=false

# Serverless entrypoint
CMD ["python", "-u", "handler.py"]
