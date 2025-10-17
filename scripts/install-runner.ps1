<#
.SYNOPSIS
    Automated installation and setup script for GitHub Actions self-hosted runner on Windows.

.DESCRIPTION
    This script performs a complete installation of a GitHub Actions self-hosted runner including:
    - Prerequisites validation (Git, PowerShell, disk space)
    - Latest runner download and installation
    - Runner configuration with organization-level access
    - Optional Windows service setup
    - Firewall configuration
    - Working directory and cache setup
    Comprehensive error handling and logging throughout the process.

.PARAMETER OrgOrRepo
    The organization name (e.g., "myorg") or full repository path (e.g., "owner/repo")

.PARAMETER Token
    GitHub Personal Access Token (PAT) with admin:org or repo permissions
    For organization: requires admin:org scope
    For repository: requires repo scope

.PARAMETER RunnerName
    Custom name for the runner (default: hostname)

.PARAMETER Labels
    Comma-separated list of labels for the runner
    Default: "self-hosted,gpu-cuda,unity,dotnet,python,windows"

.PARAMETER WorkFolder
    Working directory for the runner (default: C:\actions-runner)

.PARAMETER CacheFolder
    Cache directory for build artifacts (default: C:\actions-runner-cache)

.PARAMETER IsOrg
    Switch to indicate this is an organization-level runner (recommended)

.PARAMETER InstallService
    Switch to install the runner as a Windows service for automatic startup

.PARAMETER SkipPrerequisites
    Skip prerequisites validation (not recommended)

.PARAMETER SkipFirewall
    Skip firewall configuration

.PARAMETER InstallNodeJS
    Install Node.js 20 and pnpm 9 for JavaScript development

.PARAMETER InstallPython
    Install Python 3.11 and security tools (pip-audit, detect-secrets)

.PARAMETER InstallDocker
    Verify and configure Docker installation with BuildKit support

.PARAMETER InstallJesusStack
    Install complete stack for Jesus MCP project (Node.js + Python + Docker)

.EXAMPLE
    .\install-runner.ps1 -OrgOrRepo "DakotaIrsik" -Token "ghp_xxx" -IsOrg -InstallService

    Installs an organization-level runner with default labels as a Windows service

.EXAMPLE
    .\install-runner.ps1 -OrgOrRepo "owner/repo" -Token "ghp_xxx" -Labels "self-hosted,windows,dotnet"

    Installs a repository-level runner with custom labels

.EXAMPLE
    .\install-runner.ps1 -OrgOrRepo "DakotaIrsik" -Token "ghp_xxx" -IsOrg -InstallJesusStack

    Installs runner with complete Jesus project stack (Node.js 20, Python 3.11, Docker)

.NOTES
    Requires PowerShell 5.1+ and administrator privileges for service installation
    Minimum requirements: 8GB RAM, 50GB free disk space, Windows 10/11 or Server 2019+
    See docs/hardware-specs.md for recommended specifications
    GitHub documentation: https://docs.github.com/en/actions/hosting-your-own-runners
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "GitHub organization or repository (e.g., 'myorg' or 'owner/repo')")]
    [string]$OrgOrRepo,

    [Parameter(Mandatory = $true, HelpMessage = "GitHub Personal Access Token with admin:org or repo permissions")]
    [string]$Token,

    [Parameter(Mandatory = $false)]
    [string]$RunnerName = $env:COMPUTERNAME,

    [Parameter(Mandatory = $false)]
    [string]$Labels = "self-hosted,gpu-cuda,unity,dotnet,python,windows",

    [Parameter(Mandatory = $false)]
    [string]$WorkFolder = "C:\actions-runner",

    [Parameter(Mandatory = $false)]
    [string]$CacheFolder = "C:\actions-runner-cache",

    [Parameter(Mandatory = $false)]
    [switch]$IsOrg,

    [Parameter(Mandatory = $false)]
    [switch]$InstallService,

    [Parameter(Mandatory = $false)]
    [switch]$SkipPrerequisites,

    [Parameter(Mandatory = $false)]
    [switch]$SkipFirewall,

    [Parameter(Mandatory = $false)]
    [switch]$InstallNodeJS,

    [Parameter(Mandatory = $false)]
    [switch]$InstallPython,

    [Parameter(Mandatory = $false)]
    [switch]$InstallDocker,

    [Parameter(Mandatory = $false)]
    [switch]$InstallJesusStack
)

