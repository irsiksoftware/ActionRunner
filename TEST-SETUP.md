# Test Environment Setup Guide

This guide documents the prerequisites and setup steps for running all tests in the ActionRunner project.

## Prerequisites

### Required Software

#### 1. PowerShell
- **Minimum Version:** PowerShell 5.0 or PowerShell Core 7.0+
- **Verify Installation:**
  ```powershell
  $PSVersionTable.PSVersion
  ```
- **Installation:** PowerShell 5.0+ is included with Windows 10/11. For PowerShell Core:
  ```powershell
  winget install Microsoft.PowerShell
  ```

#### 2. Pester Testing Framework
- **Minimum Version:** Pester 5.0.0+
- **Verify Installation:**
  ```powershell
  Get-Module -ListAvailable Pester
  ```
- **Installation:**
  ```powershell
  Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck -Scope CurrentUser
  ```

#### 3. Git
- **Purpose:** Required for repository operations and testing git-related scripts
- **Verify Installation:**
  ```powershell
  git --version
  ```
- **Installation:**
  ```powershell
  winget install Git.Git
  ```

### Optional Components (for specific test categories)

#### Docker Desktop (for Docker/Container tests)
- **Purpose:** Required for `verify-docker.Tests.ps1`, `setup-docker.Tests.ps1`, container capability tests
- **Minimum Version:** Docker Desktop 4.0+
- **Verify Installation:**
  ```powershell
  docker --version
  docker-compose --version
  ```
- **Installation:**
  ```powershell
  winget install Docker.DockerDesktop
  ```
- **Post-Install:** Enable WSL2 backend in Docker Desktop settings

#### WSL2 (for Linux/WSL tests)
- **Purpose:** Required for `verify-wsl2.Tests.ps1`, Linux runner tests
- **Verify Installation:**
  ```powershell
  wsl --list --verbose
  ```
- **Installation:**
  ```powershell
  wsl --install
  # Restart computer after installation
  ```

#### GitHub CLI (for integration tests)
- **Purpose:** Required for GitHub API integration tests
- **Verify Installation:**
  ```powershell
  gh --version
  ```
- **Installation:**
  ```powershell
  winget install GitHub.cli
  ```
- **Authentication:**
  ```powershell
  gh auth login
  ```

## Environment Setup

### 1. Clone the Repository

```powershell
git clone https://github.com/irsiksoftware/ActionRunner.git
cd ActionRunner
```

### 2. Verify Directory Structure

Ensure the following directories and files exist:

```
ActionRunner/
├── scripts/          # PowerShell scripts to be tested
├── config/           # Configuration files
├── tests/            # Pester test files
│   ├── run-tests.ps1 # Main test runner
│   └── *.Tests.ps1   # Individual test files
├── dockerfiles/      # Docker image definitions
└── README.md
```

### 3. Configure Test Environment Variables (Optional)

Some tests may require environment variables for GitHub API access:

```powershell
# For GitHub API integration tests (optional)
$env:GITHUB_TOKEN = "your_github_pat_token"
$env:GITHUB_REPOSITORY = "irsiksoftware/ActionRunner"
```

**Note:** Most tests run in mock/dry-run mode and do not require actual credentials.

### 4. Check System Permissions

Some tests verify admin privilege checks but don't require actual admin rights. However, to run the full integration suite:

- **Standard Tests:** Can run as regular user
- **Integration Tests:** May require administrator privileges for:
  - Firewall rule tests
  - Service management tests
  - WSL2 configuration tests

To run PowerShell as Administrator:
```powershell
# Right-click PowerShell → "Run as Administrator"
# Or from existing PowerShell:
Start-Process powershell -Verb RunAs
```

## Running Tests

### Quick Start - Run All Tests

```powershell
cd tests
.\run-tests.ps1
```

### Run with Detailed Output

```powershell
.\run-tests.ps1 -Detailed
```

### Run with Code Coverage

```powershell
.\run-tests.ps1 -Coverage
```

### Run Specific Test Files

```powershell
# Test runner registration
Invoke-Pester -Path .\register-runner.Tests.ps1

# Test Docker setup
Invoke-Pester -Path .\setup-docker.Tests.ps1

# Test firewall configuration
Invoke-Pester -Path .\apply-firewall-rules.Tests.ps1
```

### Run Tests by Capability

```powershell
# From repository root
.\scripts\run-tests-by-capability.ps1 -Capability All
.\scripts\run-tests-by-capability.ps1 -Capability Core
.\scripts\run-tests-by-capability.ps1 -Capability WebApp
.\scripts\run-tests-by-capability.ps1 -Capability Docker
.\scripts\run-tests-by-capability.ps1 -Capability Integration
```

### Run Tests by Tag

```powershell
# Run only security tests
Invoke-Pester -Path .\tests\ -Tag Security

# Run only unit tests (skip integration tests)
Invoke-Pester -Path .\tests\ -ExcludeTag Integration
```

