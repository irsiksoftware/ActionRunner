#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies ASP.NET Core development environment is properly configured.

.DESCRIPTION
    This script checks that ASP.NET Core and .NET SDK are installed and properly
    configured on the self-hosted runner. It validates the ability to create and
    build basic ASP.NET Core web applications.

    Checks include:
    - .NET SDK 6.0, 7.0, or 8.0
    - ASP.NET Core runtime
    - dotnet CLI functionality
    - Basic web project creation and build

.PARAMETER ExitOnFailure
    Exit with code 1 if any checks fail (useful for CI/CD)

.PARAMETER JsonOutput
    Output results in JSON format

.PARAMETER MinimumVersion
    Minimum required .NET SDK version (default: 6.0)

.EXAMPLE
    .\verify-aspnetcore.ps1

.EXAMPLE
    .\verify-aspnetcore.ps1 -ExitOnFailure

.EXAMPLE
    .\verify-aspnetcore.ps1 -JsonOutput

.EXAMPLE
    .\verify-aspnetcore.ps1 -MinimumVersion "8.0"

.NOTES
    Author: ActionRunner Team
    Version: 1.0.0
    Created for Issue #58: ASP.NET Core verification tests
#>

[CmdletBinding()]
param(
    [switch]$ExitOnFailure,
    [switch]$JsonOutput,
    [string]$MinimumVersion = "6.0"
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
        $script:results.failed++
        $checkResult = @{
            name = $Name
            expected = $Expected
            actual = "Error: $($_.Exception.Message)"
            passed = $false
            message = $FailureMessage
            severity = 'Error'
        }
        $script:results.checks += $checkResult

        if (-not $JsonOutput) {
            Write-Host "❌ $Name : Error - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

if (-not $JsonOutput) {
    Write-Host "`n=== ASP.NET Core Environment Verification ===" -ForegroundColor Cyan
    Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray
}

# Check 1: .NET SDK installed
Test-Requirement `
    -Name ".NET SDK" `
    -Expected "Version $MinimumVersion or higher" `
    -FailureMessage ".NET SDK not found or version below $MinimumVersion" `
    -Check {
        $dotnetVersion = dotnet --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $dotnetVersion) {
            $version = $dotnetVersion.Trim()
            $majorMinor = [System.Version]($version -split '-')[0]
            $minVersion = [System.Version]$MinimumVersion
            @{ Passed = ($majorMinor -ge $minVersion); Value = $version }
        }
        else {
            @{ Passed = $false; Value = "Not installed" }
        }
    }

# Check 2: ASP.NET Core runtime installed
Test-Requirement `
    -Name "ASP.NET Core Runtime" `
    -Expected "Installed" `
    -FailureMessage "ASP.NET Core runtime not found" `
    -Check {
        $runtimes = dotnet --list-runtimes 2>&1 | Select-String "Microsoft.AspNetCore.App"
        if ($runtimes) {
            $versions = $runtimes | ForEach-Object { ($_ -split ' ')[1] }
            @{ Passed = $true; Value = "Versions: $($versions -join ', ')" }
        }
        else {
            @{ Passed = $false; Value = "Not installed" }
        }
    }

# Check 3: dotnet CLI functionality
Test-Requirement `
    -Name "dotnet CLI" `
    -Expected "Functional" `
    -FailureMessage "dotnet CLI not responding correctly" `
    -Check {
        $info = dotnet --info 2>&1
        if ($LASTEXITCODE -eq 0 -and $info) {
            @{ Passed = $true; Value = "OK" }
        }
        else {
            @{ Passed = $false; Value = "CLI error" }
        }
    }

# Check 4: ASP.NET Core SDK workload
Test-Requirement `
    -Name "ASP.NET Core SDK Workload" `
    -Expected "Available" `
    -FailureMessage "ASP.NET Core SDK workload not available" `
    -Check {
        $sdks = dotnet --list-sdks 2>&1
        if ($LASTEXITCODE -eq 0 -and $sdks) {
            $versions = $sdks | ForEach-Object { ($_ -split ' ')[0] }
            @{ Passed = $true; Value = "SDK versions: $($versions -join ', ')" }
        }
        else {
            @{ Passed = $false; Value = "No SDKs found" }
        }
    }

# Check 5: Test project creation
Test-Requirement `
    -Name "Web Project Creation" `
    -Expected "Can create ASP.NET Core web project" `
    -FailureMessage "Failed to create ASP.NET Core web project" `
    -Check {
        $testDir = Join-Path $env:TEMP "aspnetcore-test-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            Push-Location $testDir

            $createOutput = dotnet new webapi --no-https -n TestApi 2>&1
            if ($LASTEXITCODE -eq 0 -and (Test-Path "TestApi/TestApi.csproj")) {
                @{ Passed = $true; Value = "Project created successfully" }
            }
            else {
                @{ Passed = $false; Value = "Creation failed: $createOutput" }
            }
        }
        finally {
            Pop-Location
            if (Test-Path $testDir) {
                Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

# Check 6: Test project build
Test-Requirement `
    -Name "Web Project Build" `
    -Expected "Can build ASP.NET Core web project" `
    -FailureMessage "Failed to build ASP.NET Core web project" `
    -Check {
        $testDir = Join-Path $env:TEMP "aspnetcore-build-test-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            Push-Location $testDir

            dotnet new webapi --no-https -n TestBuildApi 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Push-Location TestBuildApi
                $buildOutput = dotnet build --configuration Release 2>&1
                $buildSuccess = $LASTEXITCODE -eq 0
                Pop-Location

                if ($buildSuccess) {
                    @{ Passed = $true; Value = "Build successful" }
                }
                else {
                    @{ Passed = $false; Value = "Build failed" }
                }
            }
            else {
                @{ Passed = $false; Value = "Project creation failed" }
            }
        }
        finally {
            Pop-Location
            if (Test-Path $testDir) {
                Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

# Check 7: NuGet package restore
Test-Requirement `
    -Name "NuGet Package Restore" `
    -Expected "Can restore NuGet packages" `
    -FailureMessage "Failed to restore NuGet packages" `
    -Severity "Warning" `
    -Check {
        $testDir = Join-Path $env:TEMP "aspnetcore-restore-test-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            Push-Location $testDir

            dotnet new webapi --no-https -n TestRestoreApi 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Push-Location TestRestoreApi
                $restoreOutput = dotnet restore 2>&1
                $restoreSuccess = $LASTEXITCODE -eq 0
                Pop-Location

                if ($restoreSuccess) {
                    @{ Passed = $true; Value = "Restore successful" }
                }
                else {
                    @{ Passed = $false; Value = "Restore failed" }
                }
            }
            else {
                @{ Passed = $false; Value = "Project creation failed" }
            }
        }
        finally {
            Pop-Location
            if (Test-Path $testDir) {
                Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

# Summary
if (-not $JsonOutput) {
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Passed:   $($results.passed)" -ForegroundColor Green
    Write-Host "Failed:   $($results.failed)" -ForegroundColor $(if ($results.failed -gt 0) { "Red" } else { "Gray" })
    Write-Host "Warnings: $($results.warnings)" -ForegroundColor $(if ($results.warnings -gt 0) { "Yellow" } else { "Gray" })
    Write-Host "Total:    $($results.checks.Count)" -ForegroundColor Gray

    if ($results.failed -eq 0) {
        Write-Host "`n✅ ASP.NET Core environment is properly configured!" -ForegroundColor Green
    }
    else {
        Write-Host "`n❌ ASP.NET Core environment has issues that need to be addressed." -ForegroundColor Red
    }
}
else {
    $results | ConvertTo-Json -Depth 10
}

# Exit handling
if ($ExitOnFailure -and $results.failed -gt 0) {
    exit 1
}

exit 0
