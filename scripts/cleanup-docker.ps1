# Docker Cleanup Script
# Removes stopped containers, unused images, and frees up disk space

param(
    [switch]$All,
    [switch]$Force,
    [int]$OlderThanDays = 7
)

$ErrorActionPreference = "Stop"

Write-Host "=== Docker Cleanup ===" -ForegroundColor Cyan
Write-Host ""

# Confirm if not using Force
if (-not $Force) {
    Write-Host "This will remove:" -ForegroundColor Yellow
    Write-Host "  - Stopped ActionRunner containers" -ForegroundColor Gray
    if ($All) {
        Write-Host "  - All unused images" -ForegroundColor Gray
        Write-Host "  - All build cache" -ForegroundColor Gray
    }
    else {
        Write-Host "  - Dangling images" -ForegroundColor Gray
    }
    Write-Host ""

    $confirm = Read-Host "Continue? (y/n)"
    if ($confirm -ne "y") {
        Write-Host "Cancelled" -ForegroundColor Yellow
        exit 0
    }
}

# Remove stopped ActionRunner containers
Write-Host "[1/4] Removing stopped ActionRunner containers..." -ForegroundColor Yellow

$stoppedContainers = docker ps -a --filter "name=actionrunner-" --filter "status=exited" -q

if ($stoppedContainers) {
    $count = ($stoppedContainers | Measure-Object).Count
    docker rm $stoppedContainers
    Write-Host "  ✓ Removed $count stopped containers" -ForegroundColor Green
}
else {
    Write-Host "  ✓ No stopped containers to remove" -ForegroundColor Green
}

# Remove old containers (running longer than specified days)
Write-Host ""
Write-Host "[2/4] Checking for old containers..." -ForegroundColor Yellow

$oldContainers = docker ps --filter "name=actionrunner-" --format "{{.ID}} {{.CreatedAt}}" |
    ForEach-Object {
        $parts = $_ -split ' ', 2
        $id = $parts[0]
        $created = [datetime]::Parse($parts[1])
        if ((Get-Date).AddDays(-$OlderThanDays) -gt $created) {
            $id
        }
    }

if ($oldContainers) {
    $count = ($oldContainers | Measure-Object).Count
    Write-Host "  Found $count containers older than $OlderThanDays days" -ForegroundColor Yellow
    docker stop $oldContainers -t 30
    docker rm $oldContainers
    Write-Host "  ✓ Removed old containers" -ForegroundColor Green
}
else {
    Write-Host "  ✓ No old containers found" -ForegroundColor Green
}

# Remove unused images
Write-Host ""
Write-Host "[3/4] Removing unused images..." -ForegroundColor Yellow

if ($All) {
    # Remove all unused images, not just dangling ones
    docker image prune -a -f --filter "until=${OlderThanDays}d"
    Write-Host "  ✓ Removed all unused images" -ForegroundColor Green
}
else {
    # Remove only dangling images
    docker image prune -f
    Write-Host "  ✓ Removed dangling images" -ForegroundColor Green
}

# Clean build cache
Write-Host ""
Write-Host "[4/4] Cleaning build cache..." -ForegroundColor Yellow

if ($All) {
    docker builder prune -a -f
    Write-Host "  ✓ Removed all build cache" -ForegroundColor Green
}
else {
    docker builder prune -f
    Write-Host "  ✓ Removed unused build cache" -ForegroundColor Green
}

# Show disk space saved
Write-Host ""
Write-Host "=== Cleanup Complete ===" -ForegroundColor Cyan
Write-Host ""

# Display current Docker disk usage
Write-Host "Current Docker disk usage:" -ForegroundColor White
docker system df

Write-Host ""
Write-Host "Tip: Use -All flag to remove all unused images and cache" -ForegroundColor Gray
Write-Host "Tip: Use -Force flag to skip confirmation prompt" -ForegroundColor Gray
Write-Host ""
