#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies Android SDK and build tools are properly configured.

.DESCRIPTION
    This script checks that Android SDK and build tools are installed and properly configured on the
    self-hosted runner. It validates the ability to create and build basic Android projects.

    Checks include:
    - Android SDK installation and tools
    - Android SDK environment variables (ANDROID_HOME, ANDROID_SDK_ROOT)
    - Android SDK build tools, platform tools, and command-line tools
    - SDK platforms installation
    - Basic Android project creation and build
    - Gradle wrapper for Android builds

.PARAMETER ExitOnFailure
    Exit with code 1 if any checks fail (useful for CI/CD)

.PARAMETER JsonOutput
    Output results in JSON format

.PARAMETER MinimumApiLevel
    Minimum required Android API level (default: 21)

.PARAMETER MinimumBuildToolsVersion
    Minimum required build tools version (default: 30.0.0)

.EXAMPLE
    .\verify-android.ps1

.EXAMPLE
    .\verify-android.ps1 -ExitOnFailure

.EXAMPLE
    .\verify-android.ps1 -JsonOutput

.EXAMPLE
    .\verify-android.ps1 -MinimumApiLevel 28 -MinimumBuildToolsVersion "33.0.0"

.NOTES
    Author: ActionRunner Team
    Version: 1.0.0
    Created for Issue #72: Add Android build tests
#>

[CmdletBinding()]
param(
    [switch]$ExitOnFailure,
    [switch]$JsonOutput,
    [int]$MinimumApiLevel = 21,
    [string]$MinimumBuildToolsVersion = "30.0.0"
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
    Write-Host "`n=== Android SDK and Build Tools Verification ===" -ForegroundColor Cyan
    Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray
}

# Check 1: ANDROID_HOME environment variable
Test-Requirement `
    -Name "ANDROID_HOME Configuration" `
    -Expected "ANDROID_HOME environment variable set" `
    -FailureMessage "ANDROID_HOME not configured" `
    -Check {
        $androidHome = $env:ANDROID_HOME
        if ($androidHome -and (Test-Path $androidHome)) {
            @{ Passed = $true; Value = $androidHome }
        }
        else {
            @{ Passed = $false; Value = "Not set or invalid" }
        }
    }