$ErrorActionPreference = "Stop"
$LogFile = Join-Path $env:TEMP "runner-install-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Logging function
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }

    Write-Host $logMessage -ForegroundColor $color
    Add-Content -Path $LogFile -Value $logMessage
}

function Test-Administrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Prerequisites {
    Write-Log "Validating prerequisites..." "INFO"
    $errors = @()

    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5) {
        $errors += "PowerShell 5.1 or higher required (current: $($psVersion.ToString()))"
    } else {
        Write-Log "PowerShell version: $($psVersion.ToString())" "SUCCESS"
    }

    # Check OS version
    $os = Get-CimInstance Win32_OperatingSystem
    $osVersion = [System.Version]$os.Version
    if ($osVersion.Major -lt 10) {
        $errors += "Windows 10/11 or Server 2019+ required (current: $($os.Caption))"
    } else {
        Write-Log "Operating System: $($os.Caption)" "SUCCESS"
    }

    # Check Git installation
    try {
        $gitVersion = git --version 2>$null
        Write-Log "Git installed: $gitVersion" "SUCCESS"
    } catch {
        $errors += "Git is not installed or not in PATH. Install from https://git-scm.com/"
    }

    # Check available disk space
    $drive = (Split-Path $WorkFolder -Qualifier)
    $disk = Get-PSDrive $drive.TrimEnd(':') -ErrorAction SilentlyContinue
    if ($disk) {
        $freeSpaceGB = [math]::Round($disk.Free / 1GB, 2)
        if ($freeSpaceGB -lt 50) {
            $errors += "Insufficient disk space. Required: 50GB, Available: ${freeSpaceGB}GB on drive $drive"
        } else {
            Write-Log "Available disk space: ${freeSpaceGB}GB on drive $drive" "SUCCESS"
        }
    }

    # Check available RAM
    $ram = Get-CimInstance Win32_ComputerSystem
    $ramGB = [math]::Round($ram.TotalPhysicalMemory / 1GB, 2)
    if ($ramGB -lt 8) {
        $errors += "Insufficient RAM. Recommended: 32GB+, Minimum: 8GB, Available: ${ramGB}GB"
    } else {
        Write-Log "Total RAM: ${ramGB}GB" "SUCCESS"
    }

    # Check internet connectivity
    try {
        $null = Invoke-WebRequest -Uri "https://api.github.com" -UseBasicParsing -TimeoutSec 10
        Write-Log "Internet connectivity to GitHub: OK" "SUCCESS"
    } catch {
        $errors += "Cannot reach GitHub API. Check internet connection and firewall settings."
    }

    if ($errors.Count -gt 0) {
        Write-Log "Prerequisites validation failed:" "ERROR"
        foreach ($prereqError in $errors) {
            Write-Log "  - $prereqError" "ERROR"
        }
        return $false
    }

    Write-Log "All prerequisites validated successfully" "SUCCESS"
    return $true
}

function Install-Runner {
    Write-Log "Starting runner installation..." "INFO"

    # Create work folders
    foreach ($folder in @($WorkFolder, $CacheFolder)) {
        if (-not (Test-Path $folder)) {
            Write-Log "Creating folder: $folder"
            New-Item -ItemType Directory -Path $folder -Force | Out-Null
        } else {
            Write-Log "Folder already exists: $folder" "WARN"
        }
    }

    Set-Location $WorkFolder

    # Download latest runner
    Write-Log "Fetching latest runner version from GitHub..."
    try {
        $latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/actions/runner/releases/latest" -Headers @{
            "Accept" = "application/vnd.github+json"
        }
    } catch {
        Write-Log "Failed to fetch runner releases: $($_.Exception.Message)" "ERROR"
        throw
    }

    $version = $latestRelease.tag_name.TrimStart('v')
    $asset = $latestRelease.assets | Where-Object { $_.name -like "*win-x64-*.zip" } | Select-Object -First 1

    if (-not $asset) {
        Write-Log "Failed to find Windows x64 runner asset in release" "ERROR"
        throw "No suitable runner package found"
    }

    $downloadUrl = $asset.browser_download_url
    $zipFile = "actions-runner-win-x64-$version.zip"

    Write-Log "Downloading runner version $version..." "INFO"
    Write-Log "URL: $downloadUrl"

    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile -UseBasicParsing
        Write-Log "Download completed successfully" "SUCCESS"
    } catch {
        Write-Log "Failed to download runner: $($_.Exception.Message)" "ERROR"
        throw
    }

    # Verify download
    if (-not (Test-Path $zipFile)) {
        Write-Log "Downloaded file not found: $zipFile" "ERROR"
        throw "Download verification failed"
    }

    $fileSize = [math]::Round((Get-Item $zipFile).Length / 1MB, 2)
    Write-Log "Downloaded file size: ${fileSize}MB"

    # Extract runner
    Write-Log "Extracting runner package..."
    if (Test-Path ".\bin") {
        Write-Log "Runner binaries already exist, removing old installation..." "WARN"
        Remove-Item ".\bin", ".\externals" -Recurse -Force -ErrorAction SilentlyContinue
    }

    try {
        Expand-Archive -Path $zipFile -DestinationPath . -Force
        Write-Log "Extraction completed successfully" "SUCCESS"
    } catch {
        Write-Log "Failed to extract runner: $($_.Exception.Message)" "ERROR"
        throw
    }

    # Verify extraction
    if (-not (Test-Path ".\config.cmd")) {
        Write-Log "Runner extraction incomplete - config.cmd not found" "ERROR"
        throw "Extraction verification failed"
    }

    # Cleanup downloaded zip
    Remove-Item $zipFile -Force -ErrorAction SilentlyContinue
    Write-Log "Cleaned up installation files"

    return $version
}

