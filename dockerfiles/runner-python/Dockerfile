# Python Docker Image for GitHub Actions Runner
# Python 3.11+ with common testing and development dependencies
# Image size: ~1GB

FROM python:3.11-slim

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    build-essential \
    libssl-dev \
    libffi-dev \
    libpq-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip and install common Python dependencies
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Install common testing frameworks
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
    isort \
    autopep8

# Install common development libraries
RUN pip install --no-cache-dir \
    requests \
    aiohttp \
    pydantic \
    python-dotenv \
    pyyaml \
    click

# Set up GitHub Actions runner user
RUN useradd -m -s /bin/bash runner && \
    mkdir -p /home/runner/work && \
    chown -R runner:runner /home/runner

# Set working directory
WORKDIR /home/runner

# Switch to non-root user
USER runner

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python --version || exit 1

# Default command
CMD ["/bin/bash"]
