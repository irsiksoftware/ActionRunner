#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies React Native development environment for GitHub Actions runners.

.DESCRIPTION
    This script performs comprehensive verification of React Native development environment:
    - Node.js installation and version (dependency on Issue #9)
    - npm and package management
    - React Native CLI installation
    - Android SDK setup (dependency on Issue #25)
    - iOS build environment (macOS only)
    - React Native project initialization
    - Metro bundler functionality
    - React Native project build capabilities

.PARAMETER ExitOnFailure
    Exit with code 1 if any verification checks fail.

.PARAMETER JsonOutput
    Output results in JSON format for automated processing.

.PARAMETER MinimumNodeVersion
    Minimum required Node.js version (default: "16.0").

.PARAMETER MinimumReactNativeVersion
    Minimum required React Native version (default: "0.70.0").

.EXAMPLE
    .\verify-reactnative.ps1
    Runs all React Native verification checks with console output.

.EXAMPLE
    .\verify-reactnative.ps1 -JsonOutput
    Runs verification checks and outputs results in JSON format.

.EXAMPLE
    .\verify-reactnative.ps1 -MinimumNodeVersion "18.0" -ExitOnFailure
    Verifies React Native with minimum Node.js version 18.0 and exits on failure.

.NOTES
    Author: ActionRunner Team
    Requires: PowerShell 5.1+, Node.js, Android SDK (for Android builds), Xcode (for iOS builds on macOS)
    Dependencies: Issue #9 (Node.js), Issue #25 (Android SDK)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$ExitOnFailure,

    [Parameter(Mandatory = $false)]
    [switch]$JsonOutput,

    [Parameter(Mandatory = $false)]
    [string]$MinimumNodeVersion = "16.0",

    [Parameter(Mandatory = $false)]
    [string]$MinimumReactNativeVersion = "0.70.0"
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
    Write-ColorOutput "`n=== React Native Development Environment Verification ===" -Color Cyan
    Write-ColorOutput "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -Color Cyan
}

# Check 1: Node.js availability (Dependency on Issue #9)
Test-Requirement -Name "Node.js Command Available" -Check {
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        return $nodeCmd.Source
    }
    return $null
} -Expected "Node.js executable in PATH" -FailureMessage "Node.js command not found in PATH (required by Issue #9)"

# Check 2: Node.js version
Test-Requirement -Name "Node.js Version" -Check {
    $versionOutput = node --version 2>&1 | Out-String
    if ($versionOutput -match 'v?(\d+\.\d+)') {
        $currentVersion = $Matches[1]
        $minVersion = [version]$MinimumNodeVersion
        $currentVersionObj = [version]$currentVersion

        if ($currentVersionObj -ge $minVersion) {
            return $currentVersion
        }
    }
    return $null
} -Expected "Node.js >= $MinimumNodeVersion" -FailureMessage "Node.js version is below minimum required version $MinimumNodeVersion"

# Check 3: npm availability
Test-Requirement -Name "npm Command Available" -Check {
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if ($npmCmd) {
        $npmVersion = npm --version 2>&1 | Out-String
        return $npmVersion.Trim()
    }
    return $null
} -Expected "npm package manager" -FailureMessage "npm command not found"

# Check 4: React Native CLI
Test-Requirement -Name "React Native CLI Available" -Check {
    # Check if react-native command is available
    $rnCmd = Get-Command react-native -ErrorAction SilentlyContinue
    if ($rnCmd) {
        return $rnCmd.Source
    }

    # Check if npx can run react-native
    $npxCheck = npx react-native --version 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and $npxCheck) {
        return "Available via npx"
    }
    return $null
} -Expected "React Native CLI accessible" -FailureMessage "React Native CLI not found (install with: npm install -g react-native-cli)"

# Check 5: React Native CLI version
Test-Requirement -Name "React Native CLI Version" -Check {
    $versionOutput = npx react-native --version 2>&1 | Out-String
    if ($versionOutput -match '(\d+\.\d+\.\d+)') {
        $currentVersion = $Matches[1]
        $minVersion = [version]$MinimumReactNativeVersion
        $currentVersionObj = [version]$currentVersion

        if ($currentVersionObj -ge $minVersion) {
            return $currentVersion
        }
    }
    return $null
} -Expected "React Native >= $MinimumReactNativeVersion" -FailureMessage "React Native version is below minimum required version $MinimumReactNativeVersion" -Severity Warning

# Check 6: Watchman (optional but recommended)
Test-Requirement -Name "Watchman File Watcher" -Check {
    $watchmanCmd = Get-Command watchman -ErrorAction SilentlyContinue
    if ($watchmanCmd) {
        $watchmanVersion = watchman --version 2>&1 | Out-String
        if ($watchmanVersion) {
            return $watchmanVersion.Trim()
        }
    }
    return $null
} -Expected "Watchman for file watching" -FailureMessage "Watchman not found (optional but recommended for better performance)" -Severity Warning

# Check 7: Android SDK (Dependency on Issue #25)
Test-Requirement -Name "Android SDK Configuration" -Check {
    if ($env:ANDROID_HOME -and (Test-Path $env:ANDROID_HOME)) {
        return $env:ANDROID_HOME
    }
    if ($env:ANDROID_SDK_ROOT -and (Test-Path $env:ANDROID_SDK_ROOT)) {
        return $env:ANDROID_SDK_ROOT
    }
    return $null
} -Expected "ANDROID_HOME or ANDROID_SDK_ROOT set" -FailureMessage "Android SDK not configured (required by Issue #25)" -Severity Warning

