# ActionRunner

Dakota Irsik's self-hosted GitHub Actions runner infrastructure for private projects.

## Overview

This is the configuration and setup for my self-hosted Windows runners that power CI/CD for:
- **QiFlow** - Unity game project
- **LogSmith** - .NET logging library
- **TalkSmith** - React Native communication app
- **Other private repos** - Python tools, experiments, etc.

**Critical**: These runners are for MY private repos only. Never enable for public repositories.

## Runner Label Strategy

Jobs are routed to appropriate runners using labels:

| Label | Purpose | Use For |
|-------|---------|---------|
| `self-hosted` | Base label for all my runners | All jobs |
| `windows` | Windows environment | All jobs (default OS) |
| `unity` | Unity build environment | QiFlow builds |
| `dotnet` | .NET SDK installed | LogSmith, C# projects |
| `python` | Python environment | Scripts, tools, automation |
| `react-native` | React Native setup | TalkSmith builds |
| `gpu` | NVIDIA GPU available | ML training, GPU-accelerated builds |
| `docker` | Docker isolation enabled | Untrusted/experimental code |

**Example workflow label usage:**
```yaml
jobs:
  build:
    runs-on: [self-hosted, windows, unity]
```

## Workflow Examples

### Unity Build (QiFlow)

```yaml
name: Unity Build
on: [push, pull_request]

jobs:
  build-windows:
    runs-on: [self-hosted, windows, unity]
    steps:
      - uses: actions/checkout@v4

      - name: Build Unity Project
        run: |
          & "C:\Program Files\Unity\Hub\Editor\2022.3.10f1\Editor\Unity.exe" `
            -quit -batchmode -nographics `
            -projectPath . `
            -buildWindows64Player build/QiFlow.exe `
            -logFile build/unity.log

      - name: Upload Build
        uses: actions/upload-artifact@v4
        with:
          name: windows-build
          path: build/QiFlow.exe
```

### .NET Library (LogSmith)

```yaml
name: .NET Build and Test
on: [push, pull_request]

jobs:
  build:
    runs-on: [self-hosted, windows, dotnet]
    steps:
      - uses: actions/checkout@v4

      - name: Restore dependencies
        run: dotnet restore

      - name: Build
        run: dotnet build --no-restore --configuration Release

      - name: Test
        run: dotnet test --no-build --configuration Release --verbosity normal

      - name: Pack NuGet
        run: dotnet pack --no-build --configuration Release --output nupkgs/

      - name: Upload Package
        uses: actions/upload-artifact@v4
        with:
          name: nuget-package
          path: nupkgs/*.nupkg
```

### React Native (TalkSmith)

```yaml
name: React Native Build
on: [push, pull_request]

jobs:
  build-android:
    runs-on: [self-hosted, windows, react-native]
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

      - name: Build Android APK
        run: |
          cd android
          .\gradlew.bat assembleRelease

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: android-apk
          path: android/app/build/outputs/apk/release/*.apk
```

### Python Scripts

```yaml
name: Python Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: [self-hosted, windows, python]
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run tests
        run: pytest tests/ --verbose

      - name: Run linting
        run: |
          flake8 src/
          black --check src/
```

### Docker Isolated Execution (Untrusted Code)

```yaml
name: Run in Docker
on: [push, pull_request]

jobs:
  test-untrusted:
    runs-on: [self-hosted, windows, docker]
    container:
      image: actionrunner/python:latest
      options: --cpus 2 --memory 2g
    steps:
      - uses: actions/checkout@v4

      - name: Run tests in isolated container
        run: pytest tests/
```

### GPU-Accelerated Workloads

```yaml
name: ML Training
on: workflow_dispatch

jobs:
  train:
    runs-on: [self-hosted, windows, gpu]
    steps:
      - uses: actions/checkout@v4

      - name: Verify GPU
        run: nvidia-smi

      - name: Train Model
        run: python train.py --use-gpu --epochs 100
```

## Quick Setup

### Initial Runner Installation

