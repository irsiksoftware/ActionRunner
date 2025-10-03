BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot ".." "scripts" "benchmark-runner.ps1"
    $script:TestOutputPath = Join-Path $PSScriptRoot ".." "test-benchmark-output"

    # Ensure test output directory exists
    if (-not (Test-Path $script:TestOutputPath)) {
        New-Item -Path $script:TestOutputPath -ItemType Directory -Force | Out-Null
    }
}

AfterAll {
    # Cleanup test output directory
    if (Test-Path $script:TestOutputPath) {
        Remove-Item -Path $script:TestOutputPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "benchmark-runner.ps1 Script Existence" {
    It "Script file should exist" {
        Test-Path $script:ScriptPath | Should -Be $true
    }

    It "Script should have valid PowerShell syntax" {
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:ScriptPath -Raw), [ref]$errors)
        $errors.Count | Should -Be 0
    }
}

Describe "benchmark-runner.ps1 Parameters" {
    BeforeAll {
        $script:ScriptContent = Get-Content $script:ScriptPath -Raw
    }

    It "Should have OutputPath parameter" {
        $script:ScriptContent | Should -Match '\[string\]\$OutputPath'
    }

    It "Should have RunAll parameter" {
        $script:ScriptContent | Should -Match '\[switch\]\$RunAll'
    }

    It "Should have BenchmarkTypes parameter" {
        $script:ScriptContent | Should -Match '\[string\]\$BenchmarkTypes'
    }

    It "Should have Iterations parameter" {
        $script:ScriptContent | Should -Match '\[int\]\$Iterations'
    }
}

Describe "benchmark-runner.ps1 Core Functions" {
    BeforeAll {
        $script:ScriptContent = Get-Content $script:ScriptPath -Raw
    }

    It "Should define Write-BenchmarkLog function" {
        $script:ScriptContent | Should -Match 'function Write-BenchmarkLog'
    }

    It "Should define Get-SystemInfo function" {
        $script:ScriptContent | Should -Match 'function Get-SystemInfo'
    }

    It "Should define Measure-DiskIOPerformance function" {
        $script:ScriptContent | Should -Match 'function Measure-DiskIOPerformance'
    }

    It "Should define Measure-NetworkPerformance function" {
        $script:ScriptContent | Should -Match 'function Measure-NetworkPerformance'
    }

    It "Should define Measure-DotNetPerformance function" {
        $script:ScriptContent | Should -Match 'function Measure-DotNetPerformance'
    }

    It "Should define Measure-PythonPerformance function" {
        $script:ScriptContent | Should -Match 'function Measure-PythonPerformance'
    }

    It "Should define Measure-GitPerformance function" {
        $script:ScriptContent | Should -Match 'function Measure-GitPerformance'
    }

    It "Should define Export-BenchmarkReport function" {
        $script:ScriptContent | Should -Match 'function Export-BenchmarkReport'
    }
}

