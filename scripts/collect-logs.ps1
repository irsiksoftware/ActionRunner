<#
.SYNOPSIS
    Collect runner operation logs, job execution logs, and system events.

.DESCRIPTION
    Gathers logs from various sources including:
    - Runner service logs
    - Job execution logs
    - System performance logs
    - Security audit logs

    Organizes logs into the logs/ directory with proper categorization.

.PARAMETER OutputPath
    Path to output directory. Defaults to ./logs

.PARAMETER Days
    Number of days of logs to collect. Defaults to 7.

.PARAMETER IncludeWindowsEvents
    Include Windows Event Log entries

.EXAMPLE
    .\collect-logs.ps1
    Collect last 7 days of logs to ./logs directory

.EXAMPLE
    .\collect-logs.ps1 -Days 30 -IncludeWindowsEvents
    Collect last 30 days including Windows events
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath = ".\logs",

    [Parameter()]
    [int]$Days = 7,

    [Parameter()]
    [switch]$IncludeWindowsEvents
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Create timestamp for this collection
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$collectionPath = Join-Path $OutputPath "collection_$timestamp"

Write-Host "=== Runner Log Collection ===" -ForegroundColor Cyan
Write-Host "Collecting logs from the last $Days days..." -ForegroundColor White
Write-Host "Output: $collectionPath" -ForegroundColor White
Write-Host ""

# Create directory structure
$directories = @(
    "runner",
    "jobs",
    "performance",
    "security"
)

foreach ($dir in $directories) {
    $path = Join-Path $OutputPath $dir
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
        Write-Host "Created directory: $dir" -ForegroundColor Green
    }
}

# Create collection subdirectory
New-Item -Path $collectionPath -ItemType Directory -Force | Out-Null

# Calculate date range
$startDate = (Get-Date).AddDays(-$Days)

# Collect Runner Service Logs
Write-Host "`n[1/4] Collecting runner service logs..." -ForegroundColor Yellow
$runnerLogPath = Join-Path $collectionPath "runner-service.log"
$runnerLogs = @()

# Check for GitHub Actions runner logs
$possibleRunnerPaths = @(
    "$env:RUNNER_ROOT\_diag",
    "C:\actions-runner\_diag",
    "$env:USERPROFILE\actions-runner\_diag",
    ".\_diag"
)

foreach ($path in $possibleRunnerPaths) {
    if (Test-Path $path) {
        Write-Host "  Found runner logs at: $path" -ForegroundColor Gray
        $logs = Get-ChildItem -Path $path -Filter "*.log" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt $startDate } |
            Sort-Object LastWriteTime -Descending

        foreach ($log in $logs) {
            $runnerLogs += @{
                Source = $log.FullName
                Content = Get-Content $log.FullName -ErrorAction SilentlyContinue
                Time = $log.LastWriteTime
            }
        }
    }
}

if ($runnerLogs.Count -gt 0) {
    $runnerLogs | ForEach-Object {
        Add-Content -Path $runnerLogPath -Value "=== $($_.Source) - $($_.Time) ==="
        Add-Content -Path $runnerLogPath -Value $_.Content
        Add-Content -Path $runnerLogPath -Value "`n"
    }
    Write-Host "  Collected $($runnerLogs.Count) runner log files" -ForegroundColor Green
} else {
    Add-Content -Path $runnerLogPath -Value "No runner service logs found for the specified time period."
    Write-Host "  No runner logs found" -ForegroundColor Gray
}

# Collect Job Execution Logs
Write-Host "`n[2/4] Collecting job execution logs..." -ForegroundColor Yellow
$jobLogPath = Join-Path $collectionPath "job-executions.log"
$jobLogs = @()

# Look for workflow run logs
$possibleJobPaths = @(
    "$env:RUNNER_ROOT\_work",
    "C:\actions-runner\_work",
    "$env:USERPROFILE\actions-runner\_work",
    ".\_work"
)

foreach ($path in $possibleJobPaths) {
    if (Test-Path $path) {
        Write-Host "  Found job logs at: $path" -ForegroundColor Gray
        $logs = Get-ChildItem -Path $path -Filter "*.log" -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt $startDate } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 50  # Limit to prevent overwhelming

        foreach ($log in $logs) {
            $jobLogs += @{
                Source = $log.FullName
                Time = $log.LastWriteTime
                Size = $log.Length
            }
        }
    }
}

if ($jobLogs.Count -gt 0) {
    $summary = $jobLogs | ForEach-Object {
        "[$(Get-Date $_.Time -Format 'yyyy-MM-dd HH:mm:ss')] $($_.Source) ($([math]::Round($_.Size/1KB, 2)) KB)"
    }
    Set-Content -Path $jobLogPath -Value "=== Job Execution Logs Summary ==="
    Add-Content -Path $jobLogPath -Value "Total jobs logged: $($jobLogs.Count)"
    Add-Content -Path $jobLogPath -Value "`nLog Files:"
    Add-Content -Path $jobLogPath -Value $summary
    Write-Host "  Found $($jobLogs.Count) job execution logs" -ForegroundColor Green
} else {
    Set-Content -Path $jobLogPath -Value "No job execution logs found for the specified time period."
    Write-Host "  No job logs found" -ForegroundColor Gray
}