function Register-Runner {
    param([string]$Version)

    Write-Log "Configuring runner registration..." "INFO"

    # Validate token format
    if ($Token -notmatch '^(ghp_|github_pat_)') {
        Write-Log "Invalid token format. Token should start with 'ghp_' or 'github_pat_'" "ERROR"
        throw "Invalid token format"
    }

    # Determine runner URL
    if ($IsOrg) {
        $tokenUrl = "https://api.github.com/orgs/$OrgOrRepo/actions/runners/registration-token"
        $runnerUrl = "https://github.com/$OrgOrRepo"
        Write-Log "Configuring as organization-level runner for: $OrgOrRepo" "INFO"
    } else {
        $tokenUrl = "https://api.github.com/repos/$OrgOrRepo/actions/runners/registration-token"
        $runnerUrl = "https://github.com/$OrgOrRepo"
        Write-Log "Configuring as repository-level runner for: $OrgOrRepo" "INFO"
    }

    # Get registration token from GitHub API
    Write-Log "Requesting registration token from GitHub..."
    try {
        $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Headers @{
            "Accept" = "application/vnd.github+json"
            "Authorization" = "Bearer $Token"
            "X-GitHub-Api-Version" = "2022-11-28"
        }
        $registrationToken = $response.token
        Write-Log "Successfully obtained registration token" "SUCCESS"
    } catch {
        Write-Log "Failed to get registration token: $($_.Exception.Message)" "ERROR"
        Write-Log "Ensure your token has correct permissions:" "ERROR"
        Write-Log "  - For organizations: admin:org scope" "ERROR"
        Write-Log "  - For repositories: repo scope" "ERROR"
        throw
    }

    # Configure runner
    Write-Log "Configuring runner with the following settings:" "INFO"
    Write-Log "  Runner Name: $RunnerName"
    Write-Log "  Labels: $Labels"
    Write-Log "  Work Folder: $WorkFolder\_work"
    Write-Log "  Runner URL: $runnerUrl"

    $configArgs = @(
        "--url", $runnerUrl,
        "--token", $registrationToken,
        "--name", $RunnerName,
        "--labels", $Labels,
        "--work", "_work",
        "--unattended",
        "--replace"
    )

    Write-Log "Executing runner configuration..."
    & .\config.cmd $configArgs 2>&1 | Tee-Object -FilePath $LogFile -Append

    if ($LASTEXITCODE -ne 0) {
        Write-Log "Runner configuration failed with exit code $LASTEXITCODE" "ERROR"
        throw "Configuration failed"
    }

    Write-Log "Runner configured successfully" "SUCCESS"
}

