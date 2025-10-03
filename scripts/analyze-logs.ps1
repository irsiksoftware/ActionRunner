<#
.SYNOPSIS
    Analyze runner logs to identify patterns, errors, and trends.

.DESCRIPTION
    Analyzes collected logs to provide insights:
    - Error frequency and patterns
    - Job success/failure rates
    - Performance trends
    - Security events
    - Common issues

.PARAMETER LogPath
    Path to logs directory. Defaults to ./logs

.PARAMETER Days
    Number of days to analyze. Defaults to 7.

.PARAMETER OutputFormat
    Output format: Text, JSON, or HTML. Defaults to Text.

.PARAMETER ReportPath
    Path to save the analysis report. Optional.

.EXAMPLE
    .\analyze-logs.ps1
    Analyze last 7 days of logs and display results

.EXAMPLE
    .\analyze-logs.ps1 -Days 30 -OutputFormat JSON -ReportPath .\reports\analysis.json
    Analyze 30 days and save JSON report
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$LogPath = ".\logs",

    [Parameter()]
    [int]$Days = 7,

    [Parameter()]
    [ValidateSet('Text', 'JSON', 'HTML')]
    [string]$OutputFormat = 'Text',

    [Parameter()]
    [string]$ReportPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "=== Log Analysis ===" -ForegroundColor Cyan
Write-Host "Analyzing logs from last $Days days..." -ForegroundColor White
Write-Host "Log Path: $LogPath" -ForegroundColor White
Write-Host ""

# Ensure log path exists
if (-not (Test-Path $LogPath)) {
    Write-Host "Log path does not exist: $LogPath" -ForegroundColor Red
    exit 1
}

# Calculate date range
$startDate = (Get-Date).AddDays(-$Days)
$analysisTime = Get-Date

# Initialize analysis structure
$analysis = @{
    Metadata = @{
        AnalysisTime = $analysisTime.ToString('yyyy-MM-dd HH:mm:ss')
        DateRange = @{
            Start = $startDate.ToString('yyyy-MM-dd')
            End = $analysisTime.ToString('yyyy-MM-dd')
        }
        DaysAnalyzed = $Days
    }
    Summary = @{
        TotalFiles = 0
        TotalSize = 0
        FilesAnalyzed = 0
    }
    Errors = @{
        TotalCount = 0
        UniquePatterns = @()
        ByCategory = @{}
    }
    Jobs = @{
        TotalExecutions = 0
        Successful = 0
        Failed = 0
        SuccessRate = 0
    }
    Performance = @{
        AverageCPU = 0
        AverageMemory = 0
        PeakCPU = 0
        PeakMemory = 0
    }
    Security = @{
        Events = 0
        Warnings = @()
    }
    Recommendations = @()
}

# Collect all log files
Write-Host "[1/5] Scanning log files..." -ForegroundColor Yellow
$allLogs = Get-ChildItem -Path $LogPath -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Extension -in @('.log', '.txt', '.json') -and
        $_.LastWriteTime -gt $startDate
    }

$analysis.Summary.TotalFiles = $allLogs.Count
$analysis.Summary.TotalSize = ($allLogs | Measure-Object -Property Length -Sum).Sum

Write-Host "  Found $($allLogs.Count) log files ($([math]::Round($analysis.Summary.TotalSize / 1MB, 2)) MB)" -ForegroundColor Green

# Analyze errors
Write-Host "`n[2/5] Analyzing errors and warnings..." -ForegroundColor Yellow
$errorPatterns = @(
    @{ Pattern = 'error'; Category = 'Error'; Severity = 'High' }
    @{ Pattern = 'exception'; Category = 'Exception'; Severity = 'High' }
    @{ Pattern = 'failed'; Category = 'Failure'; Severity = 'Medium' }
    @{ Pattern = 'warning'; Category = 'Warning'; Severity = 'Low' }
    @{ Pattern = 'timeout'; Category = 'Timeout'; Severity = 'Medium' }
    @{ Pattern = 'denied'; Category = 'Access Denied'; Severity = 'High' }
    @{ Pattern = 'cannot'; Category = 'Cannot'; Severity = 'Medium' }
)

