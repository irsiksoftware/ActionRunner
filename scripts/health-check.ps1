<#
.SYNOPSIS
    Performs health checks on the GitHub Actions runner and system resources.

.DESCRIPTION
    This script checks the health of the GitHub Actions runner including:
    - Runner service status
    - Disk space availability
    - CPU and RAM usage
    - GPU availability and VRAM (for CUDA workloads)
    - Network connectivity to GitHub
    - Last successful job execution time

.PARAMETER OutputFormat
    Output format: JSON or Text (default: JSON)

.PARAMETER DiskThresholdGB
    Minimum free disk space in GB to consider healthy (default: 100)

.PARAMETER WorkDirectory
    Runner work directory to check (default: C:\actions-runner)

.EXAMPLE
    .\health-check.ps1

.EXAMPLE
    .\health-check.ps1 -OutputFormat Text -DiskThresholdGB 50
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("JSON", "Text")]
    [string]$OutputFormat = "JSON",

    [Parameter(Mandatory = $false)]
    [int]$DiskThresholdGB = 100,

    [Parameter(Mandatory = $false)]
    [string]$WorkDirectory = "C:\actions-runner"
)

$ErrorActionPreference = "Continue"

# Health check results
$healthStatus = @{
    Timestamp = Get-Date -Format "o"
    OverallHealth = "Healthy"
    Checks = @{}
}

# Check 1: Runner service status
try {
    $service = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($service) {
        $serviceHealthy = $service.Status -eq "Running"
        $healthStatus.Checks.RunnerService = @{
            Status = if ($serviceHealthy) { "Healthy" } else { "Unhealthy" }
            ServiceName = $service.Name
            ServiceStatus = $service.Status.ToString()
            Message = if ($serviceHealthy) { "Runner service is running" } else { "Runner service is not running: $($service.Status)" }
        }
        if (-not $serviceHealthy) { $healthStatus.OverallHealth = "Unhealthy" }
    } else {
        $healthStatus.Checks.RunnerService = @{
            Status = "Warning"
            Message = "No runner service found (may be running interactively)"
        }
        $healthStatus.OverallHealth = "Warning"
    }
} catch {
    $healthStatus.Checks.RunnerService = @{
        Status = "Error"
        Message = "Failed to check runner service: $($_.Exception.Message)"
    }
    $healthStatus.OverallHealth = "Unhealthy"
}

# Check 2: Disk space
try {
    $drive = (Get-Item $WorkDirectory -ErrorAction SilentlyContinue).PSDrive.Name
    if (-not $drive) {
        $drive = "C"
    }

    $disk = Get-PSDrive -Name $drive -ErrorAction Stop
    $freeSpaceGB = [math]::Round($disk.Free / 1GB, 2)
    $totalSpaceGB = [math]::Round(($disk.Used + $disk.Free) / 1GB, 2)
    $usedPercentage = [math]::Round(($disk.Used / ($disk.Used + $disk.Free)) * 100, 2)

    $diskHealthy = $freeSpaceGB -ge $DiskThresholdGB
    $healthStatus.Checks.DiskSpace = @{
        Status = if ($diskHealthy) { "Healthy" } else { "Unhealthy" }
        Drive = "${drive}:"
        FreeSpaceGB = $freeSpaceGB
        TotalSpaceGB = $totalSpaceGB
        UsedPercentage = $usedPercentage
        ThresholdGB = $DiskThresholdGB
        Message = if ($diskHealthy) {
            "Disk space is sufficient: $freeSpaceGB GB free"
        } else {
            "Low disk space: $freeSpaceGB GB free (threshold: $DiskThresholdGB GB)"
        }
    }
    if (-not $diskHealthy) { $healthStatus.OverallHealth = "Unhealthy" }
} catch {
    $healthStatus.Checks.DiskSpace = @{
        Status = "Error"
        Message = "Failed to check disk space: $($_.Exception.Message)"
    }
    $healthStatus.OverallHealth = "Unhealthy"
}

# Check 3: CPU and RAM usage
try {
    $cpu = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction Stop
    $cpuUsage = [math]::Round($cpu.CounterSamples[0].CookedValue, 2)

    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRAM = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedRAM = [math]::Round($totalRAM - $freeRAM, 2)
    $ramUsagePercentage = [math]::Round(($usedRAM / $totalRAM) * 100, 2)

    $resourcesHealthy = $cpuUsage -lt 95 -and $ramUsagePercentage -lt 95
    $healthStatus.Checks.SystemResources = @{
        Status = if ($resourcesHealthy) { "Healthy" } else { "Warning" }
        CPUUsagePercentage = $cpuUsage
        RAMUsagePercentage = $ramUsagePercentage
        TotalRAMGB = $totalRAM
        UsedRAMGB = $usedRAM
        FreeRAMGB = $freeRAM
        Message = if ($resourcesHealthy) {
            "System resources are normal (CPU: $cpuUsage%, RAM: $ramUsagePercentage%)"
        } else {
            "High resource usage (CPU: $cpuUsage%, RAM: $ramUsagePercentage%)"
        }
    }
    if (-not $resourcesHealthy -and $healthStatus.OverallHealth -eq "Healthy") {
        $healthStatus.OverallHealth = "Warning"
    }
} catch {
    $healthStatus.Checks.SystemResources = @{
        Status = "Error"
        Message = "Failed to check system resources: $($_.Exception.Message)"
    }
}

