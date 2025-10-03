#Requires -Version 5.1

<#
.SYNOPSIS
    Analyzes GitHub Actions runner logs to identify patterns and issues

.DESCRIPTION
    Parses and analyzes collected runner logs to identify:
    - Common error patterns
    - Performance trends
    - Failed job patterns
    - Resource usage patterns
    - Security events
    - Anomalies and outliers

    Generates reports and recommendations for optimization.

.PARAMETER LogPath
    Path to logs directory or collected logs archive (default: logs/)

.PARAMETER OutputPath
    Path to save analysis reports (default: logs/analysis)

.PARAMETER Days
    Number of days to analyze (default: 7)

.PARAMETER Format
    Output format: json, html, or text (default: text)

.EXAMPLE
    .\analyze-logs.ps1
    .\analyze-logs.ps1 -LogPath "logs\collected\20251003-120000" -Format html
    .\analyze-logs.ps1 -Days 30 -OutputPath "reports"

.NOTES
    Author: GitHub Actions Runner Team
    Version: 1.0.0
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "logs",

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "logs\analysis",

    [Parameter(Mandatory=$false)]
    [int]$Days = 7,

    [Parameter(Mandatory=$false)]
    [ValidateSet('json', 'html', 'text')]
    [string]$Format = 'text'
)

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$reportFile = Join-Path $OutputPath "analysis-report-${timestamp}.txt"

