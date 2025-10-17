<#
.SYNOPSIS
    Run tests organized by build capability buckets
.DESCRIPTION
    Executes Pester tests grouped by capability areas (WebApp, Mobile, AI/LLM, etc.)
    and provides clear status reporting for each build capability.
#>

param(
    [Parameter()]
    [ValidateSet('All', 'Core', 'WebApp', 'Docker', 'Mobile', 'AI', 'Integration')]
    [string]$Capability = 'All',

    [Parameter()]
    [switch]$CI,

    [Parameter()]
    [switch]$DetailedOutput
)

$ErrorActionPreference = 'Stop'

# Define capability buckets
$CapabilityBuckets = @{
    'Core' = @{
        Name = 'Core Infrastructure'
        Description = 'Basic runner setup, configuration, and monitoring'
        Tags = @('Core', 'Config', 'Setup', 'Monitoring')
        Tests = @(
            'setup-runner.Tests.ps1'
            'apply-config.Tests.ps1'
            'health-check.Tests.ps1'
            'monitor-runner.Tests.ps1'
            'maintenance-mode.Tests.ps1'
            'update-runner.Tests.ps1'
            'check-runner-updates.Tests.ps1'
        )
        Icon = '⚙️'
    }

    'WebApp' = @{
        Name = 'Web Application Build Support'
        Description = 'Python, .NET, Node.js web frameworks'
        Tags = @('WebApp', 'Python', 'DotNet', 'NodeJS', 'Web')
        Tests = @(
            'verify-jesus-environment.Tests.ps1'  # Will be tagged for Python/Node.js checks
            'install-runner-devstack.Tests.ps1'   # Python, Node.js, .NET installation
        )
        Icon = '🌐'
    }

    'Docker' = @{
        Name = 'Docker & Container Support'
        Description = 'Docker setup, images, and container management'
        Tags = @('Docker', 'Container', 'WSL')
        Tests = @(
            'setup-docker.Tests.ps1'
            'cleanup-docker.Tests.ps1'
            'verify-wsl2.Tests.ps1'
        )
        Icon = '🐳'
    }

    'Mobile' = @{
        Name = 'Mobile Build Support'
        Description = 'Unity, Android, iOS, React Native, Flutter'
        Tags = @('Mobile', 'Unity', 'Android', 'iOS', 'ReactNative', 'Flutter')
        Tests = @()  # Will be created in Phase 3
        Icon = '📱'
    }

    'AI' = @{
        Name = 'AI/LLM Build Support'
        Description = 'LangChain, OpenAI, vector databases, model serving'
        Tags = @('AI', 'LLM', 'ML', 'GPU')
        Tests = @()  # Will be created in Phase 4
        Icon = '🤖'
    }

    'Integration' = @{
        Name = 'Integration & Workflows'
        Description = 'GitHub integration, workflows, end-to-end tests'
        Tags = @('Integration', 'Workflow', 'E2E')
        Tests = @(
            'end-to-end-workflow.Integration.Tests.ps1'
            'Workflows.Tests.ps1'
            'migrate-to-self-hosted.Tests.ps1'
            'register-runner.Tests.ps1'
            'self-hosted-runner.Tests.ps1'
            'dashboard.Tests.ps1'
        )
        Icon = '🔄'
    }

    'Utilities' = @{
        Name = 'Utilities & Support'
        Description = 'Cleanup, logging, benchmarking'
        Tags = @('Utility', 'Cleanup', 'Logging', 'Benchmark')
        Tests = @(
            'cleanup-workspace.Tests.ps1'
            'logging.Tests.ps1'
            'benchmark-runner.Tests.ps1'
        )
        Icon = '🛠️'
    }
}

function Write-CapabilityHeader {
    param($Capability, $Bucket)

    $line = "=" * 80
    Write-Host "`n$line" -ForegroundColor Cyan
    Write-Host "$($Bucket.Icon)  $($Bucket.Name)" -ForegroundColor Cyan
    Write-Host "   $($Bucket.Description)" -ForegroundColor Gray
    Write-Host "$line`n" -ForegroundColor Cyan
}

