# Node.js Docker Image for GitHub Actions Runner
# Node.js 20+ with pnpm support and common development dependencies
# Image size: ~900MB

FROM node:20-slim

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    build-essential \
    python3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install pnpm globally
RUN npm install -g pnpm

# Install common Node.js development tools
RUN npm install -g \
    typescript \
    ts-node \
    eslint \
    prettier \
    jest \
    nodemon \
    pm2

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
    CMD node --version && pnpm --version || exit 1

# Default command
CMD ["/bin/bash"]
