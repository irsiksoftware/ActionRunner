#Requires -Version 5.1

<#
.SYNOPSIS
    Rotates and manages GitHub Actions runner logs

.DESCRIPTION
    Implements log rotation policy to:
    - Archive old logs
    - Compress archived logs
    - Delete logs older than retention period
    - Prevent disk space issues
    - Maintain audit trail compliance

.PARAMETER LogDirectory
    Directory containing logs to rotate (default: logs/)

.PARAMETER RetentionDays
    Number of days to retain logs (default: 30)

.PARAMETER CompressLogs
    Compress rotated logs to save disk space (default: true)

.PARAMETER ArchiveDirectory
    Directory to store archived logs (default: logs/archive)

.PARAMETER DryRun
    Perform dry run without deleting files

.EXAMPLE
    .\rotate-logs.ps1
    .\rotate-logs.ps1 -RetentionDays 90
    .\rotate-logs.ps1 -DryRun
    .\rotate-logs.ps1 -LogDirectory "C:\runner\logs" -ArchiveDirectory "D:\archive"

.NOTES
    Author: GitHub Actions Runner Team
    Version: 1.0.0
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$LogDirectory = "logs",

    [Parameter(Mandatory=$false)]
    [int]$RetentionDays = 30,

    [Parameter(Mandatory=$false)]
    [switch]$CompressLogs = $true,

    [Parameter(Mandatory=$false)]
    [string]$ArchiveDirectory = "logs\archive",

    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$rotationLogPath = Join-Path $LogDirectory "rotation-log.txt"

# Create directories if they don't exist
foreach ($dir in @($LogDirectory, $ArchiveDirectory)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# Function to log messages
function Write-RotationLog {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$ts] [$Level] $Message"

    # Ensure log directory exists
    $logDir = Split-Path -Parent $rotationLogPath
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    Add-Content -Path $rotationLogPath -Value $logMessage

    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARN" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }
}

Write-Host "`n=== GitHub Actions Runner Log Rotation ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Log Directory: $LogDirectory" -ForegroundColor Gray
Write-Host "Archive Directory: $ArchiveDirectory" -ForegroundColor Gray
Write-Host "Retention Period: $RetentionDays days" -ForegroundColor Gray
if ($DryRun) {
    Write-Host "MODE: DRY RUN (no files will be modified)" -ForegroundColor Yellow
}
Write-Host ""

Write-RotationLog "Starting log rotation..."
Write-RotationLog "Retention period: $RetentionDays days"
Write-RotationLog "Dry run: $($DryRun.IsPresent)"

$stats = @{
    files_checked = 0
    files_archived = 0
    files_compressed = 0
    files_deleted = 0
    space_freed_mb = 0
    space_saved_compression_mb = 0
    errors = 0
}

# Calculate cutoff date
$cutoffDate = (Get-Date).AddDays(-$RetentionDays)
Write-RotationLog "Cutoff date: $($cutoffDate.ToString('yyyy-MM-dd HH:mm:ss'))"

# 1. Find and process log files
Write-RotationLog "Scanning for log files..."

if (-not (Test-Path $LogDirectory)) {
    Write-RotationLog "Log directory not found: $LogDirectory" "ERROR"
    exit 1
}

