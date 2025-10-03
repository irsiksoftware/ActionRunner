#Requires -Version 5.1

<#
.SYNOPSIS
    Collects GitHub Actions runner logs for debugging and compliance

.DESCRIPTION
    Comprehensive log collection script that gathers:
    - Runner service logs
    - Job execution logs
    - System performance logs
    - Security audit logs
    - Docker logs (if available)

    Outputs to a structured directory with timestamped archives.

.PARAMETER OutputPath
    Directory to store collected logs (default: logs/collected)

.PARAMETER IncludeSystem
    Include system-level logs (Event Logs, Performance Counters)

.PARAMETER IncludeSecurity
    Include security audit logs

.PARAMETER Days
    Number of days of history to collect (default: 7)

.PARAMETER CreateArchive
    Create compressed archive of collected logs

.EXAMPLE
    .\collect-logs.ps1
    .\collect-logs.ps1 -OutputPath "C:\logs\runner-archive" -CreateArchive
    .\collect-logs.ps1 -IncludeSystem -IncludeSecurity -Days 30

.NOTES
    Author: GitHub Actions Runner Team
    Version: 1.0.0
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "logs\collected",

    [Parameter(Mandatory=$false)]
    [switch]$IncludeSystem,

    [Parameter(Mandatory=$false)]
    [switch]$IncludeSecurity,

    [Parameter(Mandatory=$false)]
    [int]$Days = 7,

    [Parameter(Mandatory=$false)]
    [switch]$CreateArchive
)

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$collectionPath = Join-Path $OutputPath $timestamp

# Create output directory
if (-not (Test-Path $collectionPath)) {
    New-Item -ItemType Directory -Path $collectionPath -Force | Out-Null
}

$logFile = Join-Path $collectionPath "collection-log.txt"

# Function to log messages
function Write-CollectionLog {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$ts] [$Level] $Message"
    Add-Content -Path $logFile -Value $logMessage

    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARN" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }
}

Write-Host "`n=== GitHub Actions Runner Log Collection ===" -ForegroundColor Cyan
Write-Host "Timestamp: $timestamp" -ForegroundColor Gray
Write-Host "Output: $collectionPath`n" -ForegroundColor Gray

Write-CollectionLog "Starting log collection..."
Write-CollectionLog "Collection period: Last $Days days"

# 1. Collect Runner Service Logs
Write-CollectionLog "Collecting runner service logs..."

try {
    $runnerServices = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue

    if ($runnerServices) {
        $serviceInfo = @()
        foreach ($service in $runnerServices) {
            $serviceInfo += [PSCustomObject]@{
                Name = $service.Name
                DisplayName = $service.DisplayName
                Status = $service.Status
                StartType = $service.StartType
            }
        }

        $serviceInfo | ConvertTo-Json -Depth 5 | Out-File (Join-Path $collectionPath "runner-services.json")
        $serviceInfo | Format-Table -AutoSize | Out-File (Join-Path $collectionPath "runner-services.txt")
        Write-CollectionLog "Runner service information collected" "SUCCESS"
    } else {
        Write-CollectionLog "No runner services found" "WARN"
    }
} catch {
    Write-CollectionLog "Failed to collect runner service info: $($_.Exception.Message)" "ERROR"
}

# 2. Collect Runner Diagnostic Logs
Write-CollectionLog "Collecting runner diagnostic logs..."

$diagPaths = @(
    "_diag",
    "..\..\_diag",
    "$env:GITHUB_RUNNER_HOME\_diag"
)

$diagLogsCollected = $false
foreach ($diagPath in $diagPaths) {
    if (Test-Path $diagPath) {
        try {
            $cutoffDate = (Get-Date).AddDays(-$Days)
            $diagLogs = Get-ChildItem -Path $diagPath -Filter "*.log" -ErrorAction SilentlyContinue |
                        Where-Object { $_.LastWriteTime -gt $cutoffDate }

            if ($diagLogs) {
                $diagDir = Join-Path $collectionPath "runner-diag"
                New-Item -ItemType Directory -Path $diagDir -Force | Out-Null

                foreach ($log in $diagLogs) {
                    Copy-Item -Path $log.FullName -Destination $diagDir -Force
                }

                Write-CollectionLog "Collected $($diagLogs.Count) diagnostic log files from $diagPath" "SUCCESS"
                $diagLogsCollected = $true
                break
            }
        } catch {
            Write-CollectionLog "Failed to collect from $diagPath`: $($_.Exception.Message)" "WARN"
        }
    }
}

if (-not $diagLogsCollected) {
    Write-CollectionLog "No runner diagnostic logs found" "WARN"
}

