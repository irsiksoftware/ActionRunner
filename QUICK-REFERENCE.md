# Quick Reference - Dual Runner Setup

Your unified self-hosted GitHub Actions infrastructure cheat sheet!

## 📋 Your Current Architecture

```
Windows Machine (DESKTOP-02MAEJL)
├── Windows Runner (qiflow-runner)
│   └── Labels: [self-hosted, windows, docker]
└── Linux Runner (qiflow-linux-runner) ← NEW!
    └── Labels: [self-hosted, linux, docker, wsl2]
```

---

## 🚀 Setup Commands

### Install Linux Runner (One-Time)

```powershell
cd C:\Code\ActionRunner

# Get token from: https://github.com/YOUR-ORG/YOUR-REPO/settings/actions/runners
.\scripts\setup-wsl2-runner.ps1 `
  -RepoUrl "https://github.com/DakotaIrsik/QiFlow" `
  -Token "YOUR_RUNNER_TOKEN" `
  -RunnerName "qiflow-linux-runner"
```

### Build Docker Images (One-Time)

```powershell
# Windows Python image (~8GB, 10-15 min)
.\scripts\build-python-image.ps1

# Linux Python image (~2GB, 5-10 min) - built automatically during setup
# Or rebuild manually:
wsl -d Ubuntu bash -c "cd /mnt/c/Code/ActionRunner && ./scripts/build-python-image-linux.sh"
```

---

## 🎮 Managing Runners

### Check Status

```powershell
# Both runners
.\scripts\manage-runners.ps1 -Action status

# Windows only
.\scripts\manage-runners.ps1 -Action status -Runner windows

# Linux only
.\scripts\manage-runners.ps1 -Action status -Runner linux
```

### Start/Stop/Restart

```powershell
# Stop both
.\scripts\manage-runners.ps1 -Action stop

# Start both
.\scripts\manage-runners.ps1 -Action start

# Restart both
.\scripts\manage-runners.ps1 -Action restart

# Control individual runners
.\scripts\manage-runners.ps1 -Action stop -Runner linux
.\scripts\manage-runners.ps1 -Action start -Runner windows
```

### View Logs

```powershell
# Linux runner logs (last 50 lines)
.\scripts\manage-runners.ps1 -Action logs -Runner linux

# Linux runner logs (follow in real-time)
.\scripts\manage-runners.ps1 -Action logs -Runner linux -Follow

# Windows runner logs
.\scripts\manage-runners.ps1 -Action logs -Runner windows
```

---

## 📝 Workflow Examples

### Linux Runner (Recommended for Python)

```yaml
jobs:
  test:
    runs-on: [self-hosted, linux, docker, wsl2]

    container:  # ← Native container support!
      image: runner-python-multi:latest

    steps:
      - uses: actions/checkout@v4
      - run: python3.10 -m pytest tests/
```

### Windows Runner

```yaml
jobs:
  test:
    runs-on: [self-hosted, windows, docker]

    # NO container: keyword (not supported on Windows)

    steps:
      - uses: actions/checkout@v4

      - name: Run in container
        shell: powershell
        run: |
          docker run --rm `
            -v "${PWD}:C:\workspace" `
            -w C:\workspace `
            runner-python-multi:latest `
            powershell -c "C:\Python310\python.exe -m pytest tests/"
```

### Both Runners (Cross-Platform)

Use the unified template:

```powershell
Copy-Item .\.github\workflow-templates\python-unified-dual-runner.yml `
          C:\Path\To\QiFlow\.github\workflows\tests.yml
```

---

## 🔍 Troubleshooting

### "Container operations only supported on Linux runners"

**Problem:** Using `container:` keyword on Windows runner

**Fix:** Use Linux runner instead:
```yaml
runs-on: [self-hosted, linux, docker, wsl2]  # ← Change this
container:
  image: runner-python-multi:latest
```

### Runner Not Showing in GitHub

```powershell
# Check if running
.\scripts\manage-runners.ps1 -Action status

# Restart if needed
.\scripts\manage-runners.ps1 -Action restart

# View logs
.\scripts\manage-runners.ps1 -Action logs -Follow
```

### Docker Image Not Found

```powershell
# List images
docker images

# Rebuild if missing
.\scripts\build-python-image.ps1  # Windows
wsl -d Ubuntu bash -c "cd /mnt/c/Code/ActionRunner && ./scripts/build-python-image-linux.sh"  # Linux
```

### WSL2 Not Working

```powershell
# Restart WSL2
wsl --shutdown
wsl -d Ubuntu

# Check version
wsl --list --verbose
# Should show VERSION 2

# Upgrade if needed
wsl --set-version Ubuntu 2
```

---

## 📊 Quick Decisions

### Which Runner Should I Use?

**Use Linux Runner for:**
- ✅ Python applications (4x smaller containers)
- ✅ Node.js/JavaScript
- ✅ .NET Core/5+ (cross-platform)
- ✅ Most CI/CD tasks
- ✅ When you need `container:` keyword

**Use Windows Runner for:**
- ✅ .NET Framework (not Core)
- ✅ Unity builds
- ✅ Windows-specific APIs
- ✅ Testing Windows behavior

**Use Both (Matrix):**
- ✅ Cross-platform validation
- ✅ Catching platform-specific bugs

---

## 🎯 Common Tasks

### Update Workflow to Use Containers

**Before (Broken):**
```yaml
steps:
  - uses: actions/setup-python@v5  # ← FAILS
    with:
      python-version: '3.10'
```

**After (Working - Linux):**
```yaml
runs-on: [self-hosted, linux, docker, wsl2]
container:
  image: runner-python-multi:latest
steps:
  - run: python3.10 -m pytest
```

**After (Working - Windows):**
```yaml
runs-on: [self-hosted, windows, docker]
steps:
  - shell: powershell
    run: |
      docker run --rm `
        -v "${PWD}:C:\workspace" `
        -w C:\workspace `
        runner-python-multi:latest `
        powershell -c "C:\Python310\python.exe -m pytest"
```

### Add New Python Package to Container

1. Edit Dockerfile:
   - Windows: `docker\Dockerfile.python-multi`
   - Linux: `docker\Dockerfile.python-multi-linux`

2. Add package to RUN command:
   ```dockerfile
   RUN python3.12 -m pip install your-package
   ```

3. Rebuild:
   ```powershell
   .\scripts\build-python-image.ps1
   ```

### Check GitHub for Active Runners

Go to: `https://github.com/YOUR-ORG/YOUR-REPO/settings/actions/runners`

Should see both with green "Idle" status:
- qiflow-runner
- qiflow-linux-runner

---

## 📚 Full Documentation

- **[WSL2-DUAL-RUNNER-SETUP.md](WSL2-DUAL-RUNNER-SETUP.md)** - Complete setup guide
- **[Unified Workflow Template](.github/workflow-templates/python-unified-dual-runner.yml)** - Copy this!
- **[DOCKER-SETUP.md](DOCKER-SETUP.md)** - Windows container details
- **[docs/docker-isolation.md](docs/docker-isolation.md)** - Architecture overview

---

## 💡 Pro Tips

1. **Default to Linux runner** - It's faster and has better container support
2. **Test on both platforms** - Use matrix jobs to catch platform bugs
3. **Keep images updated** - Rebuild monthly or when adding dependencies
4. **Monitor resource usage** - WSL2 can use a lot of RAM (configure `.wslconfig`)
5. **Use unified template** - Handles both runners automatically

---

**Need help?** Check [WSL2-DUAL-RUNNER-SETUP.md](WSL2-DUAL-RUNNER-SETUP.md) for troubleshooting
