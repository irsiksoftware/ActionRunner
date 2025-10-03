#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies the Jesus project development environment is properly configured.

.DESCRIPTION
    This script checks that all required dependencies for the Jesus MCP Agentic AI Platform
    are installed and properly configured on the self-hosted runner.

    Checks include:
    - Node.js 20.x
    - pnpm 9.x
    - Python 3.11
    - Docker with BuildKit
    - Security tools (pip-audit, detect-secrets, OSV Scanner)

.PARAMETER ExitOnFailure
    Exit with code 1 if any checks fail (useful for CI/CD)

.PARAMETER JsonOutput
    Output results in JSON format

.EXAMPLE
    .\verify-jesus-environment.ps1

.EXAMPLE
    .\verify-jesus-environment.ps1 -ExitOnFailure

.EXAMPLE
    .\verify-jesus-environment.ps1 -JsonOutput

.NOTES
    Author: ActionRunner Team
    Version: 1.0.0
    Created for Issue #30: Jesus project runner verification
#>

[CmdletBinding()]
param(
    [switch]$ExitOnFailure,
    [switch]$JsonOutput
)

$ErrorActionPreference = 'Continue'

# Results collection
$results = @{
    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
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
        [string]$Severity = 'Error'  # Error or Warning
    )

    try {
        $result = & $Check

        $checkResult = @{
            name = $Name
            expected = $Expected
            actual = $result.Value
            passed = $result.Passed
            message = if ($result.Passed) { "OK" } else { $FailureMessage }
            severity = if ($result.Passed) { "Pass" } else { $Severity }
        }

        if ($result.Passed) {
            $script:results.passed++
            if (-not $JsonOutput) {
                Write-Host "✅ $Name : $($result.Value)" -ForegroundColor Green
            }
        }
        else {
            if ($Severity -eq 'Error') {
                $script:results.failed++
                if (-not $JsonOutput) {
                    Write-Host "❌ $Name : $FailureMessage" -ForegroundColor Red
                }
            }
            else {
                $script:results.warnings++
                if (-not $JsonOutput) {
                    Write-Host "⚠️  $Name : $FailureMessage" -ForegroundColor Yellow
                }
            }
        }

        $script:results.checks += $checkResult
    }
    catch {
        $checkResult = @{
            name = $Name
            expected = $Expected
            actual = "Error: $_"
            passed = $false
            message = $FailureMessage
            severity = $Severity
        }

        if ($Severity -eq 'Error') {
            $script:results.failed++
            if (-not $JsonOutput) {
                Write-Host "❌ $Name : Error - $_" -ForegroundColor Red
            }
        }
        else {
            $script:results.warnings++
            if (-not $JsonOutput) {
                Write-Host "⚠️  $Name : Error - $_" -ForegroundColor Yellow
            }
        }

        $script:results.checks += $checkResult
    }
}

# Display header
if (-not $JsonOutput) {
    Write-Host "`n=== Jesus Project Environment Verification ===" -ForegroundColor Cyan
    Write-Host "Checking development environment dependencies...`n" -ForegroundColor Gray
}

# Check Node.js 20.x
Test-Requirement -Name "Node.js 20.x" -Expected "v20.x" -Check {
    if (Get-Command node -ErrorAction SilentlyContinue) {
        $version = node --version
        $passed = $version -match '^v20\.'
        return @{ Passed = $passed; Value = $version }
    }
    return @{ Passed = $false; Value = "Not installed" }
} -FailureMessage "Node.js 20.x not found. Install from: https://nodejs.org/"

# Check pnpm 9.x
Test-Requirement -Name "pnpm 9.x" -Expected "9.x" -Check {
    if (Get-Command pnpm -ErrorAction SilentlyContinue) {
        $version = pnpm --version
        $passed = $version -match '^9\.'
        return @{ Passed = $passed; Value = "v$version" }
    }
    return @{ Passed = $false; Value = "Not installed" }
} -FailureMessage "pnpm 9.x not found. Install with: npm install -g pnpm@9"

# Check Python 3.11
Test-Requirement -Name "Python 3.11" -Expected "3.11.x" -Check {
    $pythonCmds = @('python', 'python3', 'python3.11')
    foreach ($cmd in $pythonCmds) {
        if (Get-Command $cmd -ErrorAction SilentlyContinue) {
            $version = & $cmd --version 2>&1
            if ($version -match '3\.11\.') {
                return @{ Passed = $true; Value = $version }
            }
        }
    }
    return @{ Passed = $false; Value = "Not installed" }
} -FailureMessage "Python 3.11 not found. Install from: https://www.python.org/"