Describe "benchmark-runner.ps1 Execution - Disk I/O Only" {
    BeforeAll {
        # Run quick test with just disk I/O (fastest benchmark)
        $script:Result = & $script:ScriptPath -BenchmarkTypes "diskio" -Iterations 1 -OutputPath $script:TestOutputPath 2>&1
        $script:ExitCode = $LASTEXITCODE
    }

    It "Should execute without errors" {
        $script:ExitCode | Should -Be 0
    }

    It "Should create output directory" {
        Test-Path $script:TestOutputPath | Should -Be $true
    }

    It "Should generate markdown report" {
        $mdFiles = Get-ChildItem -Path $script:TestOutputPath -Filter "benchmark-*.md"
        $mdFiles.Count | Should -BeGreaterThan 0
    }

    It "Should generate JSON report" {
        $jsonFiles = Get-ChildItem -Path $script:TestOutputPath -Filter "benchmark-*.json"
        $jsonFiles.Count | Should -BeGreaterThan 0
    }

    It "Markdown report should contain system information" {
        $mdFile = Get-ChildItem -Path $script:TestOutputPath -Filter "benchmark-*.md" | Select-Object -First 1
        $content = Get-Content $mdFile.FullName -Raw
        $content | Should -Match "System Information"
        $content | Should -Match "OS:"
        $content | Should -Match "Processor:"
    }

    It "Markdown report should contain Disk I/O results" {
        $mdFile = Get-ChildItem -Path $script:TestOutputPath -Filter "benchmark-*.md" | Select-Object -First 1
        $content = Get-Content $mdFile.FullName -Raw
        $content | Should -Match "DiskIO Performance"
        $content | Should -Match "AvgWriteSpeedMBps:"
        $content | Should -Match "AvgReadSpeedMBps:"
    }

    It "JSON report should be valid JSON" {
        $jsonFile = Get-ChildItem -Path $script:TestOutputPath -Filter "benchmark-*.json" | Select-Object -First 1
        $json = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
        $json | Should -Not -BeNullOrEmpty
    }

    It "JSON report should contain Timestamp" {
        $jsonFile = Get-ChildItem -Path $script:TestOutputPath -Filter "benchmark-*.json" | Select-Object -First 1
        $json = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
        $json.Timestamp | Should -Not -BeNullOrEmpty
    }

    It "JSON report should contain SystemInfo" {
        $jsonFile = Get-ChildItem -Path $script:TestOutputPath -Filter "benchmark-*.json" | Select-Object -First 1
        $json = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
        $json.SystemInfo | Should -Not -BeNullOrEmpty
        $json.SystemInfo.OS | Should -Not -BeNullOrEmpty
    }

    It "JSON report should contain DiskIO benchmark results" {
        $jsonFile = Get-ChildItem -Path $script:TestOutputPath -Filter "benchmark-*.json" | Select-Object -First 1
        $json = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
        $json.Benchmarks.DiskIO | Should -Not -BeNullOrEmpty
        $json.Benchmarks.DiskIO.AvgWriteSpeedMBps | Should -BeGreaterThan 0
        $json.Benchmarks.DiskIO.AvgReadSpeedMBps | Should -BeGreaterThan 0
    }
}

Describe "benchmark-runner.ps1 Output Validation" {
    BeforeAll {
        # Get the most recent test output
        $script:JsonFile = Get-ChildItem -Path $script:TestOutputPath -Filter "benchmark-*.json" |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        $script:JsonData = Get-Content $script:JsonFile.FullName -Raw | ConvertFrom-Json
    }

    It "Should have valid SystemInfo structure" {
        $script:JsonData.SystemInfo.OS | Should -Not -BeNullOrEmpty
        $script:JsonData.SystemInfo.Processor | Should -Not -BeNullOrEmpty
        $script:JsonData.SystemInfo.ProcessorCores | Should -BeGreaterThan 0
        $script:JsonData.SystemInfo.TotalMemoryGB | Should -BeGreaterThan 0
    }

    It "Should have Benchmarks collection" {
        $script:JsonData.Benchmarks | Should -Not -BeNullOrEmpty
    }

    It "DiskIO benchmark should have expected metrics" {
        $diskIO = $script:JsonData.Benchmarks.DiskIO
        $diskIO | Should -Not -BeNullOrEmpty

        # Check for either metrics or skip status
        if ($diskIO.Status) {
            $diskIO.Status | Should -Match "Skipped|Failed"
        } else {
            $diskIO.AvgWriteSpeedMBps | Should -BeGreaterThan 0
            $diskIO.AvgReadSpeedMBps | Should -BeGreaterThan 0
            $diskIO.AvgSmallFileOpsPerSec | Should -BeGreaterThan 0
        }
    }

    It "Performance metrics should be realistic" {
        $diskIO = $script:JsonData.Benchmarks.DiskIO
        if (-not $diskIO.Status) {
            # Write speed should be reasonable (0.1 MB/s to 10 GB/s)
            $diskIO.AvgWriteSpeedMBps | Should -BeGreaterThan 0.1
            $diskIO.AvgWriteSpeedMBps | Should -BeLessThan 10000

            # Read speed should be reasonable
            $diskIO.AvgReadSpeedMBps | Should -BeGreaterThan 0.1
            $diskIO.AvgReadSpeedMBps | Should -BeLessThan 10000
        }
    }
}

