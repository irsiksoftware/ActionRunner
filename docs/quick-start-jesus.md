# Quick Start: Jesus Project Runner Setup

This guide helps you set up a self-hosted GitHub Actions runner for the **Jesus MCP Agentic AI Platform** project in under 30 minutes.

## Problem Solved

**Blocker:** Workflows queued waiting for self-hosted runner
**Impact:** No CI/CD, no security scanning, no automated testing
**Solution:** Automated runner setup with all dependencies

## Prerequisites

- Windows 10/11 or Windows Server 2019+
- Administrator privileges
- 100GB+ free disk space
- Internet connection
- GitHub repository access

## One-Command Setup

### Step 1: Get Runner Token

1. Go to your Jesus repository on GitHub
2. Navigate to: **Settings → Actions → Runners**
3. Click **"New self-hosted runner"**
4. Select **Windows** as the operating system
5. Copy the **token** that appears (starts with `A...`)

### Step 2: Run Setup Script

Open PowerShell as Administrator and run:

```powershell
# Clone ActionRunner repository (if not already)
git clone https://github.com/DakotaIrsik/ActionRunner.git
cd ActionRunner

# Run the setup script
.\scripts\setup-jesus-runner.ps1 `
    -RepoUrl "https://github.com/USERNAME/jesus" `
    -RunnerToken "YOUR_TOKEN_HERE"
```

Replace:
- `USERNAME` with your GitHub username
- `YOUR_TOKEN_HERE` with the token from Step 1

### Step 3: Verify Setup

The script will:
1. ✅ Install Node.js 20.x
2. ✅ Install pnpm 9.x
3. ✅ Install Python 3.11
4. ✅ Install security tools (pip-audit, detect-secrets)
5. ✅ Verify Docker installation
6. ✅ Download and configure GitHub Actions runner
7. ✅ Install runner as Windows service
8. ✅ Run integration tests

**Expected output:**
```
============================================
    Jesus Project Runner Setup Complete!
============================================

✅ Node.js 20.x installed
✅ pnpm 9.x installed
✅ Python 3.11 installed
✅ Security tools installed
✅ Docker verified
✅ Runner configured and started

All integration tests PASSED!
```

### Step 4: Confirm Runner is Online

1. Go back to GitHub: **Settings → Actions → Runners**
2. You should see your runner listed as **"Idle"** (green dot)
3. Runner name will be your computer name (e.g., `DESKTOP-ABC123`)

### Step 5: Test the Runner

Push a commit to your Jesus repository or manually trigger a workflow:

```bash
# In your Jesus repository
git commit --allow-empty -m "Test runner"
git push
```

Watch the **Actions** tab in GitHub to see your workflow run on the self-hosted runner!

## What Gets Installed

### Node.js Stack
- **Node.js 20.18.0** (LTS)
- **pnpm 9.x** (globally via npm)
- pnpm cache configured at `C:\pnpm-store`

### Python Stack
- **Python 3.11.x** (latest)
- **pip** (latest)
- **pip-audit** (for security scanning)
- **detect-secrets** (for secret detection)

### Docker Stack
- **Docker Desktop** (verified, not installed by script)
- **Docker BuildKit** (verified)
- **Docker Buildx** (verified)

### Security Tools
- **OSV Scanner** (installed to `C:\Program Files\osv-scanner`)
- **curl** (Windows built-in)

### Runner Configuration
- **Location:** `C:\actions-runner`
- **Service Name:** `actions.runner.*`
- **Labels:** `self-hosted`, `Windows`, `X64`, `jesus`
- **Auto-start:** Yes (Windows service)

## Troubleshooting

### Docker Not Found

If the script reports Docker is not installed:

1. Download Docker Desktop: https://www.docker.com/products/docker-desktop
2. Install Docker Desktop
3. Enable WSL2 backend (recommended)
4. Start Docker Desktop
5. Re-run setup script with `-SkipDocker` flag:
   ```powershell
   .\scripts\setup-jesus-runner.ps1 `
       -RepoUrl "https://github.com/USERNAME/jesus" `
       -RunnerToken "YOUR_TOKEN" `
       -SkipDocker
   ```

### Runner Token Expired

Runner tokens expire after 1 hour. If you see "Invalid token" error:

1. Go back to: **Settings → Actions → Runners → New self-hosted runner**
2. Copy the new token
3. Re-run the setup script with the new token

### Insufficient Disk Space

The script requires 100GB free space. To free up space:

```powershell
# Clean Docker images (if Docker installed)
docker system prune -a

# Clean Windows temp files
cleanmgr /d C:

