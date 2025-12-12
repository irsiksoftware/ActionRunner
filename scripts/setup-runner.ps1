<#
.SYNOPSIS
    Sets up a self-hosted GitHub Actions runner for ActionRunner infrastructure.

.DESCRIPTION
    This script automates the installation and configuration of GitHub Actions runners
    for Dakota Irsik's private repository infrastructure. It handles download, installation,
    configuration, and service setup with security best practices.

.PARAMETER RepoUrl
    The GitHub repository URL (e.g., https://github.com/DakotaIrsik/ActionRunner)

.PARAMETER Token
    GitHub runner registration token (get from repo Settings > Actions > Runners)

.PARAMETER RunnerName
    Name for this runner instance (default: hostname-runner)

.PARAMETER Labels
    Comma-separated list of labels (default: self-hosted,windows)

.PARAMETER WorkDirectory
    Runner work directory (default: C:\actions-runner)

.PARAMETER RunAsService
    Install runner as a Windows service (default: true)

.EXAMPLE
    .\setup-runner.ps1 -RepoUrl "https://github.com/DakotaIrsik/ActionRunner" -Token "ABC123..."

.EXAMPLE
    .\setup-runner.ps1 -RepoUrl "https://github.com/DakotaIrsik/QiFlow" -Token "XYZ789..." -Labels "self-hosted,windows,unity"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoUrl,

    [Parameter(Mandatory = $true)]
    [string]$Token,

    [Parameter(Mandatory = $false)]
    [string]$RunnerName = "$env:COMPUTERNAME-runner",

    [Parameter(Mandatory = $false)]
    [string]$Labels = "self-hosted,windows",

    [Parameter(Mandatory = $false)]
    [string]$WorkDirectory = "C:\actions-runner",

    [Parameter(Mandatory = $false)]
    [bool]$RunAsService = $true
)

$ErrorActionPreference = "Stop"

# Logging setup
$LogFile = "C:\Code\ActionRunner\logs\runner-setup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $LogFile -Value $logMessage
}

Write-Log "Starting GitHub Actions runner setup"
Write-Log "Repository: $RepoUrl"
Write-Log "Runner Name: $RunnerName"
Write-Log "Labels: $Labels"
Write-Log "Work Directory: $WorkDirectory"

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and $RunAsService) {
    Write-Log "ERROR: Must run as Administrator to install as service" "ERROR"
    throw "This script requires Administrator privileges when RunAsService is true"
}

# Create work directory
Write-Log "Creating work directory: $WorkDirectory"
if (-not (Test-Path $WorkDirectory)) {
    New-Item -Path $WorkDirectory -ItemType Directory -Force | Out-Null
}

# Download latest runner
Write-Log "Downloading GitHub Actions runner..."
$runnerVersion = "2.311.0"  # Latest stable version as of Oct 2025
$runnerUrl = "https://github.com/actions/runner/releases/download/v$runnerVersion/actions-runner-win-x64-$runnerVersion.zip"
$runnerZip = Join-Path $WorkDirectory "actions-runner.zip"

try {
    Invoke-WebRequest -Uri $runnerUrl -OutFile $runnerZip
    Write-Log "Downloaded runner to $runnerZip"
} catch {
    Write-Log "ERROR downloading runner: $_" "ERROR"
    throw
}

# Extract runner
Write-Log "Extracting runner..."
try {
    Expand-Archive -Path $runnerZip -DestinationPath $WorkDirectory -Force
    Remove-Item $runnerZip
    Write-Log "Runner extracted successfully"
} catch {
    Write-Log "ERROR extracting runner: $_" "ERROR"
    throw
}

# Configure runner
Write-Log "Configuring runner..."
Push-Location $WorkDirectory
try {
    $configArgs = @(
        "--url", $RepoUrl,
        "--token", $Token,
        "--name", $RunnerName,
        "--labels", $Labels,
        "--work", "_work",
        "--unattended",
        "--replace"
    )

    if ($RunAsService) {
        $configArgs += "--runasservice"
    }

    & .\config.cmd $configArgs
    Write-Log "Runner configured successfully"

    # Install and start service
    if ($RunAsService) {
        Write-Log "Installing runner as Windows service..."
        & .\svc.cmd install
        Write-Log "Starting runner service..."
        & .\svc.cmd start

        # Verify service is running
        Start-Sleep -Seconds 5
        $serviceName = Get-Service -Name "actions.runner.*" | Where-Object { $_.Status -eq 'Running' } | Select-Object -First 1
        if ($serviceName) {
            Write-Log "Runner service started successfully: $($serviceName.Name)"
        } else {
            Write-Log "WARNING: Runner service may not have started correctly" "WARN"
        }
    } else {
        Write-Log "Runner configured but not installed as service (manual start required)"
    }

} catch {
    Write-Log "ERROR configuring runner: $_" "ERROR"
    throw
} finally {
    Pop-Location
}

# Create status report
Write-Log "=== Runner Setup Complete ==="
Write-Log "Repository: $RepoUrl"
Write-Log "Runner Name: $RunnerName"
Write-Log "Labels: $Labels"
Write-Log "Work Directory: $WorkDirectory"
Write-Log "Running as Service: $RunAsService"
Write-Log "Log File: $LogFile"

if ($RunAsService) {
    Write-Log ""
    Write-Log "To check runner status:"
    Write-Log "  Get-Service actions.runner.*"
    Write-Log ""
    Write-Log "To stop runner:"
    Write-Log "  Stop-Service actions.runner.*"
    Write-Log ""
    Write-Log "To start runner:"
    Write-Log "  Start-Service actions.runner.*"
}

Write-Host ""
Write-Host "[OK] Runner setup completed successfully!" -ForegroundColor Green
Write-Host "  Check GitHub repository Settings > Actions > Runners to verify" -ForegroundColor Green
