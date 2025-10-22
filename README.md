# ActionRunner - Irsik Software Build Infrastructure

Welcome! This is the build infrastructure for **Dakota Irsik / Irsik Software** repositories. If you're an AI assistant helping build applications in our org, you're in the right place.

## 🚀 NEW: Organization-Level Runner Pool (Recommended)

**Deploy 3-10+ runners for parallel builds across ALL repos!**

Organization-level runners are shared across all repositories in irsiksoftware (LogSmith, LogSmithPro, CandyRush, etc.). This is the recommended approach for maximum efficiency and scalability.

### Quick Deploy (3 Runners)

```powershell
# Get token from: https://github.com/organizations/irsiksoftware/settings/actions/runners/new

cd C:\Code\ActionRunner

.\scripts\deploy-runner-pool.ps1 `
    -OrgName "irsiksoftware" `
    -Token "YOUR_TOKEN_HERE" `
    -Count 3
```

**Benefits:**
- ✅ **Shared Infrastructure** - One runner pool serves all repos
- ✅ **Auto-Detection** - Capabilities detected automatically (Unity, GPU, Docker, etc.)
- ✅ **Easy Scaling** - Add runners without updating workflows
- ✅ **Parallel Builds** - 3 runners = 3× faster CI (15min → 5min for Unity builds)

**Usage in workflows:**
```yaml
jobs:
  build:
    runs-on: [self-hosted, unity-pool]  # Uses any available org runner
```

**Documentation:**
- 📘 **[QUICK-START-ORG-RUNNERS.md](QUICK-START-ORG-RUNNERS.md)** ← Start here!
- 📖 **[ORG-RUNNER-DEPLOYMENT.md](ORG-RUNNER-DEPLOYMENT.md)** ← Complete guide

---

## 👋 For AI Assistants (Claude, etc.)

This repository configures our self-hosted GitHub Actions runners. When you're helping build apps in the Irsik Software organization, workflows will run on these runners instead of GitHub's hosted infrastructure.

### Build Capabilities

Our runners support these build environments:

| Capability | Status | Frameworks/Tools |
|------------|--------|------------------|
| ⚙️ **Core Infrastructure** | ✓ Ready | Runner management, health checks, monitoring |
| 🌐 **Web Applications** | ⚠ Partial | Python, .NET, Node.js, pnpm |
| 🐳 **Docker & Containers** | ⚠ Partial | Docker Desktop, WSL2, container builds |
| 🔄 **Integration & Workflows** | ✓ Ready | GitHub Actions, workflow automation |
| 📱 **Mobile Apps** | ⏳ Planned | Unity, Android, iOS, React Native, Flutter |
| 🤖 **AI/LLM** | ⏳ Planned | LangChain, OpenAI, vector databases |

See [CAPABILITY-TESTING.md](CAPABILITY-TESTING.md) for detailed capability status and [test-improvement-roadmap.csv](test-improvement-roadmap.csv) for our improvement plan.

### How to Use in Your Workflows

**Recommended: Use org-level runners with capability-based labels**

When creating GitHub Actions workflows for Irsik Software repos, use the shared runner pool:

```yaml
name: Build and Test

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  # Unity projects - use unity-pool label
  unity-build:
    runs-on: [self-hosted, unity-pool]  # Auto-assigned to any available runner with Unity

    steps:
      - uses: actions/checkout@v4

      - name: Run Unity Tests
        shell: powershell
        run: |
          # Unity build commands here
          # Runners have Unity 2022.3, 2023.2, and 6000.0 installed

  # GPU-accelerated builds
  gpu-build:
    runs-on: [self-hosted, gpu, nvidia]  # Requires runner with NVIDIA GPU

    steps:
      - uses: actions/checkout@v4
      - name: GPU-accelerated task
        run: # Your GPU task

  # Docker builds
  docker-build:
    runs-on: [self-hosted, docker]  # Requires runner with Docker

    steps:
      - uses: actions/checkout@v4
      - name: Build in Docker
        shell: powershell
        run: |
          docker build -t myapp .
          docker run --rm myapp npm test
