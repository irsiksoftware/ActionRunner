# Docker Setup Script for ActionRunner
# This script installs and configures Docker Desktop for Windows with WSL2 backend
# and GPU passthrough for CUDA containers

#Requires -RunAsAdministrator

param(
    [switch]$SkipInstall,
    [switch]$ConfigureGPU,
    [int]$MaxCPUs = 8,
    [int]$MaxMemoryGB = 16
)

$ErrorActionPreference = "Stop"

Write-Host "=== ActionRunner Docker Setup ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

# Function to check if Docker is installed
function Test-DockerInstalled {
    try {
        $docker = Get-Command docker -ErrorAction SilentlyContinue
        return $null -ne $docker
    }
    catch {
        return $false
    }
}

# Function to check if WSL2 is enabled
function Test-WSL2Enabled {
    try {
        $wslVersion = wsl --status 2>&1
        return $wslVersion -match "WSL 2"
    }
    catch {
        return $false
    }
}

# Install Docker Desktop
if (-not $SkipInstall) {
    Write-Host "[1/6] Checking Docker Desktop installation..." -ForegroundColor Yellow

    if (Test-DockerInstalled) {
        Write-Host "  ✓ Docker Desktop is already installed" -ForegroundColor Green
    }
    else {
        Write-Host "  Installing Docker Desktop for Windows..." -ForegroundColor Cyan

        $dockerInstallerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
        $installerPath = "$env:TEMP\DockerDesktopInstaller.exe"

        Write-Host "  Downloading Docker Desktop installer..."
        Invoke-WebRequest -Uri $dockerInstallerUrl -OutFile $installerPath

        Write-Host "  Running installer..."
        Start-Process -FilePath $installerPath -ArgumentList "install", "--quiet" -Wait

        Write-Host "  ✓ Docker Desktop installed" -ForegroundColor Green
        Write-Host "  Note: You may need to restart your computer and log back in" -ForegroundColor Yellow
    }
}
else {
    Write-Host "[1/6] Skipping Docker installation (--SkipInstall flag set)" -ForegroundColor Yellow
}

# Enable WSL2
Write-Host ""
Write-Host "[2/6] Configuring WSL2 backend..." -ForegroundColor Yellow

if (Test-WSL2Enabled) {
    Write-Host "  ✓ WSL2 is enabled" -ForegroundColor Green
}
else {
    Write-Host "  Enabling WSL2..."

    # Enable WSL feature
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

    # Enable Virtual Machine Platform
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

    # Set WSL2 as default
    wsl --set-default-version 2

    Write-Host "  ✓ WSL2 enabled" -ForegroundColor Green
    Write-Host "  Note: A system restart is required" -ForegroundColor Yellow
}

# Configure Docker daemon settings
Write-Host ""
Write-Host "[3/6] Configuring Docker daemon settings..." -ForegroundColor Yellow

$dockerConfigPath = "$env:APPDATA\Docker\settings.json"

if (Test-Path $dockerConfigPath) {
    $dockerConfig = Get-Content $dockerConfigPath -Raw | ConvertFrom-Json
}
else {
    $dockerConfig = @{}
}

# Set resource limits
$dockerConfig | Add-Member -NotePropertyName "cpus" -NotePropertyValue $MaxCPUs -Force
$dockerConfig | Add-Member -NotePropertyName "memoryMiB" -NotePropertyValue ($MaxMemoryGB * 1024) -Force

# Enable WSL2 backend
$dockerConfig | Add-Member -NotePropertyName "wslEngineEnabled" -NotePropertyValue $true -Force

# Security settings
$dockerConfig | Add-Member -NotePropertyName "exposeDockerAPIOnTCP2375" -NotePropertyValue $false -Force

# Save configuration
$dockerConfig | ConvertTo-Json -Depth 10 | Set-Content $dockerConfigPath

Write-Host "  ✓ Docker daemon configured" -ForegroundColor Green
Write-Host "    - Max CPUs: $MaxCPUs" -ForegroundColor Gray
Write-Host "    - Max Memory: ${MaxMemoryGB}GB" -ForegroundColor Gray

# Configure GPU passthrough for CUDA containers
if ($ConfigureGPU) {
    Write-Host ""
    Write-Host "[4/6] Configuring GPU passthrough for CUDA containers..." -ForegroundColor Yellow

    # Check if NVIDIA GPU is available
    try {
        $nvidiaGPU = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -like "*NVIDIA*" }

        if ($nvidiaGPU) {
            Write-Host "  ✓ NVIDIA GPU detected: $($nvidiaGPU.Name)" -ForegroundColor Green

            # Install CUDA on WSL2
            Write-Host "  Installing CUDA on WSL2..."
            wsl bash -c "curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.0-1_all.deb -o /tmp/cuda-keyring.deb && sudo dpkg -i /tmp/cuda-keyring.deb && sudo apt-get update && sudo apt-get install -y cuda-toolkit-12-2"

            Write-Host "  ✓ GPU passthrough configured" -ForegroundColor Green
        }
        else {
            Write-Host "  ! No NVIDIA GPU detected - skipping GPU configuration" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ! Error configuring GPU: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Continuing without GPU support..." -ForegroundColor Yellow
    }
}
else {
    Write-Host ""
    Write-Host "[4/6] Skipping GPU configuration (use --ConfigureGPU to enable)" -ForegroundColor Yellow
}

# Build Docker images
Write-Host ""
Write-Host "[5/6] Building Docker images..." -ForegroundColor Yellow

$dockerPath = Join-Path $PSScriptRoot "..\docker"

if (Test-Path $dockerPath) {
    $dockerfiles = @(
        @{Name="dotnet"; File="Dockerfile.dotnet"}
        @{Name="python"; File="Dockerfile.python"}
        @{Name="unity"; File="Dockerfile.unity"}
        @{Name="gpu"; File="Dockerfile.gpu"}
    )

    foreach ($df in $dockerfiles) {
        $dockerfilePath = Join-Path $dockerPath $df.File
        if (Test-Path $dockerfilePath) {
            Write-Host "  Building $($df.Name) image..."
            docker build -t "actionrunner-$($df.Name):latest" -f $dockerfilePath $dockerPath
            Write-Host "  ✓ Built actionrunner-$($df.Name):latest" -ForegroundColor Green
        }
    }
}
else {
    Write-Host "  ! Docker directory not found at $dockerPath" -ForegroundColor Yellow
}

# Test Docker installation
Write-Host ""
Write-Host "[6/6] Testing Docker installation..." -ForegroundColor Yellow

try {
    docker run --rm hello-world | Out-Null
    Write-Host "  ✓ Docker is working correctly" -ForegroundColor Green
}
catch {
    Write-Host "  ! Docker test failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  You may need to start Docker Desktop manually" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "=== Setup Complete ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Docker Desktop is configured with:" -ForegroundColor White
Write-Host "  - WSL2 backend enabled" -ForegroundColor Gray
Write-Host "  - Resource limits: $MaxCPUs CPUs, ${MaxMemoryGB}GB RAM" -ForegroundColor Gray
if ($ConfigureGPU) {
    Write-Host "  - GPU passthrough configured" -ForegroundColor Gray
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Restart Docker Desktop if needed" -ForegroundColor Gray
Write-Host "  2. Review docker images with: docker images" -ForegroundColor Gray
Write-Host "  3. Test a container with: docker run --rm actionrunner-python:latest python --version" -ForegroundColor Gray
Write-Host ""