$errorMatches = @{}

foreach ($log in $allLogs) {
    try {
        $content = Get-Content $log.FullName -ErrorAction SilentlyContinue
        if ($null -eq $content) { continue }

        $analysis.Summary.FilesAnalyzed++

        foreach ($pattern in $errorPatterns) {
            $matches = $content | Select-String -Pattern $pattern.Pattern -SimpleMatch -CaseSensitive:$false
            if ($matches.Count -gt 0) {
                if (-not $errorMatches.ContainsKey($pattern.Category)) {
                    $errorMatches[$pattern.Category] = @{
                        Count = 0
                        Severity = $pattern.Severity
                        Examples = @()
                    }
                }
                $errorMatches[$pattern.Category].Count += $matches.Count

                # Store first 3 examples
                if ($errorMatches[$pattern.Category].Examples.Count -lt 3) {
                    $errorMatches[$pattern.Category].Examples += $matches |
                        Select-Object -First (3 - $errorMatches[$pattern.Category].Examples.Count) -ExpandProperty Line
                }

                $analysis.Errors.TotalCount += $matches.Count
            }
        }
    } catch {
        Write-Host "  Warning: Could not analyze $($log.Name)" -ForegroundColor Gray
    }
}

$analysis.Errors.ByCategory = $errorMatches
$analysis.Errors.UniquePatterns = $errorMatches.Keys

if ($analysis.Errors.TotalCount -gt 0) {
    Write-Host "  Found $($analysis.Errors.TotalCount) errors/warnings across $($errorMatches.Count) categories" -ForegroundColor Yellow
} else {
    Write-Host "  No errors or warnings found" -ForegroundColor Green
}

# Analyze job executions
Write-Host "`n[3/5] Analyzing job executions..." -ForegroundColor Yellow
$jobLogs = $allLogs | Where-Object { $_.DirectoryName -like '*jobs*' -or $_.Name -like '*job*' }

foreach ($log in $jobLogs) {
    try {
        $content = Get-Content $log.FullName -ErrorAction SilentlyContinue
        if ($null -eq $content) { continue }

        $analysis.Jobs.TotalExecutions++

        if ($content -match 'success|completed|passed') {
            $analysis.Jobs.Successful++
        }
        if ($content -match 'failed|error|aborted') {
            $analysis.Jobs.Failed++
        }
    } catch {
        # Skip problematic files
    }
}

if ($analysis.Jobs.TotalExecutions -gt 0) {
    $analysis.Jobs.SuccessRate = [math]::Round(($analysis.Jobs.Successful / $analysis.Jobs.TotalExecutions) * 100, 1)
    Write-Host "  Analyzed $($analysis.Jobs.TotalExecutions) job executions ($($analysis.Jobs.SuccessRate)% success rate)" -ForegroundColor Green
} else {
    Write-Host "  No job execution logs found" -ForegroundColor Gray
}

# Analyze performance data
Write-Host "`n[4/5] Analyzing performance metrics..." -ForegroundColor Yellow
$perfLogs = $allLogs | Where-Object { $_.Name -like '*performance*' -or $_.DirectoryName -like '*performance*' }

$cpuReadings = @()
$memReadings = @()

foreach ($log in $perfLogs) {
    try {
        $content = Get-Content $log.FullName -Raw -ErrorAction SilentlyContinue

        # Extract CPU percentages
        if ($content -match 'LoadPercentage\s*:\s*(\d+)') {
            $cpuReadings += [int]$matches[1]
        }

        # Extract memory usage (calculate percentage from free vs total)
        if ($content -match 'TotalVisibleMemorySize\s*:\s*(\d+)' -and
            $content -match 'FreePhysicalMemory\s*:\s*(\d+)') {
            $total = [int64]$matches[1]
            $free = [int64]$matches[2]
            if ($total -gt 0) {
                $memPercent = [math]::Round((($total - $free) / $total) * 100, 1)
                $memReadings += $memPercent
            }
        }
    } catch {
        # Skip problematic files
    }
}

