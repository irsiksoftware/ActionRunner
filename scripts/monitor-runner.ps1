#Requires -Version 5.1

<#
.SYNOPSIS
    Continuous GitHub Actions Runner Monitoring Script

.DESCRIPTION
    Continuously monitors the GitHub Actions self-hosted runner and performs periodic health checks.
    Can run as a background service or scheduled task.

.PARAMETER IntervalSeconds
    Interval between health checks in seconds (default: 300 = 5 minutes)

.PARAMETER AlertWebhook
    Optional webhook URL to send alerts (supports Slack, Discord, Teams, etc.)

.PARAMETER MaxIterations
    Maximum number of monitoring iterations (0 = infinite, default: 0)

.PARAMETER MinDiskSpaceGB
    Minimum required free disk space in GB (default: 100)

.PARAMETER LogRetentionDays
    Number of days to retain monitoring logs (default: 30)

.EXAMPLE
    .\monitor-runner.ps1
    .\monitor-runner.ps1 -IntervalSeconds 60
    .\monitor-runner.ps1 -AlertWebhook "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

.NOTES
    Author: GitHub Actions Runner Team
    Version: 1.0.0
#>

param(
    [Parameter(Mandatory=$false)]
    [int]$IntervalSeconds = 300,

    [Parameter(Mandatory=$false)]
    [string]$AlertWebhook = "",

    [Parameter(Mandatory=$false)]
    [int]$MaxIterations = 0,

    [Parameter(Mandatory=$false)]
    [int]$MinDiskSpaceGB = 100,

    [Parameter(Mandatory=$false)]
    [int]$LogRetentionDays = 30
)

$monitorLogPath = "logs\monitor-runner.log"
$healthCheckScript = Join-Path $PSScriptRoot "health-check.ps1"

# Ensure health-check.ps1 exists
if (-not (Test-Path $healthCheckScript)) {
    Write-Error "Health check script not found at: $healthCheckScript"
    exit 1
}

# Function to log messages
function Write-MonitorLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Ensure log directory exists
    $logDir = Split-Path -Parent $monitorLogPath
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    Add-Content -Path $monitorLogPath -Value $logMessage
    Write-Host $logMessage
}

# Function to send alerts via webhook
function Send-Alert {
    param(
        [string]$Message,
        [string]$Severity = "warning"
    )

    if ([string]::IsNullOrEmpty($AlertWebhook)) {
        return
    }

    try {
        $payload = @{
            text = "[Runner Monitor] $Message"
            severity = $Severity
            timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            hostname = $env:COMPUTERNAME
        } | ConvertTo-Json

        Invoke-RestMethod -Uri $AlertWebhook -Method Post -Body $payload -ContentType "application/json" -ErrorAction Stop
        Write-MonitorLog "Alert sent: $Message" "INFO"
    } catch {
        Write-MonitorLog "Failed to send alert: $($_.Exception.Message)" "ERROR"
    }
}

# Function to rotate and clean old logs
function Invoke-LogRotation {
    Write-MonitorLog "Performing log rotation..." "INFO"

    $logDir = "logs"
    if (Test-Path $logDir) {
        $cutoffDate = (Get-Date).AddDays(-$LogRetentionDays)
        $oldLogs = Get-ChildItem -Path $logDir -Filter "*.log" |
                   Where-Object { $_.LastWriteTime -lt $cutoffDate }

        foreach ($log in $oldLogs) {
            try {
                Remove-Item $log.FullName -Force
                Write-MonitorLog "Removed old log: $($log.Name)" "INFO"
            } catch {
                Write-MonitorLog "Failed to remove log $($log.Name): $($_.Exception.Message)" "ERROR"
            }
        }
    }
}

# Function to perform health check and handle alerts
function Invoke-HealthCheckWithAlerts {
    Write-MonitorLog "Running health check..." "INFO"

    try {
        # Execute health check script
        $result = & $healthCheckScript -OutputFormat json -MinDiskSpaceGB $MinDiskSpaceGB 2>&1
        $exitCode = $LASTEXITCODE

        if ($result) {
            $healthData = $result | ConvertFrom-Json

            # Log overall status
            Write-MonitorLog "Health check completed. Status: $($healthData.overall_status)" "INFO"

            # Send alerts for any issues
            if ($healthData.alerts -and $healthData.alerts.Count -gt 0) {
                foreach ($alert in $healthData.alerts) {
                    Write-MonitorLog "ALERT: $alert" "WARN"
                    Send-Alert -Message $alert -Severity $(
                        if ($healthData.overall_status -eq "unhealthy") { "critical" } else { "warning" }
                    )
                }
            }

            # Check for critical failures
            if ($exitCode -eq 2) {
                Write-MonitorLog "Critical health check failure detected!" "ERROR"
                Send-Alert -Message "Runner health check CRITICAL failure on $env:COMPUTERNAME" -Severity "critical"
            } elseif ($exitCode -eq 1) {
                Write-MonitorLog "Runner health degraded" "WARN"
            }

            return $healthData
        } else {
            Write-MonitorLog "Health check returned no data" "ERROR"
            Send-Alert -Message "Health check failed to return data on $env:COMPUTERNAME" -Severity "critical"
            return $null
        }
    } catch {
        Write-MonitorLog "Health check execution failed: $($_.Exception.Message)" "ERROR"
        Send-Alert -Message "Health check execution failed on $env:COMPUTERNAME`: $($_.Exception.Message)" -Severity "critical"
        return $null
    }
}

# Main monitoring loop
Write-MonitorLog "Starting runner monitoring service..." "INFO"
Write-MonitorLog "Interval: ${IntervalSeconds}s, Max Iterations: $(if ($MaxIterations -eq 0) { 'Infinite' } else { $MaxIterations })" "INFO"

if ($AlertWebhook) {
    Write-MonitorLog "Alert webhook configured" "INFO"
    Send-Alert -Message "Runner monitoring started on $env:COMPUTERNAME" -Severity "info"
}

$iteration = 0
$lastLogRotation = Get-Date

while ($true) {
    $iteration++

    Write-MonitorLog "=== Monitoring Iteration #$iteration ===" "INFO"

    # Perform health check
    $healthResult = Invoke-HealthCheckWithAlerts

    # Perform log rotation once per day
    if (((Get-Date) - $lastLogRotation).TotalDays -ge 1) {
        Invoke-LogRotation
        $lastLogRotation = Get-Date
    }

    # Check if we should exit
    if ($MaxIterations -gt 0 -and $iteration -ge $MaxIterations) {
        Write-MonitorLog "Reached maximum iterations ($MaxIterations). Exiting..." "INFO"
        break
    }

    # Wait for next iteration
    Write-MonitorLog "Waiting ${IntervalSeconds}s until next check..." "INFO"
    Start-Sleep -Seconds $IntervalSeconds
}

Write-MonitorLog "Monitoring service stopped" "INFO"
if ($AlertWebhook) {
    Send-Alert -Message "Runner monitoring stopped on $env:COMPUTERNAME" -Severity "info"
}
