<#
.SYNOPSIS
    Rotate and compress old log files.

.DESCRIPTION
    Implements log rotation policy:
    - Keeps logs from last 30 days uncompressed
    - Compresses logs older than 30 days
    - Deletes logs older than 90 days
    - Archives compressed logs to logs/archive/

.PARAMETER LogPath
    Path to logs directory. Defaults to ./logs

.PARAMETER RetentionDays
    Number of days to keep uncompressed logs. Defaults to 30.

.PARAMETER ArchiveRetentionDays
    Number of days to keep archived logs. Defaults to 90.

.PARAMETER DryRun
    Show what would be done without making changes

.EXAMPLE
    .\rotate-logs.ps1
    Rotate logs using default settings

.EXAMPLE
    .\rotate-logs.ps1 -RetentionDays 14 -DryRun
    Preview rotation with 14-day retention
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$LogPath = ".\logs",

    [Parameter()]
    [int]$RetentionDays = 30,

    [Parameter()]
    [int]$ArchiveRetentionDays = 90,

    [Parameter()]
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "=== Log Rotation ===" -ForegroundColor Cyan
Write-Host "Log Path: $LogPath" -ForegroundColor White
Write-Host "Retention: $RetentionDays days (uncompressed)" -ForegroundColor White
Write-Host "Archive Retention: $ArchiveRetentionDays days (compressed)" -ForegroundColor White
if ($DryRun) {
    Write-Host "DRY RUN MODE - No changes will be made" -ForegroundColor Yellow
}
Write-Host ""

# Ensure log path exists
if (-not (Test-Path $LogPath)) {
    Write-Host "Log path does not exist: $LogPath" -ForegroundColor Red
    exit 1
}

# Create archive directory
$archivePath = Join-Path $LogPath "archive"
if (-not (Test-Path $archivePath)) {
    if (-not $DryRun) {
        New-Item -Path $archivePath -ItemType Directory -Force | Out-Null
    }
    Write-Host "Created archive directory: $archivePath" -ForegroundColor Green
}

# Calculate cutoff dates
$compressionDate = (Get-Date).AddDays(-$RetentionDays)
$deletionDate = (Get-Date).AddDays(-$ArchiveRetentionDays)

Write-Host "Compression cutoff: $($compressionDate.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
Write-Host "Deletion cutoff: $($deletionDate.ToString('yyyy-MM-dd'))" -ForegroundColor Gray
Write-Host ""

# Statistics
$stats = @{
    FilesScanned = 0
    FilesCompressed = 0
    FilesDeleted = 0
    BytesFreed = 0
    BytesCompressed = 0
}

# Step 1: Compress old logs
Write-Host "[1/2] Compressing logs older than $RetentionDays days..." -ForegroundColor Yellow

$logsToCompress = @(Get-ChildItem -Path $LogPath -Recurse -File |
    Where-Object {
        $_.Extension -in @('.log', '.txt', '.json') -and
        $_.LastWriteTime -lt $compressionDate -and
        $_.Directory.Name -ne 'archive'
    })

$stats.FilesScanned = $logsToCompress.Count

