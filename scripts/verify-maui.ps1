#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies .NET MAUI workload installation and configuration.

.DESCRIPTION
    This script checks that the .NET MAUI workload is properly installed and functional.
    It validates:
    - .NET SDK installation (required for MAUI)
    - MAUI workload installation
    - Windows App SDK (for Windows targets)
    - Android SDK (for Android targets)
    - MAUI project creation and build capabilities

.PARAMETER MinimumVersion
    The minimum required .NET version for MAUI (default: 8.0)

.PARAMETER ExitOnFailure
    Exit with code 1 if any checks fail

.PARAMETER JsonOutput
    Output results in JSON format

.EXAMPLE
    .\verify-maui.ps1
    Runs all MAUI dependency checks with default settings

.EXAMPLE
    .\verify-maui.ps1 -MinimumVersion "9.0"
    Checks for .NET SDK version 9.0 or higher

.EXAMPLE
    .\verify-maui.ps1 -JsonOutput
    Outputs results in JSON format

.EXAMPLE
    .\verify-maui.ps1 -ExitOnFailure
    Exits with error code if any checks fail

.NOTES
    File Name      : verify-maui.ps1
    Author         : ActionRunner Team
    Prerequisite   : PowerShell 5.1 or higher
    Copyright 2025 - ActionRunner
#>

[CmdletBinding()]
param(
    [string]$MinimumVersion = "8.0",
    [switch]$ExitOnFailure,
    [switch]$JsonOutput
)

$ErrorActionPreference = 'Continue'

# Initialize results
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
        [string]$Severity = 'error'
    )

    $result = @{
        name = $Name
        expected = $Expected
        actual = ""
        status = "unknown"
        message = ""
    }

    try {
        $actual = & $Check
        $result.actual = $actual -join "`n"

        if ($actual) {
            $result.status = "passed"
            $result.message = "Check passed"
            $script:passed++
        } else {
            if ($Severity -eq 'warning') {
                $result.status = "warning"
                $script:warnings++
            } else {
                $result.status = "failed"
                $script:failed++
            }
            $result.message = $FailureMessage
        }
    } catch {
        if ($Severity -eq 'warning') {
            $result.status = "warning"
            $script:warnings++
        } else {
            $result.status = "failed"
            $script:failed++
        }
        $result.message = $_.Exception.Message
    }

    $script:checks += $result

    if (-not $JsonOutput) {
        $icon = if ($result.status -eq "passed") { "✅" } elseif ($result.status -eq "warning") { "⚠️" } else { "❌" }
        Write-Host "$icon $Name"
        if ($result.status -ne "passed") {
            Write-Host "   $($result.message)" -ForegroundColor Yellow
        }
    }

    return $result.status -eq "passed"
}

# Check 1: .NET SDK is installed
Test-Requirement -Name ".NET SDK Installation" -Check {
    $dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($dotnetCmd) {
        return $dotnetCmd.Path
    }
    return $null
} -Expected "dotnet CLI found" -FailureMessage ".NET SDK not installed. Install from https://dotnet.microsoft.com/download"

# Check 2: .NET SDK version meets minimum requirement for MAUI
Test-Requirement -Name ".NET SDK Version (>= $MinimumVersion)" -Check {
    try {
        $version = dotnet --version 2>&1
        if ($version -match '^\d+\.\d+') {
            $installedVersion = [System.Version]::Parse($version)
            $requiredVersion = [System.Version]::Parse($MinimumVersion)
            if ($installedVersion -ge $requiredVersion) {
                return $version
            }
        }
    } catch {
        # Ignore parse errors
    }
    return $null
} -Expected "Version >= $MinimumVersion" -FailureMessage ".NET SDK version $MinimumVersion or higher required for MAUI"

# Check 3: MAUI workload is installed
Test-Requirement -Name "MAUI Workload" -Check {
    try {
        $workloads = dotnet workload list 2>&1
        if ($workloads -match 'maui') {
            return "MAUI workload installed"
        }
    } catch {
        # Ignore errors
    }
    return $null
} -Expected "MAUI workload installed" -FailureMessage "MAUI workload not installed. Run: dotnet workload install maui"

# Check 4: MAUI Windows workload (for Windows desktop apps)
Test-Requirement -Name "MAUI Windows Workload" -Check {
    try {
        $workloads = dotnet workload list 2>&1
        if ($workloads -match 'maui-windows') {
            return "MAUI Windows workload installed"
        }
    } catch {
        # Ignore errors
    }
    return $null
} -Expected "MAUI Windows workload installed" -FailureMessage "MAUI Windows workload not installed. Run: dotnet workload install maui-windows" -Severity "warning"

