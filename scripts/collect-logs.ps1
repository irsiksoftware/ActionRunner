<#
.SYNOPSIS
    Collects GitHub Actions runner logs and system events for debugging and audit purposes.

.DESCRIPTION
    This script gathers:
    - Runner service logs
    - Job execution logs
    - System performance metrics
    - Security audit logs
    - Windows Event Logs related to the runner

.PARAMETER OutputPath
    Path where collected logs will be saved. Default: .\logs

.PARAMETER IncludeSystemLogs
    Include system performance and security logs. Default: $true

.PARAMETER DaysToCollect
    Number of days of logs to collect. Default: 7

.EXAMPLE
    .\collect-logs.ps1
    Collects logs from the last 7 days to the default logs directory.

.EXAMPLE
    .\collect-logs.ps1 -OutputPath "C:\Logs\Runner" -DaysToCollect 30
    Collects 30 days of logs to a custom directory.
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\logs",

    [Parameter(Mandatory=$false)]
    [bool]$IncludeSystemLogs = $true,

    [Parameter(Mandatory=$false)]
    [int]$DaysToCollect = 7
)

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFileName = "runner-logs-$timestamp"

Write-Host "=== GitHub Actions Runner Log Collection ===" -ForegroundColor Cyan
Write-Host "Start Time: $(Get-Date)" -ForegroundColor Green
Write-Host "Output Path: $OutputPath" -ForegroundColor Green
Write-Host "Days to Collect: $DaysToCollect" -ForegroundColor Green
Write-Host ""

# Calculate date filter
$startDate = (Get-Date).AddDays(-$DaysToCollect)

# 1. Collect Runner Service Logs
Write-Host "[1/5] Collecting runner service logs..." -ForegroundColor Yellow
$runnerServiceLogs = @()

# Check for Actions Runner service
$runnerServices = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue

if ($runnerServices) {
    foreach ($service in $runnerServices) {
        $serviceName = $service.Name
        Write-Host "  Found runner service: $serviceName" -ForegroundColor Gray

        # Get service details
        $serviceInfo = @{
            ServiceName = $serviceName
            DisplayName = $service.DisplayName
            Status = $service.Status
            StartType = $service.StartType
            CollectionTime = Get-Date
        }
        $runnerServiceLogs += $serviceInfo
    }
} else {
    Write-Host "  No runner services found. Is the runner installed?" -ForegroundColor Yellow
}

# Save service info
$runnerServiceLogs | ConvertTo-Json | Out-File "$OutputPath\$logFileName-service-info.json"

# 2. Collect Job Execution Logs
Write-Host "[2/5] Collecting job execution logs..." -ForegroundColor Yellow

# Look for runner installation directories
$possibleRunnerPaths = @(
    "$env:USERPROFILE\actions-runner",
    "C:\actions-runner",
    "C:\actions\runner",
    "$env:ProgramFiles\GitHub Actions Runner"
)

$jobLogs = @()
foreach ($path in $possibleRunnerPaths) {
    if (Test-Path $path) {
        Write-Host "  Checking runner path: $path" -ForegroundColor Gray

        # Collect _diag logs
        $diagPath = Join-Path $path "_diag"
        if (Test-Path $diagPath) {
            $diagFiles = Get-ChildItem -Path $diagPath -Filter "*.log" -File |
                Where-Object { $_.LastWriteTime -ge $startDate }

            foreach ($file in $diagFiles) {
                Write-Host "    Found diag log: $($file.Name)" -ForegroundColor Gray
                Copy-Item $file.FullName -Destination "$OutputPath\$logFileName-diag-$($file.Name)"
            }
        }

        # Collect job logs
        $workPath = Join-Path $path "_work"
        if (Test-Path $workPath) {
            $workDirs = Get-ChildItem -Path $workPath -Directory
            foreach ($dir in $workDirs) {
                $logFiles = Get-ChildItem -Path $dir.FullName -Filter "*.log" -Recurse -File |
                    Where-Object { $_.LastWriteTime -ge $startDate }

                foreach ($file in $logFiles) {
                    Write-Host "    Found job log: $($file.Name)" -ForegroundColor Gray
                    $jobLogs += @{
                        FileName = $file.Name
                        Path = $file.FullName
                        Size = $file.Length
                        LastModified = $file.LastWriteTime
                    }
                }
            }
        }
    }
}