# Check 8: Android SDK platform-tools (for adb)
Test-Requirement -Name "Android Platform Tools" -Check {
    $adbCmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($adbCmd) {
        $adbVersion = adb --version 2>&1 | Out-String
        if ($adbVersion -match 'Version (\S+)') {
            return $Matches[1]
        }
        return "Installed"
    }
    return $null
} -Expected "adb command available" -FailureMessage "Android platform-tools (adb) not found in PATH" -Severity Warning

# Check 9: Java Runtime (required for Android builds)
Test-Requirement -Name "Java Runtime" -Check {
    $javaCmd = Get-Command java -ErrorAction SilentlyContinue
    if ($javaCmd) {
        $javaVersion = java -version 2>&1 | Out-String
        if ($javaVersion -match 'version "?(\d+)') {
            return "Java $($Matches[1])"
        }
        return "Installed"
    }
    return $null
} -Expected "Java runtime for Android builds" -FailureMessage "Java runtime not found (required for Android builds)" -Severity Warning

# Check 10: iOS build environment (macOS only)
$isOnMacOS = ($PSVersionTable.PSVersion.Major -ge 6) -and ($PSVersionTable.OS -match 'Darwin')
if ($isOnMacOS) {
    Test-Requirement -Name "Xcode Command Line Tools" -Check {
        $xcodeSelect = xcode-select -p 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -and $xcodeSelect) {
            return $xcodeSelect.Trim()
        }
        return $null
    } -Expected "Xcode command line tools installed" -FailureMessage "Xcode command line tools not found" -Severity Warning

    Test-Requirement -Name "CocoaPods" -Check {
        $podCmd = Get-Command pod -ErrorAction SilentlyContinue
        if ($podCmd) {
            $podVersion = pod --version 2>&1 | Out-String
            return $podVersion.Trim()
        }
        return $null
    } -Expected "CocoaPods for iOS dependency management" -FailureMessage "CocoaPods not found (required for iOS builds)" -Severity Warning
}

# Check 11: React Native project initialization test
$testDir = $null
try {
    $testDir = Join-Path $env:TEMP "rn_test_$(Get-Random)"

    Test-Requirement -Name "React Native Project Initialization" -Check {
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        Push-Location $testDir
        try {
            # Initialize a React Native project
            $initOutput = npx react-native init TestApp --skip-install 2>&1 | Out-String

            $projectPath = Join-Path $testDir "TestApp"
            if (Test-Path (Join-Path $projectPath "package.json")) {
                return "Project initialized successfully"
            }
            return $null
        }
        finally {
            Pop-Location
        }
    } -Expected "React Native project structure created" -FailureMessage "Failed to initialize React Native project"

    $projectPath = Join-Path $testDir "TestApp"
    if (Test-Path $projectPath) {
        Test-Requirement -Name "React Native Dependencies Installation" -Check {
            Push-Location $projectPath
            try {
                $installOutput = npm install 2>&1 | Out-String
                if ($LASTEXITCODE -eq 0 -and (Test-Path "node_modules")) {
                    return "Dependencies installed"
                }
                return $null
            }
            finally {
                Pop-Location
            }
        } -Expected "npm install succeeds" -FailureMessage "Failed to install React Native dependencies"

        Test-Requirement -Name "Metro Bundler Start Check" -Check {
            Push-Location $projectPath
            try {
                # Check if metro bundler can be started (just verify the command exists)
                $packageJson = Get-Content "package.json" -Raw | ConvertFrom-Json
                if ($packageJson.scripts.start) {
                    return "Metro bundler script available"
                }
                return $null
            }
            finally {
                Pop-Location
            }
        } -Expected "Metro bundler configured" -FailureMessage "Metro bundler script not found in package.json" -Severity Warning

        Test-Requirement -Name "React Native Android Build Setup" -Check {
            Push-Location $projectPath
            try {
                # Check if Android build files exist
                $androidPath = Join-Path $projectPath "android"
                if (Test-Path $androidPath) {
                    $gradleWrapper = Join-Path $androidPath "gradlew.bat"
                    if ($IsWindows -or (-not ($PSVersionTable.PSVersion.Major -ge 6))) {
                        # On Windows
                        if (Test-Path $gradleWrapper) {
                            return "Android build setup complete"
                        }
                    }
                    else {
                        # On Unix-like systems
                        $gradleWrapperUnix = Join-Path $androidPath "gradlew"
                        if (Test-Path $gradleWrapperUnix) {
                            return "Android build setup complete"
                        }
                    }
                }
                return $null
            }
            finally {
                Pop-Location
            }
        } -Expected "Android build configuration present" -FailureMessage "Android build setup incomplete" -Severity Warning

        if ($isOnMacOS) {
            Test-Requirement -Name "React Native iOS Build Setup" -Check {
                Push-Location $projectPath
                try {
                    # Check if iOS build files exist
                    $iosPath = Join-Path $projectPath "ios"
                    if (Test-Path $iosPath) {
                        $podfile = Join-Path $iosPath "Podfile"
                        if (Test-Path $podfile) {
                            return "iOS build setup complete"
                        }
                    }
                    return $null
                }
                finally {
                    Pop-Location
                }
            } -Expected "iOS build configuration present" -FailureMessage "iOS build setup incomplete" -Severity Warning
        }
    }
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
