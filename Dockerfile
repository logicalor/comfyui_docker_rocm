FROM rocm/dev-ubuntu-24.04:6.2

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Update and install Python 3.12, build essentials, and utilities
RUN apt-get update && apt-get install -y \
    python3.12 \
    python3.12-dev \
    python3.12-venv \
    python3-pip \
    build-essential \
    gcc \
    g++ \
    make \
    cmake \
    pkg-config \
    # GLib runtime (provides libgthread-2.0.so.0)
    libglib2.0-0 \
    # Fonts for text rendering nodes
    fonts-dejavu-core \
    fontconfig \
    wget \
    curl \
    git \
    vim \
    htop \
    nano \
    # For dropping privileges in init script
    gosu \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.12 as default python3
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1

# Remove PEP 668 restrictions (we're in a container, it's fine)
RUN rm -f /usr/lib/python3.12/EXTERNALLY-MANAGED

# Upgrade pip
RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel --ignore-installed

# Create virtual environment
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Install PyTorch with ROCm 6.2 support (into venv)
RUN pip install --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.2

# Install ComfyUI via pip (into venv)
RUN pip install --no-cache-dir comfy-cli

# Set environment variables for ROCm
ENV PATH="/opt/rocm/bin:$VIRTUAL_ENV/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/rocm/lib:${LD_LIBRARY_PATH}"

# Use existing ubuntu user (UID/GID 1000) from base image and add to video/render groups
RUN usermod -aG video,render ubuntu

# Create workspace directory and set ownership
RUN mkdir -p /workspace && chown -R ubuntu:ubuntu /workspace

# Give non-root user access to venv for installing packages at runtime
RUN chown -R ubuntu:ubuntu $VIRTUAL_ENV

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy init script that fixes permissions (runs as root before dropping to user)
COPY init.sh /init.sh
RUN chmod +x /init.sh

# Set working directory (container starts as root, init.sh drops to ubuntu user)
WORKDIR /workspace

# Expose ComfyUI port
EXPOSE 8188

# Set entrypoint to init script (handles permissions, then drops to user)
ENTRYPOINT ["/init.sh"]

# Default command - pass any additional args to ComfyUI
CMD []