# Check 2: ANDROID_SDK_ROOT environment variable
Test-Requirement `
    -Name "ANDROID_SDK_ROOT Configuration" `
    -Expected "ANDROID_SDK_ROOT environment variable set" `
    -FailureMessage "ANDROID_SDK_ROOT not configured" `
    -Severity "Warning" `
    -Check {
        $androidSdkRoot = $env:ANDROID_SDK_ROOT
        if ($androidSdkRoot -and (Test-Path $androidSdkRoot)) {
            @{ Passed = $true; Value = $androidSdkRoot }
        }
        else {
            @{ Passed = $false; Value = "Not set or invalid" }
        }
    }

# Check 3: Android SDK command-line tools
Test-Requirement `
    -Name "Android SDK Command-line Tools" `
    -Expected "sdkmanager available" `
    -FailureMessage "Android SDK command-line tools not found" `
    -Check {
        $sdkmanager = Get-Command sdkmanager -ErrorAction SilentlyContinue
        if ($sdkmanager) {
            @{ Passed = $true; Value = "sdkmanager found at $($sdkmanager.Source)" }
        }
        else {
            # Try alternative paths
            $androidHome = $env:ANDROID_HOME
            if ($androidHome) {
                $sdkmanagerPaths = @(
                    (Join-Path $androidHome "cmdline-tools\latest\bin\sdkmanager.bat"),
                    (Join-Path $androidHome "tools\bin\sdkmanager.bat")
                )
                $found = $sdkmanagerPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
                if ($found) {
                    @{ Passed = $true; Value = "sdkmanager found at $found" }
                }
                else {
                    @{ Passed = $false; Value = "Not found in PATH or ANDROID_HOME" }
                }
            }
            else {
                @{ Passed = $false; Value = "Not found" }
            }
        }
    }

# Check 4: Android SDK platform-tools
Test-Requirement `
    -Name "Android Platform Tools" `
    -Expected "adb available" `
    -FailureMessage "Android platform-tools not found" `
    -Check {
        $adb = Get-Command adb -ErrorAction SilentlyContinue
        if ($adb) {
            $adbVersion = adb version 2>&1 | Select-Object -First 1
            @{ Passed = $true; Value = $adbVersion }
        }
        else {
            @{ Passed = $false; Value = "Not found" }
        }
    }

# Check 5: Android SDK build-tools
Test-Requirement `
    -Name "Android Build Tools" `
    -Expected "Build tools version $MinimumBuildToolsVersion or higher" `
    -FailureMessage "Android build-tools not found or version below $MinimumBuildToolsVersion" `
    -Check {
        $androidHome = $env:ANDROID_HOME
        if ($androidHome) {
            $buildToolsDir = Join-Path $androidHome "build-tools"
            if (Test-Path $buildToolsDir) {
                $versions = Get-ChildItem $buildToolsDir -Directory |
                    Where-Object { $_.Name -match '^\d+\.\d+\.\d+' } |
                    ForEach-Object {
                        try {
                            [version]($_.Name -split '-')[0]
                        }
                        catch {
                            $null
                        }
                    } |
                    Where-Object { $_ -ne $null } |
                    Sort-Object -Descending

                if ($versions.Count -gt 0) {
                    $latestVersion = $versions[0]
                    $minVersion = [version]$MinimumBuildToolsVersion
                    if ($latestVersion -ge $minVersion) {
                        @{ Passed = $true; Value = "Latest version: $latestVersion" }
                    }
                    else {
                        @{ Passed = $false; Value = "Latest version $latestVersion is below minimum $MinimumBuildToolsVersion" }
                    }
                }
                else {
                    @{ Passed = $false; Value = "No build-tools versions found" }
                }
            }
            else {
                @{ Passed = $false; Value = "build-tools directory not found" }
            }
        }
        else {
            @{ Passed = $false; Value = "ANDROID_HOME not set" }
        }
    }

# Check 6: Android SDK platforms
Test-Requirement `
    -Name "Android SDK Platforms" `
    -Expected "At least one SDK platform installed (API $MinimumApiLevel or higher)" `
    -FailureMessage "No Android SDK platforms found or all below API $MinimumApiLevel" `
    -Check {
        $androidHome = $env:ANDROID_HOME
        if ($androidHome) {
            $platformsDir = Join-Path $androidHome "platforms"
            if (Test-Path $platformsDir) {
                $platforms = Get-ChildItem $platformsDir -Directory |
                    Where-Object { $_.Name -match '^android-(\d+)' } |
                    ForEach-Object {
                        if ($_.Name -match '^android-(\d+)') {
                            [int]$matches[1]
                        }
                    } |
                    Where-Object { $_ -ge $MinimumApiLevel } |
                    Sort-Object -Descending

                if ($platforms.Count -gt 0) {
                    $platformList = $platforms -join ', '
                    @{ Passed = $true; Value = "API levels: $platformList" }
                }
                else {
                    @{ Passed = $false; Value = "No platforms at API $MinimumApiLevel or higher" }
                }
            }
            else {
                @{ Passed = $false; Value = "platforms directory not found" }
            }
        }
        else {
            @{ Passed = $false; Value = "ANDROID_HOME not set" }
        }
    }

# Check 7: Java runtime (required for Android builds)
Test-Requirement `
    -Name "Java Runtime" `
    -Expected "Java installed (required for Android builds)" `
    -FailureMessage "Java not found - Android builds require Java" `
    -Check {
        $javaVersion = java -version 2>&1
        if ($LASTEXITCODE -eq 0 -and $javaVersion) {
            if ($javaVersion -match 'version "([^"]+)"' -or $javaVersion -match 'openjdk version "([^"]+)"') {
                $version = $matches[1]
                @{ Passed = $true; Value = "Java $version" }
            }
            else {
                @{ Passed = $true; Value = "Java installed" }
            }
        }
        else {
            @{ Passed = $false; Value = "Not installed" }
        }
    }

# Check 8: Gradle installed (for Android builds)
Test-Requirement `
    -Name "Gradle Installation" `
    -Expected "Gradle installed for Android builds" `
    -FailureMessage "Gradle not found" `
    -Severity "Warning" `
    -Check {
        $gradleVersion = gradle --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $gradleVersion) {
            if ($gradleVersion -match 'Gradle ([\d.]+)') {
                $version = $matches[1]
                @{ Passed = $true; Value = "Gradle $version" }
            }
            else {
                @{ Passed = $true; Value = "Gradle installed" }
            }
        }
        else {
            @{ Passed = $false; Value = "Not installed (Gradle wrapper can be used)" }
        }
    }

