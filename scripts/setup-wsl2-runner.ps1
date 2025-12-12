<#
.SYNOPSIS
    Sets up a Linux GitHub Actions runner inside WSL2 Ubuntu.

.DESCRIPTION
    This script installs and configures a GitHub Actions runner INSIDE your WSL2 Ubuntu instance.
    This gives you BOTH Windows and Linux runners on the same machine!

    Architecture after setup:
    - Windows Host → Windows Runner (labels: windows, docker)
    - WSL2 Ubuntu → Linux Runner (labels: linux, docker)

.PARAMETER RepoUrl
    GitHub repository URL (e.g., https://github.com/DakotaIrsik/QiFlow)

.PARAMETER Token
    GitHub runner registration token (get from repo Settings > Actions > Runners)

.PARAMETER RunnerName
    Name for the Linux runner (default: "linux-runner")

.PARAMETER DistroName
    WSL2 distro name (default: "Ubuntu")

.EXAMPLE
    .\setup-wsl2-runner.ps1 -RepoUrl "https://github.com/DakotaIrsik/QiFlow" -Token "YOUR_TOKEN"

.EXAMPLE
    .\setup-wsl2-runner.ps1 -RepoUrl "https://github.com/DakotaIrsik/QiFlow" -Token "YOUR_TOKEN" -RunnerName "qiflow-linux-runner"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoUrl,

    [Parameter(Mandatory = $true)]
    [string]$Token,

    [Parameter(Mandatory = $false)]
    [string]$RunnerName = "linux-runner",

    [Parameter(Mandatory = $false)]
    [string]$DistroName = "Ubuntu"
)

$ErrorActionPreference = "Stop"

Write-Host "=== WSL2 Linux Runner Setup ===" -ForegroundColor Cyan
Write-Host ""

# Check if WSL2 is installed
Write-Host "Checking WSL2..." -ForegroundColor Yellow
try {
    $wslList = wsl --list --verbose
    if ($LASTEXITCODE -ne 0) {
        throw "WSL not found"
    }
} catch {
    Write-Host "❌ WSL2 is not installed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Install WSL2 first:" -ForegroundColor Yellow
    Write-Host "  wsl --install" -ForegroundColor White
    Write-Host ""
    Write-Host "Then restart your computer and run this script again."
    exit 1
}

# Check if specified distro exists
if (-not ($wslList -match $DistroName)) {
    Write-Host "❌ WSL2 distro '$DistroName' not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Available distros:" -ForegroundColor Yellow
    wsl --list
    Write-Host ""
    Write-Host "Install Ubuntu from Microsoft Store or specify a different distro with -DistroName"
    exit 1
}

# Check if distro is WSL2 (not WSL1)
$version = ($wslList | Select-String -Pattern "$DistroName\s+\w+\s+(\d+)" | ForEach-Object { $_.Matches.Groups[1].Value })
if ($version -ne "2") {
    Write-Host "⚠ Converting $DistroName to WSL2..." -ForegroundColor Yellow
    wsl --set-version $DistroName 2
    Start-Sleep -Seconds 5
}

Write-Host "✓ WSL2 $DistroName is ready" -ForegroundColor Green
Write-Host ""

# Get the ActionRunner repo path in WSL2 format
$currentPath = Get-Location
$wslPath = wsl -d $DistroName wslpath -a $currentPath.Path
Write-Host "Repository path in WSL2: $wslPath" -ForegroundColor Gray
Write-Host ""

# Create installation script for WSL2
Write-Host "Creating installation script..." -ForegroundColor Yellow

