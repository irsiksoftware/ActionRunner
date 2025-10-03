$scriptPath = Join-Path $PSScriptRoot "..\scripts\health-check.ps1"

Describe "health-check.ps1 Script Tests" {
    Context "Parameter Validation" {
        It "Should have optional OutputFormat parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params['OutputFormat'].Attributes.Mandatory | Should -Be $false
        }

        It "Should validate OutputFormat as JSON or Text" {
            $params = (Get-Command $scriptPath).Parameters
            $validateSet = $params['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'JSON'
            $validateSet.ValidValues | Should -Contain 'Text'
        }

        It "Should have optional DiskThresholdGB parameter with default" {
            $params = (Get-Command $scriptPath).Parameters
            $params['DiskThresholdGB'].Attributes.Mandatory | Should -Be $false
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

        It "Should check runner service status" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Get-Service.*actions\.runner'
        }

        It "Should check disk space" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Get-PSDrive'
        }

        It "Should check CPU and RAM usage" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Win32_OperatingSystem'
            $content | Should -Match 'Processor.*Time'
        }

        It "Should check GPU availability" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Win32_VideoController'
        }

        It "Should check network connectivity" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Test-Connection'
            $content | Should -Match 'github\.com'
        }

        It "Should check last job execution" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Worker_.*\.log'
        }
    }

    Context "JSON Output Format" {
        It "Should produce valid JSON output" {
            $output = & $scriptPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $PSScriptRoot
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include Timestamp in JSON output" {
            $output = & $scriptPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $PSScriptRoot
            $json = $output | ConvertFrom-Json
            $json.Timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include OverallHealth in JSON output" {
            $output = & $scriptPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $PSScriptRoot
            $json = $output | ConvertFrom-Json
            $json.OverallHealth | Should -BeIn @('Healthy', 'Warning', 'Unhealthy')
        }

        It "Should include Checks object in JSON output" {
            $output = & $scriptPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $PSScriptRoot
            $json = $output | ConvertFrom-Json
            $json.Checks | Should -Not -BeNullOrEmpty
        }

        It "Should include RunnerService check" {
            $output = & $scriptPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $PSScriptRoot
            $json = $output | ConvertFrom-Json
            $json.Checks.RunnerService | Should -Not -BeNullOrEmpty
        }

        It "Should include DiskSpace check" {
            $output = & $scriptPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $PSScriptRoot
            $json = $output | ConvertFrom-Json
            $json.Checks.DiskSpace | Should -Not -BeNullOrEmpty
        }

        It "Should include SystemResources check" {
            $output = & $scriptPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $PSScriptRoot
            $json = $output | ConvertFrom-Json
            $json.Checks.SystemResources | Should -Not -BeNullOrEmpty
        }

        It "Should include GPU check" {
            $output = & $scriptPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $PSScriptRoot
            $json = $output | ConvertFrom-Json
            $json.Checks.GPU | Should -Not -BeNullOrEmpty
        }

        It "Should include NetworkConnectivity check" {
            $output = & $scriptPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $PSScriptRoot
            $json = $output | ConvertFrom-Json
            $json.Checks.NetworkConnectivity | Should -Not -BeNullOrEmpty
        }
    }

    Context "Health Check Logic" {
        It "Should report disk space metrics" {
            $output = & $scriptPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $PSScriptRoot
            $json = $output | ConvertFrom-Json
            $json.Checks.DiskSpace.FreeSpaceGB | Should -BeOfType [double]
            $json.Checks.DiskSpace.TotalSpaceGB | Should -BeOfType [double]
        }

        It "Should report CPU usage percentage" {
            $output = & $scriptPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $PSScriptRoot
            $json = $output | ConvertFrom-Json
            $json.Checks.SystemResources.CPUUsagePercentage | Should -BeOfType [double]
            $json.Checks.SystemResources.CPUUsagePercentage | Should -BeGreaterOrEqual 0
            $json.Checks.SystemResources.CPUUsagePercentage | Should -BeLessOrEqual 100
        }

        It "Should report RAM usage percentage" {
            $output = & $scriptPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $PSScriptRoot
            $json = $output | ConvertFrom-Json
            $json.Checks.SystemResources.RAMUsagePercentage | Should -BeOfType [double]
            $json.Checks.SystemResources.RAMUsagePercentage | Should -BeGreaterOrEqual 0
            $json.Checks.SystemResources.RAMUsagePercentage | Should -BeLessOrEqual 100
        }

        It "Should apply disk threshold correctly" {
            # Test with very high threshold to force unhealthy state
            $output = & $scriptPath -OutputFormat JSON -DiskThresholdGB 99999 -WorkDirectory $PSScriptRoot
            $json = $output | ConvertFrom-Json
            $json.Checks.DiskSpace.Status | Should -Be 'Unhealthy'
        }

        It "Should check connectivity to GitHub" {
            $output = & $scriptPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $PSScriptRoot
            $json = $output | ConvertFrom-Json
            $json.Checks.NetworkConnectivity.Results | Should -Not -BeNullOrEmpty
            $hostnames = $json.Checks.NetworkConnectivity.Results | ForEach-Object { $_.Host }
            $hostnames | Should -Contain 'github.com'
            $hostnames | Should -Contain 'api.github.com'
        }
    }

    Context "Exit Codes" {
        It "Should exit with 0 when healthy" {
            # Use low disk threshold to ensure healthy state
            & $scriptPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $PSScriptRoot
            $LASTEXITCODE | Should -Be 0
        }

        It "Should exit with 1 when unhealthy" {
            # Use very high disk threshold to force unhealthy state
            & $scriptPath -OutputFormat JSON -DiskThresholdGB 99999 -WorkDirectory $PSScriptRoot
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Text Output Format" {
        It "Should produce text output" {
            $output = & $scriptPath -OutputFormat Text -DiskThresholdGB 10 -WorkDirectory $PSScriptRoot
            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match 'GitHub Actions Runner Health Check'
        }

        It "Should display overall health status" {
            $output = & $scriptPath -OutputFormat Text -DiskThresholdGB 10 -WorkDirectory $PSScriptRoot
            $output | Should -Match 'Overall Health:'
        }

        It "Should display check results" {
            $output = & $scriptPath -OutputFormat Text -DiskThresholdGB 10 -WorkDirectory $PSScriptRoot
            $output | Should -Match 'RunnerService'
            $output | Should -Match 'DiskSpace'
            $output | Should -Match 'SystemResources'
        }
    }
}
