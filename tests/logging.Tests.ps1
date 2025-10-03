BeforeAll {
    # Import Pester module
    Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

    # Setup test environment
    $script:TestRoot = $PSScriptRoot
    $script:ProjectRoot = Split-Path $TestRoot -Parent
    $script:ScriptsPath = Join-Path $ProjectRoot "scripts"
    $script:TestLogsPath = Join-Path $TestRoot "test-logs"

    # Ensure test logs directory exists
    if (Test-Path $TestLogsPath) {
        Remove-Item $TestLogsPath -Recurse -Force
    }
    New-Item -Path $TestLogsPath -ItemType Directory -Force | Out-Null
}

Describe "Log Collection Script" {
    BeforeAll {
        $script:CollectScript = Join-Path $ScriptsPath "collect-logs.ps1"
    }

    It "Should exist" {
        Test-Path $CollectScript | Should -Be $true
    }

    It "Should have proper parameters" {
        $params = (Get-Command $CollectScript).Parameters.Keys
        $params | Should -Contain 'OutputPath'
        $params | Should -Contain 'Days'
        $params | Should -Contain 'IncludeWindowsEvents'
    }

    It "Should create log directory structure" {
        & $CollectScript -OutputPath $TestLogsPath -Days 1

        Test-Path (Join-Path $TestLogsPath "runner") | Should -Be $true
        Test-Path (Join-Path $TestLogsPath "jobs") | Should -Be $true
        Test-Path (Join-Path $TestLogsPath "performance") | Should -Be $true
        Test-Path (Join-Path $TestLogsPath "security") | Should -Be $true
    }

    It "Should create collection directory with timestamp" {
        & $CollectScript -OutputPath $TestLogsPath -Days 1

        $collections = Get-ChildItem $TestLogsPath -Directory | Where-Object { $_.Name -like "collection_*" }
        $collections.Count | Should -BeGreaterThan 0
    }

    It "Should create manifest file" {
        & $CollectScript -OutputPath $TestLogsPath -Days 1

        $collection = Get-ChildItem $TestLogsPath -Directory | Where-Object { $_.Name -like "collection_*" } | Select-Object -First 1
        $manifestPath = Join-Path $collection.FullName "manifest.json"

        Test-Path $manifestPath | Should -Be $true

        $manifest = Get-Content $manifestPath | ConvertFrom-Json
        $manifest.DaysCollected | Should -Be 1
    }

    It "Should create required log files" {
        & $CollectScript -OutputPath $TestLogsPath -Days 1

        $collection = Get-ChildItem $TestLogsPath -Directory | Where-Object { $_.Name -like "collection_*" } | Select-Object -First 1

        Test-Path (Join-Path $collection.FullName "runner-service.log") | Should -Be $true
        Test-Path (Join-Path $collection.FullName "job-executions.log") | Should -Be $true
        Test-Path (Join-Path $collection.FullName "system-performance.log") | Should -Be $true
        Test-Path (Join-Path $collection.FullName "security-audit.log") | Should -Be $true
    }

    AfterAll {
        if (Test-Path $TestLogsPath) {
            Remove-Item $TestLogsPath -Recurse -Force
        }
    }
}

