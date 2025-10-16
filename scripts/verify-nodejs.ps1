#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies Node.js and pnpm installation and functionality.

.DESCRIPTION
    This script verifies that Node.js and pnpm are properly installed and functional by checking:
    - Node.js command availability
    - Node.js version meets minimum requirements
    - npm command availability
    - pnpm command availability
    - pnpm version meets minimum requirements
    - Package installation capability
    - Project initialization capability
    - Script execution capability
    - Dependency resolution

.PARAMETER MinimumNodeVersion
    Minimum Node.js version required. Default is "16.0".

.PARAMETER MinimumPnpmVersion
    Minimum pnpm version required. Default is "8.0".

.PARAMETER ExitOnFailure
    Exit with code 1 if any check fails. Otherwise continues and reports all results.

.PARAMETER JsonOutput
    Output results in JSON format for integration with monitoring systems.

.EXAMPLE
    .\verify-nodejs.ps1
    Runs all Node.js and pnpm verification checks with default minimum versions

.EXAMPLE
    .\verify-nodejs.ps1 -MinimumNodeVersion "18.0" -MinimumPnpmVersion "8.6" -ExitOnFailure
    Runs checks requiring Node.js 18.0+ and pnpm 8.6+ and exits on first failure

.EXAMPLE
    .\verify-nodejs.ps1 -JsonOutput
    Outputs results in JSON format
#>

[CmdletBinding()]
param(
    [string]$MinimumNodeVersion = "16.0",
    [string]$MinimumPnpmVersion = "8.0",
    [switch]$ExitOnFailure,
    [switch]$JsonOutput
)

$ErrorActionPreference = 'Continue'

# Initialize results collection
$checks = @()
$passed = 0
$failed = 0
$warnings = 0

function Test-Requirement {
    param(
        [string]$Name,
        [scriptblock]$Check,
        [string]$Expected,
        [string]$FailureMessage,
        [string]$Severity = "Error"
    )

    try {
        $result = & $Check
        $checkPassed = $result.Success
        $actual = $result.Value

        if ($checkPassed) {
            $script:passed++
            if (-not $JsonOutput) {
                Write-Host "✅ $Name" -ForegroundColor Green
                if ($actual) {
                    Write-Host "   $actual" -ForegroundColor Gray
                }
            }
        } else {
            if ($Severity -eq "Warning") {
                $script:warnings++
                if (-not $JsonOutput) {
                    Write-Host "⚠️  $Name" -ForegroundColor Yellow
                    Write-Host "   $FailureMessage" -ForegroundColor Yellow
                }
            } else {
                $script:failed++
                if (-not $JsonOutput) {
                    Write-Host "❌ $Name" -ForegroundColor Red
                    Write-Host "   $FailureMessage" -ForegroundColor Red
                }
            }
        }

        $script:checks += @{
            name = $Name
            status = if ($checkPassed) { "passed" } elseif ($Severity -eq "Warning") { "warning" } else { "failed" }
            expected = $Expected
            actual = $actual
            message = if ($checkPassed) { "" } else { $FailureMessage }
            severity = $Severity
        }

        if (-not $checkPassed -and $ExitOnFailure -and $Severity -ne "Warning") {
            exit 1
        }
    }
    catch {
        $script:failed++
        if (-not $JsonOutput) {
            Write-Host "❌ $Name" -ForegroundColor Red
            Write-Host "   Error: $_" -ForegroundColor Red
        }

        $script:checks += @{
            name = $Name
            status = "failed"
            expected = $Expected
            actual = "Error: $_"
            message = $FailureMessage
            severity = $Severity
        }

        if ($ExitOnFailure) {
            exit 1
        }
    }
}

if (-not $JsonOutput) {
    Write-Host "`n=== Node.js/pnpm Verification ===" -ForegroundColor Cyan
    Write-Host "Checking Node.js and pnpm installation and functionality...`n" -ForegroundColor Cyan
}

