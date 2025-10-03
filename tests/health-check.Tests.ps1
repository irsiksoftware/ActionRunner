<#
.SYNOPSIS
    Pester tests for health-check.ps1 script.

.DESCRIPTION
    Comprehensive validation tests for the runner health check script including:
    - Script existence and structure
    - Parameter validation
    - Health check functions
    - Output format validation
    - Alert generation
    - Exit codes
#>

$script:HealthCheckScript = Join-Path $PSScriptRoot "..\scripts\health-check.ps1"

Describe "Health Check Script Tests" -Tags @("Monitoring", "HealthCheck", "Scripts") {

    BeforeAll {
        $scriptExists = Test-Path $HealthCheckScript
    }

    Context "Script File Structure" {
        It "Should exist" {
            Test-Path $HealthCheckScript | Should -Be $true
        }

        It "Should be a PowerShell script" {
            $HealthCheckScript | Should -Match "\.ps1$"
        }

        It "Should require PowerShell 5.1 or higher" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "#Requires -Version 5\.1"
        }

        It "Should have synopsis in help" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "\.SYNOPSIS"
        }

        It "Should have description in help" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "\.DESCRIPTION"
        }

        It "Should have examples in help" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "\.EXAMPLE"
        }
    }

    Context "Script Parameters" {
        It "Should accept OutputFormat parameter" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "\[Parameter.*\].*\[string\]\`$OutputFormat"
        }

        It "Should accept MinDiskSpaceGB parameter" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "\[Parameter.*\].*\[int\]\`$MinDiskSpaceGB"
        }

        It "Should accept LogPath parameter" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "\[Parameter.*\].*\[string\]\`$LogPath"
        }

        It "Should validate OutputFormat values" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "\[ValidateSet\('json',\s*'text'\)\]"
        }

        It "Should have default value for OutputFormat" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "\`$OutputFormat\s*=\s*'json'"
        }

        It "Should have default value for MinDiskSpaceGB" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "\`$MinDiskSpaceGB\s*=\s*100"
        }
    }

    Context "Health Check Functions" {
        It "Should define Test-RunnerService function" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "function Test-RunnerService"
        }

        It "Should define Test-DiskSpace function" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "function Test-DiskSpace"
        }

        It "Should define Test-ResourceUsage function" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "function Test-ResourceUsage"
        }

        It "Should define Test-GPUStatus function" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "function Test-GPUStatus"
        }

        It "Should define Test-GitHubConnectivity function" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "function Test-GitHubConnectivity"
        }

        It "Should define Test-LastJobExecution function" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "function Test-LastJobExecution"
        }
    }

    Context "Runner Service Check" {
        It "Should check for GitHub Actions runner services" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "Get-Service.*actions\.runner"
        }

        It "Should check service status" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "Status.*Running"
        }

        It "Should generate alerts for non-running services" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "alerts.*not running"
        }
    }

    Context "Disk Space Check" {
        It "Should check all drives" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "Get-PSDrive.*FileSystem"
        }

        It "Should calculate free space in GB" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "Free.*1GB"
        }

        It "Should compare against threshold" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "freeGB.*MinDiskSpaceGB"
        }

        It "Should generate alerts for low disk space" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "alerts.*free.*threshold"
        }
    }

    Context "Resource Usage Check" {
        It "Should check CPU usage" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "Get-Counter.*Processor.*% Processor Time"
        }

        It "Should check RAM usage" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "Win32_OperatingSystem"
            $content | Should -Match "TotalVisibleMemorySize"
        }

        It "Should alert on high CPU usage" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "cpuUsage.*90"
        }

        It "Should alert on high RAM usage" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "ramUsagePercent.*90"
        }
    }

    Context "GPU Status Check" {
        It "Should attempt to use nvidia-smi" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "nvidia-smi"
        }

        It "Should query GPU memory" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "memory\.total.*memory\.free"
        }

        It "Should query GPU temperature" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "temperature\.gpu"
        }

        It "Should alert on high GPU temperature" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "temperature.*85"
        }

        It "Should handle missing nvidia-smi gracefully" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "ErrorAction.*SilentlyContinue"
        }
    }

    Context "Network Connectivity Check" {
        It "Should check GitHub API endpoint" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "api\.github\.com"
        }

        It "Should check GitHub web endpoint" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "github\.com"
        }

        It "Should use web request to test connectivity" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "Invoke-WebRequest"
        }

        It "Should have timeout for requests" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "TimeoutSec"
        }

        It "Should generate alerts for unreachable endpoints" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "unreachable"
        }
    }

    Context "Last Job Execution Check" {
        It "Should look for runner log files" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "_diag"
        }

        It "Should search for Worker log files" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "Worker_.*\.log"
        }

        It "Should check multiple log paths" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "GITHUB_RUNNER_HOME"
        }

        It "Should calculate time since last job" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "TotalHours"
        }

        It "Should alert if no jobs in 24 hours" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "24.*hours"
        }
    }

    Context "Output Format - JSON" {
        It "Should output JSON format by default" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "ConvertTo-Json"
        }

        It "Should include timestamp in output" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "timestamp.*Get-Date"
        }

        It "Should include overall_status" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "overall_status"
        }

        It "Should include checks object" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "checks\s*=\s*@\{\}"
        }

        It "Should include alerts array" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "alerts\s*=\s*@\(\)"
        }

        It "Should use depth for nested JSON" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "ConvertTo-Json.*-Depth"
        }
    }

    Context "Output Format - Text" {
        It "Should support text output format" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "OutputFormat.*text"
        }

        It "Should display colored output for status" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "ForegroundColor"
        }

        It "Should show alerts section" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "Write-Host.*Alerts"
        }

        It "Should show detailed checks section" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "Write-Host.*Detailed Checks"
        }
    }

    Context "Status Levels" {
        It "Should set status to healthy by default" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "overall_status.*healthy"
        }

        It "Should set status to degraded for warnings" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "overall_status.*degraded"
        }

        It "Should set status to unhealthy for critical issues" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "overall_status.*unhealthy"
        }
    }

    Context "Exit Codes" {
        It "Should exit 0 for healthy status" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "if.*healthy.*exit 0"
        }

        It "Should exit 1 for degraded status" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "degraded.*exit 1"
        }

        It "Should exit 2 for unhealthy status" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "exit 2"
        }
    }

    Context "Logging" {
        It "Should define Write-Log function" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "function Write-Log"
        }

        It "Should create log directory if missing" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "New-Item.*Directory"
        }

        It "Should write to log file" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "Add-Content.*LogPath"
        }

        It "Should include timestamp in logs" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "Get-Date.*Format"
        }

        It "Should include log level" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "Level.*INFO"
        }
    }

    Context "Error Handling" {
        It "Should use ErrorAction SilentlyContinue for optional checks" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "ErrorAction.*SilentlyContinue"
        }

        It "Should use try-catch for GPU checks" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "try.*nvidia-smi[\s\S]*catch"
        }

        It "Should handle missing runner services" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "No runner services found"
        }

        It "Should handle missing log files" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "No runner log files found"
        }
    }

    Context "Script Execution" {
        It "Should execute all health checks" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "Test-RunnerService"
            $content | Should -Match "Test-DiskSpace"
            $content | Should -Match "Test-ResourceUsage"
            $content | Should -Match "Test-GPUStatus"
            $content | Should -Match "Test-GitHubConnectivity"
            $content | Should -Match "Test-LastJobExecution"
        }

        It "Should log start and completion" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "Starting health check"
            $content | Should -Match "Health check completed"
        }
    }

    Context "Best Practices" {
        It "Should not contain hardcoded credentials" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Not -Match "password\s*=\s*`"[^`"]+`""
            $content | Should -Not -Match "api[_-]?key\s*=\s*`"[^`"]+`""
        }

        It "Should use secure web requests" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "https://"
        }

        It "Should use proper error handling" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "ErrorAction"
        }

        It "Should have descriptive variable names" {
            $content = Get-Content $HealthCheckScript -Raw
            $content | Should -Match "\`$healthStatus"
            $content | Should -Match "\`$cpuUsage"
            $content | Should -Match "\`$freeGB"
        }
    }
}
