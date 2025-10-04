#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies CMake build tool is properly configured.

.DESCRIPTION
    This script checks that CMake is installed and properly configured on the
    self-hosted runner. It validates the ability to create and build basic CMake projects.

    Checks include:
    - CMake installation and version
    - C/C++ compiler availability
    - CMake project generation and build
    - Build system support (Make/Ninja/MSBuild)

.PARAMETER ExitOnFailure
    Exit with code 1 if any checks fail (useful for CI/CD)

.PARAMETER JsonOutput
    Output results in JSON format

.PARAMETER MinimumVersion
    Minimum required CMake version (default: 3.15)

.EXAMPLE
    .\verify-cmake.ps1

.EXAMPLE
    .\verify-cmake.ps1 -ExitOnFailure

.EXAMPLE
    .\verify-cmake.ps1 -JsonOutput

.EXAMPLE
    .\verify-cmake.ps1 -MinimumVersion "3.20"

.NOTES
    Author: ActionRunner Team
    Version: 1.0.0
    Created for Issue #87: CMake verification tests
#>

[CmdletBinding()]
param(
    [switch]$ExitOnFailure,
    [switch]$JsonOutput,
    [string]$MinimumVersion = "3.15"
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
    Write-Host "`n=== CMake Build Tool Environment Verification ===" -ForegroundColor Cyan
    Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray
}

# Check 1: CMake installed
Test-Requirement `
    -Name "CMake Installation" `
    -Expected "Version $MinimumVersion or higher" `
    -FailureMessage "CMake not found or version below $MinimumVersion" `
    -Check {
        $cmakeVersion = cmake --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $cmakeVersion) {
            # Parse "cmake version 3.21.3" format
            if ($cmakeVersion -match 'cmake version ([\d.]+)') {
                $version = $matches[1]
                $installedVersion = [version]($version -split '-')[0]
                $minVersion = [version]$MinimumVersion
                @{ Passed = ($installedVersion -ge $minVersion); Value = "CMake $version" }
            }
            else {
                @{ Passed = $false; Value = "Unable to parse version" }
            }
        }
        else {
            @{ Passed = $false; Value = "Not installed" }
        }
    }

# Check 2: C++ compiler
Test-Requirement `
    -Name "C++ Compiler" `
    -Expected "C++ compiler available" `
    -FailureMessage "No C++ compiler found" `
    -Check {
        # Try different compilers
        $compilers = @(
            @{ Name = "MSVC"; Command = "cl"; Args = "" }
            @{ Name = "GCC"; Command = "g++"; Args = "--version" }
            @{ Name = "Clang"; Command = "clang++"; Args = "--version" }
        )

        foreach ($compiler in $compilers) {
            $null = & $compiler.Command $compiler.Args 2>&1
            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) {
                return @{ Passed = $true; Value = "$($compiler.Name) available" }
            }
        }
        @{ Passed = $false; Value = "No compiler found" }
    }

# Check 3: C compiler
Test-Requirement `
    -Name "C Compiler" `
    -Expected "C compiler available" `
    -FailureMessage "No C compiler found" `
    -Severity "Warning" `
    -Check {
        # Try different compilers
        $compilers = @(
            @{ Name = "MSVC"; Command = "cl"; Args = "" }
            @{ Name = "GCC"; Command = "gcc"; Args = "--version" }
            @{ Name = "Clang"; Command = "clang"; Args = "--version" }
        )

        foreach ($compiler in $compilers) {
            $null = & $compiler.Command $compiler.Args 2>&1
            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) {
                return @{ Passed = $true; Value = "$($compiler.Name) available" }
            }
        }
        @{ Passed = $false; Value = "No compiler found" }
    }

# Check 4: Build system support
Test-Requirement `
    -Name "Build System" `
    -Expected "Make, Ninja, or MSBuild available" `
    -FailureMessage "No build system found" `
    -Check {
        $buildSystems = @(
            @{ Name = "Ninja"; Command = "ninja"; Args = "--version" }
            @{ Name = "Make"; Command = "make"; Args = "--version" }
            @{ Name = "MSBuild"; Command = "msbuild"; Args = "/version" }
        )

        foreach ($buildSystem in $buildSystems) {
            $null = & $buildSystem.Command $buildSystem.Args 2>&1
            if ($LASTEXITCODE -eq 0) {
                return @{ Passed = $true; Value = "$($buildSystem.Name) available" }
            }
        }
        @{ Passed = $false; Value = "No build system found" }
    }

# Check 5: CMake generators
Test-Requirement `
    -Name "CMake Generators" `
    -Expected "CMake can list available generators" `
    -FailureMessage "Cannot query CMake generators" `
    -Severity "Warning" `
    -Check {
        $generators = cmake --help 2>&1 | Select-String "Generators" -Context 0,10
        if ($generators) {
            @{ Passed = $true; Value = "Generators available" }
        }
        else {
            @{ Passed = $false; Value = "Cannot list generators" }
        }
    }

