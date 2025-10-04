# Linux Self-Hosted Runner Setup

Complete guide for setting up self-hosted GitHub Actions runners on Linux with Docker containerization.

## 📋 Prerequisites

- **Linux Server/VM** running Ubuntu 22.04 or later (Debian-based)
- **Root/sudo access**
- **Minimum specs:**
  - 4 CPU cores (8+ recommended)
  - 8GB RAM (16GB+ recommended)
  - 50GB disk space (100GB+ recommended)
- **GitHub repository** with admin access
- **Runner registration token** (get from repo Settings → Actions → Runners)

## 🚀 Quick Start (Automated)

The easiest way - one script does everything:

```bash
# 1. Clone ActionRunner repo on your Linux server
git clone https://github.com/DakotaIrsik/ActionRunner.git
cd ActionRunner

# 2. Get runner token from GitHub
# Go to: https://github.com/YOUR-ORG/YOUR-REPO/settings/actions/runners
# Click "New self-hosted runner" → Copy the token

# 3. Run setup script (installs Docker, runner, builds image)
sudo ./scripts/setup-linux-runner.sh \
  --repo-url https://github.com/DakotaIrsik/YOUR-REPO \
  --token YOUR_RUNNER_TOKEN \
  --name "linux-runner" \
  --labels "self-hosted,linux,docker"

# That's it! Wait 10-15 minutes for everything to install
```

The script will:
1. ✅ Install Docker
2. ✅ Create runner user
3. ✅ Download & configure GitHub Actions runner
4. ✅ Install as systemd service
5. ✅ Build `runner-python-multi:latest` Docker image

## 📦 What Gets Installed

### Docker Image: `runner-python-multi:latest`

Includes:
- **Python 3.9, 3.10, 3.11, 3.12** (all versions pre-installed!)
- **Common tools:** pytest, pytest-cov, black, flake8, mypy
- **Web frameworks:** Flask, Django, requests
- **Git** for checkout actions
- **Ubuntu 22.04** base

### Runner Service

- Runs as systemd service (auto-starts on boot)
- Isolated user account (`runner`)
- Labels: `self-hosted`, `linux`, `docker`

## 🔧 Manual Setup (Step-by-Step)

If you prefer manual installation:

### Step 1: Install Docker

```bash
# Update packages
sudo apt-get update

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Start Docker
sudo systemctl start docker
sudo systemctl enable docker

# Verify
docker --version
```

### Step 2: Create Runner User

```bash
# Create user
sudo useradd -m -s /bin/bash runner

# Add to docker group
sudo usermod -aG docker runner
```

### Step 3: Install GitHub Actions Runner

```bash
# Create runner directory
mkdir -p ~/actions-runner
cd ~/actions-runner

# Download runner (check for latest version)
RUNNER_VERSION="2.311.0"
curl -o actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
  -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Extract
tar xzf actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
rm actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Configure (replace with your values)
./config.sh \
  --url https://github.com/YOUR-ORG/YOUR-REPO \
  --token YOUR_TOKEN \
  --name "linux-runner" \
  --labels "self-hosted,linux,docker" \
  --unattended

# Install as service
sudo ./svc.sh install runner
sudo ./svc.sh start
```

### Step 4: Build Python Container

```bash
# Clone ActionRunner repo
cd ~
git clone https://github.com/DakotaIrsik/ActionRunner.git
cd ActionRunner

# Build image
./scripts/build-python-image-linux.sh

# Verify
docker run --rm runner-python-multi:latest
```

## ✅ Verification

### Check Runner Status

```bash
# Check service
sudo systemctl status actions.runner.*

# View logs
sudo journalctl -u actions.runner.* -f
```

### Check in GitHub

Go to: `https://github.com/YOUR-ORG/YOUR-REPO/settings/actions/runners`

You should see your runner with status **Idle** (green circle).

### Test Docker Image

```bash
# Run verification
docker run --rm runner-python-multi:latest

# Output should show:
# === Python Multi-Version Container (Linux) ===
# Available Python versions:
# Python 3.9.x
# Python 3.10.x
# Python 3.11.x
# Python 3.12.x
```

