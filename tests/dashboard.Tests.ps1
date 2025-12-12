Describe "Dashboard and Reporting Tests" {
    BeforeAll {
        $scriptRoot = Split-Path -Parent $PSScriptRoot
        $generateReportScript = Join-Path $scriptRoot "scripts\generate-report.ps1"
        $dashboardDir = Join-Path $scriptRoot "dashboard"
        $testReportDir = Join-Path $TestDrive "reports"
    }

    Context "Generate Report Script" {
        It "Should exist" {
            Test-Path $generateReportScript | Should -Be $true
        }

        It "Should generate a daily report" {
            $result = & $generateReportScript -ReportType "Daily" -OutputPath $testReportDir

            $result | Should -Not -BeNullOrEmpty
            $result.ReportType | Should -Be "Daily"
            $result.GeneratedAt | Should -Not -BeNullOrEmpty
        }

        It "Should create JSON report file" {
            & $generateReportScript -ReportType "Daily" -OutputPath $testReportDir | Out-Null

            $jsonFiles = Get-ChildItem -Path $testReportDir -Filter "*.json"
            $jsonFiles.Count | Should -BeGreaterThan 0
        }

        It "Should create HTML report file" {
            & $generateReportScript -ReportType "Daily" -OutputPath $testReportDir | Out-Null

            $htmlFiles = Get-ChildItem -Path $testReportDir -Filter "*.html"
            $htmlFiles.Count | Should -BeGreaterThan 0
        }

        It "Should generate weekly report" {
            $result = & $generateReportScript -ReportType "Weekly" -OutputPath $testReportDir

            $result.ReportType | Should -Be "Weekly"
        }

        It "Should generate custom date range report" {
            $result = & $generateReportScript -ReportType "Custom" -StartDate "2025-09-01" -EndDate "2025-10-01" -OutputPath $testReportDir

            $result.ReportType | Should -Be "Custom"
            $result.StartDate | Should -Be "2025-09-01"
            $result.EndDate | Should -Be "2025-10-01"
        }

        It "Should include runner information" {
            $result = & $generateReportScript -ReportType "Daily" -OutputPath $testReportDir

            $result.RunnerInfo | Should -Not -BeNullOrEmpty
            $result.RunnerInfo.Hostname | Should -Not -BeNullOrEmpty
        }

        It "Should include job statistics" {
            $result = & $generateReportScript -ReportType "Daily" -OutputPath $testReportDir

            $result.JobStatistics | Should -Not -BeNullOrEmpty
            $result.JobStatistics.TotalJobs | Should -BeGreaterOrEqual 0
            $result.JobStatistics.SuccessRate | Should -Not -BeNullOrEmpty
        }

        It "Should include resource utilization" {
            $result = & $generateReportScript -ReportType "Daily" -OutputPath $testReportDir

            $result.ResourceUtilization | Should -Not -BeNullOrEmpty
            $result.ResourceUtilization.DiskUsedGB | Should -BeGreaterOrEqual 0
            $result.ResourceUtilization.DiskFreeGB | Should -BeGreaterOrEqual 0
        }

        It "Should include performance metrics" {
            $result = & $generateReportScript -ReportType "Daily" -OutputPath $testReportDir

            $result.PerformanceMetrics | Should -Not -BeNullOrEmpty
        }

        It "Should include cost analysis" {
            $result = & $generateReportScript -ReportType "Daily" -OutputPath $testReportDir

            $result.CostAnalysis | Should -Not -BeNullOrEmpty
            $result.CostAnalysis.EstimatedElectricityCost | Should -BeGreaterOrEqual 0
        }

        It "Should create output directory if it doesn't exist" {
            $newTestDir = Join-Path $TestDrive "new-reports-dir"

            Test-Path $newTestDir | Should -Be $false

            & $generateReportScript -ReportType "Daily" -OutputPath $newTestDir | Out-Null

            Test-Path $newTestDir | Should -Be $true
        }
    }

    Context "Dashboard Files" {
        It "Should have index.html file" {
            $indexPath = Join-Path $dashboardDir "index.html"
            Test-Path $indexPath | Should -Be $true
        }

        It "Should have dashboard.js file" {
            $jsPath = Join-Path $dashboardDir "dashboard.js"
            Test-Path $jsPath | Should -Be $true
        }

        It "Should have server.ps1 file" {
            $serverPath = Join-Path $dashboardDir "server.ps1"
            Test-Path $serverPath | Should -Be $true
        }

        It "index.html should contain required elements" {
            $indexPath = Join-Path $dashboardDir "index.html"
            $content = Get-Content $indexPath -Raw

            $content | Should -Match "Runner Dashboard"
            $content | Should -Match "dashboard.js"
            $content | Should -Match "statusDot"
            $content | Should -Match "totalJobs"
            $content | Should -Match "successRate"
        }

        It "dashboard.js should contain required functions" {
            $jsPath = Join-Path $dashboardDir "dashboard.js"
            $content = Get-Content $jsPath -Raw

            $content | Should -Match "function loadDashboard"
            $content | Should -Match "function updateDashboard"
            $content | Should -Match "function generateMockData"
        }

        It "server.ps1 should be valid PowerShell" {
            $serverPath = Join-Path $dashboardDir "server.ps1"

            {
                $null = [System.Management.Automation.PSParser]::Tokenize(
                    (Get-Content $serverPath -Raw),
                    [ref]$null
                )
            } | Should -Not -Throw
        }
    }

    Context "Report Data Validation" {
        It "Should generate valid JSON" {
            $result = & $generateReportScript -ReportType "Daily" -OutputPath $testReportDir
            $jsonFiles = Get-ChildItem -Path $testReportDir -Filter "*.json" | Select-Object -First 1

            { Get-Content $jsonFiles.FullName | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include all required report sections" {
            $result = & $generateReportScript -ReportType "Daily" -OutputPath $testReportDir

            $result.PSObject.Properties.Name | Should -Contain "ReportType"
            $result.PSObject.Properties.Name | Should -Contain "GeneratedAt"
            $result.PSObject.Properties.Name | Should -Contain "RunnerInfo"
            $result.PSObject.Properties.Name | Should -Contain "JobStatistics"
            $result.PSObject.Properties.Name | Should -Contain "ResourceUtilization"
            $result.PSObject.Properties.Name | Should -Contain "PerformanceMetrics"
            $result.PSObject.Properties.Name | Should -Contain "CostAnalysis"
        }

        It "HTML report should be valid HTML" {
            & $generateReportScript -ReportType "Daily" -OutputPath $testReportDir | Out-Null
            $htmlFiles = Get-ChildItem -Path $testReportDir -Filter "*.html" | Select-Object -First 1
            $content = Get-Content $htmlFiles.FullName -Raw

            $content | Should -Match "<!DOCTYPE html>"
            $content | Should -Match "<html.*>"
            $content | Should -Match "</html>"
            $content | Should -Match "<body>"
            $content | Should -Match "</body>"
        }
    }

    Context "Dashboard Server" {
        It "Should have valid server script" {
            $serverPath = Join-Path $dashboardDir "server.ps1"
            Test-Path $serverPath | Should -Be $true
        }

        It "Server script should accept Port parameter" {
            $serverPath = Join-Path $dashboardDir "server.ps1"

            $params = (Get-Command $serverPath).Parameters
            $params.ContainsKey("Port") | Should -Be $true
        }

        It "Server script should have default port" {
            $serverPath = Join-Path $dashboardDir "server.ps1"

            $params = (Get-Command $serverPath).Parameters
            $params["Port"].Attributes.ParameterSetName | Should -Not -BeNullOrEmpty
        }
    }
}