Describe "Log Rotation Script" {
    BeforeAll {
        $script:RotateScript = Join-Path $ScriptsPath "rotate-logs.ps1"

        # Create test logs
        New-Item -Path $TestLogsPath -ItemType Directory -Force | Out-Null
        New-Item -Path (Join-Path $TestLogsPath "archive") -ItemType Directory -Force | Out-Null

        # Create old log file (35 days old)
        $oldLog = Join-Path $TestLogsPath "old-log.log"
        "Old log content" | Set-Content $oldLog
        (Get-Item $oldLog).LastWriteTime = (Get-Date).AddDays(-35)

        # Create recent log file (5 days old)
        $recentLog = Join-Path $TestLogsPath "recent-log.log"
        "Recent log content" | Set-Content $recentLog
        (Get-Item $recentLog).LastWriteTime = (Get-Date).AddDays(-5)

        # Create very old archive (95 days old)
        $oldArchive = Join-Path $TestLogsPath "archive\very-old.zip"
        Compress-Archive -Path $oldLog -DestinationPath $oldArchive -Force
        (Get-Item $oldArchive).LastWriteTime = (Get-Date).AddDays(-95)
    }

    It "Should exist" {
        Test-Path $RotateScript | Should -Be $true
    }

    It "Should have proper parameters" {
        $params = (Get-Command $RotateScript).Parameters.Keys
        $params | Should -Contain 'LogPath'
        $params | Should -Contain 'RetentionDays'
        $params | Should -Contain 'ArchiveRetentionDays'
        $params | Should -Contain 'DryRun'
    }

    It "Should support dry run mode" {
        $result = & $RotateScript -LogPath $TestLogsPath -RetentionDays 30 -DryRun

        # Old log should still exist in dry run
        Test-Path (Join-Path $TestLogsPath "old-log.log") | Should -Be $true
    }

    It "Should compress old logs" {
        # Reset test environment
        Remove-Item (Join-Path $TestLogsPath "archive\*") -Force -ErrorAction SilentlyContinue

        & $RotateScript -LogPath $TestLogsPath -RetentionDays 30 -ArchiveRetentionDays 90

        # Check archive was created
        $archives = Get-ChildItem (Join-Path $TestLogsPath "archive") -Filter "*.zip"
        $archives.Count | Should -BeGreaterThan 0
    }

    It "Should keep recent logs uncompressed" {
        Test-Path (Join-Path $TestLogsPath "recent-log.log") | Should -Be $true
    }

    It "Should delete very old archives" {
        & $RotateScript -LogPath $TestLogsPath -RetentionDays 30 -ArchiveRetentionDays 90

        # Very old archive should be deleted
        $veryOldArchive = Join-Path $TestLogsPath "archive\very-old.zip"
        Test-Path $veryOldArchive | Should -Be $false
    }

    It "Should return statistics" {
        $stats = & $RotateScript -LogPath $TestLogsPath -RetentionDays 30 -ArchiveRetentionDays 90

        $stats.Keys | Should -Contain 'FilesScanned'
        $stats.Keys | Should -Contain 'FilesCompressed'
        $stats.Keys | Should -Contain 'FilesDeleted'
        $stats.Keys | Should -Contain 'BytesFreed'
    }

    AfterAll {
        if (Test-Path $TestLogsPath) {
            Remove-Item $TestLogsPath -Recurse -Force
        }
    }
}

