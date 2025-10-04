#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies Maven build tool is properly configured.

.DESCRIPTION
    This script checks that Maven is installed and properly configured on the
    self-hosted runner. It validates the ability to create and build basic Maven projects.

    Checks include:
    - Maven installation and version
    - Java runtime (required for Maven)
    - Maven repository configuration
    - Basic Maven project creation and build

.PARAMETER ExitOnFailure
    Exit with code 1 if any checks fail (useful for CI/CD)

.PARAMETER JsonOutput
    Output results in JSON format

.PARAMETER MinimumVersion
    Minimum required Maven version (default: 3.6)

.EXAMPLE
    .\verify-maven.ps1

.EXAMPLE
    .\verify-maven.ps1 -ExitOnFailure

.EXAMPLE
    .\verify-maven.ps1 -JsonOutput

.EXAMPLE
    .\verify-maven.ps1 -MinimumVersion "3.8"

.NOTES
    Author: ActionRunner Team
    Version: 1.0.0
    Created for Issue #89: Maven verification tests
#>

[CmdletBinding()]
param(
    [switch]$ExitOnFailure,
    [switch]$JsonOutput,
    [string]$MinimumVersion = "3.6"
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
    Write-Host "`n=== Maven Build Tool Environment Verification ===" -ForegroundColor Cyan
    Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray
}

# Check 1: Maven installed
Test-Requirement `
    -Name "Maven Installation" `
    -Expected "Version $MinimumVersion or higher" `
    -FailureMessage "Maven not found or version below $MinimumVersion" `
    -Check {
        $mvnVersion = mvn -version 2>&1
        if ($LASTEXITCODE -eq 0 -and $mvnVersion) {
            # Parse "Apache Maven 3.8.6" format
            if ($mvnVersion -match 'Apache Maven ([\d.]+)') {
                $version = $matches[1]
                $installedVersion = [version]($version -split '-')[0]
                $minVersion = [version]$MinimumVersion
                @{ Passed = ($installedVersion -ge $minVersion); Value = "Maven $version" }
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
    -Expected "Java installed (required for Maven)" `
    -FailureMessage "Java not found - Maven requires Java" `
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

# Check 4: Maven home
Test-Requirement `
    -Name "Maven Home" `
    -Expected "M2_HOME or MAVEN_HOME set" `
    -FailureMessage "Maven home directory not configured" `
    -Severity "Warning" `
    -Check {
        $mavenHome = if ($env:M2_HOME) { $env:M2_HOME } else { $env:MAVEN_HOME }
        if ($mavenHome) {
            @{ Passed = $true; Value = $mavenHome }
        }
        else {
            @{ Passed = $false; Value = "Not set" }
        }
    }

# Check 5: Maven local repository
Test-Requirement `
    -Name "Maven Local Repository" `
    -Expected "Local repository directory exists" `
    -FailureMessage "Maven local repository not found" `
    -Severity "Warning" `
    -Check {
        $m2Repo = Join-Path $env:USERPROFILE ".m2\repository"
        if (Test-Path $m2Repo) {
            @{ Passed = $true; Value = $m2Repo }
        }
        else {
            @{ Passed = $false; Value = "Not initialized" }
        }
    }

# Check 6: Maven settings file
Test-Requirement `
    -Name "Maven Settings" `
    -Expected "settings.xml exists" `
    -FailureMessage "Maven settings.xml not found" `
    -Severity "Warning" `
    -Check {
        $settingsFile = Join-Path $env:USERPROFILE ".m2\settings.xml"
        if (Test-Path $settingsFile) {
            @{ Passed = $true; Value = "Custom settings found" }
        }
        else {
            @{ Passed = $false; Value = "Using defaults" }
        }
    }

# Check 7: Test Maven build with a simple project
Test-Requirement `
    -Name "Maven Build Test" `
    -Expected "Can create and build a simple Maven project" `
    -FailureMessage "Unable to create or build Maven project" `
    -Check {
        $testDir = Join-Path $env:TEMP "maven-test-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            Push-Location $testDir

            # Create a minimal pom.xml
            $pomXml = @'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.test</groupId>
    <artifactId>maven-verification-test</artifactId>
    <version>1.0-SNAPSHOT</version>
    <packaging>jar</packaging>

    <properties>
        <maven.compiler.source>1.8</maven.compiler.source>
        <maven.compiler.target>1.8</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>
</project>
'@
            Set-Content -Path (Join-Path $testDir "pom.xml") -Value $pomXml -Force

            # Create source directory
            $srcDir = Join-Path $testDir "src\main\java\com\test"
            New-Item -ItemType Directory -Path $srcDir -Force | Out-Null

            # Create a simple Java class
            $javaClass = @'
package com.test;

public class App {
    public static void main(String[] args) {
        System.out.println("Hello, Maven!");
    }
}
'@
            Set-Content -Path (Join-Path $srcDir "App.java") -Value $javaClass -Force

            # Validate the project
            $validateOutput = mvn validate 2>&1
            if ($LASTEXITCODE -ne 0) {
                Pop-Location
                return @{ Passed = $false; Value = "Project validation failed" }
            }

            # Compile the project
            $compileOutput = mvn compile 2>&1
            if ($LASTEXITCODE -eq 0) {
                $targetDir = Join-Path $testDir "target\classes\com\test"
                if (Test-Path (Join-Path $targetDir "App.class")) {
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
                @{ Passed = $false; Value = "Compilation failed" }
            }
        }
        finally {
            Pop-Location -ErrorAction SilentlyContinue
            if (Test-Path $testDir) {
                Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

# Check 8: Maven package goal
Test-Requirement `
    -Name "Maven Package Test" `
    -Expected "Can package a Maven project" `
    -FailureMessage "Unable to package Maven project" `
    -Check {
        $testDir = Join-Path $env:TEMP "maven-package-test-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            Push-Location $testDir

            # Create a minimal pom.xml
            $pomXml = @'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.test</groupId>
    <artifactId>maven-package-test</artifactId>
    <version>1.0-SNAPSHOT</version>
    <packaging>jar</packaging>

    <properties>
        <maven.compiler.source>1.8</maven.compiler.source>
        <maven.compiler.target>1.8</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>
</project>
'@
            Set-Content -Path (Join-Path $testDir "pom.xml") -Value $pomXml -Force

            # Create source directory
            $srcDir = Join-Path $testDir "src\main\java\com\test"
            New-Item -ItemType Directory -Path $srcDir -Force | Out-Null

            # Create a simple Java class
            $javaClass = @'
package com.test;

public class App {
    public static String getMessage() {
        return "Hello";
    }
}
'@
            Set-Content -Path (Join-Path $srcDir "App.java") -Value $javaClass -Force

            # Package the project (skip tests)
            $packageOutput = mvn package -DskipTests 2>&1
            if ($LASTEXITCODE -eq 0) {
                $jarFile = Join-Path $testDir "target\maven-package-test-1.0-SNAPSHOT.jar"
                if (Test-Path $jarFile) {
                    Pop-Location
                    @{ Passed = $true; Value = "JAR created successfully" }
                }
                else {
                    Pop-Location
                    @{ Passed = $false; Value = "JAR file not created" }
                }
            }
            else {
                Pop-Location
                @{ Passed = $false; Value = "Package failed" }
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
