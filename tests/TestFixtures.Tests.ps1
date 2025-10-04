BeforeAll {
    # Import the TestFixtures module
    Import-Module (Join-Path $PSScriptRoot "TestFixtures.psm1") -Force
}

Describe "TestFixtures Module" {
    Context "Mock GitHub API Responses" {
        It "Should return successful runner response" {
            $response = Get-MockRunnerResponse -Scenario 'Success'

            $response.id | Should -Be 12345
            $response.name | Should -Be 'test-runner'
            $response.os | Should -Be 'windows'
            $response.status | Should -Be 'online'
            $response.labels.Count | Should -BeGreaterThan 0
        }

        It "Should throw exception for expired token" {
            { Get-MockRunnerResponse -Scenario 'TokenExpired' } | Should -Throw
        }

        It "Should throw exception for not found" {
            { Get-MockRunnerResponse -Scenario 'NotFound' } | Should -Throw
        }

        It "Should throw exception for rate limited" {
            { Get-MockRunnerResponse -Scenario 'RateLimited' } | Should -Throw
        }
    }

    Context "Mock Docker Container Lists" {
        It "Should return running containers" {
            $containers = Get-MockDockerContainerList -Scenario 'Running'

            $containers.Count | Should -Be 2
            $containers[0].Status | Should -Match '^Up'
            $containers[1].Status | Should -Match '^Up'
        }

        It "Should return stopped containers" {
            $containers = Get-MockDockerContainerList -Scenario 'Stopped'

            $containers.Count | Should -Be 1
            $containers[0].Status | Should -Match '^Exited'
        }

        It "Should return mixed container states" {
            $containers = Get-MockDockerContainerList -Scenario 'Mixed'

            $containers.Count | Should -Be 2
            $containers[0].Status | Should -Match '^Up'
            $containers[1].Status | Should -Match '^Exited'
        }

        It "Should return empty list when no containers" {
            $containers = Get-MockDockerContainerList -Scenario 'Empty'

            $containers.Count | Should -Be 0
        }
    }

    Context "Mock Runner Directory" {
        It "Should create basic directory structure" {
            $testPath = New-TestDirectory -Prefix 'MockRunner'

            try {
                New-MockRunnerDirectory -Path $testPath

                Test-Path (Join-Path $testPath '_diag') | Should -Be $true
                Test-Path (Join-Path $testPath '_work') | Should -Be $true
                Test-Path (Join-Path $testPath 'bin') | Should -Be $true
            }
            finally {
                Remove-TestDirectory -Path $testPath
            }
        }

        It "Should create logs when specified" {
            $testPath = New-TestDirectory -Prefix 'MockRunnerLogs'

            try {
                New-MockRunnerDirectory -Path $testPath -IncludeLogs

                $logs = Get-ChildItem (Join-Path $testPath '_diag') -Filter '*.log'
                $logs.Count | Should -BeGreaterThan 0
            }
            finally {
                Remove-TestDirectory -Path $testPath
            }
        }

        It "Should create config when specified" {
            $testPath = New-TestDirectory -Prefix 'MockRunnerConfig'

            try {
                New-MockRunnerDirectory -Path $testPath -IncludeConfig

                Test-Path (Join-Path $testPath '.runner') | Should -Be $true
                Test-Path (Join-Path $testPath '.credentials') | Should -Be $true
            }
            finally {
                Remove-TestDirectory -Path $testPath
            }
        }
    }

    Context "Mock Health Check Results" {
        It "Should return healthy status" {
            $result = Get-MockHealthCheckResult -Status 'Healthy'

            $result.RunnerStatus | Should -Be 'Running'
            $result.DiskSpaceGB | Should -BeGreaterThan 100
            $result.Issues.Count | Should -Be 0
        }

        It "Should return warning status with issues" {
            $result = Get-MockHealthCheckResult -Status 'Warning'

            $result.RunnerStatus | Should -Be 'Running'
            $result.DiskSpaceGB | Should -BeLessThan 50
            $result.Issues.Count | Should -BeGreaterThan 0
        }

        It "Should return critical status" {
            $result = Get-MockHealthCheckResult -Status 'Critical'

            $result.RunnerStatus | Should -Be 'Stopped'
            $result.DiskSpaceGB | Should -BeLessThan 10
            $result.Issues.Count | Should -BeGreaterThan 2
        }

        It "Should return degraded status" {
            $result = Get-MockHealthCheckResult -Status 'Degraded'

            $result.RunnerStatus | Should -Be 'Running'
            $result.ActiveJobs | Should -BeGreaterThan 5
        }
    }

    Context "Mock Runner Configuration" {
        It "Should return default configuration" {
            $config = Get-MockRunnerConfig -Type 'Default'

            $config.RunnerName | Should -Not -BeNullOrEmpty
            $config.WorkDirectory | Should -Not -BeNullOrEmpty
            $config.Labels | Should -Contain 'self-hosted'
        }

        It "Should return custom configuration with additional labels" {
            $config = Get-MockRunnerConfig -Type 'Custom'

            $config.Labels | Should -Contain 'gpu'
            $config.MaxJobs | Should -BeGreaterThan 0
        }

        It "Should return minimal configuration" {
            $config = Get-MockRunnerConfig -Type 'Minimal'

            $config.Keys.Count | Should -BeLessThan 5
        }

        It "Should return enterprise configuration" {
            $config = Get-MockRunnerConfig -Type 'Enterprise'

            $config.RunnerGroup | Should -Be 'production'
            $config.MaxJobs | Should -BeGreaterThan 5
        }
    }

    Context "Mock Docker Configuration" {
        It "Should return valid Docker configuration" {
            $config = Get-MockDockerConfig

            $config.MaxCPUs | Should -BeGreaterThan 0
            $config.MaxMemoryGB | Should -BeGreaterThan 0
            $config.LogDriver | Should -Not -BeNullOrEmpty
        }
    }

    Context "Mock Service Status" {
        It "Should return running service" {
            $service = Get-MockServiceStatus -Status 'Running'

            $service.Status | Should -Be 'Running'
            $service.CanStop | Should -Be $true
        }

        It "Should return stopped service" {
            $service = Get-MockServiceStatus -Status 'Stopped'

            $service.Status | Should -Be 'Stopped'
            $service.CanStop | Should -Be $false
        }

        It "Should accept custom service name" {
            $customName = 'actions.runner.custom.runner'
            $service = Get-MockServiceStatus -ServiceName $customName

            $service.Name | Should -Be $customName
        }
    }

    Context "Mock Performance Metrics" {
        It "Should return normal load metrics" {
            $metrics = Get-MockPerformanceMetrics -LoadLevel 'Normal'

            $metrics.CPU.UsagePercent | Should -BeLessThan 50
            $metrics.Memory.UsagePercent | Should -BeLessThan 70
            $metrics.Disk.UsagePercent | Should -BeLessThan 70
        }

        It "Should return high load metrics" {
            $metrics = Get-MockPerformanceMetrics -LoadLevel 'High'

            $metrics.CPU.UsagePercent | Should -BeGreaterThan 70
            $metrics.Memory.UsagePercent | Should -BeGreaterThan 70
        }

        It "Should return low load metrics" {
            $metrics = Get-MockPerformanceMetrics -LoadLevel 'Low'

            $metrics.CPU.UsagePercent | Should -BeLessThan 20
            $metrics.Memory.UsagePercent | Should -BeLessThan 30
        }

        It "Should include all required metric categories" {
            $metrics = Get-MockPerformanceMetrics

            $metrics.CPU | Should -Not -BeNull
            $metrics.Memory | Should -Not -BeNull
            $metrics.Disk | Should -Not -BeNull
            $metrics.Network | Should -Not -BeNull
        }
    }

    Context "Mock Job History" {
        It "Should generate requested number of jobs" {
            $count = 15
            $jobs = Get-MockJobHistory -Count $count

            $jobs.Count | Should -Be $count
        }

        It "Should respect success rate" {
            $count = 100
            $successRate = 0.8
            $jobs = Get-MockJobHistory -Count $count -SuccessRate $successRate

            $successful = ($jobs | Where-Object { $_.Conclusion -eq 'Success' }).Count
            $actualRate = $successful / $count

            # Allow 10% variance
            $actualRate | Should -BeGreaterOrEqual ($successRate - 0.1)
            $actualRate | Should -BeLessOrEqual ($successRate + 0.1)
        }

        It "Should include required job properties" {
            $jobs = Get-MockJobHistory -Count 5

            foreach ($job in $jobs) {
                $job.JobId | Should -Not -BeNull
                $job.JobName | Should -Not -BeNullOrEmpty
                $job.Status | Should -Not -BeNullOrEmpty
                $job.StartTime | Should -Not -BeNull
                $job.DurationSeconds | Should -BeGreaterThan 0
            }
        }
    }

    Context "Mock Error Logs" {
        It "Should generate network error logs" {
            $log = Get-MockErrorLog -ErrorType 'Network'

            $log | Should -Match 'Network'
            $log | Should -Match 'ERROR'
        }

        It "Should generate timeout error logs" {
            $log = Get-MockErrorLog -ErrorType 'Timeout'

            $log | Should -Match 'timeout'
            $log | Should -Match 'ERROR'
        }

        It "Should generate memory error logs" {
            $log = Get-MockErrorLog -ErrorType 'OutOfMemory'

            $log | Should -Match 'memory'
            $log | Should -Match 'ERROR'
        }

        It "Should generate disk error logs" {
            $log = Get-MockErrorLog -ErrorType 'DiskFull'

            $log | Should -Match 'disk'
            $log | Should -Match 'ERROR'
        }

        It "Should generate mixed error logs" {
            $log = Get-MockErrorLog -ErrorType 'Mixed'

            $log | Should -Match 'ERROR'
            $log | Should -Match 'WARN'
            $lines = $log -split "`n"
            $lines.Count | Should -BeGreaterThan 1
        }
    }

    Context "Test Helper Functions" {
        It "Should create unique test directories" {
            $dir1 = New-TestDirectory
            $dir2 = New-TestDirectory

            try {
                $dir1 | Should -Not -Be $dir2
                Test-Path $dir1 | Should -Be $true
                Test-Path $dir2 | Should -Be $true
            }
            finally {
                Remove-TestDirectory -Path $dir1
                Remove-TestDirectory -Path $dir2
            }
        }

        It "Should create directory with custom prefix" {
            $prefix = 'CustomTest'
            $dir = New-TestDirectory -Prefix $prefix

            try {
                $dir | Should -Match $prefix
                Test-Path $dir | Should -Be $true
            }
            finally {
                Remove-TestDirectory -Path $dir
            }
        }

        It "Should remove test directory and contents" {
            $dir = New-TestDirectory
            New-Item (Join-Path $dir 'testfile.txt') -ItemType File -Force | Out-Null

            Remove-TestDirectory -Path $dir

            Test-Path $dir | Should -Be $false
        }

        It "Should handle non-existent directory removal gracefully" {
            $fakePath = Join-Path $env:TEMP 'NonExistentDir-12345'

            { Remove-TestDirectory -Path $fakePath } | Should -Not -Throw
        }
    }
}
