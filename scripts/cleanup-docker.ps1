#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Cleans up Docker containers, images, and volumes after job completion
.DESCRIPTION
    Removes stopped containers, dangling images, and unused volumes to free up disk space.
    Can be run after each job or on a schedule to maintain system health.
.EXAMPLE
    .\cleanup-docker.ps1
.EXAMPLE
    .\cleanup-docker.ps1 -Force -RemoveAllContainers
#>

param(
    [switch]$Force,
    [switch]$RemoveAllContainers,
    [switch]$RemoveAllImages,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host "=== Docker Cleanup for Self-Hosted Runner ===" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is running
function Test-DockerRunning {
    try {
        docker info | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

if (-not (Test-DockerRunning)) {
    Write-Error "Docker is not running. Please start Docker Desktop and try again."
    exit 1
}

# Function to remove stopped containers
function Remove-StoppedContainers {
    Write-Host "[1/5] Removing stopped containers..." -ForegroundColor Yellow

    $stoppedContainers = docker ps -a --filter "status=exited" --filter "status=dead" -q

    if ($stoppedContainers) {
        $containerCount = ($stoppedContainers | Measure-Object).Count
        Write-Host "Found $containerCount stopped container(s)" -ForegroundColor Cyan

        if ($DryRun) {
            Write-Host "[DRY RUN] Would remove $containerCount container(s)" -ForegroundColor Yellow
        } else {
            docker rm $stoppedContainers
            Write-Host "[OK] Removed $containerCount stopped container(s)" -ForegroundColor Green
        }
    } else {
        Write-Host "[OK] No stopped containers to remove" -ForegroundColor Green
    }
}

# Function to remove all containers (if forced)
function Remove-AllContainers {
    Write-Host "[1/5] Removing all containers..." -ForegroundColor Yellow

    if (-not $RemoveAllContainers) {
        Remove-StoppedContainers
        return
    }

    $allContainers = docker ps -a -q

    if ($allContainers) {
        $containerCount = ($allContainers | Measure-Object).Count
        Write-Host "Found $containerCount container(s)" -ForegroundColor Cyan

        if ($DryRun) {
            Write-Host "[DRY RUN] Would remove $containerCount container(s)" -ForegroundColor Yellow
        } else {
            if ($Force) {
                docker rm -f $allContainers
                Write-Host "[OK] Removed $containerCount container(s)" -ForegroundColor Green
            } else {
                Write-Host "[SKIP] Use -Force with -RemoveAllContainers to remove running containers" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "[OK] No containers to remove" -ForegroundColor Green
    }
}

# Function to remove dangling images
function Remove-DanglingImages {
    Write-Host "[2/5] Removing dangling images..." -ForegroundColor Yellow

    $danglingImages = docker images -f "dangling=true" -q

    if ($danglingImages) {
        $imageCount = ($danglingImages | Measure-Object).Count
        Write-Host "Found $imageCount dangling image(s)" -ForegroundColor Cyan

        if ($DryRun) {
            Write-Host "[DRY RUN] Would remove $imageCount dangling image(s)" -ForegroundColor Yellow
        } else {
            docker rmi $danglingImages
            Write-Host "[OK] Removed $imageCount dangling image(s)" -ForegroundColor Green
        }
    } else {
        Write-Host "[OK] No dangling images to remove" -ForegroundColor Green
    }
}

# Function to remove all non-runner images (if forced)
function Remove-UnusedImages {
    Write-Host "[2/5] Removing unused images..." -ForegroundColor Yellow

    if ($RemoveAllImages) {
        Write-Host "Removing all images except runner-* images..." -ForegroundColor Cyan

        # Get all images that are not runner images
        $allImages = docker images --format "{{.Repository}}:{{.Tag}}" | Where-Object { $_ -notmatch "^runner-" }

        if ($allImages) {
            $imageCount = ($allImages | Measure-Object).Count
            Write-Host "Found $imageCount non-runner image(s)" -ForegroundColor Cyan

            if ($DryRun) {
                Write-Host "[DRY RUN] Would remove $imageCount image(s)" -ForegroundColor Yellow
                $allImages | ForEach-Object { Write-Host "  - $_" -ForegroundColor DarkGray }
            } else {
                if ($Force) {
                    $allImages | ForEach-Object { docker rmi $_ }
                    Write-Host "[OK] Removed $imageCount image(s)" -ForegroundColor Green
                } else {
                    Write-Host "[SKIP] Use -Force with -RemoveAllImages to remove all non-runner images" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "[OK] No non-runner images to remove" -ForegroundColor Green
        }
    } else {
        Remove-DanglingImages
    }
}

# Function to remove unused volumes
function Remove-UnusedVolumes {
    Write-Host "[3/5] Removing unused volumes..." -ForegroundColor Yellow

    $unusedVolumes = docker volume ls -f "dangling=true" -q

    if ($unusedVolumes) {
        $volumeCount = ($unusedVolumes | Measure-Object).Count
        Write-Host "Found $volumeCount unused volume(s)" -ForegroundColor Cyan

        if ($DryRun) {
            Write-Host "[DRY RUN] Would remove $volumeCount volume(s)" -ForegroundColor Yellow
        } else {
            docker volume rm $unusedVolumes
            Write-Host "[OK] Removed $volumeCount volume(s)" -ForegroundColor Green
        }
    } else {
        Write-Host "[OK] No unused volumes to remove" -ForegroundColor Green
    }
}

# Function to remove build cache
function Remove-BuildCache {
    Write-Host "[4/5] Removing build cache..." -ForegroundColor Yellow

    if ($DryRun) {
        $cacheInfo = docker system df -v | Select-String "Build Cache"
        Write-Host "[DRY RUN] Would prune build cache" -ForegroundColor Yellow
        Write-Host $cacheInfo -ForegroundColor DarkGray
    } else {
        docker builder prune -f
        Write-Host "[OK] Build cache pruned" -ForegroundColor Green
    }
}

# Function to display disk usage
function Show-DiskUsage {
    Write-Host "[5/5] Docker disk usage summary..." -ForegroundColor Yellow
    Write-Host ""
    docker system df
    Write-Host ""
}

# Main execution
try {
    Write-Host "Cleanup mode: $(if ($DryRun) { 'DRY RUN' } else { 'ACTIVE' })" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Cyan' })
    Write-Host ""

    Remove-AllContainers
    Remove-UnusedImages
    Remove-UnusedVolumes
    Remove-BuildCache
    Show-DiskUsage

    Write-Host ""
    Write-Host "=== Docker Cleanup Complete ===" -ForegroundColor Green
    Write-Host ""

    if ($DryRun) {
        Write-Host "This was a dry run. Run without -DryRun to perform actual cleanup." -ForegroundColor Yellow
    }

    # Calculate space reclaimed (if not dry run)
    if (-not $DryRun) {
        Write-Host "Space reclaimed. Check 'docker system df' for current usage." -ForegroundColor Cyan
    }
}
catch {
    Write-Host ""
    Write-Host "[ERROR] Cleanup failed: $_" -ForegroundColor Red
    exit 1
}
