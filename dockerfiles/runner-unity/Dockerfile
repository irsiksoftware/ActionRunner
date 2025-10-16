# Unity Docker Image for GitHub Actions Runner
# Supports Unity 2021.3 LTS with GPU acceleration
# Image size: ~10GB+

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    unzip \
    libglu1-mesa \
    libgconf-2-4 \
    libgl1 \
    xvfb \
    libxcursor1 \
    libxrandr2 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Unity Hub and Unity Editor version
ENV UNITY_VERSION=2021.3.31f1
ENV UNITY_HUB_VERSION=3.5.1
ENV UNITY_CHANGESET=6b54b7616050

# Install Unity Hub
RUN wget -qO /tmp/UnityHub.AppImage \
    https://public-cdn.cloud.unity3d.com/hub/prod/UnityHub.AppImage && \
    chmod +x /tmp/UnityHub.AppImage && \
    cd /tmp && \
    ./UnityHub.AppImage --appimage-extract && \
    mv squashfs-root /opt/unity-hub && \
    ln -s /opt/unity-hub/AppRun /usr/bin/unity-hub && \
    rm /tmp/UnityHub.AppImage

# Install Unity Editor
# Note: Requires Unity license file to be mounted at runtime
RUN mkdir -p /opt/unity && \
    unity-hub install --version ${UNITY_VERSION} --changeset ${UNITY_CHANGESET} \
    --install-location /opt/unity || true

# Install Android build support (for mobile builds)
RUN unity-hub install-modules --version ${UNITY_VERSION} \
    --module android --module android-sdk-ndk-tools || true

# Install iOS build support (requires macOS for actual builds)
RUN unity-hub install-modules --version ${UNITY_VERSION} \
    --module ios || true

# Set up GitHub Actions runner user
RUN useradd -m -s /bin/bash runner && \
    mkdir -p /home/runner/work && \
    chown -R runner:runner /home/runner

# Unity license and project directories
RUN mkdir -p /root/.local/share/unity3d/Unity && \
    ln -s /root/.local/share/unity3d/Unity /home/runner/.local/share/unity3d/Unity || true

# Set working directory
WORKDIR /home/runner

# Environment variables for GPU support
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=graphics,utility,compute

# Copy Unity build script
COPY ./scripts/unity-build.sh /usr/local/bin/unity-build
RUN chmod +x /usr/local/bin/unity-build

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD unity-hub -- --version || exit 1

# Default command
CMD ["/bin/bash"]
