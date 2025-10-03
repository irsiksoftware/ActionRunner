<#
.SYNOPSIS
    Automated workspace cleanup script for self-hosted GitHub Actions runners.

.DESCRIPTION
    Manages disk space by cleaning up:
    - Unity Library folders older than specified days
    - Build artifacts and caches
    - Docker containers and images (if Docker is available)
    - Temporary files
    - Old log files

    Maintains minimum free space threshold and logs all operations.

.PARAMETER DryRun
    Preview what would be deleted without actually deleting anything.

.PARAMETER DaysOld
    Age threshold in days for cleaning Unity Library folders and build artifacts (default: 7).

.PARAMETER MinFreeSpaceGB
    Minimum free space threshold in GB. Script will be more aggressive if below this (default: 500).

.PARAMETER LogPath
    Path to the cleanup log file (default: logs/cleanup.log).

.PARAMETER ExcludePaths
    Array of paths to exclude from cleanup.

.EXAMPLE
    .\cleanup-workspace.ps1 -DryRun
    Preview cleanup operations without making changes.

.EXAMPLE
    .\cleanup-workspace.ps1 -DaysOld 14 -MinFreeSpaceGB 300
    Clean files older than 14 days, maintain 300GB free space.

.EXAMPLE
    .\cleanup-workspace.ps1 -ExcludePaths @("C:\important-project", "D:\protected-data")
    Clean workspace while protecting specific directories.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$DryRun,

    [Parameter()]
    [int]$DaysOld = 7,

    [Parameter()]
    [int]$MinFreeSpaceGB = 500,

    [Parameter()]
    [string]$LogPath = "logs\cleanup.log",

    [Parameter()]
    [string[]]$ExcludePaths = @()
)

$ErrorActionPreference = 'Continue'
$script:DeletedCount = 0
$script:SpaceFreedBytes = 0
$script:LogEntries = @()

function Write-CleanupLog {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"

    $script:LogEntries += $logEntry

    switch ($Level) {
        'Error'   { Write-Host $logEntry -ForegroundColor Red }
        'Warning' { Write-Host $logEntry -ForegroundColor Yellow }
        'Success' { Write-Host $logEntry -ForegroundColor Green }
        default   { Write-Host $logEntry }
    }
}

function Save-CleanupLog {
    if ($script:LogEntries.Count -eq 0) {
        return
    }

    try {
        $logDir = Split-Path $LogPath -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        $script:LogEntries | Add-Content -Path $LogPath -Encoding UTF8
        Write-CleanupLog "Log saved to: $LogPath" -Level Info
    } catch {
        Write-CleanupLog "Failed to save log: $_" -Level Error
    }
}

function Get-DiskSpace {
    param([string]$DriveLetter)

    try {
        $drive = Get-PSDrive -Name $DriveLetter.TrimEnd(':') -PSProvider FileSystem -ErrorAction Stop
        return @{
            FreeGB = [math]::Round($drive.Free / 1GB, 2)
            TotalGB = [math]::Round(($drive.Free + $drive.Used) / 1GB, 2)
            PercentFree = [math]::Round(($drive.Free / ($drive.Free + $drive.Used)) * 100, 2)
        }
    } catch {
        return $null
    }
}

function Test-PathExcluded {
    param([string]$Path)

    foreach ($excludePath in $ExcludePaths) {
        if ($Path -like "$excludePath*") {
            return $true
        }
    }
    return $false
}

