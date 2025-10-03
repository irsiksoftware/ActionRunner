<#
.SYNOPSIS
    Rotates and compresses old log files to manage disk space.

.DESCRIPTION
    This script implements log rotation by:
    - Compressing logs older than specified days
    - Moving compressed logs to archive directory
    - Deleting logs older than retention period
    - Maintaining the last N days of uncompressed logs for quick access

.PARAMETER LogPath
    Path to the logs directory. Default: .\logs

.PARAMETER RetentionDays
    Number of days to keep logs. Default: 30

.PARAMETER CompressAfterDays
    Compress logs older than this many days. Default: 7

.PARAMETER ArchivePath
    Path to store archived (compressed) logs. Default: .\logs\archive

.PARAMETER DeleteArchivesAfterDays
    Delete compressed archives older than this many days. Default: 90

.EXAMPLE
    .\rotate-logs.ps1
    Runs log rotation with default settings.

.EXAMPLE
    .\rotate-logs.ps1 -RetentionDays 60 -CompressAfterDays 14
    Keeps logs for 60 days, compressing those older than 14 days.
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$LogPath = ".\logs",

    [Parameter(Mandatory=$false)]
    [int]$RetentionDays = 30,

    [Parameter(Mandatory=$false)]
    [int]$CompressAfterDays = 7,

    [Parameter(Mandatory=$false)]
    [string]$ArchivePath = ".\logs\archive",

    [Parameter(Mandatory=$false)]
    [int]$DeleteArchivesAfterDays = 90
)

# Ensure paths exist
if (-not (Test-Path $LogPath)) {
    Write-Host "Log path does not exist: $LogPath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $ArchivePath)) {
    New-Item -ItemType Directory -Path $ArchivePath -Force | Out-Null
    Write-Host "Created archive directory: $ArchivePath" -ForegroundColor Green
}

Write-Host "=== GitHub Actions Runner Log Rotation ===" -ForegroundColor Cyan
Write-Host "Start Time: $(Get-Date)" -ForegroundColor Green
Write-Host "Log Path: $LogPath" -ForegroundColor Green
Write-Host "Retention Days: $RetentionDays" -ForegroundColor Green
Write-Host "Compress After Days: $CompressAfterDays" -ForegroundColor Green
Write-Host "Archive Path: $ArchivePath" -ForegroundColor Green
Write-Host ""

# Calculate cutoff dates
$compressDate = (Get-Date).AddDays(-$CompressAfterDays)
$deleteDate = (Get-Date).AddDays(-$RetentionDays)
$archiveDeleteDate = (Get-Date).AddDays(-$DeleteArchivesAfterDays)

$stats = @{
    FilesCompressed = 0
    FilesDeleted = 0
    ArchivesDeleted = 0
    SpaceSaved = 0
    Errors = 0
}

# 1. Compress old logs
Write-Host "[1/3] Compressing logs older than $CompressAfterDays days..." -ForegroundColor Yellow

$logsToCompress = Get-ChildItem -Path $LogPath -Filter "*.log" -File |
    Where-Object { $_.LastWriteTime -lt $compressDate -and $_.LastWriteTime -gt $deleteDate }

foreach ($log in $logsToCompress) {
    try {
        $archiveName = "$($log.BaseName)-$(Get-Date $log.LastWriteTime -Format 'yyyyMMdd').zip"
        $archiveFullPath = Join-Path $ArchivePath $archiveName

        # Skip if already archived
        if (Test-Path $archiveFullPath) {
            Write-Host "  Archive already exists: $archiveName" -ForegroundColor Gray
            Remove-Item $log.FullName -Force
            $stats.FilesCompressed++
            continue
        }

        # Compress the log file
        Compress-Archive -Path $log.FullName -DestinationPath $archiveFullPath -CompressionLevel Optimal

        $originalSize = $log.Length
        $compressedSize = (Get-Item $archiveFullPath).Length
        $spaceSaved = $originalSize - $compressedSize

        Write-Host "  Compressed: $($log.Name) -> $archiveName (saved $([math]::Round($spaceSaved/1KB, 2)) KB)" -ForegroundColor Green

        # Delete original after successful compression
        Remove-Item $log.FullName -Force

        $stats.FilesCompressed++
        $stats.SpaceSaved += $spaceSaved
    } catch {
        Write-Host "  Error compressing $($log.Name): $($_.Exception.Message)" -ForegroundColor Red
        $stats.Errors++
    }
}

# Also compress JSON log files
$jsonLogsToCompress = Get-ChildItem -Path $LogPath -Filter "*.json" -File |
    Where-Object { $_.LastWriteTime -lt $compressDate -and $_.LastWriteTime -gt $deleteDate }

