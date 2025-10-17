# GPU Docker Image for GitHub Actions Runner
# NVIDIA CUDA enabled with Python, PyTorch, TensorFlow
# Requires NVIDIA Docker runtime and compatible GPU drivers on host

# Use NVIDIA CUDA base image with Ubuntu
FROM nvidia/cuda:12.3.1-cudnn8-runtime-ubuntu22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set CUDA environment variables
ENV CUDA_HOME=/usr/local/cuda \
    PATH=/usr/local/cuda/bin:${PATH} \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64:${LD_LIBRARY_PATH} \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3.11-dev \
    python3-pip \
    git \
    curl \
    wget \
    build-essential \
    libssl-dev \
    libffi-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create symlink for python
RUN ln -sf /usr/bin/python3.11 /usr/bin/python && \
    ln -sf /usr/bin/python3.11 /usr/bin/python3

# Upgrade pip and install common Python dependencies
RUN python -m pip install --no-cache-dir --upgrade pip setuptools wheel

# Install PyTorch with CUDA 12.1 support
RUN pip install --no-cache-dir \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Install TensorFlow with GPU support
RUN pip install --no-cache-dir tensorflow[and-cuda]

# Install common ML/AI libraries
RUN pip install --no-cache-dir \
    transformers \
    accelerate \
    datasets \
    tokenizers \
    sentencepiece \
    scikit-learn \
    pandas \
    numpy \
    scipy \
    matplotlib \
    seaborn \
    jupyter \
    notebook \
    jupyterlab

# Install testing frameworks
RUN pip install --no-cache-dir \
    pytest \
    pytest-cov \
    pytest-xdist \
    pytest-asyncio \
    pytest-mock

# Install code quality tools
RUN pip install --no-cache-dir \
    black \
    flake8 \
    pylint \
    mypy \
    isort

# Set up GitHub Actions runner user
RUN useradd -m -s /bin/bash runner && \
    mkdir -p /home/runner/work && \
    chown -R runner:runner /home/runner

# Set working directory
WORKDIR /home/runner

# Switch to non-root user
USER runner

# Health check - verify GPU access and core libraries
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import torch; import tensorflow as tf; assert torch.cuda.is_available(), 'CUDA not available'; exit(0)" || exit 1

# Default command
CMD ["/bin/bash"]
