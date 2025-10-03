#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Enable or disable maintenance mode for GitHub Actions self-hosted runner.

.DESCRIPTION
    This script manages runner maintenance mode by:
    - Enabling maintenance mode (stops runner, prevents new jobs)
    - Disabling maintenance mode (restarts runner)
    - Scheduling maintenance windows
    - Checking current maintenance status
    - Waiting for active jobs to complete before entering maintenance

.PARAMETER Action
    Action to perform: Enable, Disable, or Status

.PARAMETER RunnerPath
    Path to runner installation directory (default: C:\actions-runner)

.PARAMETER MaxWaitMinutes
    Maximum time to wait for jobs to complete before enabling maintenance (default: 30)

.PARAMETER Force
    Force maintenance mode even if jobs are running

.PARAMETER Schedule
    Schedule maintenance mode for a future time (format: "yyyy-MM-dd HH:mm")

.EXAMPLE
    .\maintenance-mode.ps1 -Action Enable
    Enable maintenance mode, waiting for jobs to complete

.EXAMPLE
    .\maintenance-mode.ps1 -Action Disable
    Disable maintenance mode and restart runner

.EXAMPLE
    .\maintenance-mode.ps1 -Action Status
    Check current maintenance mode status

.EXAMPLE
    .\maintenance-mode.ps1 -Action Enable -Schedule "2024-01-15 02:00"
    Schedule maintenance mode to start at 2:00 AM on Jan 15

.NOTES
    Author: GitHub Actions Runner Team
    Version: 1.0.0
    Requires: Administrator privileges
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Enable', 'Disable', 'Status')]
    [string]$Action,

    [string]$RunnerPath = "C:\actions-runner",
    [int]$MaxWaitMinutes = 30,
    [switch]$Force,
    [string]$Schedule
)

