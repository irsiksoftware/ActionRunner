<#
.SYNOPSIS
    Pester tests for collect-logs.ps1 script.

.DESCRIPTION
    Comprehensive tests validating log collection functionality including:
    - Parameter validation
    - Service log collection
    - Job log collection
    - Event log collection
    - Performance metrics collection
    - Output file generation
    - Error handling
#>

$script:ScriptPath = Join-Path $PSScriptRoot "..\scripts\collect-logs.ps1"

Describe "collect-logs.ps1 Tests" -Tags @("Logging", "Security") {

    Context "Script Existence and Structure" {
        It "Should exist at expected path" {
            Test-Path $ScriptPath | Should -Be $true
        }

        It "Should have valid PowerShell syntax" {
            { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $ScriptPath -Raw), [ref]$null) } | Should -Not -Throw
        }

        It "Should contain proper help documentation" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "\.SYNOPSIS"
            $content | Should -Match "\.DESCRIPTION"
            $content | Should -Match "\.PARAMETER"
            $content | Should -Match "\.EXAMPLE"
        }
    }

    Context "Parameter Validation" {
        It "Should accept OutputPath parameter" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match '\$OutputPath'
        }

        It "Should have default OutputPath value" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match '\[string\]\$OutputPath\s*=\s*"\.\\logs"'
        }

        It "Should accept IncludeSystemLogs parameter" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match '\$IncludeSystemLogs'
        }

        It "Should accept DaysToCollect parameter" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match '\$DaysToCollect'
        }

        It "Should have default DaysToCollect of 7" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match '\[int\]\$DaysToCollect\s*=\s*7'
        }
    }

    Context "Output Directory Management" {
        It "Should create output directory if it doesn't exist" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "New-Item.*-ItemType Directory.*-Path.*OutputPath"
        }

        It "Should use Test-Path to check directory existence" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Test-Path.*OutputPath"
        }
    }

    Context "Service Log Collection" {
        It "Should check for GitHub Actions runner services" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Get-Service.*actions\.runner"
        }

        It "Should collect service information" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "ServiceName"
            $content | Should -Match "DisplayName"
            $content | Should -Match "Status"
            $content | Should -Match "StartType"
        }

        It "Should save service info to JSON" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "service-info\.json"
            $content | Should -Match "ConvertTo-Json"
        }
    }

    Context "Job Execution Log Collection" {
        It "Should check common runner installation paths" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "actions-runner"
            $content | Should -Match "C:\\actions-runner"
        }

        It "Should collect _diag logs" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "_diag"
        }

        It "Should collect _work logs" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "_work"
        }

        It "Should filter logs by date" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "LastWriteTime.*-ge.*startDate"
        }

        It "Should copy diag log files to output directory" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Copy-Item"
        }
    }

    Context "Performance Metrics Collection" {
        It "Should collect CPU performance counters when IncludeSystemLogs is true" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Processor.*% Processor Time"
        }

        It "Should collect memory performance counters" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Memory.*Available MBytes"
        }

        It "Should collect disk performance counters" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "PhysicalDisk.*% Disk Time"
        }

        It "Should collect network performance counters" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Network Interface.*Bytes Total"
        }

        It "Should save performance data to JSON" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "performance\.json"
        }
    }

    Context "Windows Event Log Collection" {
        It "Should collect Application event logs" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "LogName\s*=\s*'Application'"
        }

        It "Should collect System event logs" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "LogName\s*=\s*'System'"
        }

        It "Should collect Security event logs when IncludeSystemLogs is true" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "LogName\s*=\s*'Security'"
        }

        It "Should filter events by GitHub/Actions/Runner keywords" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "GitHub.*Actions.*Runner"
        }

        It "Should use Get-WinEvent cmdlet" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Get-WinEvent"
        }

        It "Should handle event log access errors gracefully" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "ErrorAction\s+SilentlyContinue"
        }
    }

    Context "Summary Report Generation" {
        It "Should create summary with collection metadata" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "CollectionDate"
            $content | Should -Match "DaysCollected"
            $content | Should -Match "StartDate"
        }

        It "Should include counts of collected items" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "RunnerServices"
            $content | Should -Match "JobLogs"
        }

        It "Should save summary to JSON file" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "summary\.json"
        }

        It "Should list all created log files" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "LogFiles"
        }
    }

    Context "Timestamp and File Naming" {
        It "Should use timestamped filenames" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Get-Date -Format.*yyyyMMdd_HHmmss"
        }

        It "Should include timestamp in log filename" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "runner-logs-.*timestamp"
        }
    }

    Context "Error Handling" {
        It "Should use try-catch blocks for event log collection" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "try\s*{[\s\S]*Get-WinEvent[\s\S]*}\s*catch"
        }

        It "Should use -ErrorAction SilentlyContinue for non-critical operations" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "-ErrorAction\s+SilentlyContinue"
        }

        It "Should provide informative warning messages" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Write-Host.*Yellow"
        }
    }

    Context "Output and Progress Reporting" {
        It "Should display progress headers" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "\[1/5\]"
            $content | Should -Match "\[2/5\]"
            $content | Should -Match "\[3/5\]"
            $content | Should -Match "\[4/5\]"
            $content | Should -Match "\[5/5\]"
        }

        It "Should use colored output for different message types" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "-ForegroundColor\s+Cyan"
            $content | Should -Match "-ForegroundColor\s+Green"
            $content | Should -Match "-ForegroundColor\s+Yellow"
        }

        It "Should display completion summary" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Collection Complete"
        }
    }

    Context "Security Considerations" {
        It "Should limit event log collection to prevent excessive data" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Select-Object -First 1000"
        }

        It "Should note admin privilege requirements for Security logs" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "administrator privileges"
        }

        It "Should filter only relevant events" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Where-Object.*Message -match"
        }
    }

    Context "Date Filtering" {
        It "Should calculate start date based on DaysToCollect parameter" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "AddDays\(-.*DaysToCollect"
        }

        It "Should use date filter for file collection" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "LastWriteTime -ge.*startDate"
        }

        It "Should use date filter for event logs" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "StartTime\s*=.*startDate"
        }
    }

    Context "JSON Output Format" {
        It "Should use ConvertTo-Json for structured data" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "ConvertTo-Json"
        }

        It "Should output multiple JSON files for different log types" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "service-info\.json"
            $content | Should -Match "job-logs\.json"
            $content | Should -Match "performance\.json"
            $content | Should -Match "summary\.json"
        }
    }

    Context "Integration Validation" {
        It "Should be executable PowerShell script" {
            $ScriptPath | Should -Exist
            $ScriptPath | Should -Match '\.ps1$'
        }
    }
}
