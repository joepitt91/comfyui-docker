# SPDX-FileCopyrightText: 2025-2026 Joe Pitt
#
# SPDX-License-Identifier: GPL-3.0-only

# Phase 1 - Get ComfyUI and platform-specific torch versions

FROM python:3.13-slim AS base
RUN python3 -m venv /opt/ComfyUI.venv
RUN apt update && apt install git -yq
WORKDIR /opt

ARG COMFYUI_VERSION=0.0.0
RUN git clone --depth 1 --branch ${COMFYUI_VERSION} https://github.com/comfyanonymous/ComfyUI
WORKDIR /opt/ComfyUI
RUN rm -rf .git
ARG TORCH_VERSION=latest
RUN . /opt/ComfyUI.venv/bin/activate &&\
    pip install --no-cache-dir --quiet -r requirements.txt &&\
    pip install --no-cache-dir --quiet -r manager_requirements.txt

FROM python:3.13-slim AS amd_torch
RUN python3 -m venv /opt/ComfyUI.venv
ARG TORCH_VERSION=latest
RUN . /opt/ComfyUI.venv/bin/activate && \
    pip install --no-cache-dir --quiet torch torchaudio torchvision --index-url https://download.pytorch.org/whl/rocm7.2 &&\
    pip install --no-cache-dir --quiet matrix-nio PyOpenGL PyOpenGL_accelerate sageattention

FROM python:3.13-slim AS intel_torch
RUN python3 -m venv /opt/ComfyUI.venv
ARG TORCH_VERSION=latest
RUN . /opt/ComfyUI.venv/bin/activate && \
    pip install --no-cache-dir --quiet torch torchaudio torchvision --index-url https://download.pytorch.org/whl/xpu &&\
    pip install --no-cache-dir --quiet matrix-nio PyOpenGL PyOpenGL_accelerate sageattention

FROM python:3.13-slim AS nvidia_torch
RUN python3 -m venv /opt/ComfyUI.venv
ARG TORCH_VERSION=latest
RUN . /opt/ComfyUI.venv/bin/activate && \
    pip install --no-cache-dir --quiet torch torchaudio torchvision &&\
    pip install --no-cache-dir --quiet matrix-nio PyOpenGL PyOpenGL_accelerate sageattention

# Phrase 2 - Combine dependencies

FROM python:3.13-slim AS amd_flatten
COPY --chown=nobody:nogroup --from=base /opt /opt
COPY --chown=nobody:nogroup --from=amd_torch /opt /opt

FROM python:3.13-slim AS intel_flatten
COPY --chown=nobody:nogroup --from=base /opt /opt
COPY --chown=nobody:nogroup --from=intel_torch /opt /opt

FROM python:3.13-slim AS nvidia_flatten
COPY --chown=nobody:nogroup --from=base /opt /opt
COPY --chown=nobody:nogroup --from=nvidia_torch /opt /opt

# Phase 3 - Build final images

FROM python:3.13-slim AS final_base
ENTRYPOINT ["/bin/bash", "/usr/local/bin/entrypoint.sh"]

# Network & Server Flags
ENV LISTEN_ADDR=0.0.0.0
ENV CORS_HEADER=*
ENV MAX_UPLOAD_MB=100

# Attention Flags
ENV SPLIT_CROSS_ATTENTION=false
ENV QUAD_CROSS_ATTENTION=false
ENV PYTORCH_CROSS_ATTENTION=false
ENV SAGE_ATTENTION=false
ENV XFORMERS=true
ENV FORCE_UPCAST_ATTENTION=false
ENV DONT_UPCAST_ATTENTION=false

# VRAM & Memory Flags
ENV GPU_ONLY=false
ENV VRAM=auto
ENV CPU_ONLY=false

# Performance & Debugging Flags
ENV FAST=none

# ComfyUI Manager Flags
ENV ENABLE_MANAGER=false

# Logging & Misc Flags
ENV LOG_VERBOSITY=INFO
ENV MULTI_USER=false

# Home path fixes
ENV HOME=/opt/content
ENV HF_HOME=/opt/content/.cache/huggingface
ENV TORCH_HOME=/opt/content/.cache/torch
ENV XDG_CACHE_HOME=/opt/content/cache