# 3. Collect Job Execution Logs
Write-CollectionLog "Collecting job execution logs..."

$workPaths = @(
    "_work",
    "..\..\_work",
    "$env:GITHUB_RUNNER_HOME\_work"
)

$jobLogsCollected = $false
foreach ($workPath in $workPaths) {
    if (Test-Path $workPath) {
        try {
            $cutoffDate = (Get-Date).AddDays(-$Days)
            $jobLogs = Get-ChildItem -Path $workPath -Recurse -Filter "*.log" -ErrorAction SilentlyContinue |
                       Where-Object { $_.LastWriteTime -gt $cutoffDate } |
                       Select-Object -First 100  # Limit to prevent excessive collection

            if ($jobLogs) {
                $jobDir = Join-Path $collectionPath "job-logs"
                New-Item -ItemType Directory -Path $jobDir -Force | Out-Null

                foreach ($log in $jobLogs) {
                    $relativePath = $log.FullName.Replace($workPath, "").TrimStart('\')
                    $destPath = Join-Path $jobDir $relativePath
                    $destDir = Split-Path -Parent $destPath

                    if (-not (Test-Path $destDir)) {
                        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                    }

                    Copy-Item -Path $log.FullName -Destination $destPath -Force
                }

                Write-CollectionLog "Collected $($jobLogs.Count) job execution logs from $workPath" "SUCCESS"
                $jobLogsCollected = $true
                break
            }
        } catch {
            Write-CollectionLog "Failed to collect from $workPath`: $($_.Exception.Message)" "WARN"
        }
    }
}

if (-not $jobLogsCollected) {
    Write-CollectionLog "No job execution logs found" "WARN"
}

# 4. Collect Health Check Logs
Write-CollectionLog "Collecting health check logs..."

$healthLogPaths = @("logs\health-check.log", "logs\monitor-runner.log")
foreach ($healthLog in $healthLogPaths) {
    if (Test-Path $healthLog) {
        try {
            Copy-Item -Path $healthLog -Destination $collectionPath -Force
            Write-CollectionLog "Collected $healthLog" "SUCCESS"
        } catch {
            Write-CollectionLog "Failed to collect $healthLog`: $($_.Exception.Message)" "WARN"
        }
    }
}

# 5. Collect System Performance Data
if ($IncludeSystem) {
    Write-CollectionLog "Collecting system performance data..."

    try {
        $sysInfo = @{
            Timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            ComputerName = $env:COMPUTERNAME
            OS = (Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, OSArchitecture, LastBootUpTime)
            CPU = (Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed)
            Memory = @{
                TotalGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
                Available = (Get-CimInstance Win32_OperatingSystem | Select-Object FreePhysicalMemory, TotalVisibleMemorySize)
            }
            Disk = (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } |
                    Select-Object Name, @{N='UsedGB';E={[math]::Round($_.Used/1GB,2)}}, @{N='FreeGB';E={[math]::Round($_.Free/1GB,2)}})
        }

        $sysInfo | ConvertTo-Json -Depth 10 | Out-File (Join-Path $collectionPath "system-info.json")
        Write-CollectionLog "System performance data collected" "SUCCESS"
    } catch {
        Write-CollectionLog "Failed to collect system performance data: $($_.Exception.Message)" "ERROR"
    }
}

# 6. Collect Windows Event Logs (Runner-related)
if ($IncludeSystem) {
    Write-CollectionLog "Collecting Windows Event Logs..."

    try {
        $cutoffDate = (Get-Date).AddDays(-$Days)
        $eventDir = Join-Path $collectionPath "event-logs"
        New-Item -ItemType Directory -Path $eventDir -Force | Out-Null

        # Application logs related to runner
        $appEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Application'
            StartTime = $cutoffDate
        } -ErrorAction SilentlyContinue |
        Where-Object { $_.Message -match 'actions\.runner|github' }

        if ($appEvents) {
            $appEvents | Select-Object TimeCreated, Level, Message, Id |
            Export-Csv -Path (Join-Path $eventDir "application-events.csv") -NoTypeInformation
            Write-CollectionLog "Collected $($appEvents.Count) application events" "SUCCESS"
        }

        # System logs
        $sysEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            StartTime = $cutoffDate
            Level = 1,2,3  # Critical, Error, Warning
        } -MaxEvents 1000 -ErrorAction SilentlyContinue

        if ($sysEvents) {
            $sysEvents | Select-Object TimeCreated, Level, Message, Id |
            Export-Csv -Path (Join-Path $eventDir "system-events.csv") -NoTypeInformation
            Write-CollectionLog "Collected $($sysEvents.Count) system events" "SUCCESS"
        }
    } catch {
        Write-CollectionLog "Failed to collect event logs: $($_.Exception.Message)" "WARN"
    }
}

