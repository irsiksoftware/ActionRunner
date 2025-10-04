# Test Environment Setup Guide

This guide documents the prerequisites and setup steps for running all tests in the ActionRunner project.

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Core Prerequisites](#core-prerequisites)
3. [Language and Toolchain Prerequisites](#language-and-toolchain-prerequisites)
4. [Docker and Container Prerequisites](#docker-and-container-prerequisites)
5. [Database Prerequisites](#database-prerequisites)
6. [Security and Monitoring Tools](#security-and-monitoring-tools)
7. [Running Tests](#running-tests)
8. [Troubleshooting](#troubleshooting)

---

## System Requirements

### Operating System
- **Windows 10/11** (64-bit) or **Windows Server 2019/2022**
- **PowerShell 5.1+** (PowerShell 7+ recommended)
- **Administrator privileges** for some tests and setup tasks

### Hardware
- **CPU**: 4+ cores recommended
- **RAM**: 8GB minimum, 16GB+ recommended for Docker tests
- **Disk**: 50GB+ free space (Docker images require significant storage)
- **GPU**: Optional, required only for AI/LLM and Unity tests

---

## Core Prerequisites

### 1. PowerShell and Pester

```powershell
# Check PowerShell version (5.1+ required)
$PSVersionTable.PSVersion

# Install/Update Pester (5.0+ required)
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck -Scope CurrentUser

# Verify Pester installation
Get-Module -ListAvailable Pester
```

### 2. Git

```powershell
# Install Git for Windows
winget install Git.Git

# Verify installation
git --version
```

### 3. GitHub CLI (optional, for PR tests)

```powershell
# Install GitHub CLI
winget install GitHub.cli

# Authenticate
gh auth login
```

---

## Language and Toolchain Prerequisites

### Python (Required for multiple test suites)

```powershell
# Install Python 3.8+
winget install Python.Python.3.11

# Verify installation
python --version
pip --version

# Install common dependencies
pip install pytest requests pyyaml
```

### Node.js (Required for JavaScript/TypeScript tests)

```powershell
# Install Node.js LTS
winget install OpenJS.NodeJS.LTS

# Verify installation
node --version
npm --version
```

### .NET SDK (Required for ASP.NET Core tests)

```powershell
# Install .NET 8 SDK
winget install Microsoft.DotNet.SDK.8

# Verify installation
dotnet --version
```

### Rust (Optional, for Rust toolchain tests)

```powershell
# Download and run rustup installer
# Visit: https://rustup.rs/

# Verify installation
rustc --version
cargo --version
```

### Go (Optional, for Go toolchain tests)

```powershell
# Install Go
winget install GoLang.Go

# Verify installation
go version
```

### Java and Build Tools (Optional)

```powershell
# Install Java JDK
winget install Microsoft.OpenJDK.17

# Install Maven
winget install Apache.Maven

# Install Gradle
winget install Gradle.Gradle

# Verify installations
java -version
mvn --version
gradle --version
```

### CMake (Optional, for C/C++ tests)

```powershell
# Install CMake
winget install Kitware.CMake

# Verify installation
cmake --version
```

---

## Docker and Container Prerequisites

### 1. Enable WSL2

```powershell
# Run in elevated PowerShell
wsl --install

# Set WSL2 as default
wsl --set-default-version 2

# Verify WSL2 is installed
wsl --list --verbose
```

### 2. Install Docker Desktop

1. Download Docker Desktop from [docker.com](https://www.docker.com/products/docker-desktop)
2. Install and enable WSL2 backend
3. Start Docker Desktop

```powershell
# Verify Docker installation
docker --version
docker compose version

# Test Docker
docker run hello-world
```

### 3. Configure Docker Resources

Update Docker Desktop settings:
- **CPU**: Allocate at least 2 cores (4+ recommended)
- **Memory**: Allocate at least 4GB (8GB+ recommended)
- **Disk**: Ensure adequate storage for images

### 4. Pull Base Images (Optional)

```powershell
# Common base images used in tests
docker pull mcr.microsoft.com/dotnet/sdk:8.0
docker pull python:3.11-slim
docker pull node:lts
docker pull postgres:15
docker pull mongo:7
docker pull redis:7
```

---

## Database Prerequisites

### PostgreSQL (Optional, for database tests)

```powershell
# Run PostgreSQL in Docker
docker run -d `
  --name postgres-test `
  -e POSTGRES_PASSWORD=test123 `
  -p 5432:5432 `
  postgres:15

# Verify connection
docker exec -it postgres-test psql -U postgres -c "SELECT version();"
```

### MongoDB (Optional, for database tests)

```powershell
# Run MongoDB in Docker
docker run -d `
  --name mongo-test `
  -p 27017:27017 `
  mongo:7

# Verify connection
docker exec -it mongo-test mongosh --eval "db.version()"
```

### Redis (Optional, for cache tests)

```powershell
# Run Redis in Docker
docker run -d `
  --name redis-test `
  -p 6379:6379 `
  redis:7

# Verify connection
docker exec -it redis-test redis-cli ping
```

---

## Security and Monitoring Tools

### Security Scanning Tools

```powershell
# Install Trivy for container scanning
winget install Aqua.Trivy

# Verify installation
trivy --version
```

### Monitoring Prerequisites

For dashboard and health check tests:

```powershell
# Install Node.js (if not already installed)
# See Language Prerequisites section

# Optional: Install http-server for simple web serving
npm install -g http-server
```

---

## Running Tests

### Quick Start

```powershell
# Navigate to project root
cd C:\Code\ActionRunner

# Run all tests
.\tests\run-tests.ps1

# Run with detailed output
.\tests\run-tests.ps1 -Detailed

# Run with code coverage
.\tests\run-tests.ps1 -Coverage
```

### Running Specific Test Suites

```powershell
# Run tests by capability (requires specific prerequisites)
.\scripts\run-tests-by-capability.ps1 -Capability "PowerShell"
.\scripts\run-tests-by-capability.ps1 -Capability "Docker"
.\scripts\run-tests-by-capability.ps1 -Capability "Python"
.\scripts\run-tests-by-capability.ps1 -Capability "DotNet"

# Run individual test files
Invoke-Pester -Path .\tests\setup-docker.Tests.ps1
Invoke-Pester -Path .\tests\verify-rust.Tests.ps1
Invoke-Pester -Path .\tests\health-check.Tests.ps1
```

### Test Categories

Tests are organized by category:

| Category | Prerequisites | Test Files |
|----------|--------------|------------|
| **Core** | PowerShell, Pester | `*.Tests.ps1` (general) |
| **Docker** | Docker Desktop, WSL2 | `setup-docker.Tests.ps1`, `cleanup-docker.Tests.ps1` |
| **Languages** | Python, Node.js, .NET, Rust, Go | `verify-*.Tests.ps1` |
| **Databases** | PostgreSQL, MongoDB, Redis (Docker) | `verify-*.Tests.ps1` (database-specific) |
| **Security** | Trivy, security tools | `verify-security-scanning.Tests.ps1` |
| **Monitoring** | Web server, Node.js | `health-check*.Tests.ps1`, `dashboard.Tests.ps1` |
| **Integration** | Multiple prerequisites | `*.Integration.Tests.ps1` |

---

## Troubleshooting

### Common Issues

#### Pester Version Conflicts

```powershell
# Remove old Pester versions
Get-Module Pester -ListAvailable | Uninstall-Module -Force

# Install Pester 5.x
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck
```

#### Docker Not Running

```powershell
# Check Docker service status
Get-Service Docker

# Start Docker Desktop manually or via command
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Wait for Docker to be ready
docker ps
```

#### WSL2 Issues

```powershell
# Check WSL2 status
wsl --status

# Update WSL2
wsl --update

# Set default version
wsl --set-default-version 2
```

#### Permission Issues

```powershell
# Run PowerShell as Administrator for:
# - Installing modules system-wide
# - Docker setup tests
# - Firewall configuration tests
# - Service installation tests

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "Running as Administrator: $isAdmin"
```

#### Test Database Connection Failures

```powershell
# Check if containers are running
docker ps -a

# Restart test databases
docker restart postgres-test mongo-test redis-test

# Check container logs
docker logs postgres-test
docker logs mongo-test
docker logs redis-test
```

#### Missing Language Toolchains

For tests requiring optional toolchains (Rust, Go, Java):

```powershell
# Skip tests requiring missing tools
Invoke-Pester -Path .\tests\ -ExcludeTag 'Rust','Go','Java'

# Or install required toolchain (see Language Prerequisites)
```

### Getting Help

- **Documentation**: See `tests\README.md` for test-specific documentation
- **Issues**: Check existing issues on GitHub repository
- **Logs**: Test logs are saved to `.\test-results\` directory

---

## Environment Validation

Before running tests, validate your environment:

```powershell
# Validation script (create this helper)
function Test-ActionRunnerEnvironment {
    Write-Host "Validating ActionRunner Test Environment..." -ForegroundColor Cyan

    $checks = @()

    # PowerShell version
    $checks += [PSCustomObject]@{
        Component = "PowerShell"
        Required = "5.1+"
        Actual = $PSVersionTable.PSVersion.ToString()
        Status = if ($PSVersionTable.PSVersion.Major -ge 5) { "OK" } else { "FAIL" }
    }

    # Pester
    $pester = Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1
    $checks += [PSCustomObject]@{
        Component = "Pester"
        Required = "5.0+"
        Actual = if ($pester) { $pester.Version.ToString() } else { "Not Installed" }
        Status = if ($pester -and $pester.Version.Major -ge 5) { "OK" } else { "FAIL" }
    }

    # Docker
    $dockerVersion = try { (docker --version) 2>&1 } catch { "Not Installed" }
    $checks += [PSCustomObject]@{
        Component = "Docker"
        Required = "Any"
        Actual = if ($dockerVersion -match "version") { $dockerVersion } else { "Not Installed" }
        Status = if ($dockerVersion -match "version") { "OK" } else { "OPTIONAL" }
    }

    # Python
    $pythonVersion = try { (python --version) 2>&1 } catch { "Not Installed" }
    $checks += [PSCustomObject]@{
        Component = "Python"
        Required = "3.8+"
        Actual = if ($pythonVersion -match "Python") { $pythonVersion } else { "Not Installed" }
        Status = if ($pythonVersion -match "Python 3\.([8-9]|[0-9]{2})") { "OK" } else { "OPTIONAL" }
    }

    # Node.js
    $nodeVersion = try { (node --version) 2>&1 } catch { "Not Installed" }
    $checks += [PSCustomObject]@{
        Component = "Node.js"
        Required = "14+"
        Actual = if ($nodeVersion -match "v") { $nodeVersion } else { "Not Installed" }
        Status = if ($nodeVersion -match "v") { "OK" } else { "OPTIONAL" }
    }

    # Display results
    $checks | Format-Table -AutoSize

    $failures = $checks | Where-Object { $_.Status -eq "FAIL" }
    if ($failures) {
        Write-Host "`nRequired components missing or outdated:" -ForegroundColor Red
        $failures | ForEach-Object { Write-Host "  - $($_.Component): $($_.Actual)" -ForegroundColor Red }
        return $false
    } else {
        Write-Host "`nEnvironment validation passed!" -ForegroundColor Green
        return $true
    }
}

# Run validation
Test-ActionRunnerEnvironment
```

---

## Quick Setup Script

For a streamlined setup experience:

```powershell
# Quick setup script for core prerequisites
function Install-ActionRunnerTestPrerequisites {
    param(
        [switch]$IncludeOptional
    )

    Write-Host "Installing ActionRunner Test Prerequisites..." -ForegroundColor Cyan

    # Install Pester
    Write-Host "Installing Pester..." -ForegroundColor Yellow
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck -Scope CurrentUser

    if ($IncludeOptional) {
        # Install optional components via winget
        Write-Host "Installing optional components..." -ForegroundColor Yellow

        $components = @(
            @{ Name = "Python.Python.3.11"; DisplayName = "Python 3.11" },
            @{ Name = "OpenJS.NodeJS.LTS"; DisplayName = "Node.js LTS" },
            @{ Name = "Microsoft.DotNet.SDK.8"; DisplayName = ".NET 8 SDK" },
            @{ Name = "Docker.DockerDesktop"; DisplayName = "Docker Desktop" }
        )

        foreach ($component in $components) {
            Write-Host "Installing $($component.DisplayName)..." -ForegroundColor Yellow
            try {
                winget install $component.Name --silent --accept-source-agreements --accept-package-agreements
            } catch {
                Write-Host "  Failed to install $($component.DisplayName): $_" -ForegroundColor Red
            }
        }
    }

    Write-Host "`nSetup complete! Run Test-ActionRunnerEnvironment to validate." -ForegroundColor Green
}

# Example usage:
# Install-ActionRunnerTestPrerequisites
# Install-ActionRunnerTestPrerequisites -IncludeOptional
```

---

## Next Steps

1. Validate your environment using the validation script
2. Run the test suite: `.\tests\run-tests.ps1`
3. Review test results in `.\test-results\`
4. For CI/CD integration, see `tests\README.md`

For specific test requirements, refer to the individual test files and their documentation headers.
