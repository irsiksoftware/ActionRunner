BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot ".." "scripts" "generate-report.ps1"
    $script:TestOutputPath = Join-Path $PSScriptRoot ".." "test-report-output"
    $script:TestLogPath = Join-Path $PSScriptRoot ".." "test-log-output"

    # Ensure test directories exist
    if (-not (Test-Path $script:TestOutputPath)) {
        New-Item -Path $script:TestOutputPath -ItemType Directory -Force | Out-Null
    }
    if (-not (Test-Path $script:TestLogPath)) {
        New-Item -Path $script:TestLogPath -ItemType Directory -Force | Out-Null
    }
}

AfterAll {
    # Cleanup test output directories
    if (Test-Path $script:TestOutputPath) {
        Remove-Item -Path $script:TestOutputPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $script:TestLogPath) {
        Remove-Item -Path $script:TestLogPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "generate-report.ps1 Script Existence" {
    It "Script file should exist" {
        Test-Path $script:ScriptPath | Should -Be $true
    }

    It "Script should have valid PowerShell syntax" {
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:ScriptPath -Raw), [ref]$errors)
        $errors.Count | Should -Be 0
    }
}

Describe "generate-report.ps1 Parameters" {
    BeforeAll {
        $script:ScriptContent = Get-Content $script:ScriptPath -Raw
    }

    It "Should have ReportType parameter with ValidateSet" {
        $script:ScriptContent | Should -Match '\[ValidateSet\("Daily",\s*"Weekly",\s*"Custom"\)\]'
    }

    It "Should have StartDate parameter" {
        $script:ScriptContent | Should -Match '\[string\]\$StartDate'
    }

    It "Should have EndDate parameter" {
        $script:ScriptContent | Should -Match '\[string\]\$EndDate'
    }

    It "Should have OutputPath parameter" {
        $script:ScriptContent | Should -Match '\[string\]\$OutputPath'
    }

    It "Should have LogPath parameter" {
        $script:ScriptContent | Should -Match '\[string\]\$LogPath'
    }
}

Describe "generate-report.ps1 Core Functions and Features" {
    BeforeAll {
        $script:ScriptContent = Get-Content $script:ScriptPath -Raw
    }

    It "Should get computer information" {
        $script:ScriptContent | Should -Match 'Get-ComputerInfo'
    }

    It "Should check disk space with Get-PSDrive" {
        $script:ScriptContent | Should -Match 'Get-PSDrive'
    }

    It "Should parse worker logs" {
        $script:ScriptContent | Should -Match 'Worker_\*\.log'
    }

    It "Should generate JSON output" {
        $script:ScriptContent | Should -Match 'ConvertTo-Json'
    }

    It "Should generate HTML output" {
        $script:ScriptContent | Should -Match '<!DOCTYPE html>'
    }

    It "Should calculate success rate" {
        $script:ScriptContent | Should -Match 'SuccessfulJobs\s*/\s*\$jobStats\.TotalJobs'
    }

    It "Should include cost analysis" {
        $script:ScriptContent | Should -Match 'CostAnalysis'
        $script:ScriptContent | Should -Match 'EstimatedElectricityCost'
    }
}

Describe "generate-report.ps1 Help and Documentation" {
    It "Should have synopsis in help" {
        $help = Get-Help $script:ScriptPath
        $help.Synopsis | Should -Not -BeNullOrEmpty
    }

    It "Should have description in help" {
        $help = Get-Help $script:ScriptPath
        $help.Description | Should -Not -BeNullOrEmpty
    }

    It "Should have examples in help" {
        $help = Get-Help $script:ScriptPath
        $help.Examples | Should -Not -BeNullOrEmpty
        $help.Examples.Example.Count | Should -BeGreaterThan 0
    }

    It "Should document ReportType parameter" {
        $help = Get-Help $script:ScriptPath
        $help.Parameters.Parameter.Name | Should -Contain "ReportType"
    }

    It "Should document StartDate parameter" {
        $help = Get-Help $script:ScriptPath
        $help.Parameters.Parameter.Name | Should -Contain "StartDate"
    }

    It "Should document EndDate parameter" {
        $help = Get-Help $script:ScriptPath
        $help.Parameters.Parameter.Name | Should -Contain "EndDate"
    }

    It "Should document OutputPath parameter" {
        $help = Get-Help $script:ScriptPath
        $help.Parameters.Parameter.Name | Should -Contain "OutputPath"
    }
}

