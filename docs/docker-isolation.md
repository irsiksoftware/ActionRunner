# Docker Isolation for Untrusted Code

## Overview

ActionRunner uses Docker containers to provide secure, ephemeral environments for executing jobs from untrusted sources (e.g., public PRs). This isolation prevents malicious code from accessing the host system or other sensitive resources.

## Architecture

### Container Types

We provide four specialized container environments:

1. **Unity Build Environment** (`actionrunner/unity`)
   - Ubuntu 22.04 base
   - Unity Hub and Editor
   - Isolated build workspace
   - Non-root user execution

2. **Python Test Environment** (`actionrunner/python`)
   - Python 3.11 slim
   - Common testing frameworks (pytest, coverage, etc.)
   - Code quality tools (black, flake8, mypy)
   - Resource-limited execution

3. **.NET Build Environment** (`actionrunner/dotnet`)
   - .NET SDK 8.0
   - Optimized for build performance
   - NuGet cache isolation
   - Telemetry disabled

4. **GPU-Enabled AI Environment** (`actionrunner/gpu`)
   - NVIDIA CUDA 12.2 runtime
   - PyTorch and TensorFlow
   - GPU access controls
   - ML/AI framework support

### Security Features

- **User Isolation**: All containers run as non-root user `runner`
- **Resource Limits**: CPU, memory, and disk I/O constraints via WSL2 configuration
- **Network Isolation**: Containers can be run with limited network access
- **Ephemeral Storage**: Containers are destroyed after job completion
- **Read-only Mounts**: Critical directories mounted as read-only where applicable
- **Health Checks**: Regular container health monitoring

## Setup

### Prerequisites

- Windows 10/11 with WSL2 support
- Administrator access
- 16GB RAM minimum (32GB recommended)
- NVIDIA GPU (optional, for GPU workloads)

### Installation

Run the automated setup script:

```powershell
# Run as Administrator
.\scripts\setup-docker.ps1 -ConfigureGPU -MaxCPUs 8 -MaxMemoryGB 16
```

This script will:
1. Install Docker Desktop for Windows (unless -SkipInstall is used)
2. Configure WSL2 backend
3. Set up GPU passthrough for CUDA containers (if -ConfigureGPU is specified and NVIDIA GPU detected)
4. Configure resource limits (via -MaxCPUs and -MaxMemoryGB parameters)
5. Build all container images

### Manual Configuration

If you prefer manual setup, follow these steps:

#### 1. Install Docker Desktop

Download and install from: https://www.docker.com/products/docker-desktop

#### 2. Configure WSL2

```powershell
wsl --install
```

Create `.wslconfig` in your user profile:

```ini
[wsl2]
memory=8GB
processors=4
swap=4GB
nestedVirtualization=true
```

#### 3. Build Container Images

```powershell
cd docker

# Build all images
docker build -t actionrunner/unity:latest -f Dockerfile.unity .
docker build -t actionrunner/python:latest -f Dockerfile.python .
docker build -t actionrunner/dotnet:latest -f Dockerfile.dotnet .
docker build -t actionrunner/gpu:latest -f Dockerfile.gpu .
```

#### 4. Configure GPU Support (Optional)

Install NVIDIA Container Toolkit in WSL2:

```bash
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
```

## Usage

### Running Jobs with PowerShell Scripts

ActionRunner provides PowerShell scripts for easy job execution:

#### Basic Job Execution

```powershell
# Run a Python test job
.\scripts\run-in-docker.ps1 `
  -Environment python `
  -WorkspacePath "C:\repos\project" `
  -Command "pytest tests/"

# Run a .NET build
.\scripts\run-in-docker.ps1 `
  -Environment dotnet `
  -WorkspacePath "C:\repos\app" `
  -Command "dotnet build"

# Run with custom resource limits
.\scripts\run-in-docker.ps1 `
  -Environment python `
  -WorkspacePath "C:\repos\project" `
  -Command "pytest tests/" `
  -MaxCPUs 8 `
  -MaxMemoryGB 16 `
  -TimeoutMinutes 120

# Network isolated execution (for untrusted code)
.\scripts\run-in-docker.ps1 `
  -Environment python `
  -WorkspacePath "C:\repos\untrusted" `
  -Command "python script.py" `
  -NetworkIsolated
```

### Running Jobs Manually with Docker

For direct Docker access:

```powershell
# Run a Python test job
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  --memory="2g" \
  --cpus="2" \
  actionrunner/python:latest \
  pytest tests/

# Run a .NET build
docker run --rm \
  -v ${PWD}:/workspace \
  -w /workspace \
  --memory="4g" \
  --cpus="4" \
  actionrunner/dotnet:latest \
  dotnet build
```

#### GPU-Enabled Execution

```powershell
# Run ML training with GPU
docker run --rm \
  --gpus all \
  -v ${PWD}:/workspace \
  -w /workspace \
  --memory="8g" \
  actionrunner/gpu:latest \
  python train_model.py
```

