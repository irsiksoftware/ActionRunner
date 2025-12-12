#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies WPF (Windows Presentation Foundation) development capability.

.DESCRIPTION
    This script checks that WPF development tools are properly installed and functional.
    It validates:
    - .NET SDK with Windows Desktop workload
    - WPF project creation capability
    - Visual Studio or Build Tools installation
    - Windows Desktop SDK availability

.PARAMETER MinimumVersion
    The minimum required .NET version (default: 6.0)

.PARAMETER ExitOnFailure
    Exit with code 1 if any checks fail

.PARAMETER JsonOutput
    Output results in JSON format

.EXAMPLE
    .\verify-wpf.ps1
    Runs all WPF dependency checks with default settings

.EXAMPLE
    .\verify-wpf.ps1 -MinimumVersion "8.0"
    Checks for .NET SDK version 8.0 or higher

.EXAMPLE
    .\verify-wpf.ps1 -JsonOutput
    Outputs results in JSON format

.EXAMPLE
    .\verify-wpf.ps1 -ExitOnFailure
    Exits with error code if any checks fail

.NOTES
    File Name      : verify-wpf.ps1
    Author         : ActionRunner Team
    Prerequisite   : PowerShell 5.1 or higher, Windows OS
    Copyright 2025 - ActionRunner
#>

[CmdletBinding()]
param(
    [string]$MinimumVersion = "6.0",
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

# Check 0: Windows OS (WPF is Windows-only)
Test-Requirement -Name "Windows Operating System" -Check {
    if ($IsWindows -or $env:OS -match 'Windows') {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            return $os.Caption
        }
        return "Windows"
    }
    return $null
} -Expected "Windows OS required" -FailureMessage "WPF requires Windows. Current OS is not Windows."

# Check 1: .NET SDK is installed
Test-Requirement -Name ".NET SDK Installation" -Check {
    $dotnetCmd = Get-Command dotnet -ErrorAction SilentlyContinue
    if ($dotnetCmd) {
        return $dotnetCmd.Path
    }
    return $null
} -Expected "dotnet CLI found" -FailureMessage ".NET SDK not installed. Install from https://dotnet.microsoft.com/download"

# Check 2: .NET SDK version meets minimum requirement
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
} -Expected "Version >= $MinimumVersion" -FailureMessage ".NET SDK version $MinimumVersion or higher required"

# Check 3: Windows Desktop SDK (includes WPF)
Test-Requirement -Name "Windows Desktop SDK" -Check {
    try {
        $sdks = dotnet --list-sdks 2>&1
        foreach ($sdk in $sdks) {
            if ($sdk -match '(\d+\.\d+\.\d+)') {
                $sdkVersion = $Matches[1]
                $majorVersion = [int]($sdkVersion.Split('.')[0])

                # .NET 6+ includes Windows Desktop by default on Windows
                if ($majorVersion -ge 6) {
                    return "Windows Desktop SDK available (.NET $majorVersion)"
                }
            }
        }
    } catch {
        # Ignore errors
    }
    return $null
} -Expected "Windows Desktop SDK available" -FailureMessage "Windows Desktop SDK not available"

# Check 4: WPF Template availability
Test-Requirement -Name "WPF Project Template" -Check {
    try {
        $templates = dotnet new list 2>&1
        if ($templates -match 'wpf') {
            return "WPF templates available"
        }
    } catch {
        # Ignore errors
    }
    return $null
} -Expected "WPF templates installed" -FailureMessage "WPF project templates not found"

# Check 5: .NET Framework (for legacy WPF projects)
Test-Requirement -Name ".NET Framework 4.x" -Check {
    $frameworkPaths = @(
        "$env:SystemRoot\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe",
        "$env:SystemRoot\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe"
    )

    foreach ($path in $frameworkPaths) {
        if (Test-Path $path) {
            return ".NET Framework 4.x found: $path"
        }
    }
    return $null
} -Expected ".NET Framework available" -FailureMessage ".NET Framework 4.x not found (required for legacy WPF projects)" -Severity "warning"

# Check 6: Visual Studio or Build Tools with Desktop workload
Test-Requirement -Name "Visual Studio Desktop Workload" -Check {
    $vsWherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vsWherePath) {
        # Check for .NET desktop development workload
        $desktopWorkload = & $vsWherePath -latest -requires Microsoft.VisualStudio.Workload.ManagedDesktop -property installationPath 2>$null
        if ($desktopWorkload) {
            return "Desktop workload found: $desktopWorkload"
        }

        # Check for any VS installation
        $vsInstallPath = & $vsWherePath -latest -property installationPath 2>$null
        if ($vsInstallPath) {
            return "Visual Studio found (desktop workload recommended): $vsInstallPath"
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
} -Expected "Desktop development workload installed" -FailureMessage "Visual Studio with Desktop workload recommended" -Severity "warning"

# Check 7: MSBuild availability
Test-Requirement -Name "MSBuild" -Check {
    # Check for MSBuild via dotnet
    try {
        $msbuildInfo = dotnet msbuild --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $msbuildInfo) {
            return "MSBuild via dotnet: $msbuildInfo"
        }
    } catch {
        # Ignore errors
    }

    # Check for standalone MSBuild
    $msbuildCmd = Get-Command msbuild -ErrorAction SilentlyContinue
    if ($msbuildCmd) {
        return "MSBuild found: $($msbuildCmd.Path)"
    }

    # Check VS installation paths
    $vsWherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vsWherePath) {
        $msbuildPath = & $vsWherePath -latest -find "MSBuild\**\Bin\MSBuild.exe" 2>$null | Select-Object -First 1
        if ($msbuildPath -and (Test-Path $msbuildPath)) {
            return "MSBuild found: $msbuildPath"
        }
    }
    return $null
} -Expected "MSBuild available" -FailureMessage "MSBuild not found"

# Check 8: Test WPF project creation
$testDir = Join-Path $env:TEMP "wpf-test-$(Get-Random)"

try {
    Test-Requirement -Name "WPF Project Creation" -Check {
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            $output = dotnet new wpf -n WpfTestApp -o $testDir 2>&1
            if ($LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $testDir "WpfTestApp.csproj"))) {
                return "WPF project created successfully"
            }
        } catch {
            # Ignore errors
        }
        return $null
    } -Expected "WPF project template works" -FailureMessage "WPF project creation failed"

    # Check 9: WPF project restore
    Test-Requirement -Name "WPF Project Restore" -Check {
        try {
            if (Test-Path (Join-Path $testDir "WpfTestApp.csproj")) {
                $output = dotnet restore $testDir 2>&1
                if ($LASTEXITCODE -eq 0) {
                    return "WPF dependencies restored successfully"
                }
            }
        } catch {
            # Ignore errors
        }
        return $null
    } -Expected "NuGet packages restored" -FailureMessage "WPF project restore failed" -Severity "warning"

    # Check 10: WPF project build
    Test-Requirement -Name "WPF Project Build" -Check {
        try {
            if (Test-Path (Join-Path $testDir "WpfTestApp.csproj")) {
                $output = dotnet build $testDir --configuration Release 2>&1
                if ($LASTEXITCODE -eq 0) {
                    return "WPF project built successfully"
                }
            }
        } catch {
            # Ignore errors
        }
        return $null
    } -Expected "Build successful" -FailureMessage "WPF project build failed" -Severity "warning"

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
        capability = "wpf"
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
    Write-Host "`n===== WPF Verification Summary =====" -ForegroundColor Cyan
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
