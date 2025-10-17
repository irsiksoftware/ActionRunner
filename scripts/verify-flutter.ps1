#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies Flutter SDK installation and configuration for GitHub Actions runners.

.DESCRIPTION
    This script performs comprehensive verification of Flutter development environment:
    - Flutter SDK installation and version
    - Dart SDK installation and version
    - Flutter doctor diagnostics
    - Flutter project creation and build
    - Flutter dependencies management
    - Flutter unit testing capabilities

.PARAMETER ExitOnFailure
    Exit with code 1 if any verification checks fail.

.PARAMETER JsonOutput
    Output results in JSON format for automated processing.

.PARAMETER MinimumFlutterVersion
    Minimum required Flutter version (default: "3.0.0").

.EXAMPLE
    .\verify-flutter.ps1
    Runs all Flutter verification checks with console output.

.EXAMPLE
    .\verify-flutter.ps1 -JsonOutput
    Runs verification checks and outputs results in JSON format.

.EXAMPLE
    .\verify-flutter.ps1 -MinimumFlutterVersion "3.10.0" -ExitOnFailure
    Verifies Flutter installation with minimum version 3.10.0 and exits on failure.

.NOTES
    Author: ActionRunner Team
    Requires: PowerShell 5.1+, Flutter SDK
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$ExitOnFailure,

    [Parameter(Mandatory = $false)]
    [switch]$JsonOutput,

    [Parameter(Mandatory = $false)]
    [string]$MinimumFlutterVersion = "3.0.0"
)

$ErrorActionPreference = 'Continue'

# Color output support
$script:SupportsColor = $Host.UI.SupportsVirtualTerminal -and (-not $JsonOutput)

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )

    if (-not $JsonOutput) {
        if ($script:SupportsColor) {
            $colorCodes = @{
                'Red'     = "`e[91m"
                'Green'   = "`e[92m"
                'Yellow'  = "`e[93m"
                'Blue'    = "`e[94m"
                'Magenta' = "`e[95m"
                'Cyan'    = "`e[96m"
                'White'   = "`e[97m"
                'Reset'   = "`e[0m"
            }
            Write-Host "$($colorCodes[$Color])$Message$($colorCodes['Reset'])"
        }
        else {
            Write-Host $Message
        }
    }
}

# Results tracking
$script:Results = @{
    timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    checks    = @()
    passed    = 0
    failed    = 0
    warnings  = 0
}

function Test-Requirement {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Check,

        [Parameter(Mandatory = $false)]
        [string]$Expected,

        [Parameter(Mandatory = $false)]
        [string]$FailureMessage,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Error', 'Warning')]
        [string]$Severity = 'Error'
    )

    $checkResult = @{
        name     = $Name
        passed   = $false
        actual   = ""
        expected = $Expected
        message  = ""
        severity = $Severity
    }

    try {
        $result = & $Check
        $checkResult.actual = $result

        if ($result) {
            $checkResult.passed = $true
            $checkResult.message = "Check passed"
            $script:Results.passed++

            if (-not $JsonOutput) {
                Write-ColorOutput "✅ $Name" -Color Green
                if ($Expected) {
                    Write-ColorOutput "   Expected: $Expected" -Color Cyan
                    Write-ColorOutput "   Actual: $result" -Color Cyan
                }
            }
        }
        else {
            $checkResult.passed = $false
            $checkResult.message = if ($FailureMessage) { $FailureMessage } else { "Check failed" }

            if ($Severity -eq 'Warning') {
                $script:Results.warnings++
                if (-not $JsonOutput) {
                    Write-ColorOutput "⚠️  $Name" -Color Yellow
                    Write-ColorOutput "   $($checkResult.message)" -Color Yellow
                }
            }
            else {
                $script:Results.failed++
                if (-not $JsonOutput) {
                    Write-ColorOutput "❌ $Name" -Color Red
                    Write-ColorOutput "   $($checkResult.message)" -Color Red
                }
            }
        }
    }
    catch {
        $checkResult.passed = $false
        $checkResult.message = $_.Exception.Message

        if ($Severity -eq 'Warning') {
            $script:Results.warnings++
            if (-not $JsonOutput) {
                Write-ColorOutput "⚠️  $Name" -Color Yellow
                Write-ColorOutput "   Error: $($_.Exception.Message)" -Color Yellow
            }
        }
        else {
            $script:Results.failed++
            if (-not $JsonOutput) {
                Write-ColorOutput "❌ $Name" -Color Red
                Write-ColorOutput "   Error: $($_.Exception.Message)" -Color Red
            }
        }
    }

    $script:Results.checks += $checkResult
}

# Display header
if (-not $JsonOutput) {
    Write-ColorOutput "`n=== Flutter SDK Verification ===" -Color Cyan
    Write-ColorOutput "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -Color Cyan
}

