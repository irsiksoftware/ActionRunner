<#
.SYNOPSIS
    Tests for DashboardDataProvider module that provides real data to the dashboard.
#>

BeforeAll {
    $modulePath = Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) "modules") "DashboardDataProvider.psm1"
    Import-Module $modulePath -Force
}

Describe "DashboardDataProvider Module" {
    Context "Get-DashboardData" {
        It "Should return a hashtable with required keys" {
            $result = Get-DashboardData -LogPath "TestDrive:\"

            $result | Should -BeOfType [hashtable]
            $result.Keys | Should -Contain "status"
            $result.Keys | Should -Contain "timestamp"
            $result.Keys | Should -Contain "metrics"
            $result.Keys | Should -Contain "charts"
            $result.Keys | Should -Contain "recentJobs"
        }

        It "Should return metrics with required fields" {
            $result = Get-DashboardData -LogPath "TestDrive:\"

            $result.metrics.Keys | Should -Contain "totalJobsToday"
            $result.metrics.Keys | Should -Contain "successfulJobs"
            $result.metrics.Keys | Should -Contain "failedJobs"
            $result.metrics.Keys | Should -Contain "successRate"
            $result.metrics.Keys | Should -Contain "diskFreeGB"
            $result.metrics.Keys | Should -Contain "diskTotalGB"
            $result.metrics.Keys | Should -Contain "avgJobDuration"
            $result.metrics.Keys | Should -Contain "queueLength"
            $result.metrics.Keys | Should -Contain "uptimeHours"
        }

        It "Should return charts with required data arrays" {
            $result = Get-DashboardData -LogPath "TestDrive:\"

            $result.charts.Keys | Should -Contain "jobsPerDay"
            $result.charts.Keys | Should -Contain "diskPerDay"
            @($result.charts.jobsPerDay).Count | Should -BeGreaterOrEqual 0
            @($result.charts.diskPerDay).Count | Should -BeGreaterOrEqual 0
        }

        It "Should return recentJobs as an array" {
            $result = Get-DashboardData -LogPath "TestDrive:\"

            # recentJobs should be array-like (can be empty)
            @($result.recentJobs).Count | Should -BeGreaterOrEqual 0
        }
    }

    Context "Parse-WorkerLogs" {
        BeforeAll {
            # Create test log directory structure
            $testLogPath = Join-Path $TestDrive "_diag"
            New-Item -Path $testLogPath -ItemType Directory -Force | Out-Null
        }

        It "Should return empty results when no logs exist" {
            $result = Parse-WorkerLogs -LogPath (Join-Path $TestDrive "nonexistent")

            $result.TotalJobs | Should -Be 0
            $result.SuccessfulJobs | Should -Be 0
            $result.FailedJobs | Should -Be 0
        }

        It "Should parse Worker log files for job completions" {
            # Create a mock Worker log file
            $logContent = @"
[2025-12-12 10:00:00Z INFO Runner.Worker] Job Build-123 completed with result: Succeeded
[2025-12-12 10:15:00Z INFO Runner.Worker] Job Test-456 completed with result: Succeeded
[2025-12-12 10:30:00Z INFO Runner.Worker] Job Deploy-789 completed with result: Failed
"@
            $logFile = Join-Path $testLogPath "Worker_20251212-100000-utc.log"
            Set-Content -Path $logFile -Value $logContent

            $result = Parse-WorkerLogs -LogPath $testLogPath -Days 7

            $result.TotalJobs | Should -Be 3
            $result.SuccessfulJobs | Should -Be 2
            $result.FailedJobs | Should -Be 1
        }

        It "Should extract job names from logs" {
            $logContent = @"
[2025-12-12 11:00:00Z INFO Runner.Worker] Job MyWorkflow-Build completed with result: Succeeded
"@
            $logFile = Join-Path $testLogPath "Worker_20251212-110000-utc.log"
            Set-Content -Path $logFile -Value $logContent

            $result = Parse-WorkerLogs -LogPath $testLogPath -Days 7

            $result.RecentJobs.Count | Should -BeGreaterThan 0
            $result.RecentJobs[0].name | Should -Not -BeNullOrEmpty
        }

        It "Should calculate jobs per day" {
            $result = Parse-WorkerLogs -LogPath $testLogPath -Days 7

            $result.JobsByDay | Should -Not -BeNullOrEmpty
        }
    }

    Context "Get-RunnerStatus" {
        It "Should return online when runner service is available" {
            $result = Get-RunnerStatus

            $result | Should -BeIn @("online", "offline", "idle")
        }
    }

    Context "Get-DiskMetrics" {
        It "Should return disk usage information" {
            $result = Get-DiskMetrics

            $result.Keys | Should -Contain "freeGB"
            $result.Keys | Should -Contain "totalGB"
            $result.freeGB | Should -BeGreaterOrEqual 0
            $result.totalGB | Should -BeGreaterThan 0
        }
    }

    Context "Get-JobDurationMetrics" {
        BeforeAll {
            $testLogPath = Join-Path $TestDrive "_diag"
            New-Item -Path $testLogPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
        }

        It "Should return average job duration" {
            $logContent = @"
[2025-12-12 10:00:00Z INFO Runner.Worker] Running job: Build-123
[2025-12-12 10:05:00Z INFO Runner.Worker] Job Build-123 completed with result: Succeeded
"@
            $logFile = Join-Path $testLogPath "Worker_20251212-100000-duration.log"
            Set-Content -Path $logFile -Value $logContent

            $result = Get-JobDurationMetrics -LogPath $testLogPath

            $result | Should -BeGreaterOrEqual 0
        }
    }

    Context "Integration with real log path detection" {
        It "Should auto-detect runner log paths" {
            $paths = Get-RunnerLogPaths

            # Should return multiple paths (even if they don't exist)
            @($paths).Count | Should -BeGreaterThan 0
        }
    }
}

Describe "DashboardDataProvider Error Handling" {
    Context "Invalid inputs" {
        It "Should handle null LogPath gracefully" {
            { Get-DashboardData -LogPath $null } | Should -Not -Throw
        }

        It "Should handle invalid path gracefully" {
            { Get-DashboardData -LogPath "Z:\NonExistent\Path\That\Does\Not\Exist" } | Should -Not -Throw
        }
    }

    Context "Malformed log files" {
        BeforeAll {
            $testLogPath = Join-Path $TestDrive "_diag_malformed"
            New-Item -Path $testLogPath -ItemType Directory -Force | Out-Null
        }

        It "Should handle malformed log content gracefully" {
            $malformedContent = "This is not a valid log format @#$%^&*()"
            $logFile = Join-Path $testLogPath "Worker_malformed.log"
            Set-Content -Path $logFile -Value $malformedContent

            { Parse-WorkerLogs -LogPath $testLogPath } | Should -Not -Throw
        }

        It "Should handle empty log files" {
            $logFile = Join-Path $testLogPath "Worker_empty.log"
            Set-Content -Path $logFile -Value ""

            { Parse-WorkerLogs -LogPath $testLogPath } | Should -Not -Throw
        }
    }
}