foreach ($log in $jsonLogsToCompress) {
    try {
        $archiveName = "$($log.BaseName)-$(Get-Date $log.LastWriteTime -Format 'yyyyMMdd').zip"
        $archiveFullPath = Join-Path $ArchivePath $archiveName

        if (Test-Path $archiveFullPath) {
            Write-Host "  Archive already exists: $archiveName" -ForegroundColor Gray
            Remove-Item $log.FullName -Force
            $stats.FilesCompressed++
            continue
        }

        Compress-Archive -Path $log.FullName -DestinationPath $archiveFullPath -CompressionLevel Optimal

        $originalSize = $log.Length
        $compressedSize = (Get-Item $archiveFullPath).Length
        $spaceSaved = $originalSize - $compressedSize

        Write-Host "  Compressed: $($log.Name) -> $archiveName (saved $([math]::Round($spaceSaved/1KB, 2)) KB)" -ForegroundColor Green

        Remove-Item $log.FullName -Force

        $stats.FilesCompressed++
        $stats.SpaceSaved += $spaceSaved
    } catch {
        Write-Host "  Error compressing $($log.Name): $($_.Exception.Message)" -ForegroundColor Red
        $stats.Errors++
    }
}

# 2. Delete old uncompressed logs
Write-Host ""
Write-Host "[2/3] Deleting uncompressed logs older than $RetentionDays days..." -ForegroundColor Yellow

$logsToDelete = Get-ChildItem -Path $LogPath -Include "*.log","*.json" -File |
    Where-Object { $_.LastWriteTime -lt $deleteDate }

foreach ($log in $logsToDelete) {
    try {
        Write-Host "  Deleting: $($log.Name) (last modified: $($log.LastWriteTime))" -ForegroundColor Yellow
        Remove-Item $log.FullName -Force
        $stats.FilesDeleted++
    } catch {
        Write-Host "  Error deleting $($log.Name): $($_.Exception.Message)" -ForegroundColor Red
        $stats.Errors++
    }
}

# 3. Delete old archives
Write-Host ""
Write-Host "[3/3] Deleting archives older than $DeleteArchivesAfterDays days..." -ForegroundColor Yellow

$archivesToDelete = Get-ChildItem -Path $ArchivePath -Filter "*.zip" -File |
    Where-Object { $_.LastWriteTime -lt $archiveDeleteDate }

foreach ($archive in $archivesToDelete) {
    try {
        Write-Host "  Deleting archive: $($archive.Name) (last modified: $($archive.LastWriteTime))" -ForegroundColor Yellow
        Remove-Item $archive.FullName -Force
        $stats.ArchivesDeleted++
    } catch {
        Write-Host "  Error deleting archive $($archive.Name): $($_.Exception.Message)" -ForegroundColor Red
        $stats.Errors++
    }
}

# Generate rotation report
Write-Host ""
Write-Host "=== Rotation Summary ===" -ForegroundColor Green
Write-Host "End Time: $(Get-Date)" -ForegroundColor Green
Write-Host "Files Compressed: $($stats.FilesCompressed)" -ForegroundColor Green
Write-Host "Files Deleted: $($stats.FilesDeleted)" -ForegroundColor Green
Write-Host "Archives Deleted: $($stats.ArchivesDeleted)" -ForegroundColor Green
Write-Host "Space Saved by Compression: $([math]::Round($stats.SpaceSaved/1MB, 2)) MB" -ForegroundColor Green
Write-Host "Errors: $($stats.Errors)" -ForegroundColor $(if ($stats.Errors -gt 0) { "Red" } else { "Green" })
Write-Host ""

# Calculate current disk usage
$currentLogs = Get-ChildItem -Path $LogPath -Include "*.log","*.json" -Recurse -File
$currentArchives = Get-ChildItem -Path $ArchivePath -Filter "*.zip" -File

$logsSize = ($currentLogs | Measure-Object -Property Length -Sum).Sum
$archivesSize = ($currentArchives | Measure-Object -Property Length -Sum).Sum

Write-Host "Current Disk Usage:" -ForegroundColor Cyan
Write-Host "  Active Logs: $([math]::Round($logsSize/1MB, 2)) MB ($($currentLogs.Count) files)" -ForegroundColor Gray
Write-Host "  Archived Logs: $([math]::Round($archivesSize/1MB, 2)) MB ($($currentArchives.Count) files)" -ForegroundColor Gray
Write-Host "  Total: $([math]::Round(($logsSize + $archivesSize)/1MB, 2)) MB" -ForegroundColor Gray
Write-Host ""

# Save rotation report
$report = @{
    RotationDate = Get-Date
    Settings = @{
        RetentionDays = $RetentionDays
        CompressAfterDays = $CompressAfterDays
        DeleteArchivesAfterDays = $DeleteArchivesAfterDays
    }
    Statistics = $stats
    CurrentUsage = @{
        ActiveLogsSize = $logsSize
        ActiveLogsCount = $currentLogs.Count
        ArchivedLogsSize = $archivesSize
        ArchivedLogsCount = $currentArchives.Count
        TotalSize = $logsSize + $archivesSize
    }
}

$reportPath = Join-Path $LogPath "rotation-report-$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$report | ConvertTo-Json -Depth 3 | Out-File $reportPath

Write-Host "Rotation report saved to: $reportPath" -ForegroundColor Cyan
