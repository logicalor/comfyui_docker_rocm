#!/bin/bash
set -e

echo "=== ComfyUI Container Initialization (pip install method) ==="
echo "Running as user: $(whoami) ($(id -u):$(id -g))"

# Activate virtual environment
export VIRTUAL_ENV=/opt/venv
export PATH="$VIRTUAL_ENV/bin:$PATH"
echo "Using Python virtual environment: $VIRTUAL_ENV"
echo "Python: $(which python) ($(python --version))"

# Disable git tracking prompts
export COMFY_CLI_DISABLE_TRACKING=1

# Use HTTP/1.1 to avoid HTTP/2 stream issues
export GIT_HTTP_VERSION=HTTP/1.1
git config --global http.postBuffer 524288000

# Target directory for ComfyUI (where mounts are)
COMFYUI_DIR="/workspace/ComfyUI"

# Check if ComfyUI is already installed (has main.py)
if [ ! -f "/tmp/.comfyui_installed" ]; then
    if [ ! -f "$COMFYUI_DIR/main.py" ]; then
        echo "Installing ComfyUI..."
        
        # Clone to a temp directory first (avoids mount permission issues)
        TEMP_DIR="/tmp/comfyui_install"
        rm -rf "$TEMP_DIR" 2>/dev/null || true
        
        # Retry clone up to 3 times
        for i in 1 2 3; do
            echo "Clone attempt $i/3..."
            if git clone https://github.com/comfyanonymous/ComfyUI.git "$TEMP_DIR"; then
                break
            fi
            if [ $i -lt 3 ]; then
                echo "Clone failed, retrying in 5 seconds..."
                rm -rf "$TEMP_DIR" 2>/dev/null || true
                sleep 5
            else
                echo "Failed to clone ComfyUI after 3 attempts"
                exit 1
            fi
        done
        
        # Move files to the target directory (preserving mounted subdirectories)
        echo "Moving ComfyUI files to $COMFYUI_DIR..."
        shopt -s dotglob
        
        # Copy files, but don't overwrite mounted directories
        for item in "$TEMP_DIR"/*; do
            item_name=$(basename "$item")
            target="$COMFYUI_DIR/$item_name"
            
            # If target is a mount point (non-empty directory), copy contents into it
            if [ -d "$target" ] && [ -d "$item" ]; then
                echo "  Merging into mounted directory: $item_name"
                cp -rn "$item"/* "$target/" 2>/dev/null || true
                cp -rn "$item"/.[!.]* "$target/" 2>/dev/null || true
            else
                # Otherwise just copy/move the item
                cp -r "$item" "$COMFYUI_DIR/"
            fi
        done
        
        rm -rf "$TEMP_DIR"
        
        # Install ComfyUI requirements
        echo "Installing ComfyUI Python dependencies..."
        cd "$COMFYUI_DIR"
        pip install --no-cache-dir -r requirements.txt
        
        echo "✓ ComfyUI installation complete!"
    else
        echo "ComfyUI files found, ensuring dependencies are installed..."
        cd "$COMFYUI_DIR"
        pip install --no-cache-dir -r requirements.txt
    fi
    
    touch /tmp/.comfyui_installed
else
    echo "✓ ComfyUI already installed"
fi

# Check if ComfyUI-Manager is installed
if [ ! -f "/tmp/.comfyui_manager_installed" ]; then
    MANAGER_DIR="$COMFYUI_DIR/custom_nodes/ComfyUI-Manager"
    
    if [ ! -d "$MANAGER_DIR" ] || [ ! -f "$MANAGER_DIR/__init__.py" ]; then
        echo "Installing ComfyUI-Manager..."
        
        # Clone to temp first
        TEMP_MANAGER="/tmp/comfyui_manager_install"
        rm -rf "$TEMP_MANAGER" 2>/dev/null || true
        
        for i in 1 2 3; do
            echo "Clone attempt $i/3..."
            if git clone --depth 1 https://github.com/ltdrdata/ComfyUI-Manager.git "$TEMP_MANAGER"; then
                break
            fi
            if [ $i -lt 3 ]; then
                echo "Clone failed, retrying in 5 seconds..."
                rm -rf "$TEMP_MANAGER" 2>/dev/null || true
                sleep 5
            else
                echo "Failed to clone ComfyUI-Manager after 3 attempts"
                exit 1
            fi
        done
        
        # Move to target
        mkdir -p "$COMFYUI_DIR/custom_nodes"
        rm -rf "$MANAGER_DIR" 2>/dev/null || true
        mv "$TEMP_MANAGER" "$MANAGER_DIR"
    else
        echo "ComfyUI-Manager directory found, installing dependencies..."
    fi
    
    cd "$MANAGER_DIR"
    pip install --no-cache-dir -r requirements.txt
    touch /tmp/.comfyui_manager_installed
    echo "✓ ComfyUI-Manager installed!"
else
    echo "✓ ComfyUI-Manager already installed"
fi

echo "=== Starting ComfyUI ==="
cd "$COMFYUI_DIR"

# Install any missing custom node requirements
# NOTE: Do NOT use -q flag - we want verbose output for debugging
echo "Checking custom node dependencies..."
for node_dir in "$COMFYUI_DIR/custom_nodes"/*/; do
    if [ -f "${node_dir}requirements.txt" ]; then
        node_name=$(basename "$node_dir")
        echo "Installing requirements for $node_name..."
        
        # Skip problematic requirements that will always fail
        case "$node_name" in
            "Chye-ComfyUI-Toolset")
                # Has invalid 'comfyui>=1.0.0' requirement, install others manually
                pip install --no-cache-dir torch numpy scipy opencv-python requests coloredlogs 2>/dev/null || true
                ;;
            "comfyui-ollama")
                # Has 'dotenv' instead of 'python-dotenv'
                pip install --no-cache-dir ollama python-dotenv 2>/dev/null || true
                ;;
            *)
                # Install normally, continue on error (some packages may be platform-specific)
                pip install --no-cache-dir -r "${node_dir}requirements.txt" 2>/dev/null || true
                ;;
        esac
    fi
done

# Special case: facenet-pytorch for PuLID (needs --no-deps due to torch version conflicts)
if [ -d "$COMFYUI_DIR/custom_nodes/ComfyUI_PuLID_Flux_ll" ]; then
    echo "Installing facenet-pytorch for PuLID (with --no-deps)..."
    pip install --no-cache-dir facenet-pytorch --no-deps 2>/dev/null || true
fi

# Build command-line arguments
# COMFYUI_EXTRA_ARGS can be set in .env file for runtime options
EXTRA_ARGS="${COMFYUI_EXTRA_ARGS:-}"

echo "=== Starting ComfyUI ==="
if [ -n "$EXTRA_ARGS" ]; then
    echo "Extra arguments: $EXTRA_ARGS"
fi

# Start ComfyUI with listen on all interfaces
# $EXTRA_ARGS is intentionally unquoted to allow word splitting for multiple args
# "$@" passes any additional args from docker run command
exec python main.py --listen 0.0.0.0 $EXTRA_ARGS "$@"