EXPOSE 8188
LABEL org.opencontainers.image.authors=joepitt91
LABEL org.opencontainers.image.base.name=docker.io/_/python:3.13-slim
LABEL org.opencontainers.image.description="The most powerful and modular diffusion model GUI, api and backend with a graph/nodes interface."
LABEL org.opencontainers.image.documentation=https://github.com/joepitt91/comfyui-docker
LABEL org.opencontainers.image.source=https://github.com/joepitt91/comfyui-docker
LABEL org.opencontainers.image.title="ComfyUI"
LABEL org.opencontainers.image.url=https://github.com/joepitt91/comfyui-docker
STOPSIGNAL SIGINT
WORKDIR /opt/ComfyUI
RUN sed -i 's/Components: main/Components: main non-free/gm' /etc/apt/sources.list.d/debian.sources &&\
    apt update && apt install gcc git libcudart12 -yq && rm -rf /var/lib/apt/list/* &&\
    mkdir -p /etc/ssl/private/ /opt/content /opt/ComfyUI /opt/ComfyUI.venv /tmp/comfyui /opt/ComfyUI/user && \
    chown -R nobody:nogroup /etc/ssl/private/ /opt/content /opt/ComfyUI /opt/ComfyUI.venv /tmp/comfyui
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
USER nobody
VOLUME /etc/ssl/private/ /opt/ComfyUI/user /opt/content /tmp/comfyui
ARG COMFYUI_VERSION=v0.0.0 TORCH_VERSION=latest
LABEL org.opencontainers.image.version=${COMFYUI_VERSION}
ENV COMFYUI_VERSION=${COMFYUI_VERSION} TORCH_VERSION=${TORCH_VERSION}

FROM final_base AS amd
COPY --chown=nobody:nogroup --from=amd_flatten /opt /opt

FROM final_base AS cpu
ENV CPU_ONLY=true
COPY --chown=nobody:nogroup --from=base /opt /opt

FROM final_base AS intel
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libstdc++.so.6 LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu \
    SYCL_UR_USE_LEVEL_ZERO_V2=1 ONEAPI_DEVICE_SELECTOR=level_zero:0
COPY --chown=nobody:nogroup --from=intel_flatten /opt /opt
USER root

RUN apt-get update &&\
    apt-get -yq install ocl-icd-libopencl1 wget &&\
    rm -rf /var/lib/apt/lists/* &&\
    wget -q https://github.com/intel/intel-graphics-compiler/releases/download/v2.40.13/intel-igc-core-2_2.40.13+22418_amd64.deb &&\
    wget -q https://github.com/intel/intel-graphics-compiler/releases/download/v2.40.13/intel-igc-opencl-2_2.40.13+22418_amd64.deb &&\
    wget -q https://github.com/intel/compute-runtime/releases/download/26.31.39395.13/intel-ocloc-dbgsym_26.31.39395.13-0_amd64.ddeb &&\
    wget -q https://github.com/intel/compute-runtime/releases/download/26.31.39395.13/intel-ocloc_26.31.39395.13-0_amd64.deb &&\
    wget -q https://github.com/intel/compute-runtime/releases/download/26.31.39395.13/intel-opencl-icd-dbgsym_26.31.39395.13-0_amd64.ddeb &&\
    wget -q https://github.com/intel/compute-runtime/releases/download/26.31.39395.13/intel-opencl-icd_26.31.39395.13-0_amd64.deb &&\
    wget -q https://github.com/intel/compute-runtime/releases/download/26.31.39395.13/libigdgmm12_22.10.0_amd64.deb &&\
    wget -q https://github.com/intel/compute-runtime/releases/download/26.31.39395.13/libze-intel-gpu1-dbgsym_26.31.39395.13-0_amd64.ddeb &&\
    wget -q https://github.com/intel/compute-runtime/releases/download/26.31.39395.13/libze-intel-gpu1_26.31.39395.13-0_amd64.deb &&\
    dpkg -i *.deb &&\
    rm *.deb

USER nobody

FROM final_base AS nvidia
COPY --chown=nobody:nogroup --from=nvidia_flatten /opt /opt