## Test Categories

### Core Infrastructure Tests
- `register-runner.Tests.ps1` - Runner registration
- `install-runner.Tests.ps1` - Runner installation
- `health-check.Tests.ps1` - Health monitoring
- `service-management.Tests.ps1` - Windows service management

**Prerequisites:** PowerShell, Pester

### Security Tests
- `runner-user-setup.Tests.ps1` - Service account setup
- `apply-firewall-rules.Tests.ps1` - Firewall configuration
- `firewall-rules-config.Tests.ps1` - YAML validation

**Prerequisites:** PowerShell, Pester, Administrator rights (for some tests)

### Docker/Container Tests
- `setup-docker.Tests.ps1` - Docker setup
- `verify-docker.Tests.ps1` - Docker verification
- `cleanup-docker.Tests.ps1` - Docker cleanup

**Prerequisites:** PowerShell, Pester, Docker Desktop

### WSL2/Linux Tests
- `verify-wsl2.Tests.ps1` - WSL2 verification
- `verify-linux-*.Tests.ps1` - Linux environment tests

**Prerequisites:** PowerShell, Pester, WSL2

### Integration Tests
- `health-check.Integration.Tests.ps1` - Health check integration
- `end-to-end-workflow.Integration.Tests.ps1` - Full workflow tests
- `mock-registration-service.Tests.ps1` - GitHub API mocking

**Prerequisites:** PowerShell, Pester, GitHub CLI (some tests)

### Framework/Language Verification Tests
- `verify-python.Tests.ps1` - Python environment
- `verify-dotnet.Tests.ps1` - .NET SDK
- `verify-nodejs.Tests.ps1` - Node.js environment
- `verify-flutter.Tests.ps1`, `verify-unity.Tests.ps1`, etc. - Mobile/game frameworks

**Prerequisites:** PowerShell, Pester, plus respective framework installations

## Troubleshooting

### Common Issues

#### "Pester version conflicts"
**Problem:** Multiple versions of Pester installed

**Solution:**
```powershell
Uninstall-Module Pester -AllVersions
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck
```

#### "Administrator privileges required"
**Problem:** Some tests check admin requirements

**Solution:**
- Most tests run without admin rights (they mock privileged operations)
- For full integration tests, run PowerShell as Administrator

#### "Docker daemon not running"
**Problem:** Docker Desktop not started

**Solution:**
```powershell
# Start Docker Desktop manually, or:
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
# Wait 30 seconds for Docker to initialize
Start-Sleep -Seconds 30
```

#### "WSL2 not installed"
**Problem:** WSL2 tests fail

**Solution:**
```powershell
wsl --install
# Restart computer
wsl --set-default-version 2
```

#### "GitHub API rate limit exceeded"
**Problem:** Too many API calls without authentication

**Solution:**
```powershell
# Authenticate with GitHub CLI
gh auth login

# Or set token environment variable
$env:GITHUB_TOKEN = "your_github_pat_token"
```

### Test Failures

If tests fail, check:

1. **Prerequisites installed** - Run verification commands above
2. **Environment variables** - Check if required variables are set
3. **File permissions** - Ensure read/write access to test directories
4. **Network connectivity** - Some tests may require internet access
5. **Anti-virus software** - May block PowerShell script execution

### Enable Script Execution

If you get "script execution disabled" errors:

```powershell
# Check current policy
Get-ExecutionPolicy

# Set policy for current user (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or for current session only
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
```

## CI/CD Integration

### GitHub Actions

Tests run automatically on push/PR via `.github/workflows/capability-tests.yml`

```yaml
- name: Run Pester Tests
  shell: powershell
  run: |
    Install-Module -Name Pester -Force -SkipPublisherCheck
    .\tests\run-tests.ps1 -Detailed -Coverage
```

### Local Pre-Commit Testing

Before committing changes:

```powershell
# Run full test suite
.\tests\run-tests.ps1 -Coverage

# Check test results
if ($LASTEXITCODE -ne 0) {
    Write-Host "Tests failed! Fix errors before committing." -ForegroundColor Red
}
```

## Additional Resources

- **Test Documentation:** `tests/README.md`
- **Capability Testing:** `CAPABILITY-TESTING.md`
- **Test Roadmap:** `test-improvement-roadmap.csv`
- **Pester Documentation:** https://pester.dev/
- **GitHub Actions Runner Security:** https://docs.github.com/en/actions/hosting-your-own-runners

## Getting Help

If you encounter issues not covered in this guide:

1. Check `tests/README.md` for test-specific details
2. Review test output for specific error messages
3. Check GitHub Issues for known problems
4. Contact the repository maintainers

---

**Last Updated:** 2025-10-17
**Repository:** https://github.com/irsiksoftware/ActionRunner
