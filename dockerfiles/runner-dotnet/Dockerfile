# .NET Docker Image for GitHub Actions Runner
# Supports .NET 6, 7, and 8 SDK and runtime
# Multi-stage build for optimized image size

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS sdk-8
FROM mcr.microsoft.com/dotnet/sdk:7.0 AS sdk-7
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS sdk-6

# Final image with all .NET versions
FROM mcr.microsoft.com/dotnet/sdk:8.0

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set up .NET environment variables
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1 \
    NUGET_XMLDOC_MODE=skip \
    DOTNET_NOLOGO=1

# Install .NET 6 and 7 SDKs alongside .NET 8
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install .NET 6 SDK
RUN wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --channel 6.0 --install-dir /usr/share/dotnet && \
    rm dotnet-install.sh

# Install .NET 7 SDK
RUN wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh && \
    chmod +x dotnet-install.sh && \
    ./dotnet-install.sh --channel 7.0 --install-dir /usr/share/dotnet && \
    rm dotnet-install.sh

# Set up GitHub Actions runner user
RUN useradd -m -s /bin/bash runner && \
    mkdir -p /home/runner/work && \
    chown -R runner:runner /home/runner

# Set working directory
WORKDIR /home/runner

# Verify installations
RUN dotnet --list-sdks && \
    dotnet --list-runtimes

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD dotnet --version || exit 1

# Default command
CMD ["/bin/bash"]
