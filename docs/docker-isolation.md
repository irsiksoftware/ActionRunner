# Docker Isolation for Self-Hosted Runner

## Overview

This document describes the Docker-based isolation setup for running GitHub Actions jobs in secure, ephemeral containers on the self-hosted runner. This approach is critical for safely executing jobs from untrusted sources, particularly public pull requests.

## Architecture

### Container Environments

The runner provides four pre-built Docker images, each optimized for specific workloads:

1. **runner-unity** - Unity game development and builds
2. **runner-python** - Python testing and development
3. **runner-dotnet** - .NET Core builds and testing
4. **runner-gpu** - AI/ML workloads with GPU acceleration

### Security Model

Each job runs in an isolated Docker container with:
- **No host access** - Containers cannot access the host filesystem or network
- **Resource limits** - CPU, memory, and disk usage are capped
- **Ephemeral storage** - All data is destroyed after job completion
- **Network isolation** - Limited external network access
- **Non-root execution** - Jobs run as non-privileged users

## Setup

### Prerequisites

- Windows 10/11 Pro or Windows Server 2019/2022
- Administrator access
- At least 16GB RAM (32GB recommended for GPU workloads)
- 100GB free disk space
- NVIDIA GPU (optional, for GPU-enabled containers)

### Installation

Run the setup script as Administrator:

```powershell
.\scripts\setup-docker.ps1
```

#### Installation Options

```powershell
# Install with GPU support
.\scripts\setup-docker.ps1 -EnableGPU

# Custom resource limits
.\scripts\setup-docker.ps1 -MaxCPUs 8 -MaxMemoryGB 16

# Skip Docker installation (if already installed)
.\scripts\setup-docker.ps1 -SkipDockerInstall
```

### Post-Installation

1. **Restart your system** if WSL2 was just installed
2. **Start Docker Desktop** and wait for it to fully initialize
3. **Verify installation**:
   ```powershell
   docker run hello-world
   docker images --filter "reference=runner-*"
   ```

## Usage

### Running Jobs in Containers

To use Docker isolation in your GitHub Actions workflow, specify the container in your job definition:

```yaml
jobs:
  python-tests:
    runs-on: self-hosted
    container:
      image: runner-python:latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: pytest tests/

  unity-build:
    runs-on: self-hosted
    container:
      image: runner-unity:latest
    steps:
      - uses: actions/checkout@v4
      - name: Build Unity project
        run: |
          # Unity build commands

  gpu-training:
    runs-on: self-hosted
    container:
      image: runner-gpu:latest
      options: --gpus all
    steps:
      - uses: actions/checkout@v4
      - name: Train model
        run: python train.py
```

### Container Resource Limits

You can specify resource limits in your workflow:

```yaml
jobs:
  resource-limited:
    runs-on: self-hosted
    container:
      image: runner-python:latest
      options: >-
        --cpus 2
        --memory 4g
        --storage-opt size=20g
```

## Maintenance

### Cleanup After Jobs

The cleanup script runs automatically after each job to remove containers and free up space:

```powershell
# Manual cleanup
.\scripts\cleanup-docker.ps1

# Dry run to see what would be removed
.\scripts\cleanup-docker.ps1 -DryRun

# Aggressive cleanup (removes all containers and non-runner images)
.\scripts\cleanup-docker.ps1 -Force -RemoveAllContainers -RemoveAllImages
```

### Scheduled Cleanup

Add a scheduled task to run cleanup daily:

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\Code\ActionRunner\scripts\cleanup-docker.ps1"

$trigger = New-ScheduledTaskTrigger -Daily -At 2am

Register-ScheduledTask -TaskName "Docker Cleanup" `
    -Action $action -Trigger $trigger -RunLevel Highest
```

### Updating Images

To rebuild images with the latest dependencies:

```powershell
# Rebuild all images
cd docker
docker build -t runner-unity:latest -f Dockerfile.unity .
docker build -t runner-python:latest -f Dockerfile.python .
docker build -t runner-dotnet:latest -f Dockerfile.dotnet .
docker build -t runner-gpu:latest -f Dockerfile.gpu .

# Or re-run setup script
.\scripts\setup-docker.ps1 -SkipDockerInstall
```

## GPU Support

### Requirements

- NVIDIA GPU with CUDA support
- Windows 10/11 with WSL2
- NVIDIA drivers (latest version)

### Configuration

GPU passthrough is configured automatically when using the `-EnableGPU` flag:

