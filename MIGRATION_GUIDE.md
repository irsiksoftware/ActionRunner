# Migration Guide: GitHub-Hosted to Self-Hosted Runners

## Purpose

This guide helps you migrate your CI/CD workflows from GitHub-hosted runners to self-hosted runners when you've hit your GitHub Actions minutes limit.

## When to Migrate

Migrate to self-hosted runners when:
- ✅ You've exhausted your GitHub Actions minutes quota
- ✅ You need specific hardware (GPU, more RAM, specific CPU)
- ✅ You need access to local resources or services
- ✅ You want faster builds with cached dependencies
- ✅ Your repositories are **private** (NEVER use with public repos!)

## Prerequisites

Before migrating, ensure you have:

- [ ] Windows 10/11 or Windows Server 2019/2022
- [ ] PowerShell 5.0 or higher
- [ ] Administrator access for initial setup
- [ ] Private GitHub repository access
- [ ] Understanding of security implications (see [docs/security.md](docs/security.md))

## Step 1: Set Up Self-Hosted Runner

### 1.1 Download GitHub Actions Runner

```powershell
# Create runner directory
mkdir C:\actions-runner
cd C:\actions-runner

# Download latest runner (check https://github.com/actions/runner/releases for latest version)
$runnerVersion = "2.311.0"
Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v$runnerVersion/actions-runner-win-x64-$runnerVersion.zip" -OutFile actions-runner.zip

# Extract
Expand-Archive -Path actions-runner.zip -DestinationPath . -Force
```

### 1.2 Configure Security (CRITICAL!)

```powershell
# Clone this repository
cd C:\Code
git clone https://github.com/YOUR-ORG/ActionRunner.git
cd ActionRunner

# Run as Administrator:
# 1. Create secure service account
.\config\runner-user-setup.ps1

# 2. Apply firewall rules
.\config\apply-firewall-rules.ps1
```

### 1.3 Register Runner with GitHub

```powershell
cd C:\actions-runner

# Get registration token from GitHub:
# Repository Settings → Actions → Runners → New self-hosted runner

# Configure the runner
.\config.cmd --url https://github.com/YOUR-ORG/YOUR-REPO --token YOUR-REGISTRATION-TOKEN --runasservice --labels windows,self-hosted

# When prompted for service account, use: GitHubRunner
# (Created by runner-user-setup.ps1)

# Start the service
Start-Service actions.runner.*
```

### 1.4 Verify Runner is Online

```powershell
# Check service status
Get-Service actions.runner.* | Select-Object Name, Status

# Verify in GitHub:
# Repository Settings → Actions → Runners
# You should see your runner listed as "Idle"
```

## Step 2: Update Your Workflows

### 2.1 Simple Migration

**Before (GitHub-hosted):**
```yaml
jobs:
  build:
    runs-on: ubuntu-latest  # or windows-latest
```

**After (Self-hosted):**
```yaml
jobs:
  build:
    runs-on: [self-hosted, windows]
```

### 2.2 Add Runner Labels for Specific Capabilities

If your runner has specific tools installed, use labels:

```yaml
jobs:
  unity-build:
    runs-on: [self-hosted, windows, unity]

  dotnet-build:
    runs-on: [self-hosted, windows, dotnet]

  python-tests:
    runs-on: [self-hosted, windows, python]
```

### 2.3 Configure Runner Labels

```powershell
# Stop the runner service
Stop-Service actions.runner.*

# Remove the runner
cd C:\actions-runner
.\config.cmd remove --token YOUR-REMOVAL-TOKEN

# Re-configure with custom labels
.\config.cmd --url https://github.com/YOUR-ORG/YOUR-REPO --token YOUR-TOKEN --runasservice --labels windows,self-hosted,dotnet,python,unity

# Start the service
Start-Service actions.runner.*
```

## Step 3: Update Existing Workflows

### Example 1: .NET Project

**Before:**
```yaml
name: .NET Build
on: [push, pull_request]

jobs:
  build:
    runs-on: windows-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v3
        with:
          dotnet-version: '8.0.x'

      - name: Restore
        run: dotnet restore

      - name: Build
        run: dotnet build --configuration Release

      - name: Test
        run: dotnet test --configuration Release
```

**After:**
```yaml
name: .NET Build
on: [push, pull_request]

jobs:
  build:
    runs-on: [self-hosted, windows, dotnet]  # Changed to self-hosted

    steps:
      - uses: actions/checkout@v4

      # Remove setup step if .NET is pre-installed on runner
      # - name: Setup .NET
      #   uses: actions/setup-dotnet@v3
      #   with:
      #     dotnet-version: '8.0.x'

      - name: Restore
        run: dotnet restore

      - name: Build
        run: dotnet build --configuration Release

      - name: Test
        run: dotnet test --configuration Release
```

### Example 2: Python Project

**Before:**
```yaml
name: Python Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run tests
        run: pytest tests/
```

**After (Windows runner):**
```yaml
name: Python Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: [self-hosted, windows, python]

    steps:
      - uses: actions/checkout@v4

      # Keep setup if you want specific Python version
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install dependencies
        shell: pwsh
        run: pip install -r requirements.txt

      - name: Run tests
        shell: pwsh
        run: pytest tests/
```

### Example 3: Node.js / React Native

**Before:**
```yaml
name: Node.js Build
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

      - name: Build
        run: npm run build
```

