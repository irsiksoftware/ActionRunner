# Dual-Runner Setup: Windows + Linux on One Machine

The ultimate setup - TWO self-hosted runners on a single Windows machine with WSL2!

## 🎯 What You'll Have

```
Your Windows Machine (DESKTOP-02MAEJL)
│
├── Runner 1: Windows Host Runner ✅ (already installed)
│   ├── Name: qiflow-runner
│   ├── Location: C:\actions-runner-qiflow\
│   ├── Service: Windows Service
│   ├── Labels: [self-hosted, windows, docker]
│   ├── Best for: .NET Framework, Unity, Windows-specific
│   └── Limitation: Cannot use container: keyword (must use docker run)
│
└── Runner 2: WSL2 Linux Runner 🆕 (we'll install this)
    ├── Name: linux-runner (or qiflow-linux-runner)
    ├── Location: ~/actions-runner (inside WSL2)
    ├── Service: systemd service (in WSL2)
    ├── Labels: [self-hosted, linux, docker, wsl2]
    ├── Best for: Python, Node, cross-platform, faster builds
    └── Advantage: CAN use container: keyword natively!
```

## 🚀 Quick Start

### Prerequisites Check

```powershell
# 1. Verify WSL2 is installed
wsl --list --verbose

# Should show:
# NAME      STATE           VERSION
# Ubuntu    Running         2

# 2. Verify Docker Desktop is running
docker --version

# 3. Verify Windows runner exists
Get-Service actions.runner.*
```

### One-Command Setup

```powershell
cd C:\Code\ActionRunner

# Get a NEW runner token from GitHub (for the Linux runner)
# Go to: https://github.com/YOUR-ORG/YOUR-REPO/settings/actions/runners
# Click "New self-hosted runner" → Copy token

# Run the setup script
.\scripts\setup-wsl2-runner.ps1 `
  -RepoUrl "https://github.com/DakotaIrsik/QiFlow" `
  -Token "YOUR_NEW_RUNNER_TOKEN" `
  -RunnerName "qiflow-linux-runner"

# Wait 5-10 minutes...
```

The script will:
1. ✅ Verify WSL2 is ready
2. ✅ Install GitHub Actions runner INSIDE WSL2
3. ✅ Configure it as systemd service
4. ✅ Build Linux Python Docker image
5. ✅ Start the runner

## ✅ Verification

### Check Both Runners in GitHub

Go to: `https://github.com/YOUR-ORG/YOUR-REPO/settings/actions/runners`

You should see **TWO runners**, both with green "Idle" status:
- `qiflow-runner` (windows, docker)
- `qiflow-linux-runner` (linux, docker, wsl2)

### Check Windows Runner

```powershell
Get-Service actions.runner.*

# Should show: Running
```

### Check Linux Runner

```powershell
wsl -d Ubuntu sudo systemctl status actions.runner.*

# Should show: active (running)
```

### Test Docker Images

```powershell
# List images (should see both)
docker images

# REPOSITORY                    TAG       SIZE
# runner-python-multi           latest    ~8GB  (Windows container)
# runner-python-multi           latest    ~2GB  (Linux container)
```

## 📝 Using Both Runners in Workflows

Now your workflows can intelligently use the right runner!

### Strategy 1: OS-Specific Jobs

```yaml
name: Multi-Platform Tests

on: [push, pull_request]

jobs:
  test-windows:
    name: Test on Windows
    runs-on: [self-hosted, windows, docker]

    steps:
      - uses: actions/checkout@v4

      # Windows runner: Use docker run (no container: keyword)
      - name: Run tests in Windows container
        shell: powershell
        run: |
          docker run --rm `
            -v "${PWD}:C:\workspace" `
            -w C:\workspace `
            runner-python-multi:latest `
            powershell -c "C:\Python310\python.exe -m pytest tests/"

  test-linux:
    name: Test on Linux
    runs-on: [self-hosted, linux, docker]

    # Linux runner: Can use container: keyword!
    container:
      image: runner-python-multi:latest

    steps:
      - uses: actions/checkout@v4

      - name: Run tests
        run: python3.10 -m pytest tests/
```

### Strategy 2: Matrix with Both Platforms

```yaml
name: Full Coverage Tests

on: [push, pull_request]

jobs:
  test:
    name: ${{ matrix.platform }} - Python ${{ matrix.python-version }}
    runs-on: ${{ matrix.runner }}

    strategy:
      fail-fast: false
      matrix:
        include:
          # Windows tests (using docker run)
          - platform: Windows
            runner: [self-hosted, windows, docker]
            python-version: '3.10'
            python-path: 'C:\Python310\python.exe'

          - platform: Windows
            runner: [self-hosted, windows, docker]
            python-version: '3.12'
            python-path: 'C:\Python312\python.exe'

          # Linux tests (using container keyword)
          - platform: Linux
            runner: [self-hosted, linux, docker]
            python-version: '3.10'
            python-path: 'python3.10'

          - platform: Linux
            runner: [self-hosted, linux, docker]
            python-version: '3.12'
            python-path: 'python3.12'

    # Conditionally use container (only for Linux)
    container: ${{ matrix.platform == 'Linux' && 'runner-python-multi:latest' || '' }}

    steps:
      - uses: actions/checkout@v4

      # Windows path
      - name: Run tests (Windows)
        if: matrix.platform == 'Windows'
        shell: powershell
        run: |
          docker run --rm `
            -v "${PWD}:C:\workspace" `
            -w C:\workspace `
            runner-python-multi:latest `
            powershell -c "${{ matrix.python-path }} -m pytest tests/"

      # Linux path (already in container)
      - name: Run tests (Linux)
        if: matrix.platform == 'Linux'
        run: ${{ matrix.python-path }} -m pytest tests/
```