# 7. Collect Security Audit Logs
if ($IncludeSecurity) {
    Write-CollectionLog "Collecting security audit logs..."

    try {
        $cutoffDate = (Get-Date).AddDays(-$Days)
        $securityDir = Join-Path $collectionPath "security-logs"
        New-Item -ItemType Directory -Path $securityDir -Force | Out-Null

        $secEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            StartTime = $cutoffDate
        } -MaxEvents 5000 -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -in @(4624, 4625, 4648, 4672, 4720, 4726) }  # Logon events, privilege use, account management

        if ($secEvents) {
            $secEvents | Select-Object TimeCreated, Id, Message |
            Export-Csv -Path (Join-Path $securityDir "security-events.csv") -NoTypeInformation
            Write-CollectionLog "Collected $($secEvents.Count) security events" "SUCCESS"
        }
    } catch {
        Write-CollectionLog "Failed to collect security logs: $($_.Exception.Message)" "WARN"
    }
}

# 8. Collect Docker Logs (if available)
Write-CollectionLog "Checking for Docker logs..."

try {
    $dockerAvailable = Get-Command docker -ErrorAction SilentlyContinue
    if ($dockerAvailable) {
        $dockerDir = Join-Path $collectionPath "docker-logs"
        New-Item -ItemType Directory -Path $dockerDir -Force | Out-Null

        # Docker system info
        docker info 2>&1 | Out-File (Join-Path $dockerDir "docker-info.txt")

        # Container logs
        $containers = docker ps -a --format "{{.ID}}|{{.Names}}" 2>$null
        if ($containers) {
            foreach ($container in $containers) {
                $parts = $container -split '\|'
                $id = $parts[0]
                $name = $parts[1]

                try {
                    docker logs --since "${Days}d" $id 2>&1 | Out-File (Join-Path $dockerDir "${name}_${id}.log")
                } catch {
                    Write-CollectionLog "Failed to collect logs for container $name" "WARN"
                }
            }
            Write-CollectionLog "Collected Docker container logs" "SUCCESS"
        }

        # Docker events
        docker events --since "${Days}d" --until "0s" 2>&1 | Out-File (Join-Path $dockerDir "docker-events.txt")
    } else {
        Write-CollectionLog "Docker not available" "INFO"
    }
} catch {
    Write-CollectionLog "Failed to collect Docker logs: $($_.Exception.Message)" "WARN"
}

# 9. Create Summary Report
Write-CollectionLog "Creating summary report..."

$summary = @{
    CollectionTimestamp = $timestamp
    CollectionPeriodDays = $Days
    OutputPath = $collectionPath
    FilesCollected = (Get-ChildItem -Path $collectionPath -Recurse -File).Count
    TotalSizeMB = [math]::Round((Get-ChildItem -Path $collectionPath -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
    IncludeSystem = $IncludeSystem.IsPresent
    IncludeSecurity = $IncludeSecurity.IsPresent
}

$summary | ConvertTo-Json -Depth 5 | Out-File (Join-Path $collectionPath "summary.json")
Write-CollectionLog "Summary report created" "SUCCESS"

# 10. Create Archive (if requested)
if ($CreateArchive) {
    Write-CollectionLog "Creating compressed archive..."

    try {
        $archivePath = Join-Path $OutputPath "runner-logs-${timestamp}.zip"
        Compress-Archive -Path $collectionPath -DestinationPath $archivePath -Force
        Write-CollectionLog "Archive created: $archivePath" "SUCCESS"

        Write-Host "`nArchive created successfully:" -ForegroundColor Green
        Write-Host "  Path: $archivePath" -ForegroundColor Cyan
        Write-Host "  Size: $([math]::Round((Get-Item $archivePath).Length / 1MB, 2)) MB" -ForegroundColor Cyan
    } catch {
        Write-CollectionLog "Failed to create archive: $($_.Exception.Message)" "ERROR"
    }
}

# Final Summary
Write-Host "`n=== Collection Complete ===" -ForegroundColor Green
Write-Host "Output Directory: $collectionPath" -ForegroundColor Cyan
Write-Host "Files Collected: $($summary.FilesCollected)" -ForegroundColor Cyan
Write-Host "Total Size: $($summary.TotalSizeMB) MB" -ForegroundColor Cyan
Write-Host "Log File: $logFile`n" -ForegroundColor Cyan

Write-CollectionLog "Log collection completed successfully"
exit 0
