#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies Go development environment is properly configured.

.DESCRIPTION
    This script checks that Go toolchain is installed and properly
    configured on the self-hosted runner. It validates the ability to create and
    build basic Go applications.

    Checks include:
    - Go compiler version
    - GOPATH and GOROOT configuration
    - Go module support
    - Basic Go project creation and build

.PARAMETER ExitOnFailure
    Exit with code 1 if any checks fail (useful for CI/CD)

.PARAMETER JsonOutput
    Output results in JSON format

.PARAMETER MinimumVersion
    Minimum required Go version (default: 1.18)

.EXAMPLE
    .\verify-go.ps1

.EXAMPLE
    .\verify-go.ps1 -ExitOnFailure

.EXAMPLE
    .\verify-go.ps1 -JsonOutput

.EXAMPLE
    .\verify-go.ps1 -MinimumVersion "1.20"

.NOTES
    Author: ActionRunner Team
    Version: 1.0.0
    Created for Issue #91: Go toolchain verification
#>

[CmdletBinding()]
param(
    [switch]$ExitOnFailure,
    [switch]$JsonOutput,
    [string]$MinimumVersion = "1.20"
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
    Write-Host "`n=== Go Toolchain Environment Verification ===" -ForegroundColor Cyan
    Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray
}

# Check 1: Go compiler installed
Test-Requirement `
    -Name "Go Compiler" `
    -Expected "Version $MinimumVersion or higher" `
    -FailureMessage "Go compiler not found or version below $MinimumVersion" `
    -Check {
        $goVersion = go version 2>&1
        if ($LASTEXITCODE -eq 0 -and $goVersion) {
            # Parse "go version go1.21.0 windows/amd64" format
            if ($goVersion -match 'go version go([\d.]+)') {
                $version = $matches[1]
                $installedVersion = [version]($version -split '-')[0]
                $minVersion = [version]$MinimumVersion
                @{ Passed = ($installedVersion -ge $minVersion); Value = "go$version" }
            }
            else {
                @{ Passed = $false; Value = "Unable to parse version" }
            }
        }
        else {
            @{ Passed = $false; Value = "Not installed" }
        }
    }

# Check 2: GOROOT environment variable
Test-Requirement `
    -Name "GOROOT Configuration" `
    -Expected "GOROOT set and points to valid directory" `
    -FailureMessage "GOROOT not set or invalid" `
    -Severity "Warning" `
    -Check {
        $goroot = go env GOROOT 2>&1
        if ($LASTEXITCODE -eq 0 -and $goroot -and (Test-Path $goroot)) {
            @{ Passed = $true; Value = $goroot.Trim() }
        }
        else {
            @{ Passed = $false; Value = "Not configured or invalid" }
        }
    }

# Check 3: GOPATH environment variable
Test-Requirement `
    -Name "GOPATH Configuration" `
    -Expected "GOPATH set and points to valid directory" `
    -FailureMessage "GOPATH not set or invalid" `
    -Severity "Warning" `
    -Check {
        $gopath = go env GOPATH 2>&1
        if ($LASTEXITCODE -eq 0 -and $gopath) {
            # GOPATH may not exist yet, which is fine
            @{ Passed = $true; Value = $gopath.Trim() }
        }
        else {
            @{ Passed = $false; Value = "Not configured" }
        }
    }