if ($cpuReadings.Count -gt 0) {
    $analysis.Performance.AverageCPU = [math]::Round(($cpuReadings | Measure-Object -Average).Average, 1)
    $analysis.Performance.PeakCPU = ($cpuReadings | Measure-Object -Maximum).Maximum
}

if ($memReadings.Count -gt 0) {
    $analysis.Performance.AverageMemory = [math]::Round(($memReadings | Measure-Object -Average).Average, 1)
    $analysis.Performance.PeakMemory = [math]::Round(($memReadings | Measure-Object -Maximum).Maximum, 1)
}

if ($cpuReadings.Count -gt 0 -or $memReadings.Count -gt 0) {
    Write-Host "  Analyzed $($cpuReadings.Count) CPU readings and $($memReadings.Count) memory readings" -ForegroundColor Green
} else {
    Write-Host "  No performance metrics found" -ForegroundColor Gray
}

# Analyze security events
Write-Host "`n[5/5] Analyzing security events..." -ForegroundColor Yellow
$securityLogs = $allLogs | Where-Object { $_.Name -like '*security*' -or $_.DirectoryName -like '*security*' }

$securityPatterns = @(
    'failed.*login',
    'unauthorized',
    'permission.*denied',
    'access.*denied',
    'authentication.*failed'
)

$securityWarnings = @()

foreach ($log in $securityLogs) {
    try {
        $content = Get-Content $log.FullName -ErrorAction SilentlyContinue
        if ($null -eq $content) { continue }

        foreach ($pattern in $securityPatterns) {
            $matches = $content | Select-String -Pattern $pattern -CaseSensitive:$false
            if ($matches.Count -gt 0) {
                $analysis.Security.Events += $matches.Count
                foreach ($match in $matches | Select-Object -First 2) {
                    $securityWarnings += $match.Line.Trim()
                }
            }
        }
    } catch {
        # Skip problematic files
    }
}

$analysis.Security.Warnings = $securityWarnings

if ($analysis.Security.Events -gt 0) {
    Write-Host "  Found $($analysis.Security.Events) security-related events" -ForegroundColor Yellow
} else {
    Write-Host "  No security issues detected" -ForegroundColor Green
}

# Generate recommendations
Write-Host "`nGenerating recommendations..." -ForegroundColor Yellow

if ($analysis.Errors.TotalCount -gt 100) {
    $analysis.Recommendations += "High error count detected ($($analysis.Errors.TotalCount) errors). Review error patterns and implement fixes."
}

if ($analysis.Jobs.SuccessRate -lt 80 -and $analysis.Jobs.TotalExecutions -gt 0) {
    $analysis.Recommendations += "Job success rate is below 80% ($($analysis.Jobs.SuccessRate)%). Investigate failing jobs."
}

if ($analysis.Performance.PeakCPU -gt 90) {
    $analysis.Recommendations += "Peak CPU usage is high ($($analysis.Performance.PeakCPU)%). Consider resource optimization."
}

if ($analysis.Performance.PeakMemory -gt 90) {
    $analysis.Recommendations += "Peak memory usage is high ($($analysis.Performance.PeakMemory)%). Monitor for memory leaks."
}

if ($analysis.Security.Events -gt 10) {
    $analysis.Recommendations += "Multiple security events detected ($($analysis.Security.Events)). Review security audit logs."
}

if ($analysis.Summary.TotalSize -gt 1GB) {
    $analysis.Recommendations += "Log directory size is large ($([math]::Round($analysis.Summary.TotalSize / 1GB, 2)) GB). Run log rotation."
}

if ($analysis.Recommendations.Count -eq 0) {
    $analysis.Recommendations += "No critical issues detected. System appears healthy."
}

# Output results
Write-Host "`n=== Analysis Complete ===" -ForegroundColor Cyan
Write-Host ""

