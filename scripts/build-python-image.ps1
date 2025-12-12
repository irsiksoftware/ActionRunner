<#
.SYNOPSIS
    Builds the multi-Python Docker image for containerized GitHub Actions workflows.

.DESCRIPTION
    Builds a Windows container with Python 3.9, 3.10, 3.11, and 3.12 pre-installed.
    This image is reusable across all workflows - build once, use everywhere.

.PARAMETER Registry
    Optional: Push to registry (e.g., "ghcr.io/dakotairsik", "dockerhub-username")

.PARAMETER Tag
    Image tag (default: "latest")

.PARAMETER NoBuild
    Skip build, only push existing image

.EXAMPLE
    .\build-python-image.ps1
    # Builds locally as runner-python-multi:latest

.EXAMPLE
    .\build-python-image.ps1 -Registry "ghcr.io/dakotairsik" -Tag "v1.0"
    # Builds and pushes to GitHub Container Registry

.EXAMPLE
    .\build-python-image.ps1 -Registry "dockerhub-user"
    # Builds and pushes to Docker Hub
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Registry = "",

    [Parameter(Mandatory = $false)]
    [string]$Tag = "latest",

    [Parameter(Mandatory = $false)]
    [switch]$NoBuild
)

$ErrorActionPreference = "Stop"

# Configuration
$ImageName = "runner-python-multi"
$DockerfilePath = Join-Path $PSScriptRoot "..\docker\Dockerfile.python-multi"
$BuildContext = Join-Path $PSScriptRoot "..\docker"

# Determine full image name
if ($Registry) {
    $FullImageName = "${Registry}/${ImageName}:${Tag}"
    $LocalImageName = "${ImageName}:${Tag}"
} else {
    $FullImageName = "${ImageName}:${Tag}"
    $LocalImageName = $FullImageName
}

Write-Host "=== Python Multi-Version Docker Image Builder ===" -ForegroundColor Cyan
Write-Host ""

# Verify Docker is running
Write-Host "Checking Docker..." -ForegroundColor Yellow
try {
    docker version | Out-Null
    Write-Host "[OK] Docker is running" -ForegroundColor Green
} catch {
    Write-Error "Docker is not running. Please start Docker Desktop and try again."
    exit 1
}

# Build image
if (-not $NoBuild) {
    Write-Host ""
    Write-Host "Building image: $LocalImageName" -ForegroundColor Yellow
    Write-Host "Dockerfile: $DockerfilePath" -ForegroundColor Gray
    Write-Host "This will take 10-15 minutes (downloading base image + installing Python versions)..." -ForegroundColor Gray
    Write-Host ""

    $buildArgs = @(
        "build",
        "-t", $LocalImageName,
        "-f", $DockerfilePath,
        $BuildContext
    )

    try {
        & docker $buildArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Docker build failed with exit code $LASTEXITCODE"
        }
        Write-Host ""
        Write-Host "[OK] Image built successfully: $LocalImageName" -ForegroundColor Green
    } catch {
        Write-Error "Failed to build Docker image: $_"
        exit 1
    }
}

# Tag for registry if needed
if ($Registry -and ($LocalImageName -ne $FullImageName)) {
    Write-Host ""
    Write-Host "Tagging image for registry..." -ForegroundColor Yellow
    docker tag $LocalImageName $FullImageName
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to tag image"
        exit 1
    }
    Write-Host "[OK] Tagged as: $FullImageName" -ForegroundColor Green
}

# Push to registry
if ($Registry) {
    Write-Host ""
    Write-Host "Pushing to registry: $Registry" -ForegroundColor Yellow
    Write-Host "Image: $FullImageName" -ForegroundColor Gray
    Write-Host ""

    try {
        docker push $FullImageName
        if ($LASTEXITCODE -ne 0) {
            throw "Docker push failed"
        }
        Write-Host ""
        Write-Host "[OK] Image pushed successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Use in workflows with:" -ForegroundColor Cyan
        Write-Host "  container:" -ForegroundColor White
        Write-Host "    image: $FullImageName" -ForegroundColor White
    } catch {
        Write-Error "Failed to push image: $_"
        Write-Host ""
        Write-Host "If you haven't logged in, run:" -ForegroundColor Yellow
        Write-Host "  docker login $Registry" -ForegroundColor White
        exit 1
    }
}

# Show image info
Write-Host ""
Write-Host "=== Image Information ===" -ForegroundColor Cyan
docker images $LocalImageName --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

Write-Host ""
Write-Host "=== Test the Image ===" -ForegroundColor Cyan
Write-Host "Run verification:" -ForegroundColor Yellow
Write-Host "  docker run --rm $LocalImageName" -ForegroundColor White
Write-Host ""
Write-Host "Test Python 3.10:" -ForegroundColor Yellow
Write-Host "  docker run --rm $LocalImageName powershell -c 'C:\Python310\python.exe --version'" -ForegroundColor White
Write-Host ""
Write-Host "Interactive shell:" -ForegroundColor Yellow
Write-Host "  docker run --rm -it $LocalImageName" -ForegroundColor White

Write-Host ""
Write-Host "[OK] Build complete!" -ForegroundColor Green