$installScript = @(
    "#!/bin/bash",
    "set -e",
    "",
    "echo '=== Installing Linux Runner in WSL2 ==='",
    "echo ''",
    "",
    "# Update package lists",
    "echo 'Updating packages...'",
    "sudo apt-get update -qq",
    "",
    "# Install dependencies",
    "echo 'Installing dependencies...'",
    "sudo apt-get install -y curl wget git",
    "",
    "# Create runner directory",
    "RUNNER_DIR=`"`$HOME/actions-runner`"",
    "mkdir -p `"`$RUNNER_DIR`"",
    "cd `"`$RUNNER_DIR`"",
    "",
    "# Download runner",
    "RUNNER_VERSION=`"2.311.0`"",
    "if [ ! -f `"config.sh`" ]; then",
    "    echo 'Downloading GitHub Actions runner...'",
    "    curl -o actions-runner-linux-x64-`${RUNNER_VERSION}.tar.gz \",
    "        -L https://github.com/actions/runner/releases/download/v`${RUNNER_VERSION}/actions-runner-linux-x64-`${RUNNER_VERSION}.tar.gz",
    "",
    "    tar xzf actions-runner-linux-x64-`${RUNNER_VERSION}.tar.gz",
    "    rm actions-runner-linux-x64-`${RUNNER_VERSION}.tar.gz",
    "    echo '✓ Runner downloaded'",
    "else",
    "    echo '✓ Runner already downloaded'",
    "fi",
    "",
    "# Configure runner",
    "echo ''",
    "echo 'Configuring runner...'",
    "./config.sh \",
    "    --url '$RepoUrl' \",
    "    --token '$Token' \",
    "    --name '$RunnerName' \",
    "    --labels 'self-hosted,linux,docker,wsl2' \",
    "    --work '_work' \",
    "    --unattended \",
    "    --replace",
    "",
    "echo '✓ Runner configured'",
    "",
    "# Install as systemd service",
    "echo ''",
    "echo 'Installing as systemd service...'",
    "sudo ./svc.sh install",
    "sudo ./svc.sh start",
    "",
    "echo '✓ Service installed and started'",
    "",
    "# Build Linux Docker image",
    "echo ''",
    "echo 'Building Python Docker image...'",
    "REPO_PATH='$wslPath'",
    "if [ -d `"`$REPO_PATH/docker`" ]; then",
    "    cd `"`$REPO_PATH`"",
    "",
    "    if [ -f `"scripts/build-python-image-linux.sh`" ]; then",
    "        chmod +x scripts/build-python-image-linux.sh",
    "        ./scripts/build-python-image-linux.sh",
    "    else",
    "        echo 'Building manually...'",
    "        docker build -t runner-python-multi:latest -f docker/Dockerfile.python-multi-linux docker/",
    "    fi",
    "",
    "    echo '✓ Docker image built'",
    "else",
    "    echo '⚠ Could not find repository at `$REPO_PATH'",
    "    echo '  You can build the Docker image manually later'",
    "fi",
    "",
    "# Check service status",
    "echo ''",
    "echo '=== Runner Status ==='",
    "sudo systemctl status actions.runner.* --no-pager || true",
    "",
    "echo ''",
    "echo '✓ Setup complete!'",
    "echo ''",
    "echo 'Your Linux runner is now active with labels:'",
    "echo '  - self-hosted'",
    "echo '  - linux'",
    "echo '  - docker'",
    "echo '  - wsl2'"
) -join "`n"

# Save script to temp file
$tempScript = [System.IO.Path]::GetTempFileName()
$tempScriptLinux = $tempScript -replace '\\', '/' -replace 'C:', '/mnt/c'
Set-Content -Path $tempScript -Value $installScript -NoNewline

Write-Host "✓ Installation script created" -ForegroundColor Green
Write-Host ""

# Run the installation script in WSL2
Write-Host "Running installation in WSL2..." -ForegroundColor Yellow
Write-Host "This may take 5-10 minutes..." -ForegroundColor Gray
Write-Host ""

try {
    # Copy script to WSL2 and execute
    $bashCommand = "cat > /tmp/setup-runner.sh << 'EOFMARKER'`n$installScript`nEOFMARKER`nchmod +x /tmp/setup-runner.sh`n/tmp/setup-runner.sh"
    wsl -d $DistroName bash -c $bashCommand

    if ($LASTEXITCODE -ne 0) {
        throw "Installation failed with exit code $LASTEXITCODE"
    }

    Write-Host ""
    Write-Host "=== Setup Complete! ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "You now have TWO runners on this machine:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Windows Runner (Windows host)" -ForegroundColor Yellow
    Write-Host "   Labels: self-hosted, windows, docker"
    Write-Host "   For: Windows builds, .NET Framework, Unity"
    Write-Host ""
    Write-Host "2. Linux Runner (WSL2 Ubuntu) ← NEW!" -ForegroundColor Yellow
    Write-Host "   Labels: self-hosted, linux, docker, wsl2"
    Write-Host "   For: Python, Node, cross-platform testing"
    Write-Host ""
    Write-Host "Verify both runners at:" -ForegroundColor Cyan
    Write-Host "  $RepoUrl/settings/actions/runners" -ForegroundColor White
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. Copy unified workflow template to your repo" -ForegroundColor White
    Write-Host "2. Push and watch both runners work together!" -ForegroundColor White
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "❌ Setup failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Check WSL2 is running: wsl -d $DistroName" -ForegroundColor White
    Write-Host "2. View WSL2 logs: wsl -d $DistroName journalctl -xe" -ForegroundColor White
    Write-Host "3. Try running manually inside WSL2" -ForegroundColor White
    exit 1
} finally {
    # Cleanup temp file
    if (Test-Path $tempScript) {
        Remove-Item $tempScript -Force
    }
}

# Show how to manage the runners
Write-Host "=== Managing Your Runners ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Windows Runner:" -ForegroundColor Yellow
Write-Host "  Status:  Get-Service actions.runner.*" -ForegroundColor White
Write-Host "  Stop:    Stop-Service actions.runner.*" -ForegroundColor White
Write-Host "  Start:   Start-Service actions.runner.*" -ForegroundColor White
Write-Host ""
Write-Host "Linux Runner (in WSL2):" -ForegroundColor Yellow
Write-Host "  Status:  wsl -d $DistroName sudo systemctl status actions.runner.*" -ForegroundColor White
Write-Host "  Stop:    wsl -d $DistroName sudo systemctl stop actions.runner.*" -ForegroundColor White
Write-Host "  Start:   wsl -d $DistroName sudo systemctl start actions.runner.*" -ForegroundColor White
Write-Host "  Logs:    wsl -d $DistroName sudo journalctl -u actions.runner.* -f" -ForegroundColor White
Write-Host ""
