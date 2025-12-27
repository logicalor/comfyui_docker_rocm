#!/bin/bash
# Init script - runs as root to fix permissions, then drops to ubuntu user
set -e

echo "=== Initializing container (running as root) ==="

# Fix ownership of workspace directories created by Docker mounts
# Docker creates parent directories as root when subdirectory mounts are specified
if [ -d "/workspace/ComfyUI" ]; then
    echo "Fixing ownership of /workspace/ComfyUI..."
    chown -R ubuntu:ubuntu /workspace/ComfyUI
fi

# Ensure the workspace is owned by ubuntu
chown -R ubuntu:ubuntu /workspace

echo "=== Dropping to ubuntu user ==="

# Execute the main entrypoint as the ubuntu user
exec gosu ubuntu /entrypoint.sh "$@"
