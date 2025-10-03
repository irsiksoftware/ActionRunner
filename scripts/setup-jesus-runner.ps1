#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Sets up GitHub Actions self-hosted runner for Jesus MCP Agentic AI Platform project.

.DESCRIPTION
    This script automates the complete setup of a self-hosted runner with all requirements
    for the Jesus project, including Node.js, Python, Docker, and security tools.

    Requirements:
    - Node.js 20.x
    - pnpm 9.x
    - Python 3.11
    - Docker with BuildKit support
    - Security tools (pip-audit, detect-secrets, OSV Scanner)

.PARAMETER RunnerPath
    Path for runner installation (default: C:\actions-runner)

.PARAMETER RunnerToken
    GitHub runner registration token (from repo settings)

.PARAMETER RepoUrl
    GitHub repository URL (e.g., https://github.com/username/jesus)

.PARAMETER RunnerName
    Name for this runner (default: hostname)

.PARAMETER SkipDocker
    Skip Docker installation check (use if Docker already configured)

.PARAMETER SkipNodeJs
    Skip Node.js installation (use if already installed)

.PARAMETER SkipPython
    Skip Python installation (use if already installed)

.EXAMPLE
    .\setup-jesus-runner.ps1 -RepoUrl "https://github.com/user/jesus" -RunnerToken "ABC123..."

.EXAMPLE
    .\setup-jesus-runner.ps1 -RepoUrl "https://github.com/user/jesus" -RunnerToken "ABC123..." -SkipDocker

.NOTES
    Author: ActionRunner Team
    Version: 1.0.0
    Created for Issue #30: Setup runner for Jesus project
#>

[CmdletBinding()]
param(
    [string]$RunnerPath = "C:\actions-runner",
    [Parameter(Mandatory=$true)]
    [string]$RunnerToken,
    [Parameter(Mandatory=$true)]
    [string]$RepoUrl,
    [string]$RunnerName = $env:COMPUTERNAME,
    [switch]$SkipDocker,
    [switch]$SkipNodeJs,
    [switch]$SkipPython
)

$ErrorActionPreference = "Stop"
$logFile = "C:\Temp\jesus-runner-setup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Ensure temp directory exists
if (-not (Test-Path "C:\Temp")) {
    New-Item -ItemType Directory -Path "C:\Temp" -Force | Out-Null
}

# Logging function
function Write-SetupLog {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'SUCCESS', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    Add-Content -Path $logFile -Value $logMessage

    switch ($Level) {
        'ERROR' { Write-Host $logMessage -ForegroundColor Red }
        'WARN' { Write-Host $logMessage -ForegroundColor Yellow }
        'SUCCESS' { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }
}

Write-Host "`n=== Jesus Project Runner Setup ===" -ForegroundColor Cyan
Write-Host "Log file: $logFile`n" -ForegroundColor Gray

Write-SetupLog "Starting Jesus project runner setup"
Write-SetupLog "Repository: $RepoUrl"
Write-SetupLog "Runner name: $RunnerName"

# Function to check disk space
function Test-DiskSpace {
    param([int]$RequiredGB = 100)

    Write-SetupLog "Checking disk space..."

    $systemDrive = $env:SystemDrive
    $freeSpaceGB = [math]::Round((Get-PSDrive $systemDrive.Replace(':', '')).Free / 1GB, 2)

    Write-SetupLog "Free disk space: $freeSpaceGB GB (Required: $RequiredGB GB)"

    if ($freeSpaceGB -lt $RequiredGB) {
        Write-SetupLog "Insufficient disk space. Minimum $RequiredGB GB required for Jesus project." "ERROR"
        return $false
    }

    Write-SetupLog "Disk space check passed" "SUCCESS"
    return $true
}

# Function to install Chocolatey
function Install-Chocolatey {
    Write-SetupLog "Checking Chocolatey installation..."

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-SetupLog "Chocolatey already installed" "SUCCESS"
        return $true
    }

    Write-SetupLog "Installing Chocolatey..."

    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        Write-SetupLog "Chocolatey installed successfully" "SUCCESS"
        return $true
    } catch {
        Write-SetupLog "Failed to install Chocolatey: $_" "ERROR"
        return $false
    }
}

