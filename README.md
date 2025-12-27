# ComfyUI Docker (AMD ROCm)

A Docker-based ComfyUI setup optimized for AMD GPUs using ROCm.

## Features

- ROCm 6.2 support for AMD GPUs (RX 7000 series, etc.)
- Python virtual environment isolation
- Automatic ComfyUI and ComfyUI-Manager installation
- Configurable data directories via environment variables
- Runtime arguments configurable without rebuilding
- Non-root user execution with proper permissions

## Requirements

- Docker and Docker Compose
- AMD GPU with ROCm support
- ROCm drivers installed on host

## Quick Start

1. **Clone this repository**

2. **Create your environment file**
   ```bash
   cp .env.example .env
   ```

3. **Edit `.env`** and set your paths:
   ```dotenv
   COMFYUI_OUTPUT=/path/to/output
   COMFYUI_MODELS=/path/to/models
   COMFYUI_CUSTOM_NODES=/path/to/custom_nodes
   COMFYUI_LOGS=/path/to/logs
   COMFYUI_CACHE=/path/to/cache
   COMFYUI_USER_DEFAULT=/path/to/user/default
   ```

4. **Create the directories** on your host:
   ```bash
   mkdir -p /path/to/output /path/to/models /path/to/custom_nodes \
            /path/to/logs /path/to/cache /path/to/user/default
   ```

5. **Build and start**
   ```bash
   docker compose up -d --build
   ```

6. **Access ComfyUI** at http://localhost:8188

## Configuration

### Directory Structure

| Variable | Description |
|----------|-------------|
| `COMFYUI_OUTPUT` | Generated images |
| `COMFYUI_MODELS` | Model files, LoRAs, VAEs, checkpoints |
| `COMFYUI_CUSTOM_NODES` | Custom node plugins |
| `COMFYUI_LOGS` | Log files |
| `COMFYUI_CACHE` | Cache files |
| `COMFYUI_USER_DEFAULT` | User workflows and settings |

### Runtime Options

Set `COMFYUI_EXTRA_ARGS` in `.env` to pass arguments to ComfyUI:

```dotenv
# Reserve 4GB VRAM for other applications
COMFYUI_EXTRA_ARGS=--reserve-vram 4.0

# Low VRAM mode
COMFYUI_EXTRA_ARGS=--lowvram

# Multiple options
COMFYUI_EXTRA_ARGS=--reserve-vram 2.0 --force-fp16
```

Common options:
- `--lowvram` / `--highvram` / `--normalvram` - VRAM modes
- `--reserve-vram X.X` - Reserve VRAM in GB
- `--disable-smart-memory` - Disable smart memory management
- `--force-fp16` / `--force-fp32` - Force precision
- `--preview-method auto` - Preview generation method

### GPU Configuration

The `docker-compose.yml` includes settings for AMD GPUs:

```yaml
environment:
  - HSA_OVERRIDE_GFX_VERSION=11.0.0  # For RDNA3 (RX 7000 series)
  - ROCR_VISIBLE_DEVICES=0,1         # GPU indices to use
```

Adjust `HSA_OVERRIDE_GFX_VERSION` based on your GPU architecture.

## Commands

```bash
# Start
docker compose up -d

# Stop
docker compose down

# View logs
docker compose logs -f

# Rebuild after Dockerfile changes
docker compose up -d --build

# Full rebuild (no cache)
docker compose build --no-cache && docker compose up -d

# Shell access
docker compose exec comfyui-pip bash
```

## Updating

### Update ComfyUI (inside container)
```bash
docker compose exec comfyui-pip bash
cd /workspace/ComfyUI
git pull
```

### Update Docker image
```bash
docker compose build --no-cache
docker compose up -d
```

## File Structure

```
.
├── Dockerfile          # Container image definition
├── docker-compose.yml  # Service configuration
├── entrypoint.sh       # Container startup script
├── init.sh             # Permission fixing script (runs as root)
├── .env.example        # Example environment configuration
├── .env                # Your local configuration (not in git)
├── .gitignore          # Git ignore rules
└── .dockerignore       # Docker build ignore rules
```

## Troubleshooting

### Permission denied errors
The container uses an init script to fix permissions on mounted directories. If you still see permission issues, ensure your host directories are owned by UID 1000:
```bash
sudo chown -R 1000:1000 /path/to/your/comfyui/directories
```

### GPU not detected
- Verify ROCm is installed on host: `rocminfo`
- Check GPU is visible: `docker run --rm --device=/dev/kfd --device=/dev/dri rocm/dev-ubuntu-24.04:6.2 rocminfo`

### Out of memory
- Set `COMFYUI_EXTRA_ARGS=--lowvram` in `.env`
- Or reserve less VRAM: `COMFYUI_EXTRA_ARGS=--reserve-vram 1.0`

## License

This Docker configuration is provided as-is. ComfyUI has its own license.

## Disclaimer

This repository is **unsupported**. Feel free to fork, adapt, or use as a reference for your own setup, but no support, maintenance, or updates are guaranteed. Use at your own risk.
