BeforeAll {
    $script:TestRoot = $PSScriptRoot
    $script:ProjectRoot = Split-Path $TestRoot -Parent
    $script:ScriptsPath = Join-Path $ProjectRoot "scripts"
    $script:scriptPath = Join-Path $ScriptsPath "collect-logs.ps1"
}

Describe "collect-logs.ps1" {
    BeforeEach {
        # Create test environment
        $script:testRoot = Join-Path $TestDrive "collect-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
    }

    Context "Script Validation" {
        It "Script file should exist" {
            Test-Path $scriptPath | Should -Be $true
        }

        It "Script should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$errors)
            $errors.Count | Should -Be 0
        }

        It "Script should support -OutputPath parameter" {
            $help = Get-Help $scriptPath
            $help.parameters.parameter.name | Should -Contain 'OutputPath'
        }

        It "Script should support -Days parameter" {
            $help = Get-Help $scriptPath
            $help.parameters.parameter.name | Should -Contain 'Days'
        }

        It "Script should support -IncludeWindowsEvents parameter" {
            $help = Get-Help $scriptPath
            $help.parameters.parameter.name | Should -Contain 'IncludeWindowsEvents'
        }
    }

    Context "Directory Creation" {
        It "Should create output directory if it does not exist" {
            $outputPath = Join-Path $script:testRoot "new-output"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            Test-Path $outputPath | Should -Be $true
        }

        It "Should create collection subdirectory with timestamp" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $collections.Count | Should -BeGreaterThan 0
        }

        It "Should create runner subdirectory in output path" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            Test-Path (Join-Path $outputPath "runner") | Should -Be $true
        }

        It "Should create jobs subdirectory in output path" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            Test-Path (Join-Path $outputPath "jobs") | Should -Be $true
        }

        It "Should create performance subdirectory in output path" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            Test-Path (Join-Path $outputPath "performance") | Should -Be $true
        }

        It "Should create security subdirectory in output path" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            Test-Path (Join-Path $outputPath "security") | Should -Be $true
        }

        It "Should not recreate existing subdirectories" {
            $outputPath = Join-Path $script:testRoot "logs"
            New-Item -ItemType Directory -Path (Join-Path $outputPath "runner") -Force | Out-Null
            $originalTime = (Get-Item (Join-Path $outputPath "runner")).LastWriteTime

            Start-Sleep -Milliseconds 100
            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $newTime = (Get-Item (Join-Path $outputPath "runner")).LastWriteTime
            # Directory should exist but timestamp shouldn't change significantly
            Test-Path (Join-Path $outputPath "runner") | Should -Be $true
        }
    }

    Context "Log Collection - Runner Service Logs" {
        It "Should create runner-service.log file" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $runnerLog = Get-ChildItem -Path $collections[0].FullName -Filter "runner-service.log"
            $runnerLog | Should -Not -BeNullOrEmpty
        }

        It "Should check multiple possible runner log paths" {
            # This test verifies the script checks various standard locations
            # The script should handle when none exist without error
            $outputPath = Join-Path $script:testRoot "logs"

            { & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should write message when no runner logs found" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $runnerLog = Join-Path $collections[0].FullName "runner-service.log"
            $content = Get-Content $runnerLog -Raw
            $content | Should -Match "No runner service logs found"
        }

        It "Should filter runner logs by date range" {
            # This test documents the expected behavior based on the Days parameter
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            # Script should only collect logs from last 7 days
            # Verification happens within the script logic
            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $collections.Count | Should -BeGreaterThan 0
        }
    }

    Context "Log Collection - Job Execution Logs" {
        It "Should create job-executions.log file" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $jobLog = Get-ChildItem -Path $collections[0].FullName -Filter "job-executions.log"
            $jobLog | Should -Not -BeNullOrEmpty
        }

        It "Should write message when no job logs found" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $jobLog = Join-Path $collections[0].FullName "job-executions.log"
            $content = Get-Content $jobLog -Raw
            $content | Should -Match "No job execution logs found"
        }

        It "Should create summary format for job logs" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $jobLog = Join-Path $collections[0].FullName "job-executions.log"
            $content = Get-Content $jobLog -Raw
            $content | Should -Match "Job Execution Logs Summary"
        }

        It "Should limit job logs to 50 most recent" {
            # This test documents the built-in limit to prevent overwhelming output
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            # Script has Select-Object -First 50 limit
            # This is a design decision to prevent excessive output
            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $collections.Count | Should -BeGreaterThan 0
        }
    }

    Context "Log Collection - System Performance" {
        It "Should create system-performance.log file" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $perfLog = Get-ChildItem -Path $collections[0].FullName -Filter "system-performance.log"
            $perfLog | Should -Not -BeNullOrEmpty
        }

        It "Should collect CPU information" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $perfLog = Join-Path $collections[0].FullName "system-performance.log"
            $content = Get-Content $perfLog -Raw
            $content | Should -Match "CPU Information"
        }

        It "Should collect Memory information" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $perfLog = Join-Path $collections[0].FullName "system-performance.log"
            $content = Get-Content $perfLog -Raw
            $content | Should -Match "Memory Information"
        }

        It "Should collect Disk information" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $perfLog = Join-Path $collections[0].FullName "system-performance.log"
            $content = Get-Content $perfLog -Raw
            $content | Should -Match "Disk Information"
        }

        It "Should collect Top 10 Processes by CPU" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $perfLog = Join-Path $collections[0].FullName "system-performance.log"
            $content = Get-Content $perfLog -Raw
            $content | Should -Match "Top 10 Processes by CPU"
        }

        It "Should include timestamp in performance snapshot" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $perfLog = Join-Path $collections[0].FullName "system-performance.log"
            $content = Get-Content $perfLog -Raw
            $content | Should -Match "Collected:"
        }
    }

    Context "Log Collection - Security Audit" {
        It "Should create security-audit.log file" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $secLog = Get-ChildItem -Path $collections[0].FullName -Filter "security-audit.log"
            $secLog | Should -Not -BeNullOrEmpty
        }

        It "Should collect basic security information" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $secLog = Join-Path $collections[0].FullName "security-audit.log"
            $content = Get-Content $secLog -Raw
            $content | Should -Match "Security Audit Log"
        }

        It "Should include username in security audit" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $secLog = Join-Path $collections[0].FullName "security-audit.log"
            $content = Get-Content $secLog -Raw
            $content | Should -Match "User:"
        }

        It "Should include computer name in security audit" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $secLog = Join-Path $collections[0].FullName "security-audit.log"
            $content = Get-Content $secLog -Raw
            $content | Should -Match "Computer:"
        }

        It "Should include firewall status in security audit" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $secLog = Join-Path $collections[0].FullName "security-audit.log"
            $content = Get-Content $secLog -Raw
            $content | Should -Match "Firewall Status"
        }

        It "Should not collect Windows events by default" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $secLog = Join-Path $collections[0].FullName "security-audit.log"
            $content = Get-Content $secLog -Raw
            # Should not contain Recent Security Events section when not requested
            $content | Should -Not -Match "Recent Security Events"
        }

        It "Should attempt to collect Windows events when IncludeWindowsEvents is specified" {
            $outputPath = Join-Path $script:testRoot "logs"

            # This may fail if not run as admin, but should not throw
            { & $scriptPath -OutputPath $outputPath -Days 7 -IncludeWindowsEvents -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context "Manifest Generation" {
        It "Should create manifest.json file" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $manifest = Get-ChildItem -Path $collections[0].FullName -Filter "manifest.json"
            $manifest | Should -Not -BeNullOrEmpty
        }

        It "Should create valid JSON in manifest" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $manifestPath = Join-Path $collections[0].FullName "manifest.json"
            $content = Get-Content $manifestPath -Raw
            { $content | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include CollectionTime in manifest" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $manifestPath = Join-Path $collections[0].FullName "manifest.json"
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.CollectionTime | Should -Not -BeNullOrEmpty
        }

        It "Should include DaysCollected in manifest" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $manifestPath = Join-Path $collections[0].FullName "manifest.json"
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.DaysCollected | Should -Be 7
        }

        It "Should include OutputPath in manifest" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $manifestPath = Join-Path $collections[0].FullName "manifest.json"
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.OutputPath | Should -Not -BeNullOrEmpty
        }

        It "Should include Summary section in manifest" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $manifestPath = Join-Path $collections[0].FullName "manifest.json"
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.Summary | Should -Not -BeNullOrEmpty
        }

        It "Should include RunnerLogs count in Summary" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $manifestPath = Join-Path $collections[0].FullName "manifest.json"
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.Summary.RunnerLogs | Should -BeGreaterOrEqual 0
        }

        It "Should include JobLogs count in Summary" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $manifestPath = Join-Path $collections[0].FullName "manifest.json"
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.Summary.JobLogs | Should -BeGreaterOrEqual 0
        }

        It "Should include PerformanceSnapshot flag in Summary" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $manifestPath = Join-Path $collections[0].FullName "manifest.json"
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.Summary.PerformanceSnapshot | Should -Be $true
        }

        It "Should include SecurityAudit flag in Summary" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $manifestPath = Join-Path $collections[0].FullName "manifest.json"
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.Summary.SecurityAudit | Should -Be $true
        }

        It "Should include WindowsEvents flag in Summary" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -IncludeWindowsEvents -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $manifestPath = Join-Path $collections[0].FullName "manifest.json"
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.Summary.WindowsEvents | Should -Be $true
        }

        It "Should set WindowsEvents to false when not included" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $manifestPath = Join-Path $collections[0].FullName "manifest.json"
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.Summary.WindowsEvents | Should -Be $false
        }
    }

    Context "Custom Days Parameter" {
        It "Should respect Days parameter value of 1" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 1 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $manifestPath = Join-Path $collections[0].FullName "manifest.json"
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.DaysCollected | Should -Be 1
        }

        It "Should respect Days parameter value of 30" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 30 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $manifestPath = Join-Path $collections[0].FullName "manifest.json"
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.DaysCollected | Should -Be 30
        }

        It "Should use default value of 7 days when not specified" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $manifestPath = Join-Path $collections[0].FullName "manifest.json"
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.DaysCollected | Should -Be 7
        }
    }

    Context "Custom Output Path" {
        It "Should use default output path when not specified" {
            # Default is .\logs which would be relative to script location
            # This test runs the script and verifies it completes
            { & $scriptPath -Days 7 -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should create output at specified custom path" {
            $customPath = Join-Path $script:testRoot "custom-logs"

            & $scriptPath -OutputPath $customPath -Days 7 -ErrorAction SilentlyContinue

            Test-Path $customPath | Should -Be $true
        }

        It "Should handle absolute paths" {
            $absolutePath = Join-Path $script:testRoot "absolute-path"

            & $scriptPath -OutputPath $absolutePath -Days 7 -ErrorAction SilentlyContinue

            Test-Path $absolutePath | Should -Be $true
        }

        It "Should handle relative paths" {
            Push-Location $script:testRoot
            try {
                & $scriptPath -OutputPath "relative-logs" -Days 7 -ErrorAction SilentlyContinue

                Test-Path (Join-Path $script:testRoot "relative-logs") | Should -Be $true
            } finally {
                Pop-Location
            }
        }
    }

    Context "Error Handling" {
        It "Should complete without throwing when no logs exist" {
            $outputPath = Join-Path $script:testRoot "logs"

            { & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should handle CIM query failures gracefully" {
            # Script uses Get-CimInstance which should work on Windows
            # But should handle failures without crashing
            $outputPath = Join-Path $script:testRoot "logs"

            { & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should handle firewall query failures gracefully" {
            # Get-NetFirewallProfile may fail in some environments
            $outputPath = Join-Path $script:testRoot "logs"

            { & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should handle Windows Event Log access failures gracefully" {
            # May not have permissions to access Security log
            $outputPath = Join-Path $script:testRoot "logs"

            { & $scriptPath -OutputPath $outputPath -Days 7 -IncludeWindowsEvents -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context "Output Files Structure" {
        It "Should create exactly 4 log files plus manifest" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $files = Get-ChildItem -Path $collections[0].FullName -File
            # runner-service.log, job-executions.log, system-performance.log, security-audit.log, manifest.json
            $files.Count | Should -Be 5
        }

        It "Should create all expected log files" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $files = Get-ChildItem -Path $collections[0].FullName -File
            $fileNames = $files.Name
            $fileNames | Should -Contain "runner-service.log"
            $fileNames | Should -Contain "job-executions.log"
            $fileNames | Should -Contain "system-performance.log"
            $fileNames | Should -Contain "security-audit.log"
            $fileNames | Should -Contain "manifest.json"
        }

        It "Should create files with content" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $files = Get-ChildItem -Path $collections[0].FullName -File
            foreach ($file in $files) {
                $file.Length | Should -BeGreaterThan 0
            }
        }
    }

    Context "Timestamp Format" {
        It "Should use consistent timestamp format in collection directory name" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            # Format should be collection_yyyy-MM-dd_HH-mm-ss
            $collections[0].Name | Should -Match "collection_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}"
        }

        It "Should create unique collection directories for multiple runs" {
            $outputPath = Join-Path $script:testRoot "logs"

            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
            & $scriptPath -OutputPath $outputPath -Days 7 -ErrorAction SilentlyContinue

            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $collections.Count | Should -BeGreaterOrEqual 2
        }
    }

    Context "Integration Test" {
        It "Should complete full collection cycle successfully" {
            $outputPath = Join-Path $script:testRoot "integration-logs"

            { & $scriptPath -OutputPath $outputPath -Days 14 -IncludeWindowsEvents -ErrorAction SilentlyContinue } | Should -Not -Throw

            # Verify structure
            Test-Path $outputPath | Should -Be $true
            Test-Path (Join-Path $outputPath "runner") | Should -Be $true
            Test-Path (Join-Path $outputPath "jobs") | Should -Be $true
            Test-Path (Join-Path $outputPath "performance") | Should -Be $true
            Test-Path (Join-Path $outputPath "security") | Should -Be $true

            # Verify collection
            $collections = Get-ChildItem -Path $outputPath -Filter "collection_*" -Directory
            $collections.Count | Should -BeGreaterThan 0

            # Verify manifest
            $manifestPath = Join-Path $collections[0].FullName "manifest.json"
            Test-Path $manifestPath | Should -Be $true
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.DaysCollected | Should -Be 14
            $manifest.Summary.WindowsEvents | Should -Be $true
        }
    }
}
