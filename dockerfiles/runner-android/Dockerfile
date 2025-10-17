# Android SDK Docker Image for GitHub Actions Runner
# Android SDK with command-line tools, platform tools, and build tools
# Image size: ~2.5GB

FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set Android SDK environment variables
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH=${PATH}:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/build-tools/34.0.0

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    unzip \
    openjdk-17-jdk \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create Android SDK directory
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools

# Download and install Android command-line tools
RUN wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools && \
    mv /tmp/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest && \
    rm -rf /tmp/cmdline-tools.zip /tmp/cmdline-tools

# Accept Android SDK licenses
RUN yes | sdkmanager --licenses

# Install Android SDK components
RUN sdkmanager --update && \
    sdkmanager \
    "platform-tools" \
    "platforms;android-34" \
    "build-tools;34.0.0" \
    "cmdline-tools;latest" \
    "emulator" \
    "system-images;android-34;google_apis;x86_64"

# Set up GitHub Actions runner user
RUN useradd -m -s /bin/bash runner && \
    mkdir -p /home/runner/work && \
    chown -R runner:runner /home/runner && \
    chown -R runner:runner ${ANDROID_SDK_ROOT}

# Set working directory
WORKDIR /home/runner

# Switch to non-root user
USER runner

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD adb version && sdkmanager --version || exit 1

# Default command
CMD ["/bin/bash"]
