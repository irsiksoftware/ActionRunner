#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies .NET SDK and CLI dependencies are correctly installed and configured.

.DESCRIPTION
    This script checks that the .NET SDK and CLI tools are properly installed and functional.
    It validates:
    - .NET SDK installation and version
    - .NET runtime availability
    - dotnet CLI functionality
    - Project creation and build capabilities
    - NuGet restore functionality

.PARAMETER MinimumVersion
    The minimum required .NET version (default: 6.0)

.PARAMETER ExitOnFailure
    Exit with code 1 if any checks fail

.PARAMETER JsonOutput
    Output results in JSON format

.EXAMPLE
    .\verify-dotnet.ps1
    Runs all .NET dependency checks with default settings

.EXAMPLE
    .\verify-dotnet.ps1 -MinimumVersion "8.0"
    Checks for .NET SDK version 8.0 or higher

.EXAMPLE
    .\verify-dotnet.ps1 -JsonOutput
    Outputs results in JSON format

.EXAMPLE
    .\verify-dotnet.ps1 -ExitOnFailure
    Exits with error code if any checks fail

.NOTES
    File Name      : verify-dotnet.ps1
    Author         : ActionRunner Team
    Prerequisite   : PowerShell 5.1 or higher
    Copyright 2025 - ActionRunner
#>

[CmdletBinding()]
param(
    [string]$MinimumVersion = "6.0",
    [switch]$ExitOnFailure,
    [switch]$JsonOutput
)

$ErrorActionPreference = 'Continue'

# Function to perform individual checks
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
        $status = if ($result) { "Pass" } else { "Fail" }
        $actual = if ($result) { $Expected } else { $FailureMessage }

        [PSCustomObject]@{
            name = $Name
            status = $status
            expected = $Expected
            actual = $actual
            severity = if ($status -eq "Fail") { $Severity } else { "None" }
        }
    }
    catch {
        [PSCustomObject]@{
            name = $Name
            status = "Fail"
            expected = $Expected
            actual = "Exception: $($_.Exception.Message)"
            severity = $Severity
        }
    }
}

# Initialize results
$checks = @()

# Check 1: .NET SDK is installed
$checks += Test-Requirement -Name ".NET SDK" -Expected "Installed" -FailureMessage "Not installed" -Check {
    $dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
    $null -ne $dotnetCmd
}

# Check 2: .NET SDK version meets minimum requirement
$checks += Test-Requirement -Name ".NET SDK Version" -Expected "Version >= $MinimumVersion" -FailureMessage "Version < $MinimumVersion or not found" -Check {
    try {
        $version = dotnet --version 2>&1
        if ($version -match '^\d+\.\d+') {
            $installedVersion = [System.Version]::Parse($version)
            $requiredVersion = [System.Version]::Parse($MinimumVersion)
            $installedVersion -ge $requiredVersion
        }
        else {
            $false
        }
    }
    catch {
        $false
    }
}

# Check 3: .NET CLI info command works
$checks += Test-Requirement -Name ".NET CLI Info" -Expected "Command successful" -FailureMessage "Command failed" -Check {
    try {
        $info = dotnet --info 2>&1
        $LASTEXITCODE -eq 0 -and $info
    }
    catch {
        $false
    }
}

# Check 4: List installed SDKs
$checks += Test-Requirement -Name ".NET SDK List" -Expected "At least one SDK found" -FailureMessage "No SDKs found" -Check {
    try {
        $sdks = dotnet --list-sdks 2>&1
        $LASTEXITCODE -eq 0 -and $sdks
    }
    catch {
        $false
    }
}

# Check 5: List installed runtimes
$checks += Test-Requirement -Name ".NET Runtime List" -Expected "At least one runtime found" -FailureMessage "No runtimes found" -Check {
    try {
        $runtimes = dotnet --list-runtimes 2>&1
        $LASTEXITCODE -eq 0 -and $runtimes
    }
    catch {
        $false
    }
}

# Check 6: Test project creation and build
$testDir = Join-Path $env:TEMP "dotnet-test-$(Get-Random)"
$checks += Test-Requirement -Name ".NET Project Creation" -Expected "Project created successfully" -FailureMessage "Project creation failed" -Check {
    try {
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        $createOutput = dotnet new console -n TestProject -o $testDir 2>&1
        $LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $testDir "TestProject.csproj"))
    }
    catch {
        $false
    }
}

# Check 7: Test NuGet restore
$checks += Test-Requirement -Name ".NET Restore" -Expected "Restore successful" -FailureMessage "Restore failed" -Check {
    try {
        if (Test-Path (Join-Path $testDir "TestProject.csproj")) {
            $restoreOutput = dotnet restore $testDir 2>&1
            $LASTEXITCODE -eq 0
        }
        else {
            $false
        }
    }
    catch {
        $false
    }
}

# Check 8: Test project build
$checks += Test-Requirement -Name ".NET Build" -Expected "Build successful" -FailureMessage "Build failed" -Check {
    try {
        if (Test-Path (Join-Path $testDir "TestProject.csproj")) {
            $buildOutput = dotnet build $testDir --configuration Release 2>&1
            $LASTEXITCODE -eq 0
        }
        else {
            $false
        }
    }
    catch {
        $false
    }
}

# Cleanup
try {
    if (Test-Path $testDir) {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
catch {
    # Ignore cleanup errors
}

# Calculate summary
$passed = ($checks | Where-Object { $_.status -eq "Pass" }).Count
$failed = ($checks | Where-Object { $_.status -eq "Fail" }).Count
$warnings = ($checks | Where-Object { $_.severity -eq "Warning" }).Count

# Output results
if ($JsonOutput) {
    $result = [PSCustomObject]@{
        timestamp = Get-Date -Format "o"
        checks = $checks
        passed = $passed
        failed = $failed
        warnings = $warnings
        totalChecks = $checks.Count
    }
    $result | ConvertTo-Json -Depth 10
}
else {
    Write-Host "`n=== .NET Dependency Verification ===" -ForegroundColor Cyan
    Write-Host ""

    foreach ($check in $checks) {
        $symbol = if ($check.status -eq "Pass") { "✅" } else { "❌" }
        $color = if ($check.status -eq "Pass") { "Green" } else { "Red" }

        Write-Host "$symbol " -NoNewline -ForegroundColor $color
        Write-Host "$($check.name): " -NoNewline
        Write-Host "$($check.actual)" -ForegroundColor $color
    }

    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Passed: $passed" -ForegroundColor Green
    Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
    Write-Host "Warnings: $warnings" -ForegroundColor Yellow
    Write-Host "Total Checks: $($checks.Count)"
    Write-Host ""
}

# Exit with appropriate code
if ($ExitOnFailure -and $failed -gt 0) {
    exit 1
}

exit 0
