# Self-Hosted Runner Migration Guide

## Overview

This guide walks you through migrating from GitHub-hosted runners to self-hosted runners to avoid GitHub Actions minutes limitations.

## Quick Start (5 Minutes)

### Prerequisites

- Windows 11 Pro machine (see [hardware-specs.md](hardware-specs.md) for full specs)
- GitHub Personal Access Token (PAT) with `admin:org` or `repo` scope
- PowerShell 5.1+ (run as Administrator for service installation)

### Step 1: Register the Runner

```powershell
# For organization-level runner (recommended)
.\scripts\register-runner.ps1 `
    -OrgOrRepo "your-org-name" `
    -Token "ghp_your_token_here" `
    -IsOrg `
    -InstallService

# For single repository runner
.\scripts\register-runner.ps1 `
    -OrgOrRepo "owner/repo-name" `
    -Token "ghp_your_token_here" `
    -InstallService
```

### Step 2: Verify Runner is Online

1. Visit GitHub Settings:
   - **Organization**: `https://github.com/organizations/YOUR-ORG/settings/actions/runners`
   - **Repository**: `https://github.com/OWNER/REPO/settings/actions/runners`

2. Confirm your runner shows as "Idle" (green dot)

### Step 3: Update Your Workflows

Replace `runs-on: ubuntu-latest` or `runs-on: windows-latest` with:

```yaml
jobs:
  build:
    runs-on: [self-hosted, windows, dotnet]  # Add relevant labels
```

