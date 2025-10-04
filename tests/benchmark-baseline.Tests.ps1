BeforeAll {
    $script:BaselinePath = Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "data") "benchmark-baseline.json"
}

Describe "Benchmark Baseline Data" {
    Context "File Existence and Structure" {
        It "Baseline file should exist" {
            Test-Path $script:BaselinePath | Should -Be $true
        }

        It "Should be valid JSON" {
            { Get-Content $script:BaselinePath -Raw | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should have version field" {
            $baseline = Get-Content $script:BaselinePath -Raw | ConvertFrom-Json
            $baseline.version | Should -Not -BeNullOrEmpty
        }

        It "Should have description field" {
            $baseline = Get-Content $script:BaselinePath -Raw | ConvertFrom-Json
            $baseline.description | Should -Not -BeNullOrEmpty
        }

        It "Should have baselines section" {
            $baseline = Get-Content $script:BaselinePath -Raw | ConvertFrom-Json
            $baseline.baselines | Should -Not -BeNullOrEmpty
        }
    }

    Context "DiskIO Baseline" {
        BeforeAll {
            $script:Baseline = Get-Content $script:BaselinePath -Raw | ConvertFrom-Json
        }

        It "Should have DiskIO baseline" {
            $script:Baseline.baselines.DiskIO | Should -Not -BeNullOrEmpty
        }

        It "Should have MinWriteSpeedMBps" {
            $script:Baseline.baselines.DiskIO.MinWriteSpeedMBps | Should -BeGreaterThan 0
        }

        It "Should have MinReadSpeedMBps" {
            $script:Baseline.baselines.DiskIO.MinReadSpeedMBps | Should -BeGreaterThan 0
        }

        It "Should have MinSmallFileOpsPerSec" {
            $script:Baseline.baselines.DiskIO.MinSmallFileOpsPerSec | Should -BeGreaterThan 0
        }

        It "Read speed should be higher than or equal to write speed" {
            $script:Baseline.baselines.DiskIO.MinReadSpeedMBps |
                Should -BeGreaterOrEqual $script:Baseline.baselines.DiskIO.MinWriteSpeedMBps
        }
    }

    Context "Network Baseline" {
        BeforeAll {
            $script:Baseline = Get-Content $script:BaselinePath -Raw | ConvertFrom-Json
        }

        It "Should have Network baseline" {
            $script:Baseline.baselines.Network | Should -Not -BeNullOrEmpty
        }

        It "Should have MaxGitHubLatencyMs" {
            $script:Baseline.baselines.Network.MaxGitHubLatencyMs | Should -BeGreaterThan 0
        }

        It "Should have MinDownloadSpeedMBps" {
            $script:Baseline.baselines.Network.MinDownloadSpeedMBps | Should -BeGreaterThan 0
        }

        It "Latency threshold should be reasonable (< 2000ms)" {
            $script:Baseline.baselines.Network.MaxGitHubLatencyMs | Should -BeLessThan 2000
        }
    }

    Context "DotNet Baseline" {
        BeforeAll {
            $script:Baseline = Get-Content $script:BaselinePath -Raw | ConvertFrom-Json
        }

        It "Should have DotNet baseline" {
            $script:Baseline.baselines.DotNet | Should -Not -BeNullOrEmpty
        }

        It "Should have MaxBuildTimeSeconds" {
            $script:Baseline.baselines.DotNet.MaxBuildTimeSeconds | Should -BeGreaterThan 0
        }

        It "Build time threshold should be reasonable (< 120s)" {
            $script:Baseline.baselines.DotNet.MaxBuildTimeSeconds | Should -BeLessThan 120
        }
    }

    Context "Python Baseline" {
        BeforeAll {
            $script:Baseline = Get-Content $script:BaselinePath -Raw | ConvertFrom-Json
        }

        It "Should have Python baseline" {
            $script:Baseline.baselines.Python | Should -Not -BeNullOrEmpty
        }

        It "Should have MaxStartupTimeMs" {
            $script:Baseline.baselines.Python.MaxStartupTimeMs | Should -BeGreaterThan 0
        }

        It "Should have MaxSimpleScriptTimeMs" {
            $script:Baseline.baselines.Python.MaxSimpleScriptTimeMs | Should -BeGreaterThan 0
        }
    }

    Context "Git Baseline" {
        BeforeAll {
            $script:Baseline = Get-Content $script:BaselinePath -Raw | ConvertFrom-Json
        }

        It "Should have Git baseline" {
            $script:Baseline.baselines.Git | Should -Not -BeNullOrEmpty
        }

        It "Should have MaxCloneTimeSeconds" {
            $script:Baseline.baselines.Git.MaxCloneTimeSeconds | Should -BeGreaterThan 0
        }

        It "Should have MaxStatusTimeMs" {
            $script:Baseline.baselines.Git.MaxStatusTimeMs | Should -BeGreaterThan 0
        }
    }

    Context "Performance Grades" {
        BeforeAll {
            $script:Baseline = Get-Content $script:BaselinePath -Raw | ConvertFrom-Json
        }

        It "Should have performanceGrades section" {
            $script:Baseline.performanceGrades | Should -Not -BeNullOrEmpty
        }

        It "Should have DiskIO performance grades" {
            $script:Baseline.performanceGrades.DiskIO | Should -Not -BeNullOrEmpty
            $script:Baseline.performanceGrades.DiskIO.WriteSpeed | Should -Not -BeNullOrEmpty
            $script:Baseline.performanceGrades.DiskIO.ReadSpeed | Should -Not -BeNullOrEmpty
        }

        It "Should have Network performance grades" {
            $script:Baseline.performanceGrades.Network | Should -Not -BeNullOrEmpty
            $script:Baseline.performanceGrades.Network.Latency | Should -Not -BeNullOrEmpty
        }

        It "Performance grade thresholds should be ordered correctly (Excellent > Good > Adequate > Poor)" {
            $writeSpeed = $script:Baseline.performanceGrades.DiskIO.WriteSpeed
            $writeSpeed.Excellent | Should -BeGreaterThan $writeSpeed.Good
            $writeSpeed.Good | Should -BeGreaterThan $writeSpeed.Adequate
            $writeSpeed.Adequate | Should -BeGreaterThan $writeSpeed.Poor
        }
    }

    Context "Baseline Comparison Functionality" {
        BeforeAll {
            $script:Baseline = Get-Content $script:BaselinePath -Raw | ConvertFrom-Json
        }

        It "Should be usable for comparing benchmark results" {
            # Simulate a benchmark result
            $mockResult = @{
                DiskIO = @{
                    AvgWriteSpeedMBps = 250
                    AvgReadSpeedMBps = 300
                }
            }

            # Compare against baseline
            $writePass = $mockResult.DiskIO.AvgWriteSpeedMBps -ge $script:Baseline.baselines.DiskIO.MinWriteSpeedMBps
            $readPass = $mockResult.DiskIO.AvgReadSpeedMBps -ge $script:Baseline.baselines.DiskIO.MinReadSpeedMBps

            $writePass | Should -Be $true
            $readPass | Should -Be $true
        }

        It "Should correctly identify failing performance" {
            # Simulate a poor benchmark result
            $mockResult = @{
                DiskIO = @{
                    AvgWriteSpeedMBps = 50  # Below baseline of 100
                }
            }

            $writePass = $mockResult.DiskIO.AvgWriteSpeedMBps -ge $script:Baseline.baselines.DiskIO.MinWriteSpeedMBps
            $writePass | Should -Be $false
        }
    }

    Context "Data Integrity" {
        BeforeAll {
            $script:Baseline = Get-Content $script:BaselinePath -Raw | ConvertFrom-Json
        }

        It "Should have notes field" {
            $script:Baseline.notes | Should -Not -BeNullOrEmpty
        }

        It "Notes should be an array" {
            $script:Baseline.notes -is [array] | Should -Be $true
        }

        It "Should have creation date" {
            $script:Baseline.created | Should -Not -BeNullOrEmpty
        }

        It "All baseline categories should have descriptions" {
            $script:Baseline.baselines.DiskIO.description | Should -Not -BeNullOrEmpty
            $script:Baseline.baselines.Network.description | Should -Not -BeNullOrEmpty
            $script:Baseline.baselines.DotNet.description | Should -Not -BeNullOrEmpty
            $script:Baseline.baselines.Python.description | Should -Not -BeNullOrEmpty
            $script:Baseline.baselines.Git.description | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Baseline Integration with Benchmark Runner" {
    BeforeAll {
        $script:BenchmarkScript = Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "scripts") "benchmark-runner.ps1"
    }

    It "Benchmark script should exist" {
        Test-Path $script:BenchmarkScript | Should -Be $true
    }

    It "Baseline path should be accessible from benchmark context" {
        $baselineFromScript = Join-Path (Join-Path (Split-Path $script:BenchmarkScript -Parent) "..") (Join-Path "data" "benchmark-baseline.json")
        Test-Path $baselineFromScript | Should -Be $true
    }
}