# Check 1: Node.js command availability
Test-Requirement -Name "Node.js Command Available" -Expected "node command found in PATH" -FailureMessage "Node.js is not installed or not in PATH. Install Node.js from https://nodejs.org/" -Check {
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        return @{ Success = $true; Value = "Found: $($nodeCmd.Source)" }
    }
    return @{ Success = $false; Value = "Not found" }
}

# Check 2: Node.js version
Test-Requirement -Name "Node.js Version" -Expected "node >= $MinimumNodeVersion" -FailureMessage "Node.js version is below minimum required version $MinimumNodeVersion" -Check {
    $versionOutput = node --version 2>&1 | Out-String
    if ($versionOutput -match 'v?([\d.]+)') {
        $version = $matches[1]
        $current = [version]($version -replace '^(\d+\.\d+).*', '$1')
        $minimum = [version]$MinimumNodeVersion

        if ($current -ge $minimum) {
            return @{ Success = $true; Value = "Node.js v$version" }
        }
        return @{ Success = $false; Value = "Node.js v$version (minimum: $MinimumNodeVersion)" }
    }
    return @{ Success = $false; Value = "Unable to determine Node.js version" }
}

# Check 3: npm command availability
Test-Requirement -Name "npm Command Available" -Expected "npm command found in PATH" -FailureMessage "npm is not installed or not in PATH" -Check {
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if ($npmCmd) {
        $npmVersion = npm --version 2>&1 | Out-String
        return @{ Success = $true; Value = "npm v$($npmVersion.Trim())" }
    }
    return @{ Success = $false; Value = "Not found" }
}

# Check 4: pnpm command availability
Test-Requirement -Name "pnpm Command Available" -Expected "pnpm command found in PATH" -FailureMessage "pnpm is not installed. Install with: npm install -g pnpm" -Check {
    $pnpmCmd = Get-Command pnpm -ErrorAction SilentlyContinue
    if ($pnpmCmd) {
        return @{ Success = $true; Value = "Found: $($pnpmCmd.Source)" }
    }
    return @{ Success = $false; Value = "Not found" }
}

# Check 5: pnpm version
Test-Requirement -Name "pnpm Version" -Expected "pnpm >= $MinimumPnpmVersion" -FailureMessage "pnpm version is below minimum required version $MinimumPnpmVersion" -Check {
    $versionOutput = pnpm --version 2>&1 | Out-String
    if ($versionOutput -match '([\d.]+)') {
        $version = $matches[1]
        $current = [version]($version -replace '^(\d+\.\d+).*', '$1')
        $minimum = [version]$MinimumPnpmVersion

        if ($current -ge $minimum) {
            return @{ Success = $true; Value = "pnpm v$version" }
        }
        return @{ Success = $false; Value = "pnpm v$version (minimum: $MinimumPnpmVersion)" }
    }
    return @{ Success = $false; Value = "Unable to determine pnpm version" }
}

# Check 6: Node.js execution test
Test-Requirement -Name "Node.js Execution" -Expected "Can execute JavaScript code" -FailureMessage "Cannot execute JavaScript code with Node.js" -Check {
    $testOutput = node -e "console.log('test')" 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and $testOutput -match "test") {
        return @{ Success = $true; Value = "JavaScript execution works" }
    }
    return @{ Success = $false; Value = "Execution test failed" }
}

# Check 7: pnpm store configuration
Test-Requirement -Name "pnpm Store Path" -Expected "pnpm store is configured" -FailureMessage "pnpm store configuration issue" -Severity "Warning" -Check {
    $storeOutput = pnpm store path 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and $storeOutput.Trim()) {
        return @{ Success = $true; Value = "Store: $($storeOutput.Trim())" }
    }
    return @{ Success = $false; Value = "Store path not configured" }
}

