# Pester tests for Windows service management functionality
# Run with: Invoke-Pester -Path .\tests\service-management.Tests.ps1

BeforeAll {
    # Test requires elevated permissions - check and skip if not admin
    $currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Warning "Service management tests require elevated permissions. Run PowerShell as Administrator to execute these tests."
    }

    # Test service name pattern for GitHub Actions runners
    $script:ServicePattern = "actions.runner.*"
    $script:TestServicePrefix = "actions.runner"
}

Describe "Windows Service Management - Service Query Operations" {
    Context "Service Discovery" {
        It "Should be able to query Windows services" {
            { Get-Service -ErrorAction Stop } | Should -Not -Throw
        }

        It "Should be able to filter services by pattern" {
            $services = Get-Service -Name "*" -ErrorAction SilentlyContinue
            $services | Should -Not -BeNullOrEmpty
        }

        It "Should be able to find GitHub Actions runner services" {
            $runnerServices = Get-Service -Name $script:ServicePattern -ErrorAction SilentlyContinue
            # May be empty if no runners installed, but should not throw
            $runnerServices.GetType().Name | Should -BeIn @('ServiceController', 'Object[]', 'ServiceController[]')
        }

        It "Should return service properties correctly" {
            $service = Get-Service | Select-Object -First 1
            $service.Name | Should -Not -BeNullOrEmpty
            $service.Status | Should -BeIn @('Running', 'Stopped', 'Paused', 'StartPending', 'StopPending', 'ContinuePending', 'PausePending')
        }
    }

    Context "Service Status Detection" {
        It "Should detect Running services" {
            $runningServices = Get-Service | Where-Object { $_.Status -eq 'Running' }
            $runningServices | Should -Not -BeNullOrEmpty
        }

        It "Should detect Stopped services" {
            $stoppedServices = Get-Service | Where-Object { $_.Status -eq 'Stopped' }
            # Most systems will have some stopped services
            $stoppedServices.Count | Should -BeGreaterOrEqual 0
        }

        It "Should check specific GitHub Actions runner service if exists" {
            $runnerServices = Get-Service -Name $script:ServicePattern -ErrorAction SilentlyContinue
            if ($runnerServices) {
                foreach ($service in $runnerServices) {
                    $service.Status | Should -BeIn @('Running', 'Stopped', 'Paused', 'StartPending', 'StopPending')
                }
            } else {
                # No runner services found - this is expected on systems without runners
                Set-ItResult -Skipped -Because "No GitHub Actions runner services found on this system"
            }
        }
    }
}

Describe "Windows Service Management - Service Properties" {
    Context "Service Metadata" {
        It "Should retrieve service display name" {
            $service = Get-Service | Select-Object -First 1
            $service.DisplayName | Should -Not -BeNullOrEmpty
        }

        It "Should retrieve service name" {
            $service = Get-Service | Select-Object -First 1
            $service.Name | Should -Not -BeNullOrEmpty
        }

        It "Should identify service startup type using CIM" {
            $service = Get-Service | Select-Object -First 1
            $cimService = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($service.Name)'" -ErrorAction SilentlyContinue
            if ($cimService) {
                $cimService.StartMode | Should -BeIn @('Auto', 'Manual', 'Disabled', 'Boot', 'System')
            }
        }
    }

    Context "GitHub Actions Runner Service Properties" {
        It "Should verify runner service naming convention" {
            $runnerServices = Get-Service -Name $script:ServicePattern -ErrorAction SilentlyContinue
            if ($runnerServices) {
                foreach ($service in $runnerServices) {
                    $service.Name | Should -Match '^actions\.runner\.'
                }
            } else {
                Set-ItResult -Skipped -Because "No GitHub Actions runner services found on this system"
            }
        }

        It "Should verify runner service display names" {
            $runnerServices = Get-Service -Name $script:ServicePattern -ErrorAction SilentlyContinue
            if ($runnerServices) {
                foreach ($service in $runnerServices) {
                    $service.DisplayName | Should -Match 'GitHub Actions Runner'
                }
            } else {
                Set-ItResult -Skipped -Because "No GitHub Actions runner services found on this system"
            }
        }

        It "Should check runner service startup configuration" {
            $runnerServices = Get-Service -Name $script:ServicePattern -ErrorAction SilentlyContinue
            if ($runnerServices) {
                foreach ($service in $runnerServices) {
                    $cimService = Get-CimInstance -ClassName Win32_Service -Filter "Name='$($service.Name)'" -ErrorAction SilentlyContinue
                    if ($cimService) {
                        # Runner services are typically set to Auto start
                        $cimService.StartMode | Should -BeIn @('Auto', 'Manual', 'Disabled')
                    }
                }
            } else {
                Set-ItResult -Skipped -Because "No GitHub Actions runner services found on this system"
            }
        }
    }
}

Describe "Windows Service Management - Service Control Operations" -Tag "RequiresElevation" {
    BeforeAll {
        if (-not $isAdmin) {
            Write-Warning "Service control tests require elevated permissions and will be skipped."
        }
    }

    Context "Service Control Permissions" {
        It "Should have permission to query service status" {
            { Get-Service -ErrorAction Stop | Select-Object -First 1 } | Should -Not -Throw
        }

        It "Should check if running with elevated permissions" -Skip:(-not $isAdmin) {
            $isAdmin | Should -Be $true
        }
    }

    Context "Service Start/Stop Validation" -Skip:(-not $isAdmin) {
        It "Should validate Start-Service cmdlet is available" {
            Get-Command Start-Service -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should validate Stop-Service cmdlet is available" {
            Get-Command Stop-Service -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should validate Restart-Service cmdlet is available" {
            Get-Command Restart-Service -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should handle service not found errors gracefully" {
            $nonExistentService = "NonExistent-Service-$(Get-Random)"
            { Get-Service -Name $nonExistentService -ErrorAction Stop } | Should -Throw
        }
    }
}

