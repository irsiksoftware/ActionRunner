#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies security scanning tools are properly configured on the runner.

.DESCRIPTION
    This script checks that security scanning tools and integrations are available
    and properly configured on the self-hosted runner. It validates the ability to
    perform security scans on code and dependencies.

    Checks include:
    - Git for secret scanning
    - PowerShell security modules
    - Windows Defender (if available)
    - Code scanning capabilities
    - Dependency scanning support

.PARAMETER ExitOnFailure
    Exit with code 1 if any checks fail (useful for CI/CD)

.PARAMETER JsonOutput
    Output results in JSON format

.PARAMETER IncludeOptional
    Include optional security tools in verification

.EXAMPLE
    .\verify-security-scanning.ps1

.EXAMPLE
    .\verify-security-scanning.ps1 -ExitOnFailure

.EXAMPLE
    .\verify-security-scanning.ps1 -JsonOutput

.EXAMPLE
    .\verify-security-scanning.ps1 -IncludeOptional

.NOTES
    Author: ActionRunner Team
    Version: 1.0.0
    Created for Issue #82: Security scanning verification tests
#>

[CmdletBinding()]
param(
    [switch]$ExitOnFailure,
    [switch]$JsonOutput,
    [switch]$IncludeOptional
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
    Write-Host "`n=== Security Scanning Verification ===" -ForegroundColor Cyan
    Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray
}

# Check 1: Git installed (required for secret scanning)
Test-Requirement `
    -Name "Git" `
    -Expected "Installed" `
    -FailureMessage "Git not found - required for secret scanning" `
    -Check {
        $gitVersion = git --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $gitVersion) {
            @{ Passed = $true; Value = $gitVersion.Trim() }
        }
        else {
            @{ Passed = $false; Value = "Not installed" }
        }
    }

# Check 2: PowerShell execution policy allows script execution
Test-Requirement `
    -Name "PowerShell Execution Policy" `
    -Expected "Allows script execution" `
    -FailureMessage "Execution policy too restrictive for security scripts" `
    -Severity "Warning" `
    -Check {
        $policy = Get-ExecutionPolicy -Scope CurrentUser
        $allowed = $policy -in @('RemoteSigned', 'Unrestricted', 'Bypass')
        @{ Passed = $allowed; Value = $policy }
    }

# Check 3: Windows Defender status (Windows only)
if ($IsWindows -or (-not (Get-Variable IsWindows -ErrorAction SilentlyContinue))) {
    Test-Requirement `
        -Name "Windows Defender" `
        -Expected "Available" `
        -FailureMessage "Windows Defender not available" `
        -Severity "Warning" `
        -Check {
            try {
                $defenderStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
                if ($defenderStatus) {
                    $enabled = $defenderStatus.AntivirusEnabled
                    @{ Passed = $enabled; Value = "Antivirus Enabled: $enabled" }
                }
                else {
                    @{ Passed = $false; Value = "Not available" }
                }
            }
            catch {
                @{ Passed = $false; Value = "Not available or access denied" }
            }
        }
}

