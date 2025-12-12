#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies mobile development capabilities and determines if the 'mobile' label should be assigned.

.DESCRIPTION
    This script aggregates checks from individual mobile framework verification scripts to determine
    if the runner has ANY mobile development capability. If at least one mobile framework is detected
    (Android SDK, iOS/Xcode, Flutter, or React Native), the runner qualifies for the 'mobile' label.

    This script addresses Issue #157: Ghost Feature - the 'mobile' label was advertised in README.md
    but no detection logic existed to auto-detect and assign this label.

    Checks include:
    - Android SDK (ANDROID_HOME, build-tools, platform-tools)
    - iOS development (Xcode, iOS SDK - macOS only)
    - Flutter SDK
    - React Native CLI and dependencies

.PARAMETER ExitOnFailure
    Exit with code 1 if no mobile capabilities are detected.

.PARAMETER JsonOutput
    Output results in JSON format for automated processing.

.PARAMETER RequireAll
    Require ALL mobile frameworks to be present (default: require ANY one framework).

.EXAMPLE
    .\verify-mobile.ps1
    Runs all mobile capability checks with console output.

.EXAMPLE
    .\verify-mobile.ps1 -JsonOutput
    Runs verification checks and outputs results in JSON format.

.EXAMPLE
    .\verify-mobile.ps1 -ExitOnFailure
    Runs verification and exits with code 1 if no mobile capability is detected.

.NOTES
    Author: ActionRunner Team
    Version: 1.0.0
    Created for Issue #157: Ghost Feature - mobile label implementation
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$ExitOnFailure,

    [Parameter(Mandatory = $false)]
    [switch]$JsonOutput,

    [Parameter(Mandatory = $false)]
    [switch]$RequireAll
)

$ErrorActionPreference = 'Continue'

# Results tracking
$script:Results = @{
    timestamp           = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    checks              = @()
    passed              = 0
    failed              = 0
    warnings            = 0
    mobileCapabilities  = @()
    recommendedLabels   = @()
    qualifiesForMobile  = $false
}

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )

    if (-not $JsonOutput) {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Test-Capability {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Framework,

        [Parameter(Mandatory = $true)]
        [scriptblock]$Check,

        [Parameter(Mandatory = $false)]
        [string]$Description
    )

    $checkResult = @{
        name        = $Name
        framework   = $Framework
        passed      = $false
        details     = ""
        description = $Description
    }

    try {
        $result = & $Check
        $checkResult.passed = $result.Passed
        $checkResult.details = $result.Details

        if ($result.Passed) {
            $script:Results.passed++
            if (-not $JsonOutput) {
                Write-ColorOutput "  [+] $Name" -Color Green
                if ($result.Details) {
                    Write-ColorOutput "      $($result.Details)" -Color Gray
                }
            }
        }
        else {
            $script:Results.failed++
            if (-not $JsonOutput) {
                Write-ColorOutput "  [-] $Name" -Color DarkGray
                if ($result.Details) {
                    Write-ColorOutput "      $($result.Details)" -Color DarkGray
                }
            }
        }
    }
    catch {
        $script:Results.failed++
        $checkResult.passed = $false
        $checkResult.details = "Error: $($_.Exception.Message)"

        if (-not $JsonOutput) {
            Write-ColorOutput "  [!] $Name - Error: $($_.Exception.Message)" -Color Red
        }
    }

    $script:Results.checks += $checkResult
    return $checkResult.passed
}

# Display header
if (-not $JsonOutput) {
    Write-ColorOutput "`n=== Mobile Development Capability Detection ===" -Color Cyan
    Write-ColorOutput "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Color Gray
    Write-ColorOutput "Purpose: Determine eligibility for 'mobile' runner label`n" -Color Gray
}

# ============================================================================
# ANDROID SDK DETECTION
# ============================================================================
if (-not $JsonOutput) {
    Write-ColorOutput "Android SDK:" -Color Yellow
}

$androidCapable = $false

$androidHomeCheck = Test-Capability `
    -Name "ANDROID_HOME Environment Variable" `
    -Framework "Android" `
    -Description "Android SDK root directory" `
    -Check {
        $androidHome = $env:ANDROID_HOME
        if ($androidHome -and (Test-Path $androidHome)) {
            @{ Passed = $true; Details = "Set to: $androidHome" }
        }
        else {
            @{ Passed = $false; Details = "Not set or path doesn't exist" }
        }
    }

$androidBuildToolsCheck = Test-Capability `
    -Name "Android Build Tools" `
    -Framework "Android" `
    -Description "Required for compiling Android apps" `
    -Check {
        $androidHome = $env:ANDROID_HOME
        if ($androidHome) {
            $buildToolsDir = Join-Path $androidHome "build-tools"
            if (Test-Path $buildToolsDir) {
                $versions = Get-ChildItem $buildToolsDir -Directory -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match '^\d+\.\d+\.\d+' }
                if ($versions.Count -gt 0) {
                    $latest = $versions | Sort-Object Name -Descending | Select-Object -First 1
                    @{ Passed = $true; Details = "Found $($versions.Count) version(s), latest: $($latest.Name)" }
                }
                else {
                    @{ Passed = $false; Details = "No build-tools versions installed" }
                }
            }
            else {
                @{ Passed = $false; Details = "build-tools directory not found" }
            }
        }
        else {
            @{ Passed = $false; Details = "ANDROID_HOME not set" }
        }
    }