# Check 6: Test CMake project configuration
Test-Requirement `
    -Name "CMake Project Configuration" `
    -Expected "Can configure a simple CMake project" `
    -FailureMessage "Unable to configure CMake project" `
    -Check {
        $testDir = Join-Path $env:TEMP "cmake-test-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            Push-Location $testDir

            # Create a minimal CMakeLists.txt
            $cmakeLists = @'
cmake_minimum_required(VERSION 3.10)
project(CMakeVerificationTest)

add_executable(test_app main.cpp)
'@
            Set-Content -Path (Join-Path $testDir "CMakeLists.txt") -Value $cmakeLists -Force

            # Create a simple C++ source file
            $cppSource = @'
#include <iostream>

int main() {
    std::cout << "Hello, CMake!" << std::endl;
    return 0;
}
'@
            Set-Content -Path (Join-Path $testDir "main.cpp") -Value $cppSource -Force

            # Create build directory
            $buildDir = Join-Path $testDir "build"
            New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

            # Configure the project
            Push-Location $buildDir
            $configOutput = cmake .. 2>&1
            Pop-Location

            if ($LASTEXITCODE -eq 0) {
                if (Test-Path (Join-Path $buildDir "CMakeCache.txt")) {
                    Pop-Location
                    @{ Passed = $true; Value = "Configuration successful" }
                }
                else {
                    Pop-Location
                    @{ Passed = $false; Value = "CMakeCache.txt not created" }
                }
            }
            else {
                Pop-Location
                @{ Passed = $false; Value = "Configuration failed" }
            }
        }
        finally {
            Pop-Location -ErrorAction SilentlyContinue
            if (Test-Path $testDir) {
                Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

# Check 7: Test CMake build
Test-Requirement `
    -Name "CMake Build Test" `
    -Expected "Can build a simple CMake project" `
    -FailureMessage "Unable to build CMake project" `
    -Check {
        $testDir = Join-Path $env:TEMP "cmake-build-test-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            Push-Location $testDir

            # Create a minimal CMakeLists.txt
            $cmakeLists = @'
cmake_minimum_required(VERSION 3.10)
project(CMakeBuildTest)

add_executable(hello main.cpp)
'@
            Set-Content -Path (Join-Path $testDir "CMakeLists.txt") -Value $cmakeLists -Force

            # Create a simple C++ source file
            $cppSource = @'
#include <iostream>

int main() {
    std::cout << "Build test!" << std::endl;
    return 0;
}
'@
            Set-Content -Path (Join-Path $testDir "main.cpp") -Value $cppSource -Force

            # Create build directory
            $buildDir = Join-Path $testDir "build"
            New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

            # Configure and build
            Push-Location $buildDir
            $configOutput = cmake .. 2>&1
            if ($LASTEXITCODE -ne 0) {
                Pop-Location
                Pop-Location
                return @{ Passed = $false; Value = "Configuration failed" }
            }

            $buildOutput = cmake --build . 2>&1
            Pop-Location

            if ($LASTEXITCODE -eq 0) {
                # Check for executable (extensions vary by platform)
                $exeFound = (Test-Path (Join-Path $buildDir "hello.exe")) -or `
                           (Test-Path (Join-Path $buildDir "hello")) -or `
                           (Test-Path (Join-Path $buildDir "Debug\hello.exe")) -or `
                           (Test-Path (Join-Path $buildDir "Release\hello.exe"))

                if ($exeFound) {
                    Pop-Location
                    @{ Passed = $true; Value = "Build successful" }
                }
                else {
                    Pop-Location
                    @{ Passed = $false; Value = "Executable not created" }
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

# Check 8: CMake with library
Test-Requirement `
    -Name "CMake Library Test" `
    -Expected "Can build project with library" `
    -FailureMessage "Unable to build CMake project with library" `
    -Check {
        $testDir = Join-Path $env:TEMP "cmake-lib-test-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            Push-Location $testDir

            # Create a minimal CMakeLists.txt with library
            $cmakeLists = @'
cmake_minimum_required(VERSION 3.10)
project(CMakeLibTest)

add_library(mylib STATIC mylib.cpp)
add_executable(app main.cpp)
target_link_libraries(app mylib)
'@
            Set-Content -Path (Join-Path $testDir "CMakeLists.txt") -Value $cmakeLists -Force

            # Create library source
            $libSource = @'
int add(int a, int b) {
    return a + b;
}
'@
            Set-Content -Path (Join-Path $testDir "mylib.cpp") -Value $libSource -Force

            # Create main source
            $mainSource = @'
int add(int a, int b);

int main() {
    return add(2, 3);
}
'@
            Set-Content -Path (Join-Path $testDir "main.cpp") -Value $mainSource -Force

            # Create build directory
            $buildDir = Join-Path $testDir "build"
            New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

            # Configure and build
            Push-Location $buildDir
            $configOutput = cmake .. 2>&1
            if ($LASTEXITCODE -ne 0) {
                Pop-Location
                Pop-Location
                return @{ Passed = $false; Value = "Configuration failed" }
            }

            $buildOutput = cmake --build . 2>&1
            Pop-Location

            if ($LASTEXITCODE -eq 0) {
                # Check for library file (extensions and locations vary)
                $libFound = (Test-Path (Join-Path $buildDir "libmylib.a")) -or `
                           (Test-Path (Join-Path $buildDir "mylib.lib")) -or `
                           (Test-Path (Join-Path $buildDir "Debug\mylib.lib")) -or `
                           (Test-Path (Join-Path $buildDir "Release\mylib.lib"))

                if ($libFound) {
                    Pop-Location
                    @{ Passed = $true; Value = "Library build successful" }
                }
                else {
                    Pop-Location
                    @{ Passed = $false; Value = "Library not created" }
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