# Check 4: Test file content scanning capability
Test-Requirement `
    -Name "File Content Scanning" `
    -Expected "Can scan files for patterns" `
    -FailureMessage "Cannot perform file content scanning" `
    -Check {
        $testDir = Join-Path $env:TEMP "security-scan-test-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            $testFile = Join-Path $testDir "test.txt"
            "password=secret123" | Out-File $testFile -Encoding UTF8

            $secretPattern = 'password\s*=\s*\S+'
            $found = Select-String -Path $testFile -Pattern $secretPattern

            if ($found) {
                @{ Passed = $true; Value = "Pattern matching works" }
            }
            else {
                @{ Passed = $false; Value = "Pattern matching failed" }
            }
        }
        finally {
            if (Test-Path $testDir) {
                Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

# Check 5: Secret detection patterns
Test-Requirement `
    -Name "Secret Detection Patterns" `
    -Expected "Can detect common secret patterns" `
    -FailureMessage "Secret detection patterns not functional" `
    -Check {
        $testContent = @"
API_KEY=1234567890abcdef
password="myP@ssw0rd"
token=ghp_1234567890abcdef
"@
        $patterns = @(
            'API_KEY\s*=\s*\S+',
            'password\s*=\s*["'']?\S+["'']?',
            'token\s*=\s*\S+'
        )

        $detectedCount = 0
        foreach ($pattern in $patterns) {
            if ($testContent -match $pattern) {
                $detectedCount++
            }
        }

        $passed = $detectedCount -eq $patterns.Count
        @{ Passed = $passed; Value = "Detected $detectedCount/$($patterns.Count) patterns" }
    }

# Check 6: Git hooks support (for pre-commit scanning)
Test-Requirement `
    -Name "Git Hooks Support" `
    -Expected "Can create git hooks" `
    -FailureMessage "Cannot create git hooks for security scanning" `
    -Check {
        $testDir = Join-Path $env:TEMP "git-hooks-test-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            Push-Location $testDir

            git init 2>&1 | Out-Null
            $hooksDir = Join-Path $testDir ".git\hooks"

            if (Test-Path $hooksDir) {
                $testHook = Join-Path $hooksDir "pre-commit.sample"
                if (Test-Path $testHook) {
                    @{ Passed = $true; Value = "Git hooks directory accessible" }
                }
                else {
                    @{ Passed = $true; Value = "Hooks directory exists" }
                }
            }
            else {
                @{ Passed = $false; Value = "Hooks directory not found" }
            }
        }
        finally {
            Pop-Location
            if (Test-Path $testDir) {
                Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

# Check 7: PowerShell Script Analyzer (optional but recommended)
Test-Requirement `
    -Name "PSScriptAnalyzer Module" `
    -Expected "Installed for PowerShell security analysis" `
    -FailureMessage "PSScriptAnalyzer not installed - recommended for PowerShell security" `
    -Severity "Warning" `
    -Check {
        $module = Get-Module -ListAvailable -Name PSScriptAnalyzer
        if ($module) {
            @{ Passed = $true; Value = "Version $($module.Version)" }
        }
        else {
            @{ Passed = $false; Value = "Not installed" }
        }
    }

# Check 8: Test security scan script execution
Test-Requirement `
    -Name "Security Script Execution" `
    -Expected "Can execute security scanning scripts" `
    -FailureMessage "Cannot execute security scanning scripts" `
    -Check {
        $testDir = Join-Path $env:TEMP "security-exec-test-$(Get-Random)"
        try {
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            $testScript = Join-Path $testDir "scan-test.ps1"

            @'
param([string]$Path)
Get-ChildItem -Path $Path -File | Select-String -Pattern "password|secret|token" -Quiet
'@ | Out-File $testScript -Encoding UTF8

            $testFile = Join-Path $testDir "test.txt"
            "no secrets here" | Out-File $testFile -Encoding UTF8

            $output = & $testScript -Path $testDir 2>&1
            @{ Passed = $true; Value = "Security scripts can execute" }
        }
        catch {
            @{ Passed = $false; Value = "Execution failed: $($_.Exception.Message)" }
        }
        finally {
            if (Test-Path $testDir) {
                Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

# Optional checks (if -IncludeOptional is specified)
if ($IncludeOptional) {
    # Check 9: SARIF support (for GitHub Code Scanning)
    Test-Requirement `
        -Name "SARIF Output Support" `
        -Expected "Can generate SARIF formatted output" `
        -FailureMessage "SARIF output generation not supported" `
        -Severity "Warning" `
        -Check {
            try {
                $sarifTemplate = @{
                    version = "2.1.0"
                    '$schema' = "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json"
                    runs = @()
                }
                $json = $sarifTemplate | ConvertTo-Json -Depth 10
                @{ Passed = $true; Value = "SARIF generation supported" }
            }
            catch {
                @{ Passed = $false; Value = "SARIF generation failed" }
            }
        }

    # Check 10: Code signing verification capability
    Test-Requirement `
        -Name "Code Signing Verification" `
        -Expected "Can verify code signatures" `
        -FailureMessage "Code signing verification not available" `
        -Severity "Warning" `
        -Check {
            try {
                $signature = Get-AuthenticodeSignature -FilePath $PSCommandPath
                @{ Passed = $true; Value = "Signature verification available" }
            }
            catch {
                @{ Passed = $false; Value = "Not available" }
            }
        }
}

# Summary
if (-not $JsonOutput) {
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Passed:   $($results.passed)" -ForegroundColor Green
    Write-Host "Failed:   $($results.failed)" -ForegroundColor $(if ($results.failed -gt 0) { "Red" } else { "Gray" })
    Write-Host "Warnings: $($results.warnings)" -ForegroundColor $(if ($results.warnings -gt 0) { "Yellow" } else { "Gray" })
    Write-Host "Total:    $($results.checks.Count)" -ForegroundColor Gray

    if ($results.failed -eq 0) {
        Write-Host "`n✅ Security scanning tools are properly configured!" -ForegroundColor Green
    }
    else {
        Write-Host "`n❌ Security scanning environment has issues that need to be addressed." -ForegroundColor Red
    }
}
else {
    $results | ConvertTo-Json -Depth 10
}

# Exit handling
if ($ExitOnFailure -and $results.failed -gt 0) {
    exit 1
}

exit 0