# Function to install Node.js 20
function Install-NodeJs {
    if ($SkipNodeJs) {
        Write-SetupLog "Skipping Node.js installation (as requested)" "INFO"
        return $true
    }

    Write-SetupLog "Checking Node.js installation..."

    $nodeVersion = $null
    if (Get-Command node -ErrorAction SilentlyContinue) {
        $nodeVersion = (node --version) -replace 'v', ''
        Write-SetupLog "Node.js version $nodeVersion found"

        if ($nodeVersion -like "20.*") {
            Write-SetupLog "Node.js 20.x already installed" "SUCCESS"
            return $true
        } else {
            Write-SetupLog "Node.js version $nodeVersion found, but v20.x required" "WARN"
        }
    }

    Write-SetupLog "Installing Node.js 20.x..."

    try {
        choco install nodejs-lts --version=20.18.0 -y

        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        $installedVersion = (node --version)
        Write-SetupLog "Node.js installed: $installedVersion" "SUCCESS"
        return $true
    } catch {
        Write-SetupLog "Failed to install Node.js: $_" "ERROR"
        return $false
    }
}

# Function to install pnpm
function Install-Pnpm {
    Write-SetupLog "Checking pnpm installation..."

    if (Get-Command pnpm -ErrorAction SilentlyContinue) {
        $pnpmVersion = (pnpm --version)
        Write-SetupLog "pnpm version $pnpmVersion found"

        if ($pnpmVersion -like "9.*") {
            Write-SetupLog "pnpm 9.x already installed" "SUCCESS"
            return $true
        }
    }

    Write-SetupLog "Installing pnpm 9.x..."

    try {
        npm install -g pnpm@9

        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        $installedVersion = (pnpm --version)
        Write-SetupLog "pnpm installed: $installedVersion" "SUCCESS"

        # Configure pnpm cache
        pnpm config set store-dir "C:\pnpm-store"
        Write-SetupLog "pnpm cache configured: C:\pnpm-store" "SUCCESS"

        return $true
    } catch {
        Write-SetupLog "Failed to install pnpm: $_" "ERROR"
        return $false
    }
}

# Function to install Python 3.11
function Install-Python {
    if ($SkipPython) {
        Write-SetupLog "Skipping Python installation (as requested)" "INFO"
        return $true
    }

    Write-SetupLog "Checking Python installation..."

    $pythonVersion = $null
    if (Get-Command python -ErrorAction SilentlyContinue) {
        $pythonVersion = (python --version) -replace 'Python ', ''
        Write-SetupLog "Python version $pythonVersion found"

        if ($pythonVersion -like "3.11.*") {
            Write-SetupLog "Python 3.11 already installed" "SUCCESS"
            return $true
        } else {
            Write-SetupLog "Python version $pythonVersion found, but 3.11.x required" "WARN"
        }
    }

    Write-SetupLog "Installing Python 3.11..."

    try {
        choco install python311 -y

        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        $installedVersion = (python --version)
        Write-SetupLog "Python installed: $installedVersion" "SUCCESS"

        # Verify pip
        python -m ensurepip --upgrade
        Write-SetupLog "pip verified and upgraded" "SUCCESS"

        return $true
    } catch {
        Write-SetupLog "Failed to install Python: $_" "ERROR"
        return $false
    }
}

# Function to install Python security tools
function Install-PythonSecurityTools {
    Write-SetupLog "Installing Python security tools..."

    try {
        # Install pip-audit
        python -m pip install pip-audit
        Write-SetupLog "pip-audit installed" "SUCCESS"

        # Install detect-secrets
        python -m pip install detect-secrets
        Write-SetupLog "detect-secrets installed" "SUCCESS"

        return $true
    } catch {
        Write-SetupLog "Failed to install Python security tools: $_" "ERROR"
        return $false
    }
}