# Check available space
Get-PSDrive C
```

### Integration Tests Failed

If some tests fail but runner is configured:

1. Check the log file (path shown in script output)
2. Manually verify components:
   ```powershell
   node --version    # Should show v20.x
   pnpm --version    # Should show 9.x
   python --version  # Should show 3.11.x
   docker --version  # Should show version info
   ```
3. Re-run failed installations manually

### Runner Service Won't Start

If the runner service fails to start:

```powershell
# Check service status
Get-Service -Name "actions.runner.*"

# View service logs
Get-EventLog -LogName Application -Source "actions.runner.*" -Newest 10

# Try starting manually
cd C:\actions-runner
.\run.cmd
```

## Advanced Options

### Skip Already-Installed Components

```powershell
# Skip Node.js if already installed
.\scripts\setup-jesus-runner.ps1 `
    -RepoUrl "URL" -RunnerToken "TOKEN" -SkipNodeJs

# Skip Python if already installed
.\scripts\setup-jesus-runner.ps1 `
    -RepoUrl "URL" -RunnerToken "TOKEN" -SkipPython

# Skip multiple components
.\scripts\setup-jesus-runner.ps1 `
    -RepoUrl "URL" -RunnerToken "TOKEN" `
    -SkipNodeJs -SkipPython -SkipDocker
```

### Custom Runner Path

```powershell
# Install runner to custom location
.\scripts\setup-jesus-runner.ps1 `
    -RepoUrl "URL" -RunnerToken "TOKEN" `
    -RunnerPath "D:\runners\jesus-runner"
```

### Custom Runner Name

```powershell
# Set custom runner name
.\scripts\setup-jesus-runner.ps1 `
    -RepoUrl "URL" -RunnerToken "TOKEN" `
    -RunnerName "jesus-ci-runner-01"
```

## Updating Workflows

After runner setup, update your workflow files to use the self-hosted runner:

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  test:
    runs-on: [self-hosted, Windows, X64, jesus]  # Changed from ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        run: node --version  # No setup needed, already installed

      - name: Install dependencies
        run: pnpm install

      - name: Run tests
        run: pnpm test
```

## Monitoring the Runner

### View Runner Status

```powershell
# Check service status
Get-Service -Name "actions.runner.*"

# View running jobs
Get-Process | Where-Object { $_.ProcessName -like "*Runner*" }

# Check logs
Get-Content "C:\actions-runner\_diag\Runner_*.log" -Tail 50
```

### View Job Logs

Logs are stored at:
```
C:\actions-runner\_diag\
C:\actions-runner\logs\
```

### Restart Runner

```powershell
# Restart the service
Restart-Service -Name "actions.runner.*"

# Or manually
cd C:\actions-runner
.\svc.cmd stop
.\svc.cmd start
```

## Maintenance

### Update Runner

To update the runner to a new version:

```powershell
.\scripts\update-runner.ps1
```

See `docs/upgrade-guide.md` for detailed update procedures.

### Remove Runner

To unregister and remove the runner:

```powershell
cd C:\actions-runner

# Stop and remove service
.\svc.cmd stop
.\svc.cmd uninstall

# Unregister from GitHub
.\config.cmd remove --token YOUR_REMOVAL_TOKEN
```

## Success Criteria

After following this guide, you should have:

- ✅ Runner appears in GitHub Settings → Actions → Runners
- ✅ Runner status shows "Idle" (green)
- ✅ Workflows trigger and run on self-hosted runner
- ✅ Jobs complete successfully with green checkmarks
- ✅ CI and security workflows pass
- ✅ No more queued workflows waiting for runner

## Next Steps

1. **Test thoroughly:** Run multiple workflows to ensure stability
2. **Monitor performance:** Check job execution times
3. **Set up monitoring:** Consider implementing Issue #4 (health check)
4. **Optimize:** Review Issue #10 (performance benchmarking)
5. **Secure:** Review `docs/security.md` for best practices

## Getting Help

- **Setup logs:** `C:\Temp\jesus-runner-setup-*.log`
- **Runner logs:** `C:\actions-runner\_diag\`
- **GitHub Issues:** https://github.com/DakotaIrsik/ActionRunner/issues
- **Related Issues:**
  - Issue #30: Setup runner for Jesus project
  - Issue #16: URGENT: Migrate to self-hosted runner
  - Issue #7: Implement runner update scripts
  - Issue #4: Runner health check and monitoring

## Related Documentation

- [Upgrade Guide](./upgrade-guide.md) - Runner updates and maintenance
- [Security Guide](./security.md) - Security best practices
- [Migration Guide](../README.md) - Self-hosted runner migration strategies

---

**Setup time:** ~15-30 minutes
**Difficulty:** Easy (automated)
**Priority:** P0 - Critical

**Status:** ✅ Ready to use