## 📝 Using in Workflows

Update your workflows to use the Linux runner:

```yaml
name: Python Tests

on: [push, pull_request]

jobs:
  test-linux:
    runs-on: [self-hosted, linux, docker]  # ← Uses your Linux runner
    container:
      image: runner-python-multi:latest     # ← Uses pre-built container

    strategy:
      matrix:
        python-version: ['3.9', '3.10', '3.11', '3.12']

    steps:
      - uses: actions/checkout@v4

      - name: Run tests with Python ${{ matrix.python-version }}
        run: python${{ matrix.python-version }} -m pytest tests/
```

## 🔄 Maintenance

### Update Runner

```bash
cd ~/actions-runner

# Stop service
sudo ./svc.sh stop

# Update (download new version, reconfigure)
# See GitHub docs for update steps

# Start service
sudo ./svc.sh start
```

### Rebuild Docker Image

```bash
cd ~/ActionRunner

# Pull latest Dockerfile changes
git pull

# Rebuild
./scripts/build-python-image-linux.sh
```

### View Logs

```bash
# Runner service logs
sudo journalctl -u actions.runner.* -f

# Docker logs
docker ps                          # Get container ID
docker logs -f <container-id>
```

### Cleanup Docker

```bash
# Remove stopped containers
docker container prune -f

# Remove unused images
docker image prune -a -f

# Check disk usage
docker system df
```

## 🐛 Troubleshooting

### Runner Not Showing in GitHub

1. Check service status: `sudo systemctl status actions.runner.*`
2. View logs: `sudo journalctl -u actions.runner.* --no-pager -n 50`
3. Verify network connectivity to github.com
4. Check token hasn't expired (regenerate if needed)

### Docker Not Working

```bash
# Restart Docker
sudo systemctl restart docker

# Check Docker status
sudo systemctl status docker

# Test Docker
docker run hello-world
```

### Container Build Fails

```bash
# Clear Docker cache
docker builder prune -a

# Check disk space
df -h

# Try building with verbose output
docker build --no-cache --progress=plain -t runner-python-multi:latest -f docker/Dockerfile.python-multi-linux docker/
```

### Permission Errors

```bash
# Ensure runner user is in docker group
sudo usermod -aG docker runner

# Restart Docker
sudo systemctl restart docker

# Re-login or reboot for group changes to take effect
```

## 🔒 Security Notes

- Runner runs as non-root user (`runner`)
- All jobs execute in isolated Docker containers
- Containers are ephemeral (destroyed after each job)
- Use container isolation for untrusted code
- Keep Docker and runner updated

## 🌐 Multi-Platform Setup

You now have both Windows and Linux runners! Use matrix strategy:

```yaml
jobs:
  test:
    strategy:
      matrix:
        os:
          - runs-on: [self-hosted, windows, docker]
            image: runner-python-multi:latest
          - runs-on: [self-hosted, linux, docker]
            image: runner-python-multi:latest
        python-version: ['3.9', '3.10', '3.11', '3.12']

    runs-on: ${{ matrix.os.runs-on }}
    container:
      image: ${{ matrix.os.image }}
```

## 📚 Next Steps

- [ ] Set up monitoring (see `docs/monitoring.md`)
- [ ] Configure automatic cleanup (`cron` jobs)
- [ ] Set up log rotation
- [ ] Add more runners for parallel jobs
- [ ] Configure firewall rules

## 🍎 macOS Runners

For macOS (required for iOS builds):

1. **Hardware Required:** Actual Mac Mini or Mac Studio
2. **Cannot use VMs** (Apple licensing restrictions for CI)
3. Setup is similar but uses macOS-specific steps
4. Contact for macOS runner setup guide

---

**Related Documentation:**
- [Windows Setup](DOCKER-SETUP.md)
- [Docker Isolation](docs/docker-isolation.md)
- [Workflow Templates](.github/workflow-templates/)