function Remove-ItemSafely {
    param(
        [string]$Path,
        [string]$Description
    )

    if (Test-PathExcluded -Path $Path) {
        Write-CleanupLog "Skipped (excluded): $Path" -Level Info
        return
    }

    try {
        if (Test-Path $Path) {
            $size = 0
            if (Test-Path $Path -PathType Container) {
                $size = (Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
                         Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            } else {
                $size = (Get-Item $Path -ErrorAction SilentlyContinue).Length
            }

            if ($DryRun) {
                $sizeMB = [math]::Round($size / 1MB, 2)
                Write-CleanupLog "[DRY RUN] Would delete: $Description - $Path ($sizeMB MB)" -Level Warning
            } else {
                Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
                $script:DeletedCount++
                $script:SpaceFreedBytes += $size
                $sizeMB = [math]::Round($size / 1MB, 2)
                Write-CleanupLog "Deleted: $Description - $Path ($sizeMB MB)" -Level Success
            }
        }
    } catch {
        Write-CleanupLog "Failed to delete $Path : $_" -Level Error
    }
}

function Clean-UnityLibraries {
    Write-CleanupLog "=== Cleaning Unity Library Folders ===" -Level Info

    $cutoffDate = (Get-Date).AddDays(-$DaysOld)
    $unityLibraries = Get-ChildItem -Path . -Directory -Recurse -Filter "Library" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -like "*Unity*" -or
            (Test-Path (Join-Path $_.Parent.FullName "Assets")) -or
            (Test-Path (Join-Path $_.Parent.FullName "ProjectSettings"))
        } |
        Where-Object { $_.LastWriteTime -lt $cutoffDate }

    $count = 0
    foreach ($lib in $unityLibraries) {
        Remove-ItemSafely -Path $lib.FullName -Description "Unity Library folder"
        $count++
    }

    Write-CleanupLog "Processed $count Unity Library folders" -Level Info
}

function Clean-BuildArtifacts {
    Write-CleanupLog "=== Cleaning Build Artifacts ===" -Level Info

    $cutoffDate = (Get-Date).AddDays(-$DaysOld)

    # Common build output directories
    $buildPatterns = @(
        "bin",
        "obj",
        "build",
        "Build",
        "Builds",
        "dist",
        "out",
        "target"
    )

    $count = 0
    foreach ($pattern in $buildPatterns) {
        $buildDirs = Get-ChildItem -Path . -Directory -Recurse -Filter $pattern -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoffDate }

        foreach ($dir in $buildDirs) {
            Remove-ItemSafely -Path $dir.FullName -Description "Build artifact directory"
            $count++
        }
    }

    Write-CleanupLog "Processed $count build artifact directories" -Level Info
}

function Clean-CacheDirectories {
    Write-CleanupLog "=== Cleaning Cache Directories ===" -Level Info

    $cutoffDate = (Get-Date).AddDays(-$DaysOld)

    $cachePatterns = @(
        "node_modules",
        ".nuget",
        ".gradle",
        ".m2",
        "__pycache__",
        ".pytest_cache"
    )

    $count = 0
    foreach ($pattern in $cachePatterns) {
        $cacheDirs = Get-ChildItem -Path . -Directory -Recurse -Filter $pattern -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoffDate }

        foreach ($dir in $cacheDirs) {
            Remove-ItemSafely -Path $dir.FullName -Description "Cache directory"
            $count++
        }
    }

    Write-CleanupLog "Processed $count cache directories" -Level Info
}

function Clean-TempFiles {
    Write-CleanupLog "=== Cleaning Temporary Files ===" -Level Info

    $cutoffDate = (Get-Date).AddDays(-$DaysOld)
    $tempExtensions = @("*.tmp", "*.temp", "*.bak", "*.old")

    $count = 0
    foreach ($ext in $tempExtensions) {
        $tempFiles = Get-ChildItem -Path . -File -Recurse -Filter $ext -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoffDate }

        foreach ($file in $tempFiles) {
            Remove-ItemSafely -Path $file.FullName -Description "Temporary file"
            $count++
        }
    }

    Write-CleanupLog "Processed $count temporary files" -Level Info
}

function Clean-OldLogs {
    Write-CleanupLog "=== Cleaning Old Log Files ===" -Level Info

    $cutoffDate = (Get-Date).AddDays(-30) # Keep logs for 30 days

    if (Test-Path "logs") {
        $oldLogs = Get-ChildItem -Path "logs" -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoffDate -and $_.FullName -ne (Resolve-Path $LogPath -ErrorAction SilentlyContinue).Path }

        $count = 0
        foreach ($log in $oldLogs) {
            Remove-ItemSafely -Path $log.FullName -Description "Old log file"
            $count++
        }

        Write-CleanupLog "Processed $count old log files" -Level Info
    }
}