# Collect System Performance Logs
Write-Host "`n[3/4] Collecting system performance logs..." -ForegroundColor Yellow
$perfLogPath = Join-Path $collectionPath "system-performance.log"

$perfData = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    CPU = Get-CimInstance Win32_Processor | Select-Object Name, LoadPercentage, NumberOfCores, NumberOfLogicalProcessors
    Memory = Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory
    Disk = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 } | Select-Object DeviceID, Size, FreeSpace
    Process = Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, CPU, WorkingSet, Id
}

Set-Content -Path $perfLogPath -Value "=== System Performance Snapshot ==="
Add-Content -Path $perfLogPath -Value "Collected: $($perfData.Timestamp)"
Add-Content -Path $perfLogPath -Value "`n=== CPU Information ==="
Add-Content -Path $perfLogPath -Value ($perfData.CPU | Format-List | Out-String)
Add-Content -Path $perfLogPath -Value "`n=== Memory Information ==="
Add-Content -Path $perfLogPath -Value ($perfData.Memory | Format-List | Out-String)
Add-Content -Path $perfLogPath -Value "`n=== Disk Information ==="
Add-Content -Path $perfLogPath -Value ($perfData.Disk | Format-Table | Out-String)
Add-Content -Path $perfLogPath -Value "`n=== Top 10 Processes by CPU ==="
Add-Content -Path $perfLogPath -Value ($perfData.Process | Format-Table | Out-String)

Write-Host "  Collected system performance snapshot" -ForegroundColor Green

# Collect Security Audit Logs
Write-Host "`n[4/4] Collecting security audit logs..." -ForegroundColor Yellow
$securityLogPath = Join-Path $collectionPath "security-audit.log"

$securityInfo = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    User = $env:USERNAME
    Computer = $env:COMPUTERNAME
    FirewallStatus = Get-NetFirewallProfile | Select-Object Name, Enabled
    RecentLogons = @()
}

# Try to get recent security events if Windows Event Log is available
if ($IncludeWindowsEvents) {
    try {
        $securityEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            StartTime = $startDate
            ID = @(4624, 4625, 4672)  # Logon success, failure, special privileges
        } -MaxEvents 100 -ErrorAction SilentlyContinue

        $securityInfo.RecentLogons = $securityEvents | ForEach-Object {
            @{
                Time = $_.TimeCreated
                EventID = $_.Id
                Message = $_.Message.Split("`n")[0]
            }
        }
        Write-Host "  Collected $($securityEvents.Count) Windows security events" -ForegroundColor Green
    } catch {
        Write-Host "  Unable to access Windows Event Log (may require admin privileges)" -ForegroundColor Gray
    }
}

Set-Content -Path $securityLogPath -Value "=== Security Audit Log ==="
Add-Content -Path $securityLogPath -Value "Collected: $($securityInfo.Timestamp)"
Add-Content -Path $securityLogPath -Value "User: $($securityInfo.User)"
Add-Content -Path $securityLogPath -Value "Computer: $($securityInfo.Computer)"
Add-Content -Path $securityLogPath -Value "`n=== Firewall Status ==="
Add-Content -Path $securityLogPath -Value ($securityInfo.FirewallStatus | Format-Table | Out-String)

if ($securityInfo.RecentLogons.Count -gt 0) {
    Add-Content -Path $securityLogPath -Value "`n=== Recent Security Events ==="
    foreach ($event in $securityInfo.RecentLogons) {
        Add-Content -Path $securityLogPath -Value "[$($event.Time)] Event $($event.EventID): $($event.Message)"
    }
}

Write-Host "  Collected security audit information" -ForegroundColor Green

# Create summary manifest
Write-Host "`nCreating collection manifest..." -ForegroundColor Yellow
$manifestPath = Join-Path $collectionPath "manifest.json"

$manifest = @{
    CollectionTime = $timestamp
    DaysCollected = $Days
    OutputPath = $collectionPath
    Summary = @{
        RunnerLogs = $runnerLogs.Count
        JobLogs = $jobLogs.Count
        PerformanceSnapshot = $true
        SecurityAudit = $true
        WindowsEvents = $IncludeWindowsEvents
    }
}

$manifest | ConvertTo-Json -Depth 3 | Set-Content -Path $manifestPath
Write-Host "  Created manifest: manifest.json" -ForegroundColor Green

# Display summary
Write-Host "`n=== Collection Complete ===" -ForegroundColor Cyan
Write-Host "Location: $collectionPath" -ForegroundColor White
Write-Host "`nCollected:" -ForegroundColor White
Write-Host "  - Runner service logs: $($runnerLogs.Count) files" -ForegroundColor Gray
Write-Host "  - Job execution logs: $($jobLogs.Count) files" -ForegroundColor Gray
Write-Host "  - System performance: 1 snapshot" -ForegroundColor Gray
Write-Host "  - Security audit: 1 report" -ForegroundColor Gray
if ($IncludeWindowsEvents) {
    Write-Host "  - Windows events: $($securityInfo.RecentLogons.Count) events" -ForegroundColor Gray
}

Write-Host "`nFiles created:" -ForegroundColor White
Get-ChildItem $collectionPath | ForEach-Object {
    Write-Host "  - $($_.Name) ($([math]::Round($_.Length/1KB, 2)) KB)" -ForegroundColor Gray
}

Write-Host "`nLog collection completed successfully!" -ForegroundColor Green
