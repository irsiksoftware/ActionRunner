#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies Python pip package manager installation and functionality.

.DESCRIPTION
    This script verifies that pip is properly installed and functional by checking:
    - pip command availability
    - pip version meets minimum requirements
    - pip configuration
    - pip package installation capability
    - pip package listing
    - pip package upgrade capability
    - requirements.txt installation capability

.PARAMETER MinimumVersion
    Minimum pip version required. Default is "20.0".

.PARAMETER ExitOnFailure
    Exit with code 1 if any check fails. Otherwise continues and reports all results.

.PARAMETER JsonOutput
    Output results in JSON format for integration with monitoring systems.

.EXAMPLE
    .\verify-pip.ps1
    Runs all pip verification checks with default minimum version 20.0

.EXAMPLE
    .\verify-pip.ps1 -MinimumVersion "21.0" -ExitOnFailure
    Runs checks requiring pip 21.0 or higher and exits on first failure

.EXAMPLE
    .\verify-pip.ps1 -JsonOutput
    Outputs results in JSON format
#>

[CmdletBinding()]
param(
    [string]$MinimumVersion = "20.0",
    [switch]$ExitOnFailure,
    [switch]$JsonOutput
)

$ErrorActionPreference = 'Continue'

# Initialize results collection
$checks = @()
$passed = 0
$failed = 0
$warnings = 0

function Test-Requirement {
    param(
        [string]$Name,
        [scriptblock]$Check,
        [string]$Expected,
        [string]$FailureMessage,
        [string]$Severity = "Error"
    )

    try {
        $result = & $Check
        $checkPassed = $result.Success
        $actual = $result.Value

        if ($checkPassed) {
            $script:passed++
            if (-not $JsonOutput) {
                Write-Host "✅ $Name" -ForegroundColor Green
                if ($actual) {
                    Write-Host "   $actual" -ForegroundColor Gray
                }
            }
        } else {
            if ($Severity -eq "Warning") {
                $script:warnings++
                if (-not $JsonOutput) {
                    Write-Host "⚠️  $Name" -ForegroundColor Yellow
                    Write-Host "   $FailureMessage" -ForegroundColor Yellow
                }
            } else {
                $script:failed++
                if (-not $JsonOutput) {
                    Write-Host "❌ $Name" -ForegroundColor Red
                    Write-Host "   $FailureMessage" -ForegroundColor Red
                }
            }
        }

        $script:checks += @{
            name = $Name
            status = if ($checkPassed) { "passed" } elseif ($Severity -eq "Warning") { "warning" } else { "failed" }
            expected = $Expected
            actual = $actual
            message = if ($checkPassed) { "" } else { $FailureMessage }
            severity = $Severity
        }

        if (-not $checkPassed -and $ExitOnFailure -and $Severity -ne "Warning") {
            exit 1
        }
    }
    catch {
        $script:failed++
        if (-not $JsonOutput) {
            Write-Host "❌ $Name" -ForegroundColor Red
            Write-Host "   Error: $_" -ForegroundColor Red
        }

        $script:checks += @{
            name = $Name
            status = "failed"
            expected = $Expected
            actual = "Error: $_"
            message = $FailureMessage
            severity = $Severity
        }

        if ($ExitOnFailure) {
            exit 1
        }
    }
}

if (-not $JsonOutput) {
    Write-Host "`n=== Python pip Verification ===" -ForegroundColor Cyan
    Write-Host "Checking pip installation and functionality...`n" -ForegroundColor Cyan
}

# Check 1: pip command availability
Test-Requirement -Name "pip Command Available" -Expected "pip command found in PATH" -FailureMessage "pip is not installed or not in PATH. Install Python with pip support." -Check {
    $pipCmd = Get-Command pip -ErrorAction SilentlyContinue
    if ($pipCmd) {
        return @{ Success = $true; Value = "Found: $($pipCmd.Source)" }
    }
    return @{ Success = $false; Value = "Not found" }
}

# Check 2: pip version
Test-Requirement -Name "pip Version" -Expected "pip >= $MinimumVersion" -FailureMessage "pip version is below minimum required version $MinimumVersion" -Check {
    $versionOutput = pip --version 2>&1 | Out-String
    if ($versionOutput -match 'pip\s+([\d.]+)') {
        $version = $matches[1]
        $current = [version]($version -replace '^(\d+\.\d+).*', '$1')
        $minimum = [version]$MinimumVersion

        if ($current -ge $minimum) {
            return @{ Success = $true; Value = "pip $version" }
        }
        return @{ Success = $false; Value = "pip $version (minimum: $MinimumVersion)" }
    }
    return @{ Success = $false; Value = "Unable to determine pip version" }
}

# Check 3: pip configuration
Test-Requirement -Name "pip Configuration" -Expected "Valid pip configuration" -FailureMessage "pip configuration may be corrupted" -Check {
    $configOutput = pip config list 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -or $configOutput -match "no config files found") {
        return @{ Success = $true; Value = "Configuration valid" }
    }
    return @{ Success = $false; Value = "Configuration error" }
}

# Check 4: pip list
Test-Requirement -Name "pip List Packages" -Expected "Can list installed packages" -FailureMessage "Cannot list installed packages" -Check {
    $listOutput = pip list --format=json 2>&1
    if ($LASTEXITCODE -eq 0) {
        try {
            $packages = $listOutput | ConvertFrom-Json
            $count = $packages.Count
            return @{ Success = $true; Value = "$count packages installed" }
        }
        catch {
            return @{ Success = $false; Value = "Failed to parse package list" }
        }
    }
    return @{ Success = $false; Value = "pip list command failed" }
}

