# SPDX-FileCopyrightText: 2025-2026 Joe Pitt
#
# SPDX-License-Identifier: GPL-3.0-only

# Phase 1 - Get ComfyUI and platform-specific torch versions
ARG PYTHON_VERSION=3.14
FROM python:${PYTHON_VERSION}-slim AS base
RUN python3 -m venv /opt/ComfyUI.venv
RUN apt update && apt install git -yq
WORKDIR /opt

ARG COMFYUI_VERSION=0.0.0
RUN git clone --depth 1 --branch ${COMFYUI_VERSION} https://github.com/comfyanonymous/ComfyUI
WORKDIR /opt/ComfyUI
RUN rm -rf .git
ARG TORCH_VERSION=latest
RUN . /opt/ComfyUI.venv/bin/activate && pip install --no-cache-dir --quiet -r requirements.txt

ARG PYTHON_VERSION=3.14
FROM python:${PYTHON_VERSION}-slim AS amd_torch
RUN python3 -m venv /opt/ComfyUI.venv
ARG TORCH_VERSION=latest
RUN . /opt/ComfyUI.venv/bin/activate && \
    pip install --no-cache-dir --quiet torch torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/rocm6.2.4

ARG PYTHON_VERSION=3.14
FROM python:${PYTHON_VERSION}-slim AS intel_torch
RUN python3 -m venv /opt/ComfyUI.venv
ARG TORCH_VERSION=latest
RUN . /opt/ComfyUI.venv/bin/activate && \
    pip install --no-cache-dir --quiet torch torchvision torchaudio --index-url https://download.pytorch.org/whl/xpu

ARG PYTHON_VERSION=3.14
FROM python:${PYTHON_VERSION}-slim AS nvidia_torch
RUN python3 -m venv /opt/ComfyUI.venv
ARG TORCH_VERSION=latest
RUN . /opt/ComfyUI.venv/bin/activate && \
    pip install --no-cache-dir --quiet torch torchvision torchaudio \
        --extra-index-url https://download.pytorch.org/whl/cu128

# Phrase 2 - Combine dependencies

ARG PYTHON_VERSION=3.14
FROM python:${PYTHON_VERSION}-slim AS amd_flatten
COPY --chown=nobody:nogroup --from=base /opt /opt
COPY --chown=nobody:nogroup --from=amd_torch /opt /opt

ARG PYTHON_VERSION=3.14
FROM python:${PYTHON_VERSION}-slim AS intel_flatten
COPY --chown=nobody:nogroup --from=base /opt /opt
COPY --chown=nobody:nogroup --from=intel_torch /opt /opt

ARG PYTHON_VERSION=3.14
FROM python:${PYTHON_VERSION}-slim AS nvidia_flatten
COPY --chown=nobody:nogroup --from=base /opt /opt
COPY --chown=nobody:nogroup --from=nvidia_torch /opt /opt

# Phase 3 - Build final images

ARG PYTHON_VERSION=3.14
FROM python:${PYTHON_VERSION}-slim AS final_base
ARG PYTHON_VERSION=3.14
ENTRYPOINT ["/bin/bash", "/usr/local/bin/entrypoint.sh"]
ENV CORS_HEADER=*
ENV CPU_ONLY=false
ENV GPU_ONLY=false
ENV LISTEN_ADDR=0.0.0.0
ENV MAX_UPLOAD_MB=100
ENV SPLIT_CROSS_ATTENTION=false
ENV XDG_CACHE_HOME=/opt/content/cache
ENV VRAM=auto
EXPOSE 8188
LABEL org.opencontainers.image.authors=joepitt91
LABEL org.opencontainers.image.base.name=docker.io/_/python:${PYTHON_VERSION}-slim
LABEL org.opencontainers.image.description="The most powerful and modular diffusion model GUI, api and backend with a graph/nodes interface."
LABEL org.opencontainers.image.documentation=https://github.com/joepitt91/comfyui-docker
LABEL org.opencontainers.image.source=https://github.com/joepitt91/comfyui-docker
LABEL org.opencontainers.image.title="ComfyUI"
LABEL org.opencontainers.image.url=https://github.com/joepitt91/comfyui-docker
STOPSIGNAL SIGINT
WORKDIR /opt/ComfyUI
RUN apt update && apt install git -yq && rm -rf /var/lib/apt/list/* &&\
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
ENV  LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libstdc++.so.6 LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu \
    SYCL_UR_USE_LEVEL_ZERO_V2=1 ONEAPI_DEVICE_SELECTOR=level_zero:0
COPY --chown=nobody:nogroup --from=intel_flatten /opt /opt
USER root
RUN sed -i 's/main/main contrib non-free non-free-firmware/g' /etc/apt/sources.list.d/debian.sources &&\
    apt-get -yq update &&\
    apt-get -yq install clinfo firmware-intel-graphics intel-gpu-tools libze-dev libze1 &&\
    echo "Types: deb" >/etc/apt/sources.list.d/sid.sources &&\
    echo "URIs: http://deb.debian.org/debian" >>/etc/apt/sources.list.d/sid.sources &&\
    echo "Suites: sid"  >>/etc/apt/sources.list.d/sid.sources &&\
    echo "Components: main contrib non-free non-free-firmware"  >>/etc/apt/sources.list.d/sid.sources &&\
    echo "Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg"  >>/etc/apt/sources.list.d/sid.sources &&\
    apt-get -yq update &&\
    apt-get -yq install intel-opencl-icd libze-intel-gpu1 &&\
    rm -rf /var/lib/lists/*
USER nobody

FROM final_base AS nvidia
COPY --chown=nobody:nogroup --from=nvidia_flatten /opt /opt