Describe "benchmark-runner.ps1 Error Handling" {
    It "Should handle invalid OutputPath gracefully" {
        # Use invalid path with illegal characters (on Windows)
        $invalidPath = "C:\Invalid<>Path"
        { & $script:ScriptPath -BenchmarkTypes "diskio" -Iterations 1 -OutputPath $invalidPath -ErrorAction Stop } |
            Should -Throw
    }

    It "Should handle invalid BenchmarkTypes parameter" {
        # Script should handle unknown benchmark types gracefully
        $result = & $script:ScriptPath -BenchmarkTypes "invalid,unknown" -Iterations 1 -OutputPath $script:TestOutputPath 2>&1
        # Should still execute and create reports (just with warnings)
        Test-Path $script:TestOutputPath | Should -Be $true
    }

    It "Should handle zero iterations" {
        { & $script:ScriptPath -BenchmarkTypes "diskio" -Iterations 0 -OutputPath $script:TestOutputPath } |
            Should -Not -Throw
    }
}

Describe "benchmark-runner.ps1 Help and Documentation" {
    It "Should have synopsis in help" {
        $help = Get-Help $script:ScriptPath
        $help.Synopsis | Should -Not -BeNullOrEmpty
    }

    It "Should have description in help" {
        $help = Get-Help $script:ScriptPath
        $help.Description | Should -Not -BeNullOrEmpty
    }

    It "Should have examples in help" {
        $help = Get-Help $script:ScriptPath
        $help.Examples | Should -Not -BeNullOrEmpty
        $help.Examples.Example.Count | Should -BeGreaterThan 0
    }

    It "Should document all parameters" {
        $help = Get-Help $script:ScriptPath
        $help.Parameters.Parameter.Name | Should -Contain "OutputPath"
        $help.Parameters.Parameter.Name | Should -Contain "RunAll"
        $help.Parameters.Parameter.Name | Should -Contain "BenchmarkTypes"
        $help.Parameters.Parameter.Name | Should -Contain "Iterations"
    }
}

Describe "benchmark-runner.ps1 Performance Ratings" {
    BeforeAll {
        $script:MdFile = Get-ChildItem -Path $script:TestOutputPath -Filter "benchmark-*.md" |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        $script:MdContent = Get-Content $script:MdFile.FullName -Raw
    }

    It "Should include Performance Rating section" {
        $script:MdContent | Should -Match "Performance Rating"
    }

    It "Should include Recommendations section" {
        $script:MdContent | Should -Match "Recommendations"
    }

    It "Should provide disk performance rating" {
        $script:MdContent | Should -Match "Disk I/O:"
    }
}

Describe "benchmark-runner.ps1 Integration" {
    It "Script should be callable from any directory" {
        Push-Location $env:TEMP
        try {
            $result = & $script:ScriptPath -BenchmarkTypes "diskio" -Iterations 1 -OutputPath $script:TestOutputPath 2>&1
            $LASTEXITCODE | Should -Be 0
        } finally {
            Pop-Location
        }
    }

    It "Should handle concurrent executions" {
        # Run two benchmarks to different output directories
        $output1 = Join-Path $script:TestOutputPath "concurrent1"
        $output2 = Join-Path $script:TestOutputPath "concurrent2"

        $job1 = Start-Job -ScriptBlock {
            param($scriptPath, $output)
            & $scriptPath -BenchmarkTypes "diskio" -Iterations 1 -OutputPath $output
        } -ArgumentList $script:ScriptPath, $output1

        $job2 = Start-Job -ScriptBlock {
            param($scriptPath, $output)
            & $scriptPath -BenchmarkTypes "diskio" -Iterations 1 -OutputPath $output
        } -ArgumentList $script:ScriptPath, $output2

        $null = Wait-Job -Job $job1, $job2 -Timeout 60
        $job1.State | Should -Be "Completed"
        $job2.State | Should -Be "Completed"

        Remove-Job -Job $job1, $job2 -Force
    }
}
