<#
.SYNOPSIS
    Analyzes GitHub Actions runner logs to identify patterns, errors, and trends.

.DESCRIPTION
    This script performs log analysis to:
    - Identify error patterns and frequencies
    - Track job success/failure rates
    - Detect performance issues
    - Generate statistical reports
    - Highlight anomalies and warnings

.PARAMETER LogPath
    Path to the logs directory. Default: .\logs

.PARAMETER OutputFormat
    Output format: 'Console', 'JSON', or 'HTML'. Default: Console

.PARAMETER DaysToAnalyze
    Number of days of logs to analyze. Default: 7

.PARAMETER GenerateReport
    Generate a detailed HTML report. Default: $false

.EXAMPLE
    .\analyze-logs.ps1
    Analyzes last 7 days of logs and displays results in console.

.EXAMPLE
    .\analyze-logs.ps1 -DaysToAnalyze 30 -GenerateReport $true
    Analyzes last 30 days and generates an HTML report.
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$LogPath = ".\logs",

    [Parameter(Mandatory=$false)]
    [ValidateSet('Console', 'JSON', 'HTML')]
    [string]$OutputFormat = 'Console',

    [Parameter(Mandatory=$false)]
    [int]$DaysToAnalyze = 7,

    [Parameter(Mandatory=$false)]
    [bool]$GenerateReport = $false
)

if (-not (Test-Path $LogPath)) {
    Write-Host "Log path does not exist: $LogPath" -ForegroundColor Red
    exit 1
}

Write-Host "=== GitHub Actions Runner Log Analysis ===" -ForegroundColor Cyan
Write-Host "Start Time: $(Get-Date)" -ForegroundColor Green
Write-Host "Analyzing logs from: $LogPath" -ForegroundColor Green
Write-Host "Days to analyze: $DaysToAnalyze" -ForegroundColor Green
Write-Host ""

$startDate = (Get-Date).AddDays(-$DaysToAnalyze)

# Initialize analysis results
$analysis = @{
    AnalysisDate = Get-Date
    Period = @{
        StartDate = $startDate
        EndDate = Get-Date
        Days = $DaysToAnalyze
    }
    Summary = @{
        TotalLogFiles = 0
        TotalEvents = 0
        Errors = 0
        Warnings = 0
        JobExecutions = 0
    }
    ErrorPatterns = @{}
    WarningPatterns = @{}
    JobStats = @{
        Successful = 0
        Failed = 0
        Cancelled = 0
        Unknown = 0
    }
    PerformanceMetrics = @{
        AverageCPU = 0
        AverageMemory = 0
        PeakCPU = 0
        PeakMemory = 0
    }
    Recommendations = @()
}

# 1. Analyze JSON log files
Write-Host "[1/4] Analyzing JSON log files..." -ForegroundColor Yellow

$jsonFiles = Get-ChildItem -Path $LogPath -Filter "*.json" -File |
    Where-Object { $_.LastWriteTime -ge $startDate }

$analysis.Summary.TotalLogFiles = $jsonFiles.Count

