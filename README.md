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

When creating GitHub Actions workflows for Irsik Software repos, use:

```yaml
name: Build and Test

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: [self-hosted, windows]  # Use our runner

    steps:
      - uses: actions/checkout@v4

      - name: Build your app
        shell: powershell  # Use 'powershell', not 'pwsh'
        run: |
          # Your build commands here
          Write-Host "Building..."
```

**Important Notes:**
- Use `shell: powershell` (not `pwsh` - PowerShell Core not installed)
- Use `runs-on: [self-hosted, windows]` for our runners
- For Docker builds: `runs-on: [self-hosted, windows, docker]`

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

| Repository | Runner Name | Labels |
|------------|-------------|--------|
| ActionRunner | actionrunner-runner | `self-hosted`, `windows`, `docker` |
| qiflow | qiflow-runner | `self-hosted`, `windows`, `docker` |
| qiflowgo | qiflowgo-runner | `self-hosted`, `windows`, `docker` |
| gifdistributor | gifdistributor-runner | `self-hosted`, `windows`, `docker` |

---

## 🛠️ Setup Instructions (For Infrastructure Admins)

### Initial Runner Setup

1. **Download GitHub Actions Runner**

```powershell
mkdir C:\actions-runner
cd C:\actions-runner

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
.\config.cmd --url https://github.com/DakotaIrsik/YOUR-REPO --token YOUR-TOKEN --runasservice
```

4. **Verify Installation**

```powershell
# Check service status
Get-Service actions.runner.* | Select-Object Name, Status, StartType

# Run capability tests
.\scripts\run-tests-by-capability.ps1 -Capability All
```

### Adding Build Capabilities

We're actively expanding build support. Current priorities:

**Priority 1 - Web Apps (Quick Wins)**
- Create Python Docker image with Flask/Django
- Create .NET Docker image with ASP.NET Core
- Create Node.js Docker image with pnpm
- Add framework verification tests

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
