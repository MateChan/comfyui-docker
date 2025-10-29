FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PATH="/root/.local/bin:$PATH"

RUN apt-get update && apt-get install -y \
  python3.10 \
  python3-pip \
  git \
  wget \
  curl \
  libgl1 \
  libglib2.0-0 \
  libgomp1 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | sh

WORKDIR /app

RUN git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git /app

RUN uv pip install --system --no-cache-dir \
  torch==2.5.1 \
  torchvision==0.20.1 \
  torchaudio==2.5.1 \
  --index-url https://download.pytorch.org/whl/cu121

RUN uv pip install --system --no-cache-dir -r requirements.txt

RUN uv pip install --system --no-cache-dir \
  sentencepiece==0.2.0 \
  accelerate==1.2.1 \
  tokenizers==0.22.0

RUN mkdir -p /app/models/checkpoints \
  /app/models/vae \
  /app/models/loras \
  /app/models/controlnet \
  /app/models/clip \
  /app/models/unet \
  /app/input \
  /app/output \
  /app/user \
  /app/custom_nodes

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8188

ENTRYPOINT ["/entrypoint.sh"]