if ($logsToCompress.Count -eq 0) {
    Write-Host "  No logs to compress" -ForegroundColor Gray
} else {
    Write-Host "  Found $($logsToCompress.Count) logs to compress" -ForegroundColor White

    foreach ($log in $logsToCompress) {
        try {
            $stats.FilesScanned++
            $relativePath = $log.FullName.Substring($LogPath.Length + 1)
            $archiveName = "$($log.BaseName)_$($log.LastWriteTime.ToString('yyyy-MM-dd')).zip"
            $archiveFullPath = Join-Path $archivePath $archiveName

            if ($DryRun) {
                Write-Host "  [DRY RUN] Would compress: $relativePath -> archive/$archiveName" -ForegroundColor Gray
            } else {
                # Compress the file
                Compress-Archive -Path $log.FullName -DestinationPath $archiveFullPath -Force

                # Verify compression succeeded
                if (Test-Path $archiveFullPath) {
                    $originalSize = $log.Length
                    $compressedSize = (Get-Item $archiveFullPath).Length
                    $stats.BytesFreed += $originalSize - $compressedSize
                    $stats.BytesCompressed += $compressedSize
                    $stats.FilesCompressed++

                    # Delete original
                    Remove-Item $log.FullName -Force
                    Write-Host "  Compressed: $relativePath (saved $([math]::Round(($originalSize - $compressedSize) / 1KB, 2)) KB)" -ForegroundColor Green
                }
            }
        } catch {
            Write-Host "  ERROR compressing $($log.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Step 2: Delete old archives
Write-Host "`n[2/2] Deleting archives older than $ArchiveRetentionDays days..." -ForegroundColor Yellow

$archivesToDelete = @(Get-ChildItem -Path $archivePath -Filter "*.zip" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $deletionDate })

if ($archivesToDelete.Count -eq 0) {
    Write-Host "  No archives to delete" -ForegroundColor Gray
} else {
    Write-Host "  Found $($archivesToDelete.Count) archives to delete" -ForegroundColor White

    foreach ($archive in $archivesToDelete) {
        try {
            $size = $archive.Length
            if ($DryRun) {
                Write-Host "  [DRY RUN] Would delete: $($archive.Name) ($([math]::Round($size / 1KB, 2)) KB)" -ForegroundColor Gray
            } else {
                Remove-Item $archive.FullName -Force
                $stats.BytesFreed += $size
                $stats.FilesDeleted++
                Write-Host "  Deleted: $($archive.Name) (freed $([math]::Round($size / 1KB, 2)) KB)" -ForegroundColor Green
            }
        } catch {
            Write-Host "  ERROR deleting $($archive.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Step 3: Clean up empty directories
Write-Host "`n[3/3] Cleaning up empty directories..." -ForegroundColor Yellow
$emptyDirs = @(Get-ChildItem -Path $LogPath -Recurse -Directory |
    Where-Object { $_.Name -ne 'archive' -and @(Get-ChildItem $_.FullName -File).Count -eq 0 })

if ($emptyDirs.Count -eq 0) {
    Write-Host "  No empty directories found" -ForegroundColor Gray
} else {
    foreach ($dir in $emptyDirs) {
        if ($DryRun) {
            Write-Host "  [DRY RUN] Would remove empty directory: $($dir.Name)" -ForegroundColor Gray
        } else {
            Remove-Item $dir.FullName -Force -Recurse
            Write-Host "  Removed empty directory: $($dir.Name)" -ForegroundColor Green
        }
    }
}

# Display summary
Write-Host "`n=== Rotation Summary ===" -ForegroundColor Cyan
Write-Host "Files scanned: $($stats.FilesScanned)" -ForegroundColor White
Write-Host "Files compressed: $($stats.FilesCompressed)" -ForegroundColor White
Write-Host "Files deleted: $($stats.FilesDeleted)" -ForegroundColor White
Write-Host "Space freed: $([math]::Round($stats.BytesFreed / 1MB, 2)) MB" -ForegroundColor White
Write-Host "Archive size: $([math]::Round($stats.BytesCompressed / 1MB, 2)) MB" -ForegroundColor White

if ($stats.FilesCompressed -gt 0 -or $stats.FilesDeleted -gt 0) {
    $compressionRatio = if ($stats.BytesCompressed -gt 0) {
        [math]::Round((1 - ($stats.BytesCompressed / ($stats.BytesCompressed + $stats.BytesFreed))) * 100, 1)
    } else {
        0
    }
    Write-Host "Compression ratio: $compressionRatio%" -ForegroundColor White
}

# Current disk usage
Write-Host "`n=== Current Log Disk Usage ===" -ForegroundColor Cyan
$currentLogs = @(Get-ChildItem -Path $LogPath -Recurse -File)
$totalSize = if ($currentLogs.Count -gt 0) {
    ($currentLogs | Measure-Object -Property Length -Sum).Sum
} else {
    0
}
Write-Host "Total files: $($currentLogs.Count)" -ForegroundColor White
Write-Host "Total size: $([math]::Round($totalSize / 1MB, 2)) MB" -ForegroundColor White

if ($DryRun) {
    Write-Host "`nDRY RUN completed - No changes were made" -ForegroundColor Yellow
} else {
    Write-Host "`nLog rotation completed successfully!" -ForegroundColor Green
}

# Return stats for automation
return $stats