# Check 5: MAUI Android workload (optional for cross-platform)
Test-Requirement -Name "MAUI Android Workload" -Check {
    try {
        $workloads = dotnet workload list 2>&1
        if ($workloads -match 'maui-android') {
            return "MAUI Android workload installed"
        }
    } catch {
        # Ignore errors
    }
    return $null
} -Expected "MAUI Android workload installed" -FailureMessage "MAUI Android workload not installed (optional for mobile builds)" -Severity "warning"

# Check 6: Windows App SDK (for WinUI3/MAUI Windows)
Test-Requirement -Name "Windows App SDK" -Check {
    # Check for Windows App SDK via NuGet package cache or SDK presence
    $windowsAppSdkPaths = @(
        "$env:USERPROFILE\.nuget\packages\microsoft.windowsappsdk",
        "$env:ProgramFiles\Microsoft SDKs\Windows App SDK"
    )

    foreach ($path in $windowsAppSdkPaths) {
        if (Test-Path $path) {
            return "Windows App SDK found at: $path"
        }
    }

    # Also check via dotnet workload
    try {
        $workloads = dotnet workload list 2>&1
        if ($workloads -match 'microsoft-net-sdk-windowsdesktop') {
            return "Windows Desktop SDK workload installed"
        }
    } catch {
        # Ignore errors
    }
    return $null
} -Expected "Windows App SDK available" -FailureMessage "Windows App SDK not found (may be installed on first build)" -Severity "warning"

# Check 7: Visual Studio Build Tools or VS (recommended for MAUI)
Test-Requirement -Name "Visual Studio / Build Tools" -Check {
    $vsWherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vsWherePath) {
        $vsInstallPath = & $vsWherePath -latest -property installationPath 2>$null
        if ($vsInstallPath) {
            return "Visual Studio found: $vsInstallPath"
        }
    }

    # Check for Build Tools
    $buildToolsPaths = @(
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools",
        "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\BuildTools"
    )
    foreach ($path in $buildToolsPaths) {
        if (Test-Path $path) {
            return "Build Tools found: $path"
        }
    }
    return $null
} -Expected "Visual Studio or Build Tools installed" -FailureMessage "Visual Studio or Build Tools recommended for MAUI development" -Severity "warning"

# Check 8: Test MAUI project creation
$testDir = Join-Path $env:TEMP "maui-test-$(Get-Random)"

try {
    Test-Requirement -Name "MAUI Project Creation" -Check {
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            $output = dotnet new maui -n MauiTestApp -o $testDir 2>&1
            if ($LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $testDir "MauiTestApp.csproj"))) {
                return "MAUI project created successfully"
            }
        } catch {
            # Ignore errors
        }
        return $null
    } -Expected "MAUI project template available" -FailureMessage "MAUI project creation failed. Ensure MAUI workload is installed."

    # Check 9: MAUI project restore
    Test-Requirement -Name "MAUI Project Restore" -Check {
        try {
            if (Test-Path (Join-Path $testDir "MauiTestApp.csproj")) {
                $output = dotnet restore $testDir 2>&1
                if ($LASTEXITCODE -eq 0) {
                    return "MAUI dependencies restored successfully"
                }
            }
        } catch {
            # Ignore errors
        }
        return $null
    } -Expected "NuGet packages restored" -FailureMessage "MAUI project restore failed" -Severity "warning"

} finally {
    # Cleanup
    if (Test-Path $testDir) {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Output results
if ($JsonOutput) {
    $result = @{
        timestamp = Get-Date -Format "o"
        capability = "maui"
        checks = $checks
        summary = @{
            total = $checks.Count
            passed = $passed
            failed = $failed
            warnings = $warnings
        }
    }

    $result | ConvertTo-Json -Depth 10
} else {
    Write-Host "`n===== MAUI Verification Summary =====" -ForegroundColor Cyan
    Write-Host "Total checks: $($checks.Count)"
    Write-Host "Passed: $passed" -ForegroundColor Green
    Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
    Write-Host "Warnings: $warnings" -ForegroundColor Yellow
    Write-Host ""
}

# Exit with appropriate code
if ($ExitOnFailure -and $failed -gt 0) {
    exit 1
}

exit 0
