#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies Rust development environment is properly configured.

.DESCRIPTION
    This script checks that Rust toolchain is installed and properly
    configured on the self-hosted runner. It validates the ability to create and
    build basic Rust applications.

    Checks include:
    - Rust compiler (rustc) version
    - Cargo package manager
    - Rust toolchain configuration
    - Basic Rust project creation and build

.PARAMETER ExitOnFailure
    Exit with code 1 if any checks fail (useful for CI/CD)

.PARAMETER JsonOutput
    Output results in JSON format

.PARAMETER MinimumVersion
    Minimum required Rust version (default: 1.70)

.EXAMPLE
    .\verify-rust.ps1

.EXAMPLE
    .\verify-rust.ps1 -ExitOnFailure

.EXAMPLE
    .\verify-rust.ps1 -JsonOutput

.EXAMPLE
    .\verify-rust.ps1 -MinimumVersion "1.75"

.NOTES
    Author: ActionRunner Team
    Version: 1.0.0
    Created for Issue #90: Rust toolchain verification
#>

[CmdletBinding()]
param(
    [switch]$ExitOnFailure,
    [switch]$JsonOutput,
    [string]$MinimumVersion = "1.70"
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
    Write-Host "`n=== Rust Toolchain Environment Verification ===" -ForegroundColor Cyan
    Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray
}

# Check 1: Rust compiler installed
Test-Requirement `
    -Name "Rust Compiler" `
    -Expected "Version $MinimumVersion or higher" `
    -FailureMessage "Rust compiler not found or version below $MinimumVersion" `
    -Check {
        $rustcVersion = rustc --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $rustcVersion) {
            # Parse "rustc 1.75.0 (82e1608df 2023-12-21)" format
            if ($rustcVersion -match 'rustc ([\d.]+)') {
                $version = $matches[1]
                $installedVersion = [version]($version -split '-')[0]
                $minVersion = [version]$MinimumVersion
                @{ Passed = ($installedVersion -ge $minVersion); Value = "rustc $version" }
            }
            else {
                @{ Passed = $false; Value = "Unable to parse version" }
            }
        }
        else {
            @{ Passed = $false; Value = "Not installed" }
        }
    }

# Check 2: Cargo package manager
Test-Requirement `
    -Name "Cargo Package Manager" `
    -Expected "Cargo installed and functional" `
    -FailureMessage "Cargo not found or not working" `
    -Check {
        $cargoVersion = cargo --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $cargoVersion) {
            # Parse "cargo 1.75.0 (1d8b05cdd 2023-11-20)" format
            if ($cargoVersion -match 'cargo ([\d.]+)') {
                $version = $matches[1]
                @{ Passed = $true; Value = "cargo $version" }
            }
            else {
                @{ Passed = $false; Value = "Unable to parse version" }
            }
        }
        else {
            @{ Passed = $false; Value = "Not installed" }
        }
    }

# Check 3: Rustup toolchain manager
Test-Requirement `
    -Name "Rustup Toolchain Manager" `
    -Expected "Rustup installed" `
    -FailureMessage "Rustup not installed" `
    -Severity "Warning" `
    -Check {
        $rustupVersion = rustup --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $rustupVersion) {
            if ($rustupVersion -match 'rustup ([\d.]+)') {
                $version = $matches[1]
                @{ Passed = $true; Value = "rustup $version" }
            }
            else {
                @{ Passed = $false; Value = "Unable to parse version" }
            }
        }
        else {
            @{ Passed = $false; Value = "Not installed" }
        }
    }

# Check 4: Active toolchain
Test-Requirement `
    -Name "Active Toolchain" `
    -Expected "Default toolchain configured" `
    -FailureMessage "No default toolchain configured" `
    -Severity "Warning" `
    -Check {
        $toolchain = rustup show active-toolchain 2>&1
        if ($LASTEXITCODE -eq 0 -and $toolchain) {
            @{ Passed = $true; Value = $toolchain.Trim() }
        }
        else {
            @{ Passed = $false; Value = "Not configured" }
        }
    }

