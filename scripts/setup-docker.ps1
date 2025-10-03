#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sets up Docker Desktop for Windows with WSL2 backend and GPU support
.DESCRIPTION
    Installs Docker Desktop, configures WSL2 backend, sets up GPU passthrough
    for CUDA containers, and configures resource limits for runner isolation
.EXAMPLE
    .\setup-docker.ps1
#>

param(
    [switch]$SkipDockerInstall,
    [switch]$EnableGPU,
    [int]$MaxCPUs = 4,
    [int]$MaxMemoryGB = 8
)

$ErrorActionPreference = "Stop"

Write-Host "=== Docker Setup for Self-Hosted Runner ===" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator"
    exit 1
}

# Function to check WSL2 installation
function Test-WSL2 {
    try {
        $wslVersion = wsl --list --verbose 2>&1
        if ($wslVersion -match "WSL 2") {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

# Function to install WSL2
function Install-WSL2 {
    Write-Host "[1/5] Installing WSL2..." -ForegroundColor Yellow

    if (Test-WSL2) {
        Write-Host "[OK] WSL2 is already installed" -ForegroundColor Green
        return
    }

    # Enable WSL feature
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

    # Enable Virtual Machine Platform
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

    # Set WSL2 as default
    wsl --set-default-version 2

    # Install Ubuntu distribution
    wsl --install -d Ubuntu

    Write-Host "[OK] WSL2 installed successfully" -ForegroundColor Green
    Write-Host "[WARNING] A system restart may be required" -ForegroundColor Yellow
}

# Function to install Docker Desktop
function Install-DockerDesktop {
    Write-Host "[2/5] Installing Docker Desktop..." -ForegroundColor Yellow

    if ($SkipDockerInstall) {
        Write-Host "[SKIP] Docker installation skipped" -ForegroundColor Yellow
        return
    }

    # Check if Docker is already installed
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-Host "[OK] Docker is already installed" -ForegroundColor Green
        return
    }

    # Download Docker Desktop installer
    $dockerUrl = "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe"
    $installerPath = "$env:TEMP\DockerDesktopInstaller.exe"

    Write-Host "Downloading Docker Desktop..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $dockerUrl -OutFile $installerPath -UseBasicParsing

    Write-Host "Installing Docker Desktop..." -ForegroundColor Cyan
    Start-Process -FilePath $installerPath -ArgumentList "install", "--quiet" -Wait

    Remove-Item $installerPath -Force

    Write-Host "[OK] Docker Desktop installed successfully" -ForegroundColor Green
}

# Function to configure Docker settings
function Configure-Docker {
    Write-Host "[3/5] Configuring Docker settings..." -ForegroundColor Yellow

    $dockerConfigPath = "$env:APPDATA\Docker\settings.json"

    # Create Docker config directory if it doesn't exist
    $dockerConfigDir = Split-Path $dockerConfigPath -Parent
    if (-not (Test-Path $dockerConfigDir)) {
        New-Item -ItemType Directory -Path $dockerConfigDir -Force | Out-Null
    }

    # Base configuration
    $config = @{
        "wslEngineEnabled" = $true
        "memoryMiB" = ($MaxMemoryGB * 1024)
        "cpus" = $MaxCPUs
        "swapMiB" = 2048
        "diskSizeMiB" = 102400  # 100GB
        "autoStart" = $true
        "displayedOnboarding" = $true
    }

    # Save configuration
    $config | ConvertTo-Json -Depth 10 | Set-Content -Path $dockerConfigPath

    Write-Host "[OK] Docker configured with $MaxCPUs CPUs and ${MaxMemoryGB}GB RAM" -ForegroundColor Green
}

# Function to setup GPU support
function Setup-GPUSupport {
    Write-Host "[4/5] Setting up GPU support..." -ForegroundColor Yellow

    if (-not $EnableGPU) {
        Write-Host "[SKIP] GPU support not requested" -ForegroundColor Yellow
        return
    }

    # Check for NVIDIA GPU
    $gpuInfo = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -match "NVIDIA" }

    if (-not $gpuInfo) {
        Write-Host "[WARNING] No NVIDIA GPU detected, skipping GPU setup" -ForegroundColor Yellow
        return
    }

    Write-Host "NVIDIA GPU detected: $($gpuInfo.Name)" -ForegroundColor Cyan

    # Install NVIDIA Container Toolkit (requires WSL2)
    Write-Host "Installing NVIDIA Container Toolkit in WSL2..." -ForegroundColor Cyan
    wsl bash -c "curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg"
    wsl bash -c "curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list"
    wsl bash -c "sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit"

    Write-Host "[OK] GPU support configured" -ForegroundColor Green
}

# Function to build Docker images
function Build-DockerImages {
    Write-Host "[5/5] Building Docker images..." -ForegroundColor Yellow

    $dockerPath = "$PSScriptRoot\..\docker"

    if (-not (Test-Path $dockerPath)) {
        Write-Host "[WARNING] Docker directory not found at $dockerPath" -ForegroundColor Yellow
        return
    }

    # Build each image
    $images = @(
        @{Name="unity"; File="Dockerfile.unity"},
        @{Name="python"; File="Dockerfile.python"},
        @{Name="dotnet"; File="Dockerfile.dotnet"},
        @{Name="gpu"; File="Dockerfile.gpu"}
    )

    foreach ($image in $images) {
        $dockerfilePath = Join-Path $dockerPath $image.File

        if (Test-Path $dockerfilePath) {
            Write-Host "Building runner-$($image.Name) image..." -ForegroundColor Cyan
            docker build -t "runner-$($image.Name):latest" -f $dockerfilePath $dockerPath

            if ($LASTEXITCODE -eq 0) {
                Write-Host "[OK] runner-$($image.Name) image built" -ForegroundColor Green
            } else {
                Write-Host "[ERROR] Failed to build runner-$($image.Name)" -ForegroundColor Red
            }
        }
    }
}

# Main execution
try {
    Install-WSL2
    Install-DockerDesktop
    Configure-Docker
    Setup-GPUSupport
    Build-DockerImages

    Write-Host ""
    Write-Host "=== Docker Setup Complete ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Restart your system if WSL2 was just installed" -ForegroundColor White
    Write-Host "2. Start Docker Desktop" -ForegroundColor White
    Write-Host "3. Verify installation with: docker run hello-world" -ForegroundColor White
    Write-Host ""

    # Display built images
    Write-Host "Available runner images:" -ForegroundColor Cyan
    docker images --filter "reference=runner-*"
}
catch {
    Write-Host ""
    Write-Host "[ERROR] Setup failed: $_" -ForegroundColor Red
    exit 1
}