$jobLogs | ConvertTo-Json | Out-File "$OutputPath\$logFileName-job-logs.json"

# 3. Collect System Performance Logs
if ($IncludeSystemLogs) {
    Write-Host "[3/5] Collecting system performance logs..." -ForegroundColor Yellow

    $perfData = @{
        CPU = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue
        Memory = Get-Counter '\Memory\Available MBytes' -ErrorAction SilentlyContinue
        Disk = Get-Counter '\PhysicalDisk(_Total)\% Disk Time' -ErrorAction SilentlyContinue
        Network = Get-Counter '\Network Interface(*)\Bytes Total/sec' -ErrorAction SilentlyContinue
        CollectionTime = Get-Date
    }

    $perfData | ConvertTo-Json -Depth 3 | Out-File "$OutputPath\$logFileName-performance.json"
    Write-Host "  Performance snapshot saved" -ForegroundColor Gray
} else {
    Write-Host "[3/5] Skipping system performance logs" -ForegroundColor Yellow
}

# 4. Collect Windows Event Logs
Write-Host "[4/5] Collecting Windows Event Logs..." -ForegroundColor Yellow

try {
    # Application logs related to GitHub Actions
    $appLogs = Get-WinEvent -FilterHashtable @{
        LogName = 'Application'
        StartTime = $startDate
    } -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -match 'GitHub|Actions|Runner' } |
    Select-Object -First 1000

    if ($appLogs) {
        $appLogs | Select-Object TimeCreated, Id, LevelDisplayName, Message |
            ConvertTo-Json | Out-File "$OutputPath\$logFileName-eventlog-application.json"
        Write-Host "  Collected $($appLogs.Count) application events" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Could not access Application event log: $($_.Exception.Message)" -ForegroundColor Yellow
}

try {
    # System logs
    $sysLogs = Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        StartTime = $startDate
    } -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -match 'actions.runner|GitHub' } |
    Select-Object -First 1000

    if ($sysLogs) {
        $sysLogs | Select-Object TimeCreated, Id, LevelDisplayName, Message |
            ConvertTo-Json | Out-File "$OutputPath\$logFileName-eventlog-system.json"
        Write-Host "  Collected $($sysLogs.Count) system events" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Could not access System event log: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 5. Collect Security Audit Logs
if ($IncludeSystemLogs) {
    Write-Host "[5/5] Collecting security audit logs..." -ForegroundColor Yellow

    try {
        # Security logs (requires admin privileges)
        $secLogs = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            StartTime = $startDate
        } -ErrorAction SilentlyContinue |
        Where-Object { $_.Message -match 'actions.runner|GitHub' } |
        Select-Object -First 1000

        if ($secLogs) {
            $secLogs | Select-Object TimeCreated, Id, LevelDisplayName, Message |
                ConvertTo-Json | Out-File "$OutputPath\$logFileName-eventlog-security.json"
            Write-Host "  Collected $($secLogs.Count) security events" -ForegroundColor Gray
        } else {
            Write-Host "  No security events found (may require admin privileges)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  Could not access Security event log: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  Note: Security logs require administrator privileges" -ForegroundColor Yellow
    }
} else {
    Write-Host "[5/5] Skipping security audit logs" -ForegroundColor Yellow
}

# Create summary report
Write-Host ""
Write-Host "Creating summary report..." -ForegroundColor Yellow

$summary = @{
    CollectionDate = Get-Date
    DaysCollected = $DaysToCollect
    StartDate = $startDate
    RunnerServices = $runnerServiceLogs.Count
    JobLogs = $jobLogs.Count
    IncludedSystemLogs = $IncludeSystemLogs
    OutputPath = (Resolve-Path $OutputPath).Path
    LogFiles = (Get-ChildItem $OutputPath -Filter "$logFileName*").Name
}

$summary | ConvertTo-Json | Out-File "$OutputPath\$logFileName-summary.json"

Write-Host ""
Write-Host "=== Collection Complete ===" -ForegroundColor Green
Write-Host "End Time: $(Get-Date)" -ForegroundColor Green
Write-Host "Total Files Created: $($summary.LogFiles.Count)" -ForegroundColor Green
Write-Host "Output Location: $($summary.OutputPath)" -ForegroundColor Green
Write-Host ""
Write-Host "Files created:" -ForegroundColor Cyan
$summary.LogFiles | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
