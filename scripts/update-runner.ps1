#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Safely updates GitHub Actions self-hosted runner to the latest version.

.DESCRIPTION
    This script automates the runner update process with safety checks:
    - Checks for available runner updates
    - Gracefully waits for active jobs to complete
    - Creates backup of current configuration
    - Downloads and installs new runner version
    - Preserves custom configurations
    - Verifies successful installation
    - Rolls back on failure
    - Restarts runner service

.PARAMETER RunnerPath
    Path to runner installation directory (default: C:\actions-runner)

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER SkipBackup
    Skip configuration backup (not recommended)

.PARAMETER Version
    Specific version to install (default: latest)

.PARAMETER MaxWaitMinutes
    Maximum time to wait for jobs to complete (default: 60)

.PARAMETER DryRun
    Simulate update without making changes

.EXAMPLE
    .\update-runner.ps1
    Update to latest version with default settings

.EXAMPLE
    .\update-runner.ps1 -Version "2.311.0" -Force
    Update to specific version without prompts

.EXAMPLE
    .\update-runner.ps1 -DryRun
    Check for updates without applying

.NOTES
    Author: GitHub Actions Runner Team
    Version: 1.0.0
    Requires: Administrator privileges
#>

[CmdletBinding()]
param(
    [string]$RunnerPath = "C:\actions-runner",
    [switch]$Force,
    [switch]$SkipBackup,
    [string]$Version,
    [int]$MaxWaitMinutes = 60,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$logFile = Join-Path $RunnerPath "logs\update-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Ensure log directory exists
$logDir = Join-Path $RunnerPath "logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Function to log messages
function Write-UpdateLog {
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

Write-Host "`n=== GitHub Actions Runner Update Tool ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Log file: $logFile`n" -ForegroundColor Gray

Write-UpdateLog "Starting runner update process"
Write-UpdateLog "Runner path: $RunnerPath"

# Verify runner path exists
if (-not (Test-Path $RunnerPath)) {
    Write-UpdateLog "Runner path not found: $RunnerPath" "ERROR"
    exit 1
}

# Function to get current runner version
function Get-CurrentRunnerVersion {
    $configPath = Join-Path $RunnerPath ".runner"

    if (-not (Test-Path $configPath)) {
        Write-UpdateLog "Runner configuration file not found" "WARN"
        return $null
    }

    try {
        $config = Get-Content $configPath | ConvertFrom-Json
        return $config.agentVersion
    } catch {
        Write-UpdateLog "Failed to parse runner configuration: $_" "WARN"
        return $null
    }
}

# Function to get latest runner version from GitHub API
function Get-LatestRunnerVersion {
    try {
        Write-UpdateLog "Checking for latest runner version..."

        $apiUrl = "https://api.github.com/repos/actions/runner/releases/latest"
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get

        $latestVersion = $response.tag_name -replace '^v', ''
        Write-UpdateLog "Latest available version: $latestVersion" "SUCCESS"

        return @{
            Version = $latestVersion
            DownloadUrl = ($response.assets | Where-Object { $_.name -like "*win-x64-*.zip" }).browser_download_url
            ReleaseNotes = $response.body
        }
    } catch {
        Write-UpdateLog "Failed to check for updates: $_" "ERROR"
        return $null
    }
}

# Function to check if runner is busy
function Test-RunnerBusy {
    try {
        $service = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue

        if (-not $service) {
            Write-UpdateLog "Runner service not found. Runner might be running interactively." "WARN"
            return $false
        }

        # Check if runner process is active
        $runnerProcess = Get-Process | Where-Object { $_.ProcessName -like "*Runner.Listener*" }

        if (-not $runnerProcess) {
            return $false
        }

        # Check for active job by looking at CPU/memory usage patterns
        # This is a heuristic - a more accurate method would require runner API
        $cpuUsage = (Get-Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue

        if ($cpuUsage -gt 20) {
            Write-UpdateLog "Runner appears to be processing a job (CPU: $([math]::Round($cpuUsage, 2))%)" "INFO"
            return $true
        }

        return $false
    } catch {
        Write-UpdateLog "Failed to check runner status: $_" "WARN"
        return $false
    }
}

# Function to wait for runner to become idle
function Wait-RunnerIdle {
    param([int]$MaxMinutes)

    Write-UpdateLog "Waiting for runner to become idle (max $MaxMinutes minutes)..."

    $startTime = Get-Date
    $timeout = $startTime.AddMinutes($MaxMinutes)

    while ((Get-Date) -lt $timeout) {
        if (-not (Test-RunnerBusy)) {
            Write-UpdateLog "Runner is now idle" "SUCCESS"
            return $true
        }

        $elapsed = ((Get-Date) - $startTime).TotalMinutes
        Write-UpdateLog "  Still waiting... ($([math]::Round($elapsed, 1)) minutes elapsed)" "INFO"
        Start-Sleep -Seconds 30
    }

    Write-UpdateLog "Timeout waiting for runner to become idle" "WARN"
    return $false
}

# Function to stop runner service
function Stop-RunnerService {
    try {
        Write-UpdateLog "Stopping runner service..."

        $service = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue

        if ($service) {
            if ($DryRun) {
                Write-UpdateLog "[DRY RUN] Would stop service: $($service.Name)" "INFO"
                return $true
            }

            Stop-Service -Name $service.Name -Force
            Start-Sleep -Seconds 5

            if ($service.Status -eq 'Stopped') {
                Write-UpdateLog "Runner service stopped successfully" "SUCCESS"
                return $true
            } else {
                Write-UpdateLog "Failed to stop runner service" "ERROR"
                return $false
            }
        } else {
            Write-UpdateLog "No runner service found. Runner might be running interactively." "WARN"

            # Try to stop runner process directly
            $runnerProcess = Get-Process | Where-Object { $_.ProcessName -like "*Runner.Listener*" }

            if ($runnerProcess) {
                if (-not $DryRun) {
                    $runnerProcess | Stop-Process -Force
                    Write-UpdateLog "Stopped runner process" "SUCCESS"
                }
            }

            return $true
        }
    } catch {
        Write-UpdateLog "Error stopping runner service: $_" "ERROR"
        return $false
    }
}

# Function to start runner service
function Start-RunnerService {
    try {
        Write-UpdateLog "Starting runner service..."

        $service = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue

        if ($service) {
            if ($DryRun) {
                Write-UpdateLog "[DRY RUN] Would start service: $($service.Name)" "INFO"
                return $true
            }

            Start-Service -Name $service.Name
            Start-Sleep -Seconds 5

            if ($service.Status -eq 'Running') {
                Write-UpdateLog "Runner service started successfully" "SUCCESS"
                return $true
            } else {
                Write-UpdateLog "Failed to start runner service" "ERROR"
                return $false
            }
        } else {
            Write-UpdateLog "No runner service found. You may need to start the runner manually." "WARN"
            return $true
        }
    } catch {
        Write-UpdateLog "Error starting runner service: $_" "ERROR"
        return $false
    }
}

# Function to create backup
function New-RunnerBackup {
    try {
        $backupDir = Join-Path $RunnerPath "backups"
        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        }

        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupPath = Join-Path $backupDir "runner-backup-$timestamp"

        Write-UpdateLog "Creating backup at: $backupPath"

        if ($DryRun) {
            Write-UpdateLog "[DRY RUN] Would create backup" "INFO"
            return $backupPath
        }

        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

        # Backup critical files
        $filesToBackup = @(
            ".runner",
            ".credentials",
            ".credentials_rsaparams",
            ".path"
        )

        foreach ($file in $filesToBackup) {
            $sourcePath = Join-Path $RunnerPath $file
            if (Test-Path $sourcePath) {
                Copy-Item -Path $sourcePath -Destination $backupPath -Force
                Write-UpdateLog "  Backed up: $file" "SUCCESS"
            }
        }

        # Backup config directory if it exists
        $configDir = Join-Path $RunnerPath "config"
        if (Test-Path $configDir) {
            $configBackup = Join-Path $backupPath "config"
            Copy-Item -Path $configDir -Destination $configBackup -Recurse -Force
            Write-UpdateLog "  Backed up config directory" "SUCCESS"
        }

        Write-UpdateLog "Backup created successfully" "SUCCESS"
        return $backupPath
    } catch {
        Write-UpdateLog "Failed to create backup: $_" "ERROR"
        throw
    }
}

# Function to download and install runner
function Install-RunnerUpdate {
    param(
        [string]$DownloadUrl,
        [string]$TargetVersion
    )

    try {
        Write-UpdateLog "Downloading runner version $TargetVersion..."

        $downloadPath = Join-Path $env:TEMP "actions-runner-win-x64-$TargetVersion.zip"

        if ($DryRun) {
            Write-UpdateLog "[DRY RUN] Would download from: $DownloadUrl" "INFO"
            Write-UpdateLog "[DRY RUN] Would install to: $RunnerPath" "INFO"
            return $true
        }

        # Download new version
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $downloadPath
        Write-UpdateLog "Download completed: $downloadPath" "SUCCESS"

        # Extract to runner path (overwriting existing files)
        Write-UpdateLog "Extracting runner files..."
        Expand-Archive -Path $downloadPath -DestinationPath $RunnerPath -Force

        Write-UpdateLog "Runner files extracted successfully" "SUCCESS"

        # Clean up download
        Remove-Item -Path $downloadPath -Force
        Write-UpdateLog "Cleaned up temporary files" "SUCCESS"

        return $true
    } catch {
        Write-UpdateLog "Failed to install runner update: $_" "ERROR"
        return $false
    }
}

# Function to verify installation
function Test-RunnerInstallation {
    try {
        Write-UpdateLog "Verifying runner installation..."

        # Check for critical files
        $requiredFiles = @(
            "run.cmd",
            "config.cmd",
            "Runner.Listener.exe"
        )

        foreach ($file in $requiredFiles) {
            $filePath = Join-Path $RunnerPath $file
            if (-not (Test-Path $filePath)) {
                Write-UpdateLog "Missing required file: $file" "ERROR"
                return $false
            }
        }

        # Verify version
        $newVersion = Get-CurrentRunnerVersion

        if ($newVersion) {
            Write-UpdateLog "Installed version: $newVersion" "SUCCESS"
            return $true
        } else {
            Write-UpdateLog "Could not verify installed version" "WARN"
            return $true  # Don't fail on this
        }
    } catch {
        Write-UpdateLog "Verification failed: $_" "ERROR"
        return $false
    }
}

# Function to restore from backup
function Restore-FromBackup {
    param([string]$BackupPath)

    try {
        Write-UpdateLog "Restoring from backup: $BackupPath" "WARN"

        if (-not (Test-Path $BackupPath)) {
            Write-UpdateLog "Backup path not found: $BackupPath" "ERROR"
            return $false
        }

        # Restore backed up files
        $backupFiles = Get-ChildItem -Path $BackupPath -File
        foreach ($file in $backupFiles) {
            $destPath = Join-Path $RunnerPath $file.Name
            Copy-Item -Path $file.FullName -Destination $destPath -Force
            Write-UpdateLog "  Restored: $($file.Name)" "INFO"
        }

        # Restore config directory if it exists
        $configBackup = Join-Path $BackupPath "config"
        if (Test-Path $configBackup) {
            $configDest = Join-Path $RunnerPath "config"
            Copy-Item -Path $configBackup -Destination $configDest -Recurse -Force
            Write-UpdateLog "  Restored config directory" "INFO"
        }

        Write-UpdateLog "Restore completed" "SUCCESS"
        return $true
    } catch {
        Write-UpdateLog "Failed to restore from backup: $_" "ERROR"
        return $false
    }
}

# Main execution
try {
    # Pre-flight checks
    Write-UpdateLog "=== Pre-Update Checks ===" "INFO"

    # Check disk space
    $drive = (Get-Item $RunnerPath).PSDrive
    $freeSpaceGB = [math]::Round((Get-PSDrive $drive.Name).Free / 1GB, 2)

    Write-UpdateLog "Free disk space: $freeSpaceGB GB"

    if ($freeSpaceGB -lt 5) {
        Write-UpdateLog "Insufficient disk space (minimum 5 GB required)" "ERROR"
        exit 1
    }

    # Get current version
    $currentVersion = Get-CurrentRunnerVersion

    if ($currentVersion) {
        Write-UpdateLog "Current runner version: $currentVersion" "INFO"
    } else {
        Write-UpdateLog "Could not determine current runner version" "WARN"
    }

    # Get latest version or use specified version
    if ($Version) {
        Write-UpdateLog "Target version specified: $Version" "INFO"
        $targetVersion = $Version
        $downloadUrl = "https://github.com/actions/runner/releases/download/v$Version/actions-runner-win-x64-$Version.zip"
    } else {
        $latest = Get-LatestRunnerVersion

        if (-not $latest) {
            Write-UpdateLog "Failed to check for updates" "ERROR"
            exit 1
        }

        $targetVersion = $latest.Version
        $downloadUrl = $latest.DownloadUrl
    }

    # Check if update is needed
    if ($currentVersion -eq $targetVersion) {
        Write-UpdateLog "Runner is already up to date (version $currentVersion)" "SUCCESS"

        if (-not $Force) {
            exit 0
        } else {
            Write-UpdateLog "Forcing reinstall of same version" "WARN"
        }
    }

    # Confirmation
    if (-not $Force -and -not $DryRun) {
        Write-Host "`nReady to update runner:" -ForegroundColor Yellow
        Write-Host "  Current version: $currentVersion" -ForegroundColor Gray
        Write-Host "  Target version: $targetVersion" -ForegroundColor Gray
        Write-Host "  Runner path: $RunnerPath" -ForegroundColor Gray

        $response = Read-Host "`nContinue with update? (y/N)"

        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-UpdateLog "Update cancelled by user" "WARN"
            exit 0
        }
    }

    Write-UpdateLog "`n=== Starting Update Process ===" "INFO"

    # Wait for runner to be idle
    if (-not (Wait-RunnerIdle -MaxMinutes $MaxWaitMinutes)) {
        Write-UpdateLog "Runner did not become idle within timeout period" "ERROR"

        if (-not $Force) {
            Write-UpdateLog "Use -Force to update anyway (may interrupt active jobs)" "WARN"
            exit 1
        } else {
            Write-UpdateLog "Forcing update despite active jobs" "WARN"
        }
    }

    # Stop runner
    if (-not (Stop-RunnerService)) {
        Write-UpdateLog "Failed to stop runner service" "ERROR"
        exit 1
    }

    # Create backup
    $backupPath = $null
    if (-not $SkipBackup) {
        $backupPath = New-RunnerBackup
    } else {
        Write-UpdateLog "Skipping backup (not recommended)" "WARN"
    }

    # Install update
    Write-UpdateLog "Installing runner update..." "INFO"

    if (-not (Install-RunnerUpdate -DownloadUrl $downloadUrl -TargetVersion $targetVersion)) {
        Write-UpdateLog "Update installation failed" "ERROR"

        # Attempt rollback
        if ($backupPath) {
            Write-UpdateLog "Attempting to restore from backup..." "WARN"
            Restore-FromBackup -BackupPath $backupPath
        }

        Start-RunnerService
        exit 1
    }

    # Verify installation
    if (-not (Test-RunnerInstallation)) {
        Write-UpdateLog "Installation verification failed" "ERROR"

        # Attempt rollback
        if ($backupPath) {
            Write-UpdateLog "Attempting to restore from backup..." "WARN"
            Restore-FromBackup -BackupPath $backupPath
        }

        Start-RunnerService
        exit 1
    }

    # Restart runner
    if (-not (Start-RunnerService)) {
        Write-UpdateLog "Failed to restart runner service" "ERROR"
        Write-UpdateLog "You may need to start the runner manually" "WARN"
        exit 1
    }

    # Success!
    Write-Host "`n=== Update Completed Successfully ===" -ForegroundColor Green
    Write-Host "Previous version: $currentVersion" -ForegroundColor Cyan
    Write-Host "New version: $targetVersion" -ForegroundColor Cyan

    if ($backupPath) {
        Write-Host "Backup location: $backupPath" -ForegroundColor Gray
    }

    Write-UpdateLog "Runner update completed successfully" "SUCCESS"

    exit 0

} catch {
    Write-UpdateLog "Fatal error during update: $_" "ERROR"
    Write-UpdateLog $_.ScriptStackTrace "ERROR"

    # Attempt to restart runner even if update failed
    Start-RunnerService

    exit 1
}