# Function to check Docker installation
function Test-DockerInstallation {
    if ($SkipDocker) {
        Write-SetupLog "Skipping Docker check (as requested)" "INFO"
        return $true
    }

    Write-SetupLog "Checking Docker installation..."

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-SetupLog "Docker not found. Please install Docker Desktop manually:" "ERROR"
        Write-SetupLog "  1. Download from: https://www.docker.com/products/docker-desktop" "ERROR"
        Write-SetupLog "  2. Install Docker Desktop" "ERROR"
        Write-SetupLog "  3. Enable WSL2 backend (for Windows)" "ERROR"
        Write-SetupLog "  4. Restart this script with -SkipDocker after Docker is installed" "ERROR"
        return $false
    }

    Write-SetupLog "Docker found: $(docker --version)" "SUCCESS"

    # Check Docker Buildx
    Write-SetupLog "Checking Docker Buildx..."
    try {
        $buildxVersion = docker buildx version
        Write-SetupLog "Docker Buildx available: $buildxVersion" "SUCCESS"
    } catch {
        Write-SetupLog "Docker Buildx not available" "ERROR"
        return $false
    }

    # Test Docker connectivity
    Write-SetupLog "Testing Docker connectivity..."
    try {
        docker ps | Out-Null
        Write-SetupLog "Docker is running and accessible" "SUCCESS"
    } catch {
        Write-SetupLog "Docker is not running or not accessible" "ERROR"
        Write-SetupLog "Please start Docker Desktop and try again" "ERROR"
        return $false
    }

    return $true
}

# Function to install OSV Scanner
function Install-OSVScanner {
    Write-SetupLog "Installing OSV Scanner..."

    try {
        $osvPath = "C:\Program Files\osv-scanner"

        if (-not (Test-Path $osvPath)) {
            New-Item -ItemType Directory -Path $osvPath -Force | Out-Null
        }

        # Download OSV Scanner
        $osvUrl = "https://github.com/google/osv-scanner/releases/latest/download/osv-scanner_windows_amd64.exe"
        $osvExe = Join-Path $osvPath "osv-scanner.exe"

        Write-SetupLog "Downloading OSV Scanner from GitHub..."
        Invoke-WebRequest -Uri $osvUrl -OutFile $osvExe

        # Add to PATH
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($currentPath -notlike "*$osvPath*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$osvPath", "Machine")
            $env:Path += ";$osvPath"
        }

        Write-SetupLog "OSV Scanner installed successfully" "SUCCESS"
        return $true
    } catch {
        Write-SetupLog "Failed to install OSV Scanner: $_" "WARN"
        Write-SetupLog "OSV Scanner installation is optional. Workflows will install it if needed." "INFO"
        return $true  # Don't fail on this
    }
}

# Function to install GitHub Actions Runner
function Install-Runner {
    Write-SetupLog "Setting up GitHub Actions Runner..."

    if (Test-Path $RunnerPath) {
        Write-SetupLog "Runner directory already exists: $RunnerPath" "WARN"
        $response = Read-Host "Remove existing directory and reinstall? (y/N)"

        if ($response -eq 'y' -or $response -eq 'Y') {
            Remove-Item -Path $RunnerPath -Recurse -Force
            Write-SetupLog "Removed existing runner directory" "INFO"
        } else {
            Write-SetupLog "Keeping existing runner directory" "INFO"
            return $true
        }
    }

    # Create runner directory
    New-Item -ItemType Directory -Path $RunnerPath -Force | Out-Null
    Write-SetupLog "Created runner directory: $RunnerPath" "SUCCESS"

    # Download latest runner
    Write-SetupLog "Downloading GitHub Actions Runner..."

    try {
        $apiUrl = "https://api.github.com/repos/actions/runner/releases/latest"
        $release = Invoke-RestMethod -Uri $apiUrl -Method Get

        $asset = $release.assets | Where-Object { $_.name -like "*win-x64-*.zip" }
        $downloadUrl = $asset.browser_download_url
        $version = $release.tag_name

        Write-SetupLog "Downloading runner version $version..."

        $zipPath = Join-Path $env:TEMP "actions-runner.zip"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath

        Write-SetupLog "Extracting runner..."
        Expand-Archive -Path $zipPath -DestinationPath $RunnerPath -Force

        Remove-Item -Path $zipPath -Force

        Write-SetupLog "Runner files extracted successfully" "SUCCESS"
        return $true
    } catch {
        Write-SetupLog "Failed to download/extract runner: $_" "ERROR"
        return $false
    }
}