```powershell
.\scripts\setup-docker.ps1 -EnableGPU
```

### Verification

Test GPU access in a container:

```powershell
docker run --rm --gpus all runner-gpu:latest powershell -Command `
    "python -c 'import torch; print(f\"CUDA available: {torch.cuda.is_available()}\")'"
```

## Troubleshooting

### Docker Desktop Not Starting

1. Ensure WSL2 is properly installed: `wsl --list --verbose`
2. Check Windows Features: Hyper-V and WSL must be enabled
3. Restart Docker Desktop service
4. Check Docker Desktop logs in `%LOCALAPPDATA%\Docker\log.txt`

### Container Build Failures

1. Ensure Docker has sufficient disk space
2. Clear build cache: `docker builder prune -a`
3. Check for network connectivity issues
4. Verify base images are accessible

### GPU Not Detected in Container

1. Verify NVIDIA drivers are installed on host
2. Check WSL2 has GPU access: `wsl nvidia-smi`
3. Ensure NVIDIA Container Toolkit is installed in WSL2
4. Restart Docker Desktop after driver updates

### Out of Disk Space

1. Run cleanup script: `.\scripts\cleanup-docker.ps1 -Force`
2. Check disk usage: `docker system df`
3. Increase Docker disk size in Docker Desktop settings
4. Remove unused images: `docker image prune -a`

### Performance Issues

1. Increase resource allocation in `setup-docker.ps1`
2. Move Docker data to faster SSD
3. Reduce number of concurrent jobs
4. Monitor resource usage: `docker stats`

## Security Best Practices

### For Public Repositories

1. **Always use containers** for jobs triggered by public PRs
2. **Review PR code** before approving workflow runs
3. **Limit network access** using Docker network policies
4. **Monitor resource usage** to detect abuse
5. **Use read-only volumes** for shared data

### Container Hardening

```yaml
container:
  image: runner-python:latest
  options: >-
    --read-only
    --security-opt=no-new-privileges
    --cap-drop=ALL
    --network=none
```

### Secrets Management

- Never pass secrets to untrusted containers
- Use GitHub's encrypted secrets
- Rotate secrets regularly
- Audit secret access

## Advanced Configuration

### Custom Images

Create custom Dockerfiles in the `docker/` directory:

```dockerfile
# docker/Dockerfile.custom
FROM runner-python:latest

# Install additional dependencies
RUN pip install my-custom-package

# Custom configuration
ENV MY_VAR=value
```

Build and use:

```powershell
docker build -t runner-custom:latest -f docker/Dockerfile.custom docker/
```

### Volume Mounts

Mount host directories (use with caution):

```yaml
container:
  image: runner-python:latest
  volumes:
    - /c/cache:/cache:ro  # Read-only cache
```

### Network Configuration

Configure custom networks for inter-container communication:

```powershell
docker network create runner-network

# In workflow:
# options: --network runner-network
```

## Monitoring and Logging

### Container Logs

View logs from running containers:

```powershell
# List running containers
docker ps

# View logs
docker logs <container-id>

# Follow logs in real-time
docker logs -f <container-id>
```

### Resource Monitoring

Monitor resource usage:

```powershell
# Real-time stats
docker stats

# Disk usage
docker system df

# Container inspection
docker inspect <container-id>
```

### Automated Monitoring

Set up monitoring in your workflow:

```yaml
steps:
  - name: Monitor resources
    run: |
      docker stats --no-stream
      docker system df
```

## Migration Guide

### From Native Execution

To migrate existing workflows to use containers:

1. Identify the appropriate container image (python, dotnet, unity, gpu)
2. Add container specification to job
3. Test workflow in isolated environment
4. Update any host-specific paths or commands
5. Verify all dependencies are available in container

### Example Migration

Before:
```yaml
jobs:
  test:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - run: pytest
```

After:
```yaml
jobs:
  test:
    runs-on: self-hosted
    container:
      image: runner-python:latest
    steps:
      - uses: actions/checkout@v4
      - run: pytest
```

## Support and Resources

- [Docker Desktop Documentation](https://docs.docker.com/desktop/windows/)
- [WSL2 Documentation](https://docs.microsoft.com/en-us/windows/wsl/)
- [GitHub Actions Container Jobs](https://docs.github.com/en/actions/using-jobs/running-jobs-in-a-container)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

## Related Documentation

- [Security Guide](./security.md)
- [Troubleshooting Guide](./troubleshooting.md)
- [Self-Hosted Runner Setup](../README.md)
