########################  Stage 0: base  ########################
FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04 AS base
ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    PYTHONUNBUFFERED=1 \
    CMAKE_BUILD_PARALLEL_LEVEL=8
# --- system deps ---
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-pip python3-distutils python3-dev \
      build-essential git wget curl libgl1 libglib2.0-0 libsm6 libxrender1 \
      google-perftools && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    rm -rf /var/lib/apt/lists/*
# --- ComfyUI CLI ---
RUN python3 -m pip install --no-cache-dir comfy-cli==1.3.8 runpod requests && \
    yes | comfy --workspace /comfyui install --cuda-version 12.4 --nvidia
# --- helper files ---
ADD src/extra_model_paths.yaml /
COPY src/extra_model_paths.yaml /comfyui/extra_model_paths.yaml
WORKDIR /
ADD src/start.sh src/restore_snapshot.sh src/rp_handler.py /
RUN chmod +x /start.sh /restore_snapshot.sh


###############################################################################
# Custom nodes 
###############################################################################
COPY requirements.txt /requirements.txt
RUN pip install --no-cache-dir -r /requirements.txt

# Clone all custom nodes WITHOUT installing their requirements
RUN mkdir -p /comfyui/custom_nodes && cd /comfyui/custom_nodes && \
    git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Impact-Pack.git && \
    git clone --depth 1 https://github.com/rgthree/rgthree-comfy.git && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-KJNodes.git && \
    git clone --depth 1 https://github.com/kijai/ComfyUI-Florence2.git && \
    git clone --depth 1 https://github.com/cubiq/ComfyUI_essentials.git && \
    git clone --depth 1 https://github.com/welltop-cn/ComfyUI-TeaCache.git && \
    git clone --depth 1 https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git && \
    git clone --depth 1 https://github.com/aria1th/ComfyUI-LogicUtils.git

# Force reinstall of potentially conflicting packages
RUN pip install --no-cache-dir --force-reinstall opencv-python-headless

# ---------- Default model ----------
# build-time default
ENV MODEL_TYPE=dev-fp8
########################  Stage 1: final  ########################
FROM base AS final
VOLUME /runpod-volume
CMD ["/start.sh"]
