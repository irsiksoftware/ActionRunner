#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies desktop application development capabilities (MAUI and WPF).

.DESCRIPTION
    This script checks that desktop application development tools are properly installed.
    It validates both MAUI and WPF capabilities and provides a combined status for the
    'desktop' runner label.

    Desktop capability includes:
    - .NET MAUI (cross-platform desktop apps)
    - WPF (Windows-only desktop apps)

.PARAMETER MinimumVersion
    The minimum required .NET version (default: 8.0 for MAUI, 6.0 for WPF)

.PARAMETER ExitOnFailure
    Exit with code 1 if all desktop capabilities fail

.PARAMETER JsonOutput
    Output results in JSON format

.PARAMETER RequireAll
    Require both MAUI and WPF to pass (default: require at least one)

.EXAMPLE
    .\verify-desktop.ps1
    Runs desktop capability checks, passes if either MAUI or WPF is available

.EXAMPLE
    .\verify-desktop.ps1 -RequireAll
    Requires both MAUI and WPF to be available

.EXAMPLE
    .\verify-desktop.ps1 -JsonOutput
    Outputs results in JSON format

.EXAMPLE
    .\verify-desktop.ps1 -ExitOnFailure
    Exits with error code if no desktop capability is available

.NOTES
    File Name      : verify-desktop.ps1
    Author         : ActionRunner Team
    Prerequisite   : PowerShell 5.1 or higher, Windows OS
    Copyright 2025 - ActionRunner
#>

[CmdletBinding()]
param(
    [string]$MinimumVersion = "8.0",
    [switch]$ExitOnFailure,
    [switch]$JsonOutput,
    [switch]$RequireAll
)

$ErrorActionPreference = 'Continue'

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Initialize results
$capabilities = @{
    maui = @{
        available = $false
        checks = @()
        summary = @{}
    }
    wpf = @{
        available = $false
        checks = @()
        summary = @{}
    }
}

$overallPassed = $false

# Run MAUI verification
if (-not $JsonOutput) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Desktop Capability Verification" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "`n--- MAUI Verification ---" -ForegroundColor Yellow
}

$mauiScript = Join-Path $ScriptDir "verify-maui.ps1"
if (Test-Path $mauiScript) {
    try {
        $mauiResult = & $mauiScript -JsonOutput -MinimumVersion $MinimumVersion 2>&1 | Out-String
        # Extract JSON from output (find first { to last })
        if ($mauiResult -match '(\{[\s\S]*\})') {
            $mauiJsonStr = $Matches[1]
            $mauiJson = $mauiJsonStr | ConvertFrom-Json -ErrorAction SilentlyContinue
        } else {
            $mauiJson = $null
        }

        if ($mauiJson) {
            $capabilities.maui.checks = $mauiJson.checks
            $capabilities.maui.summary = $mauiJson.summary

            # MAUI is available if no critical failures (passed > 0 and failed == 0 for core checks)
            # Consider MAUI available if the workload is installed (check index 2)
            $mauiWorkloadPassed = $false
            foreach ($check in $mauiJson.checks) {
                if ($check.name -eq "MAUI Workload" -and $check.status -eq "passed") {
                    $mauiWorkloadPassed = $true
                    break
                }
            }
            $capabilities.maui.available = $mauiWorkloadPassed

            if (-not $JsonOutput) {
                if ($capabilities.maui.available) {
                    Write-Host "✅ MAUI: Available" -ForegroundColor Green
                } else {
                    Write-Host "❌ MAUI: Not available" -ForegroundColor Red
                    Write-Host "   Install with: dotnet workload install maui" -ForegroundColor Yellow
                }
            }
        }
    } catch {
        if (-not $JsonOutput) {
            Write-Host "❌ MAUI verification failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
} else {
    if (-not $JsonOutput) {
        Write-Host "⚠️ MAUI verification script not found" -ForegroundColor Yellow
    }
}

# Run WPF verification
if (-not $JsonOutput) {
    Write-Host "`n--- WPF Verification ---" -ForegroundColor Yellow
}

$wpfScript = Join-Path $ScriptDir "verify-wpf.ps1"
if (Test-Path $wpfScript) {
    try {
        $wpfResult = & $wpfScript -JsonOutput -MinimumVersion "6.0" 2>&1 | Out-String
        # Extract JSON from output (find first { to last })
        if ($wpfResult -match '(\{[\s\S]*\})') {
            $wpfJsonStr = $Matches[1]
            $wpfJson = $wpfJsonStr | ConvertFrom-Json -ErrorAction SilentlyContinue
        } else {
            $wpfJson = $null
        }

        if ($wpfJson) {
            $capabilities.wpf.checks = $wpfJson.checks
            $capabilities.wpf.summary = $wpfJson.summary

            # WPF is available if project creation works
            $wpfProjectPassed = $false
            foreach ($check in $wpfJson.checks) {
                if ($check.name -eq "WPF Project Creation" -and $check.status -eq "passed") {
                    $wpfProjectPassed = $true
                    break
                }
            }
            $capabilities.wpf.available = $wpfProjectPassed

            if (-not $JsonOutput) {
                if ($capabilities.wpf.available) {
                    Write-Host "✅ WPF: Available" -ForegroundColor Green
                } else {
                    Write-Host "❌ WPF: Not available" -ForegroundColor Red
                }
            }
        }
    } catch {
        if (-not $JsonOutput) {
            Write-Host "❌ WPF verification failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
} else {
    if (-not $JsonOutput) {
        Write-Host "⚠️ WPF verification script not found" -ForegroundColor Yellow
    }
}

# Determine overall desktop capability
if ($RequireAll) {
    $overallPassed = $capabilities.maui.available -and $capabilities.wpf.available
} else {
    $overallPassed = $capabilities.maui.available -or $capabilities.wpf.available
}

# Output results
if ($JsonOutput) {
    $result = @{
        timestamp = Get-Date -Format "o"
        capability = "desktop"
        available = $overallPassed
        requireAll = $RequireAll.IsPresent
        capabilities = $capabilities
        summary = @{
            maui = $capabilities.maui.available
            wpf = $capabilities.wpf.available
            desktopReady = $overallPassed
        }
    }

    $result | ConvertTo-Json -Depth 10
} else {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Desktop Verification Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    Write-Host "`nCapabilities:"
    $mauiStatus = if ($capabilities.maui.available) { "✅ Available" } else { "❌ Not available" }
    $wpfStatus = if ($capabilities.wpf.available) { "✅ Available" } else { "❌ Not available" }
    Write-Host "  MAUI: $mauiStatus"
    Write-Host "  WPF:  $wpfStatus"

    Write-Host ""
    if ($overallPassed) {
        Write-Host "✅ Desktop capability: READY" -ForegroundColor Green
        Write-Host "   Runner can use the 'desktop' label" -ForegroundColor Gray
    } else {
        Write-Host "❌ Desktop capability: NOT READY" -ForegroundColor Red
        Write-Host "   Install MAUI: dotnet workload install maui" -ForegroundColor Yellow
        Write-Host "   WPF requires Windows with .NET SDK" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Exit with appropriate code
if ($ExitOnFailure -and -not $overallPassed) {
    exit 1
}

exit 0