$androidPlatformToolsCheck = Test-Capability `
    -Name "Android Platform Tools (adb)" `
    -Framework "Android" `
    -Description "Android Debug Bridge for device communication" `
    -Check {
        $adb = Get-Command adb -ErrorAction SilentlyContinue
        if ($adb) {
            $adbVersion = adb version 2>&1 | Select-Object -First 1
            @{ Passed = $true; Details = $adbVersion }
        }
        else {
            @{ Passed = $false; Details = "adb not found in PATH" }
        }
    }

# Android is capable if ANDROID_HOME is set AND either build-tools or platform-tools exist
if ($androidHomeCheck -and ($androidBuildToolsCheck -or $androidPlatformToolsCheck)) {
    $androidCapable = $true
    $script:Results.mobileCapabilities += "Android"
}

# ============================================================================
# iOS/XCODE DETECTION (macOS only)
# ============================================================================
if (-not $JsonOutput) {
    Write-ColorOutput "`niOS/Xcode (macOS only):" -Color Yellow
}

$iosCapable = $false
$isRunningOnMacOS = ($PSVersionTable.PSVersion.Major -ge 6) -and ($PSVersionTable.OS -match 'Darwin')

if ($isRunningOnMacOS) {
    $xcodeCheck = Test-Capability `
        -Name "Xcode Installation" `
        -Framework "iOS" `
        -Description "Apple's IDE for iOS development" `
        -Check {
            $xcodebuild = Get-Command xcodebuild -ErrorAction SilentlyContinue
            if ($xcodebuild) {
                $version = xcodebuild -version 2>&1 | Select-Object -First 1
                @{ Passed = $true; Details = $version }
            }
            else {
                @{ Passed = $false; Details = "xcodebuild not found" }
            }
        }

    $iosSdkCheck = Test-Capability `
        -Name "iOS SDK" `
        -Framework "iOS" `
        -Description "iOS development SDK" `
        -Check {
            try {
                $sdks = xcodebuild -showsdks 2>&1 | Select-String "iphoneos"
                if ($sdks -and $sdks.Count -gt 0) {
                    @{ Passed = $true; Details = "Found $($sdks.Count) iOS SDK(s)" }
                }
                else {
                    @{ Passed = $false; Details = "No iOS SDKs found" }
                }
            }
            catch {
                @{ Passed = $false; Details = "Unable to query SDKs" }
            }
        }

    $cocoaPodsCheck = Test-Capability `
        -Name "CocoaPods" `
        -Framework "iOS" `
        -Description "Dependency manager for iOS projects" `
        -Check {
            $pod = Get-Command pod -ErrorAction SilentlyContinue
            if ($pod) {
                $version = pod --version 2>&1
                @{ Passed = $true; Details = "Version: $version" }
            }
            else {
                @{ Passed = $false; Details = "pod not found in PATH" }
            }
        }

    if ($xcodeCheck -and $iosSdkCheck) {
        $iosCapable = $true
        $script:Results.mobileCapabilities += "iOS"
    }
}
else {
    if (-not $JsonOutput) {
        Write-ColorOutput "  [~] Skipped - Not running on macOS" -Color DarkGray
    }
    $script:Results.checks += @{
        name        = "iOS Development"
        framework   = "iOS"
        passed      = $false
        details     = "iOS development requires macOS"
        description = "Skipped - platform is not macOS"
    }
}

# ============================================================================
# FLUTTER SDK DETECTION
# ============================================================================
if (-not $JsonOutput) {
    Write-ColorOutput "`nFlutter SDK:" -Color Yellow
}

$flutterCapable = $false

$flutterCheck = Test-Capability `
    -Name "Flutter Command" `
    -Framework "Flutter" `
    -Description "Flutter SDK installation" `
    -Check {
        $flutter = Get-Command flutter -ErrorAction SilentlyContinue
        if ($flutter) {
            $version = flutter --version 2>&1 | Out-String
            if ($version -match 'Flutter (\d+\.\d+\.\d+)') {
                @{ Passed = $true; Details = "Flutter $($Matches[1])" }
            }
            else {
                @{ Passed = $true; Details = "Flutter installed at $($flutter.Source)" }
            }
        }
        else {
            @{ Passed = $false; Details = "flutter not found in PATH" }
        }
    }

$dartCheck = Test-Capability `
    -Name "Dart SDK" `
    -Framework "Flutter" `
    -Description "Dart programming language SDK" `
    -Check {
        $dart = Get-Command dart -ErrorAction SilentlyContinue
        if ($dart) {
            $version = dart --version 2>&1 | Out-String
            if ($version -match 'Dart SDK version: (\d+\.\d+\.\d+)') {
                @{ Passed = $true; Details = "Dart $($Matches[1])" }
            }
            else {
                @{ Passed = $true; Details = "Dart installed" }
            }
        }
        else {
            @{ Passed = $false; Details = "dart not found in PATH" }
        }
    }

