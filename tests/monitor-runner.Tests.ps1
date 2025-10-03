<#
.SYNOPSIS
    Pester tests for monitor-runner.ps1 script.

.DESCRIPTION
    Comprehensive validation tests for the continuous monitoring script including:
    - Script existence and structure
    - Parameter validation
    - Monitoring loop logic
    - Alert webhook integration
    - Log rotation
#>

$script:MonitorScript = Join-Path $PSScriptRoot "..\scripts\monitor-runner.ps1"

Describe "Monitor Runner Script Tests" -Tags @("Monitoring", "Continuous", "Scripts") {

    BeforeAll {
        $scriptExists = Test-Path $MonitorScript
    }

    Context "Script File Structure" {
        It "Should exist" {
            Test-Path $MonitorScript | Should -Be $true
        }

        It "Should be a PowerShell script" {
            $MonitorScript | Should -Match "\.ps1$"
        }

        It "Should require PowerShell 5.1 or higher" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "#Requires -Version 5\.1"
        }

        It "Should have synopsis in help" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "\.SYNOPSIS"
        }

        It "Should have description in help" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "\.DESCRIPTION"
        }

        It "Should have examples in help" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "\.EXAMPLE"
        }
    }

    Context "Script Parameters" {
        It "Should accept IntervalSeconds parameter" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "\[Parameter.*\].*\[int\]\`$IntervalSeconds"
        }

        It "Should accept AlertWebhook parameter" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "\[Parameter.*\].*\[string\]\`$AlertWebhook"
        }

        It "Should accept MaxIterations parameter" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "\[Parameter.*\].*\[int\]\`$MaxIterations"
        }

        It "Should accept MinDiskSpaceGB parameter" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "\[Parameter.*\].*\[int\]\`$MinDiskSpaceGB"
        }

        It "Should accept LogRetentionDays parameter" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "\[Parameter.*\].*\[int\]\`$LogRetentionDays"
        }

        It "Should have default value for IntervalSeconds (300)" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "\`$IntervalSeconds\s*=\s*300"
        }

        It "Should have default value for MaxIterations (0 = infinite)" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "\`$MaxIterations\s*=\s*0"
        }

        It "Should have default value for LogRetentionDays (30)" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "\`$LogRetentionDays\s*=\s*30"
        }
    }

    Context "Dependencies" {
        It "Should reference health-check.ps1 script" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "health-check\.ps1"
        }

        It "Should check if health-check.ps1 exists" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Test-Path.*healthCheckScript"
        }

        It "Should exit if health-check.ps1 not found" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Health check script not found"
            $content | Should -Match "exit 1"
        }
    }

    Context "Logging Functions" {
        It "Should define Write-MonitorLog function" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "function Write-MonitorLog"
        }

        It "Should create log directory if missing" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "New-Item.*Directory"
        }

        It "Should write to monitor log file" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "monitor-runner\.log"
        }

        It "Should include timestamp in logs" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Get-Date.*Format"
        }

        It "Should include log level" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Level.*INFO"
        }

        It "Should write to console and file" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Write-Host"
            $content | Should -Match "Add-Content"
        }
    }

    Context "Alert Functions" {
        It "Should define Send-Alert function" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "function Send-Alert"
        }

        It "Should accept Message parameter" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Send-Alert.*Message"
        }

        It "Should accept Severity parameter" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Severity"
        }

        It "Should skip if webhook is empty" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "IsNullOrEmpty.*AlertWebhook"
        }

        It "Should send webhook via Invoke-RestMethod" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Invoke-RestMethod"
        }

        It "Should include timestamp in alert payload" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "timestamp.*Get-Date"
        }

        It "Should include hostname in alert payload" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "hostname.*COMPUTERNAME"
        }

        It "Should convert payload to JSON" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "ConvertTo-Json"
        }

        It "Should handle webhook failures gracefully" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Failed to send alert"
        }
    }

    Context "Log Rotation Functions" {
        It "Should define Invoke-LogRotation function" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "function Invoke-LogRotation"
        }

        It "Should calculate cutoff date based on retention days" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "AddDays.*-.*LogRetentionDays"
        }

        It "Should find old log files" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Get-ChildItem.*\.log"
        }

        It "Should remove logs older than retention period" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Remove-Item.*log"
        }

        It "Should log rotation actions" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Performing log rotation"
            $content | Should -Match "Removed old log"
        }
    }

    Context "Health Check Execution" {
        It "Should define Invoke-HealthCheckWithAlerts function" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "function Invoke-HealthCheckWithAlerts"
        }

        It "Should execute health-check.ps1 script" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "&.*healthCheckScript"
        }

        It "Should request JSON output from health check" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "-OutputFormat json"
        }

        It "Should pass MinDiskSpaceGB to health check" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "-MinDiskSpaceGB.*MinDiskSpaceGB"
        }

        It "Should capture exit code from health check" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "LASTEXITCODE"
        }

        It "Should parse JSON results" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "ConvertFrom-Json"
        }

        It "Should process alerts from health check" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "foreach.*alert.*alerts"
        }

        It "Should send alerts via webhook" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Send-Alert.*alert"
        }

        It "Should handle critical failures" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "exitCode.*2"
            $content | Should -Match "CRITICAL"
        }
    }

    Context "Monitoring Loop" {
        It "Should have infinite loop capability" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "while.*true"
        }

        It "Should track iteration count" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "\`$iteration\+\+"
        }

        It "Should log iteration number" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Iteration.*iteration"
        }

        It "Should call health check in loop" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Invoke-HealthCheckWithAlerts"
        }

        It "Should perform log rotation daily" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "TotalDays.*1"
            $content | Should -Match "Invoke-LogRotation"
        }

        It "Should respect MaxIterations limit" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "MaxIterations.*iteration.*break"
        }

        It "Should sleep between iterations" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Start-Sleep.*IntervalSeconds"
        }
    }

    Context "Startup and Shutdown" {
        It "Should log monitoring start" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Starting runner monitoring"
        }

        It "Should log configuration on startup" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Interval.*IntervalSeconds"
        }

        It "Should send startup alert if webhook configured" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "monitoring started"
        }

        It "Should log monitoring stop" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Monitoring service stopped"
        }

        It "Should send shutdown alert if webhook configured" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "monitoring stopped"
        }
    }

    Context "Error Handling" {
        It "Should handle health check execution failures" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "try.*health[\s\S]*catch"
        }

        It "Should log health check failures" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Health check execution failed"
        }

        It "Should send critical alert on health check failure" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Send-Alert.*critical"
        }

        It "Should handle missing health check results" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "returned no data"
        }
    }

    Context "Best Practices" {
        It "Should not contain hardcoded credentials" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Not -Match "password\s*=\s*`"[^`"]+`""
            $content | Should -Not -Match "api[_-]?key\s*=\s*`"[^`"]+`""
        }

        It "Should use secure webhook URLs" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "https://"
        }

        It "Should have descriptive variable names" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "\`$iteration"
            $content | Should -Match "\`$healthResult"
            $content | Should -Match "\`$lastLogRotation"
        }

        It "Should provide usage examples" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "\.EXAMPLE"
            $content | Should -Match "monitor-runner\.ps1"
        }
    }

    Context "Integration" {
        It "Should work with health-check.ps1" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "health-check\.ps1"
        }

        It "Should support webhook integration" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "Slack.*Discord.*Teams"
        }

        It "Should be suitable for background execution" {
            $content = Get-Content $MonitorScript -Raw
            $content | Should -Match "while.*true"
            $content | Should -Match "Start-Sleep"
        }
    }
}