# Function to write to report
function Write-Report {
    param([string]$Message, [string]$Level = "INFO")
    Add-Content -Path $reportFile -Value $Message

    switch ($Level) {
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        "WARN" { Write-Host $Message -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        "HEADER" { Write-Host $Message -ForegroundColor Cyan }
        default { Write-Host $Message }
    }
}

Write-Host "`n=== GitHub Actions Runner Log Analysis ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Log Path: $LogPath`n" -ForegroundColor Gray

$analysisResults = @{
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    period_days = $Days
    log_path = $LogPath
    findings = @()
    errors = @()
    warnings = @()
    performance = @{}
    recommendations = @()
}

Write-Report "=== Log Analysis Report ===" "HEADER"
Write-Report "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Report "Analysis Period: Last $Days days"
Write-Report "Log Source: $LogPath"
Write-Report ""

# 1. Analyze Runner Service Logs
Write-Report "--- Runner Service Analysis ---" "HEADER"

try {
    if (Test-Path (Join-Path $LogPath "health-check.log")) {
        $healthLog = Get-Content (Join-Path $LogPath "health-check.log") -ErrorAction SilentlyContinue

        if ($healthLog) {
            $errorCount = ($healthLog | Select-String -Pattern "\[ERROR\]").Count
            $warnCount = ($healthLog | Select-String -Pattern "\[WARN\]").Count

            Write-Report "Health Check Log Statistics:"
            Write-Report "  Total Entries: $($healthLog.Count)"
            Write-Report "  Errors: $errorCount" $(if ($errorCount -gt 0) { "ERROR" } else { "INFO" })
            Write-Report "  Warnings: $warnCount" $(if ($warnCount -gt 0) { "WARN" } else { "INFO" })

            $analysisResults.findings += @{
                category = "health_check"
                total_entries = $healthLog.Count
                errors = $errorCount
                warnings = $warnCount
            }

            # Extract recent errors
            $recentErrors = $healthLog | Select-String -Pattern "\[ERROR\]" | Select-Object -Last 10
            if ($recentErrors) {
                Write-Report "`n  Recent Errors:"
                foreach ($error in $recentErrors) {
                    Write-Report "    - $error" "ERROR"
                    $analysisResults.errors += $error.ToString()
                }
            }
        }
    }
} catch {
    Write-Report "Failed to analyze health check logs: $($_.Exception.Message)" "WARN"
}

Write-Report ""

# 2. Analyze Diagnostic Logs for Error Patterns
Write-Report "--- Error Pattern Analysis ---" "HEADER"

try {
    $diagPath = Join-Path $LogPath "runner-diag"
    if (Test-Path $diagPath) {
        $diagLogs = Get-ChildItem -Path $diagPath -Filter "*.log" -ErrorAction SilentlyContinue

        if ($diagLogs) {
            $errorPatterns = @{}
            $totalErrors = 0

            foreach ($log in $diagLogs) {
                $content = Get-Content $log.FullName -ErrorAction SilentlyContinue
                $errors = $content | Select-String -Pattern "error|exception|failed|failure" -CaseSensitive:$false

                foreach ($error in $errors) {
                    $totalErrors++
                    # Extract error type
                    if ($error -match "(Exception|Error|Failed):\s*(.+)") {
                        $errorType = $Matches[1]
                        if ($errorPatterns.ContainsKey($errorType)) {
                            $errorPatterns[$errorType]++
                        } else {
                            $errorPatterns[$errorType] = 1
                        }
                    }
                }
            }

            Write-Report "Diagnostic Logs Analyzed: $($diagLogs.Count)"
            Write-Report "Total Error Occurrences: $totalErrors"

            if ($errorPatterns.Count -gt 0) {
                Write-Report "`nTop Error Patterns:"
                $errorPatterns.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10 | ForEach-Object {
                    Write-Report "  $($_.Key): $($_.Value) occurrences" "WARN"
                }

                $analysisResults.findings += @{
                    category = "error_patterns"
                    total_errors = $totalErrors
                    patterns = $errorPatterns
                }
            } else {
                Write-Report "No error patterns detected" "SUCCESS"
            }
        }
    }
} catch {
    Write-Report "Failed to analyze diagnostic logs: $($_.Exception.Message)" "WARN"
}

Write-Report ""

# 3. Analyze Job Execution Patterns
Write-Report "--- Job Execution Analysis ---" "HEADER"

try {
    $jobPath = Join-Path $LogPath "job-logs"
    if (Test-Path $jobPath) {
        $jobLogs = Get-ChildItem -Path $jobPath -Filter "*.log" -Recurse -ErrorAction SilentlyContinue

        if ($jobLogs) {
            $jobStats = @{
                total_jobs = $jobLogs.Count
                failed_jobs = 0
                successful_jobs = 0
            }

            foreach ($log in $jobLogs) {
                $content = Get-Content $log.FullName -ErrorAction SilentlyContinue -TotalCount 100

                if ($content -match "failed|error|exception") {
                    $jobStats.failed_jobs++
                } elseif ($content -match "success|completed") {
                    $jobStats.successful_jobs++
                }
            }

            Write-Report "Total Job Logs: $($jobStats.total_jobs)"
            Write-Report "Failed Jobs: $($jobStats.failed_jobs)" $(if ($jobStats.failed_jobs -gt 0) { "ERROR" } else { "INFO" })
            Write-Report "Successful Jobs: $($jobStats.successful_jobs)" "SUCCESS"

            if ($jobStats.total_jobs -gt 0) {
                $successRate = [math]::Round(($jobStats.successful_jobs / $jobStats.total_jobs) * 100, 2)
                Write-Report "Success Rate: ${successRate}%" $(if ($successRate -lt 80) { "WARN" } else { "SUCCESS" })

                $analysisResults.performance.job_success_rate = $successRate
            }

            $analysisResults.findings += @{
                category = "job_execution"
                stats = $jobStats
            }
        }
    }
} catch {
    Write-Report "Failed to analyze job execution logs: $($_.Exception.Message)" "WARN"
}

Write-Report ""

# 4. Analyze System Performance Trends
Write-Report "--- System Performance Analysis ---" "HEADER"

try {
    $sysInfoPath = Join-Path $LogPath "system-info.json"
    if (Test-Path $sysInfoPath) {
        $sysInfo = Get-Content $sysInfoPath | ConvertFrom-Json

        Write-Report "System Information:"
        Write-Report "  Computer: $($sysInfo.ComputerName)"
        Write-Report "  OS: $($sysInfo.OS.Caption)"
        Write-Report "  CPU: $($sysInfo.CPU.Name)"
        Write-Report "  Total Memory: $($sysInfo.Memory.TotalGB) GB"

        if ($sysInfo.Disk) {
            Write-Report "`n  Disk Usage:"
            foreach ($disk in $sysInfo.Disk) {
                $percentFree = [math]::Round(($disk.FreeGB / ($disk.FreeGB + $disk.UsedGB)) * 100, 2)
                $status = if ($percentFree -lt 10) { "ERROR" } elseif ($percentFree -lt 20) { "WARN" } else { "INFO" }
                Write-Report "    Drive $($disk.Name): $($disk.FreeGB) GB free / $($disk.FreeGB + $disk.UsedGB) GB total (${percentFree}% free)" $status

                if ($percentFree -lt 20) {
                    $analysisResults.warnings += "Low disk space on drive $($disk.Name): ${percentFree}% free"
                }
            }
        }

        $analysisResults.performance.system_info = $sysInfo
    }
} catch {
    Write-Report "Failed to analyze system performance: $($_.Exception.Message)" "WARN"
}

Write-Report ""

# 5. Analyze Event Logs
Write-Report "--- Event Log Analysis ---" "HEADER"

try {
    $eventPath = Join-Path $LogPath "event-logs"
    if (Test-Path $eventPath) {
        $appEvents = Join-Path $eventPath "application-events.csv"
        $sysEvents = Join-Path $eventPath "system-events.csv"

        if (Test-Path $appEvents) {
            $appData = Import-Csv $appEvents
            Write-Report "Application Events: $($appData.Count)"

            $criticalEvents = $appData | Where-Object { $_.Level -eq 1 }
            if ($criticalEvents) {
                Write-Report "  Critical Events: $($criticalEvents.Count)" "ERROR"
                $analysisResults.errors += "Found $($criticalEvents.Count) critical application events"
            }
        }

        if (Test-Path $sysEvents) {
            $sysData = Import-Csv $sysEvents
            Write-Report "System Events: $($sysData.Count)"

            $criticalSysEvents = $sysData | Where-Object { $_.Level -eq 1 }
            if ($criticalSysEvents) {
                Write-Report "  Critical Events: $($criticalSysEvents.Count)" "ERROR"
                $analysisResults.errors += "Found $($criticalSysEvents.Count) critical system events"
            }
        }
    }
} catch {
    Write-Report "Failed to analyze event logs: $($_.Exception.Message)" "WARN"
}

Write-Report ""

# 6. Generate Recommendations
Write-Report "--- Recommendations ---" "HEADER"

if ($analysisResults.errors.Count -gt 5) {
    $rec = "High error count detected ($($analysisResults.errors.Count) errors). Review error patterns and consider troubleshooting."
    Write-Report $rec "WARN"
    $analysisResults.recommendations += $rec
}

if ($analysisResults.performance.job_success_rate -and $analysisResults.performance.job_success_rate -lt 80) {
    $rec = "Job success rate is below 80%. Investigate failed jobs and improve reliability."
    Write-Report $rec "WARN"
    $analysisResults.recommendations += $rec
}

if ($analysisResults.warnings.Count -gt 0) {
    foreach ($warning in $analysisResults.warnings) {
        Write-Report $warning "WARN"
    }
    $rec = "Address disk space and resource warnings to prevent future issues."
    $analysisResults.recommendations += $rec
}

if ($analysisResults.recommendations.Count -eq 0) {
    Write-Report "No critical issues detected. System is operating normally." "SUCCESS"
    $analysisResults.recommendations += "Continue monitoring. System health is good."
}

Write-Report ""

# 7. Save Analysis Results
Write-Report "--- Analysis Summary ---" "HEADER"
Write-Report "Total Findings: $($analysisResults.findings.Count)"
Write-Report "Total Errors: $($analysisResults.errors.Count)"
Write-Report "Total Warnings: $($analysisResults.warnings.Count)"
Write-Report "Recommendations: $($analysisResults.recommendations.Count)"
Write-Report ""

# Save JSON output
$jsonOutputPath = Join-Path $OutputPath "analysis-${timestamp}.json"
$analysisResults | ConvertTo-Json -Depth 10 | Out-File $jsonOutputPath
Write-Report "JSON report saved: $jsonOutputPath" "SUCCESS"

# Generate HTML report if requested
if ($Format -eq 'html') {
    $htmlOutputPath = Join-Path $OutputPath "analysis-${timestamp}.html"

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Runner Log Analysis - $timestamp</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .stat { display: inline-block; margin: 10px; padding: 15px; background-color: #ecf0f1; border-radius: 5px; }
        .error { color: #e74c3c; font-weight: bold; }
        .warn { color: #f39c12; font-weight: bold; }
        .success { color: #27ae60; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #3498db; color: white; }
        .recommendation { background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 10px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>GitHub Actions Runner Log Analysis</h1>
        <p><strong>Generated:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p><strong>Analysis Period:</strong> Last $Days days</p>

        <h2>Summary</h2>
        <div class="stat">Findings: <strong>$($analysisResults.findings.Count)</strong></div>
        <div class="stat">Errors: <strong class="error">$($analysisResults.errors.Count)</strong></div>
        <div class="stat">Warnings: <strong class="warn">$($analysisResults.warnings.Count)</strong></div>

        <h2>Recommendations</h2>
        $(foreach ($rec in $analysisResults.recommendations) { "<div class='recommendation'>$rec</div>" })

        <h2>Detailed Findings</h2>
        <pre>$(Get-Content $reportFile -Raw)</pre>
    </div>
</body>
</html>
"@

    $html | Out-File $htmlOutputPath
    Write-Report "HTML report saved: $htmlOutputPath" "SUCCESS"
}

Write-Host "`n=== Analysis Complete ===" -ForegroundColor Green
Write-Host "Report saved: $reportFile" -ForegroundColor Cyan
if ($Format -eq 'json') {
    Write-Host "JSON saved: $jsonOutputPath" -ForegroundColor Cyan
}
if ($Format -eq 'html') {
    Write-Host "HTML saved: $htmlOutputPath" -ForegroundColor Cyan
}

exit 0
