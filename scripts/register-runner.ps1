<#
.SYNOPSIS
    Registers a GitHub Actions self-hosted runner for an organization or repository.

.DESCRIPTION
    This script automates the registration of a self-hosted GitHub Actions runner.
    It downloads the runner software, configures it with the specified labels,
    and optionally installs it as a Windows service.

.PARAMETER OrgOrRepo
    The organization name (e.g., "myorg") or full repository path (e.g., "owner/repo")

.PARAMETER Token
    GitHub Personal Access Token (PAT) with admin:org or repo permissions
    For organization: requires admin:org scope
    For repository: requires repo scope

.PARAMETER RunnerName
    Custom name for the runner (default: hostname)

.PARAMETER Labels
    Comma-separated list of labels for the runner
    Default: "self-hosted,windows,dotnet,python,unity,gpu-cuda,docker"

.PARAMETER WorkFolder
    Working directory for the runner (default: C:\actions-runner)

.PARAMETER IsOrg
    Switch to indicate this is an organization-level runner

.PARAMETER InstallService
    Switch to install the runner as a Windows service

.EXAMPLE
    .\register-runner.ps1 -OrgOrRepo "myorg" -Token "ghp_xxx" -IsOrg -InstallService

.EXAMPLE
    .\register-runner.ps1 -OrgOrRepo "owner/repo" -Token "ghp_xxx" -Labels "self-hosted,windows,dotnet"

.NOTES
    Requires PowerShell 5.1+ and admin privileges for service installation
    GitHub documentation: https://docs.github.com/en/actions/hosting-your-own-runners
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OrgOrRepo,

    [Parameter(Mandatory = $true)]
    [string]$Token,

    [Parameter(Mandatory = $false)]
    [string]$RunnerName = $env:COMPUTERNAME,

    [Parameter(Mandatory = $false)]
    [string]$Labels = "self-hosted,windows,dotnet,python,unity,gpu-cuda,docker",

    [Parameter(Mandatory = $false)]
    [string]$WorkFolder = "C:\actions-runner",

    [Parameter(Mandatory = $false)]
    [switch]$IsOrg,

    [Parameter(Mandatory = $false)]
    [switch]$InstallService
)

$ErrorActionPreference = "Stop"

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

Write-Log "Starting GitHub Actions runner registration" "INFO"

# Validate token format
if ($Token -notmatch '^(ghp_|github_pat_)') {
    Write-Log "Invalid token format. Token should start with 'ghp_' or 'github_pat_'" "ERROR"
    exit 1
}

# Create work folder
if (-not (Test-Path $WorkFolder)) {
    Write-Log "Creating work folder: $WorkFolder"
    New-Item -ItemType Directory -Path $WorkFolder -Force | Out-Null
}

Set-Location $WorkFolder

# Download latest runner
Write-Log "Fetching latest runner version..."
$latestRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/actions/runner/releases/latest" -Headers @{
    "Accept" = "application/vnd.github+json"
}

$version = $latestRelease.tag_name.TrimStart('v')
$asset = $latestRelease.assets | Where-Object { $_.name -like "*win-x64-*.zip" } | Select-Object -First 1

if (-not $asset) {
    Write-Log "Failed to find Windows x64 runner asset" "ERROR"
    exit 1
}

$downloadUrl = $asset.browser_download_url
$zipFile = "actions-runner-win-x64-$version.zip"

Write-Log "Downloading runner version $version from $downloadUrl"
Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile

# Extract runner
Write-Log "Extracting runner..."
if (Test-Path ".\bin") {
    Write-Log "Runner already extracted, skipping extraction" "WARN"
} else {
    Expand-Archive -Path $zipFile -DestinationPath . -Force
}

# Get registration token from GitHub API
Write-Log "Requesting registration token from GitHub..."

if ($IsOrg) {
    $tokenUrl = "https://api.github.com/orgs/$OrgOrRepo/actions/runners/registration-token"
    $runnerUrl = "https://github.com/$OrgOrRepo"
} else {
    $tokenUrl = "https://api.github.com/repos/$OrgOrRepo/actions/runners/registration-token"
    $runnerUrl = "https://github.com/$OrgOrRepo"
}

try {
    $response = Invoke-RestMethod -Uri $tokenUrl -Method Post -Headers @{
        "Accept" = "application/vnd.github+json"
        "Authorization" = "Bearer $Token"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
    $registrationToken = $response.token
    Write-Log "Successfully obtained registration token" "SUCCESS"
} catch {
    Write-Log "Failed to get registration token: $($_.Exception.Message)" "ERROR"
    Write-Log "Make sure your token has the correct permissions (admin:org for orgs, repo for repos)" "ERROR"
    exit 1
}

# Configure runner
Write-Log "Configuring runner with name: $RunnerName"
Write-Log "Labels: $Labels"

$configArgs = @(
    "--url", $runnerUrl,
    "--token", $registrationToken,
    "--name", $RunnerName,
    "--labels", $Labels,
    "--work", "_work",
    "--unattended",
    "--replace"
)

if ($IsOrg) {
    Write-Log "Configuring as organization-level runner" "INFO"
}

& .\config.cmd $configArgs

if ($LASTEXITCODE -ne 0) {
    Write-Log "Runner configuration failed with exit code $LASTEXITCODE" "ERROR"
    exit 1
}

Write-Log "Runner configured successfully" "SUCCESS"

# Install as service
if ($InstallService) {
    Write-Log "Installing runner as Windows service..."

    # Check for admin privileges
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "Service installation requires administrator privileges" "ERROR"
        Write-Log "Please run this script as Administrator or use -InstallService:$false" "ERROR"
        exit 1
    }

    & .\svc.cmd install

    if ($LASTEXITCODE -ne 0) {
        Write-Log "Service installation failed with exit code $LASTEXITCODE" "ERROR"
        exit 1
    }

    Write-Log "Starting runner service..."
    & .\svc.cmd start

    if ($LASTEXITCODE -ne 0) {
        Write-Log "Service start failed with exit code $LASTEXITCODE" "ERROR"
        exit 1
    }

    Write-Log "Runner service installed and started successfully" "SUCCESS"
} else {
    Write-Log "Runner configured but not installed as service" "INFO"
    Write-Log "To run the runner manually, execute: .\run.cmd" "INFO"
    Write-Log "To install as service later, run: .\svc.cmd install" "INFO"
}

# Cleanup
if (Test-Path $zipFile) {
    Remove-Item $zipFile -Force
    Write-Log "Cleaned up installation files"
}

Write-Log "Runner registration complete!" "SUCCESS"
Write-Log "Runner URL: $runnerUrl" "INFO"
Write-Log "Runner Name: $RunnerName" "INFO"
Write-Log "Labels: $Labels" "INFO"
Write-Log "Work Folder: $WorkFolder" "INFO"

# Display next steps
Write-Host "`n=== NEXT STEPS ===" -ForegroundColor Cyan
Write-Host "1. Verify runner is online: https://github.com/$OrgOrRepo/settings/actions/runners" -ForegroundColor White
Write-Host "2. Update your workflows to use: runs-on: [self-hosted, windows, ...]" -ForegroundColor White
Write-Host "3. Monitor runner logs: Get-Content '$WorkFolder\_diag\Runner_*.log' -Tail 50 -Wait" -ForegroundColor White
Write-Host "4. Configure firewall rules: .\scripts\setup-firewall.ps1" -ForegroundColor White
Write-Host "5. Set up workspace cleanup: .\scripts\cleanup-workspace.ps1" -ForegroundColor White
