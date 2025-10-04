<#
.SYNOPSIS
    Manage both Windows and Linux (WSL2) GitHub Actions runners.

.DESCRIPTION
    Central management script for your dual-runner setup.
    Control both Windows and Linux runners from one place!

.PARAMETER Action
    Action to perform: status, start, stop, restart, logs

.PARAMETER Runner
    Which runner: windows, linux, or both (default: both)

.PARAMETER DistroName
    WSL2 distro name (default: Ubuntu)

.PARAMETER Follow
    Follow logs in real-time (for logs action)

.EXAMPLE
    .\manage-runners.ps1 -Action status
    # Show status of both runners

.EXAMPLE
    .\manage-runners.ps1 -Action stop -Runner linux
    # Stop only the Linux runner

.EXAMPLE
    .\manage-runners.ps1 -Action logs -Runner linux -Follow
    # Follow Linux runner logs in real-time

.EXAMPLE
    .\manage-runners.ps1 -Action restart
    # Restart both runners
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('status', 'start', 'stop', 'restart', 'logs')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [ValidateSet('windows', 'linux', 'both')]
    [string]$Runner = 'both',

    [Parameter(Mandatory = $false)]
    [string]$DistroName = 'Ubuntu',

    [Parameter(Mandatory = $false)]
    [switch]$Follow
)

$ErrorActionPreference = "Continue"

# Colors
function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "=== $Text ===" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Success {
    param([string]$Text)
    Write-Host "✅ $Text" -ForegroundColor Green
}

function Write-Error2 {
    param([string]$Text)
    Write-Host "❌ $Text" -ForegroundColor Red
}

function Write-Warning2 {
    param([string]$Text)
    Write-Host "⚠️  $Text" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Text)
    Write-Host "ℹ️  $Text" -ForegroundColor Cyan
}

# ==============================================================================
# STATUS FUNCTIONS
# ==============================================================================

function Get-WindowsRunnerStatus {
    Write-Header "Windows Runner Status"

    $service = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue

    if ($null -eq $service) {
        Write-Error2 "Windows runner service not found"
        Write-Info "Install with: .\scripts\setup-runner.ps1"
        return $false
    }

    foreach ($svc in $service) {
        $statusColor = if ($svc.Status -eq 'Running') { 'Green' } else { 'Red' }
        $statusIcon = if ($svc.Status -eq 'Running') { '✅' } else { '❌' }

        Write-Host "$statusIcon Name:      " -NoNewline
        Write-Host $svc.Name

        Write-Host "   Status:    " -NoNewline
        Write-Host $svc.Status -ForegroundColor $statusColor

        Write-Host "   StartType: " -NoNewline
        Write-Host $svc.StartType
    }

    return $service.Status -eq 'Running'
}

function Get-LinuxRunnerStatus {
    Write-Header "Linux Runner Status (WSL2)"

    # Check if WSL2 distro exists
    $wslList = wsl --list --quiet 2>&1
    if ($wslList -notmatch $DistroName) {
        Write-Error2 "WSL2 distro '$DistroName' not found"
        Write-Info "Install with: wsl --install -d Ubuntu"
        return $false
    }

    # Check if runner service exists in WSL2
    $serviceCheck = wsl -d $DistroName bash -c "systemctl list-units --all | grep -c 'actions.runner'" 2>&1

    if ($serviceCheck -eq "0") {
        Write-Error2 "Linux runner service not found in WSL2"
        Write-Info "Install with: .\scripts\setup-wsl2-runner.ps1"
        return $false
    }

    # Get detailed status
    Write-Host "Distro: $DistroName"
    Write-Host ""

    $statusOutput = wsl -d $DistroName sudo systemctl status actions.runner.* --no-pager 2>&1

    # Parse status
    if ($statusOutput -match "Active: active \(running\)") {
        Write-Success "Runner is active and running"
        $isRunning = $true
    } elseif ($statusOutput -match "Active: inactive \(dead\)") {
        Write-Error2 "Runner is stopped"
        $isRunning = $false
    } else {
        Write-Warning2 "Unknown status"
        $isRunning = $false
    }

    # Show key information
    Write-Host ""
    Write-Host "Details:" -ForegroundColor Yellow
    $statusOutput | Select-String -Pattern "Loaded:|Active:|Main PID:|Memory:|CPU:" | ForEach-Object {
        Write-Host "  $_"
    }

    return $isRunning
}

# ==============================================================================
# CONTROL FUNCTIONS
# ==============================================================================