function Write-CapabilitySummary {
    param($Results)

    Write-Host "`n`n"
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host "BUILD CAPABILITY STATUS" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host ""

    $overallPassed = 0
    $overallFailed = 0

    foreach ($result in $Results) {
        $bucket = $result.Bucket
        $testResult = $result.Result

        $overallPassed += $testResult.PassedCount
        $overallFailed += $testResult.FailedCount

        $passRate = if ($testResult.TotalCount -gt 0) {
            [math]::Round(($testResult.PassedCount / $testResult.TotalCount) * 100, 1)
        } else {
            0
        }

        $status = if ($testResult.FailedCount -eq 0 -and $testResult.TotalCount -gt 0) {
            "✓"
        } elseif ($passRate -ge 80) {
            "⚠"
        } else {
            "✗"
        }

        $statusColor = if ($testResult.FailedCount -eq 0 -and $testResult.TotalCount -gt 0) {
            "Green"
        } elseif ($passRate -ge 80) {
            "Yellow"
        } else {
            "Red"
        }

        Write-Host "$($bucket.Icon) " -NoNewline
        Write-Host "$status " -NoNewline -ForegroundColor $statusColor
        Write-Host "$($bucket.Name): " -NoNewline -ForegroundColor White
        Write-Host "$($testResult.PassedCount)/$($testResult.TotalCount) " -NoNewline
        Write-Host "($passRate%)" -ForegroundColor $statusColor
    }

    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Cyan

    $totalTests = $overallPassed + $overallFailed
    $totalPassRate = if ($totalTests -gt 0) {
        [math]::Round(($overallPassed / $totalTests) * 100, 1)
    } else {
        0
    }

    Write-Host "OVERALL: " -NoNewline -ForegroundColor Cyan
    Write-Host "$overallPassed/$totalTests tests passing " -NoNewline
    Write-Host "($totalPassRate%)" -ForegroundColor $(if ($totalPassRate -ge 90) { "Green" } elseif ($totalPassRate -ge 70) { "Yellow" } else { "Red" })
    Write-Host ""
}

# Main execution
$testsPath = Join-Path $PSScriptRoot "..\tests"
$results = @()

if ($Capability -eq 'All') {
    foreach ($capKey in @('Core', 'WebApp', 'Docker', 'Integration', 'Utilities', 'Mobile', 'AI')) {
        $bucket = $CapabilityBuckets[$capKey]

        if ($bucket.Tests.Count -eq 0) {
            Write-Host "`n$($bucket.Icon) $($bucket.Name): No tests defined yet (coming in future phases)" -ForegroundColor Gray
            continue
        }

        Write-CapabilityHeader -Capability $capKey -Bucket $bucket

        $testFiles = $bucket.Tests | ForEach-Object { Join-Path $testsPath $_ }
        $existingTests = $testFiles | Where-Object { Test-Path $_ }

        if ($existingTests.Count -eq 0) {
            Write-Host "No test files found for this capability" -ForegroundColor Yellow
            continue
        }

        $config = New-PesterConfiguration
        $config.Run.Path = $existingTests
        $config.Run.PassThru = $true
        $config.Output.Verbosity = if ($DetailedOutput) { 'Detailed' } else { 'Normal' }
        $config.Run.Exit = $false

        $result = Invoke-Pester -Configuration $config

        $results += @{
            Capability = $capKey
            Bucket = $bucket
            Result = $result
        }
    }

    Write-CapabilitySummary -Results $results

} else {
    $bucket = $CapabilityBuckets[$Capability]

    if ($bucket.Tests.Count -eq 0) {
        Write-Host "$($bucket.Icon) $($bucket.Name): No tests defined yet" -ForegroundColor Yellow
        exit 0
    }

    Write-CapabilityHeader -Capability $Capability -Bucket $bucket

    $testFiles = $bucket.Tests | ForEach-Object { Join-Path $testsPath $_ }
    $existingTests = $testFiles | Where-Object { Test-Path $_ }

    $config = New-PesterConfiguration
    $config.Run.Path = $existingTests
    $config.Run.PassThru = $true
    $config.Output.Verbosity = if ($DetailedOutput) { 'Detailed' } else { 'Normal' }
    $config.Run.Exit = $CI

    $result = Invoke-Pester -Configuration $config

    # Summary for single capability
    $passRate = if ($result.TotalCount -gt 0) {
        [math]::Round(($result.PassedCount / $result.TotalCount) * 100, 1)
    } else {
        0
    }

    Write-Host "`n$($bucket.Icon) $($bucket.Name): " -NoNewline
    Write-Host "$($result.PassedCount)/$($result.TotalCount) tests passing " -NoNewline
    Write-Host "($passRate%)" -ForegroundColor $(if ($passRate -ge 90) { "Green" } elseif ($passRate -ge 70) { "Yellow" } else { "Red" })
}

# Export results for CI
if ($CI -and $Capability -eq 'All') {
    $summary = @{
        Timestamp = Get-Date -Format 'o'
        Capabilities = @{}
    }

    foreach ($result in $results) {
        $passRate = if ($result.Result.TotalCount -gt 0) {
            [math]::Round(($result.Result.PassedCount / $result.Result.TotalCount) * 100, 1)
        } else {
            0
        }

        $summary.Capabilities[$result.Capability] = @{
            Name = $result.Bucket.Name
            Total = $result.Result.TotalCount
            Passed = $result.Result.PassedCount
            Failed = $result.Result.FailedCount
            PassRate = $passRate
            Status = if ($result.Result.FailedCount -eq 0 -and $result.Result.TotalCount -gt 0) { 'Pass' }
                     elseif ($passRate -ge 80) { 'Warning' }
                     else { 'Fail' }
        }
    }

    $outputPath = Join-Path $PSScriptRoot "..\test-capability-status.json"
    $summary | ConvertTo-Json -Depth 10 | Out-File $outputPath -Encoding UTF8
    Write-Host "`nCapability status exported to: $outputPath" -ForegroundColor Cyan
}
