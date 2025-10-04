#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies Gradle build tool is properly configured.

.DESCRIPTION
    This script checks that Gradle is installed and properly configured on the
    self-hosted runner. It validates the ability to create and build basic Gradle projects.

    Checks include:
    - Gradle installation and version
    - Java runtime (required for Gradle)
    - Gradle home configuration
    - Gradle user home and cache directories
    - Basic Gradle project creation and build
    - Kotlin DSL support

.PARAMETER ExitOnFailure
    Exit with code 1 if any checks fail (useful for CI/CD)

.PARAMETER JsonOutput
    Output results in JSON format

.PARAMETER MinimumVersion
    Minimum required Gradle version (default: 6.0)

.EXAMPLE
    .\verify-gradle.ps1

.EXAMPLE
    .\verify-gradle.ps1 -ExitOnFailure

.EXAMPLE
    .\verify-gradle.ps1 -JsonOutput

.EXAMPLE
    .\verify-gradle.ps1 -MinimumVersion "7.0"

.NOTES
    Author: ActionRunner Team
    Version: 1.0.0
    Created for Issue #88: Gradle verification tests
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
    Write-Host "`n=== Gradle Build Tool Environment Verification ===" -ForegroundColor Cyan
    Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray
}

# Check 1: Gradle installed
Test-Requirement `
    -Name "Gradle Installation" `
    -Expected "Version $MinimumVersion or higher" `
    -FailureMessage "Gradle not found or version below $MinimumVersion" `
    -Check {
        $gradleVersion = gradle --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $gradleVersion) {
            # Parse "Gradle 7.5.1" format
            if ($gradleVersion -match 'Gradle ([\d.]+)') {
                $version = $matches[1]
                $installedVersion = [version]($version -split '-')[0]
                $minVersion = [version]$MinimumVersion
                @{ Passed = ($installedVersion -ge $minVersion); Value = "Gradle $version" }
            }
            else {
                @{ Passed = $false; Value = "Unable to parse version" }
            }
        }
        else {
            @{ Passed = $false; Value = "Not installed" }
        }
    }