function Start-WindowsRunner {
    Write-Header "Starting Windows Runner"

    $service = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue

    if ($null -eq $service) {
        Write-Error2 "Windows runner service not found"
        return
    }

    if ($service.Status -eq 'Running') {
        Write-Success "Already running"
        return
    }

    try {
        Start-Service $service.Name
        Start-Sleep -Seconds 2
        $service.Refresh()

        if ($service.Status -eq 'Running') {
            Write-Success "Started successfully"
        } else {
            Write-Error2 "Failed to start"
        }
    } catch {
        Write-Error2 "Error starting service: $_"
    }
}

function Stop-WindowsRunner {
    Write-Header "Stopping Windows Runner"

    $service = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue

    if ($null -eq $service) {
        Write-Error2 "Windows runner service not found"
        return
    }

    if ($service.Status -eq 'Stopped') {
        Write-Success "Already stopped"
        return
    }

    try {
        Stop-Service $service.Name
        Start-Sleep -Seconds 2
        $service.Refresh()

        if ($service.Status -eq 'Stopped') {
            Write-Success "Stopped successfully"
        } else {
            Write-Error2 "Failed to stop"
        }
    } catch {
        Write-Error2 "Error stopping service: $_"
    }
}

function Start-LinuxRunner {
    Write-Header "Starting Linux Runner (WSL2)"

    try {
        wsl -d $DistroName sudo systemctl start actions.runner.*

        Start-Sleep -Seconds 2

        $status = wsl -d $DistroName sudo systemctl is-active actions.runner.* 2>&1

        if ($status -eq "active") {
            Write-Success "Started successfully"
        } else {
            Write-Error2 "Failed to start (status: $status)"
        }
    } catch {
        Write-Error2 "Error starting service: $_"
    }
}

function Stop-LinuxRunner {
    Write-Header "Stopping Linux Runner (WSL2)"

    try {
        wsl -d $DistroName sudo systemctl stop actions.runner.*

        Start-Sleep -Seconds 2

        $status = wsl -d $DistroName sudo systemctl is-active actions.runner.* 2>&1

        if ($status -eq "inactive") {
            Write-Success "Stopped successfully"
        } else {
            Write-Error2 "Failed to stop (status: $status)"
        }
    } catch {
        Write-Error2 "Error stopping service: $_"
    }
}

function Get-WindowsRunnerLogs {
    Write-Header "Windows Runner Logs"
    Write-Info "Showing Windows Event Log entries..."
    Write-Host ""

    # Windows runners don't have great logging, show what we can
    Get-EventLog -LogName Application -Source "actions-runner-*" -Newest 20 -ErrorAction SilentlyContinue | Format-Table TimeGenerated, EntryType, Message -AutoSize
}

function Get-LinuxRunnerLogs {
    Write-Header "Linux Runner Logs (WSL2)"

    if ($Follow) {
        Write-Info "Following logs... (Press Ctrl+C to exit)"
        Write-Host ""
        wsl -d $DistroName sudo journalctl -u actions.runner.* -f
    } else {
        Write-Info "Showing last 50 lines..."
        Write-Host ""
        wsl -d $DistroName sudo journalctl -u actions.runner.* -n 50 --no-pager
    }
}

# ==============================================================================
# MAIN LOGIC
# ==============================================================================

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   GitHub Actions Runner Manager (Dual Setup) ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Cyan

$doWindows = ($Runner -eq 'windows' -or $Runner -eq 'both')
$doLinux = ($Runner -eq 'linux' -or $Runner -eq 'both')

switch ($Action) {
    'status' {
        if ($doWindows) { $windowsOk = Get-WindowsRunnerStatus }
        if ($doLinux) { $linuxOk = Get-LinuxRunnerStatus }

        Write-Host ""
        Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan

        if ($doWindows -and $doLinux) {
            if ($windowsOk -and $linuxOk) {
                Write-Success "Both runners are operational!"
            } else {
                Write-Warning2 "One or more runners have issues"
            }
        }
    }

    'start' {
        if ($doWindows) { Start-WindowsRunner }
        if ($doLinux) { Start-LinuxRunner }
    }

    'stop' {
        if ($doWindows) { Stop-WindowsRunner }
        if ($doLinux) { Stop-LinuxRunner }
    }

    'restart' {
        if ($doWindows) {
            Stop-WindowsRunner
            Start-Sleep -Seconds 1
            Start-WindowsRunner
        }
        if ($doLinux) {
            Stop-LinuxRunner
            Start-Sleep -Seconds 1
            Start-LinuxRunner
        }
    }

    'logs' {
        if ($doWindows) { Get-WindowsRunnerLogs }
        if ($doLinux) { Get-LinuxRunnerLogs }
    }
}

Write-Host ""
