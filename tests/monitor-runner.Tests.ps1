$scriptPath = Join-Path $PSScriptRoot "..\scripts\monitor-runner.ps1"

Describe "monitor-runner.ps1 Script Tests" {
    Context "Parameter Validation" {
        It "Should have optional IntervalSeconds parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params['IntervalSeconds'].Attributes.Mandatory | Should -Be $false
        }

        It "Should have optional LogDirectory parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params['LogDirectory'].Attributes.Mandatory | Should -Be $false
        }

        It "Should have optional DiskThresholdGB parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params['DiskThresholdGB'].Attributes.Mandatory | Should -Be $false
        }

        It "Should have optional AlertOnFailure parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params['AlertOnFailure'].Attributes.Mandatory | Should -Be $false
        }

        It "Should have optional MaxLogFiles parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params['MaxLogFiles'].Attributes.Mandatory | Should -Be $false
        }

        It "Should have optional WorkDirectory parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params['WorkDirectory'].Attributes.Mandatory | Should -Be $false
        }
    }

    Context "Script Syntax and Structure" {
        It "Should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize(
                (Get-Content $scriptPath -Raw),
                [ref]$errors
            )
            $errors.Count | Should -Be 0
        }

        It "Should contain comment-based help" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\.SYNOPSIS'
            $content | Should -Match '\.DESCRIPTION'
            $content | Should -Match '\.PARAMETER'
            $content | Should -Match '\.EXAMPLE'
        }

        It "Should reference health-check script" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'health-check\.ps1'
        }

        It "Should have log directory creation logic" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'New-Item.*Directory'
        }

        It "Should have monitoring loop" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'while.*\$true'
            $content | Should -Match 'Start-Sleep'
        }

        It "Should have log cleanup function" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'function Remove-OldLogFiles'
        }

        It "Should have alert display function" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'function Show-Alert'
        }
    }

    Context "Function Tests" {
        BeforeAll {
            # Source the script to test functions (without running the loop)
            $scriptContent = Get-Content $scriptPath -Raw

            # Extract just the functions for testing
            $removeOldLogFilesPattern = '(?s)function Remove-OldLogFiles\s*\{.*?\n\}'
            $showAlertPattern = '(?s)function Show-Alert\s*\{.*?\n\}'

            if ($scriptContent -match $removeOldLogFilesPattern) {
                $removeOldLogFilesFunc = $matches[0]
                Invoke-Expression $removeOldLogFilesFunc
            }

            if ($scriptContent -match $showAlertPattern) {
                $showAlertFunc = $matches[0]
                Invoke-Expression $showAlertFunc
            }
        }

        It "Should define Remove-OldLogFiles function" {
            Get-Command Remove-OldLogFiles -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should define Show-Alert function" {
            Get-Command Show-Alert -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    Context "Log Management" {
        BeforeAll {
            $testLogDir = Join-Path $TestDrive "test-logs"
            New-Item -ItemType Directory -Path $testLogDir -Force | Out-Null
        }

        It "Should validate log file naming pattern" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'health-.*\.json'
        }

        It "Should include timestamp in log filename" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Get-Date.*Format.*yyyy-MM-dd'
        }

        It "Should save health check output to JSON file" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'ConvertTo-Json'
            $content | Should -Match 'Out-File'
        }
    }

    Context "Monitoring Configuration" {
        It "Should have configurable check interval" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$IntervalSeconds'
        }

        It "Should track consecutive failures" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$consecutiveFailures'
        }

        It "Should track check count" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$checkCount'
        }

        It "Should call health-check script with parameters" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '&\s+\$healthCheckScript.*-OutputFormat.*JSON'
            $content | Should -Match '-DiskThresholdGB'
            $content | Should -Match '-WorkDirectory'
        }
    }

    Context "Alert Logic" {
        It "Should check AlertOnFailure parameter" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'if.*\$AlertOnFailure'
        }

        It "Should display alerts for unhealthy checks" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Show-Alert.*unhealthy'
        }

        It "Should track unhealthy and warning checks separately" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Unhealthy.*Error'
            $content | Should -Match 'Warning'
        }
    }

    Context "Cleanup Functionality" {
        It "Should periodically clean up old logs" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Remove-OldLogFiles'
        }

        It "Should respect MaxLogFiles parameter" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$MaxLogFiles'
        }

        It "Should sort log files by LastWriteTime" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Sort-Object.*LastWriteTime'
        }
    }

    Context "Error Handling" {
        It "Should validate health-check script exists" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Test-Path.*healthCheckScript'
        }

        It "Should handle health check execution errors" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'try.*catch'
        }

        It "Should have error action preference set" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$ErrorActionPreference'
        }
    }

    Context "Output and Reporting" {
        It "Should display startup information" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'GitHub Actions Runner Continuous Monitoring'
            $content | Should -Match 'Check interval:'
            $content | Should -Match 'Log directory:'
        }

        It "Should display check results with timestamp" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Get-Date.*Format.*HH:mm:ss'
            $content | Should -Match 'Running health check'
        }

        It "Should display overall health status with color" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Write-Host.*-ForegroundColor'
            $content | Should -Match 'Green|Yellow|Red'
        }

        It "Should provide shutdown summary" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'finally'
            $content | Should -Match 'Monitoring stopped'
            $content | Should -Match 'Total checks performed'
        }
    }
}
