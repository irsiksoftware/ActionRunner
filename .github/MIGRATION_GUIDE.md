# Self-Hosted Runner Migration Guide

## Overview

This guide helps you migrate GitHub Actions workflows from GitHub-hosted runners to self-hosted runners to avoid GitHub Actions minutes limits and maintain uninterrupted CI/CD operations.

## Prerequisites

- Windows machine with administrator access
- GitHub repository access with runner registration permissions
- PowerShell 5.1 or later

## Quick Start (Critical Migration)

If you need to migrate **immediately** due to minutes exhaustion:

```powershell
# 1. Setup self-hosted runner (requires admin privileges)
.\scripts\setup-runner.ps1 `
    -RepoUrl "https://github.com/YOUR_ORG/YOUR_REPO" `
    -Token "YOUR_RUNNER_TOKEN"

# 2. Verify and migrate workflows
.\scripts\migrate-to-self-hosted.ps1 -AutoUpdate
```

## Detailed Steps

### Step 1: Get Runner Registration Token

1. Go to your GitHub repository
2. Navigate to **Settings** > **Actions** > **Runners**
3. Click **New self-hosted runner**
4. Copy the registration token (starts with `A...`)

### Step 2: Setup Self-Hosted Runner

Run the setup script with administrator privileges:

```powershell
# Basic setup
.\scripts\setup-runner.ps1 `
    -RepoUrl "https://github.com/DakotaIrsik/ActionRunner" `
    -Token "YOUR_TOKEN_HERE"

# Advanced setup with custom labels
.\scripts\setup-runner.ps1 `
    -RepoUrl "https://github.com/DakotaIrsik/ActionRunner" `
    -Token "YOUR_TOKEN_HERE" `
    -RunnerName "windows-docker-runner" `
    -Labels "self-hosted,windows,docker,x64"
```

**What this does:**
- Downloads latest GitHub Actions runner
- Installs and configures runner for your repository
- Registers runner as a Windows service
- Starts runner automatically

### Step 3: Verify Runner Status

Check that the runner is online:

```powershell
# Check Windows service
Get-Service actions.runner.*

# Verify in GitHub UI
# Go to Settings > Actions > Runners - you should see your runner with "Idle" status
```

### Step 4: Migrate Workflows

#### Option A: Automatic Migration (Recommended)

```powershell
# Verify what needs migration
.\scripts\migrate-to-self-hosted.ps1 -VerifyOnly

# Migrate all workflows automatically (creates backups)
.\scripts\migrate-to-self-hosted.ps1 -AutoUpdate
```

#### Option B: Manual Migration

Update your workflow files manually. Change:

```yaml
# Before
runs-on: ubuntu-latest
```

To:

```yaml
# After
runs-on: [self-hosted, windows]
```

For Linux workloads (requires WSL2 or Docker):

```yaml
runs-on: [self-hosted, linux]
```

### Step 5: Test Migration

1. Push a small change to trigger a workflow
2. Monitor the workflow run in GitHub Actions UI
3. Verify it runs on your self-hosted runner
4. Check runner logs: `C:\actions-runner\_diag\`

### Step 6: Monitor Runner Health

```powershell
# Run health check manually
.\scripts\health-check.ps1

# Check runner logs
.\scripts\collect-logs.ps1

# Monitor runner continuously
.\scripts\monitor-runner.ps1
```

## Workflow Examples

### Basic CI Workflow

```yaml
name: CI Build

on: [push, pull_request]

jobs:
  build:
    runs-on: [self-hosted, windows]
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: |
          echo "Building on self-hosted runner"
          # Your build commands here
```

### Docker Workflow

```yaml
name: Docker Build

on: [push]

jobs:
  docker-build:
    runs-on: [self-hosted, windows, docker]
    steps:
      - uses: actions/checkout@v4
      - name: Build Docker image
        run: |
          docker build -t myapp:latest .
```

### Multi-Job Workflow

```yaml
name: Full Pipeline

on: [push]

jobs:
  test:
    runs-on: [self-hosted, windows]
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: dotnet test

  build:
    needs: test
    runs-on: [self-hosted, windows]
    steps:
      - uses: actions/checkout@v4
      - name: Build application
        run: dotnet build -c Release
```

## Troubleshooting

### Runner Not Appearing in GitHub

1. Check runner service is running: `Get-Service actions.runner.*`
2. Check runner logs: `C:\actions-runner\_diag\Runner_*.log`
3. Verify token hasn't expired (tokens expire after 1 hour)
4. Re-run setup with `--replace` flag (already included in setup script)

### Workflow Not Using Self-Hosted Runner

1. Verify workflow file uses correct `runs-on` syntax
2. Check runner labels match workflow requirements
3. Ensure runner is online in GitHub UI (Settings > Actions > Runners)
4. Push changes to trigger workflow

### Runner Service Crashes

```powershell
# Check service status
Get-Service actions.runner.* | Select-Object Name, Status

# View service logs
Get-EventLog -LogName Application -Source "actions.runner.*" -Newest 50

# Restart service
Restart-Service actions.runner.*
```

### Disk Space Issues

```powershell
# Clean up Docker resources
.\scripts\cleanup-docker.ps1

# Clean up workspace
.\scripts\cleanup-workspace.ps1

# Check disk space
.\scripts\health-check.ps1 -DiskThresholdGB 50
```

## Security Best Practices

1. **Run runner as dedicated service account** (not administrator)
2. **Use ephemeral runners** for untrusted code
3. **Enable Windows Firewall** with appropriate rules
4. **Keep runner software updated** using `.\scripts\update-runner.ps1`
5. **Monitor runner logs** for suspicious activity
6. **Isolate workflows** using Docker containers when possible

## Cost Savings

- **GitHub-hosted runners:** $0.008/minute (Windows), $0.016/minute (macOS)
- **Self-hosted runners:** Free (only infrastructure costs)

For a busy repository running 10,000 minutes/month on Windows:
- GitHub-hosted: **$80/month**
- Self-hosted: **$0** (plus your server costs)

## Maintenance

### Regular Tasks

```powershell
# Weekly: Update runner
.\scripts\update-runner.ps1

# Weekly: Clean up Docker
.\scripts\cleanup-docker.ps1

# Monthly: Rotate logs
.\scripts\rotate-logs.ps1

# As needed: Health check
.\scripts\health-check.ps1
```

### Automated Monitoring

The repository includes automated health checks via GitHub Actions:
- Runs every 6 hours
- Checks disk space, memory, CPU
- Uploads health reports
- Alerts on failures

## Additional Resources

- [GitHub Self-Hosted Runners Documentation](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Runner Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- Project scripts: `scripts/` directory

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review runner logs: `C:\actions-runner\_diag\`
3. Check migration logs: `logs/migration-*.log`
4. Review GitHub Actions run logs in repository

## Migration Checklist

- [ ] Get runner registration token from GitHub
- [ ] Run `setup-runner.ps1` with admin privileges
- [ ] Verify runner appears online in GitHub Settings
- [ ] Run `migrate-to-self-hosted.ps1 -VerifyOnly`
- [ ] Backup workflow files (automatic with `-AutoUpdate`)
- [ ] Run `migrate-to-self-hosted.ps1 -AutoUpdate`
- [ ] Review and commit workflow changes
- [ ] Test workflows with manual trigger
- [ ] Monitor first few runs for issues
- [ ] Set up automated health checks
- [ ] Schedule regular maintenance tasks
