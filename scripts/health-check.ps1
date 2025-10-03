#Requires -Version 5.1

<#
.SYNOPSIS
    GitHub Actions Runner Health Check Script

.DESCRIPTION
    Performs comprehensive health checks on the GitHub Actions self-hosted runner including:
    - Runner service status
    - Disk space availability
    - CPU and RAM usage
    - GPU availability and VRAM (for CUDA workloads)
    - Network connectivity to GitHub
    - Last successful job execution time

.PARAMETER OutputFormat
    Output format: 'json' or 'text' (default: json)

.PARAMETER MinDiskSpaceGB
    Minimum required free disk space in GB (default: 100)

.PARAMETER LogPath
    Path to store health check logs (default: logs/health-check.log)

.EXAMPLE
    .\health-check.ps1
    .\health-check.ps1 -OutputFormat text
    .\health-check.ps1 -MinDiskSpaceGB 200

.NOTES
    Author: GitHub Actions Runner Team
    Version: 1.0.0
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('json', 'text')]
    [string]$OutputFormat = 'json',

    [Parameter(Mandatory=$false)]
    [int]$MinDiskSpaceGB = 100,

    [Parameter(Mandatory=$false)]
    [string]$LogPath = "logs\health-check.log"
)

# Initialize results object
$healthStatus = @{
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    overall_status = "healthy"
    checks = @{}
    alerts = @()
}

# Function to log messages
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Ensure log directory exists
    $logDir = Split-Path -Parent $LogPath
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    Add-Content -Path $LogPath -Value $logMessage
}

# Check 1: Runner Service Status
function Test-RunnerService {
    Write-Log "Checking runner service status..."

    $runnerServices = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue

    if ($runnerServices) {
        $serviceStatus = @()
        foreach ($service in $runnerServices) {
            $serviceStatus += @{
                name = $service.Name
                status = $service.Status.ToString()
                display_name = $service.DisplayName
            }

            if ($service.Status -ne 'Running') {
                $healthStatus.alerts += "Runner service '$($service.Name)' is not running (Status: $($service.Status))"
                $healthStatus.overall_status = "unhealthy"
            }
        }

        $healthStatus.checks.runner_service = @{
            status = if ($runnerServices | Where-Object { $_.Status -ne 'Running' }) { "unhealthy" } else { "healthy" }
            services = $serviceStatus
        }
    } else {
        $healthStatus.checks.runner_service = @{
            status = "unknown"
            message = "No runner services found"
        }
        $healthStatus.alerts += "No GitHub Actions runner services detected"
        $healthStatus.overall_status = "degraded"
    }
}

# Check 2: Disk Space
function Test-DiskSpace {
    Write-Log "Checking disk space..."

    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null }
    $diskStatus = @()

    foreach ($drive in $drives) {
        $freeGB = [math]::Round($drive.Free / 1GB, 2)
        $usedGB = [math]::Round($drive.Used / 1GB, 2)
        $totalGB = [math]::Round(($drive.Free + $drive.Used) / 1GB, 2)
        $percentFree = [math]::Round(($drive.Free / ($drive.Free + $drive.Used)) * 100, 2)

        $diskStatus += @{
            drive = $drive.Name
            free_gb = $freeGB
            used_gb = $usedGB
            total_gb = $totalGB
            percent_free = $percentFree
        }

        if ($freeGB -lt $MinDiskSpaceGB) {
            $healthStatus.alerts += "Drive $($drive.Name): has only ${freeGB}GB free (threshold: ${MinDiskSpaceGB}GB)"
            $healthStatus.overall_status = "unhealthy"
        }
    }

    $healthStatus.checks.disk_space = @{
        status = if ($healthStatus.alerts -match "Drive.*free") { "unhealthy" } else { "healthy" }
        drives = $diskStatus
        threshold_gb = $MinDiskSpaceGB
    }
}

