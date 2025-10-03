Describe "maintenance-mode.ps1 Script Tests" {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot "..\scripts\maintenance-mode.ps1"
        $scriptContent = Get-Content $scriptPath -Raw
    }

    Context "Parameter Validation" {
        It "Should have Action parameter as mandatory" {
            $scriptContent | Should -Match '\[Parameter\(Mandatory = \$true\)\]'
            $scriptContent | Should -Match '\[string\]\$Action'
        }

        It "Should validate Action parameter values" {
            $scriptContent | Should -Match "ValidateSet\('Enable', 'Disable', 'Status'\)"
        }

        It "Should have RunnerPath parameter" {
            $scriptContent | Should -Match '\[string\]\$RunnerPath'
        }

        It "Should have MaxWaitMinutes parameter" {
            $scriptContent | Should -Match '\[int\]\$MaxWaitMinutes'
        }

        It "Should have Force switch parameter" {
            $scriptContent | Should -Match '\[switch\]\$Force'
        }

        It "Should have Schedule parameter" {
            $scriptContent | Should -Match '\[string\]\$Schedule'
        }
    }

    Context "Script Syntax and Structure" {
        It "Should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize(
                $scriptContent,
                [ref]$errors
            )
            $errors.Count | Should -Be 0
        }

        It "Should require Administrator privileges" {
            $scriptContent | Should -Match '#Requires -RunAsAdministrator'
        }

        It "Should require PowerShell 5.1 or later" {
            $scriptContent | Should -Match '#Requires -Version 5\.1'
        }

        It "Should contain comment-based help" {
            $scriptContent | Should -Match '\.SYNOPSIS'
            $scriptContent | Should -Match '\.DESCRIPTION'
            $scriptContent | Should -Match '\.PARAMETER'
            $scriptContent | Should -Match '\.EXAMPLE'
        }

        It "Should set ErrorActionPreference to Stop" {
            $scriptContent | Should -Match '\$ErrorActionPreference\s*=\s*"Stop"'
        }
    }

    Context "Maintenance Mode Management" {
        It "Should use maintenance marker file" {
            $scriptContent | Should -Match '\$maintenanceFile.*\.maintenance'
        }

        It "Should have Enable-MaintenanceMode function" {
            $scriptContent | Should -Match 'function Enable-MaintenanceMode'
        }

        It "Should have Disable-MaintenanceMode function" {
            $scriptContent | Should -Match 'function Disable-MaintenanceMode'
        }

        It "Should have Get-MaintenanceStatus function" {
            $scriptContent | Should -Match 'function Get-MaintenanceStatus'
        }

        It "Should check if already in maintenance mode" {
            $scriptContent | Should -Match 'Test-Path.*\$maintenanceFile'
            $scriptContent | Should -Match 'Already in maintenance mode'
        }

        It "Should check if not in maintenance mode" {
            $scriptContent | Should -Match 'Not currently in maintenance mode'
        }
    }

    Context "Logging Functionality" {
        It "Should create log file with timestamp" {
            $scriptContent | Should -Match '\$logFile.*maintenance-.*Get-Date.*Format'
        }

        It "Should have Write-MaintenanceLog function" {
            $scriptContent | Should -Match 'function Write-MaintenanceLog'
        }

        It "Should support multiple log levels" {
            $scriptContent | Should -Match 'ValidateSet.*INFO.*SUCCESS.*WARN.*ERROR'
        }

        It "Should write to both file and console" {
            $scriptContent | Should -Match 'Add-Content.*\$logFile'
            $scriptContent | Should -Match 'Write-Host'
        }
    }

    Context "Runner Status Functions" {
        It "Should have Test-RunnerBusy function" {
            $scriptContent | Should -Match 'function Test-RunnerBusy'
        }

        It "Should check for runner service" {
            $scriptContent | Should -Match 'Get-Service.*actions\.runner'
        }

        It "Should check for runner process" {
            $scriptContent | Should -Match 'Get-Process.*Runner\.Listener'
        }

        It "Should check CPU usage to detect active jobs" {
            $scriptContent | Should -Match 'Get-Counter.*Processor.*Time'
        }

        It "Should have Wait-RunnerIdle function" {
            $scriptContent | Should -Match 'function Wait-RunnerIdle'
        }

        It "Should wait with timeout for runner to be idle" {
            $scriptContent | Should -Match 'while.*Get-Date.*timeout'
            $scriptContent | Should -Match 'Start-Sleep'
        }
    }

    Context "Enable Maintenance Mode" {
        It "Should wait for runner to be idle before enabling" {
            $scriptContent | Should -Match 'Wait-RunnerIdle.*-MaxMinutes'
        }

        It "Should stop runner service when enabling" {
            $scriptContent | Should -Match 'Stop-Service'
        }

        It "Should create maintenance marker file" {
            $scriptContent | Should -Match 'Set-Content.*\$maintenanceFile'
        }

        It "Should store maintenance metadata" {
            $scriptContent | Should -Match 'EnabledAt'
            $scriptContent | Should -Match 'EnabledBy'
            $scriptContent | Should -Match 'Reason'
            $scriptContent | Should -Match 'ConvertTo-Json'
        }

        It "Should force enable if specified" {
            $scriptContent | Should -Match 'Use -Force to enable anyway'
            $scriptContent | Should -Match 'Forcing maintenance mode despite active jobs'
        }

        It "Should handle service not found" {
            $scriptContent | Should -Match 'No runner service found'
        }

        It "Should stop runner process if service not found" {
            $scriptContent | Should -Match 'Stop-Process.*Force'
        }
    }

    Context "Disable Maintenance Mode" {
        It "Should remove maintenance marker file" {
            $scriptContent | Should -Match 'Remove-Item.*\$maintenanceFile'
        }

        It "Should start runner service when disabling" {
            $scriptContent | Should -Match 'Start-Service'
        }

        It "Should verify service started successfully" {
            $scriptContent | Should -Match 'service\.Status.*-eq.*Running'
            $scriptContent | Should -Match 'Runner service started successfully'
        }

        It "Should handle start failure" {
            $scriptContent | Should -Match 'Failed to start runner service'
        }

        It "Should warn if service not found" {
            $scriptContent | Should -Match 'may need to start manually'
        }
    }

    Context "Status Reporting" {
        It "Should display maintenance mode status" {
            $scriptContent | Should -Match 'Maintenance Mode Status'
        }

        It "Should show when maintenance is active" {
            $scriptContent | Should -Match 'MAINTENANCE MODE ACTIVE'
        }

        It "Should show when operational" {
            $scriptContent | Should -Match 'OPERATIONAL'
        }

        It "Should display enabled timestamp" {
            $scriptContent | Should -Match 'Enabled at:'
        }

        It "Should display who enabled maintenance" {
            $scriptContent | Should -Match 'Enabled by:'
        }

        It "Should show service status" {
            $scriptContent | Should -Match 'Service Status:'
        }

        It "Should show runner activity" {
            $scriptContent | Should -Match 'Runner Activity:'
        }

        It "Should indicate if runner is busy" {
            $scriptContent | Should -Match 'Busy.*job running'
        }

        It "Should indicate if runner is idle" {
            $scriptContent | Should -Match 'Idle'
        }
    }

    Context "Scheduling Functionality" {
        It "Should have Set-MaintenanceSchedule function" {
            $scriptContent | Should -Match 'function Set-MaintenanceSchedule'
        }

        It "Should parse scheduled time" {
            $scriptContent | Should -Match 'DateTime.*ParseExact'
            $scriptContent | Should -Match 'yyyy-MM-dd HH:mm'
        }

        It "Should reject past scheduled times" {
            $scriptContent | Should -Match 'Scheduled time must be in the future'
        }

        It "Should create scheduled task" {
            $scriptContent | Should -Match 'New-ScheduledTaskAction'
            $scriptContent | Should -Match 'New-ScheduledTaskTrigger'
            $scriptContent | Should -Match 'Register-ScheduledTask'
        }

        It "Should run as SYSTEM account" {
            $scriptContent | Should -Match 'New-ScheduledTaskPrincipal.*SYSTEM'
        }

        It "Should run with highest privileges" {
            $scriptContent | Should -Match 'RunLevel.*Highest'
        }

        It "Should only support scheduling with Enable action" {
            $scriptContent | Should -Match 'Scheduling only supported with -Action Enable'
        }
    }

    Context "Error Handling" {
        It "Should use try-catch for main execution" {
            $scriptContent | Should -Match 'try\s*\{'
            $scriptContent | Should -Match '\}\s*catch\s*\{'
        }

        It "Should log fatal errors" {
            $scriptContent | Should -Match 'Fatal error'
            $scriptContent | Should -Match 'ScriptStackTrace'
        }

        It "Should verify runner path exists" {
            $scriptContent | Should -Match 'Test-Path.*\$RunnerPath'
            $scriptContent | Should -Match 'Runner path not found'
        }

        It "Should exit with appropriate codes" {
            $scriptContent | Should -Match 'exit 0'
            $scriptContent | Should -Match 'exit 1'
        }
    }

    Context "Action Routing" {
        It "Should route to enable function" {
            $scriptContent | Should -Match "switch.*\$Action"
            $scriptContent | Should -Match "'Enable'.*Enable-MaintenanceMode"
        }

        It "Should route to disable function" {
            $scriptContent | Should -Match "'Disable'.*Disable-MaintenanceMode"
        }

        It "Should route to status function" {
            $scriptContent | Should -Match "'Status'.*Get-MaintenanceStatus"
        }
    }

    Context "User Communication" {
        It "Should display help message when enabled" {
            $scriptContent | Should -Match 'Runner is now in maintenance mode'
            $scriptContent | Should -Match 'will not accept new jobs'
        }

        It "Should show how to resume" {
            $scriptContent | Should -Match 'To resume.*maintenance-mode.*-Action Disable'
        }

        It "Should display success message when disabled" {
            $scriptContent | Should -Match 'Runner is now online and accepting jobs'
        }

        It "Should display schedule confirmation" {
            $scriptContent | Should -Match 'Maintenance mode scheduled for'
            $scriptContent | Should -Match 'Scheduled task:'
        }

        It "Should show how to cancel schedule" {
            $scriptContent | Should -Match 'To cancel.*Unregister-ScheduledTask'
        }
    }

    Context "Documentation Quality" {
        It "Should document all parameters in help" {
            $scriptContent | Should -Match '\.PARAMETER Action'
            $scriptContent | Should -Match '\.PARAMETER RunnerPath'
            $scriptContent | Should -Match '\.PARAMETER MaxWaitMinutes'
            $scriptContent | Should -Match '\.PARAMETER Force'
            $scriptContent | Should -Match '\.PARAMETER Schedule'
        }

        It "Should include multiple usage examples" {
            $examples = [regex]::Matches($scriptContent, '\.EXAMPLE')
            $examples.Count | Should -BeGreaterThan 3
        }

        It "Should have notes section" {
            $scriptContent | Should -Match '\.NOTES'
        }

        It "Should document version" {
            $scriptContent | Should -Match 'Version:.*1\.0\.0'
        }
    }

    Context "Service Refresh" {
        It "Should refresh service status after stop" {
            $scriptContent | Should -Match 'service\.Refresh\(\)'
        }

        It "Should verify service status after operations" {
            $scriptContent | Should -Match 'service\.Status.*-eq'
        }
    }
}