# Check 5: Test Rust build with a simple program
Test-Requirement `
    -Name "Rust Build Test" `
    -Expected "Can create and build a simple Rust program" `
    -FailureMessage "Unable to create or build Rust program" `
    -Check {
        $testDir = Join-Path $env:TEMP "rust-test-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null

            # Create a simple main.rs
            $mainRs = @'
fn main() {
    println!("Hello, Rust!");
}
'@
            $mainRsPath = Join-Path $testDir "main.rs"
            Set-Content -Path $mainRsPath -Value $mainRs -Force

            # Compile the program
            Push-Location $testDir
            $buildOutput = rustc main.rs 2>&1
            if ($LASTEXITCODE -eq 0) {
                $exePath = Join-Path $testDir "main.exe"
                if (Test-Path $exePath) {
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

# Check 6: Cargo project creation and build
Test-Requirement `
    -Name "Cargo Project Test" `
    -Expected "Can create and build a Cargo project" `
    -FailureMessage "Unable to create or build Cargo project" `
    -Check {
        $testDir = Join-Path $env:TEMP "cargo-test-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            Push-Location $testDir

            # Create new cargo project
            $cargoNew = cargo new testapp --bin 2>&1
            if ($LASTEXITCODE -ne 0) {
                Pop-Location
                return @{ Passed = $false; Value = "Project creation failed" }
            }

            # Build the project
            $projectDir = Join-Path $testDir "testapp"
            Push-Location $projectDir
            $cargoBuild = cargo build 2>&1
            Pop-Location
            Pop-Location

            if ($LASTEXITCODE -eq 0) {
                $exePath = Join-Path $projectDir "target\debug\testapp.exe"
                if (Test-Path $exePath) {
                    @{ Passed = $true; Value = "Build successful" }
                }
                else {
                    @{ Passed = $false; Value = "Executable not created" }
                }
            }
            else {
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

# Check 7: Cargo test command
Test-Requirement `
    -Name "Cargo Test Command" `
    -Expected "cargo test command available" `
    -FailureMessage "cargo test command not working" `
    -Check {
        $testDir = Join-Path $env:TEMP "cargo-test-cmd-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            Push-Location $testDir

            # Create new cargo project
            $cargoNew = cargo new testapp --bin 2>&1
            if ($LASTEXITCODE -ne 0) {
                Pop-Location
                return @{ Passed = $false; Value = "Project creation failed" }
            }

            # Run tests
            $projectDir = Join-Path $testDir "testapp"
            Push-Location $projectDir
            $cargoTest = cargo test 2>&1
            Pop-Location
            Pop-Location

            if ($LASTEXITCODE -eq 0) {
                @{ Passed = $true; Value = "Tests passed" }
            }
            else {
                @{ Passed = $false; Value = "Tests failed" }
            }
        }
        finally {
            Pop-Location -ErrorAction SilentlyContinue
            if (Test-Path $testDir) {
                Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

# Check 8: Rustfmt code formatter
Test-Requirement `
    -Name "Rustfmt Code Formatter" `
    -Expected "rustfmt command available" `
    -FailureMessage "rustfmt command not working" `
    -Severity "Warning" `
    -Check {
        $rustfmt = rustfmt --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $rustfmt) {
            @{ Passed = $true; Value = $rustfmt.Trim() }
        }
        else {
            @{ Passed = $false; Value = "Not available" }
        }
    }

# Check 9: Clippy linter
Test-Requirement `
    -Name "Clippy Linter" `
    -Expected "clippy command available" `
    -FailureMessage "clippy command not working" `
    -Severity "Warning" `
    -Check {
        $clippy = cargo clippy --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $clippy) {
            @{ Passed = $true; Value = $clippy.Trim() }
        }
        else {
            @{ Passed = $false; Value = "Not available" }
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
