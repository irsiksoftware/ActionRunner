#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies iOS build environment for GitHub Actions runner on macOS

.DESCRIPTION
    Performs comprehensive checks of Xcode, iOS SDK, Command Line Tools,
    and related iOS development dependencies. Validates that the macOS
    environment is properly configured for iOS builds with GitHub Actions
    self-hosted runners.

.PARAMETER ExitOnFailure
    Exit with code 1 if any critical checks fail

.PARAMETER JsonOutput
    Output results in JSON format for programmatic consumption

.EXAMPLE
    .\verify-ios-build.ps1
    Runs all iOS build environment checks with human-readable output

.EXAMPLE
    .\verify-ios-build.ps1 -JsonOutput
    Runs verification and outputs results as JSON

.EXAMPLE
    .\verify-ios-build.ps1 -ExitOnFailure
    Runs verification and exits with code 1 on any failure
#>

[CmdletBinding()]
param(
    [switch]$ExitOnFailure,
    [switch]$JsonOutput
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
    Write-Host "=== iOS Build Environment Verification ===" -ForegroundColor Cyan
    Write-Host ""
}

# Check 0: Platform check - must be macOS
Test-Requirement `
    -Name "Platform Check" `
    -Expected "Running on macOS (Darwin)" `
    -FailureMessage "This script requires macOS. iOS builds are not supported on Windows or Linux." `
    -Severity "Critical" `
    -Check {
        $isMacOS = ($PSVersionTable.PSVersion.Major -ge 6) -and ($PSVersionTable.OS -match 'Darwin')
        @{
            Success = $isMacOS
            Actual = if ($isMacOS) { "macOS" } else { $PSVersionTable.OS }
        }
    }

# Check 1: Xcode command availability
Test-Requirement `
    -Name "Xcode Command" `
    -Expected "xcodebuild command is available" `
    -FailureMessage "Xcode not found. Install Xcode from the App Store." `
    -Severity "Critical" `
    -Check {
        $xcodeCmd = Get-Command xcodebuild -ErrorAction SilentlyContinue
        @{
            Success = $null -ne $xcodeCmd
            Actual = if ($xcodeCmd) { $xcodeCmd.Source } else { "Not found" }
        }
    }

# Check 2: Xcode version
Test-Requirement `
    -Name "Xcode Version" `
    -Expected "Xcode 14.0 or higher" `
    -FailureMessage "Xcode version is too old or could not be determined" `
    -Severity "Critical" `
    -Check {
        try {
            $versionOutput = xcodebuild -version 2>&1 | Select-Object -First 1
            if ($LASTEXITCODE -eq 0 -and $versionOutput -match 'Xcode\s+(\d+\.\d+)') {
                $version = [version]$matches[1]
                $minVersion = [version]'14.0'
                @{
                    Success = $version -ge $minVersion
                    Actual = "Xcode $version"
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

# Check 3: Command Line Tools
Test-Requirement `
    -Name "Command Line Tools" `
    -Expected "Command Line Tools are installed" `
    -FailureMessage "Command Line Tools not installed. Run: xcode-select --install" `
    -Severity "Critical" `
    -Check {
        try {
            $cltPath = xcode-select -p 2>&1
            $success = $LASTEXITCODE -eq 0 -and (Test-Path $cltPath)
            @{
                Success = $success
                Actual = if ($success) { "Installed at $cltPath" } else { "Not installed" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
        }
    }

# Check 4: iOS SDK availability
Test-Requirement `
    -Name "iOS SDK" `
    -Expected "iOS SDK is available" `
    -FailureMessage "iOS SDK not found. Ensure Xcode is properly installed." `
    -Severity "Critical" `
    -Check {
        try {
            $sdks = xcodebuild -showsdks 2>&1 | Select-String "iphoneos"
            $success = $null -ne $sdks -and $sdks.Count -gt 0
            $sdkVersion = if ($sdks) {
                ($sdks | Select-Object -First 1).ToString() -replace '.*iphoneos(\d+\.\d+).*', '$1'
            } else {
                "Not found"
            }
            @{
                Success = $success
                Actual = if ($success) { "iOS SDK $sdkVersion" } else { "Not found" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
        }
    }

# Check 5: iOS Simulator
Test-Requirement `
    -Name "iOS Simulator" `
    -Expected "iOS Simulator is available" `
    -FailureMessage "iOS Simulator not found or not accessible" `
    -Severity "Warning" `
    -Check {
        try {
            $simulators = xcrun simctl list devices available 2>&1 | Select-String "iPhone"
            $success = $null -ne $simulators -and $simulators.Count -gt 0
            @{
                Success = $success
                Actual = if ($success) { "$($simulators.Count) simulator(s) available" } else { "No simulators found" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
        }
    }

# Check 6: CocoaPods
Test-Requirement `
    -Name "CocoaPods" `
    -Expected "CocoaPods is available for dependency management" `
    -FailureMessage "CocoaPods not found. Install with: sudo gem install cocoapods" `
    -Severity "Warning" `
    -Check {
        try {
            $pod = Get-Command pod -ErrorAction SilentlyContinue
            if ($null -ne $pod) {
                $version = pod --version 2>&1
                $success = $LASTEXITCODE -eq 0
                @{
                    Success = $success
                    Actual = if ($success) { "CocoaPods $version" } else { "Found but version check failed" }
                }
            }
            else {
                @{ Success = $false; Actual = "Not installed" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
        }
    }

# Check 7: xcodebuild test capability
Test-Requirement `
    -Name "Build Test" `
    -Expected "xcodebuild can show build settings" `
    -FailureMessage "Cannot retrieve build settings from xcodebuild" `
    -Severity "Info" `
    -Check {
        try {
            $null = xcodebuild -showBuildSettings 2>&1
            $success = $LASTEXITCODE -eq 0
            @{
                Success = $success
                Actual = if ($success) { "Build settings accessible" } else { "Cannot access build settings" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
        }
    }

# Check 8: xcrun availability
Test-Requirement `
    -Name "xcrun Command" `
    -Expected "xcrun command is available" `
    -FailureMessage "xcrun not found. Reinstall Command Line Tools." `
    -Severity "Critical" `
    -Check {
        $xcrun = Get-Command xcrun -ErrorAction SilentlyContinue
        @{
            Success = $null -ne $xcrun
            Actual = if ($xcrun) { $xcrun.Source } else { "Not found" }
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
        Write-Host "✅ iOS build environment is properly configured!" -ForegroundColor Green
    }
    else {
        Write-Host "❌ iOS build environment has issues that need attention." -ForegroundColor Red
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