### Strategy 3: Use Template (Recommended)

Copy the pre-made template:

```powershell
# Copy template to your repo
Copy-Item .\.github\workflow-templates\python-unified-dual-runner.yml `
          C:\Path\To\QiFlow\.github\workflows\tests.yml
```

## 🔧 Managing Your Runners

### View Status of Both

```powershell
# Windows runner
Get-Service actions.runner.*

# Linux runner
wsl -d Ubuntu sudo systemctl status actions.runner.*
```

### Start/Stop Windows Runner

```powershell
# Stop
Stop-Service actions.runner.*

# Start
Start-Service actions.runner.*
```

### Start/Stop Linux Runner

```powershell
# Stop
wsl -d Ubuntu sudo systemctl stop actions.runner.*

# Start
wsl -d Ubuntu sudo systemctl start actions.runner.*

# View logs
wsl -d Ubuntu sudo journalctl -u actions.runner.* -f
```

### Update Linux Runner

```powershell
# Enter WSL2
wsl -d Ubuntu

# Stop runner
sudo systemctl stop actions.runner.*

# Update (follow GitHub's update instructions)
cd ~/actions-runner
# ... update steps ...

# Start runner
sudo systemctl start actions.runner.*

# Exit WSL2
exit
```

## 🎨 Best Practices

### When to Use Each Runner

**Use Windows Runner for:**
- ✅ .NET Framework (not .NET Core/5+)
- ✅ Unity builds
- ✅ Windows-specific APIs
- ✅ Testing Windows behavior
- ⚠️ Limitation: Must use `docker run` commands

**Use Linux Runner for:**
- ✅ Python applications (faster, smaller containers)
- ✅ Node.js/JavaScript
- ✅ .NET Core/5+ (cross-platform)
- ✅ Cross-platform testing
- ✅ Anything needing `container:` keyword

### Performance Tips

1. **Prefer Linux runner when possible:**
   - 4x smaller containers (~2GB vs ~8GB)
   - Faster startup (2-3 sec vs 10-15 sec)
   - Native container support

2. **Use matrix jobs to test both:**
   - Catch platform-specific bugs
   - Validate cross-platform compatibility

3. **Cache Docker images:**
   - Images persist across jobs
   - No need to rebuild every time

## 🐛 Troubleshooting

### Linux Runner Not Showing in GitHub

```powershell
# Check it's running in WSL2
wsl -d Ubuntu sudo systemctl status actions.runner.*

# View logs
wsl -d Ubuntu sudo journalctl -u actions.runner.* -n 50 --no-pager

# Restart WSL2
wsl --shutdown
wsl -d Ubuntu
```

### "Container operations only supported on Linux runners"

This means you're using `container:` keyword on the Windows runner.

**Fix:** Either:
1. Change to Linux runner: `runs-on: [self-hosted, linux, docker]`
2. Use `docker run` instead of `container:` keyword

### Docker Image Not Found

```powershell
# Check images exist
docker images

# If missing, rebuild:
.\scripts\build-python-image.ps1  # Windows image
wsl -d Ubuntu bash -c "cd /mnt/c/Code/ActionRunner && ./scripts/build-python-image-linux.sh"  # Linux image
```

### WSL2 Performance Issues

```powershell
# Restart WSL2
wsl --shutdown

# Limit WSL2 memory (create/edit .wslconfig in your home directory)
# C:\Users\YourName\.wslconfig
# [wsl2]
# memory=8GB
# processors=4
```

## 📊 Monitoring

### Check Which Runner Ran a Job

In GitHub Actions UI:
- Look for the runner name in job logs
- Windows jobs show: "Runner name: 'qiflow-runner'"
- Linux jobs show: "Runner name: 'qiflow-linux-runner'"

### Resource Usage

```powershell
# Windows runner: Task Manager
Get-Process | Where-Object { $_.Name -like "*runner*" }

# Linux runner: Inside WSL2
wsl -d Ubuntu top
wsl -d Ubuntu docker stats
```

## 🎓 Architecture Deep Dive

### How Docker Works with Both Runners

**Windows Runner:**
- Runner service runs on Windows host
- Executes `docker run` commands
- Can run both Windows AND Linux containers (via WSL2 backend)
- Does NOT support `container:` keyword (GitHub limitation)

**Linux Runner:**
- Runner service runs INSIDE WSL2 Ubuntu
- Natively supports `container:` keyword
- Runs Linux containers only
- More efficient for Linux workloads

**Docker Engine:**
- Single Docker Desktop installation
- Shared between Windows host and WSL2
- Same images available to both runners

### Network & File Access

**Windows Runner:**
- Runs on host network
- Full access to Windows filesystem
- Can access network drives

**Linux Runner:**
- Runs in WSL2 network
- Accesses Windows files via /mnt/c/
- Slightly slower file I/O when accessing Windows files

## 📚 Next Steps

- [ ] Run `.\scripts\setup-wsl2-runner.ps1` to install Linux runner
- [ ] Verify both runners appear in GitHub
- [ ] Copy unified workflow template
- [ ] Run a test workflow
- [ ] Monitor performance and adjust as needed

---

**Related Documentation:**
- [Unified Workflow Template](.github/workflow-templates/python-unified-dual-runner.yml)
- [Docker Setup Guide](DOCKER-SETUP.md)
- [Troubleshooting Guide](docs/troubleshooting.md)