# Check 2: Java runtime
Test-Requirement `
    -Name "Java Runtime" `
    -Expected "Java installed (required for Gradle)" `
    -FailureMessage "Java not found - Gradle requires Java" `
    -Check {
        $javaVersion = java -version 2>&1
        if ($LASTEXITCODE -eq 0 -and $javaVersion) {
            # Parse Java version from output
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

# Check 3: JAVA_HOME configured
Test-Requirement `
    -Name "JAVA_HOME Configuration" `
    -Expected "JAVA_HOME environment variable set" `
    -FailureMessage "JAVA_HOME not configured" `
    -Severity "Warning" `
    -Check {
        $javaHome = $env:JAVA_HOME
        if ($javaHome -and (Test-Path $javaHome)) {
            @{ Passed = $true; Value = $javaHome }
        }
        else {
            @{ Passed = $false; Value = "Not set or invalid" }
        }
    }

# Check 4: Gradle home
Test-Requirement `
    -Name "Gradle Home" `
    -Expected "GRADLE_HOME environment variable set" `
    -FailureMessage "Gradle home directory not configured" `
    -Severity "Warning" `
    -Check {
        $gradleHome = $env:GRADLE_HOME
        if ($gradleHome) {
            @{ Passed = $true; Value = $gradleHome }
        }
        else {
            @{ Passed = $false; Value = "Not set" }
        }
    }

# Check 5: Gradle user home
Test-Requirement `
    -Name "Gradle User Home" `
    -Expected "User home directory exists" `
    -FailureMessage "Gradle user home not found" `
    -Severity "Warning" `
    -Check {
        $gradleUserHome = if ($env:GRADLE_USER_HOME) { $env:GRADLE_USER_HOME } else { Join-Path $env:USERPROFILE ".gradle" }
        if (Test-Path $gradleUserHome) {
            @{ Passed = $true; Value = $gradleUserHome }
        }
        else {
            @{ Passed = $false; Value = "Not initialized" }
        }
    }

# Check 6: Gradle daemon
Test-Requirement `
    -Name "Gradle Daemon Support" `
    -Expected "Daemon can be queried" `
    -FailureMessage "Unable to query Gradle daemon" `
    -Severity "Warning" `
    -Check {
        $daemonStatus = gradle --status 2>&1
        if ($LASTEXITCODE -eq 0) {
            @{ Passed = $true; Value = "Daemon accessible" }
        }
        else {
            @{ Passed = $false; Value = "Daemon not accessible" }
        }
    }

# Check 7: Test Gradle build with Groovy DSL
Test-Requirement `
    -Name "Gradle Build Test (Groovy DSL)" `
    -Expected "Can create and build a simple Gradle project with Groovy DSL" `
    -FailureMessage "Unable to create or build Gradle project with Groovy DSL" `
    -Check {
        $testDir = Join-Path $env:TEMP "gradle-test-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            Push-Location $testDir

            # Create a minimal build.gradle
            $buildGradle = @'
plugins {
    id 'java'
}

group = 'com.test'
version = '1.0-SNAPSHOT'

repositories {
    mavenCentral()
}

sourceCompatibility = '1.8'
targetCompatibility = '1.8'
'@
            Set-Content -Path (Join-Path $testDir "build.gradle") -Value $buildGradle -Force

            # Create source directory
            $srcDir = Join-Path $testDir "src\main\java\com\test"
            New-Item -ItemType Directory -Path $srcDir -Force | Out-Null

            # Create a simple Java class
            $javaClass = @'
package com.test;

public class App {
    public static void main(String[] args) {
        System.out.println("Hello, Gradle!");
    }
}
'@
            Set-Content -Path (Join-Path $srcDir "App.java") -Value $javaClass -Force

            # Build the project
            $buildOutput = gradle build --no-daemon 2>&1
            if ($LASTEXITCODE -eq 0) {
                $classFile = Join-Path $testDir "build\classes\java\main\com\test\App.class"
                if (Test-Path $classFile) {
                    Pop-Location
                    @{ Passed = $true; Value = "Build successful" }
                }
                else {
                    Pop-Location
                    @{ Passed = $false; Value = "Class file not created" }
                }
            }
            else {
                Pop-Location
                @{ Passed = $false; Value = "Build failed" }
            }
        }
        finally {
            Pop-Location -ErrorAction SilentlyContinue
            if (Test-Path $testDir) {
                Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

# Check 8: Test Gradle build with Kotlin DSL
Test-Requirement `
    -Name "Gradle Build Test (Kotlin DSL)" `
    -Expected "Can create and build a simple Gradle project with Kotlin DSL" `
    -FailureMessage "Unable to create or build Gradle project with Kotlin DSL" `
    -Check {
        $testDir = Join-Path $env:TEMP "gradle-kotlin-test-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            Push-Location $testDir

            # Create a minimal build.gradle.kts
            $buildGradleKts = @'
plugins {
    java
}

group = "com.test"
version = "1.0-SNAPSHOT"

repositories {
    mavenCentral()
}

java {
    sourceCompatibility = JavaVersion.VERSION_1_8
    targetCompatibility = JavaVersion.VERSION_1_8
}
'@
            Set-Content -Path (Join-Path $testDir "build.gradle.kts") -Value $buildGradleKts -Force

            # Create source directory
            $srcDir = Join-Path $testDir "src\main\java\com\test"
            New-Item -ItemType Directory -Path $srcDir -Force | Out-Null

            # Create a simple Java class
            $javaClass = @'
package com.test;

public class KotlinDslApp {
    public static String getMessage() {
        return "Hello from Kotlin DSL!";
    }
}
'@
            Set-Content -Path (Join-Path $srcDir "KotlinDslApp.java") -Value $javaClass -Force

            # Build the project
            $buildOutput = gradle build --no-daemon 2>&1
            if ($LASTEXITCODE -eq 0) {
                $classFile = Join-Path $testDir "build\classes\java\main\com\test\KotlinDslApp.class"
                if (Test-Path $classFile) {
                    Pop-Location
                    @{ Passed = $true; Value = "Kotlin DSL build successful" }
                }
                else {
                    Pop-Location
                    @{ Passed = $false; Value = "Class file not created" }
                }
            }
            else {
                Pop-Location
                @{ Passed = $false; Value = "Kotlin DSL build failed" }
            }
        }
        finally {
            Pop-Location -ErrorAction SilentlyContinue
            if (Test-Path $testDir) {
                Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

# Check 9: Gradle wrapper support
Test-Requirement `
    -Name "Gradle Wrapper Test" `
    -Expected "Can generate Gradle wrapper" `
    -FailureMessage "Unable to generate Gradle wrapper" `
    -Check {
        $testDir = Join-Path $env:TEMP "gradle-wrapper-test-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            Push-Location $testDir

            # Generate wrapper
            $wrapperOutput = gradle wrapper --no-daemon 2>&1
            if ($LASTEXITCODE -eq 0) {
                $gradlewBat = Join-Path $testDir "gradlew.bat"
                if (Test-Path $gradlewBat) {
                    Pop-Location
                    @{ Passed = $true; Value = "Wrapper generated successfully" }
                }
                else {
                    Pop-Location
                    @{ Passed = $false; Value = "Wrapper files not created" }
                }
            }
            else {
                Pop-Location
                @{ Passed = $false; Value = "Wrapper generation failed" }
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
