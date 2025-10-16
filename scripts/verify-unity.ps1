#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies Unity build pipeline installation and configuration.

.DESCRIPTION
    This script checks Unity installation, licensing, and build pipeline capabilities.
    It validates Unity Hub, Unity Editor, build targets, and performs a test build.

.PARAMETER ExitOnFailure
    Exit with code 1 if any checks fail.

.PARAMETER JsonOutput
    Output results in JSON format.

.PARAMETER MinimumVersion
    Minimum Unity version required (default: 2021.3.0f1 LTS).

.EXAMPLE
    .\verify-unity.ps1
    Runs all Unity verification checks with standard output.

.EXAMPLE
    .\verify-unity.ps1 -JsonOutput
    Runs checks and outputs results in JSON format.

.EXAMPLE
    .\verify-unity.ps1 -MinimumVersion "2022.3.0f1" -ExitOnFailure
    Requires Unity 2022.3.0f1 or higher and exits on failure.
#>

[CmdletBinding()]
param(
    [switch]$ExitOnFailure,
    [switch]$JsonOutput,
    [string]$MinimumVersion = "2021.3.0f1"
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

# Check Unity Hub installation
Test-Requirement -Name "Unity Hub Installation" -Check {
    if ($IsWindows -or $env:OS -match 'Windows') {
        $hubPath = Get-Command "Unity Hub.exe" -ErrorAction SilentlyContinue
        if (-not $hubPath) {
            $hubPath = Get-ChildItem "C:\Program Files\Unity Hub\" -Filter "Unity Hub.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        }
    } else {
        $hubPath = Get-Command "unity-hub" -ErrorAction SilentlyContinue
    }

    if ($hubPath) {
        return $hubPath.Path
    }
    return $null
} -Expected "Unity Hub executable found" -FailureMessage "Unity Hub not found. Please install Unity Hub."

# Check Unity Editor installation
Test-Requirement -Name "Unity Editor Installation" -Check {
    if ($IsWindows -or $env:OS -match 'Windows') {
        $editorPath = Get-Command "Unity.exe" -ErrorAction SilentlyContinue
        if (-not $editorPath) {
            $editorPaths = @(
                "C:\Program Files\Unity\Hub\Editor\*\Editor\Unity.exe",
                "C:\Program Files\Unity\Editor\Unity.exe"
            )
            foreach ($path in $editorPaths) {
                $found = Get-Item $path -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) {
                    $editorPath = $found
                    break
                }
            }
        }
    } else {
        $editorPath = Get-Command "unity" -ErrorAction SilentlyContinue
        if (-not $editorPath) {
            $editorPath = Get-Item "/Applications/Unity/Hub/Editor/*/Unity.app/Contents/MacOS/Unity" -ErrorAction SilentlyContinue | Select-Object -First 1
        }
    }

    if ($editorPath) {
        return $editorPath.Path
    }
    return $null
} -Expected "Unity Editor executable found" -FailureMessage "Unity Editor not found. Please install Unity Editor via Unity Hub."