Describe "Log Analysis Script" {
    BeforeAll {
        $script:AnalyzeScript = Join-Path $ScriptsPath "analyze-logs.ps1"

        # Create test logs with sample content
        New-Item -Path $TestLogsPath -ItemType Directory -Force | Out-Null

        # Create log with errors
        $errorLog = Join-Path $TestLogsPath "error-log.log"
        @"
2024-01-01 10:00:00 INFO: Starting job
2024-01-01 10:01:00 ERROR: Failed to connect to service
2024-01-01 10:02:00 WARNING: Retry attempt 1
2024-01-01 10:03:00 ERROR: Connection timeout
2024-01-01 10:04:00 INFO: Job completed
"@ | Set-Content $errorLog

        # Create performance log
        $perfLog = Join-Path $TestLogsPath "performance.log"
        @"
=== System Performance ===
LoadPercentage : 45
TotalVisibleMemorySize : 16777216
FreePhysicalMemory : 8388608
"@ | Set-Content $perfLog

        # Create job log
        $jobLog = Join-Path $TestLogsPath "job.log"
        @"
Job started
Step 1: success
Step 2: success
Job completed successfully
"@ | Set-Content $jobLog

        # Set realistic timestamps
        (Get-Item $errorLog).LastWriteTime = (Get-Date).AddDays(-1)
        (Get-Item $perfLog).LastWriteTime = (Get-Date).AddDays(-1)
        (Get-Item $jobLog).LastWriteTime = (Get-Date).AddDays(-1)
    }

    It "Should exist" {
        Test-Path $AnalyzeScript | Should -Be $true
    }

    It "Should have proper parameters" {
        $params = (Get-Command $AnalyzeScript).Parameters.Keys
        $params | Should -Contain 'LogPath'
        $params | Should -Contain 'Days'
        $params | Should -Contain 'OutputFormat'
        $params | Should -Contain 'ReportPath'
    }

    It "Should detect errors in logs" {
        $result = & $AnalyzeScript -LogPath $TestLogsPath -Days 7 -OutputFormat JSON | ConvertFrom-Json

        $result.Errors.TotalCount | Should -BeGreaterThan 0
    }

    It "Should analyze performance metrics" {
        $result = & $AnalyzeScript -LogPath $TestLogsPath -Days 7 -OutputFormat JSON | ConvertFrom-Json

        $result.Performance | Should -Not -BeNullOrEmpty
    }

    It "Should provide recommendations" {
        $result = & $AnalyzeScript -LogPath $TestLogsPath -Days 7 -OutputFormat JSON | ConvertFrom-Json

        $result.Recommendations | Should -Not -BeNullOrEmpty
        $result.Recommendations.Count | Should -BeGreaterThan 0
    }

    It "Should support JSON output format" {
        $result = & $AnalyzeScript -LogPath $TestLogsPath -Days 7 -OutputFormat JSON

        { $result | ConvertFrom-Json } | Should -Not -Throw
    }

    It "Should support HTML output format" {
        $result = & $AnalyzeScript -LogPath $TestLogsPath -Days 7 -OutputFormat HTML

        $result | Should -Match '<!DOCTYPE html>'
        $result | Should -Match '<title>Runner Log Analysis</title>'
    }

    It "Should support text output format" {
        $result = & $AnalyzeScript -LogPath $TestLogsPath -Days 7 -OutputFormat Text

        $result | Should -Match 'RUNNER LOG ANALYSIS REPORT'
        $result | Should -Match 'SUMMARY'
        $result | Should -Match 'RECOMMENDATIONS'
    }

    It "Should save report to file" {
        $reportPath = Join-Path $TestLogsPath "analysis-report.json"
        & $AnalyzeScript -LogPath $TestLogsPath -Days 7 -OutputFormat JSON -ReportPath $reportPath

        Test-Path $reportPath | Should -Be $true
    }

    It "Should return analysis object" {
        $result = & $AnalyzeScript -LogPath $TestLogsPath -Days 7 -OutputFormat JSON | ConvertFrom-Json

        $result.Metadata | Should -Not -BeNullOrEmpty
        $result.Summary | Should -Not -BeNullOrEmpty
        $result.Errors | Should -Not -BeNullOrEmpty
        $result.Jobs | Should -Not -BeNullOrEmpty
        $result.Performance | Should -Not -BeNullOrEmpty
        $result.Security | Should -Not -BeNullOrEmpty
        $result.Recommendations | Should -Not -BeNullOrEmpty
    }

    AfterAll {
        if (Test-Path $TestLogsPath) {
            Remove-Item $TestLogsPath -Recurse -Force
        }
    }
}

Describe "Log Directory Structure" {
    BeforeAll {
        $script:LogsDir = Join-Path $ProjectRoot "logs"
    }

    It "Should have logs directory with .gitkeep" {
        Test-Path $LogsDir | Should -Be $true
        Test-Path (Join-Path $LogsDir ".gitkeep") | Should -Be $true
    }

    It "Should be tracked in git" {
        Push-Location $ProjectRoot
        $gitStatus = git ls-files logs/.gitkeep
        Pop-Location

        $gitStatus | Should -Not -BeNullOrEmpty
    }
}

Describe "Integration Tests" {
    BeforeAll {
        New-Item -Path $TestLogsPath -ItemType Directory -Force | Out-Null
    }

    It "Should complete full log workflow" {
        # Step 1: Collect logs
        & (Join-Path $ScriptsPath "collect-logs.ps1") -OutputPath $TestLogsPath -Days 1

        $collection = Get-ChildItem $TestLogsPath -Directory | Where-Object { $_.Name -like "collection_*" } | Select-Object -First 1
        $collection | Should -Not -BeNullOrEmpty

        # Step 2: Analyze logs
        $analysis = & (Join-Path $ScriptsPath "analyze-logs.ps1") -LogPath $TestLogsPath -Days 7 -OutputFormat JSON | ConvertFrom-Json
        $analysis | Should -Not -BeNullOrEmpty

        # Step 3: Rotate logs (dry run)
        $stats = & (Join-Path $ScriptsPath "rotate-logs.ps1") -LogPath $TestLogsPath -DryRun
        $stats | Should -Not -BeNullOrEmpty
    }

    AfterAll {
        if (Test-Path $TestLogsPath) {
            Remove-Item $TestLogsPath -Recurse -Force
        }
    }
}

AfterAll {
    # Cleanup
    if (Test-Path $TestLogsPath) {
        Remove-Item $TestLogsPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
