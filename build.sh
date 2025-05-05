#!/bin/bash

# SPDX-FileCopyrightText: 2025 Joe Pitt
#
# SPDX-License-Identifier: GPL-3.0-only

set -e

echo "Installing dependencies to get current ComfyUI Version..."
if [ ! -a "comfyui_version/.venv/bin/python3" ]; then
    python3 -m venv comfyui_version/.venv/
fi
# shellcheck disable=SC1091
. comfyui_version/.venv/bin/activate
python3 -m pip install --quiet --upgrade pip
python3 -m pip install --quiet --upgrade -r comfyui_version/requirements.txt

echo "Getting current ComfyUI Version..."
CURRENT_VERSION=$(python3 comfyui_version/comfyui_version.py)
CURRENT_VERSION_PARTS=()
IFS=. read -r -a CURRENT_VERSION_PARTS <<< "${CURRENT_VERSION:1}"
deactivate

REPO=ghcr.io/joepitt91/comfyui-docker
TARGETS=("amd" "cpu" "intel" "nvidia")

cd src/
for target in "${TARGETS[@]}"; do
    if [ -n "${COMFYUI_VERSION}" ] && [ "${COMFYUI_VERSION}" != "${CURRENT_VERSION}" ]; then
    echo "Building ${COMFYUI_VERSION} for ${target}..."
        tags=(--tag "${REPO}:${COMFYUI_VERSION:1}-${target}")
        docker build "${tags[@]}" --target "${target}" --build-arg COMFYUI_VERSION="${COMFYUI_VERSION}" .
    else
        echo "Building ${CURRENT_VERSION} (latest) for ${target}..."
        tags=(--tag "${REPO}:${target}"
            --tag "${REPO}:${CURRENT_VERSION:1}-${target}"
            --tag "${REPO}:${CURRENT_VERSION_PARTS[0]}.${CURRENT_VERSION_PARTS[1]}-${target}"
            --tag "${REPO}:${CURRENT_VERSION_PARTS[0]}-${target}")
        docker build "${tags[@]}" --target "${target}" --build-arg COMFYUI_VERSION="${CURRENT_VERSION}" .
    fi
done