# Check 3: CPU and RAM Usage
function Test-ResourceUsage {
    Write-Log "Checking CPU and RAM usage..."

    # Get CPU usage
    $cpuUsage = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 1).CounterSamples.CookedValue
    $cpuUsage = [math]::Round($cpuUsage, 2)

    # Get RAM usage
    $computerInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $totalRAM = [math]::Round($computerInfo.TotalVisibleMemorySize / 1MB, 2)
    $freeRAM = [math]::Round($computerInfo.FreePhysicalMemory / 1MB, 2)
    $usedRAM = [math]::Round($totalRAM - $freeRAM, 2)
    $ramUsagePercent = [math]::Round(($usedRAM / $totalRAM) * 100, 2)

    $healthStatus.checks.resource_usage = @{
        status = "healthy"
        cpu = @{
            usage_percent = $cpuUsage
        }
        ram = @{
            total_gb = $totalRAM
            used_gb = $usedRAM
            free_gb = $freeRAM
            usage_percent = $ramUsagePercent
        }
    }

    # Alert on high resource usage
    if ($cpuUsage -gt 90) {
        $healthStatus.alerts += "High CPU usage: ${cpuUsage}%"
        $healthStatus.overall_status = "degraded"
    }

    if ($ramUsagePercent -gt 90) {
        $healthStatus.alerts += "High RAM usage: ${ramUsagePercent}%"
        $healthStatus.overall_status = "degraded"
    }
}

# Check 4: GPU Availability and VRAM
function Test-GPUStatus {
    Write-Log "Checking GPU availability..."

    try {
        # Try to get NVIDIA GPU info using nvidia-smi
        $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue

        if ($nvidiaSmi) {
            $gpuInfo = & nvidia-smi --query-gpu=name,memory.total,memory.free,memory.used,temperature.gpu,utilization.gpu --format=csv,noheader,nounits 2>$null

            if ($gpuInfo) {
                $gpus = @()
                foreach ($line in $gpuInfo) {
                    $parts = $line -split ','
                    if ($parts.Count -ge 6) {
                        $gpus += @{
                            name = $parts[0].Trim()
                            memory_total_mb = [int]$parts[1].Trim()
                            memory_free_mb = [int]$parts[2].Trim()
                            memory_used_mb = [int]$parts[3].Trim()
                            temperature_c = [int]$parts[4].Trim()
                            utilization_percent = [int]$parts[5].Trim()
                        }

                        # Alert on high temperature
                        if ([int]$parts[4].Trim() -gt 85) {
                            $healthStatus.alerts += "GPU temperature high: $($parts[4].Trim())°C"
                            $healthStatus.overall_status = "degraded"
                        }
                    }
                }

                $healthStatus.checks.gpu = @{
                    status = "healthy"
                    available = $true
                    gpus = $gpus
                }
            } else {
                $healthStatus.checks.gpu = @{
                    status = "unknown"
                    available = $false
                    message = "nvidia-smi command failed"
                }
            }
        } else {
            $healthStatus.checks.gpu = @{
                status = "not_available"
                available = $false
                message = "nvidia-smi not found - no NVIDIA GPU detected"
            }
        }
    } catch {
        $healthStatus.checks.gpu = @{
            status = "error"
            available = $false
            error = $_.Exception.Message
        }
    }
}

# Check 5: Network Connectivity to GitHub
function Test-GitHubConnectivity {
    Write-Log "Checking network connectivity to GitHub..."

    $endpoints = @(
        @{ url = "https://api.github.com"; name = "GitHub API" }
        @{ url = "https://github.com"; name = "GitHub Web" }
    )

    $connectivityResults = @()
    $allHealthy = $true

    foreach ($endpoint in $endpoints) {
        try {
            $response = Invoke-WebRequest -Uri $endpoint.url -Method Head -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
            $connectivityResults += @{
                endpoint = $endpoint.name
                url = $endpoint.url
                status = "reachable"
                status_code = $response.StatusCode
            }
        } catch {
            $connectivityResults += @{
                endpoint = $endpoint.name
                url = $endpoint.url
                status = "unreachable"
                error = $_.Exception.Message
            }
            $healthStatus.alerts += "Cannot reach $($endpoint.name) ($($endpoint.url))"
            $healthStatus.overall_status = "unhealthy"
            $allHealthy = $false
        }
    }

    $healthStatus.checks.network_connectivity = @{
        status = if ($allHealthy) { "healthy" } else { "unhealthy" }
        endpoints = $connectivityResults
    }
}

