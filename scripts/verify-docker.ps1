#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies Docker daemon availability and configuration for GitHub Actions runner

.DESCRIPTION
    Performs comprehensive checks of Docker daemon installation, connectivity,
    and configuration. Validates that Docker is properly configured for use
    with GitHub Actions self-hosted runners.

.PARAMETER ExitOnFailure
    Exit with code 1 if any critical checks fail

.PARAMETER JsonOutput
    Output results in JSON format for programmatic consumption

.PARAMETER SkipDockerBuild
    Skip Docker build test (useful when testing in CI/CD)

.EXAMPLE
    .\verify-docker.ps1
    Runs all Docker verification checks with human-readable output

.EXAMPLE
    .\verify-docker.ps1 -JsonOutput
    Runs verification and outputs results as JSON

.EXAMPLE
    .\verify-docker.ps1 -ExitOnFailure
    Runs verification and exits with code 1 on any failure
#>

[CmdletBinding()]
param(
    [switch]$ExitOnFailure,
    [switch]$JsonOutput,
    [switch]$SkipDockerBuild
)

$ErrorActionPreference = 'Continue'

# Initialize results
$script:Results = @{
    timestamp = (Get-Date).ToString('o')
    checks = @()
    passed = 0
    failed = 0
    warnings = 0
}

function Test-Requirement {
    param(
        [string]$Name,
        [scriptblock]$Check,
        [string]$Expected,
        [string]$FailureMessage,
        [ValidateSet('Critical', 'Warning', 'Info')]
        [string]$Severity = 'Critical'
    )

    try {
        $result = & $Check
        $status = if ($result.Success) { 'PASS' } else { 'FAIL' }

        $checkResult = @{
            name = $Name
            status = $status
            expected = $Expected
            actual = $result.Actual
            message = if ($result.Success) { "✅ $Expected" } else { $FailureMessage }
            severity = $Severity
        }

        $script:Results.checks += $checkResult

        if ($result.Success) {
            $script:Results.passed++
            if (-not $JsonOutput) {
                Write-Host "✅ ${Name}: " -NoNewline -ForegroundColor Green
                Write-Host $Expected -ForegroundColor Gray
            }
        }
        else {
            if ($Severity -eq 'Warning') {
                $script:Results.warnings++
                if (-not $JsonOutput) {
                    Write-Host "⚠️  ${Name}: " -NoNewline -ForegroundColor Yellow
                    Write-Host $FailureMessage -ForegroundColor Gray
                }
            }
            else {
                $script:Results.failed++
                if (-not $JsonOutput) {
                    Write-Host "❌ ${Name}: " -NoNewline -ForegroundColor Red
                    Write-Host $FailureMessage -ForegroundColor Gray
                }
            }
        }
    }
    catch {
        $script:Results.failed++
        $checkResult = @{
            name = $Name
            status = 'ERROR'
            expected = $Expected
            actual = $_.Exception.Message
            message = "Error during check: $($_.Exception.Message)"
            severity = $Severity
        }
        $script:Results.checks += $checkResult

        if (-not $JsonOutput) {
            Write-Host "❌ ${Name}: " -NoNewline -ForegroundColor Red
            Write-Host "Error - $($_.Exception.Message)" -ForegroundColor Gray
        }
    }
}

# Header
if (-not $JsonOutput) {
    Write-Host ""
    Write-Host "=== Docker Environment Verification ===" -ForegroundColor Cyan
    Write-Host ""
}

