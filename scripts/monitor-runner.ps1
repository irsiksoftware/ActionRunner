<#
.SYNOPSIS
    Continuously monitors the GitHub Actions runner health and logs results.

.DESCRIPTION
    This script runs health checks on a continuous interval and logs the results.
    It can send alerts when health issues are detected and maintain a history
    of health check results for analysis.

.PARAMETER IntervalSeconds
    Time between health checks in seconds (default: 300 = 5 minutes)

.PARAMETER LogDirectory
    Directory to store health check logs (default: C:\actions-runner\logs\health)

.PARAMETER DiskThresholdGB
    Minimum free disk space in GB to consider healthy (default: 100)

.PARAMETER AlertOnFailure
    Display alerts when health checks fail (default: true)

.PARAMETER MaxLogFiles
    Maximum number of log files to retain (default: 168 = 1 week at 1-hour intervals)

.PARAMETER WorkDirectory
    Runner work directory to check (default: C:\actions-runner)

.EXAMPLE
    .\monitor-runner.ps1

.EXAMPLE
    .\monitor-runner.ps1 -IntervalSeconds 60 -AlertOnFailure $true

.EXAMPLE
    .\monitor-runner.ps1 -IntervalSeconds 300 -LogDirectory "C:\logs\runner-health" -MaxLogFiles 336
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$IntervalSeconds = 300,

    [Parameter(Mandatory = $false)]
    [string]$LogDirectory = "C:\actions-runner\logs\health",

    [Parameter(Mandatory = $false)]
    [int]$DiskThresholdGB = 100,

    [Parameter(Mandatory = $false)]
    [bool]$AlertOnFailure = $true,

    [Parameter(Mandatory = $false)]
    [int]$MaxLogFiles = 168,

    [Parameter(Mandatory = $false)]
    [string]$WorkDirectory = "C:\actions-runner"
)

$ErrorActionPreference = "Continue"

# Get the path to the health-check script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$healthCheckScript = Join-Path $scriptDir "health-check.ps1"

if (-not (Test-Path $healthCheckScript)) {
    Write-Error "Health check script not found at: $healthCheckScript"
    exit 1
}

# Create log directory if it doesn't exist
if (-not (Test-Path $LogDirectory)) {
    try {
        New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
        Write-Host "Created log directory: $LogDirectory"
    } catch {
        Write-Error "Failed to create log directory: $($_.Exception.Message)"
        exit 1
    }
}

Write-Host "=" * 70
Write-Host "GitHub Actions Runner Continuous Monitoring"
Write-Host "=" * 70
Write-Host "Started at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Check interval: $IntervalSeconds seconds"
Write-Host "Log directory: $LogDirectory"
Write-Host "Disk threshold: $DiskThresholdGB GB"
Write-Host "Alert on failure: $AlertOnFailure"
Write-Host "=" * 70
Write-Host ""

$consecutiveFailures = 0
$checkCount = 0

# Function to clean up old log files
function Remove-OldLogFiles {
    param([string]$Path, [int]$MaxFiles)

    try {
        $logFiles = Get-ChildItem -Path $Path -Filter "health-*.json" -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending

        if ($logFiles.Count -gt $MaxFiles) {
            $filesToDelete = $logFiles | Select-Object -Skip $MaxFiles
            foreach ($file in $filesToDelete) {
                Remove-Item $file.FullName -Force -ErrorAction SilentlyContinue
                Write-Verbose "Deleted old log file: $($file.Name)"
            }
            Write-Host "Cleaned up $($filesToDelete.Count) old log file(s)"
        }
    } catch {
        Write-Warning "Failed to clean up old log files: $($_.Exception.Message)"
    }
}

# Function to display alert
function Show-Alert {
    param([string]$Message, [string]$Severity = "Error")

    $color = switch ($Severity) {
        "Error" { "Red" }
        "Warning" { "Yellow" }
        "Info" { "Cyan" }
        default { "White" }
    }

    Write-Host ""
    Write-Host "!!! ALERT !!!" -ForegroundColor $color -BackgroundColor Black
    Write-Host $Message -ForegroundColor $color
    Write-Host ""
}

# Monitor loop
try {
    while ($true) {
        $checkCount++
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $logFile = Join-Path $LogDirectory "health-$timestamp.json"

        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Running health check #$checkCount..."

        try {
            # Run health check and capture output
            $healthCheckOutput = & $healthCheckScript -OutputFormat JSON -DiskThresholdGB $DiskThresholdGB -WorkDirectory $WorkDirectory 2>&1
            $exitCode = $LASTEXITCODE

            # Parse the JSON output
            $healthStatus = $healthCheckOutput | ConvertFrom-Json

            # Save to log file
            $healthStatus | ConvertTo-Json -Depth 5 | Out-File -FilePath $logFile -Encoding utf8

            # Display summary
            $overallHealth = $healthStatus.OverallHealth
            $statusColor = switch ($overallHealth) {
                "Healthy" { "Green" }
                "Warning" { "Yellow" }
                "Unhealthy" { "Red" }
                default { "White" }
            }

            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Overall Health: " -NoNewline
            Write-Host $overallHealth -ForegroundColor $statusColor

            # Count issues
            $unhealthyChecks = @($healthStatus.Checks.PSObject.Properties | Where-Object {
                $_.Value.Status -in @("Unhealthy", "Error")
            })
            $warningChecks = @($healthStatus.Checks.PSObject.Properties | Where-Object {
                $_.Value.Status -eq "Warning"
            })

            if ($unhealthyChecks.Count -gt 0) {
                Write-Host "  Unhealthy checks: $($unhealthyChecks.Count)" -ForegroundColor Red
                foreach ($check in $unhealthyChecks) {
                    Write-Host "    - $($check.Name): $($check.Value.Message)" -ForegroundColor Red
                }
                $consecutiveFailures++

                if ($AlertOnFailure) {
                    Show-Alert -Message "Runner health check FAILED! $($unhealthyChecks.Count) unhealthy check(s). Consecutive failures: $consecutiveFailures" -Severity "Error"
                }
            } else {
                $consecutiveFailures = 0
            }

            if ($warningChecks.Count -gt 0) {
                Write-Host "  Warning checks: $($warningChecks.Count)" -ForegroundColor Yellow
                foreach ($check in $warningChecks) {
                    Write-Host "    - $($check.Name): $($check.Value.Message)" -ForegroundColor Yellow
                }
            }

            # Clean up old logs periodically (every 10 checks)
            if ($checkCount % 10 -eq 0) {
                Remove-OldLogFiles -Path $LogDirectory -MaxFiles $MaxLogFiles
            }

        } catch {
            Write-Error "Health check failed: $($_.Exception.Message)"
            $consecutiveFailures++

            if ($AlertOnFailure) {
                Show-Alert -Message "Health check script execution failed! Error: $($_.Exception.Message)" -Severity "Error"
            }
        }

        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Waiting $IntervalSeconds seconds until next check..."
        Write-Host ""

        Start-Sleep -Seconds $IntervalSeconds
    }
} catch {
    Write-Error "Monitoring loop terminated: $($_.Exception.Message)"
    exit 1
} finally {
    Write-Host ""
    Write-Host "=" * 70
    Write-Host "Monitoring stopped at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "Total checks performed: $checkCount"
    Write-Host "=" * 70
}