function Install-RunnerService {
    Write-Log "Installing runner as Windows service..." "INFO"

    # Check for admin privileges
    if (-not (Test-Administrator)) {
        Write-Log "Service installation requires administrator privileges" "ERROR"
        Write-Log "Please run this script as Administrator or omit -InstallService" "ERROR"
        throw "Insufficient privileges"
    }

    Write-Log "Installing service..."
    & .\svc.cmd install 2>&1 | Tee-Object -FilePath $LogFile -Append

    if ($LASTEXITCODE -ne 0) {
        Write-Log "Service installation failed with exit code $LASTEXITCODE" "ERROR"
        throw "Service installation failed"
    }

    Write-Log "Starting runner service..."
    & .\svc.cmd start 2>&1 | Tee-Object -FilePath $LogFile -Append

    if ($LASTEXITCODE -ne 0) {
        Write-Log "Service start failed with exit code $LASTEXITCODE" "ERROR"
        throw "Service start failed"
    }

    # Verify service is running
    Start-Sleep -Seconds 2
    $service = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "Running" }
    if ($service) {
        Write-Log "Runner service installed and running: $($service.Name)" "SUCCESS"
    } else {
        Write-Log "Service installed but status verification failed" "WARN"
    }
}

function Set-FirewallRules {
    Write-Log "Configuring Windows Firewall rules..." "INFO"

    if (-not (Test-Administrator)) {
        Write-Log "Firewall configuration requires administrator privileges, skipping..." "WARN"
        return
    }

    try {
        # Allow outbound HTTPS to GitHub
        $ruleName = "GitHub Actions Runner - HTTPS"
        $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

        if ($existingRule) {
            Write-Log "Firewall rule already exists: $ruleName" "INFO"
        } else {
            New-NetFirewallRule -DisplayName $ruleName `
                -Direction Outbound `
                -Action Allow `
                -Protocol TCP `
                -RemotePort 443 `
                -RemoteAddress @("140.82.112.0/20", "143.55.64.0/20", "185.199.108.0/22", "192.30.252.0/22") `
                -Profile Any `
                -ErrorAction Stop | Out-Null
            Write-Log "Created firewall rule: $ruleName" "SUCCESS"
        }
    } catch {
        Write-Log "Failed to configure firewall: $($_.Exception.Message)" "WARN"
        Write-Log "You may need to configure firewall manually" "WARN"
    }
}

function Install-NodeJSAndPnpm {
    Write-Log "Installing Node.js 20 and pnpm 9..." "INFO"

    # Check if Node.js is already installed
    try {
        $nodeVersion = node --version 2>$null
        if ($nodeVersion -match "v20\.") {
            Write-Log "Node.js 20 already installed: $nodeVersion" "SUCCESS"
            $nodeInstalled = $true
        } else {
            Write-Log "Node.js installed but not v20.x (current: $nodeVersion)" "WARN"
            $nodeInstalled = $false
        }
    } catch {
        Write-Log "Node.js not found in PATH" "INFO"
        $nodeInstalled = $false
    }

    # Install Node.js 20 using winget if not installed
    if (-not $nodeInstalled) {
        Write-Log "Installing Node.js 20.x via winget..."
        try {
            winget install OpenJS.NodeJS.LTS --version 20 --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null

            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

            $nodeVersion = node --version 2>$null
            Write-Log "Node.js installed successfully: $nodeVersion" "SUCCESS"
        } catch {
            Write-Log "Failed to install Node.js via winget: $($_.Exception.Message)" "ERROR"
            Write-Log "Please install Node.js 20 manually from https://nodejs.org/" "ERROR"
            throw
        }
    }

    # Check if pnpm is installed
    try {
        $pnpmVersion = pnpm --version 2>$null
        if ($pnpmVersion -match "^9\.") {
            Write-Log "pnpm 9 already installed: $pnpmVersion" "SUCCESS"
        } else {
            Write-Log "pnpm installed but not v9.x (current: $pnpmVersion), upgrading..." "WARN"
            npm install -g pnpm@9 2>&1 | Out-Null
            $pnpmVersion = pnpm --version
            Write-Log "pnpm upgraded to: $pnpmVersion" "SUCCESS"
        }
    } catch {
        Write-Log "Installing pnpm 9.x globally..."
        npm install -g pnpm@9 2>&1 | Out-Null

        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

        $pnpmVersion = pnpm --version
        Write-Log "pnpm installed successfully: $pnpmVersion" "SUCCESS"
    }

    # Configure pnpm cache
    Write-Log "Configuring pnpm cache directory..."
    $pnpmCacheDir = Join-Path $CacheFolder "pnpm-cache"
    if (-not (Test-Path $pnpmCacheDir)) {
        New-Item -ItemType Directory -Path $pnpmCacheDir -Force | Out-Null
    }
    pnpm config set store-dir $pnpmCacheDir 2>&1 | Out-Null
    Write-Log "pnpm cache configured: $pnpmCacheDir" "SUCCESS"
}

function Install-PythonStack {
    Write-Log "Installing Python 3.11 and security tools..." "INFO"

    # Check if Python 3.11 is already installed
    try {
        $pythonVersion = python --version 2>$null
        if ($pythonVersion -match "Python 3\.11\.") {
            Write-Log "Python 3.11 already installed: $pythonVersion" "SUCCESS"
            $pythonInstalled = $true
        } else {
            Write-Log "Python installed but not v3.11.x (current: $pythonVersion)" "WARN"
            $pythonInstalled = $false
        }
    } catch {
        Write-Log "Python not found in PATH" "INFO"
        $pythonInstalled = $false
    }

    # Install Python 3.11 using winget if not installed
    if (-not $pythonInstalled) {
        Write-Log "Installing Python 3.11 via winget..."
        try {
            winget install Python.Python.3.11 --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null

            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

            $pythonVersion = python --version 2>$null
            Write-Log "Python installed successfully: $pythonVersion" "SUCCESS"
        } catch {
            Write-Log "Failed to install Python via winget: $($_.Exception.Message)" "ERROR"
            Write-Log "Please install Python 3.11 manually from https://www.python.org/" "ERROR"
            throw
        }
    }

    # Verify pip is available
    try {
        $pipVersion = pip --version 2>$null
        Write-Log "pip installed: $pipVersion" "SUCCESS"
    } catch {
        Write-Log "pip not found, attempting to install..." "WARN"
        python -m ensurepip --upgrade 2>&1 | Out-Null
        Write-Log "pip installed successfully" "SUCCESS"
    }

    # Install security tools required by Jesus project
    Write-Log "Installing Python security tools (pip-audit, detect-secrets)..."
    try {
        pip install pip-audit detect-secrets --quiet 2>&1 | Out-Null
        Write-Log "Security tools installed successfully" "SUCCESS"
    } catch {
        Write-Log "Failed to install security tools: $($_.Exception.Message)" "WARN"
        Write-Log "You may need to install these manually: pip install pip-audit detect-secrets" "WARN"
    }
}

function Install-DockerStack {
    Write-Log "Checking Docker installation..." "INFO"

    # Check if Docker is installed
    try {
        $dockerVersion = docker --version 2>$null
        Write-Log "Docker already installed: $dockerVersion" "SUCCESS"
    } catch {
        Write-Log "Docker not found in PATH" "ERROR"
        Write-Log "Please install Docker Desktop from https://www.docker.com/products/docker-desktop/" "ERROR"
        Write-Log "After installation, ensure Docker is running and accessible from PowerShell" "ERROR"
        throw "Docker installation required"
    }

    # Check Docker is running
    try {
        docker ps 2>&1 | Out-Null
        Write-Log "Docker daemon is running" "SUCCESS"
    } catch {
        Write-Log "Docker is installed but not running" "WARN"
        Write-Log "Please start Docker Desktop and ensure it's running" "WARN"
    }

    # Check Docker Buildx
    try {
        $buildxVersion = docker buildx version 2>$null
        Write-Log "Docker Buildx available: $buildxVersion" "SUCCESS"
    } catch {
        Write-Log "Docker Buildx not available" "WARN"
        Write-Log "Buildx is required for BuildKit support" "WARN"
    }

    # Enable BuildKit
    Write-Log "Configuring Docker BuildKit..."
    [System.Environment]::SetEnvironmentVariable("DOCKER_BUILDKIT", "1", "Machine")
    $env:DOCKER_BUILDKIT = "1"
    Write-Log "Docker BuildKit enabled" "SUCCESS"
}

function Install-JesusProjectStack {
    Write-Log "Installing complete Jesus project stack (Node.js + Python + Docker)..." "INFO"

    Install-NodeJSAndPnpm
    Install-PythonStack
    Install-DockerStack

    Write-Log "Jesus project stack installation completed" "SUCCESS"

    # Verify all tools
    Write-Log "Verifying installations..." "INFO"
    $verification = @()

    try {
        $nodeVer = node --version
        $verification += "Node.js: $nodeVer"
    } catch {
        $verification += "Node.js: NOT FOUND"
    }

    try {
        $pnpmVer = pnpm --version
        $verification += "pnpm: $pnpmVer"
    } catch {
        $verification += "pnpm: NOT FOUND"
    }

    try {
        $pythonVer = python --version
        $verification += "Python: $pythonVer"
    } catch {
        $verification += "Python: NOT FOUND"
    }

    try {
        $dockerVer = docker --version
        $verification += "Docker: $dockerVer"
    } catch {
        $verification += "Docker: NOT FOUND"
    }

    Write-Host "`n=== Installation Verification ===" -ForegroundColor Cyan
    foreach ($item in $verification) {
        Write-Log $item "INFO"
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "GitHub Actions Runner Installation" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Log "Installation log: $LogFile" "INFO"
Write-Log "Started at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"

try {
    # Check prerequisites
    if (-not $SkipPrerequisites) {
        if (-not (Test-Prerequisites)) {
            Write-Log "Prerequisites check failed. Use -SkipPrerequisites to bypass (not recommended)" "ERROR"
            exit 1
        }
    } else {
        Write-Log "Skipping prerequisites check (not recommended)" "WARN"
    }

    # Check admin privileges if service installation requested
    if ($InstallService -and -not (Test-Administrator)) {
        Write-Log "Administrator privileges required for -InstallService" "ERROR"
        Write-Log "Please run PowerShell as Administrator or omit -InstallService" "ERROR"
        exit 1
    }

    # Install runner
    $version = Install-Runner

    # Register runner
    Register-Runner -Version $version

    # Install as service
    if ($InstallService) {
        Install-RunnerService
    } else {
        Write-Log "Runner configured but not installed as service" "INFO"
        Write-Log "To run the runner manually: .\run.cmd" "INFO"
        Write-Log "To install as service later: .\svc.cmd install" "INFO"
    }

    # Configure firewall
    if (-not $SkipFirewall) {
        Set-FirewallRules
    }

    # Install development stacks if requested
    if ($InstallJesusStack) {
        Install-JesusProjectStack
    } else {
        if ($InstallNodeJS) {
            Install-NodeJSAndPnpm
        }
        if ($InstallPython) {
            Install-PythonStack
        }
        if ($InstallDocker) {
            Install-DockerStack
        }
    }

    # Display success message
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "INSTALLATION COMPLETE!" -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Green

    Write-Log "Runner Name: $RunnerName" "INFO"
    Write-Log "Labels: $Labels" "INFO"
    Write-Log "Work Folder: $WorkFolder" "INFO"
    Write-Log "Cache Folder: $CacheFolder" "INFO"
    Write-Log "Runner URL: https://github.com/$OrgOrRepo" "INFO"

    # Display next steps
    Write-Host "`n=== NEXT STEPS ===" -ForegroundColor Cyan
    Write-Host "1. Verify runner status:" -ForegroundColor White
    Write-Host "   https://github.com/$OrgOrRepo/settings/actions/runners" -ForegroundColor Gray
    Write-Host "`n2. Update your workflows to use self-hosted runner:" -ForegroundColor White
    Write-Host "   runs-on: [self-hosted, windows, <your-labels>]" -ForegroundColor Gray
    Write-Host "`n3. Monitor runner logs:" -ForegroundColor White
    Write-Host "   Get-Content '$WorkFolder\_diag\Runner_*.log' -Tail 50 -Wait" -ForegroundColor Gray
    Write-Host "`n4. Set up workspace cleanup (recommended):" -ForegroundColor White
    Write-Host "   See docs/installation.md for automation scripts" -ForegroundColor Gray
    Write-Host "`n5. Review security and configuration:" -ForegroundColor White
    Write-Host "   - Firewall rules: scripts\apply-firewall-rules.ps1" -ForegroundColor Gray
    Write-Host "   - Log rotation: scripts\rotate-logs.ps1" -ForegroundColor Gray
    Write-Host "   - Health monitoring: scripts\runner-health-check.ps1" -ForegroundColor Gray
    Write-Host "`n" -NoNewline

    Write-Log "Installation log saved to: $LogFile" "INFO"
    Write-Log "Completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "SUCCESS"

} catch {
    Write-Log "Installation failed: $($_.Exception.Message)" "ERROR"
    Write-Log "Full error: $($_ | Out-String)" "ERROR"
    Write-Log "Installation log: $LogFile" "ERROR"
    exit 1
}