```

**Legacy approach (still supported):**

For Docker containerized builds with pre-installed dependencies:

```yaml
jobs:
  # Python projects - use multi-Python container
  python-tests:
    runs-on: [self-hosted, windows, docker]
    container:
      image: runner-python-multi:latest

    steps:
      - uses: actions/checkout@v4
      - name: Run tests with Python 3.12
        shell: powershell
        run: python -m pytest tests/
```

**Important Notes:**
- ✅ **DO** use `container:` with pre-built images for isolation
- ✅ **DO** use `runs-on: [self-hosted, windows, docker]` for our runners
- ✅ **DO** use `shell: powershell` or `shell: pwsh` (both available in containers)
- ❌ **DON'T** use `actions/setup-python@v5` - Python is pre-installed in containers
- ❌ **DON'T** install dependencies on host - use containers

### Testing Your Workflows

Before pushing workflow changes, you can test our runner capabilities:

```powershell
# Test all capabilities
.\scripts\run-tests-by-capability.ps1 -Capability All

# Test specific capability
.\scripts\run-tests-by-capability.ps1 -Capability WebApp
.\scripts\run-tests-by-capability.ps1 -Capability Docker
```

### Current Runner Assignments

| Repository | Runner Name | Platform | Labels |
|------------|-------------|----------|--------|
| ActionRunner | actionrunner-runner | Windows | `self-hosted`, `windows`, `docker` |
| qiflow | qiflow-runner | Windows | `self-hosted`, `windows`, `docker` |
| qiflowgo | qiflowgo-runner | Windows | `self-hosted`, `windows`, `docker` |
| gifdistributor | gifdistributor-runner | Windows | `self-hosted`, `windows`, `docker` |
| *TBD* | linux-runner | Linux | `self-hosted`, `linux`, `docker` |

**Multi-Platform Support:**
- **Windows runners:** For Windows-specific builds, .NET, Unity
- **Linux runners:** For cross-platform testing, performance
- **macOS runners:** (Future) For iOS/macOS builds - requires Mac hardware

---

## 🛠️ Setup Instructions (For Infrastructure Admins)

### Quick Start - Dual Runner Setup (Recommended!)

**🎯 Best Setup:** TWO runners on ONE Windows machine with WSL2!

```powershell
cd C:\Code\ActionRunner

# Step 1: Install Linux runner in WSL2 (5-10 min)
# Get runner token from: https://github.com/YOUR-ORG/YOUR-REPO/settings/actions/runners
.\scripts\setup-wsl2-runner.ps1 `
  -RepoUrl "https://github.com/DakotaIrsik/QiFlow" `
  -Token "YOUR_RUNNER_TOKEN" `
  -RunnerName "qiflow-linux-runner"

# Step 2: Build Windows Python container (10-15 min)
.\scripts\build-python-image.ps1

# Step 3: Check both runners
.\scripts\manage-runners.ps1 -Action status
```

**You'll have:**
- ✅ Windows runner (already installed) → For .NET, Unity, Windows builds
- ✅ Linux runner (in WSL2) → For Python, Node, faster builds with `container:` keyword

📖 **Full guide:** [WSL2-DUAL-RUNNER-SETUP.md](WSL2-DUAL-RUNNER-SETUP.md) ← **Start here!**
📋 **Quick commands:** [QUICK-REFERENCE.md](QUICK-REFERENCE.md) ← **Bookmark this!**

**Separate Linux Server** (Optional - if you want dedicated Linux machine)
```bash
# One-command setup on Ubuntu server
git clone https://github.com/DakotaIrsik/ActionRunner.git
cd ActionRunner
sudo ./scripts/setup-linux-runner.sh \
  --repo-url https://github.com/DakotaIrsik/YOUR-REPO \
  --token YOUR_TOKEN
```
📖 **Full guide:** [LINUX-SETUP.md](LINUX-SETUP.md)

**macOS Runner** (Future - for iOS builds)
- Requires actual Mac hardware (cannot use VMs)
- Contact for setup assistance

---

### Legacy Windows Setup (Manual)

