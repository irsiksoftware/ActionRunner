# Runner Installation Guide

This guide provides step-by-step instructions for installing and configuring GitHub Actions self-hosted runners.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation Methods](#installation-methods)
  - [Windows Installation](#windows-installation)
  - [Linux Installation](#linux-installation)
  - [macOS Installation](#macos-installation)
- [Configuration Options](#configuration-options)
- [Post-Installation Setup](#post-installation-setup)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before installing a self-hosted runner, ensure your system meets the following requirements:

### Hardware Requirements

| Component | Minimum | Recommended | Notes |
|-----------|---------|-------------|-------|
| **CPU** | 4 cores | 16+ cores | Unity builds and parallel jobs benefit from more cores |
| **RAM** | 8GB | 64GB | Unity (16GB), AI models (16GB), Docker containers |
| **GPU** | N/A | NVIDIA RTX 4070 Ti+ (16GB VRAM) | Required for AI/ML workloads (TalkSmith, Stable Diffusion) |
| **Storage** | 50GB free | 2TB NVMe SSD | Unity projects (100GB each), build cache, AI models |
| **Network** | 100 Mbps | 1 Gbps wired | Fast Git clone, Docker pulls, artifact uploads |

See [docs/hardware-specs.md](hardware-specs.md) for detailed hardware recommendations.

### Software Requirements

**Windows:**
- Windows 10 (version 1803+) or Windows 11
- Windows Server 2019 or later
- PowerShell 5.1 or later
- Git for Windows
- .NET SDK 6.0+ (for .NET workloads)

**Linux:**
- Ubuntu 20.04+, RHEL 8+, or compatible distribution
- Bash 4.0+
- Git
- curl, tar
- sudo access (for service installation)

**macOS:**
- macOS 11.0+ (Big Sur or later)
- Bash 4.0+
- Git
- Xcode Command Line Tools

### GitHub Requirements

- GitHub Personal Access Token (PAT) with appropriate permissions:
  - **Organization-level runner:** `admin:org` scope
  - **Repository-level runner:** `repo` scope
- Access to organization or repository settings

## Installation Methods

### Windows Installation

#### Quick Start

1. **Open PowerShell as Administrator** (if installing as service)

2. **Download the installation script:**
   ```powershell
   cd C:\Code\ActionRunner
   ```

3. **Run the installation script:**
   ```powershell
   .\scripts\install-runner.ps1 `
     -OrgOrRepo "YourOrganization" `
     -Token "ghp_YourTokenHere" `
     -IsOrg `
     -InstallService
   ```

#### Installation Parameters

```powershell
# Organization-level runner with service
.\scripts\install-runner.ps1 `
  -OrgOrRepo "myorg" `
  -Token "ghp_xxx" `
  -IsOrg `
  -InstallService

# Repository-level runner without service
.\scripts\install-runner.ps1 `
  -OrgOrRepo "owner/repo" `
  -Token "ghp_xxx"

# Custom configuration
.\scripts\install-runner.ps1 `
  -OrgOrRepo "myorg" `
  -Token "ghp_xxx" `
  -IsOrg `
  -RunnerName "gpu-runner-01" `
  -Labels "self-hosted,windows,gpu-cuda,unity" `
  -WorkFolder "D:\actions-runner" `
  -CacheFolder "D:\runner-cache" `
  -InstallService
```

#### Parameter Reference

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `-OrgOrRepo` | Yes | - | Organization name or `owner/repo` |
| `-Token` | Yes | - | GitHub PAT with admin:org or repo scope |
| `-RunnerName` | No | Computer name | Custom name for the runner |
| `-Labels` | No | See below | Comma-separated runner labels |
| `-WorkFolder` | No | `C:\actions-runner` | Runner installation directory |
| `-CacheFolder` | No | `C:\actions-runner-cache` | Build artifacts cache location |
| `-IsOrg` | No | `false` | Organization-level runner (recommended) |
| `-InstallService` | No | `false` | Install as Windows service |
| `-SkipPrerequisites` | No | `false` | Skip prerequisites check |
| `-SkipFirewall` | No | `false` | Skip firewall configuration |

**Default Labels (Windows):** `self-hosted,gpu-cuda,unity,dotnet,python,windows`

#### What the Script Does

1. **Prerequisites Validation:**
   - Checks PowerShell version (5.1+)
   - Verifies OS version (Windows 10/11, Server 2019+)
   - Confirms Git installation
   - Validates available disk space (50GB+ required)
   - Checks RAM (8GB minimum, 32GB+ recommended)
   - Tests internet connectivity to GitHub

2. **Runner Installation:**
   - Creates work and cache directories
   - Downloads latest GitHub Actions runner
   - Extracts runner package
   - Verifies installation integrity

3. **Runner Configuration:**
   - Obtains registration token from GitHub API
   - Configures runner with specified labels
   - Sets up working directory

4. **Service Installation (Optional):**
   - Installs runner as Windows service
   - Configures automatic startup
   - Starts the service

5. **Firewall Configuration:**
   - Creates outbound HTTPS rule for GitHub
   - Configures IP address restrictions

### Linux Installation

#### Quick Start

1. **Clone the repository or download the script:**
   ```bash
   cd ~/ActionRunner
   chmod +x scripts/install-runner.sh
   ```

2. **Run the installation script:**
   ```bash
   # Organization-level runner with service
   sudo ./scripts/install-runner.sh \
     --org-or-repo "myorg" \
     --token "ghp_xxx" \
     --is-org \
     --install-service

   # Repository-level runner without service
   ./scripts/install-runner.sh \
     --org-or-repo "owner/repo" \
     --token "ghp_xxx"
   ```

#### Installation Parameters

```bash
# Custom configuration
./scripts/install-runner.sh \
  --org-or-repo "myorg" \
  --token "ghp_xxx" \
  --is-org \
  --runner-name "linux-builder-01" \
  --labels "self-hosted,linux,docker,python" \
  --work-folder "$HOME/actions-runner" \
  --cache-folder "$HOME/runner-cache" \
  --install-service
```

#### Parameter Reference

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--org-or-repo` | Yes | - | Organization name or `owner/repo` |
| `--token` | Yes | - | GitHub PAT with admin:org or repo scope |
| `--runner-name` | No | Hostname | Custom name for the runner |
| `--labels` | No | See below | Comma-separated runner labels |
| `--work-folder` | No | `~/actions-runner` | Runner installation directory |
| `--cache-folder` | No | `~/actions-runner-cache` | Build artifacts cache location |
| `--is-org` | No | false | Organization-level runner |
| `--install-service` | No | false | Install as systemd service |
| `--skip-prerequisites` | No | false | Skip prerequisites check |
| `--skip-firewall` | No | false | Skip firewall configuration |
| `--help` | No | - | Show help message |

**Default Labels (Linux):** `self-hosted,linux,dotnet,python,docker`

### macOS Installation

Installation on macOS is similar to Linux, using the same `install-runner.sh` script:

```bash
# Organization-level runner
./scripts/install-runner.sh \
  --org-or-repo "myorg" \
  --token "ghp_xxx" \
  --is-org \
  --install-service

# Note: macOS uses launchd instead of systemd for services
```

**Default Labels (macOS):** `self-hosted,macos,dotnet,python,docker`

## Configuration Options

### Runner Labels

Labels determine which workflows can use your runner. Configure labels based on your workload:

| Label | Use Case | Recommended For |
|-------|----------|-----------------|
| `self-hosted` | Auto-added to all self-hosted runners | All runners |
| `windows` / `linux` / `macos` | Operating system | Auto-detected |
| `gpu-cuda` | GPU-accelerated workloads | TalkSmith, Stable Diffusion, ML models |
| `unity` | Unity game builds | LogSmith, CandyRush, NeonLadder |
| `dotnet` | .NET compilation | WebAPITemplate, Mercury, ARKPlugin |
| `python` | Python projects | QiFlow, GIFDistributor |
| `docker` | Docker isolation | Container-based builds |
| `react-native` | React Native/mobile | QiFlowGo |

**Example workflow usage:**
```yaml
jobs:
  build-unity:
    runs-on: [self-hosted, windows, unity, gpu-cuda]

  test-python:
    runs-on: [self-hosted, linux, python, docker]

  build-dotnet:
    runs-on: [self-hosted, windows, dotnet]
```

### Organization vs Repository Runners

**Organization-level runners** (recommended):
- ✅ Can be used by all repositories in the organization
- ✅ Centralized management
- ✅ Better resource utilization
- ✅ Easier scaling
- ❌ Requires `admin:org` scope

**Repository-level runners:**
- ✅ Isolated to specific repository
- ✅ Simpler permissions (`repo` scope)
- ❌ Cannot be shared across repositories
- ❌ More runners to manage

**Recommendation:** Use organization-level runners for better flexibility and resource sharing.

### Service Installation

Installing the runner as a system service provides:
- ✅ Automatic startup on boot
- ✅ Automatic restart on failure
- ✅ Background execution
- ✅ Better reliability

**Without service installation:**
- Manual start required: `.\run.cmd` (Windows) or `./run.sh` (Linux/macOS)
- Runner stops when terminal closes
- Useful for testing or temporary runners

## Post-Installation Setup

### 1. Verify Runner Registration

Visit your GitHub organization or repository settings:
- **Organization:** `https://github.com/ORG_NAME/settings/actions/runners`
- **Repository:** `https://github.com/OWNER/REPO/settings/actions/runners`

Look for your runner in the list with a green "Idle" status.

### 2. Configure Firewall Rules

**Windows (automatically configured by script):**
The installation script creates a firewall rule for outbound HTTPS to GitHub.

**Manual configuration (if needed):**
```powershell
.\scripts\apply-firewall-rules.ps1
```

**Linux (manual configuration):**
```bash
# Using ufw
sudo ufw allow out 443/tcp

# Using iptables
sudo iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
```

See [docs/troubleshooting.md](troubleshooting.md) for firewall details.

### 3. Set Up Workspace Cleanup

Automate workspace cleanup to prevent disk space issues:

**Windows (Task Scheduler):**
```powershell
# Run weekly cleanup
schtasks /create /tn "Runner Workspace Cleanup" /tr "powershell.exe -File C:\Code\ActionRunner\scripts\cleanup-workspace.ps1" /sc weekly /d SUN /st 02:00 /ru SYSTEM
```

**Linux (cron):**
```bash
# Add to crontab (weekly on Sunday at 2 AM)
0 2 * * 0 /home/runner/ActionRunner/scripts/cleanup-workspace.sh
```

### 4. Set Up Log Rotation

**Windows:**
```powershell
.\scripts\rotate-logs.ps1 -MaxAgeDays 30 -MaxSizeMB 500
```

**Linux:**
```bash
# Add to /etc/logrotate.d/actions-runner
~/actions-runner/_diag/*.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
}
```

### 5. Configure Health Monitoring

Set up periodic health checks:

**Windows:**
```powershell
# Schedule health check every 6 hours
schtasks /create /tn "Runner Health Check" /tr "powershell.exe -File C:\Code\ActionRunner\scripts\runner-health-check.ps1" /sc hourly /mo 6
```

See [docs/troubleshooting.md](troubleshooting.md) for health monitoring details.

### 6. Update Workflows

Update your GitHub Actions workflows to use the self-hosted runner:

```yaml
name: Build and Test

on: [push, pull_request]

jobs:
  build:
    runs-on: [self-hosted, windows, dotnet]

    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v3
        with:
          dotnet-version: '8.0.x'

      - name: Build
        run: dotnet build

      - name: Test
        run: dotnet test
```

## Verification

### Check Runner Status

**Windows:**
```powershell
# Service status
Get-Service -Name "actions.runner.*"

# Runner logs
Get-Content "C:\actions-runner\_diag\Runner_*.log" -Tail 50
```

**Linux:**
```bash
# Service status
sudo systemctl status actions.runner.*

# Runner logs
tail -f ~/actions-runner/_diag/Runner_*.log
```

### Test Runner

Create a simple workflow to test the runner:

```yaml
name: Test Self-Hosted Runner

on: workflow_dispatch

jobs:
  test:
    runs-on: [self-hosted, windows]  # or [self-hosted, linux]

    steps:
      - name: Print runner info
        run: |
          echo "Runner name: $env:RUNNER_NAME"
          echo "Runner OS: $env:RUNNER_OS"
          echo "Working directory: $(pwd)"

      - name: Check Git
        run: git --version

      - name: Check disk space
        run: df -h  # Linux/macOS
        # or: Get-PSDrive C  # Windows
```

Manually trigger the workflow from GitHub Actions tab and verify it runs successfully.

## Troubleshooting

### Common Issues

#### Runner Not Appearing in GitHub

**Symptoms:** Runner doesn't show in GitHub settings after installation.

**Solutions:**
1. Check registration token validity (tokens expire after 1 hour)
2. Verify GitHub PAT permissions:
   - Organization runners: `admin:org` scope
   - Repository runners: `repo` scope
3. Check network connectivity to GitHub
4. Review runner logs for errors:
   ```powershell
   # Windows
   Get-Content "C:\actions-runner\_diag\Runner_*.log" -Tail 100
   ```
   ```bash
   # Linux/macOS
   tail -100 ~/actions-runner/_diag/Runner_*.log
   ```

#### Service Not Starting

**Symptoms:** Runner service fails to start.

**Solutions:**
1. Check service status:
   ```powershell
   # Windows
   Get-Service -Name "actions.runner.*" | Format-List *
   ```
   ```bash
   # Linux
   sudo systemctl status actions.runner.* --no-pager -l
   ```
2. Check service logs:
   ```bash
   # Linux
   sudo journalctl -u actions.runner.* -n 100
   ```
3. Verify service user permissions
4. Try running manually first: `.\run.cmd` or `./run.sh`

#### Insufficient Disk Space

**Symptoms:** Jobs fail with disk space errors.

**Solutions:**
1. Clean up workspace:
   ```powershell
   # Windows
   .\scripts\cleanup-workspace.ps1 -Force
   ```
2. Increase disk space allocation
3. Set up automatic cleanup (see Post-Installation Setup)
4. Monitor disk usage:
   ```powershell
   # Windows
   Get-PSDrive C
   ```
   ```bash
   # Linux
   df -h
   ```

#### Firewall Blocking GitHub

**Symptoms:** Runner cannot connect to GitHub, jobs timeout.

**Solutions:**
1. Allow outbound HTTPS (port 443) to GitHub IP ranges:
   - 140.82.112.0/20
   - 143.55.64.0/20
   - 185.199.108.0/22
   - 192.30.252.0/22
2. Apply firewall rules:
   ```powershell
   # Windows
   .\scripts\apply-firewall-rules.ps1
   ```
3. Check corporate proxy/firewall settings
4. Test connectivity:
   ```bash
   curl -v https://api.github.com
   ```

### Getting Help

For more detailed troubleshooting:
- See [docs/troubleshooting.md](troubleshooting.md)
- Review runner diagnostic logs in `_diag` folder
- Check GitHub Actions documentation: https://docs.github.com/en/actions/hosting-your-own-runners

### Manual Uninstallation

If you need to remove the runner:

**Windows:**
```powershell
cd C:\actions-runner

# Stop and remove service
.\svc.cmd stop
.\svc.cmd uninstall

# Remove runner from GitHub
.\config.cmd remove --token YOUR_REMOVAL_TOKEN

# Delete runner folder
cd ..
Remove-Item -Recurse -Force C:\actions-runner
```

**Linux/macOS:**
```bash
cd ~/actions-runner

# Stop and remove service
sudo ./svc.sh stop
sudo ./svc.sh uninstall

# Remove runner from GitHub
./config.sh remove --token YOUR_REMOVAL_TOKEN

# Delete runner folder
cd ..
rm -rf ~/actions-runner
```

## Next Steps

After successful installation:

1. ✅ **Verify runner is online** in GitHub settings
2. ✅ **Update workflows** to use `runs-on: [self-hosted, ...]`
3. ✅ **Set up workspace cleanup** to prevent disk issues
4. ✅ **Configure monitoring** for health checks and alerts
5. ✅ **Review security** settings and firewall rules
6. ✅ **Test workflows** with different workload types
7. ✅ **Document** any custom configuration for your team

## Related Documentation

- [Hardware Specifications](hardware-specs.md) - Recommended hardware configuration
- [Troubleshooting Guide](troubleshooting.md) - Detailed troubleshooting and monitoring
- [Label Strategy](label-strategy.md) - Runner label configuration guide
- [Self-Hosted Migration Guide](self-hosted-migration-guide.md) - Migration from GitHub-hosted runners

---

**Last Updated:** 2025-10-03
**Status:** Ready for production use