# Check 5: pip install test (dry run)
Test-Requirement -Name "pip Install Capability" -Expected "Can perform package installation checks" -FailureMessage "Cannot test package installation" -Check {
    # Test with --dry-run to avoid actually installing anything
    $testOutput = pip install --dry-run requests 2>&1 | Out-String
    if ($testOutput -match "Would install" -or $testOutput -match "Requirement already satisfied") {
        return @{ Success = $true; Value = "Installation capability verified" }
    }
    return @{ Success = $false; Value = "Installation test failed" }
}

# Check 6: pip show (test with pip itself)
Test-Requirement -Name "pip Show Package Info" -Expected "Can retrieve package information" -FailureMessage "Cannot retrieve package information" -Check {
    $showOutput = pip show pip 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and $showOutput -match "Name: pip") {
        if ($showOutput -match "Version:\s+([\d.]+)") {
            $version = $matches[1]
            return @{ Success = $true; Value = "pip version $version details retrieved" }
        }
        return @{ Success = $true; Value = "Package info retrieved" }
    }
    return @{ Success = $false; Value = "show command failed" }
}

# Check 7: pip check (verify installed packages have compatible dependencies)
Test-Requirement -Name "pip Check Dependencies" -Expected "No broken dependencies" -FailureMessage "Some packages have incompatible dependencies" -Severity "Warning" -Check {
    $checkOutput = pip check 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and $checkOutput -match "No broken requirements found") {
        return @{ Success = $true; Value = "All dependencies compatible" }
    }
    return @{ Success = $false; Value = "Dependency conflicts detected" }
}

# Check 8: pip freeze (export installed packages)
Test-Requirement -Name "pip Freeze Export" -Expected "Can export package list" -FailureMessage "Cannot export installed packages" -Check {
    $freezeOutput = pip freeze 2>&1
    if ($LASTEXITCODE -eq 0) {
        $packageCount = ($freezeOutput | Measure-Object).Count
        return @{ Success = $true; Value = "$packageCount packages in freeze output" }
    }
    return @{ Success = $false; Value = "freeze command failed" }
}

# Check 9: pip download capability (test without actually downloading)
Test-Requirement -Name "pip Download Capability" -Expected "Can access package index" -FailureMessage "Cannot access PyPI or configured package index" -Check {
    $searchOutput = pip index versions pip 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and $searchOutput -match "Available versions") {
        return @{ Success = $true; Value = "Package index accessible" }
    }
    # Fallback: try pip download with --dry-run (not all pip versions support this)
    $downloadTest = pip download --dry-run --no-deps pip 2>&1 | Out-String
    if ($downloadTest -match "Collecting pip" -or $downloadTest -match "Requirement already satisfied") {
        return @{ Success = $true; Value = "Package index accessible" }
    }
    return @{ Success = $false; Value = "Cannot access package index" }
}

# Check 10: Virtual environment creation capability
Test-Requirement -Name "Virtual Environment Support" -Expected "venv module available" -FailureMessage "Python venv module not available" -Severity "Warning" -Check {
    $venvTest = python -m venv --help 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and $venvTest -match "usage") {
        return @{ Success = $true; Value = "venv module available" }
    }
    return @{ Success = $false; Value = "venv module not found" }
}

# Check 11: requirements.txt installation test
Test-Requirement -Name "Requirements File Support" -Expected "Can process requirements.txt files" -FailureMessage "Cannot process requirements files" -Check {
    # Create temporary requirements file
    $testDir = Join-Path $env:TEMP "pip_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        $reqFile = Join-Path $testDir "requirements.txt"
        "# Test requirements file`nrequests>=2.0" | Out-File -FilePath $reqFile -Encoding utf8

        # Test with --dry-run
        $reqTest = pip install --dry-run -r $reqFile 2>&1 | Out-String
        if ($reqTest -match "Would install" -or $reqTest -match "Requirement already satisfied") {
            return @{ Success = $true; Value = "Requirements file processing works" }
        }
        return @{ Success = $false; Value = "Requirements file test failed" }
    }
    finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 12: pip upgrade capability check
Test-Requirement -Name "pip Self-Upgrade Check" -Expected "Can check for pip updates" -FailureMessage "Cannot check for pip updates" -Severity "Warning" -Check {
    $upgradeCheck = pip install --upgrade --dry-run pip 2>&1 | Out-String
    if ($upgradeCheck -match "Requirement already satisfied" -or $upgradeCheck -match "Would install") {
        return @{ Success = $true; Value = "Upgrade check successful" }
    }
    return @{ Success = $false; Value = "Upgrade check failed" }
}

# Output results
if ($JsonOutput) {
    $output = @{
        timestamp = Get-Date -Format "o"
        tool = "pip"
        minimumVersion = $MinimumVersion
        passed = $passed
        failed = $failed
        warnings = $warnings
        total = $checks.Count
        checks = $checks
    }
    $output | ConvertTo-Json -Depth 10
} else {
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Passed:   $passed" -ForegroundColor Green
    Write-Host "Failed:   $failed" -ForegroundColor Red
    Write-Host "Warnings: $warnings" -ForegroundColor Yellow
    Write-Host "Total:    $($checks.Count)`n" -ForegroundColor Cyan

    if ($failed -eq 0) {
        Write-Host "✅ All critical pip checks passed!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "❌ Some critical checks failed. Please review the issues above." -ForegroundColor Red
        exit 1
    }
}