<details>
<summary>Click to expand manual Windows setup steps</summary>

1. **Download GitHub Actions Runner**

```powershell
mkdir C:\actions-runner
cd C:\actions-runner

# Download the latest runner (check GitHub for current version)
Invoke-WebRequest -Uri https://github.com/actions/runner/releases/download/v2.328.0/actions-runner-win-x64-2.328.0.zip -OutFile actions-runner-win-x64.zip

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\actions-runner-win-x64.zip", "$PWD")
```

2. **Security Setup (Required)**

Clone this repository and run the security scripts:

```powershell
# Run as Administrator
cd C:\

# Clone the ActionRunner repository
git clone https://github.com/DakotaIrsik/ActionRunner.git
cd ActionRunner

# Create service account
.\config\runner-user-setup.ps1

# Apply firewall rules
.\config\apply-firewall-rules.ps1

# Step 3: Review security settings
notepad .\docs\security.md
notepad .\config\firewall-rules.yaml
```

3. **Register Runner**

```powershell
# Get token from GitHub: Settings → Actions → Runners → New runner
# Configure the runner (use the service account created above)
# Replace YOUR-REPO with your target repository name (e.g., qiflow, gifdistributor)
# Get YOUR-TOKEN from GitHub: Settings → Actions → Runners → New self-hosted runner
.\config.cmd --url https://github.com/DakotaIrsik/YOUR-REPO --token YOUR-TOKEN --runasservice

# When prompted, use the GitHubRunner account created by runner-user-setup.ps1
```

4. **Verify Installation**

```powershell
# Check service status
Get-Service actions.runner.* | Select-Object Name, Status, StartType

# Run capability tests
.\scripts\run-tests-by-capability.ps1 -Capability All
```

## Using the Self-Hosted Runners

### Available Runners

The following self-hosted runners are configured and available:

| Repository | Runner Labels | Docker Support |
|------------|---------------|----------------|
| **ActionRunner** | `self-hosted`, `windows`, `docker` | ✅ |
| **qiflow** | `self-hosted`, `windows`, `docker` | ✅ |
| **qiflowgo** | `self-hosted`, `windows`, `docker` | ✅ |
| **gifdistributor** | `self-hosted`, `windows`, `docker` | ✅ |

**Note**: The `docker` label is optional. Use `runs-on: [self-hosted, windows]` for standard workflows, or add `docker` when you need container isolation.

### Workflow Configuration

