#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies WSL2 installation and configuration for GitHub Actions runner

.DESCRIPTION
    Performs comprehensive checks of WSL2 installation, distro availability,
    and configuration. Validates that WSL2 is properly configured for use
    with GitHub Actions self-hosted runners and Docker Desktop integration.

.PARAMETER ExitOnFailure
    Exit with code 1 if any critical checks fail

.PARAMETER JsonOutput
    Output results in JSON format for programmatic consumption

.PARAMETER DistroName
    Name of WSL2 distro to check (default: Ubuntu)

.EXAMPLE
    .\verify-wsl2.ps1
    Runs all WSL2 verification checks with human-readable output

.EXAMPLE
    .\verify-wsl2.ps1 -JsonOutput
    Runs verification and outputs results as JSON

.EXAMPLE
    .\verify-wsl2.ps1 -ExitOnFailure -DistroName "Ubuntu-22.04"
    Runs verification for specific distro and exits with code 1 on any failure
#>

[CmdletBinding()]
param(
    [switch]$ExitOnFailure,
    [switch]$JsonOutput,
    [string]$DistroName = "Ubuntu"
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
    Write-Host "=== WSL2 Environment Verification ===" -ForegroundColor Cyan
    Write-Host ""
}

# Check 1: WSL command availability
Test-Requirement `
    -Name "WSL Command" `
    -Expected "WSL command is available in PATH" `
    -FailureMessage "WSL command not found. Install WSL with: wsl --install" `
    -Severity "Critical" `
    -Check {
        $wslCmd = Get-Command wsl -ErrorAction SilentlyContinue
        @{
            Success = $null -ne $wslCmd
            Actual = if ($wslCmd) { $wslCmd.Source } else { "Not found" }
        }
    }

# Check 2: WSL installed and accessible
Test-Requirement `
    -Name "WSL Installation" `
    -Expected "WSL is installed and accessible" `
    -FailureMessage "WSL is not installed. Run 'wsl --install' and restart." `
    -Severity "Critical" `
    -Check {
        try {
            $null = wsl --status 2>&1
            $success = $LASTEXITCODE -eq 0
            @{
                Success = $success
                Actual = if ($success) { "Installed" } else { "Not installed or not accessible" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
        }
    }

# Check 3: WSL2 is default version
Test-Requirement `
    -Name "WSL Default Version" `
    -Expected "WSL 2 is set as default version" `
    -FailureMessage "WSL 2 is not default. Run: wsl --set-default-version 2" `
    -Severity "Warning" `
    -Check {
        try {
            $statusOutput = wsl --status 2>&1 | Out-String
            $defaultVersion = if ($statusOutput -match 'Default Version:\s*(\d+)') { $matches[1] } else { "unknown" }
            @{
                Success = $defaultVersion -eq "2"
                Actual = "Default version: $defaultVersion"
            }
        }
        catch {
            @{ Success = $false; Actual = "Could not determine default version" }
        }
    }

# Check 4: At least one distro installed
Test-Requirement `
    -Name "WSL Distros" `
    -Expected "At least one WSL distro is installed" `
    -FailureMessage "No WSL distros found. Install Ubuntu from Microsoft Store." `
    -Severity "Critical" `
    -Check {
        try {
            $distroList = wsl --list --quiet 2>&1
            if ($LASTEXITCODE -eq 0 -and $distroList) {
                $distroCount = ($distroList | Measure-Object).Count
                @{
                    Success = $distroCount -gt 0
                    Actual = "$distroCount distro(s) installed"
                }
            }
            else {
                @{ Success = $false; Actual = "No distros found" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
        }
    }

# Check 5: Specific distro exists
Test-Requirement `
    -Name "Distro '$DistroName'" `
    -Expected "'$DistroName' distro is installed" `
    -FailureMessage "'$DistroName' not found. Install from Microsoft Store or specify different distro." `
    -Severity "Critical" `
    -Check {
        try {
            $distroList = wsl --list --quiet 2>&1 | Out-String
            $found = $distroList -match [regex]::Escape($DistroName)
            @{
                Success = $found
                Actual = if ($found) { "Distro '$DistroName' found" } else { "Distro '$DistroName' not found" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
        }
    }

# Check 6: Distro is running WSL2 (not WSL1)
Test-Requirement `
    -Name "WSL2 Version" `
    -Expected "'$DistroName' is running WSL 2" `
    -FailureMessage "'$DistroName' is WSL 1. Upgrade with: wsl --set-version $DistroName 2" `
    -Severity "Critical" `
    -Check {
        try {
            $verboseList = wsl --list --verbose 2>&1 | Out-String
            if ($verboseList -match "$DistroName\s+\w+\s+(\d+)") {
                $version = $matches[1]
                @{
                    Success = $version -eq "2"
                    Actual = "WSL version $version"
                }
            }
            else {
                @{ Success = $false; Actual = "Could not determine WSL version for $DistroName" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
        }
    }

# Check 7: Distro is running
Test-Requirement `
    -Name "Distro State" `
    -Expected "'$DistroName' can be started" `
    -FailureMessage "'$DistroName' cannot be started. Check WSL2 installation." `
    -Severity "Critical" `
    -Check {
        try {
            # Try to run a simple command to verify distro works
            $output = wsl -d $DistroName echo "test" 2>&1
            $success = $LASTEXITCODE -eq 0 -and $output -match "test"
            @{
                Success = $success
                Actual = if ($success) { "Distro is functional" } else { "Distro cannot run commands" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
        }
    }

# Check 8: Docker available in WSL2
Test-Requirement `
    -Name "Docker in WSL2" `
    -Expected "Docker command is available in '$DistroName'" `
    -FailureMessage "Docker not available in WSL2. Enable WSL integration in Docker Desktop." `
    -Severity "Warning" `
    -Check {
        try {
            $output = wsl -d $DistroName which docker 2>&1
            $success = $LASTEXITCODE -eq 0 -and $output -match "docker"
            @{
                Success = $success
                Actual = if ($success) { "Docker available at: $output" } else { "Docker command not found" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
        }
    }

# Check 9: Docker daemon accessible from WSL2
Test-Requirement `
    -Name "Docker Daemon in WSL2" `
    -Expected "Docker daemon is accessible from '$DistroName'" `
    -FailureMessage "Docker daemon not accessible. Start Docker Desktop." `
    -Severity "Warning" `
    -Check {
        try {
            $null = wsl -d $DistroName docker version 2>&1
            $success = $LASTEXITCODE -eq 0
            @{
                Success = $success
                Actual = if ($success) { "Docker daemon accessible" } else { "Docker daemon not accessible" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
        }
    }

# Check 10: WSL kernel version
Test-Requirement `
    -Name "WSL Kernel" `
    -Expected "WSL2 kernel version is available" `
    -FailureMessage "Could not determine WSL2 kernel version" `
    -Severity "Info" `
    -Check {
        try {
            $kernelOutput = wsl -d $DistroName uname -r 2>&1
            if ($LASTEXITCODE -eq 0 -and $kernelOutput) {
                @{
                    Success = $true
                    Actual = "Kernel: $kernelOutput"
                }
            }
            else {
                @{ Success = $false; Actual = "Could not determine kernel version" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
        }
    }

# Check 11: systemd support (for runner service)
Test-Requirement `
    -Name "systemd Support" `
    -Expected "systemd is available in '$DistroName'" `
    -FailureMessage "systemd not available. Needed for runner service." `
    -Severity "Warning" `
    -Check {
        try {
            $output = wsl -d $DistroName which systemctl 2>&1
            $success = $LASTEXITCODE -eq 0
            @{
                Success = $success
                Actual = if ($success) { "systemd available" } else { "systemd not found" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
        }
    }

# Check 12: Network connectivity from WSL2
Test-Requirement `
    -Name "WSL2 Network" `
    -Expected "WSL2 has network connectivity" `
    -FailureMessage "WSL2 has no network access. Check network settings." `
    -Severity "Critical" `
    -Check {
        try {
            $output = wsl -d $DistroName ping -c 1 -W 2 8.8.8.8 2>&1
            $success = $LASTEXITCODE -eq 0
            @{
                Success = $success
                Actual = if ($success) { "Network accessible" } else { "Network not accessible" }
            }
        }
        catch {
            @{ Success = $false; Actual = "Error: $($_.Exception.Message)" }
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
        Write-Host "✅ WSL2 environment is properly configured!" -ForegroundColor Green
    }
    else {
        Write-Host "❌ WSL2 environment has issues that need attention." -ForegroundColor Red
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