```powershell
# 1. Security setup (run as Administrator)
.\config\runner-user-setup.ps1
.\config\apply-firewall-rules.ps1

# 2. Docker setup (recommended)
.\scripts\setup-docker.ps1 -ConfigureGPU -MaxCPUs 8 -MaxMemoryGB 16

# 3. Configure runner for a specific repo
cd C:\actions-runner
.\config.cmd --url https://github.com/DakotaIrsik/YOUR-REPO --token YOUR-TOKEN --runasservice

# 4. Verify
Get-Service actions.runner.* | Select-Object Name, Status
```

### Docker Images Available

Pre-built images for different workloads:
- `actionrunner/unity:latest` - Unity builds
- `actionrunner/dotnet:latest` - .NET projects
- `actionrunner/python:latest` - Python development
- `actionrunner/gpu:latest` - GPU workloads with CUDA

## Security Features

- **Network Isolation**: Firewall rules restrict traffic to GitHub only
- **Service Account**: Runs as `GitHubRunner` user with minimal permissions
- **Docker Isolation**: Container-based execution for untrusted code
- **Audit Logging**: Comprehensive logging to `logs/` directory
- **Token Security**: Short-lived tokens, never committed to repos

## File Structure

```
ActionRunner/
├── config/                     # Security configuration
│   ├── firewall-rules.yaml    # Network isolation rules
│   ├── runner-user-setup.ps1  # Service account creation
│   └── apply-firewall-rules.ps1
├── scripts/                    # Management scripts
│   ├── setup-docker.ps1       # Docker environment setup
│   ├── setup-runner.ps1       # Runner installation
│   ├── collect-logs.ps1       # Log aggregation
│   ├── rotate-logs.ps1        # Log rotation
│   └── analyze-logs.ps1       # Log analysis
├── docker/                     # Container definitions
│   ├── Dockerfile.unity       # Unity build container
│   ├── Dockerfile.dotnet      # .NET build container
│   ├── Dockerfile.python      # Python test container
│   └── Dockerfile.gpu         # GPU-enabled container
├── logs/                       # Audit trail and logs
├── tests/                      # Pester test suite
└── docs/                       # Detailed documentation
    ├── security.md            # Security guide
    ├── docker-isolation.md    # Container setup
    └── logging.md             # Logging system
```

## Maintenance

### Weekly
```powershell
# Review logs
.\scripts\analyze-logs.ps1

# Check runner health
Get-Service actions.runner.*
```

### Monthly
```powershell
# Rotate logs
.\scripts\rotate-logs.ps1

# Update tokens (regenerate in GitHub settings)
# Clean up Docker containers and images
docker system prune -a -f
```

### As Needed
```powershell
# Run full test suite
Invoke-Pester -Path .\tests\

# Update runner version
Stop-Service actions.runner.*
# Download new version from GitHub
Start-Service actions.runner.*
```

## Troubleshooting

**Runner offline?**
```powershell
Get-Service actions.runner.* | Restart-Service
.\scripts\collect-logs.ps1  # Check logs/collected/
```

**Build failing?**
- Check runner has correct labels for your job
- Verify required SDK/tools installed on runner
- Check firewall isn't blocking required connections

**Docker issues?**
```powershell
docker ps -a  # Check container status
docker system prune -f  # Clean up containers
```

## Documentation

- **[docs/security.md](docs/security.md)** - Security risks, best practices, compliance
- **[docs/docker-isolation.md](docs/docker-isolation.md)** - Container isolation setup
- **[docs/logging.md](docs/logging.md)** - Audit trail and monitoring
- **[tests/README.md](tests/README.md)** - Test suite documentation

## Projects Using This Runner

- **QiFlow** - Unity game (labels: unity, windows)
- **LogSmith** - .NET library (labels: dotnet, windows)
- **TalkSmith** - React Native app (labels: react-native, windows)
- Various Python tools and experiments (labels: python, windows)

---

**Last Updated**: 2025-10-03 | Dakota Irsik's Internal Infrastructure