**After:**
```yaml
name: Node.js Build
on: [push, pull_request]

jobs:
  build:
    runs-on: [self-hosted, windows, react-native]

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install dependencies
        shell: pwsh
        run: npm ci

      - name: Run tests
        shell: pwsh
        run: npm test

      - name: Build
        shell: pwsh
        run: npm run build
```

## Step 4: Test Your Migration

### 4.1 Create a Test Workflow

Create `.github/workflows/test-runner.yml`:

```yaml
name: Test Self-Hosted Runner

on:
  workflow_dispatch:

jobs:
  test:
    runs-on: [self-hosted, windows]

    steps:
      - name: Check runner
        shell: pwsh
        run: |
          Write-Host "Runner is working!"
          Write-Host "OS: $($PSVersionTable.OS)"
          Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
          Get-ComputerInfo | Select-Object CsName, OsArchitecture, OsTotalVisibleMemorySize
```

### 4.2 Run Test Workflow

1. Go to your repository on GitHub
2. Click "Actions" tab
3. Select "Test Self-Hosted Runner"
4. Click "Run workflow"
5. Verify it completes successfully

## Step 5: Common Migration Issues

### Issue: Workflow fails with "No runner matching the specified labels"

**Solution:**
```powershell
# Check runner labels
cd C:\actions-runner
Get-Content .runner

# Reconfigure with correct labels if needed
.\config.cmd remove --token YOUR-TOKEN
.\config.cmd --url https://github.com/YOUR-ORG/YOUR-REPO --token YOUR-TOKEN --labels windows,self-hosted,YOUR-LABELS
```

### Issue: Permission denied errors

**Solution:**
```powershell
# Ensure GitHubRunner service account has access to workspace
# Run as Administrator:
$path = "C:\actions-runner\_work"
icacls $path /grant "GitHubRunner:(OI)(CI)F" /T
```

### Issue: Shell defaults to cmd instead of PowerShell

**Solution:** Add `shell: pwsh` to each step:
```yaml
steps:
  - name: My step
    shell: pwsh
    run: Write-Host "Using PowerShell"
```

### Issue: Tools not found (dotnet, python, npm, etc.)

**Solution:** Either:
1. Pre-install tools on runner, OR
2. Keep setup actions in workflow:
```yaml
- name: Setup .NET
  uses: actions/setup-dotnet@v3
  with:
    dotnet-version: '8.0.x'
```

## Step 6: Install Required Tools on Runner

### .NET SDK
```powershell
# Download and install .NET SDK
winget install Microsoft.DotNet.SDK.8
```

### Python
```powershell
# Install Python
winget install Python.Python.3.11

# Verify
python --version
pip --version
```

### Node.js
```powershell
# Install Node.js
winget install OpenJS.NodeJS.LTS

# Verify
node --version
npm --version
```

### Unity (for game development)
```powershell
# Install Unity Hub
winget install Unity.UnityHub

# Install specific Unity version through Unity Hub GUI
```

### Docker (for isolated workloads)
```powershell
# Install Docker Desktop
winget install Docker.DockerDesktop

# Configure for runners
cd C:\Code\ActionRunner
.\scripts\setup-docker.ps1
```

## Step 7: Monitor and Maintain

### Weekly Tasks
```powershell
# Check runner health
Get-Service actions.runner.*

# Review logs
Get-Content C:\actions-runner\_diag\Runner_*.log -Tail 50

# Check disk space
Get-PSDrive C | Select-Object Used, Free
```

### Monthly Tasks
```powershell
# Clean up old builds
cd C:\actions-runner\_work
Remove-Item * -Recurse -Force -ErrorAction SilentlyContinue

# Update Windows
Install-WindowsUpdate

# Rotate logs
cd C:\Code\ActionRunner
.\scripts\rotate-logs.ps1
```

## Step 8: Rollback Plan

If you need to rollback to GitHub-hosted runners:

### 8.1 Quick Rollback

Simply change workflow files back:

```yaml
jobs:
  build:
    runs-on: windows-latest  # Changed back from [self-hosted, windows]
```

### 8.2 Complete Removal

```powershell
# Stop and remove runner
Stop-Service actions.runner.*
cd C:\actions-runner
.\config.cmd remove --token YOUR-REMOVAL-TOKEN

# Remove service account (optional)
Remove-LocalUser -Name GitHubRunner

# Remove firewall rules (optional)
Remove-NetFirewallRule -DisplayName "GitHub Actions Runner*"
```

## Additional Resources

- [Security Guide](docs/security.md) - Critical security information
- [GitHub Self-Hosted Runners Docs](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)

## Success Checklist

- [ ] Runner installed and registered with GitHub
- [ ] Security hardening applied (service account, firewall)
- [ ] Workflow files updated to use `[self-hosted, windows]`
- [ ] Test workflow runs successfully
- [ ] All required tools installed on runner
- [ ] Monitoring and maintenance schedule established
- [ ] Team informed of changes
- [ ] Documentation updated

## Need Help?

- Check [troubleshooting section](README.md#troubleshooting) in main README
- Review runner logs in `C:\actions-runner\_diag\`
- Check GitHub Actions status: https://www.githubstatus.com/
- Create an issue in this repository

---

**Remember**: Self-hosted runners are powerful but require ongoing maintenance and security vigilance. Never use them with public repositories!