try {
    $logFiles = Get-ChildItem -Path $LogDirectory -Filter "*.log" -Recurse -File -ErrorAction SilentlyContinue
    $stats.files_checked = $logFiles.Count
    Write-RotationLog "Found $($logFiles.Count) log files"

    if ($logFiles.Count -eq 0) {
        Write-RotationLog "No log files found to rotate" "WARN"
        exit 0
    }

    # 2. Process old log files
    $oldLogs = $logFiles | Where-Object { $_.LastWriteTime -lt $cutoffDate }

    if ($oldLogs) {
        Write-RotationLog "Found $($oldLogs.Count) files older than $RetentionDays days"

        foreach ($log in $oldLogs) {
            try {
                $fileSizeMB = [math]::Round($log.Length / 1MB, 2)
                Write-RotationLog "Processing: $($log.Name) ($fileSizeMB MB, Last Modified: $($log.LastWriteTime.ToString('yyyy-MM-dd')))"

                if (-not $DryRun) {
                    # Archive the file
                    $relativePath = $log.FullName.Replace($LogDirectory, "").TrimStart('\')
                    $archivePath = Join-Path $ArchiveDirectory $relativePath
                    $archiveDir = Split-Path -Parent $archivePath

                    if (-not (Test-Path $archiveDir)) {
                        New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
                    }

                    Copy-Item -Path $log.FullName -Destination $archivePath -Force
                    $stats.files_archived++
                    Write-RotationLog "  Archived to: $archivePath"

                    # Compress if requested
                    if ($CompressLogs) {
                        $compressedPath = "${archivePath}.gz"
                        try {
                            # Use .NET compression
                            $inputFile = [System.IO.File]::OpenRead($archivePath)
                            $outputFile = [System.IO.File]::Create($compressedPath)
                            $gzipStream = New-Object System.IO.Compression.GZipStream($outputFile, [System.IO.Compression.CompressionMode]::Compress)

                            $inputFile.CopyTo($gzipStream)

                            $gzipStream.Close()
                            $outputFile.Close()
                            $inputFile.Close()

                            $compressedSize = [math]::Round((Get-Item $compressedPath).Length / 1MB, 2)
                            $savedSpace = [math]::Round($fileSizeMB - $compressedSize, 2)

                            Write-RotationLog "  Compressed: $fileSizeMB MB -> $compressedSize MB (saved: $savedSpace MB)"
                            $stats.files_compressed++
                            $stats.space_saved_compression_mb += $savedSpace

                            # Remove uncompressed archive
                            Remove-Item -Path $archivePath -Force
                        } catch {
                            Write-RotationLog "  Failed to compress: $($_.Exception.Message)" "WARN"
                        }
                    }

                    # Delete original log file
                    Remove-Item -Path $log.FullName -Force
                    $stats.files_deleted++
                    $stats.space_freed_mb += $fileSizeMB
                    Write-RotationLog "  Deleted original file" "SUCCESS"
                } else {
                    Write-RotationLog "  [DRY RUN] Would archive and delete" "INFO"
                    $stats.space_freed_mb += $fileSizeMB
                }
            } catch {
                Write-RotationLog "  Error processing $($log.Name): $($_.Exception.Message)" "ERROR"
                $stats.errors++
            }
        }
    } else {
        Write-RotationLog "No files older than $RetentionDays days found" "INFO"
    }

    # 3. Process current log files that need rotation (>100MB)
    Write-RotationLog "`nChecking for large log files..."
    $largeLogs = $logFiles | Where-Object { $_.Length -gt 100MB -and $_.LastWriteTime -ge $cutoffDate }

    if ($largeLogs) {
        Write-RotationLog "Found $($largeLogs.Count) large log files (>100MB)"

        foreach ($log in $largeLogs) {
            try {
                $fileSizeMB = [math]::Round($log.Length / 1MB, 2)
                Write-RotationLog "Large file: $($log.Name) ($fileSizeMB MB)"

                if (-not $DryRun) {
                    # Rotate by appending timestamp and creating new empty file
                    $rotatedName = "$($log.BaseName)-$timestamp$($log.Extension)"
                    $rotatedPath = Join-Path $log.DirectoryName $rotatedName

                    Move-Item -Path $log.FullName -Destination $rotatedPath -Force
                    Write-RotationLog "  Rotated to: $rotatedName"

                    # Create new empty log file
                    New-Item -ItemType File -Path $log.FullName -Force | Out-Null
                    Write-RotationLog "  Created new empty log file" "SUCCESS"

                    # Archive the rotated file
                    $relativePath = $rotatedPath.Replace($LogDirectory, "").TrimStart('\')
                    $archivePath = Join-Path $ArchiveDirectory $relativePath

                    $archiveDir = Split-Path -Parent $archivePath
                    if (-not (Test-Path $archiveDir)) {
                        New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
                    }

                    Move-Item -Path $rotatedPath -Destination $archivePath -Force
                    $stats.files_archived++
                    Write-RotationLog "  Moved to archive: $archivePath"

                    # Compress
                    if ($CompressLogs) {
                        $compressedPath = "${archivePath}.gz"
                        try {
                            $inputFile = [System.IO.File]::OpenRead($archivePath)
                            $outputFile = [System.IO.File]::Create($compressedPath)
                            $gzipStream = New-Object System.IO.Compression.GZipStream($outputFile, [System.IO.Compression.CompressionMode]::Compress)

                            $inputFile.CopyTo($gzipStream)

                            $gzipStream.Close()
                            $outputFile.Close()
                            $inputFile.Close()

                            $compressedSize = [math]::Round((Get-Item $compressedPath).Length / 1MB, 2)
                            $savedSpace = [math]::Round($fileSizeMB - $compressedSize, 2)

                            Write-RotationLog "  Compressed: $fileSizeMB MB -> $compressedSize MB (saved: $savedSpace MB)"
                            $stats.files_compressed++
                            $stats.space_saved_compression_mb += $savedSpace

                            Remove-Item -Path $archivePath -Force
                        } catch {
                            Write-RotationLog "  Failed to compress: $($_.Exception.Message)" "WARN"
                        }
                    }
                } else {
                    Write-RotationLog "  [DRY RUN] Would rotate and archive" "INFO"
                }
            } catch {
                Write-RotationLog "  Error processing $($log.Name): $($_.Exception.Message)" "ERROR"
                $stats.errors++
            }
        }
    } else {
        Write-RotationLog "No large log files requiring rotation" "INFO"
    }

    # 4. Clean up very old archives (older than retention + 30 days)
    Write-RotationLog "`nChecking archive directory for very old files..."
    $archiveCutoffDate = (Get-Date).AddDays(-($RetentionDays + 30))

    if (Test-Path $ArchiveDirectory) {
        $oldArchives = Get-ChildItem -Path $ArchiveDirectory -Recurse -File -ErrorAction SilentlyContinue |
                       Where-Object { $_.LastWriteTime -lt $archiveCutoffDate }

        if ($oldArchives) {
            Write-RotationLog "Found $($oldArchives.Count) very old archive files (>$($RetentionDays + 30) days)"

            foreach ($archive in $oldArchives) {
                $archiveSizeMB = [math]::Round($archive.Length / 1MB, 2)
                Write-RotationLog "Removing old archive: $($archive.Name) ($archiveSizeMB MB, Last Modified: $($archive.LastWriteTime.ToString('yyyy-MM-dd')))"

                if (-not $DryRun) {
                    Remove-Item -Path $archive.FullName -Force
                    $stats.files_deleted++
                    $stats.space_freed_mb += $archiveSizeMB
                    Write-RotationLog "  Deleted" "SUCCESS"
                } else {
                    Write-RotationLog "  [DRY RUN] Would delete" "INFO"
                    $stats.space_freed_mb += $archiveSizeMB
                }
            }
        } else {
            Write-RotationLog "No very old archives to remove" "INFO"
        }
    }

} catch {
    Write-RotationLog "Error during log rotation: $($_.Exception.Message)" "ERROR"
    $stats.errors++
}

# 5. Generate summary
Write-Host "`n=== Rotation Summary ===" -ForegroundColor Green
Write-Host "Files Checked: $($stats.files_checked)" -ForegroundColor Cyan
Write-Host "Files Archived: $($stats.files_archived)" -ForegroundColor Cyan
Write-Host "Files Compressed: $($stats.files_compressed)" -ForegroundColor Cyan
Write-Host "Files Deleted: $($stats.files_deleted)" -ForegroundColor Cyan
Write-Host "Space Freed: $([math]::Round($stats.space_freed_mb, 2)) MB" -ForegroundColor Green
Write-Host "Space Saved (Compression): $([math]::Round($stats.space_saved_compression_mb, 2)) MB" -ForegroundColor Green
Write-Host "Errors: $($stats.errors)" -ForegroundColor $(if ($stats.errors -gt 0) { "Red" } else { "Cyan" })

if ($DryRun) {
    Write-Host "`nDRY RUN completed - no files were modified" -ForegroundColor Yellow
}

Write-RotationLog "Log rotation completed"
Write-RotationLog "Summary: Checked=$($stats.files_checked), Archived=$($stats.files_archived), Deleted=$($stats.files_deleted), Space Freed=$($stats.space_freed_mb)MB, Errors=$($stats.errors)"

# Save stats to file
$statsPath = Join-Path $LogDirectory "rotation-stats-$timestamp.json"
$stats | ConvertTo-Json | Out-File $statsPath
Write-RotationLog "Statistics saved to: $statsPath"

exit $(if ($stats.errors -gt 0) { 1 } else { 0 })
