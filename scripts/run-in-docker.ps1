# Docker Container Runner Integration
# Executes jobs in isolated Docker containers for security

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dotnet", "python", "unity", "gpu")]
    [string]$Environment,

    [Parameter(Mandatory=$true)]
    [string]$WorkspacePath,

    [Parameter(Mandatory=$true)]
    [string]$Command,

    [int]$TimeoutMinutes = 60,
    [int]$MaxCPUs = 4,
    [int]$MaxMemoryGB = 8,
    [switch]$EnableGPU,
    [switch]$NetworkIsolated
)

$ErrorActionPreference = "Stop"

Write-Host "=== Running job in Docker container ===" -ForegroundColor Cyan
Write-Host "Environment: $Environment" -ForegroundColor Gray
Write-Host "Workspace: $WorkspacePath" -ForegroundColor Gray
Write-Host ""

# Validate workspace path exists
if (-not (Test-Path $WorkspacePath)) {
    Write-Error "Workspace path does not exist: $WorkspacePath"
    exit 1
}

# Generate container name with timestamp
$containerName = "actionrunner-$Environment-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$imageName = "actionrunner-$Environment:latest"

# Check if image exists
$imageExists = docker images -q $imageName
if (-not $imageExists) {
    Write-Error "Docker image not found: $imageName. Run setup-docker.ps1 first."
    exit 1
}

# Build docker run arguments
$dockerArgs = @(
    "run"
    "--rm"
    "--name", $containerName
    "-v", "${WorkspacePath}:/workspace"
    "--cpus", $MaxCPUs
    "--memory", "${MaxMemoryGB}g"
    "--security-opt", "no-new-privileges"
    "--cap-drop", "ALL"
    "--cap-add", "CHOWN"
    "--cap-add", "SETUID"
    "--cap-add", "SETGID"
)

# Network isolation
if ($NetworkIsolated) {
    $dockerArgs += @("--network", "none")
    Write-Host "Network: Isolated (no network access)" -ForegroundColor Yellow
}
else {
    Write-Host "Network: Enabled" -ForegroundColor Gray
}

# GPU support
if ($EnableGPU -and $Environment -eq "gpu") {
    $dockerArgs += @("--gpus", "all")
    Write-Host "GPU: Enabled" -ForegroundColor Green
}

# Add read-only root filesystem for extra security
$dockerArgs += @("--read-only", "--tmpfs", "/tmp:rw,noexec,nosuid,size=1g")

# Set timeout
$timeoutSeconds = $TimeoutMinutes * 60

# Add image and command
$dockerArgs += $imageName
$dockerArgs += "bash", "-c", $Command

Write-Host "Starting container: $containerName" -ForegroundColor Cyan
Write-Host "Timeout: $TimeoutMinutes minutes" -ForegroundColor Gray
Write-Host "Resource limits: $MaxCPUs CPUs, ${MaxMemoryGB}GB RAM" -ForegroundColor Gray
Write-Host ""
Write-Host "--- Container Output ---" -ForegroundColor DarkGray

# Run container with timeout
$job = Start-Job -ScriptBlock {
    param($dockerArgs)
    & docker @dockerArgs
} -ArgumentList (,$dockerArgs)

# Wait for job with timeout
$completed = Wait-Job -Job $job -Timeout $timeoutSeconds

if (-not $completed) {
    Write-Host ""
    Write-Error "Container timed out after $TimeoutMinutes minutes"

    # Kill the container
    Write-Host "Stopping container: $containerName" -ForegroundColor Yellow
    docker stop $containerName -t 10

    Stop-Job -Job $job
    Remove-Job -Job $job
    exit 124  # Timeout exit code
}

# Get results
$output = Receive-Job -Job $job
$exitCode = $job.State -eq "Failed" ? 1 : 0

Remove-Job -Job $job

Write-Host ""
Write-Host "--- End Container Output ---" -ForegroundColor DarkGray
Write-Host ""

# Show container stats
Write-Host "Container execution completed" -ForegroundColor Green
Write-Host "Exit code: $exitCode" -ForegroundColor Gray

# Cleanup (container auto-removed with --rm flag)
Write-Host ""
Write-Host "Container cleaned up successfully" -ForegroundColor Green

exit $exitCode
