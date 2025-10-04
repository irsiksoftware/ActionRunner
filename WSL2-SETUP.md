# WSL2 + Docker Desktop Setup Guide

You have WSL2 Ubuntu installed via Microsoft Store - perfect! This allows you to run **both Windows AND Linux containers** on the same machine.

## Architecture Overview

```
Your Windows Machine (DESKTOP-02MAEJL)
├── Windows Host
│   ├── GitHub Actions Runner Service (runs on host)
│   ├── Docker Desktop (with WSL2 backend)
│   └── WSL2 Ubuntu (from Microsoft Store)
│
└── When a job runs:
    ├── Runner service receives job from GitHub
    ├── Starts Docker container (Windows or Linux)
    ├── Job executes INSIDE container (isolated)
    └── Container destroyed after job completes
```

**Key Points:**
- ✅ Runner service runs on Windows host (already installed)
- ✅ Jobs run in isolated Docker containers
- ✅ Can run both Windows AND Linux containers
- ✅ WSL2 provides Linux container support

---

## Current Status

Based on your setup:
- ✅ WSL2 Ubuntu installed (Microsoft Store)
- ✅ Windows runner service running (qiflow-runner)
- ✅ Docker Desktop installed (you installed it yesterday)
- 🔄 Need to build Docker images

---

## Step 1: Verify Docker Desktop WSL2 Integration

1. **Open Docker Desktop**
2. **Go to Settings → Resources → WSL Integration**
3. **Enable integration with Ubuntu:**
   - Toggle on "Ubuntu" (your Microsoft Store distro)
   - Click "Apply & Restart"

This allows Docker commands to work inside WSL2 Ubuntu.

---

## Step 2: Verify WSL2 Setup

Open PowerShell and verify:

```powershell
# Check WSL2 distros
wsl --list --verbose

# Should show:
# NAME      STATE           VERSION
# Ubuntu    Running         2
```

If Ubuntu shows VERSION 1, upgrade it:
```powershell
wsl --set-version Ubuntu 2
```

---

## Step 3: Build Docker Images

You can build images from **either** Windows PowerShell or WSL2 Ubuntu (both talk to same Docker engine).

### Option A: Build from Windows PowerShell (Easier)

```powershell
cd C:\Code\ActionRunner

# Build Windows Python container (takes 10-15 minutes)
.\scripts\build-python-image.ps1

# Build Linux Python container (takes 5-10 minutes)
docker build -t runner-python-multi-linux:latest -f docker\Dockerfile.python-multi-linux docker\
```

### Option B: Build from WSL2 Ubuntu

```bash
# Open WSL2 Ubuntu
wsl

# Navigate to repo (Windows drives are mounted under /mnt/)
cd /mnt/c/Code/ActionRunner

# Build Linux Python container
./scripts/build-python-image-linux.sh
```

---

## Step 4: Verify Images

```powershell
# List all images
docker images

# Should show:
# REPOSITORY                    TAG       SIZE
# runner-python-multi           latest    ~8GB  (Windows)
# runner-python-multi-linux     latest    ~2GB  (Linux)
```

Test them:

```powershell
# Test Windows container
docker run --rm runner-python-multi:latest

# Test Linux container
docker run --rm runner-python-multi-linux:latest
```

---

## Step 5: Update Workflows to Use Containers

Your workflows should now use containers. Here's what changes:

### ❌ OLD (Broken - tries to install Python on host):
```yaml
jobs:
  test:
    runs-on: [self-hosted, windows]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5  # ← FAILS with registry errors
        with:
          python-version: '3.10'
      - run: pytest
```

### ✅ NEW (Works - uses pre-built container):
```yaml
jobs:
  test-windows:
    runs-on: [self-hosted, windows, docker]
    container:
      image: runner-python-multi:latest  # ← Windows container
    steps:
      - uses: actions/checkout@v4
      - run: C:\Python310\python.exe -m pytest

  test-linux:
    runs-on: [self-hosted, windows, docker]
    container:
      image: runner-python-multi-linux:latest  # ← Linux container
    steps:
      - uses: actions/checkout@v4
      - run: python3.10 -m pytest
```

**Note:** Even though the runner is on Windows, you can run Linux containers because Docker Desktop uses WSL2!

---

## Step 6: Test the Setup

Create a test workflow in QiFlow:

```yaml
name: Test Containerized Setup

on: [workflow_dispatch]

jobs:
  test-windows-container:
    runs-on: [self-hosted, windows, docker]
    container:
      image: runner-python-multi:latest
    steps:
      - run: |
          Write-Host "Testing Windows container"
          python --version
          Get-ComputerName

  test-linux-container:
    runs-on: [self-hosted, windows, docker]
    container:
      image: runner-python-multi-linux:latest
    steps:
      - run: |
          echo "Testing Linux container"
          python3.12 --version
          uname -a
```

Run it manually from GitHub Actions tab → "Run workflow"

---

## Understanding Container Platform Selection

Docker Desktop automatically chooses the right container type based on the image:

- **Windows base image** (`FROM mcr.microsoft.com/windows/servercore`) → Windows container
- **Linux base image** (`FROM ubuntu`) → Linux container (runs in WSL2)

Your workflow specifies which image to use, and Docker handles the rest!

---

## Common Questions

### Q: Do I need a separate Linux server?
**A:** No! Your Windows machine with WSL2 can run both Windows and Linux containers.

### Q: Which container should I use?
**A:**
- **Linux containers** are smaller, faster, and recommended for most Python work
- **Windows containers** needed for .NET Framework, Unity, or Windows-specific tools

### Q: Can I run both at the same time?
**A:** Yes! One job can use Windows container, another can use Linux container, both running on your Windows machine.

### Q: Do containers slow things down?
**A:** No! Containers are faster than installing Python each time. They start in seconds.

---

## Troubleshooting

### "Cannot start container" error

Check Docker Desktop is running:
```powershell
docker info
```

### "Image not found" error

Verify images are built:
```powershell
docker images
```

If missing, rebuild:
```powershell
.\scripts\build-python-image.ps1
```

### Linux container fails on Windows runner

1. Check Docker Desktop settings → WSL2 integration enabled
2. Verify WSL2: `wsl --list --verbose` (should show VERSION 2)
3. Restart Docker Desktop

### "The system cannot find the path specified"

You're mixing Windows/Linux paths. Remember:
- **Windows container:** `C:\Python310\python.exe`
- **Linux container:** `python3.10` or `/usr/bin/python3.10`

---

## Next Steps

1. ✅ Build both Docker images (Windows + Linux)
2. ✅ Copy workflow template to QiFlow
3. ✅ Remove `actions/setup-python@v5` from workflows
4. ✅ Test with both Windows and Linux containers
5. ✅ Enjoy fast, isolated, reproducible builds!

---

## Performance Tips

**Use Linux containers when possible:**
- 4x smaller than Windows containers (~2GB vs ~8GB)
- Faster startup (2-3 seconds vs 10-15 seconds)
- More efficient resource usage

**Reserve Windows containers for:**
- .NET Framework (not .NET Core/5+)
- Unity builds
- Windows-specific APIs
- PowerShell scripts that require Windows

---

**Related Docs:**
- [DOCKER-SETUP.md](DOCKER-SETUP.md) - Windows container details
- [Multi-platform workflow template](.github/workflow-templates/python-multiplatform-tests.yml)
- [Docker Desktop WSL2 Backend](https://docs.docker.com/desktop/windows/wsl/)
