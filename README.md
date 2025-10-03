# ActionRunner - Irsik Software Build Infrastructure

Welcome! This is the build infrastructure for **Dakota Irsik / Irsik Software** repositories. If you're an AI assistant helping build applications in our org, you're in the right place.

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

**⚠️ IMPORTANT: Always use Docker containers for isolation and pre-installed dependencies.**

When creating GitHub Actions workflows for Irsik Software repos, use containerized jobs:

```yaml
name: Build and Test

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

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

      - name: Run tests with Python 3.10
        shell: powershell
        run: C:\Python310\python.exe -m pytest tests/

  # .NET projects - use .NET container
  dotnet-build:
    runs-on: [self-hosted, windows, docker]
    container:
      image: runner-dotnet:latest

    steps:
      - uses: actions/checkout@v4

      - name: Build
        shell: powershell
        run: dotnet build

      - name: Test
        shell: powershell
        run: dotnet test
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

```powershell
# Clone this repo
git clone https://github.com/DakotaIrsik/ActionRunner.git
cd ActionRunner

# Create service account
.\config\runner-user-setup.ps1

# Apply firewall rules
.\config\apply-firewall-rules.ps1
```

3. **Register Runner**

```powershell
# Get token from GitHub: Settings → Actions → Runners → New runner
# Configure the runner (use the service account created above)
# Replace YOUR-ORG and YOUR-REPO with your GitHub organization/repository
.\config.cmd --url https://github.com/YOUR-ORG/YOUR-REPO --token YOUR-TOKEN --runasservice

# When prompted, use the GitHubRunner account created by runner-user-setup.ps1
```

4. **Verify Installation**

```powershell
# Check service status
Get-Service actions.runner.* | Select-Object Name, Status, StartType

# Run capability tests
.\scripts\run-tests-by-capability.ps1 -Capability All
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

- **[Migration Guide](docs/migration-guide.md)**: Step-by-step guide for migrating to self-hosted runner
  - Environment setup automation
  - Security configuration
  - Jesus project specific requirements
  - Troubleshooting and rollback procedures

- **[Security Guide](docs/security.md)**: Comprehensive security documentation
  - Security risks and mitigation strategies
  - Network isolation and firewall configuration
  - Token management and rotation
  - Container isolation with Docker
  - Monitoring and incident response
  - Compliance considerations

- **[macOS/iOS Build Integration](docs/ios-builds.md)**: Guide for hybrid runner setup
  - Cost analysis: GitHub-hosted vs self-hosted Mac
  - React Native iOS build workflows
  - Code signing setup and requirements

## Configuration Files

- **[scripts/setup-runner-environment.ps1](scripts/setup-runner-environment.ps1)**: Automated environment setup for Node.js, Python, Docker
- **[config/firewall-rules.yaml](config/firewall-rules.yaml)**: Windows Firewall rules configuration
- **[config/runner-user-setup.ps1](config/runner-user-setup.ps1)**: Service account creation script
- **[config/apply-firewall-rules.ps1](config/apply-firewall-rules.ps1)**: Firewall rules application script

## Development

This repository includes automated testing via GitHub Actions CI:

- **PowerShell Script Tests**: Validates all scripts with Pester
- **Configuration Validation**: Checks YAML syntax and workflow files
- **Security Scanning**: Detects potential secrets and hardcoded paths

See [.github/workflows/ci.yml](.github/workflows/ci.yml) for details.

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
# Then re-run config

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