# Check 4: GPU availability and VRAM
try {
    $gpus = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.AdapterRAM -gt 0 }

    if ($gpus) {
        $gpuInfo = @()
        foreach ($gpu in $gpus) {
            $vramGB = [math]::Round($gpu.AdapterRAM / 1GB, 2)
            $gpuInfo += @{
                Name = $gpu.Name
                VRAMGB = $vramGB
                DriverVersion = $gpu.DriverVersion
                Status = $gpu.Status
            }
        }

        $healthStatus.Checks.GPU = @{
            Status = "Healthy"
            GPUCount = $gpus.Count
            GPUs = $gpuInfo
            Message = "Found $($gpus.Count) GPU(s)"
        }
    } else {
        $healthStatus.Checks.GPU = @{
            Status = "Info"
            Message = "No GPU detected or GPU information unavailable"
        }
    }
} catch {
    $healthStatus.Checks.GPU = @{
        Status = "Info"
        Message = "Unable to retrieve GPU information: $($_.Exception.Message)"
    }
}

# Check 5: Network connectivity to GitHub
try {
    $githubHosts = @("github.com", "api.github.com")
    $connectivityResults = @()
    $allConnected = $true

    foreach ($host in $githubHosts) {
        $pingResult = Test-Connection -ComputerName $host -Count 2 -Quiet -ErrorAction SilentlyContinue
        $connectivityResults += @{
            Host = $host
            Connected = $pingResult
        }
        if (-not $pingResult) { $allConnected = $false }
    }

    $healthStatus.Checks.NetworkConnectivity = @{
        Status = if ($allConnected) { "Healthy" } else { "Unhealthy" }
        Results = $connectivityResults
        Message = if ($allConnected) {
            "Network connectivity to GitHub is working"
        } else {
            "Network connectivity issues detected"
        }
    }
    if (-not $allConnected) { $healthStatus.OverallHealth = "Unhealthy" }
} catch {
    $healthStatus.Checks.NetworkConnectivity = @{
        Status = "Error"
        Message = "Failed to check network connectivity: $($_.Exception.Message)"
    }
    $healthStatus.OverallHealth = "Unhealthy"
}

# Check 6: Last successful job execution time
try {
    $logPath = Join-Path $WorkDirectory "_diag"
    if (Test-Path $logPath) {
        $latestLog = Get-ChildItem -Path $logPath -Filter "Worker_*.log" -ErrorAction SilentlyContinue |
                     Sort-Object LastWriteTime -Descending |
                     Select-Object -First 1

        if ($latestLog) {
            $lastJobTime = $latestLog.LastWriteTime
            $hoursSinceLastJob = [math]::Round(((Get-Date) - $lastJobTime).TotalHours, 2)

            $jobHealthy = $hoursSinceLastJob -lt 72  # Alert if no job in 72 hours
            $healthStatus.Checks.LastJobExecution = @{
                Status = if ($jobHealthy) { "Healthy" } else { "Warning" }
                LastJobTime = $lastJobTime.ToString("o")
                HoursSinceLastJob = $hoursSinceLastJob
                LatestLogFile = $latestLog.Name
                Message = if ($jobHealthy) {
                    "Last job executed $hoursSinceLastJob hours ago"
                } else {
                    "No recent job execution: $hoursSinceLastJob hours since last job"
                }
            }
            if (-not $jobHealthy -and $healthStatus.OverallHealth -eq "Healthy") {
                $healthStatus.OverallHealth = "Warning"
            }
        } else {
            $healthStatus.Checks.LastJobExecution = @{
                Status = "Info"
                Message = "No job logs found in diagnostic directory"
            }
        }
    } else {
        $healthStatus.Checks.LastJobExecution = @{
            Status = "Info"
            Message = "Diagnostic log directory not found"
        }
    }
} catch {
    $healthStatus.Checks.LastJobExecution = @{
        Status = "Error"
        Message = "Failed to check last job execution: $($_.Exception.Message)"
    }
}

# Output results
if ($OutputFormat -eq "JSON") {
    $healthStatus | ConvertTo-Json -Depth 5
} else {
    Write-Host "=" * 70
    Write-Host "GitHub Actions Runner Health Check"
    Write-Host "=" * 70
    Write-Host "Timestamp: $($healthStatus.Timestamp)"
    Write-Host "Overall Health: $($healthStatus.OverallHealth)"
    Write-Host ""

    foreach ($checkName in $healthStatus.Checks.Keys) {
        $check = $healthStatus.Checks[$checkName]
        Write-Host "$checkName : $($check.Status)" -ForegroundColor $(
            switch ($check.Status) {
                "Healthy" { "Green" }
                "Warning" { "Yellow" }
                "Unhealthy" { "Red" }
                "Error" { "Red" }
                default { "White" }
            }
        )
        Write-Host "  $($check.Message)"
        Write-Host ""
    }
    Write-Host "=" * 70
}

# Exit with appropriate code
exit $(if ($healthStatus.OverallHealth -eq "Unhealthy") { 1 } else { 0 })