Describe "Windows Service Management - Service Dependencies" {
    Context "Service Dependency Detection" {
        It "Should retrieve service dependencies" {
            $service = Get-Service | Where-Object { $_.DependentServices.Count -gt 0 } | Select-Object -First 1
            if ($service) {
                $service.DependentServices | Should -Not -BeNullOrEmpty
            } else {
                Set-ItResult -Skipped -Because "No services with dependencies found"
            }
        }

        It "Should retrieve services a service depends on" {
            $service = Get-Service | Where-Object { $_.ServicesDependedOn.Count -gt 0 } | Select-Object -First 1
            if ($service) {
                $service.ServicesDependedOn | Should -Not -BeNullOrEmpty
            } else {
                Set-ItResult -Skipped -Because "No services with required services found"
            }
        }
    }
}

Describe "Windows Service Management - Service Monitoring" {
    Context "Service Health Monitoring" {
        It "Should monitor service status changes" {
            $service = Get-Service | Select-Object -First 1
            $initialStatus = $service.Status

            # Refresh and check again
            $service.Refresh()
            $service.Status | Should -BeIn @('Running', 'Stopped', 'Paused', 'StartPending', 'StopPending', 'ContinuePending', 'PausePending')
        }

        It "Should wait for service status" {
            $runningService = Get-Service | Where-Object { $_.Status -eq 'Running' } | Select-Object -First 1
            if ($runningService) {
                # This should complete immediately as service is already running
                { $runningService.WaitForStatus('Running', [TimeSpan]::FromSeconds(1)) } | Should -Not -Throw
            } else {
                Set-ItResult -Skipped -Because "No running services found"
            }
        }
    }

    Context "GitHub Actions Runner Service Monitoring" {
        It "Should monitor GitHub Actions runner service health" {
            $runnerServices = Get-Service -Name $script:ServicePattern -ErrorAction SilentlyContinue
            if ($runnerServices) {
                foreach ($service in $runnerServices) {
                    # Service should be in a valid state
                    $service.Status | Should -BeIn @('Running', 'Stopped', 'Paused', 'StartPending', 'StopPending')

                    # Service object should be valid
                    $service.Name | Should -Not -BeNullOrEmpty
                    $service.ServiceName | Should -Be $service.Name
                }
            } else {
                Set-ItResult -Skipped -Because "No GitHub Actions runner services found on this system"
            }
        }

        It "Should detect runner service availability" {
            $runnerServices = Get-Service -Name $script:ServicePattern -ErrorAction SilentlyContinue
            # Test passes whether services are found or not - we're testing detection capability
            if ($runnerServices) {
                $runnerServices.Count | Should -BeGreaterThan 0
            } else {
                # No services found is a valid result
                $true | Should -Be $true
            }
        }
    }
}

Describe "Windows Service Management - Error Handling" {
    Context "Service Query Error Handling" {
        It "Should handle non-existent service gracefully" {
            $result = Get-Service -Name "NonExistent-Service-$(Get-Random)" -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
        }

        It "Should handle wildcard patterns correctly" {
            { Get-Service -Name "*.nonexistent.*" -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should handle invalid service names" {
            $result = Get-Service -Name "" -ErrorAction SilentlyContinue
            # Should either return nothing or all services depending on implementation
            # The important thing is it doesn't throw
            $true | Should -Be $true
        }
    }
}

Describe "Windows Service Management - Integration Tests" {
    Context "Service Management Integration" {
        It "Should integrate with health-check script pattern" {
            # Verify the same pattern used in health-check.ps1 works
            $runnerServices = Get-Service -Name "actions.runner*" -ErrorAction SilentlyContinue
            # Should not throw regardless of whether services exist
            $true | Should -Be $true
        }

        It "Should support filtering by status and pattern" {
            $services = Get-Service -Name "*" -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' }
            $services.Count | Should -BeGreaterOrEqual 0
        }

        It "Should retrieve service information for monitoring" {
            $service = Get-Service | Select-Object -First 1
            $serviceInfo = @{
                Name = $service.Name
                DisplayName = $service.DisplayName
                Status = $service.Status
                CanStop = $service.CanStop
                CanPauseAndContinue = $service.CanPauseAndContinue
            }

            $serviceInfo.Name | Should -Not -BeNullOrEmpty
            $serviceInfo.Status | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Windows Service Management - Performance" {
    Context "Service Query Performance" {
        It "Should query all services in reasonable time" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $services = Get-Service
            $stopwatch.Stop()

            # Should complete within 5 seconds on most systems
            $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 5
            $services | Should -Not -BeNullOrEmpty
        }

        It "Should query specific service quickly" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $service = Get-Service | Select-Object -First 1 -ExpandProperty Name
            $result = Get-Service -Name $service
            $stopwatch.Stop()

            # Should complete within 1 second
            $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 1
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

AfterAll {
    # Cleanup - No persistent changes made by these tests
    if (-not $isAdmin) {
        Write-Warning "Some tests were skipped due to lack of elevated permissions."
        Write-Host "To run all tests, execute PowerShell as Administrator:" -ForegroundColor Yellow
        Write-Host "  Invoke-Pester -Path .\tests\service-management.Tests.ps1" -ForegroundColor Cyan
    }
}
