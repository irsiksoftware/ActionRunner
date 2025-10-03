# Test runner for ActionRunner project
# This script runs all Pester tests and generates a coverage report

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Detailed,

    [Parameter(Mandatory = $false)]
    [switch]$Coverage,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\test-results"
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  ActionRunner Test Suite" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Check if Pester is installed
$pesterModule = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -ge [version]"5.0.0" }

if (-not $pesterModule) {
    Write-Host "Pester 5.0+ is not installed. Installing..." -ForegroundColor Yellow
    Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck -Scope CurrentUser
    Write-Host "Pester installed successfully!" -ForegroundColor Green
    Write-Host ""
}

Import-Module Pester -MinimumVersion 5.0.0

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

# Configure Pester
$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path = "$PSScriptRoot"
$pesterConfig.Run.PassThru = $true
$pesterConfig.Output.Verbosity = if ($Detailed) { "Detailed" } else { "Normal" }
$pesterConfig.TestResult.Enabled = $true
$pesterConfig.TestResult.OutputPath = Join-Path $OutputPath "test-results.xml"
$pesterConfig.TestResult.OutputFormat = "NUnitXml"

if ($Coverage) {
    $pesterConfig.CodeCoverage.Enabled = $true
    $pesterConfig.CodeCoverage.Path = "$PSScriptRoot\..\scripts\*.ps1"
    $pesterConfig.CodeCoverage.OutputPath = Join-Path $OutputPath "coverage.xml"
    $pesterConfig.CodeCoverage.OutputFormat = "JaCoCo"
}

# Run tests
Write-Host "Running tests..." -ForegroundColor Cyan
Write-Host ""

$result = Invoke-Pester -Configuration $pesterConfig

# Display results summary
Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Test Results Summary" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Total Tests:  $($result.TotalCount)" -ForegroundColor White
Write-Host "Passed:       $($result.PassedCount)" -ForegroundColor Green
Write-Host "Failed:       $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { "Red" } else { "Green" })
Write-Host "Skipped:      $($result.SkippedCount)" -ForegroundColor Yellow
Write-Host "Duration:     $($result.Duration.TotalSeconds) seconds" -ForegroundColor White
Write-Host ""

if ($result.FailedCount -gt 0) {
    Write-Host "Failed Tests:" -ForegroundColor Red
    foreach ($test in $result.Failed) {
        Write-Host "  - $($test.ExpandedName)" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "Test results saved to: $OutputPath" -ForegroundColor Cyan

if ($Coverage) {
    Write-Host "Coverage report saved to: $(Join-Path $OutputPath 'coverage.xml')" -ForegroundColor Cyan
}

Write-Host ""

# Exit with appropriate code
exit $result.FailedCount