To use the self-hosted runners in your GitHub Actions workflows, specify the runner labels in the `runs-on` field:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, feature/* ]
  pull_request:
    branches: [ main ]

jobs:
  build-and-test:
    name: Build and Test
    runs-on: [self-hosted, windows, docker]  # Use self-hosted runner

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run tests
        shell: powershell  # Use 'powershell' not 'pwsh'
        run: |
          Write-Host "Running tests..."
          # Your test commands here
```

### Shell Compatibility

**IMPORTANT:** Use `shell: powershell` (Windows PowerShell) instead of `shell: pwsh` (PowerShell Core):

```yaml
# ✅ CORRECT - Use Windows PowerShell
- name: My Step
  shell: powershell
  run: |
    Write-Host "This works!"

# ❌ INCORRECT - PowerShell Core not installed
- name: My Step
  shell: pwsh
  run: |
    Write-Host "This fails!"
```

### Docker Isolation

All runners support Docker for containerized builds:

```yaml
jobs:
  docker-build:
    runs-on: [self-hosted, windows, docker]

    steps:
      - name: Build in Docker
        shell: powershell
        run: |
          docker build -t myapp .
          docker run --rm myapp npm test
```

### Example Workflows

See the workflow in this repository for a complete example:
- **[.github/workflows/ci.yml](.github/workflows/ci.yml)** - CI/CD pipeline with tests and validation

### Best Practices

1. **Always specify runner labels explicitly**: `runs-on: [self-hosted, windows, docker]`
2. **Use `powershell` shell**: Avoid `pwsh` as PowerShell Core is not installed
3. **Avoid UTF-8 special characters**: Use `[OK]` instead of `✓` in PowerShell output
4. **Clean up after jobs**: Use `if: always()` for cleanup steps
5. **Use Docker for untrusted code**: Isolate builds in containers when possible

## Jesus Project Runner Setup

For the **Jesus MCP Agentic AI Platform** project, which requires Node.js, Python, and Docker support, use the development stack installation script:

### Quick Setup (Windows)

```powershell
# 1. Clone this repository
git clone https://github.com/DakotaIrsik/ActionRunner.git
cd ActionRunner

# 2. Run the environment setup script
.\scripts\setup-runner-environment.ps1

# 3. Verify installation
node --version     # Should show v20.x
pnpm --version     # Should show 9.x
python --version   # Should show 3.11.x
docker --version
```

### Stack Components

The setup script (`setup-runner-environment.ps1`) installs:

- **Node.js 20.x** with **pnpm 9.x** for JavaScript/TypeScript builds
- **Python 3.11** with **pip**, **pip-audit**, and **detect-secrets** for security scanning
- **Docker** verification and configuration
- **OSV Scanner** for vulnerability scanning

### Usage in Jesus Workflows

Update your Jesus project workflows to use the self-hosted runner:

```yaml
# .github/workflows/ci.yml
jobs:
  build:
    runs-on: [self-hosted, windows, docker]

    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        shell: powershell
        run: pnpm install

      - name: Run build
        shell: powershell
        run: pnpm build

      - name: Run tests
        shell: powershell
        run: pnpm test
```

## Security Features

This repository includes comprehensive security controls:

- ✅ **Network Isolation**: Firewall rules restricting inbound/outbound traffic
- ✅ **Least Privilege**: Dedicated service account with minimal permissions
- ✅ **Secrets Management**: Best practices for GitHub secrets and tokens
- ✅ **Container Isolation**: Docker-based workflow execution
- ✅ **Audit Logging**: Comprehensive logging and monitoring
- ✅ **Documentation**: Security risks, best practices, and compliance guidance

## Documentation

- **[Security Guide](docs/security.md)**: Comprehensive security documentation covering risks, network isolation, token management, container isolation, monitoring, and compliance
- **[Migration Guide](docs/migration-guide.md)**: Step-by-step guide for migrating to self-hosted runners
- **[iOS Builds Guide](docs/ios-builds.md)**: macOS runner setup and iOS build integration

## Configuration Files

### Configuration Scripts
- **[config/firewall-rules.yaml](config/firewall-rules.yaml)**: Windows Firewall rules configuration
- **[config/runner-user-setup.ps1](config/runner-user-setup.ps1)**: Service account creation script
- **[config/apply-firewall-rules.ps1](config/apply-firewall-rules.ps1)**: Firewall rules application script

### Migration and Setup Scripts
- **[scripts/migrate-to-self-hosted.ps1](scripts/migrate-to-self-hosted.ps1)**: Automated workflow migration from GitHub-hosted to self-hosted runners
- **[scripts/setup-runner-environment.ps1](scripts/setup-runner-environment.ps1)**: Environment setup for Node.js, Python, Docker and security tools

## Prerequisites

- Windows 10/11 or Windows Server 2019/2022
- PowerShell 5.0 or higher
- Administrator access for initial setup
- Private GitHub repository (NEVER use with public repos)
- Docker Desktop (optional, for container isolation)

## Maintenance

### Regular Tasks

**Weekly:**
- Review runner logs in `C:\actions-runner\_diag\`
- Check firewall logs for blocked connection attempts
- Verify runner service status

**Monthly:**
- Rotate access tokens
- Update GitHub IP ranges in firewall rules
- Apply Windows security updates
- Review security logs

**Quarterly:**
- Full security audit
- Review and update security policies
- Test incident response procedures

### Updating the Runner

```powershell
# Stop the service
Stop-Service actions.runner.*

# Download and extract new version (check GitHub for latest)
Invoke-WebRequest -Uri https://github.com/actions/runner/releases/download/v2.328.0/actions-runner-win-x64-2.328.0.zip -OutFile actions-runner-win-x64.zip

# Extract to runner directory
cd C:\actions-runner
Expand-Archive -Path actions-runner-win-x64.zip -DestinationPath . -Force

# Start the service
Start-Service actions.runner.*
```

## Troubleshooting

### Runner Won't Start
1. Check service account permissions
2. Verify firewall rules allow GitHub connectivity
3. Review logs in `_diag` directory

### Network Connectivity Issues
1. Test HTTPS connectivity: `Test-NetConnection github.com -Port 443`
2. Review firewall logs
3. Verify DNS resolution

### Permission Denied Errors
1. Ensure service account has access to runner directory
2. Check file system permissions
3. Review Windows Event Logs

## Support

For issues or questions:
- Review [Security Documentation](docs/security.md)
- Check GitHub Actions [troubleshooting guide](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/monitoring-and-troubleshooting-self-hosted-runners)
- Contact your organization's security team

## License

This configuration repository is provided as-is for security hardening of GitHub Actions self-hosted runners.

## Contributing

Security improvements and feedback welcome! Please submit issues or pull requests.

</details>

---

### Adding Build Capabilities

**✅ Completed:**
- ✅ Python Docker image with Flask/Django (Windows + Linux)
- ✅ Multi-Python versions (3.9, 3.10, 3.11, 3.12)
- ✅ PowerShell Core support

**In Progress:**
- 🔄 Linux runner deployment
- 🔄 .NET Docker image with ASP.NET Core
- 🔄 Node.js Docker image with pnpm

**Planned:**

**Priority 2 - Infrastructure**
- Complete Docker/WSL2 setup
- Add database support (PostgreSQL, MongoDB, Redis)
- Enhance GitHub API integration tests

**Priority 3 - Mobile**
- Android SDK and build tools
- React Native support
- Flutter support
- Unity (if needed)

**Priority 4 - AI/LLM**
- LangChain and OpenAI SDK
- Vector database integration
- Model serving infrastructure

See [test-improvement-summary.md](test-improvement-summary.md) for detailed roadmap.

### Running Capability Tests

```powershell
# Test everything
.\scripts\run-tests-by-capability.ps1 -Capability All

# Test specific areas
.\scripts\run-tests-by-capability.ps1 -Capability Core
.\scripts\run-tests-by-capability.ps1 -Capability WebApp
.\scripts\run-tests-by-capability.ps1 -Capability Docker
.\scripts\run-tests-by-capability.ps1 -Capability Integration
```

### CI/CD Monitoring

Check `.github/workflows/capability-tests.yml` runs to see current build capability status:

- ⚙️ Core Infrastructure
- 🌐 Web Application Support
- 🐳 Docker & Container Support
- 🔄 Integration & Workflows
- 🔍 Script Validation
- 📱 Mobile Build Support (coming soon)
- 🤖 AI/LLM Build Support (coming soon)

---

## 📚 Documentation

- **[CAPABILITY-TESTING.md](CAPABILITY-TESTING.md)** - Build capability reference
- **[test-improvement-roadmap.csv](test-improvement-roadmap.csv)** - Prioritized improvements
- **[test-improvement-summary.md](test-improvement-summary.md)** - Detailed implementation plan
- **[docs/security.md](docs/security.md)** - Security best practices
- **[docs/maintenance.md](docs/maintenance.md)** - Maintenance procedures

---

## ⚠️ Security Notice

**CRITICAL**: Self-hosted runners are configured for **private Irsik Software repositories only**.

Never use with:
- ❌ Public repositories
- ❌ Untrusted pull requests
- ❌ Third-party forks

Malicious code can execute arbitrary commands and compromise infrastructure.

---

## 📧 Support

**For AI Assistants:** Check [CAPABILITY-TESTING.md](CAPABILITY-TESTING.md) for build capability details.

**For Infrastructure Issues:** Contact Dakota Irsik or review [docs/security.md](docs/security.md).

**For Build Problems:** Check workflow runs in GitHub Actions and review capability test results.

---

**Organization:** Dakota Irsik / Irsik Software
**Last Updated:** 2025-10-03