# Check pip
Test-Requirement -Name "pip" -Expected "Available" -Check {
    if (Get-Command pip -ErrorAction SilentlyContinue) {
        $version = pip --version 2>&1
        return @{ Passed = $true; Value = $version.Split()[1] }
    }
    return @{ Passed = $false; Value = "Not installed" }
} -FailureMessage "pip not found. Install with: python -m ensurepip"

# Check Docker
Test-Requirement -Name "Docker" -Expected "Running" -Check {
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        $version = docker --version
        # Test if Docker daemon is running
        $null = docker ps 2>&1
        if ($LASTEXITCODE -eq 0) {
            return @{ Passed = $true; Value = $version }
        }
        return @{ Passed = $false; Value = "Installed but not running" }
    }
    return @{ Passed = $false; Value = "Not installed" }
} -FailureMessage "Docker not running. Start Docker Desktop or install from: https://docker.com/"

# Check Docker Buildx
Test-Requirement -Name "Docker Buildx" -Expected "Available" -Check {
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        $version = docker buildx version 2>&1
        if ($LASTEXITCODE -eq 0) {
            return @{ Passed = $true; Value = $version }
        }
    }
    return @{ Passed = $false; Value = "Not available" }
} -FailureMessage "Docker Buildx not available. Update Docker Desktop." -Severity Warning

# Check pip-audit
Test-Requirement -Name "pip-audit" -Expected "Installed" -Check {
    $result = pip-audit --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        return @{ Passed = $true; Value = $result }
    }
    return @{ Passed = $false; Value = "Not installed" }
} -FailureMessage "pip-audit not installed. Install with: pip install pip-audit"

# Check detect-secrets
Test-Requirement -Name "detect-secrets" -Expected "Installed" -Check {
    $result = detect-secrets --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        return @{ Passed = $true; Value = $result }
    }
    return @{ Passed = $false; Value = "Not installed" }
} -FailureMessage "detect-secrets not installed. Install with: pip install detect-secrets"

# Check OSV Scanner (optional - warning only)
Test-Requirement -Name "OSV Scanner" -Expected "Installed" -Check {
    if (Get-Command osv-scanner -ErrorAction SilentlyContinue) {
        $version = osv-scanner --version 2>&1
        return @{ Passed = $true; Value = $version }
    }
    return @{ Passed = $false; Value = "Not installed" }
} -FailureMessage "OSV Scanner not installed (optional). Workflows will install if needed." -Severity Warning

# Check curl
Test-Requirement -Name "curl" -Expected "Available" -Check {
    if (Get-Command curl -ErrorAction SilentlyContinue) {
        $version = curl --version 2>&1 | Select-Object -First 1
        return @{ Passed = $true; Value = $version.Split()[1] }
    }
    return @{ Passed = $false; Value = "Not available" }
} -FailureMessage "curl not available (required for OSV Scanner installation)"

# Check disk space
Test-Requirement -Name "Disk Space" -Expected ">= 100GB free" -Check {
    $drive = (Get-Location).Drive
    $freeGB = [math]::Round($drive.Free / 1GB, 2)
    $passed = $freeGB -ge 100
    return @{ Passed = $passed; Value = "${freeGB}GB free" }
} -FailureMessage "Less than 100GB free disk space (minimum requirement)" -Severity Warning

# Output results
if ($JsonOutput) {
    $results | ConvertTo-Json -Depth 10 | Write-Output
}
else {
    # Summary
    Write-Host "`n=== Verification Summary ===" -ForegroundColor Cyan
    Write-Host "✅ Passed: $($results.passed)" -ForegroundColor Green

    if ($results.warnings -gt 0) {
        Write-Host "⚠️  Warnings: $($results.warnings)" -ForegroundColor Yellow
    }

    if ($results.failed -gt 0) {
        Write-Host "❌ Failed: $($results.failed)" -ForegroundColor Red
    }

    # Overall status
    Write-Host ""
    if ($results.failed -eq 0) {
        Write-Host "✅ Environment is ready for Jesus project development!" -ForegroundColor Green
        if ($results.warnings -gt 0) {
            Write-Host "⚠️  Note: Some optional components are missing but not critical." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "❌ Environment verification failed. Please install missing dependencies." -ForegroundColor Red
        Write-Host "   Run scripts/setup-jesus-runner.ps1 to install required components." -ForegroundColor Yellow
    }
    Write-Host ""
}

# Exit with appropriate code
if ($ExitOnFailure -and $results.failed -gt 0) {
    exit 1
}

exit 0