See [Workflow Examples](#workflow-examples) below for specific use cases.

## Detailed Setup

### Creating a GitHub Personal Access Token (PAT)

1. Go to **GitHub Settings** → **Developer Settings** → **Personal Access Tokens** → **Tokens (classic)**
2. Click **"Generate new token (classic)"**
3. Set expiration (recommend 90 days, set calendar reminder to renew)
4. Select scopes:
   - For **organization runner**: `admin:org` (includes `write:org`, `read:org`)
   - For **repository runner**: `repo` (full control of private repositories)
5. Click **"Generate token"** and copy it immediately (you won't see it again)

### Runner Labels Strategy

The registration script applies these default labels:

| Label | Purpose | Workflows That Use It |
|-------|---------|----------------------|
| `self-hosted` | Auto-applied to all self-hosted runners | All workflows |
| `windows` | Windows OS environment | All workflows (default) |
| `dotnet` | .NET SDK installed | tasvideos, WebAPITemplate, Mercury, ARKPlugin |
| `python` | Python 3.9-3.12 installed | QiFlow, GIFDistributor |
| `unity` | Unity 2022.3+ installed | LogSmith, CandyRush, NeonLadder |
| `gpu-cuda` | NVIDIA GPU with CUDA | TalkSmith, stable-diffusion-webui |
| `docker` | Docker Desktop installed | Isolated/untrusted code execution |

### Custom Labels

To use custom labels:

```powershell
.\scripts\register-runner.ps1 `
    -OrgOrRepo "your-org" `
    -Token "ghp_xxx" `
    -IsOrg `
    -Labels "self-hosted,windows,custom-label-1,custom-label-2" `
    -InstallService
```

## Workflow Examples

### Before: GitHub-Hosted Runner

```yaml
name: CI

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest  # ❌ Uses GitHub minutes
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: npm test
```

### After: Self-Hosted Runner

```yaml
name: CI

on: [push, pull_request]

jobs:
  build:
    runs-on: [self-hosted, windows, python]  # ✅ Uses self-hosted runner
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: npm test
```

### .NET Build Example

```yaml
jobs:
  build:
    runs-on: [self-hosted, windows, dotnet]

    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - name: Restore dependencies
        run: dotnet restore

      - name: Build
        run: dotnet build --configuration Release

      - name: Test
        run: dotnet test --configuration Release
```

### Unity Build Example

```yaml
jobs:
  unity-build:
    runs-on: [self-hosted, windows, unity]

    steps:
      - uses: actions/checkout@v4
        with:
          lfs: true  # Git LFS for Unity assets

      - name: Cache Unity Library
        uses: actions/cache@v4
        with:
          path: Library
          key: Library-${{ hashFiles('Assets/**') }}

      - name: Build Windows
        run: |
          & "C:\Program Files\Unity\Hub\Editor\2022.3.15f1\Editor\Unity.exe" `
            -quit -batchmode -nographics `
            -projectPath "$PWD" `
            -buildWindows64Player "Build/Game.exe"
```

### GPU-Accelerated ML Example

```yaml
jobs:
  train-model:
    runs-on: [self-hosted, windows, gpu-cuda]

    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install PyTorch with CUDA
        run: |
          pip install torch torchvision --index-url https://download.pytorch.org/whl/cu121

      - name: Verify GPU
        run: |
          python -c "import torch; print(torch.cuda.is_available())"

      - name: Run training
        run: python train.py --gpu
```

### Docker Isolated Example (Untrusted Code)

```yaml
jobs:
  build-untrusted:
    runs-on: [self-hosted, windows, docker]
    container:
      image: mcr.microsoft.com/dotnet/sdk:8.0
      options: --cpus 2 --memory 4g

    steps:
      - uses: actions/checkout@v4
      - name: Build in isolated container
        run: dotnet build
```

## Migration Checklist

Use this checklist to ensure complete migration:

- [ ] **Generate GitHub PAT** with correct permissions (`admin:org` or `repo`)
- [ ] **Run registration script** on your self-hosted machine
- [ ] **Verify runner online** in GitHub Settings → Actions → Runners
- [ ] **Update workflows** to use `runs-on: [self-hosted, windows, ...]`
- [ ] **Test each workflow** by triggering manual runs or pushing commits
- [ ] **Monitor runner logs** for errors: `C:\actions-runner\_diag\`
- [ ] **Set up firewall rules** (optional): `.\scripts\setup-firewall.ps1`
- [ ] **Configure workspace cleanup** (recommended): Schedule `.\scripts\cleanup-workspace.ps1`
- [ ] **Set up log rotation** (recommended): Schedule `.\scripts\rotate-logs.ps1`
- [ ] **Document PAT expiration** in calendar (renew before expiry)
- [ ] **Remove GitHub-hosted runner workflows** (or keep as fallback)

## Common Migration Patterns

### Pattern 1: Complete Migration

Replace all `runs-on` directives with self-hosted labels:

```yaml
# Before
runs-on: ubuntu-latest

# After
runs-on: [self-hosted, windows]
```

### Pattern 2: Hybrid Approach (Fallback)

Use GitHub-hosted runners as fallback if self-hosted unavailable:

```yaml
jobs:
  build:
    runs-on: ${{ github.event_name == 'pull_request' && '[self-hosted, windows]' || 'ubuntu-latest' }}
```

### Pattern 3: Job-Specific Runners

Use self-hosted for heavy jobs, GitHub-hosted for light jobs:

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest  # Fast, uses GitHub minutes

  build:
    runs-on: [self-hosted, windows, unity]  # Heavy build, uses self-hosted
```

## Troubleshooting

### Runner Not Showing in GitHub

1. Check runner service is running:
   ```powershell
   Get-Service actions.runner.*
   ```

2. View runner logs:
   ```powershell
   Get-Content C:\actions-runner\_diag\Runner_*.log -Tail 50
   ```

3. Verify network connectivity:
   ```powershell
   Test-NetConnection github.com -Port 443
   ```

### Workflow Not Using Self-Hosted Runner

1. Verify labels match exactly:
   ```yaml
   runs-on: [self-hosted, windows]  # Must match runner labels
   ```

2. Check runner is idle (not busy with another job)

3. View workflow run logs for runner assignment errors

### Jobs Failing on Self-Hosted Runner

1. Ensure required tools installed (e.g., .NET SDK, Python, Unity)
2. Check workspace cleanup ran successfully
3. Verify sufficient disk space: `Get-PSDrive C`
4. Review job logs for missing dependencies

### Authentication Errors

- **Error**: "Bad credentials" → PAT expired or has wrong scopes
- **Solution**: Generate new PAT with `admin:org` (orgs) or `repo` (repos)

## Security Considerations

### Isolation for Untrusted Code

**⚠️ WARNING**: Self-hosted runners execute workflow code directly on your machine. For public repositories or untrusted code, use Docker isolation:

```yaml
runs-on: [self-hosted, windows, docker]
container:
  image: safe-base-image:latest
  options: --cpus 2 --memory 4g --read-only
```

See [Docker isolation guide](docker-isolation.md) for detailed setup.

### Firewall Configuration

Restrict runner network access to GitHub only:

```powershell
.\scripts\setup-firewall.ps1
```

### Service Account

Run runner as dedicated service account (not admin):

```powershell
.\scripts\create-runner-user.ps1
```

## Maintenance

### Updating the Runner

```powershell
# Stop service
.\svc.cmd stop

# Re-run registration (will download latest version)
.\scripts\register-runner.ps1 -OrgOrRepo "your-org" -Token "ghp_xxx" -IsOrg -InstallService

# Service will start automatically
```

### Workspace Cleanup

Schedule daily cleanup to prevent disk space issues:

```powershell
# Manual cleanup
.\scripts\cleanup-workspace.ps1

# Schedule daily at 2 AM
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\actions-runner\scripts\cleanup-workspace.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "GitHubRunnerCleanup" -Description "Clean up GitHub Actions runner workspace"
```

### Log Rotation

```powershell
# Rotate logs (keeps last 30 days)
.\scripts\rotate-logs.ps1 -DaysToKeep 30
```

## Cost Comparison

### Before: GitHub-Hosted Runners

- **Free tier**: 2,000 minutes/month (public repos), 3,000 minutes/month (private repos on Team plan)
- **Overage**: $0.008/minute (Ubuntu), $0.016/minute (Windows), $0.08/minute (macOS)
- **Estimated monthly cost** (100 hours of Unity builds): ~$960/month

### After: Self-Hosted Runner

- **Hardware cost**: $2,800 one-time (see [hardware-specs.md](hardware-specs.md))
- **Electricity**: ~$40/month (24/7 operation at $0.12/kWh)
- **Total first-year cost**: $3,280
- **Break-even**: ~3.4 months vs. GitHub-hosted

## Advanced Configuration

### Multiple Runners (Load Balancing)

Register multiple runners with same labels for parallel job execution:

```powershell
# Runner 1
.\scripts\register-runner.ps1 -OrgOrRepo "org" -Token "ghp_xxx" -RunnerName "runner-01" -IsOrg -InstallService

# Runner 2 (on different machine)
.\scripts\register-runner.ps1 -OrgOrRepo "org" -Token "ghp_xxx" -RunnerName "runner-02" -IsOrg -InstallService
```

GitHub will distribute jobs across idle runners automatically.

### Organization-Level Runner Groups

For large orgs, use runner groups to control access:

1. Create runner group: GitHub Org Settings → Actions → Runner groups
2. Add repositories to group
3. Register runner with group:
   ```powershell
   # Note: Requires additional API call (not implemented in current script)
   # See: https://docs.github.com/en/rest/actions/self-hosted-runner-groups
   ```

### Monitoring and Alerting

Set up monitoring:

```powershell
# Check runner health
.\scripts\monitor-runner.ps1 -AlertEmail "admin@example.com"

# Schedule health checks every 15 minutes
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\actions-runner\scripts\monitor-runner.ps1"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 15)
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "GitHubRunnerHealthCheck"
```

## FAQ

### Q: Can I use the same runner for multiple repositories?

**A**: Yes! Organization-level runners are accessible to all repos in the org. Repository-level runners are scoped to a single repo.

### Q: What happens if the runner is offline?

**A**: Workflow jobs will queue until the runner comes back online or timeout (default 6 hours). Configure fallback to GitHub-hosted runners for critical workflows.

### Q: How do I remove a runner?

**A**:
```powershell
# Stop and uninstall service
.\svc.cmd stop
.\svc.cmd uninstall

# Remove runner from GitHub
.\config.cmd remove --token YOUR_PAT
```

### Q: Can I run macOS or Linux on self-hosted runners?

**A**: Yes, but this project focuses on Windows. For macOS (iOS builds), see [macOS setup guide](macos-runner-setup.md). For Linux, GitHub has excellent docs: https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners

### Q: How do I handle runner updates?

**A**: GitHub automatically updates self-hosted runners. You can also manually update by re-running the registration script, which downloads the latest version.

## Next Steps

1. **Register your runner**: Run `.\scripts\register-runner.ps1`
2. **Update workflows**: See [Workflow Examples](#workflow-examples)
3. **Test thoroughly**: Trigger test runs for each repository
4. **Set up maintenance**: Configure cleanup and monitoring scripts
5. **Monitor costs**: Track electricity usage and compare to GitHub-hosted costs

## Resources

- [Official GitHub Docs](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Hardware Specs](hardware-specs.md)
- [Troubleshooting Guide](troubleshooting.md)
- [Docker Isolation Setup](docker-isolation.md)
- [Security Best Practices](security.md)

---

**Last Updated**: 2025-10-03
**Issue**: [#16 - URGENT: Migrate to self-hosted runner](https://github.com/DakotaIrsik/ActionRunner/issues/16)