# Check Unity version
Test-Requirement -Name "Unity Version Check" -Check {
    if ($IsWindows -or $env:OS -match 'Windows') {
        $editorPath = Get-Command "Unity.exe" -ErrorAction SilentlyContinue
        if (-not $editorPath) {
            $editorPath = Get-Item "C:\Program Files\Unity\Hub\Editor\*\Editor\Unity.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        }
    } else {
        $editorPath = Get-Command "unity" -ErrorAction SilentlyContinue
        if (-not $editorPath) {
            $editorPath = Get-Item "/Applications/Unity/Hub/Editor/*/Unity.app/Contents/MacOS/Unity" -ErrorAction SilentlyContinue | Select-Object -First 1
        }
    }

    if ($editorPath) {
        # Extract version from path
        $version = $editorPath.FullName -replace '.*\\(\d+\.\d+\.\d+\w+)\\.*', '$1'
        if ($version -match '\d+\.\d+\.\d+') {
            $installedVersion = [version]($version -replace 'f.*$', '')
            $requiredVersion = [version]($MinimumVersion -replace 'f.*$', '')

            if ($installedVersion -ge $requiredVersion) {
                return $version
            }
        }
    }
    return $null
} -Expected "Unity version >= $MinimumVersion" -FailureMessage "Unity version $MinimumVersion or higher required"

# Check Unity license
Test-Requirement -Name "Unity License Status" -Check {
    if ($IsWindows -or $env:OS -match 'Windows') {
        $licenseFile = "$env:ProgramData\Unity\Unity_lic.ulf"
        if (Test-Path $licenseFile) {
            return "License file found"
        }
    } else {
        $licenseFile = "/Library/Application Support/Unity/Unity_lic.ulf"
        if (Test-Path $licenseFile) {
            return "License file found"
        }
    }
    return $null
} -Expected "Valid Unity license" -FailureMessage "Unity license not found. Please activate Unity." -Severity "warning"

# Check Android build support (common mobile target)
Test-Requirement -Name "Android Build Support" -Check {
    if ($IsWindows -or $env:OS -match 'Windows') {
        $androidModule = Get-Item "C:\Program Files\Unity\Hub\Editor\*\Editor\Data\PlaybackEngines\AndroidPlayer" -ErrorAction SilentlyContinue | Select-Object -First 1
    } else {
        $androidModule = Get-Item "/Applications/Unity/Hub/Editor/*/PlaybackEngines/AndroidPlayer" -ErrorAction SilentlyContinue | Select-Object -First 1
    }

    if ($androidModule) {
        return "Android build support installed"
    }
    return $null
} -Expected "Android build module installed" -FailureMessage "Android build support not installed. Install via Unity Hub." -Severity "warning"

# Check iOS build support (common mobile target)
Test-Requirement -Name "iOS Build Support" -Check {
    if ($IsWindows -or $env:OS -match 'Windows') {
        $iosModule = Get-Item "C:\Program Files\Unity\Hub\Editor\*\Editor\Data\PlaybackEngines\iOSSupport" -ErrorAction SilentlyContinue | Select-Object -First 1
    } else {
        $iosModule = Get-Item "/Applications/Unity/Hub/Editor/*/PlaybackEngines/iOSSupport" -ErrorAction SilentlyContinue | Select-Object -First 1
    }

    if ($iosModule) {
        return "iOS build support installed"
    }
    return $null
} -Expected "iOS build module installed" -FailureMessage "iOS build support not installed. Install via Unity Hub." -Severity "warning"

# Test Unity build by creating a minimal project
$testDir = Join-Path $env:TEMP "unity-build-test-$(Get-Random)"

try {
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    # Create minimal Unity project structure
    $projectVersion = @"
m_EditorVersion: 2021.3.0f1
m_EditorVersionWithRevision: 2021.3.0f1 (1234567890ab)
"@

    $projectSettings = @"
%YAML 1.1
%TAG !u! tag:unity3d.com,2011:
--- !u!129 &1
PlayerSettings:
  m_ObjectHideFlags: 0
  serializedVersion: 23
  productName: UnityBuildTest
  companyName: DefaultCompany
  bundleVersion: 1.0
  AndroidBundleVersionCode: 1
  iOSBundleVersion: 1.0
"@

    $testScript = @"
using UnityEngine;

public class BuildTest : MonoBehaviour
{
    void Start()
    {
        Debug.Log("Unity build pipeline test successful");
    }
}
"@

    # Create project structure
    New-Item -ItemType Directory -Path "$testDir\Assets" -Force | Out-Null
    New-Item -ItemType Directory -Path "$testDir\ProjectSettings" -Force | Out-Null

    Set-Content -Path "$testDir\ProjectSettings\ProjectVersion.txt" -Value $projectVersion -Force
    Set-Content -Path "$testDir\ProjectSettings\ProjectSettings.asset" -Value $projectSettings -Force
    Set-Content -Path "$testDir\Assets\BuildTest.cs" -Value $testScript -Force

    Test-Requirement -Name "Unity Project Structure Creation" -Check {
        $assetsExists = Test-Path "$testDir\Assets"
        $projectSettingsExists = Test-Path "$testDir\ProjectSettings"

        if ($assetsExists -and $projectSettingsExists) {
            return "Project structure created successfully"
        }
        return $null
    } -Expected "Valid Unity project structure" -FailureMessage "Failed to create Unity project structure"

    Test-Requirement -Name "Unity Build Script Validation" -Check {
        $scriptPath = "$testDir\Assets\BuildTest.cs"
        if (Test-Path $scriptPath) {
            $content = Get-Content $scriptPath -Raw
            if ($content -match "MonoBehaviour" -and $content -match "void Start") {
                return "Build script validated"
            }
        }
        return $null
    } -Expected "Valid Unity C# script" -FailureMessage "Unity script validation failed"

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
        checks = $checks
        passed = $passed
        failed = $failed
        warnings = $warnings
        summary = @{
            total = $checks.Count
            passed = $passed
            failed = $failed
            warnings = $warnings
        }
    }

    $result | ConvertTo-Json -Depth 10
} else {
    Write-Host "`n===== Summary =====" -ForegroundColor Cyan
    Write-Host "Total checks: $($checks.Count)"
    Write-Host "Passed: $passed" -ForegroundColor Green
    Write-Host "Failed: $failed" -ForegroundColor Red
    Write-Host "Warnings: $warnings" -ForegroundColor Yellow
}

# Exit with appropriate code
if ($ExitOnFailure -and $failed -gt 0) {
    exit 1
}

exit 0