# Function to configure runner
function Configure-Runner {
    Write-SetupLog "Configuring GitHub Actions Runner..."

    try {
        Push-Location $RunnerPath

        # Run configuration
        $configCmd = ".\config.cmd --url $RepoUrl --token $RunnerToken --name $RunnerName --labels self-hosted,Windows,X64,jesus --unattended"

        Write-SetupLog "Running configuration command..."
        Write-SetupLog "Command: config.cmd --url $RepoUrl --name $RunnerName --labels self-hosted,Windows,X64,jesus --unattended" "INFO"

        Invoke-Expression $configCmd

        Write-SetupLog "Runner configured successfully" "SUCCESS"

        Pop-Location
        return $true
    } catch {
        Pop-Location
        Write-SetupLog "Failed to configure runner: $_" "ERROR"
        return $false
    }
}

# Function to install runner as service
function Install-RunnerService {
    Write-SetupLog "Installing runner as Windows service..."

    try {
        Push-Location $RunnerPath

        .\svc.cmd install
        Write-SetupLog "Runner service installed" "SUCCESS"

        .\svc.cmd start
        Write-SetupLog "Runner service started" "SUCCESS"

        # Verify service
        Start-Sleep -Seconds 5
        $service = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue

        if ($service -and $service.Status -eq 'Running') {
            Write-SetupLog "Runner service is running: $($service.Name)" "SUCCESS"
        } else {
            Write-SetupLog "Runner service status unclear" "WARN"
        }

        Pop-Location
        return $true
    } catch {
        Pop-Location
        Write-SetupLog "Failed to install runner service: $_" "ERROR"
        Write-SetupLog "You may need to start the runner manually with: .\run.cmd" "WARN"
        return $false
    }
}

# Function to run integration tests
function Test-Setup {
    Write-SetupLog "`n=== Running Integration Tests ===" "INFO"

    $allPassed = $true

    # Test Node.js
    Write-SetupLog "Testing Node.js..."
    try {
        $nodeVer = node --version
        if ($nodeVer -like "v20.*") {
            Write-SetupLog "  ✅ Node.js: $nodeVer" "SUCCESS"
        } else {
            Write-SetupLog "  ❌ Node.js: $nodeVer (expected v20.x)" "ERROR"
            $allPassed = $false
        }
    } catch {
        Write-SetupLog "  ❌ Node.js not accessible" "ERROR"
        $allPassed = $false
    }

    # Test pnpm
    Write-SetupLog "Testing pnpm..."
    try {
        $pnpmVer = pnpm --version
        if ($pnpmVer -like "9.*") {
            Write-SetupLog "  ✅ pnpm: $pnpmVer" "SUCCESS"
        } else {
            Write-SetupLog "  ❌ pnpm: $pnpmVer (expected 9.x)" "ERROR"
            $allPassed = $false
        }
    } catch {
        Write-SetupLog "  ❌ pnpm not accessible" "ERROR"
        $allPassed = $false
    }

    # Test Python
    Write-SetupLog "Testing Python..."
    try {
        $pythonVer = python --version
        if ($pythonVer -like "*3.11.*") {
            Write-SetupLog "  ✅ Python: $pythonVer" "SUCCESS"
        } else {
            Write-SetupLog "  ❌ Python: $pythonVer (expected 3.11.x)" "ERROR"
            $allPassed = $false
        }
    } catch {
        Write-SetupLog "  ❌ Python not accessible" "ERROR"
        $allPassed = $false
    }

    # Test pip
    Write-SetupLog "Testing pip..."
    try {
        $pipVer = pip --version
        Write-SetupLog "  ✅ pip: $pipVer" "SUCCESS"
    } catch {
        Write-SetupLog "  ❌ pip not accessible" "ERROR"
        $allPassed = $false
    }

    # Test Docker
    if (-not $SkipDocker) {
        Write-SetupLog "Testing Docker..."
        try {
            $dockerVer = docker --version
            Write-SetupLog "  ✅ Docker: $dockerVer" "SUCCESS"

            $buildxVer = docker buildx version
            Write-SetupLog "  ✅ Docker Buildx: $buildxVer" "SUCCESS"
        } catch {
            Write-SetupLog "  ❌ Docker not accessible" "ERROR"
            $allPassed = $false
        }
    }

    # Test security tools
    Write-SetupLog "Testing security tools..."
    try {
        pip-audit --version | Out-Null
        Write-SetupLog "  ✅ pip-audit installed" "SUCCESS"
    } catch {
        Write-SetupLog "  ❌ pip-audit not accessible" "ERROR"
        $allPassed = $false
    }

    try {
        detect-secrets --version | Out-Null
        Write-SetupLog "  ✅ detect-secrets installed" "SUCCESS"
    } catch {
        Write-SetupLog "  ❌ detect-secrets not accessible" "ERROR"
        $allPassed = $false
    }

    # Test curl
    Write-SetupLog "Testing curl..."
    try {
        curl --version | Out-Null
        Write-SetupLog "  ✅ curl available" "SUCCESS"
    } catch {
        Write-SetupLog "  ❌ curl not accessible" "ERROR"
        $allPassed = $false
    }

    return $allPassed
}