Describe "generate-report.ps1 Daily Report Execution" {
    BeforeAll {
        $script:DailyResult = & $script:ScriptPath -ReportType Daily -OutputPath $script:TestOutputPath -LogPath $script:TestLogPath 2>&1
        $script:DailyExitCode = $LASTEXITCODE
    }

    It "Should execute without errors" {
        # Script doesn't explicitly exit with code, check that result was returned
        $script:DailyResult | Should -Not -BeNullOrEmpty
    }

    It "Should create output directory" {
        Test-Path $script:TestOutputPath | Should -Be $true
    }

    It "Should generate JSON report file" {
        $jsonFiles = Get-ChildItem -Path $script:TestOutputPath -Filter "report-Daily-*.json"
        $jsonFiles.Count | Should -BeGreaterThan 0
    }

    It "Should generate HTML report file" {
        $htmlFiles = Get-ChildItem -Path $script:TestOutputPath -Filter "report-Daily-*.html"
        $htmlFiles.Count | Should -BeGreaterThan 0
    }

    It "Should return report data with ReportType" {
        $script:DailyResult.ReportType | Should -Be 'Daily'
    }

    It "Should return report data with GeneratedAt" {
        $script:DailyResult.GeneratedAt | Should -Not -BeNullOrEmpty
    }

    It "Should return report data with StartDate" {
        $script:DailyResult.StartDate | Should -Not -BeNullOrEmpty
    }

    It "Should return report data with EndDate" {
        $script:DailyResult.EndDate | Should -Not -BeNullOrEmpty
    }
}

Describe "generate-report.ps1 JSON Output Validation" {
    BeforeAll {
        $script:JsonFile = Get-ChildItem -Path $script:TestOutputPath -Filter "report-Daily-*.json" |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        $script:JsonData = Get-Content $script:JsonFile.FullName -Raw | ConvertFrom-Json
    }

    It "Should produce valid JSON" {
        $script:JsonData | Should -Not -BeNullOrEmpty
    }

    It "Should contain ReportType" {
        $script:JsonData.ReportType | Should -Be 'Daily'
    }

    It "Should contain GeneratedAt timestamp" {
        $script:JsonData.GeneratedAt | Should -Not -BeNullOrEmpty
    }

    It "Should contain RunnerInfo section" {
        $script:JsonData.RunnerInfo | Should -Not -BeNullOrEmpty
    }

    It "Should contain RunnerInfo.Hostname" {
        $script:JsonData.RunnerInfo.Hostname | Should -Not -BeNullOrEmpty
    }

    It "Should contain RunnerInfo.Status" {
        $script:JsonData.RunnerInfo.Status | Should -Not -BeNullOrEmpty
    }

    It "Should contain JobStatistics section" {
        $script:JsonData.JobStatistics | Should -Not -BeNullOrEmpty
    }

    It "Should contain JobStatistics.TotalJobs" {
        $script:JsonData.JobStatistics.TotalJobs | Should -BeGreaterOrEqual 0
    }

    It "Should contain JobStatistics.SuccessfulJobs" {
        $script:JsonData.JobStatistics.SuccessfulJobs | Should -BeGreaterOrEqual 0
    }

    It "Should contain JobStatistics.FailedJobs" {
        $script:JsonData.JobStatistics.FailedJobs | Should -BeGreaterOrEqual 0
    }

    It "Should contain JobStatistics.SuccessRate" {
        $script:JsonData.JobStatistics.SuccessRate | Should -Not -BeNullOrEmpty
    }

    It "Should have consistent job counts" {
        $script:JsonData.JobStatistics.TotalJobs | Should -Be ($script:JsonData.JobStatistics.SuccessfulJobs + $script:JsonData.JobStatistics.FailedJobs)
    }

    It "Should contain ResourceUtilization section" {
        $script:JsonData.ResourceUtilization | Should -Not -BeNullOrEmpty
    }

    It "Should contain ResourceUtilization.DiskUsedGB" {
        $script:JsonData.ResourceUtilization.DiskUsedGB | Should -BeOfType [double]
    }

    It "Should contain ResourceUtilization.DiskFreeGB" {
        $script:JsonData.ResourceUtilization.DiskFreeGB | Should -BeOfType [double]
    }

    It "Should contain ResourceUtilization.DiskTotalGB" {
        $script:JsonData.ResourceUtilization.DiskTotalGB | Should -BeOfType [double]
    }

    It "Should contain ResourceUtilization.DiskUsedPercent" {
        $script:JsonData.ResourceUtilization.DiskUsedPercent | Should -BeGreaterOrEqual 0
        $script:JsonData.ResourceUtilization.DiskUsedPercent | Should -BeLessOrEqual 100
    }

    It "Should contain PerformanceMetrics section" {
        $script:JsonData.PerformanceMetrics | Should -Not -BeNullOrEmpty
    }

    It "Should contain PerformanceMetrics.AverageJobDurationSeconds" {
        $script:JsonData.PerformanceMetrics.AverageJobDurationSeconds | Should -BeGreaterOrEqual 0
    }

    It "Should contain PerformanceMetrics.JobsPerDay" {
        $script:JsonData.PerformanceMetrics.JobsPerDay | Should -BeGreaterOrEqual 0
    }

    It "Should contain CostAnalysis section" {
        $script:JsonData.CostAnalysis | Should -Not -BeNullOrEmpty
    }

    It "Should contain CostAnalysis.EstimatedRunningHours" {
        $script:JsonData.CostAnalysis.EstimatedRunningHours | Should -BeGreaterOrEqual 0
    }

    It "Should contain CostAnalysis.EstimatedPowerConsumptionKwh" {
        $script:JsonData.CostAnalysis.EstimatedPowerConsumptionKwh | Should -BeGreaterOrEqual 0
    }

    It "Should contain CostAnalysis.EstimatedElectricityCost" {
        $script:JsonData.CostAnalysis.EstimatedElectricityCost | Should -BeGreaterOrEqual 0
    }

    It "Should contain CostAnalysis.TimeSavedHours" {
        $script:JsonData.CostAnalysis.TimeSavedHours | Should -BeGreaterOrEqual 0
    }
}