$ErrorActionPreference = "Stop"
$maintenanceFile = Join-Path $RunnerPath ".maintenance"
$logFile = Join-Path $RunnerPath "logs\maintenance-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Ensure log directory exists
$logDir = Join-Path $RunnerPath "logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Function to log messages
function Write-MaintenanceLog {
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

Write-Host "`n=== GitHub Actions Runner Maintenance Mode ===" -ForegroundColor Cyan
Write-Host "Action: $Action" -ForegroundColor Gray
Write-Host "Log file: $logFile`n" -ForegroundColor Gray

Write-MaintenanceLog "Maintenance mode action: $Action"

# Function to check if runner is busy
function Test-RunnerBusy {
    try {
        $service = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue

        if (-not $service) {
            Write-MaintenanceLog "Runner service not found" "WARN"
            return $false
        }

        if ($service.Status -ne 'Running') {
            Write-MaintenanceLog "Runner service is not running" "INFO"
            return $false
        }

        # Check if runner process is active
        $runnerProcess = Get-Process | Where-Object { $_.ProcessName -like "*Runner.Listener*" }

        if (-not $runnerProcess) {
            return $false
        }

        # Check for active job by CPU usage
        $cpuUsage = (Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue

        if ($cpuUsage -gt 20) {
            Write-MaintenanceLog "Runner appears to be processing a job (CPU: $([math]::Round($cpuUsage, 2))%)" "INFO"
            return $true
        }

        return $false
    } catch {
        Write-MaintenanceLog "Failed to check runner status: $_" "WARN"
        return $false
    }
}

# Function to wait for runner to become idle
function Wait-RunnerIdle {
    param([int]$MaxMinutes)

    Write-MaintenanceLog "Waiting for runner to become idle (max $MaxMinutes minutes)..."

    $startTime = Get-Date
    $timeout = $startTime.AddMinutes($MaxMinutes)

    while ((Get-Date) -lt $timeout) {
        if (-not (Test-RunnerBusy)) {
            Write-MaintenanceLog "Runner is now idle" "SUCCESS"
            return $true
        }

        $elapsed = ((Get-Date) - $startTime).TotalMinutes
        Write-MaintenanceLog "  Still waiting... ($([math]::Round($elapsed, 1)) minutes elapsed)" "INFO"
        Start-Sleep -Seconds 30
    }

    Write-MaintenanceLog "Timeout waiting for runner to become idle" "WARN"
    return $false
}

# Function to enable maintenance mode
function Enable-MaintenanceMode {
    Write-MaintenanceLog "Enabling maintenance mode..."

    # Check if already in maintenance mode
    if (Test-Path $maintenanceFile) {
        $maintenanceInfo = Get-Content $maintenanceFile | ConvertFrom-Json
        Write-MaintenanceLog "Already in maintenance mode since $($maintenanceInfo.EnabledAt)" "WARN"
        return
    }

    # Wait for runner to become idle
    if (-not (Wait-RunnerIdle -MaxMinutes $MaxWaitMinutes)) {
        if (-not $Force) {
            Write-MaintenanceLog "Runner did not become idle. Use -Force to enable anyway." "ERROR"
            exit 1
        } else {
            Write-MaintenanceLog "Forcing maintenance mode despite active jobs" "WARN"
        }
    }

    # Stop runner service
    Write-MaintenanceLog "Stopping runner service..."
    $service = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue

    if ($service) {
        Stop-Service -Name $service.Name -Force
        Start-Sleep -Seconds 3

        $service.Refresh()
        if ($service.Status -eq 'Stopped') {
            Write-MaintenanceLog "Runner service stopped successfully" "SUCCESS"
        } else {
            Write-MaintenanceLog "Failed to stop runner service" "ERROR"
            exit 1
        }
    } else {
        Write-MaintenanceLog "No runner service found" "WARN"

        # Try to stop runner process directly
        $runnerProcess = Get-Process | Where-Object { $_.ProcessName -like "*Runner.Listener*" }
        if ($runnerProcess) {
            $runnerProcess | Stop-Process -Force
            Write-MaintenanceLog "Stopped runner process" "SUCCESS"
        }
    }

    # Create maintenance mode marker file
    $maintenanceInfo = @{
        EnabledAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        EnabledBy = $env:USERNAME
        Reason = "Manual maintenance mode activation"
    } | ConvertTo-Json

    Set-Content -Path $maintenanceFile -Value $maintenanceInfo
    Write-MaintenanceLog "Maintenance mode enabled" "SUCCESS"
    Write-Host "`nRunner is now in maintenance mode and will not accept new jobs." -ForegroundColor Yellow
    Write-Host "To resume: .\maintenance-mode.ps1 -Action Disable`n" -ForegroundColor Gray
}

# Function to disable maintenance mode
function Disable-MaintenanceMode {
    Write-MaintenanceLog "Disabling maintenance mode..."

    # Check if in maintenance mode
    if (-not (Test-Path $maintenanceFile)) {
        Write-MaintenanceLog "Not currently in maintenance mode" "WARN"
        return
    }

    # Remove maintenance marker file
    Remove-Item -Path $maintenanceFile -Force
    Write-MaintenanceLog "Removed maintenance mode marker" "INFO"

    # Start runner service
    Write-MaintenanceLog "Starting runner service..."
    $service = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue

    if ($service) {
        Start-Service -Name $service.Name
        Start-Sleep -Seconds 3

        $service.Refresh()
        if ($service.Status -eq 'Running') {
            Write-MaintenanceLog "Runner service started successfully" "SUCCESS"
        } else {
            Write-MaintenanceLog "Failed to start runner service" "ERROR"
            exit 1
        }
    } else {
        Write-MaintenanceLog "No runner service found. You may need to start manually." "WARN"
    }

    Write-MaintenanceLog "Maintenance mode disabled" "SUCCESS"
    Write-Host "`nRunner is now online and accepting jobs." -ForegroundColor Green
}

# Function to check maintenance mode status
function Get-MaintenanceStatus {
    Write-Host "`n=== Maintenance Mode Status ===" -ForegroundColor Cyan

    if (Test-Path $maintenanceFile) {
        $maintenanceInfo = Get-Content $maintenanceFile | ConvertFrom-Json

        Write-Host "Status: " -NoNewline
        Write-Host "MAINTENANCE MODE ACTIVE" -ForegroundColor Yellow
        Write-Host "Enabled at: $($maintenanceInfo.EnabledAt)" -ForegroundColor Gray
        Write-Host "Enabled by: $($maintenanceInfo.EnabledBy)" -ForegroundColor Gray
        Write-Host "Reason: $($maintenanceInfo.Reason)" -ForegroundColor Gray
    } else {
        Write-Host "Status: " -NoNewline
        Write-Host "OPERATIONAL" -ForegroundColor Green
    }

    # Check service status
    $service = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue
    if ($service) {
        Write-Host "`nService Status: " -NoNewline

        $service.Refresh()
        switch ($service.Status) {
            'Running' { Write-Host "Running" -ForegroundColor Green }
            'Stopped' { Write-Host "Stopped" -ForegroundColor Red }
            default { Write-Host $service.Status -ForegroundColor Yellow }
        }
    } else {
        Write-Host "`nService Status: " -NoNewline
        Write-Host "Not Found" -ForegroundColor Red
    }

    # Check if runner is busy
    $isBusy = Test-RunnerBusy
    Write-Host "Runner Activity: " -NoNewline
    if ($isBusy) {
        Write-Host "Busy (job running)" -ForegroundColor Yellow
    } else {
        Write-Host "Idle" -ForegroundColor Gray
    }

    Write-Host ""
}

# Function to schedule maintenance mode
function Set-MaintenanceSchedule {
    param([string]$ScheduledTime)

    try {
        $scheduleDate = [DateTime]::ParseExact($ScheduledTime, "yyyy-MM-dd HH:mm", $null)

        if ($scheduleDate -le (Get-Date)) {
            Write-MaintenanceLog "Scheduled time must be in the future" "ERROR"
            exit 1
        }

        Write-MaintenanceLog "Scheduling maintenance mode for $scheduleDate..."

        # Create scheduled task
        $taskName = "RunnerMaintenanceMode-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        $scriptPath = $PSCommandPath
        $action = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`" -Action Enable -Force"

        $trigger = New-ScheduledTaskTrigger -Once -At $scheduleDate

        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

        Register-ScheduledTask -TaskName $taskName `
            -Action $action `
            -Trigger $trigger `
            -Principal $principal `
            -Description "Enable runner maintenance mode at scheduled time" | Out-Null

        Write-MaintenanceLog "Scheduled maintenance mode for $scheduleDate" "SUCCESS"
        Write-Host "`nMaintenance mode scheduled for: $scheduleDate" -ForegroundColor Green
        Write-Host "Scheduled task: $taskName" -ForegroundColor Gray
        Write-Host "`nTo cancel: Unregister-ScheduledTask -TaskName '$taskName'`n" -ForegroundColor Gray

    } catch {
        Write-MaintenanceLog "Failed to schedule maintenance mode: $_" "ERROR"
        exit 1
    }
}

# Main execution
try {
    # Verify runner path exists
    if (-not (Test-Path $RunnerPath)) {
        Write-MaintenanceLog "Runner path not found: $RunnerPath" "ERROR"
        exit 1
    }

    # Handle scheduling if specified
    if ($Schedule) {
        if ($Action -ne 'Enable') {
            Write-MaintenanceLog "Scheduling only supported with -Action Enable" "ERROR"
            exit 1
        }

        Set-MaintenanceSchedule -ScheduledTime $Schedule
        exit 0
    }

    # Execute action
    switch ($Action) {
        'Enable' {
            Enable-MaintenanceMode
        }
        'Disable' {
            Disable-MaintenanceMode
        }
        'Status' {
            Get-MaintenanceStatus
        }
    }

    exit 0

} catch {
    Write-MaintenanceLog "Fatal error: $_" "ERROR"
    Write-MaintenanceLog $_.ScriptStackTrace "ERROR"
    exit 1
}