#### Security-Hardened Execution

For untrusted code, add these security flags:

```powershell
docker run --rm \
  -v ${PWD}:/workspace:ro \  # Read-only mount
  -w /workspace \
  --memory="2g" \
  --cpus="2" \
  --network=none \  # No network access
  --security-opt=no-new-privileges \
  --cap-drop=ALL \
  actionrunner/python:latest \
  pytest tests/
```

### Container Management

#### Using Cleanup Script

```powershell
# Basic cleanup (dangling images only)
.\scripts\cleanup-docker.ps1

# Aggressive cleanup (all unused images)
.\scripts\cleanup-docker.ps1 -All

# Skip confirmation prompt
.\scripts\cleanup-docker.ps1 -Force

# Custom age threshold
.\scripts\cleanup-docker.ps1 -OlderThanDays 14
```

#### Manual Container Management

```powershell
# List running containers
docker ps

# Stop all ActionRunner containers
docker stop $(docker ps -q --filter "name=actionrunner-")

# Remove stopped containers
docker container prune -f

# Remove unused images
docker image prune -a -f

# Complete cleanup (use with caution)
docker system prune -a -f --volumes
```

### Resource Monitoring

Monitor container resource usage:

```powershell
docker stats
```

## Integration with ActionRunner

### Configuration

Update your runner configuration to use Docker containers:

```yaml
# config/runner-config.yaml
isolation:
  enabled: true
  mode: docker

  containers:
    unity:
      image: actionrunner/unity:latest
      memory: 8g
      cpus: 4

    python:
      image: actionrunner/python:latest
      memory: 2g
      cpus: 2

    dotnet:
      image: actionrunner/dotnet:latest
      memory: 4g
      cpus: 4

    gpu:
      image: actionrunner/gpu:latest
      memory: 16g
      cpus: 8
      gpu: true

  security:
    readonly_workspace: true
    network_disabled: true
    drop_capabilities: all
```

### Workflow Example

When a job is received from a public PR:

1. Runner detects job type (Unity, Python, .NET, GPU)
2. Selects appropriate container image
3. Mounts workspace with appropriate permissions
4. Applies resource limits
5. Executes job in isolated container
6. Collects results and logs
7. Destroys container
8. Returns results to GitHub

## Troubleshooting

### Docker Desktop Not Starting

```powershell
# Restart Docker service
Restart-Service docker

# Or restart WSL
wsl --shutdown
```

### GPU Not Accessible in Container

```powershell
# Verify GPU is available on host
nvidia-smi

# Test GPU in container
docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
```

### Container Build Failures

```powershell
# Clear build cache
docker builder prune -a -f

# Rebuild with no cache
docker build --no-cache -t actionrunner/python:latest -f Dockerfile.python .
```

### WSL2 Memory Issues

Edit `.wslconfig` to reduce memory allocation:

```ini
[wsl2]
memory=4GB
processors=2
```

Then restart WSL:

```powershell
wsl --shutdown
```

## Performance Optimization

### Image Caching

Container images are cached locally. To update:

```powershell
# Pull latest base images
docker pull ubuntu:22.04
docker pull python:3.11-slim
docker pull mcr.microsoft.com/dotnet/sdk:8.0
docker pull nvidia/cuda:12.2.0-runtime-ubuntu22.04

# Rebuild images
.\scripts\setup-docker.ps1
```

### Build Artifacts

Mount a persistent volume for build artifacts:

```powershell
docker volume create actionrunner-cache

docker run --rm \
  -v ${PWD}:/workspace \
  -v actionrunner-cache:/cache \
  actionrunner/dotnet:latest \
  dotnet build
```

## Security Best Practices

1. **Always use resource limits** to prevent resource exhaustion attacks
2. **Disable network access** for untrusted code unless required
3. **Use read-only mounts** when possible
4. **Drop all capabilities** and add back only what's needed
5. **Regularly update base images** for security patches
6. **Monitor container logs** for suspicious activity
7. **Clean up containers** immediately after job completion

## Maintenance

### Regular Updates

Update container images monthly:

```powershell
# Update base images
docker pull ubuntu:22.04
docker pull python:3.11-slim
docker pull mcr.microsoft.com/dotnet/sdk:8.0
docker pull nvidia/cuda:12.2.0-runtime-ubuntu22.04

# Rebuild all images
.\scripts\setup-docker.ps1

# Clean up old images
docker image prune -a -f
```

### Monitoring

Set up monitoring for:
- Container resource usage
- Failed container starts
- Unusual network activity
- Disk space consumption

## References

- [Docker Desktop for Windows](https://docs.docker.com/desktop/install/windows-install/)
- [WSL2 Documentation](https://docs.microsoft.com/en-us/windows/wsl/)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)

---

**Last Updated:** 2025-10-03
**Review Frequency:** Monthly or when new container types are added