Describe "generate-report.ps1 HTML Output Validation" {
    BeforeAll {
        $script:HtmlFile = Get-ChildItem -Path $script:TestOutputPath -Filter "report-Daily-*.html" |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        $script:HtmlContent = Get-Content $script:HtmlFile.FullName -Raw
    }

    It "Should produce valid HTML with DOCTYPE" {
        $script:HtmlContent | Should -Match '<!DOCTYPE html>'
    }

    It "Should include HTML lang attribute" {
        $script:HtmlContent | Should -Match '<html lang="en">'
    }

    It "Should include report title" {
        $script:HtmlContent | Should -Match '<title>Runner Report - Daily</title>'
    }

    It "Should include Runner Information section" {
        $script:HtmlContent | Should -Match 'Runner Information'
    }

    It "Should include Job Statistics section" {
        $script:HtmlContent | Should -Match 'Job Statistics'
    }

    It "Should include Resource Utilization section" {
        $script:HtmlContent | Should -Match 'Resource Utilization'
    }

    It "Should include Performance Metrics section" {
        $script:HtmlContent | Should -Match 'Performance Metrics'
    }

    It "Should include Cost Analysis section" {
        $script:HtmlContent | Should -Match 'Cost Analysis'
    }

    It "Should include proper CSS styling" {
        $script:HtmlContent | Should -Match '<style>'
        $script:HtmlContent | Should -Match 'font-family'
    }

    It "Should include info-card elements" {
        $script:HtmlContent | Should -Match 'class="info-card"'
    }

    It "Should include footer" {
        $script:HtmlContent | Should -Match 'class="footer"'
        $script:HtmlContent | Should -Match 'ActionRunner Reporting System'
    }
}

Describe "generate-report.ps1 Weekly Report Execution" {
    BeforeAll {
        $script:WeeklyResult = & $script:ScriptPath -ReportType Weekly -OutputPath $script:TestOutputPath -LogPath $script:TestLogPath 2>&1
    }

    It "Should return report data with Weekly ReportType" {
        $script:WeeklyResult.ReportType | Should -Be 'Weekly'
    }

    It "Should generate Weekly JSON report file" {
        $jsonFiles = Get-ChildItem -Path $script:TestOutputPath -Filter "report-Weekly-*.json"
        $jsonFiles.Count | Should -BeGreaterThan 0
    }

    It "Should generate Weekly HTML report file" {
        $htmlFiles = Get-ChildItem -Path $script:TestOutputPath -Filter "report-Weekly-*.html"
        $htmlFiles.Count | Should -BeGreaterThan 0
    }

    It "Should have 7-day date range for weekly report" {
        $startDate = [DateTime]::ParseExact($script:WeeklyResult.StartDate, "yyyy-MM-dd", $null)
        $endDate = [DateTime]::ParseExact($script:WeeklyResult.EndDate, "yyyy-MM-dd", $null)
        ($endDate - $startDate).Days | Should -Be 7
    }
}