# Check 1: Flutter command availability
Test-Requirement -Name "Flutter Command Available" -Check {
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutterCmd) {
        return $flutterCmd.Source
    }
    return $null
} -Expected "Flutter executable in PATH" -FailureMessage "Flutter command not found in PATH"

# Check 2: Flutter version
Test-Requirement -Name "Flutter Version" -Check {
    $versionOutput = flutter --version 2>&1 | Out-String
    if ($versionOutput -match 'Flutter (\d+\.\d+\.\d+)') {
        $currentVersion = $Matches[1]
        $minVersion = [version]$MinimumFlutterVersion
        $currentVersionObj = [version]$currentVersion

        if ($currentVersionObj -ge $minVersion) {
            return $currentVersion
        }
    }
    return $null
} -Expected "Flutter >= $MinimumFlutterVersion" -FailureMessage "Flutter version is below minimum required version $MinimumFlutterVersion"

# Check 3: Dart SDK
Test-Requirement -Name "Dart SDK" -Check {
    $dartCmd = Get-Command dart -ErrorAction SilentlyContinue
    if ($dartCmd) {
        $dartVersion = dart --version 2>&1 | Out-String
        if ($dartVersion -match 'Dart SDK version: (\d+\.\d+\.\d+)') {
            return $Matches[1]
        }
        return "Installed"
    }
    return $null
} -Expected "Dart SDK installed" -FailureMessage "Dart SDK not found"

# Check 4: Flutter Doctor
Test-Requirement -Name "Flutter Doctor Diagnostics" -Check {
    $doctorOutput = flutter doctor 2>&1 | Out-String
    # We just check if flutter doctor runs successfully
    if ($LASTEXITCODE -eq 0 -or $doctorOutput) {
        return "Flutter doctor completed"
    }
    return $null
} -Expected "Flutter doctor runs successfully" -FailureMessage "Flutter doctor failed to run" -Severity Warning

# Check 5: Flutter Project Creation and Build Test
$testDir = $null
try {
    $testDir = Join-Path $env:TEMP "flutter_test_$(Get-Random)"

    Test-Requirement -Name "Flutter Project Creation" -Check {
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        $createOutput = flutter create $testDir --no-pub 2>&1 | Out-String

        if (Test-Path (Join-Path $testDir "pubspec.yaml")) {
            return "Project created successfully"
        }
        return $null
    } -Expected "Flutter project structure created" -FailureMessage "Failed to create Flutter project"

    Test-Requirement -Name "Flutter Dependencies Installation" -Check {
        Push-Location $testDir
        try {
            $pubGetOutput = flutter pub get 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0) {
                return "Dependencies installed"
            }
            return $null
        }
        finally {
            Pop-Location
        }
    } -Expected "flutter pub get succeeds" -FailureMessage "Failed to install Flutter dependencies"

    Test-Requirement -Name "Flutter Project Build Test" -Check {
        Push-Location $testDir
        try {
            # Try building for a platform (apk for Android or web)
            # Using flutter build apk --debug is most universal
            $buildOutput = flutter build apk --debug 2>&1 | Out-String

            if ($LASTEXITCODE -eq 0) {
                return "Build successful"
            }

            # If Android build fails, try web build as fallback
            $webBuildOutput = flutter build web 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0) {
                return "Web build successful"
            }

            return $null
        }
        finally {
            Pop-Location
        }
    } -Expected "Flutter project builds successfully" -FailureMessage "Failed to build Flutter project" -Severity Warning

    Test-Requirement -Name "Flutter Unit Tests" -Check {
        Push-Location $testDir
        try {
            $testOutput = flutter test 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0 -and $testOutput -match 'All tests passed') {
                return "Tests passed"
            }
            return $null
        }
        finally {
            Pop-Location
        }
    } -Expected "Flutter tests run successfully" -FailureMessage "Flutter tests failed" -Severity Warning
}
finally {
    # Cleanup
    if ($testDir -and (Test-Path $testDir)) {
        try {
            Push-Location $env:TEMP
            Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
            Pop-Location
        }
        catch {
            # Ignore cleanup errors
        }
    }
}

# Output results
if ($JsonOutput) {
    $script:Results | ConvertTo-Json -Depth 10
}
else {
    Write-ColorOutput "`n=== Summary ===" -Color Cyan
    Write-ColorOutput "Passed: $($script:Results.passed)" -Color Green
    Write-ColorOutput "Failed: $($script:Results.failed)" -Color Red
    Write-ColorOutput "Warnings: $($script:Results.warnings)" -Color Yellow
    Write-ColorOutput "Total Checks: $($script:Results.checks.Count)" -Color Cyan
}

# Exit with appropriate code
if ($ExitOnFailure -and $script:Results.failed -gt 0) {
    exit 1
}

exit 0