if ($flutterCheck -and $dartCheck) {
    $flutterCapable = $true
    $script:Results.mobileCapabilities += "Flutter"
}

# ============================================================================
# REACT NATIVE DETECTION
# ============================================================================
if (-not $JsonOutput) {
    Write-ColorOutput "`nReact Native:" -Color Yellow
}

$reactNativeCapable = $false

$nodeCheck = Test-Capability `
    -Name "Node.js" `
    -Framework "ReactNative" `
    -Description "JavaScript runtime (required for React Native)" `
    -Check {
        $node = Get-Command node -ErrorAction SilentlyContinue
        if ($node) {
            $version = node --version 2>&1
            @{ Passed = $true; Details = "Node.js $version" }
        }
        else {
            @{ Passed = $false; Details = "node not found in PATH" }
        }
    }

$npmCheck = Test-Capability `
    -Name "npm Package Manager" `
    -Framework "ReactNative" `
    -Description "Node package manager" `
    -Check {
        $npm = Get-Command npm -ErrorAction SilentlyContinue
        if ($npm) {
            $version = npm --version 2>&1
            @{ Passed = $true; Details = "npm $version" }
        }
        else {
            @{ Passed = $false; Details = "npm not found in PATH" }
        }
    }

$reactNativeCliCheck = Test-Capability `
    -Name "React Native CLI" `
    -Framework "ReactNative" `
    -Description "React Native command-line interface" `
    -Check {
        # Check if react-native is globally installed or accessible via npx
        $rn = Get-Command react-native -ErrorAction SilentlyContinue
        if ($rn) {
            @{ Passed = $true; Details = "react-native found at $($rn.Source)" }
        }
        else {
            # Try npx check
            try {
                $npxCheck = npx react-native --version 2>&1 | Out-String
                if ($LASTEXITCODE -eq 0 -and $npxCheck -match '\d+\.\d+') {
                    @{ Passed = $true; Details = "Available via npx" }
                }
                else {
                    @{ Passed = $false; Details = "Not installed globally or via npx" }
                }
            }
            catch {
                @{ Passed = $false; Details = "Not installed globally or via npx" }
            }
        }
    }

# React Native is capable if Node.js and npm are available (CLI can be installed per-project)
if ($nodeCheck -and $npmCheck) {
    $reactNativeCapable = $true
    $script:Results.mobileCapabilities += "ReactNative"
}

# ============================================================================
# DETERMINE MOBILE LABEL ELIGIBILITY
# ============================================================================
$totalCapabilities = $script:Results.mobileCapabilities.Count

if ($RequireAll) {
    # Require all frameworks (excluding iOS on non-macOS)
    $requiredCount = if ($isRunningOnMacOS) { 4 } else { 3 }
    $script:Results.qualifiesForMobile = ($totalCapabilities -ge $requiredCount)
}
else {
    # Default: ANY mobile framework qualifies for 'mobile' label
    $script:Results.qualifiesForMobile = ($totalCapabilities -gt 0)
}

# Build recommended labels list
if ($script:Results.qualifiesForMobile) {
    $script:Results.recommendedLabels += "mobile"
}
if ($androidCapable) {
    $script:Results.recommendedLabels += "android"
}
if ($iosCapable) {
    $script:Results.recommendedLabels += "ios"
}
if ($flutterCapable) {
    $script:Results.recommendedLabels += "flutter"
}
if ($reactNativeCapable) {
    $script:Results.recommendedLabels += "react-native"
}

# ============================================================================
# OUTPUT RESULTS
# ============================================================================
if ($JsonOutput) {
    $script:Results | ConvertTo-Json -Depth 10
}
else {
    Write-ColorOutput "`n=== Mobile Capability Summary ===" -Color Cyan

    Write-Host "Checks Passed: " -NoNewline
    Write-Host $script:Results.passed -ForegroundColor Green
    Write-Host "Checks Failed: " -NoNewline
    Write-Host $script:Results.failed -ForegroundColor Red

    Write-ColorOutput "`nDetected Mobile Capabilities:" -Color White
    if ($script:Results.mobileCapabilities.Count -gt 0) {
        foreach ($cap in $script:Results.mobileCapabilities) {
            Write-ColorOutput "  - $cap" -Color Green
        }
    }
    else {
        Write-ColorOutput "  (none)" -Color DarkGray
    }

    Write-ColorOutput "`n'mobile' Label Eligibility:" -Color White
    if ($script:Results.qualifiesForMobile) {
        Write-ColorOutput "  YES - Runner qualifies for 'mobile' label" -Color Green
    }
    else {
        Write-ColorOutput "  NO - No mobile development capabilities detected" -Color Red
    }

    if ($script:Results.recommendedLabels.Count -gt 0) {
        Write-ColorOutput "`nRecommended Labels:" -Color White
        Write-ColorOutput "  $($script:Results.recommendedLabels -join ', ')" -Color Cyan
    }

    Write-ColorOutput "`n" -Color White
}

# Exit with appropriate code
if ($ExitOnFailure -and -not $script:Results.qualifiesForMobile) {
    exit 1
}

exit 0