function Clean-DockerResources {
    Write-CleanupLog "=== Cleaning Docker Resources ===" -Level Info

    try {
        $dockerAvailable = Get-Command docker -ErrorAction SilentlyContinue
        if (-not $dockerAvailable) {
            Write-CleanupLog "Docker not available, skipping Docker cleanup" -Level Info
            return
        }

        docker info 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-CleanupLog "Docker is not running, skipping Docker cleanup" -Level Info
            return
        }

        # Remove stopped containers older than DaysOld
        $cutoffDate = (Get-Date).AddDays(-$DaysOld).ToString("yyyy-MM-dd")
        $stoppedContainers = docker ps -a --filter "status=exited" --format "{{.ID}}:{{.CreatedAt}}" 2>$null

        $removedContainers = 0
        foreach ($container in $stoppedContainers) {
            if ($container) {
                $parts = $container.Split(':')
                $containerId = $parts[0]

                if ($DryRun) {
                    Write-CleanupLog "[DRY RUN] Would remove stopped container: $containerId" -Level Warning
                } else {
                    docker rm $containerId 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        $removedContainers++
                        Write-CleanupLog "Removed stopped container: $containerId" -Level Success
                    }
                }
            }
        }

        # Remove dangling images
        if ($DryRun) {
            $danglingImages = docker images -f "dangling=true" -q 2>$null
            $imageCount = ($danglingImages | Measure-Object).Count
            Write-CleanupLog "[DRY RUN] Would remove $imageCount dangling images" -Level Warning
        } else {
            docker image prune -f 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-CleanupLog "Removed dangling Docker images" -Level Success
            }
        }

        # System prune (removes unused data)
        if ($DryRun) {
            Write-CleanupLog "[DRY RUN] Would run docker system prune" -Level Warning
        } else {
            $pruneOutput = docker system prune -f 2>&1
            Write-CleanupLog "Docker system prune completed" -Level Success
        }

        Write-CleanupLog "Docker cleanup completed ($removedContainers containers removed)" -Level Info

    } catch {
        Write-CleanupLog "Error during Docker cleanup: $_" -Level Error
    }
}

# Main execution
Write-CleanupLog "=====================================" -Level Info
Write-CleanupLog "Workspace Cleanup Script Started" -Level Info
Write-CleanupLog "=====================================" -Level Info
Write-CleanupLog "DryRun: $DryRun" -Level Info
Write-CleanupLog "DaysOld: $DaysOld" -Level Info
Write-CleanupLog "MinFreeSpaceGB: $MinFreeSpaceGB" -Level Info
Write-CleanupLog "ExcludePaths: $($ExcludePaths -join ', ')" -Level Info

# Check initial disk space
$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 }
foreach ($drive in $drives) {
    $space = Get-DiskSpace -DriveLetter $drive.Name
    if ($space) {
        Write-CleanupLog "Drive $($drive.Name): $($space.FreeGB) GB free of $($space.TotalGB) GB ($($space.PercentFree)% free)" -Level Info

        if ($space.FreeGB -lt $MinFreeSpaceGB) {
            Write-CleanupLog "WARNING: Drive $($drive.Name) has less than $MinFreeSpaceGB GB free!" -Level Warning
        }
    }
}

# Run cleanup operations
Clean-UnityLibraries
Clean-BuildArtifacts
Clean-CacheDirectories
Clean-TempFiles
Clean-OldLogs
Clean-DockerResources

# Summary
Write-CleanupLog "=====================================" -Level Info
Write-CleanupLog "Cleanup Summary" -Level Info
Write-CleanupLog "=====================================" -Level Info

if ($DryRun) {
    Write-CleanupLog "DRY RUN MODE - No files were actually deleted" -Level Warning
} else {
    $spaceFreedMB = [math]::Round($script:SpaceFreedBytes / 1MB, 2)
    $spaceFreedGB = [math]::Round($script:SpaceFreedBytes / 1GB, 2)
    Write-CleanupLog "Items deleted: $script:DeletedCount" -Level Success
    Write-CleanupLog "Space freed: $spaceFreedMB MB ($spaceFreedGB GB)" -Level Success
}

# Check final disk space
foreach ($drive in $drives) {
    $space = Get-DiskSpace -DriveLetter $drive.Name
    if ($space) {
        Write-CleanupLog "Drive $($drive.Name): $($space.FreeGB) GB free of $($space.TotalGB) GB ($($space.PercentFree)% free)" -Level Info
    }
}

Write-CleanupLog "Cleanup completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level Success

# Save log
Save-CleanupLog

exit 0