foreach ($file in $jsonFiles) {
    try {
        $content = Get-Content $file.FullName -Raw | ConvertFrom-Json

        # Analyze based on file type
        if ($file.Name -like "*performance*") {
            # Performance data
            if ($content.CPU) {
                $cpuValue = $content.CPU.CounterSamples.CookedValue | Select-Object -First 1
                if ($cpuValue -gt $analysis.PerformanceMetrics.PeakCPU) {
                    $analysis.PerformanceMetrics.PeakCPU = $cpuValue
                }
            }

            if ($content.Memory) {
                $memValue = $content.Memory.CounterSamples.CookedValue | Select-Object -First 1
                if ($memValue -gt $analysis.PerformanceMetrics.PeakMemory) {
                    $analysis.PerformanceMetrics.PeakMemory = $memValue
                }
            }
        }

        if ($file.Name -like "*eventlog*") {
            # Event log data
            $events = if ($content -is [array]) { $content } else { @($content) }

            foreach ($event in $events) {
                $analysis.Summary.TotalEvents++

                if ($event.LevelDisplayName -eq 'Error') {
                    $analysis.Summary.Errors++

                    # Extract error pattern
                    if ($event.Message) {
                        $firstLine = ($event.Message -split "`n")[0]
                        if ($analysis.ErrorPatterns.ContainsKey($firstLine)) {
                            $analysis.ErrorPatterns[$firstLine]++
                        } else {
                            $analysis.ErrorPatterns[$firstLine] = 1
                        }
                    }
                }

                if ($event.LevelDisplayName -eq 'Warning') {
                    $analysis.Summary.Warnings++

                    if ($event.Message) {
                        $firstLine = ($event.Message -split "`n")[0]
                        if ($analysis.WarningPatterns.ContainsKey($firstLine)) {
                            $analysis.WarningPatterns[$firstLine]++
                        } else {
                            $analysis.WarningPatterns[$firstLine] = 1
                        }
                    }
                }
            }
        }
    } catch {
        Write-Host "  Warning: Could not parse $($file.Name): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# 2. Analyze plain text log files
Write-Host "[2/4] Analyzing text log files..." -ForegroundColor Yellow

$logFiles = Get-ChildItem -Path $LogPath -Filter "*.log" -File |
    Where-Object { $_.LastWriteTime -ge $startDate }

foreach ($file in $logFiles) {
    try {
        $content = Get-Content $file.FullName -ErrorAction Stop

        foreach ($line in $content) {
            # Count job executions
            if ($line -match "Starting Job|Job started|Running job") {
                $analysis.Summary.JobExecutions++
            }

            # Count successes
            if ($line -match "Job completed successfully|Job succeeded|Finished: Success") {
                $analysis.JobStats.Successful++
            }

            # Count failures
            if ($line -match "Job failed|Job completed with errors|Finished: Failed") {
                $analysis.JobStats.Failed++
            }

            # Count cancellations
            if ($line -match "Job cancelled|Job was cancelled|Finished: Cancelled") {
                $analysis.JobStats.Cancelled++
            }

            # Detect errors
            if ($line -match "ERROR|Error|error:|Exception") {
                $analysis.Summary.Errors++

                # Extract error pattern (first 100 chars)
                $pattern = $line.Substring(0, [Math]::Min(100, $line.Length))
                if ($analysis.ErrorPatterns.ContainsKey($pattern)) {
                    $analysis.ErrorPatterns[$pattern]++
                } else {
                    $analysis.ErrorPatterns[$pattern] = 1
                }
            }

            # Detect warnings
            if ($line -match "WARNING|Warning|warn:") {
                $analysis.Summary.Warnings++

                $pattern = $line.Substring(0, [Math]::Min(100, $line.Length))
                if ($analysis.WarningPatterns.ContainsKey($pattern)) {
                    $analysis.WarningPatterns[$pattern]++
                } else {
                    $analysis.WarningPatterns[$pattern] = 1
                }
            }
        }
    } catch {
        Write-Host "  Warning: Could not read $($file.Name): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# 3. Generate recommendations
Write-Host "[3/4] Generating recommendations..." -ForegroundColor Yellow

# Check error rate
$totalJobs = $analysis.JobStats.Successful + $analysis.JobStats.Failed + $analysis.JobStats.Cancelled
if ($totalJobs -gt 0) {
    $failureRate = ($analysis.JobStats.Failed / $totalJobs) * 100
    if ($failureRate -gt 10) {
        $analysis.Recommendations += "High job failure rate ($([math]::Round($failureRate, 2))%). Investigate common error patterns."
    }
}

# Check CPU usage
if ($analysis.PerformanceMetrics.PeakCPU -gt 90) {
    $analysis.Recommendations += "Peak CPU usage is high ($($analysis.PerformanceMetrics.PeakCPU)%). Consider upgrading runner hardware."
}

# Check for repeated errors
$topErrors = $analysis.ErrorPatterns.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 3
foreach ($error in $topErrors) {
    if ($error.Value -gt 5) {
        $analysis.Recommendations += "Recurring error detected ($($error.Value) occurrences): $($error.Key.Substring(0, [Math]::Min(80, $error.Key.Length)))..."
    }
}

# Check log volume
if ($analysis.Summary.TotalLogFiles -lt 3 -and $DaysToAnalyze -gt 1) {
    $analysis.Recommendations += "Low log volume detected. Ensure log collection is running regularly."
}

if ($analysis.Recommendations.Count -eq 0) {
    $analysis.Recommendations += "No issues detected. Runner is operating normally."
}

# 4. Output results
Write-Host "[4/4] Generating output..." -ForegroundColor Yellow
Write-Host ""

if ($OutputFormat -eq 'Console' -or $GenerateReport) {
    Write-Host "=== Analysis Summary ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Period: $($analysis.Period.StartDate.ToString('yyyy-MM-dd')) to $($analysis.Period.EndDate.ToString('yyyy-MM-dd'))" -ForegroundColor Cyan
    Write-Host "Total Log Files Analyzed: $($analysis.Summary.TotalLogFiles)" -ForegroundColor Cyan
    Write-Host "Total Events: $($analysis.Summary.TotalEvents)" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Job Statistics:" -ForegroundColor Yellow
    Write-Host "  Total Jobs: $totalJobs" -ForegroundColor Gray
    Write-Host "  Successful: $($analysis.JobStats.Successful) ($([math]::Round(($analysis.JobStats.Successful/$totalJobs)*100, 1))%)" -ForegroundColor Green
    Write-Host "  Failed: $($analysis.JobStats.Failed) ($([math]::Round(($analysis.JobStats.Failed/$totalJobs)*100, 1))%)" -ForegroundColor $(if ($analysis.JobStats.Failed -gt 0) { "Red" } else { "Gray" })
    Write-Host "  Cancelled: $($analysis.JobStats.Cancelled)" -ForegroundColor Gray
    Write-Host ""

    Write-Host "Error & Warning Summary:" -ForegroundColor Yellow
    Write-Host "  Total Errors: $($analysis.Summary.Errors)" -ForegroundColor $(if ($analysis.Summary.Errors -gt 0) { "Red" } else { "Green" })
    Write-Host "  Total Warnings: $($analysis.Summary.Warnings)" -ForegroundColor $(if ($analysis.Summary.Warnings -gt 0) { "Yellow" } else { "Green" })
    Write-Host "  Unique Error Patterns: $($analysis.ErrorPatterns.Count)" -ForegroundColor Gray
    Write-Host "  Unique Warning Patterns: $($analysis.WarningPatterns.Count)" -ForegroundColor Gray
    Write-Host ""

    if ($analysis.ErrorPatterns.Count -gt 0) {
        Write-Host "Top Error Patterns:" -ForegroundColor Red
        $analysis.ErrorPatterns.GetEnumerator() |
            Sort-Object Value -Descending |
            Select-Object -First 5 |
            ForEach-Object {
                $shortMsg = $_.Key.Substring(0, [Math]::Min(80, $_.Key.Length))
                Write-Host "  [$($_.Value)x] $shortMsg..." -ForegroundColor Gray
            }
        Write-Host ""
    }

    if ($analysis.PerformanceMetrics.PeakCPU -gt 0) {
        Write-Host "Performance Metrics:" -ForegroundColor Yellow
        Write-Host "  Peak CPU Usage: $([math]::Round($analysis.PerformanceMetrics.PeakCPU, 2))%" -ForegroundColor Gray
        Write-Host "  Peak Memory Available: $([math]::Round($analysis.PerformanceMetrics.PeakMemory, 2)) MB" -ForegroundColor Gray
        Write-Host ""
    }

    Write-Host "Recommendations:" -ForegroundColor Cyan
    foreach ($rec in $analysis.Recommendations) {
        Write-Host "  • $rec" -ForegroundColor Gray
    }
    Write-Host ""
}

if ($OutputFormat -eq 'JSON' -or $GenerateReport) {
    $jsonOutput = $analysis | ConvertTo-Json -Depth 5
    $jsonPath = Join-Path $LogPath "analysis-report-$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $jsonOutput | Out-File $jsonPath
    Write-Host "JSON report saved to: $jsonPath" -ForegroundColor Green
}

if ($OutputFormat -eq 'HTML' -or $GenerateReport) {
    $htmlPath = Join-Path $LogPath "analysis-report-$(Get-Date -Format 'yyyyMMdd_HHmmss').html"

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>GitHub Actions Runner Log Analysis</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; border-left: 4px solid #3498db; padding-left: 10px; }
        .metric { display: inline-block; margin: 10px 20px 10px 0; padding: 15px 25px; background: #ecf0f1; border-radius: 5px; }
        .metric-label { font-size: 12px; color: #7f8c8d; text-transform: uppercase; }
        .metric-value { font-size: 28px; font-weight: bold; color: #2c3e50; }
        .success { color: #27ae60; }
        .error { color: #e74c3c; }
        .warning { color: #f39c12; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th { background: #34495e; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ecf0f1; }
        tr:hover { background: #f8f9fa; }
        .recommendation { background: #e8f4f8; border-left: 4px solid #3498db; padding: 12px; margin: 10px 0; border-radius: 4px; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ecf0f1; color: #7f8c8d; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>GitHub Actions Runner Log Analysis Report</h1>
        <p><strong>Analysis Date:</strong> $($analysis.AnalysisDate)</p>
        <p><strong>Period:</strong> $($analysis.Period.StartDate.ToString('yyyy-MM-dd')) to $($analysis.Period.EndDate.ToString('yyyy-MM-dd')) ($($analysis.Period.Days) days)</p>

        <h2>Summary Metrics</h2>
        <div class="metric">
            <div class="metric-label">Log Files</div>
            <div class="metric-value">$($analysis.Summary.TotalLogFiles)</div>
        </div>
        <div class="metric">
            <div class="metric-label">Total Events</div>
            <div class="metric-value">$($analysis.Summary.TotalEvents)</div>
        </div>
        <div class="metric">
            <div class="metric-label">Errors</div>
            <div class="metric-value error">$($analysis.Summary.Errors)</div>
        </div>
        <div class="metric">
            <div class="metric-label">Warnings</div>
            <div class="metric-value warning">$($analysis.Summary.Warnings)</div>
        </div>

        <h2>Job Statistics</h2>
        <table>
            <tr><th>Status</th><th>Count</th><th>Percentage</th></tr>
            <tr><td>Successful</td><td class="success">$($analysis.JobStats.Successful)</td><td>$([math]::Round(($analysis.JobStats.Successful/$totalJobs)*100, 1))%</td></tr>
            <tr><td>Failed</td><td class="error">$($analysis.JobStats.Failed)</td><td>$([math]::Round(($analysis.JobStats.Failed/$totalJobs)*100, 1))%</td></tr>
            <tr><td>Cancelled</td><td>$($analysis.JobStats.Cancelled)</td><td>$([math]::Round(($analysis.JobStats.Cancelled/$totalJobs)*100, 1))%</td></tr>
        </table>

        <h2>Top Error Patterns</h2>
        <table>
            <tr><th>Occurrences</th><th>Error Message</th></tr>
            $(($analysis.ErrorPatterns.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10 | ForEach-Object {
                "<tr><td>$($_.Value)</td><td>$($_.Key)</td></tr>"
            }) -join "`n            ")
        </table>

        <h2>Recommendations</h2>
        $(($analysis.Recommendations | ForEach-Object {
            "<div class='recommendation'>$_</div>"
        }) -join "`n        ")

        <div class="footer">
            Generated by GitHub Actions Runner Log Analyzer | $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        </div>
    </div>
</body>
</html>
"@

    $html | Out-File $htmlPath
    Write-Host "HTML report saved to: $htmlPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Analysis Complete ===" -ForegroundColor Green