# Check 6: Last Successful Job Execution
function Test-LastJobExecution {
    Write-Log "Checking last job execution time..."

    # Look for runner log files
    $runnerLogPaths = @(
        "_diag",
        "..\..\_diag",
        "$env:GITHUB_RUNNER_HOME\_diag"
    )

    $latestLog = $null
    $latestTime = [DateTime]::MinValue

    foreach ($logPath in $runnerLogPaths) {
        if (Test-Path $logPath) {
            $logFiles = Get-ChildItem -Path $logPath -Filter "Worker_*.log" -ErrorAction SilentlyContinue |
                        Sort-Object LastWriteTime -Descending |
                        Select-Object -First 1

            if ($logFiles -and $logFiles.LastWriteTime -gt $latestTime) {
                $latestLog = $logFiles
                $latestTime = $logFiles.LastWriteTime
            }
        }
    }

    if ($latestLog) {
        $hoursSinceLastJob = [math]::Round(((Get-Date) - $latestTime).TotalHours, 2)

        $healthStatus.checks.last_job_execution = @{
            status = "healthy"
            last_execution = $latestTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
            hours_since_last_job = $hoursSinceLastJob
        }

        # Alert if no jobs in last 24 hours
        if ($hoursSinceLastJob -gt 24) {
            $healthStatus.alerts += "No job execution detected in last 24 hours (${hoursSinceLastJob} hours ago)"
            $healthStatus.overall_status = "degraded"
        }
    } else {
        $healthStatus.checks.last_job_execution = @{
            status = "unknown"
            message = "No runner log files found"
        }
    }
}

# Execute all health checks
Write-Log "Starting health check..."

Test-RunnerService
Test-DiskSpace
Test-ResourceUsage
Test-GPUStatus
Test-GitHubConnectivity
Test-LastJobExecution

Write-Log "Health check completed. Overall status: $($healthStatus.overall_status)"

# Output results
if ($OutputFormat -eq 'json') {
    $healthStatus | ConvertTo-Json -Depth 10
} else {
    Write-Host "`n=== GitHub Actions Runner Health Check ===" -ForegroundColor Cyan
    Write-Host "Timestamp: $($healthStatus.timestamp)" -ForegroundColor Gray
    Write-Host "Overall Status: $($healthStatus.overall_status.ToUpper())" -ForegroundColor $(
        switch ($healthStatus.overall_status) {
            "healthy" { "Green" }
            "degraded" { "Yellow" }
            "unhealthy" { "Red" }
            default { "White" }
        }
    )

    if ($healthStatus.alerts.Count -gt 0) {
        Write-Host "`nAlerts:" -ForegroundColor Red
        foreach ($alert in $healthStatus.alerts) {
            Write-Host "  - $alert" -ForegroundColor Yellow
        }
    }

    Write-Host "`nDetailed Checks:" -ForegroundColor Cyan
    foreach ($check in $healthStatus.checks.GetEnumerator()) {
        Write-Host "`n  $($check.Key):" -ForegroundColor White
        Write-Host "    Status: $($check.Value.status)" -ForegroundColor $(
            if ($check.Value.status -eq "healthy") { "Green" }
            elseif ($check.Value.status -eq "degraded") { "Yellow" }
            elseif ($check.Value.status -eq "unhealthy") { "Red" }
            else { "Gray" }
        )

        # Display additional details based on check type
        if ($check.Value.services) {
            foreach ($svc in $check.Value.services) {
                Write-Host "      - $($svc.name): $($svc.status)" -ForegroundColor Gray
            }
        }

        if ($check.Value.drives) {
            foreach ($drive in $check.Value.drives) {
                Write-Host "      - Drive $($drive.drive): $($drive.free_gb)GB free / $($drive.total_gb)GB total ($($drive.percent_free)% free)" -ForegroundColor Gray
            }
        }

        if ($check.Value.cpu) {
            Write-Host "      - CPU: $($check.Value.cpu.usage_percent)%" -ForegroundColor Gray
        }

        if ($check.Value.ram) {
            Write-Host "      - RAM: $($check.Value.ram.used_gb)GB / $($check.Value.ram.total_gb)GB ($($check.Value.ram.usage_percent)%)" -ForegroundColor Gray
        }

        if ($check.Value.gpus) {
            foreach ($gpu in $check.Value.gpus) {
                Write-Host "      - GPU: $($gpu.name)" -ForegroundColor Gray
                Write-Host "        Memory: $($gpu.memory_used_mb)MB / $($gpu.memory_total_mb)MB" -ForegroundColor Gray
                Write-Host "        Temperature: $($gpu.temperature_c)°C" -ForegroundColor Gray
                Write-Host "        Utilization: $($gpu.utilization_percent)%" -ForegroundColor Gray
            }
        }
    }

    Write-Host ""
}

# Exit with appropriate code
if ($healthStatus.overall_status -eq "healthy") {
    exit 0
} elseif ($healthStatus.overall_status -eq "degraded") {
    exit 1
} else {
    exit 2
}
