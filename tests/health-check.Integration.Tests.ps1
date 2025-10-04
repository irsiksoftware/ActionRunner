<#
.SYNOPSIS
    Integration tests for the health-check.ps1 script.

.DESCRIPTION
    These tests verify the health-check script's integration with real system
    components including disk space, CPU, RAM, network connectivity, and GPU.
#>

Describe "health-check.ps1 Integration Tests" -Tag "Integration" {
    BeforeAll {
        # Set script path
        $script:scriptPath = Join-Path $PSScriptRoot "..\scripts\health-check.ps1"

        # Verify script exists
        if (-not (Test-Path $script:scriptPath)) {
            throw "Script not found: $script:scriptPath"
        }

        # Get current system state for comparison
        $script:testDrive = "C"
        $script:testWorkDirectory = $PSScriptRoot
    }

    Context "Disk Space Integration" {
        It "Should accurately report current disk space" {
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            # Verify against actual system disk space
            $actualDisk = Get-PSDrive -Name $script:testDrive
            $actualFreeGB = [math]::Round($actualDisk.Free / 1GB, 2)
            $actualTotalGB = [math]::Round(($actualDisk.Used + $actualDisk.Free) / 1GB, 2)

            # Allow for small variance due to timing differences
            $json.Checks.DiskSpace.FreeSpaceGB | Should -BeGreaterThan ($actualFreeGB - 1)
            $json.Checks.DiskSpace.FreeSpaceGB | Should -BeLessThan ($actualFreeGB + 1)
            $json.Checks.DiskSpace.TotalSpaceGB | Should -BeGreaterThan ($actualTotalGB - 1)
            $json.Checks.DiskSpace.TotalSpaceGB | Should -BeLessThan ($actualTotalGB + 1)
        }

        It "Should correctly identify low disk space condition" {
            # Use impossibly high threshold
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 99999 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            $json.Checks.DiskSpace.Status | Should -Be 'Unhealthy'
            $json.OverallHealth | Should -Be 'Unhealthy'
        }

        It "Should correctly identify sufficient disk space condition" {
            # Use very low threshold
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            $json.Checks.DiskSpace.Status | Should -Be 'Healthy'
            $json.Checks.DiskSpace.FreeSpaceGB | Should -BeGreaterThan 1
        }

        It "Should report correct drive letter" {
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            $json.Checks.DiskSpace.Drive | Should -Match '^[A-Z]:$'
        }

        It "Should calculate used percentage correctly" {
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            $json.Checks.DiskSpace.UsedPercentage | Should -BeGreaterThan 0
            $json.Checks.DiskSpace.UsedPercentage | Should -BeLessThan 100

            # Verify calculation
            $free = $json.Checks.DiskSpace.FreeSpaceGB
            $total = $json.Checks.DiskSpace.TotalSpaceGB
            $used = $total - $free
            $expectedPercentage = [math]::Round(($used / $total) * 100, 2)

            # Allow small rounding differences
            $json.Checks.DiskSpace.UsedPercentage | Should -BeGreaterThan ($expectedPercentage - 0.5)
            $json.Checks.DiskSpace.UsedPercentage | Should -BeLessThan ($expectedPercentage + 0.5)
        }
    }

    Context "System Resources Integration" {
        It "Should report current CPU usage" {
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            $json.Checks.SystemResources.CPUUsagePercentage | Should -Not -BeNullOrEmpty
            $json.Checks.SystemResources.CPUUsagePercentage | Should -BeGreaterOrEqual 0
            $json.Checks.SystemResources.CPUUsagePercentage | Should -BeLessOrEqual 100
        }

        It "Should report current RAM usage" {
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            $json.Checks.SystemResources.RAMUsagePercentage | Should -Not -BeNullOrEmpty
            $json.Checks.SystemResources.RAMUsagePercentage | Should -BeGreaterThan 0
            $json.Checks.SystemResources.RAMUsagePercentage | Should -BeLessOrEqual 100
        }

        It "Should accurately report total RAM" {
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            # Verify against actual system RAM
            $actualOS = Get-CimInstance -ClassName Win32_OperatingSystem
            $actualTotalRAM = [math]::Round($actualOS.TotalVisibleMemorySize / 1MB, 2)

            # Should match within 0.1 GB
            $json.Checks.SystemResources.TotalRAMGB | Should -BeGreaterThan ($actualTotalRAM - 0.1)
            $json.Checks.SystemResources.TotalRAMGB | Should -BeLessThan ($actualTotalRAM + 0.1)
        }

        It "Should calculate RAM values consistently" {
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            $total = $json.Checks.SystemResources.TotalRAMGB
            $used = $json.Checks.SystemResources.UsedRAMGB
            $free = $json.Checks.SystemResources.FreeRAMGB

            # Total should equal used + free (within rounding tolerance)
            $calculated = $used + $free
            $calculated | Should -BeGreaterThan ($total - 0.1)
            $calculated | Should -BeLessThan ($total + 0.1)
        }

        It "Should mark status as Warning when resources are high" {
            # This test is informational - we can't force high resource usage
            # but we verify the status field exists and is valid
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            $json.Checks.SystemResources.Status | Should -BeIn @('Healthy', 'Warning', 'Error')
        }
    }

    Context "Network Connectivity Integration" {
        It "Should test connectivity to github.com" {
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            $githubResult = $json.Checks.NetworkConnectivity.Results | Where-Object { $_.Host -eq 'github.com' }
            $githubResult | Should -Not -BeNullOrEmpty
            $githubResult.Connected | Should -BeOfType [bool]
        }

        It "Should test connectivity to api.github.com" {
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            $apiResult = $json.Checks.NetworkConnectivity.Results | Where-Object { $_.Host -eq 'api.github.com' }
            $apiResult | Should -Not -BeNullOrEmpty
            $apiResult.Connected | Should -BeOfType [bool]
        }

        It "Should report overall connectivity status correctly" {
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            $allConnected = ($json.Checks.NetworkConnectivity.Results | Where-Object { -not $_.Connected }).Count -eq 0

            if ($allConnected) {
                $json.Checks.NetworkConnectivity.Status | Should -Be 'Healthy'
            } else {
                $json.Checks.NetworkConnectivity.Status | Should -Be 'Unhealthy'
            }
        }

        It "Should perform actual network ping" {
            # Verify independently that we can reach GitHub
            $canPing = Test-Connection -ComputerName github.com -Count 1 -Quiet -ErrorAction SilentlyContinue

            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            $githubResult = $json.Checks.NetworkConnectivity.Results | Where-Object { $_.Host -eq 'github.com' }

            # Health check result should match independent ping
            $githubResult.Connected | Should -Be $canPing
        }
    }

    Context "GPU Detection Integration" {
        It "Should detect GPU if available" {
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            # Verify against actual GPU detection
            $actualGPUs = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue |
                          Where-Object { $_.AdapterRAM -gt 0 }

            if ($actualGPUs) {
                $json.Checks.GPU.Status | Should -BeIn @('Healthy', 'Info')
                $json.Checks.GPU.GPUCount | Should -Be $actualGPUs.Count
                $json.Checks.GPU.GPUs | Should -Not -BeNullOrEmpty
            } else {
                $json.Checks.GPU.Status | Should -Be 'Info'
                $json.Checks.GPU.Message | Should -Match 'No GPU detected'
            }
        }

        It "Should report GPU VRAM correctly if GPU exists" {
            $actualGPUs = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue |
                          Where-Object { $_.AdapterRAM -gt 0 }

            if ($actualGPUs) {
                $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
                $json = $output | ConvertFrom-Json

                foreach ($gpu in $json.Checks.GPU.GPUs) {
                    $gpu.VRAMGB | Should -BeGreaterThan 0
                    $gpu.Name | Should -Not -BeNullOrEmpty
                }
            } else {
                Set-ItResult -Skipped -Because "No GPU detected on system"
            }
        }
    }

    Context "Runner Service Integration" {
        It "Should check for runner service" {
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            $json.Checks.RunnerService | Should -Not -BeNullOrEmpty
            $json.Checks.RunnerService.Status | Should -BeIn @('Healthy', 'Warning', 'Unhealthy', 'Error')
        }

        It "Should match actual service status" {
            $actualService = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue | Select-Object -First 1

            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            if ($actualService) {
                $json.Checks.RunnerService.ServiceName | Should -Be $actualService.Name
                $json.Checks.RunnerService.ServiceStatus | Should -Be $actualService.Status.ToString()

                if ($actualService.Status -eq 'Running') {
                    $json.Checks.RunnerService.Status | Should -Be 'Healthy'
                } else {
                    $json.Checks.RunnerService.Status | Should -Be 'Unhealthy'
                }
            } else {
                $json.Checks.RunnerService.Status | Should -Be 'Warning'
                $json.Checks.RunnerService.Message | Should -Match 'No runner service found'
            }
        }
    }

    Context "Last Job Execution Integration" {
        It "Should check for diagnostic logs" {
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            $json.Checks.LastJobExecution | Should -Not -BeNullOrEmpty
            $json.Checks.LastJobExecution.Status | Should -BeIn @('Healthy', 'Warning', 'Info', 'Error')
        }

        It "Should find log files if they exist" {
            # Use a test work directory
            $testLogPath = Join-Path $script:testWorkDirectory "_diag"

            if (Test-Path $testLogPath) {
                $actualLogs = Get-ChildItem -Path $testLogPath -Filter "Worker_*.log" -ErrorAction SilentlyContinue |
                              Sort-Object LastWriteTime -Descending |
                              Select-Object -First 1

                $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
                $json = $output | ConvertFrom-Json

                if ($actualLogs) {
                    $json.Checks.LastJobExecution.LatestLogFile | Should -Be $actualLogs.Name
                    $json.Checks.LastJobExecution.HoursSinceLastJob | Should -Not -BeNullOrEmpty
                } else {
                    $json.Checks.LastJobExecution.Message | Should -Match 'No job logs found'
                }
            } else {
                Set-ItResult -Skipped -Because "No diagnostic directory in test work directory"
            }
        }
    }

    Context "Overall Health Status Integration" {
        It "Should report Unhealthy when any critical check fails" {
            # Force unhealthy with impossible disk threshold
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 99999 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            $json.OverallHealth | Should -Be 'Unhealthy'
        }

        It "Should report Healthy when all checks pass" {
            # Assume network is working and use low disk threshold
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            # Can be Warning if runner service not found, but should not be Unhealthy
            $json.OverallHealth | Should -BeIn @('Healthy', 'Warning')
        }

        It "Should include timestamp in ISO 8601 format" {
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            { [DateTime]::Parse($json.Timestamp) } | Should -Not -Throw
        }

        It "Should complete execution within reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory

            $stopwatch.Stop()

            # Health check should complete in under 30 seconds
            $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 30
        }
    }

    Context "Exit Code Integration" {
        It "Should exit with 0 when healthy or warning" {
            & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory | Out-Null
            $LASTEXITCODE | Should -Be 0
        }

        It "Should exit with 1 when unhealthy" {
            & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 99999 -WorkDirectory $script:testWorkDirectory | Out-Null
            $LASTEXITCODE | Should -Be 1
        }

        It "Should set exit code based on overall health" {
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            $json = $output | ConvertFrom-Json

            if ($json.OverallHealth -eq 'Unhealthy') {
                $LASTEXITCODE | Should -Be 1
            } else {
                $LASTEXITCODE | Should -Be 0
            }
        }
    }

    Context "Output Format Integration" {
        It "Should produce parseable JSON in JSON mode" {
            $output = & $script:scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should produce readable text in Text mode" {
            $output = & $script:scriptPath -OutputFormat Text -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory

            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match 'GitHub Actions Runner Health Check'
            $output | Should -Match 'Overall Health:'
        }

        It "Should include all check results in text output" {
            $output = & $script:scriptPath -OutputFormat Text -DiskThresholdGB 1 -WorkDirectory $script:testWorkDirectory

            $output | Should -Match 'RunnerService'
            $output | Should -Match 'DiskSpace'
            $output | Should -Match 'SystemResources'
            $output | Should -Match 'GPU'
            $output | Should -Match 'NetworkConnectivity'
        }
    }
}