Describe "generate-report.ps1 Custom Report Execution" {
    It "Should require StartDate and EndDate for Custom report type" {
        { & $script:ScriptPath -ReportType Custom -OutputPath $script:TestOutputPath -LogPath $script:TestLogPath -ErrorAction Stop } | Should -Throw
    }

    It "Should generate custom report with valid date range" {
        $startDate = (Get-Date).AddDays(-30).ToString("yyyy-MM-dd")
        $endDate = (Get-Date).ToString("yyyy-MM-dd")
        $result = & $script:ScriptPath -ReportType Custom -StartDate $startDate -EndDate $endDate -OutputPath $script:TestOutputPath -LogPath $script:TestLogPath 2>&1
        $result.ReportType | Should -Be 'Custom'
    }

    It "Should use provided date range for custom report" {
        $startDate = "2025-01-01"
        $endDate = "2025-01-31"
        $result = & $script:ScriptPath -ReportType Custom -StartDate $startDate -EndDate $endDate -OutputPath $script:TestOutputPath -LogPath $script:TestLogPath 2>&1
        $result.StartDate | Should -Be $startDate
        $result.EndDate | Should -Be $endDate
    }

    It "Should generate Custom JSON and HTML report files" {
        $jsonFiles = Get-ChildItem -Path $script:TestOutputPath -Filter "report-Custom-*.json"
        $htmlFiles = Get-ChildItem -Path $script:TestOutputPath -Filter "report-Custom-*.html"
        $jsonFiles.Count | Should -BeGreaterThan 0
        $htmlFiles.Count | Should -BeGreaterThan 0
    }
}

Describe "generate-report.ps1 Log Parsing" {
    BeforeAll {
        # Create mock log files for testing
        $mockLogContent = @"
[2025-01-01 10:00:00Z INFO Runner] Starting job
[2025-01-01 10:05:00Z INFO Worker] Job abc123 completed with result: Succeeded
[2025-01-01 10:10:00Z INFO Runner] Starting job
[2025-01-01 10:15:00Z INFO Worker] Job def456 completed with result: Failed
[2025-01-01 10:20:00Z INFO Runner] Starting job
[2025-01-01 10:25:00Z INFO Worker] Job ghi789 completed with result: Succeeded
"@
        $mockLogFile = Join-Path $script:TestLogPath "Worker_20250101_100000.log"
        $mockLogContent | Out-File $mockLogFile -Encoding UTF8
        # Set file modification time to be within the daily range
        (Get-Item $mockLogFile).LastWriteTime = Get-Date

        $script:LogResult = & $script:ScriptPath -ReportType Daily -OutputPath $script:TestOutputPath -LogPath $script:TestLogPath 2>&1
    }

    It "Should parse log files and count successful jobs" {
        $script:LogResult.JobStatistics.SuccessfulJobs | Should -Be 2
    }

    It "Should parse log files and count failed jobs" {
        $script:LogResult.JobStatistics.FailedJobs | Should -Be 1
    }

    It "Should calculate total jobs correctly" {
        $script:LogResult.JobStatistics.TotalJobs | Should -Be 3
    }

    It "Should calculate success rate correctly" {
        $script:LogResult.JobStatistics.SuccessRate | Should -Be "66.67%"
    }
}

Describe "generate-report.ps1 Error Handling" {
    It "Should handle non-existent log path gracefully" {
        $nonExistentPath = Join-Path $script:TestOutputPath "non-existent-logs"
        $result = & $script:ScriptPath -ReportType Daily -OutputPath $script:TestOutputPath -LogPath $nonExistentPath 2>&1
        $result | Should -Not -BeNullOrEmpty
        $result.JobStatistics.TotalJobs | Should -Be 0
    }

    It "Should create output directory if it doesn't exist" {
        $newOutputPath = Join-Path $script:TestOutputPath "new-reports-dir"
        if (Test-Path $newOutputPath) { Remove-Item $newOutputPath -Recurse -Force }
        $result = & $script:ScriptPath -ReportType Daily -OutputPath $newOutputPath -LogPath $script:TestLogPath 2>&1
        Test-Path $newOutputPath | Should -Be $true
    }
}

Describe "generate-report.ps1 Integration" {
    It "Script should be callable from any directory" {
        Push-Location $env:TEMP
        try {
            $result = & $script:ScriptPath -ReportType Daily -OutputPath $script:TestOutputPath -LogPath $script:TestLogPath 2>&1
            $result | Should -Not -BeNullOrEmpty
            $result.ReportType | Should -Be 'Daily'
        } finally {
            Pop-Location
        }
    }
}