# Check 1: Docker command availability
Test-Requirement `
    -Name "Docker Command" `
    -Expected "Docker CLI is available in PATH" `
    -FailureMessage "Docker command not found. Install Docker Desktop or Docker Engine." `
    -Severity "Critical" `
    -Check {
        $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
        @{
            Success = $null -ne $dockerCmd
            Actual = if ($dockerCmd) { $dockerCmd.Source } else { "Not found" }
        }
    }

# Check 2: Docker daemon running
Test-Requirement `
    -Name "Docker Daemon" `
    -Expected "Docker daemon is running and accessible" `
    -FailureMessage "Docker daemon is not running. Start Docker Desktop or dockerd service." `
    -Severity "Critical" `
    -Check {
        try {
            $null = docker version 2>&1
            $success = $LASTEXITCODE -eq 0
            @{
                Success = $success
                Actual = if ($success) { "Running" } else { "Not running or not accessible" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
        }
    }

# Check 3: Docker version
Test-Requirement `
    -Name "Docker Version" `
    -Expected "Docker version 20.10.0 or higher" `
    -FailureMessage "Docker version is too old or could not be determined" `
    -Severity "Warning" `
    -Check {
        try {
            $versionOutput = docker version --format '{{.Server.Version}}' 2>&1
            if ($LASTEXITCODE -eq 0 -and $versionOutput) {
                $version = [version]($versionOutput -replace '^(\d+\.\d+\.\d+).*', '$1')
                $minVersion = [version]'20.10.0'
                @{
                    Success = $version -ge $minVersion
                    Actual = "Docker $version"
                }
            }
            else {
                @{ Success = $false; Actual = "Could not determine version" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
        }
    }

# Check 4: Docker info accessible
Test-Requirement `
    -Name "Docker Info" `
    -Expected "Docker daemon info is accessible" `
    -FailureMessage "Cannot retrieve Docker daemon information" `
    -Severity "Critical" `
    -Check {
        try {
            $null = docker info 2>&1
            $success = $LASTEXITCODE -eq 0
            @{
                Success = $success
                Actual = if ($success) { "Accessible" } else { "Not accessible" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
        }
    }

# Check 5: Docker can pull images
Test-Requirement `
    -Name "Image Pull Test" `
    -Expected "Docker can pull images from registry" `
    -FailureMessage "Cannot pull images. Check network and registry access." `
    -Severity "Critical" `
    -Check {
        try {
            # Try to pull a tiny test image
            $null = docker pull hello-world:latest 2>&1
            $success = $LASTEXITCODE -eq 0
            @{
                Success = $success
                Actual = if ($success) { "Can pull images" } else { "Pull failed" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
        }
    }

# Check 6: Docker can run containers
Test-Requirement `
    -Name "Container Run Test" `
    -Expected "Docker can create and run containers" `
    -FailureMessage "Cannot run containers. Check Docker daemon configuration." `
    -Severity "Critical" `
    -Check {
        try {
            $output = docker run --rm hello-world 2>&1
            $success = $LASTEXITCODE -eq 0
            @{
                Success = $success
                Actual = if ($success) { "Containers can run" } else { "Run failed" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
        }
    }

# Check 7: Docker build capability
if (-not $SkipDockerBuild) {
    Test-Requirement `
        -Name "Docker Build Test" `
        -Expected "Docker can build images" `
        -FailureMessage "Cannot build Docker images" `
        -Severity "Warning" `
        -Check {
            try {
                # Create a temporary directory for build context
                $testDir = Join-Path $env:TEMP "docker-verify-$(Get-Random)"
                New-Item -ItemType Directory -Path $testDir -Force | Out-Null

                try {
                    # Create a minimal Dockerfile
                    $dockerfile = @"
FROM alpine:latest
RUN echo "Build test successful"
"@
                    Set-Content -Path (Join-Path $testDir "Dockerfile") -Value $dockerfile

                    # Build the image
                    $null = docker build -t docker-verify-test:latest $testDir 2>&1
                    $buildSuccess = $LASTEXITCODE -eq 0

                    # Clean up test image
                    if ($buildSuccess) {
                        docker rmi docker-verify-test:latest 2>&1 | Out-Null
                    }

                    @{
                        Success = $buildSuccess
                        Actual = if ($buildSuccess) { "Build successful" } else { "Build failed" }
                    }
                }
                finally {
                    Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            catch {
                @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
            }
        }
}

# Check 8: Docker storage driver
Test-Requirement `
    -Name "Storage Driver" `
    -Expected "Docker storage driver is configured" `
    -FailureMessage "Storage driver information not available" `
    -Severity "Info" `
    -Check {
        try {
            $driver = docker info --format '{{.Driver}}' 2>&1
            if ($LASTEXITCODE -eq 0 -and $driver) {
                @{
                    Success = $true
                    Actual = "Using $driver driver"
                }
            }
            else {
                @{ Success = $false; Actual = "Could not determine storage driver" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
        }
    }

# Output results
if (-not $JsonOutput) {
    Write-Host ""
    Write-Host "=== Summary ===" -ForegroundColor Cyan
    Write-Host "Passed:   " -NoNewline
    Write-Host $script:Results.passed -ForegroundColor Green
    Write-Host "Failed:   " -NoNewline
    Write-Host $script:Results.failed -ForegroundColor Red
    Write-Host "Warnings: " -NoNewline
    Write-Host $script:Results.warnings -ForegroundColor Yellow
    Write-Host ""

    if ($script:Results.failed -eq 0) {
        Write-Host "✅ Docker environment is properly configured!" -ForegroundColor Green
    }
    else {
        Write-Host "❌ Docker environment has issues that need attention." -ForegroundColor Red
    }
    Write-Host ""
}
else {
    $script:Results | ConvertTo-Json -Depth 10
}

# Exit with appropriate code
if ($ExitOnFailure -and $script:Results.failed -gt 0) {
    exit 1
}

exit 0