# Check 9: Test Android project creation and build
Test-Requirement `
    -Name "Android Project Build Test" `
    -Expected "Can create and build a basic Android project" `
    -FailureMessage "Unable to create or build Android project" `
    -Check {
        $testDir = Join-Path $env:TEMP "android-test-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            Push-Location $testDir

            # Create minimal Android project structure
            $appDir = Join-Path $testDir "app"
            $srcDir = Join-Path $appDir "src\main\java\com\test\app"
            $resDir = Join-Path $appDir "src\main\res\values"
            New-Item -ItemType Directory -Path $srcDir -Force | Out-Null
            New-Item -ItemType Directory -Path $resDir -Force | Out-Null

            # Create settings.gradle
            $settingsGradle = @'
rootProject.name = 'TestAndroidApp'
include ':app'
'@
            Set-Content -Path (Join-Path $testDir "settings.gradle") -Value $settingsGradle -Force

            # Get latest platform and build-tools
            $androidHome = $env:ANDROID_HOME
            $platformsDir = Join-Path $androidHome "platforms"
            $latestPlatform = Get-ChildItem $platformsDir -Directory |
                Where-Object { $_.Name -match '^android-(\d+)' } |
                ForEach-Object {
                    @{
                        Name = $_.Name
                        ApiLevel = [int]($matches[1])
                    }
                } |
                Sort-Object -Property ApiLevel -Descending |
                Select-Object -First 1

            $buildToolsDir = Join-Path $androidHome "build-tools"
            $latestBuildTools = Get-ChildItem $buildToolsDir -Directory |
                Where-Object { $_.Name -match '^\d+\.\d+\.\d+' } |
                Sort-Object -Descending |
                Select-Object -First 1

            # Create build.gradle (project level)
            $buildGradleRoot = @'
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:7.4.2'
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

task clean(type: Delete) {
    delete rootProject.buildDir
}
'@
            Set-Content -Path (Join-Path $testDir "build.gradle") -Value $buildGradleRoot -Force

            # Create build.gradle (app level)
            $buildGradleApp = @"
plugins {
    id 'com.android.application'
}

android {
    compileSdkVersion $($latestPlatform.ApiLevel)
    buildToolsVersion '$($latestBuildTools.Name)'

    defaultConfig {
        applicationId 'com.test.app'
        minSdkVersion $MinimumApiLevel
        targetSdkVersion $($latestPlatform.ApiLevel)
        versionCode 1
        versionName '1.0'
    }

    buildTypes {
        release {
            minifyEnabled false
        }
    }

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}

dependencies {
    implementation 'androidx.appcompat:appcompat:1.6.1'
}
"@
            Set-Content -Path (Join-Path $appDir "build.gradle") -Value $buildGradleApp -Force

            # Create AndroidManifest.xml
            $manifest = @'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.test.app">

    <application
        android:label="TestApp"
        android:theme="@android:style/Theme.Material.Light">
        <activity android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>

</manifest>
'@
            $manifestPath = Join-Path $appDir "src\main\AndroidManifest.xml"
            New-Item -ItemType Directory -Path (Split-Path $manifestPath -Parent) -Force | Out-Null
            Set-Content -Path $manifestPath -Value $manifest -Force

            # Create MainActivity.java
            $mainActivity = @'
package com.test.app;

import android.app.Activity;
import android.os.Bundle;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }
}
'@
            Set-Content -Path (Join-Path $srcDir "MainActivity.java") -Value $mainActivity -Force

            # Create strings.xml
            $stringsXml = @'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">TestApp</string>
</resources>
'@
            Set-Content -Path (Join-Path $resDir "strings.xml") -Value $stringsXml -Force

            # Generate gradle wrapper
            gradle wrapper --gradle-version 7.6 --no-daemon 2>&1 | Out-Null

            # Build the project using gradle wrapper
            if (Test-Path (Join-Path $testDir "gradlew.bat")) {
                $buildOutput = & (Join-Path $testDir "gradlew.bat") assembleDebug --no-daemon 2>&1
                if ($LASTEXITCODE -eq 0) {
                    $apkFile = Join-Path $appDir "build\outputs\apk\debug\app-debug.apk"
                    if (Test-Path $apkFile) {
                        Pop-Location
                        @{ Passed = $true; Value = "Build successful, APK created" }
                    }
                    else {
                        Pop-Location
                        @{ Passed = $false; Value = "Build completed but APK not found" }
                    }
                }
                else {
                    Pop-Location
                    @{ Passed = $false; Value = "Build failed" }
                }
            }
            else {
                Pop-Location
                @{ Passed = $false; Value = "Gradle wrapper not created" }
            }
        }
        finally {
            Pop-Location -ErrorAction SilentlyContinue
            if (Test-Path $testDir) {
                Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

if (-not $JsonOutput) {
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Passed: $($results.passed)" -ForegroundColor Green
    Write-Host "Failed: $($results.failed)" -ForegroundColor Red
    Write-Host "Warnings: $($results.warnings)" -ForegroundColor Yellow
    Write-Host "Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray
}
else {
    $results | ConvertTo-Json -Depth 10
}

if ($ExitOnFailure -and $results.failed -gt 0) {
    exit 1
}

exit 0
