<!--
SPDX-FileCopyrightText: 2025 Joe Pitt

SPDX-License-Identifier: GPL-3.0-only
-->

# ComfyUI Docker Images

Easy to use container images of ComfyUI, supporting use in CPU only mode (slow) and with AMD, Intel
Arc and NVIDIA GPUs.

This guide assumed you already have a Docker host (Docker Desktop or a server) with the appropriate
hardware support in place, if not these links may help you get started:

* [Getting Started | Docker](https://www.docker.com/get-started/)
* [Enable GPU support | Docker Docs](https://docs.docker.com/compose/how-tos/gpu-support/)

## Getting Started

To run ComfyUI:

1. Download `compose/docker-compose.{TAG}.yml` to a suitable directory on your Docker host.
    * Replace `{TAG}` with the `cpu`, `intel` or `nvidia` as appropriate tag for your system.
    * If you'd prefer to build the image locally, use `compose/docker-compose.{TAG}.build.yml`
        instead, you'll need to update `services.comfyui.build.args` and
        `services.comfyui.build.tags` to the ComfyUI version you wish to build.
    * **NOTE**: The AMD dependencies are too large (~23GB) to build the image on GitHub Actions.
        You **MUST** build the image locally using `compose/docker-compose.amd.build.yml` to run on
        AMD hardware.
2. Rename your chosen file to `docker-compose.yml`.
2. Open a terminal in the chosen directory.
3. Start the service by running:

```sh
docker compose up -d
```

4. Monitor the container's startup by running:

```sh
docker compose logs -f
```

5. Once `To see the GUI go to: http://0.0.0.0:8188` is logged by the container, ComfyUI should be
accessible at http://localhost:8188/ from the Docker host.

## Installing Models and Other Files

Once ComfyUI is running, you will need to install at least one model and will likely want to add
other content too.

To copy files into the persisted `content` volume use the following command syntax:

```sh
docker compose cp ./v1-5-pruned-emaonly.safetensors comfyui:/opt/content/models/checkpoints/
```

The directory structure of `/opt/content` is:

```
/opt/
├─ content/
│  ├─ custom_nodes/
│  ├─ input/
|  │  ├─ 3d/
│  ├─ models/
|  │  ├─ checkpoints/
|  │  ├─ clip/
|  │  ├─ clip_vision/
|  │  ├─ configs/
|  │  ├─ controlnet/
|  │  ├─ diffusers/
|  │  ├─ diffusion_models/
|  │  ├─ embeddings/
|  │  ├─ gligen/
|  │  ├─ hypernetworks/
|  │  ├─ loras/
|  │  ├─ photomaker/
|  │  ├─ style_models/
|  │  ├─ text_encoders/
|  │  ├─ unet/
|  │  ├─ upscale_models/
|  │  ├─ vae/
|  │  ├─ vae_approx/
│  ├─ output/
│  ├─ temp/
│  ├─ user/
```

## Enabling HTTPS

To run ComfyUI over HTTPS, you will need an X.509 certificate and the corresponding private key,
these need to be copied into the container's `tls` volume, then the container needs to be restarted.

In the below example, a certificate called `ComfyUI` has been obtained using `certbot`, adjust the
source paths as required for the certificate being installed.

```sh
docker compose cp --follow-link /etc/letsencrypt/live/ComfyUI/fullchain.pem comfyui:/etc/ssl/private/cert.pem
docker compose cp --follow-link /etc/letsencrypt/live/ComfyUI/privkey.pem comfyui:/etc/ssl/private/key.pem
docker compose up -d --force-recreate
```

Once complete, ComfyUI should be accessible at https://localhost:8188/.

## Network Access

By default, ComfyUI is only available on the docker host, to allow network access edit 
`docker-compose.yml` - replacing `- 127.0.0.1:8188:8188` with `- '8188:8188'` - and restart the
container by running:

```sh
docker compose up -d --force-recreate
```

Once complete, ComfyUI should be accessible at http://{docker host IP / FQDN}:8188/ 
(https://{docker host IP / FQDN}:8188/ if HTTPS has been enabled as above).

**NOTE:** If a host-based firewall is present on the Docker host, or a network firewall is between
the docker host and clients, rules will need to be added to allow access.

## More Details

### Image Tags

#### Architecture

Each supported hardware architecture has an associated set of images tagged as follows, there is no
`latest` tag for this image.

The supported architecture tags are:

* `cpu` - runs ComfyUI on the CPU, rather than GPU - slow but widely compatible.
* `intel` - runs ComfyUI on a supported Intel Arc graphics card.
* `nvidia` - runs ComfyUI on a supported NVIDIA graphics card.

**NOTE:** As above the AMD image must be build locally due to the size of its dependencies.

#### ComfyUI Version

Each imaged version of ComfyUI, has associated tags for each architecture, taking the `cpu`
architecture as an example, these include:

* `cpu` - The latest release of ComfyUI for the `cpu` architecture.
* `0-cpu` - The latest 0.*.* release of ComfyUI for the `cpu` architecture.
* `0.3-cpu` - The latest 0.3.* release of ComfyUI for the `cpu` architecture.
* `0.3.31-cpu` - Version 0.3.31 of ComfyUI for the `cpu` architecture.

### Environment Variables

ComfyUI can be customised using the following environment variables, these can be configured by
creating a file named `comfyui.env` with one variable per line in the format `VARIABLE_NAME=VALUE`,
only variables being changed from their Default need to be present in the file.

| Variable | Purpose | Default |
| -------- | ------- | ------- |
| `CORS_HEADER` | Set the Cross-Origin Resource Sharing (CORS) header to restrict access from other domains. Can be set to either `*` for unrestricted or a URL to limit CORS requests to that domain and protocol. | `*` |
| `CPU_ONLY` | Run on the CPU only - this will be slow and should be used with the `cpu` tag. | ` false` |
| `GPU_ONLY` | Run all operations on the GPU only. | ` false` |
| `LISTEN_ADDR` | What address, within the container, ComfyUI should bind to (e.g. `0.0.0.0,::` for dual-stack environments). | `0.0.0.0` |
| `MAX_UPLOAD_MB` | The maximum upload size in megabytes - when running behind a reverse proxy ensure to set this there too. | `100` |
| `SPLIT_CROSS_ATTENTION` | Enable Split Cross Attention - can help with some memory and speed issues | `false ` |
| `VRAM` | The VRAM profile to run with, can be `auto`, `high`, `normal`, `low` or `no`. | `auto` |

### Volumes

The image uses three volumes:

* `content` for user-content such as models, uploads, output files ,etc.
* `tls` for enabling HTTPS - place the certificate with chain in `cert.pem` and the unencrypted
    private key in `key.pem`
* `tmp` for temporary files - you may want to set this up as a `tmpfs` mount for performance
    optimisation.
