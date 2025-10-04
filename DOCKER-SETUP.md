# Docker-Based Python Testing Setup

This guide explains how to set up and use the containerized Python testing environment for your self-hosted GitHub Actions runners.

## 🎯 Why Docker Containers?

**The Problem:** Your workflows were using `actions/setup-python@v5` which requires admin permissions to install Python on the Windows host, causing registry permission errors.

**The Solution:** Pre-built Docker containers with all Python versions (3.9-3.12) already installed. Build once, reuse everywhere!

## 🚀 Quick Start

### Step 1: Build the Multi-Python Image

Run this once to build the container image:

```powershell
# Navigate to ActionRunner directory
cd C:\Code\ActionRunner

# Build the image (takes 10-15 minutes)
.\scripts\build-python-image.ps1
```

This creates a reusable image called `runner-python-multi:latest` with:
- Python 3.9, 3.10, 3.11, 3.12 (all versions pre-installed!)
- PowerShell Core 7+ (pwsh) + Windows PowerShell 5.1
- pytest, pytest-cov, black, flake8, mypy
- Flask, Django, requests
- Git for checkout actions

### Step 2: Verify the Image

```powershell
# Test the image
docker run --rm runner-python-multi:latest

# Should show all Python versions:
# Available Python versions:
# Python 3.9.13
# Python 3.10.x
# Python 3.11.x
# Python 3.12.x
```

### Step 3: Update Your Workflows

Replace workflows that use `actions/setup-python@v5` with containerized versions.

**❌ OLD (Broken - requires admin permissions):**
```yaml
jobs:
  test:
    runs-on: [self-hosted, windows]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5  # ← Fails with registry errors!
        with:
          python-version: 3.10
      - run: pytest
```

**✅ NEW (Works - uses pre-built container):**
```yaml
jobs:
  test:
    runs-on: [self-hosted, windows, docker]
    container:
      image: runner-python-multi:latest  # ← All Python versions included!
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        shell: powershell
        run: C:\Python310\python.exe -m pytest
```

### Step 4: Test Multiple Python Versions

Use a matrix strategy to test all versions:

```yaml
jobs:
  test:
    runs-on: [self-hosted, windows, docker]
    container:
      image: runner-python-multi:latest

    strategy:
      matrix:
        python-version: ['3.9', '3.10', '3.11', '3.12']

    steps:
      - uses: actions/checkout@v4
      - name: Run tests with Python ${{ matrix.python-version }}
        shell: powershell
        run: |
          C:\Python${{ matrix.python-version }}\python.exe -m pytest
```

## 📋 For QiFlow Repository

Copy the template workflow:

```powershell
# Copy template to QiFlow repo
Copy-Item .\.github\workflow-templates\python-tests.yml `
          C:\Path\To\QiFlow\.github\workflows\tests.yml

# Commit and push
cd C:\Path\To\QiFlow
git add .github/workflows/tests.yml
git commit -m "fix: Use containerized Python testing"
git push
```

## 🔧 Advanced Usage

### Rebuild Image (after updates)

```powershell
# Rebuild locally
.\scripts\build-python-image.ps1

# Build and push to GitHub Container Registry
.\scripts\build-python-image.ps1 -Registry "ghcr.io/dakotairsik" -Tag "v1.0"
```

### Add More Dependencies

Edit `docker/Dockerfile.python-multi` and add packages:

```dockerfile
RUN C:\Python312\python.exe -m pip install your-package-here
```

Then rebuild:
```powershell
.\scripts\build-python-image.ps1
```

### Use in Other Repos

The same image works for all Python projects:
- qiflow
- qiflowgo (if it has Python)
- gifdistributor
- Any new Python projects

## 🐛 Troubleshooting

### "Docker is not running"
```powershell
# Start Docker Desktop
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Wait 30 seconds, then retry
.\scripts\build-python-image.ps1
```

### "Container not found" in workflow
The image is only available on the specific runner where you built it. Either:
1. Build on each runner: `.\scripts\build-python-image.ps1`
2. Push to registry and pull from all runners (see Advanced Usage)

### Workflow still failing
- Ensure `runs-on: [self-hosted, windows, docker]` includes `docker` label
- Ensure `container:` section is present
- Remove any `actions/setup-python@v5` steps
- Use `shell: powershell` (not `pwsh`)

## 📚 Related Documentation

- [Docker Isolation Architecture](docs/docker-isolation.md)
- [Python Test Template](.github/workflow-templates/python-tests.yml)
- [Build Script](scripts/build-python-image.ps1)
- [Dockerfile](docker/Dockerfile.python-multi)

## ✅ Success Checklist

- [ ] Docker Desktop installed and running
- [ ] Built `runner-python-multi:latest` image
- [ ] Verified image with `docker run --rm runner-python-multi:latest`
- [ ] Updated workflows to use `container:` instead of `setup-python`
- [ ] Added `docker` to `runs-on` labels
- [ ] Tests passing in containerized environment

---

**Next Steps:**
1. Build the image: `.\scripts\build-python-image.ps1`
2. Update QiFlow workflow using the template
3. Push and test!