# Main execution
try {
    Write-SetupLog "`n=== Starting Setup Process ===" "INFO"

    # Check disk space
    if (-not (Test-DiskSpace -RequiredGB 100)) {
        exit 1
    }

    # Install Chocolatey
    if (-not (Install-Chocolatey)) {
        Write-SetupLog "Chocolatey installation required but failed" "ERROR"
        exit 1
    }

    # Install Node.js
    if (-not (Install-NodeJs)) {
        Write-SetupLog "Node.js installation failed" "ERROR"
        exit 1
    }

    # Install pnpm
    if (-not (Install-Pnpm)) {
        Write-SetupLog "pnpm installation failed" "ERROR"
        exit 1
    }

    # Install Python
    if (-not (Install-Python)) {
        Write-SetupLog "Python installation failed" "ERROR"
        exit 1
    }

    # Install Python security tools
    if (-not (Install-PythonSecurityTools)) {
        Write-SetupLog "Python security tools installation failed" "ERROR"
        exit 1
    }

    # Check Docker
    if (-not (Test-DockerInstallation)) {
        Write-SetupLog "Docker check failed" "ERROR"
        Write-SetupLog "Please install Docker Desktop and run script again with -SkipDocker" "ERROR"
        exit 1
    }

    # Install OSV Scanner
    Install-OSVScanner

    # Install and configure runner
    if (-not (Install-Runner)) {
        Write-SetupLog "Runner installation failed" "ERROR"
        exit 1
    }

    if (-not (Configure-Runner)) {
        Write-SetupLog "Runner configuration failed" "ERROR"
        exit 1
    }

    # Install as service
    Install-RunnerService

    # Run integration tests
    Write-SetupLog "`n=== Integration Tests ===" "INFO"
    $testsPass = Test-Setup

    # Success summary
    Write-Host "`n============================================" -ForegroundColor Green
    Write-Host "    Jesus Project Runner Setup Complete!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "✅ Node.js 20.x installed" -ForegroundColor Green
    Write-Host "✅ pnpm 9.x installed" -ForegroundColor Green
    Write-Host "✅ Python 3.11 installed" -ForegroundColor Green
    Write-Host "✅ Security tools installed" -ForegroundColor Green
    if (-not $SkipDocker) {
        Write-Host "✅ Docker verified" -ForegroundColor Green
    }
    Write-Host "✅ Runner configured and started" -ForegroundColor Green
    Write-Host ""

    if ($testsPass) {
        Write-Host "All integration tests PASSED!" -ForegroundColor Green
    } else {
        Write-Host "Some integration tests FAILED. Check log for details." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Verify runner appears in GitHub repo settings" -ForegroundColor White
    Write-Host "2. Trigger a workflow to test the setup" -ForegroundColor White
    Write-Host "3. Monitor first job execution" -ForegroundColor White
    Write-Host ""
    Write-Host "Log file: $logFile" -ForegroundColor Gray
    Write-Host ""

    Write-SetupLog "Setup completed successfully!" "SUCCESS"
    exit 0

} catch {
    Write-SetupLog "Fatal error during setup: $_" "ERROR"
    Write-SetupLog $_.ScriptStackTrace "ERROR"

    Write-Host "`n❌ Setup failed. Check log file: $logFile" -ForegroundColor Red
    exit 1
}