# Check 8: Project initialization test
Test-Requirement -Name "pnpm Init Capability" -Expected "Can initialize new projects" -FailureMessage "Cannot initialize projects with pnpm" -Check {
    $testDir = Join-Path $env:TEMP "pnpm_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        Push-Location $testDir
        $initOutput = pnpm init -y 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $testDir "package.json"))) {
            return @{ Success = $true; Value = "Project initialization works" }
        }
        return @{ Success = $false; Value = "Init failed" }
    }
    finally {
        Pop-Location
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 9: Package installation test
Test-Requirement -Name "pnpm Install Capability" -Expected "Can install packages" -FailureMessage "Cannot install packages with pnpm" -Check {
    $testDir = Join-Path $env:TEMP "pnpm_install_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        Push-Location $testDir

        # Create a minimal package.json
        $packageJson = @{
            name = "test-project"
            version = "1.0.0"
            dependencies = @{
                lodash = "^4.17.21"
            }
        } | ConvertTo-Json
        $packageJson | Out-File -FilePath "package.json" -Encoding utf8

        # Try to install
        $installOutput = pnpm install 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -and (Test-Path "node_modules")) {
            return @{ Success = $true; Value = "Package installation works" }
        }
        return @{ Success = $false; Value = "Install failed: $installOutput" }
    }
    finally {
        Pop-Location
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 10: pnpm list capability
Test-Requirement -Name "pnpm List Packages" -Expected "Can list installed packages" -FailureMessage "Cannot list packages" -Severity "Warning" -Check {
    $testDir = Join-Path $env:TEMP "pnpm_list_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        Push-Location $testDir
        pnpm init -y 2>&1 | Out-Null
        $listOutput = pnpm list --depth=0 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            return @{ Success = $true; Value = "List command works" }
        }
        return @{ Success = $false; Value = "List command failed" }
    }
    finally {
        Pop-Location
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 11: pnpm run scripts
Test-Requirement -Name "pnpm Run Scripts" -Expected "Can execute package scripts" -FailureMessage "Cannot execute scripts with pnpm run" -Check {
    $testDir = Join-Path $env:TEMP "pnpm_run_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        Push-Location $testDir

        # Create package.json with a test script
        $packageJson = @{
            name = "test-project"
            version = "1.0.0"
            scripts = @{
                test = "node -e `"console.log('script-works')`""
            }
        } | ConvertTo-Json
        $packageJson | Out-File -FilePath "package.json" -Encoding utf8

        $runOutput = pnpm run test 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -and $runOutput -match "script-works") {
            return @{ Success = $true; Value = "Script execution works" }
        }
        return @{ Success = $false; Value = "Script execution failed" }
    }
    finally {
        Pop-Location
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 12: pnpm workspace support
Test-Requirement -Name "pnpm Workspace Support" -Expected "Workspace feature available" -FailureMessage "Workspace support not available" -Severity "Warning" -Check {
    $testDir = Join-Path $env:TEMP "pnpm_workspace_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        Push-Location $testDir

        # Create pnpm-workspace.yaml
        "packages:`n  - 'packages/*'" | Out-File -FilePath "pnpm-workspace.yaml" -Encoding utf8

        # Check if pnpm recognizes workspace
        $workspaceOutput = pnpm list --depth=-1 2>&1 | Out-String
        if ($workspaceOutput -notmatch "error") {
            return @{ Success = $true; Value = "Workspace support available" }
        }
        return @{ Success = $false; Value = "Workspace not recognized" }
    }
    finally {
        Pop-Location
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Output results
if ($JsonOutput) {
    $output = @{
        timestamp = Get-Date -Format "o"
        tool = "nodejs-pnpm"
        minimumNodeVersion = $MinimumNodeVersion
        minimumPnpmVersion = $MinimumPnpmVersion
        passed = $passed
        failed = $failed
        warnings = $warnings
        total = $checks.Count
        checks = $checks
    }
    $output | ConvertTo-Json -Depth 10
} else {
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Passed:   $passed" -ForegroundColor Green
    Write-Host "Failed:   $failed" -ForegroundColor Red
    Write-Host "Warnings: $warnings" -ForegroundColor Yellow
    Write-Host "Total:    $($checks.Count)`n" -ForegroundColor Cyan

    if ($failed -eq 0) {
        Write-Host "✅ All critical Node.js/pnpm checks passed!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "❌ Some critical checks failed. Please review the issues above." -ForegroundColor Red
        exit 1
    }
}