# Check 4: Go modules support
Test-Requirement `
    -Name "Go Modules Support" `
    -Expected "Go modules enabled (GO111MODULE)" `
    -FailureMessage "Go modules not enabled" `
    -Severity "Warning" `
    -Check {
        $gomod = go env GO111MODULE 2>&1
        if ($LASTEXITCODE -eq 0) {
            $value = if ($gomod) { $gomod.Trim() } else { "on (default)" }
            @{ Passed = $true; Value = $value }
        }
        else {
            @{ Passed = $false; Value = "Not available" }
        }
    }

# Check 5: Go build test
Test-Requirement `
    -Name "Go Build Test" `
    -Expected "Can create and build a simple Go program" `
    -FailureMessage "Unable to create or build Go program" `
    -Check {
        $testDir = Join-Path $env:TEMP "go-test-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null

            # Create a simple main.go
            $mainGo = @'
package main

import "fmt"

func main() {
    fmt.Println("Hello, Go!")
}
'@
            $mainGoPath = Join-Path $testDir "main.go"
            Set-Content -Path $mainGoPath -Value $mainGo -Force

            # Build the program
            Push-Location $testDir
            $buildOutput = go build -o testapp.exe main.go 2>&1
            if ($LASTEXITCODE -eq 0) {
                $exePath = Join-Path $testDir "testapp.exe"
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

# Check 6: Go module project creation and build
Test-Requirement `
    -Name "Go Module Project Test" `
    -Expected "Can create and build a Go module project" `
    -FailureMessage "Unable to create or build Go module project" `
    -Check {
        $testDir = Join-Path $env:TEMP "go-mod-test-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            Push-Location $testDir

            # Initialize go module
            $goModInit = go mod init testapp 2>&1
            if ($LASTEXITCODE -ne 0) {
                Pop-Location
                return @{ Passed = $false; Value = "Module initialization failed" }
            }

            # Create a main.go
            $mainGo = @'
package main

import "fmt"

func main() {
    fmt.Println("Hello, Go Modules!")
}
'@
            $mainGoPath = Join-Path $testDir "main.go"
            Set-Content -Path $mainGoPath -Value $mainGo -Force

            # Build the project
            $goBuild = go build -o testapp.exe 2>&1
            Pop-Location

            if ($LASTEXITCODE -eq 0) {
                $exePath = Join-Path $testDir "testapp.exe"
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

# Check 7: Go test command
Test-Requirement `
    -Name "Go Test Command" `
    -Expected "go test command available" `
    -FailureMessage "go test command not working" `
    -Check {
        $testDir = Join-Path $env:TEMP "go-test-cmd-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            Push-Location $testDir

            # Initialize go module
            $goModInit = go mod init testapp 2>&1
            if ($LASTEXITCODE -ne 0) {
                Pop-Location
                return @{ Passed = $false; Value = "Module initialization failed" }
            }

            # Create a simple test file
            $testGo = @'
package main

import "testing"

func TestExample(t *testing.T) {
    if 2+2 != 4 {
        t.Error("Math is broken")
    }
}
'@
            $testGoPath = Join-Path $testDir "main_test.go"
            Set-Content -Path $testGoPath -Value $testGo -Force

            # Run tests
            $goTest = go test 2>&1
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

# Check 8: gofmt code formatter
Test-Requirement `
    -Name "Gofmt Code Formatter" `
    -Expected "gofmt command available" `
    -FailureMessage "gofmt command not working" `
    -Severity "Warning" `
    -Check {
        $gofmt = gofmt -h 2>&1
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 2) {
            # gofmt -h returns exit code 2, but that's expected
            @{ Passed = $true; Value = "Available" }
        }
        else {
            @{ Passed = $false; Value = "Not available" }
        }
    }

# Check 9: go vet command
Test-Requirement `
    -Name "Go Vet Command" `
    -Expected "go vet command available" `
    -FailureMessage "go vet command not working" `
    -Severity "Warning" `
    -Check {
        $testDir = Join-Path $env:TEMP "go-vet-test-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            Push-Location $testDir

            # Initialize go module
            $goModInit = go mod init testapp 2>&1
            if ($LASTEXITCODE -ne 0) {
                Pop-Location
                return @{ Passed = $false; Value = "Module initialization failed" }
            }

            # Create a simple file
            $mainGo = @'
package main

func main() {}
'@
            $mainGoPath = Join-Path $testDir "main.go"
            Set-Content -Path $mainGoPath -Value $mainGo -Force

            # Run go vet
            $goVet = go vet 2>&1
            Pop-Location

            if ($LASTEXITCODE -eq 0) {
                @{ Passed = $true; Value = "Available" }
            }
            else {
                @{ Passed = $false; Value = "Not available" }
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