if ($OutputFormat -eq 'JSON') {
    $output = $analysis | ConvertTo-Json -Depth 5
} elseif ($OutputFormat -eq 'HTML') {
    $output = @"
<!DOCTYPE html>
<html>
<head>
    <title>Runner Log Analysis</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        h2 { color: #666; border-bottom: 2px solid #ddd; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .warning { color: #ff6600; }
        .error { color: #cc0000; }
        .success { color: #00cc00; }
    </style>
</head>
<body>
    <h1>Runner Log Analysis Report</h1>
    <p><strong>Generated:</strong> $($analysis.Metadata.AnalysisTime)</p>
    <p><strong>Period:</strong> $($analysis.Metadata.DateRange.Start) to $($analysis.Metadata.DateRange.End)</p>

    <h2>Summary</h2>
    <table>
        <tr><th>Metric</th><th>Value</th></tr>
        <tr><td>Files Analyzed</td><td>$($analysis.Summary.FilesAnalyzed) / $($analysis.Summary.TotalFiles)</td></tr>
        <tr><td>Total Size</td><td>$([math]::Round($analysis.Summary.TotalSize / 1MB, 2)) MB</td></tr>
    </table>

    <h2>Errors</h2>
    <p class="error">Total Errors: $($analysis.Errors.TotalCount)</p>

    <h2>Job Executions</h2>
    <table>
        <tr><th>Metric</th><th>Value</th></tr>
        <tr><td>Total Executions</td><td>$($analysis.Jobs.TotalExecutions)</td></tr>
        <tr><td>Successful</td><td class="success">$($analysis.Jobs.Successful)</td></tr>
        <tr><td>Failed</td><td class="error">$($analysis.Jobs.Failed)</td></tr>
        <tr><td>Success Rate</td><td>$($analysis.Jobs.SuccessRate)%</td></tr>
    </table>

    <h2>Recommendations</h2>
    <ul>
$(foreach ($rec in $analysis.Recommendations) { "        <li>$rec</li>`n" })
    </ul>
</body>
</html>
"@
} else {
    # Text format
    $output = @"
=== RUNNER LOG ANALYSIS REPORT ===

Generated: $($analysis.Metadata.AnalysisTime)
Period: $($analysis.Metadata.DateRange.Start) to $($analysis.Metadata.DateRange.End)
Days Analyzed: $($analysis.Metadata.DaysAnalyzed)

--- SUMMARY ---
Files Analyzed: $($analysis.Summary.FilesAnalyzed) / $($analysis.Summary.TotalFiles)
Total Size: $([math]::Round($analysis.Summary.TotalSize / 1MB, 2)) MB

--- ERRORS & WARNINGS ---
Total Count: $($analysis.Errors.TotalCount)
Categories: $($analysis.Errors.UniquePatterns.Count)

$(if ($analysis.Errors.ByCategory.Count -gt 0) {
    "By Category:"
    foreach ($category in $analysis.Errors.ByCategory.Keys | Sort-Object) {
        $cat = $analysis.Errors.ByCategory[$category]
        "  - $category [$($cat.Severity)]: $($cat.Count) occurrences"
    }
})

--- JOB EXECUTIONS ---
Total Executions: $($analysis.Jobs.TotalExecutions)
Successful: $($analysis.Jobs.Successful)
Failed: $($analysis.Jobs.Failed)
Success Rate: $($analysis.Jobs.SuccessRate)%

--- PERFORMANCE ---
Average CPU: $($analysis.Performance.AverageCPU)%
Peak CPU: $($analysis.Performance.PeakCPU)%
Average Memory: $($analysis.Performance.AverageMemory)%
Peak Memory: $($analysis.Performance.PeakMemory)%

--- SECURITY ---
Events Detected: $($analysis.Security.Events)
$(if ($analysis.Security.Warnings.Count -gt 0) {
    "Warnings:"
    foreach ($warning in $analysis.Security.Warnings | Select-Object -First 5) {
        "  - $warning"
    }
})

--- RECOMMENDATIONS ---
$(foreach ($rec in $analysis.Recommendations) { "  - $rec`n" })

=== END OF REPORT ===
"@
}

# Display output
Write-Host $output

# Save to file if requested
if ($ReportPath) {
    $output | Set-Content -Path $ReportPath
    Write-Host "`nReport saved to: $ReportPath" -ForegroundColor Green
}

# Return analysis object for automation
return $analysis
