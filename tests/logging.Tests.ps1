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

Describe "Log Rotation Verification Tests" {
    BeforeAll {
        $script:RotateScript = Join-Path $ScriptsPath "rotate-logs.ps1"
        $script:VerificationLogsPath = Join-Path $TestRoot "verification-logs"

        # Create fresh test environment
        if (Test-Path $VerificationLogsPath) {
            Remove-Item $VerificationLogsPath -Recurse -Force
        }
        New-Item -Path $VerificationLogsPath -ItemType Directory -Force | Out-Null
    }

    Context "File Compression Verification" {
        BeforeAll {
            # Create test logs with different ages
            $script:TestFiles = @()

            # Create 3 old logs (35, 40, 45 days old)
            for ($i = 35; $i -le 45; $i += 5) {
                $logFile = Join-Path $VerificationLogsPath "old-log-$i.log"
                "Test log content $(Get-Date)" | Set-Content $logFile
                (Get-Item $logFile).LastWriteTime = (Get-Date).AddDays(-$i)
                $script:TestFiles += $logFile
            }

            # Create 2 recent logs (5, 15 days old)
            for ($i = 5; $i -le 15; $i += 10) {
                $logFile = Join-Path $VerificationLogsPath "recent-log-$i.log"
                "Test log content $(Get-Date)" | Set-Content $logFile
                (Get-Item $logFile).LastWriteTime = (Get-Date).AddDays(-$i)
                $script:TestFiles += $logFile
            }
        }

        It "Should compress only logs older than retention period" {
            & $RotateScript -LogPath $VerificationLogsPath -RetentionDays 30 -ArchiveRetentionDays 90

            # Old logs should be compressed and removed
            Test-Path (Join-Path $VerificationLogsPath "old-log-35.log") | Should -Be $false
            Test-Path (Join-Path $VerificationLogsPath "old-log-40.log") | Should -Be $false
            Test-Path (Join-Path $VerificationLogsPath "old-log-45.log") | Should -Be $false

            # Recent logs should remain uncompressed
            Test-Path (Join-Path $VerificationLogsPath "recent-log-5.log") | Should -Be $true
            Test-Path (Join-Path $VerificationLogsPath "recent-log-15.log") | Should -Be $true
        }

        It "Should create archive directory if it doesn't exist" {
            $newTestPath = Join-Path $TestRoot "no-archive-test"
            New-Item -Path $newTestPath -ItemType Directory -Force | Out-Null

            $testLog = Join-Path $newTestPath "test.log"
            "content" | Set-Content $testLog
            (Get-Item $testLog).LastWriteTime = (Get-Date).AddDays(-35)

            & $RotateScript -LogPath $newTestPath -RetentionDays 30

            Test-Path (Join-Path $newTestPath "archive") | Should -Be $true

            Remove-Item $newTestPath -Recurse -Force
        }

        It "Should preserve file content in compressed archives" {
            # Create log with specific content
            $contentTestPath = Join-Path $TestRoot "content-test"
            New-Item -Path $contentTestPath -ItemType Directory -Force | Out-Null

            $testContent = "This is test log content with special data: $(Get-Random)"
            $testLog = Join-Path $contentTestPath "content-test.log"
            $testContent | Set-Content $testLog
            (Get-Item $testLog).LastWriteTime = (Get-Date).AddDays(-35)

            & $RotateScript -LogPath $contentTestPath -RetentionDays 30

            # Extract and verify content
            $archive = Get-ChildItem (Join-Path $contentTestPath "archive") -Filter "*.zip" | Select-Object -First 1
            $archive | Should -Not -BeNullOrEmpty

            $extractPath = Join-Path $contentTestPath "extracted"
            Expand-Archive -Path $archive.FullName -DestinationPath $extractPath

            $extractedContent = Get-Content (Join-Path $extractPath "content-test.log") -Raw
            $extractedContent.Trim() | Should -Be $testContent.Trim()

            Remove-Item $contentTestPath -Recurse -Force
        }

        It "Should handle multiple file extensions (.log, .txt, .json)" {
            $extTestPath = Join-Path $TestRoot "extension-test"
            New-Item -Path $extTestPath -ItemType Directory -Force | Out-Null

            # Create files with different extensions
            $extensions = @('.log', '.txt', '.json')
            foreach ($ext in $extensions) {
                $file = Join-Path $extTestPath "test$ext"
                "content" | Set-Content $file
                (Get-Item $file).LastWriteTime = (Get-Date).AddDays(-35)
            }

            # Create file with unsupported extension (should not be compressed)
            $csvFile = Join-Path $extTestPath "test.csv"
            "content" | Set-Content $csvFile
            (Get-Item $csvFile).LastWriteTime = (Get-Date).AddDays(-35)

            & $RotateScript -LogPath $extTestPath -RetentionDays 30

            # Supported extensions should be compressed
            foreach ($ext in $extensions) {
                Test-Path (Join-Path $extTestPath "test$ext") | Should -Be $false
            }

            # Unsupported extension should remain
            Test-Path $csvFile | Should -Be $true

            Remove-Item $extTestPath -Recurse -Force
        }
    }

    Context "Archive Deletion Verification" {
        BeforeAll {
            $script:DeletionTestPath = Join-Path $TestRoot "deletion-test"
            New-Item -Path $DeletionTestPath -ItemType Directory -Force | Out-Null
            New-Item -Path (Join-Path $DeletionTestPath "archive") -ItemType Directory -Force | Out-Null

            # Create archives with different ages
            $tempLog = Join-Path $DeletionTestPath "temp.log"
            "content" | Set-Content $tempLog

            # Very old archive (95 days)
            $veryOldArchive = Join-Path $DeletionTestPath "archive\very-old.zip"
            Compress-Archive -Path $tempLog -DestinationPath $veryOldArchive -Force
            (Get-Item $veryOldArchive).LastWriteTime = (Get-Date).AddDays(-95)

            # Old archive (91 days)
            $oldArchive = Join-Path $DeletionTestPath "archive\old.zip"
            Compress-Archive -Path $tempLog -DestinationPath $oldArchive -Force
            (Get-Item $oldArchive).LastWriteTime = (Get-Date).AddDays(-91)

            # Recent archive (30 days)
            $recentArchive = Join-Path $DeletionTestPath "archive\recent.zip"
            Compress-Archive -Path $tempLog -DestinationPath $recentArchive -Force
            (Get-Item $recentArchive).LastWriteTime = (Get-Date).AddDays(-30)

            Remove-Item $tempLog -Force
        }

        It "Should delete archives older than archive retention period" {
            & $RotateScript -LogPath $DeletionTestPath -RetentionDays 30 -ArchiveRetentionDays 90

            # Very old archives should be deleted
            Test-Path (Join-Path $DeletionTestPath "archive\very-old.zip") | Should -Be $false
            Test-Path (Join-Path $DeletionTestPath "archive\old.zip") | Should -Be $false
        }

        It "Should keep archives within retention period" {
            Test-Path (Join-Path $DeletionTestPath "archive\recent.zip") | Should -Be $true
        }

        AfterAll {
            if (Test-Path $DeletionTestPath) {
                Remove-Item $DeletionTestPath -Recurse -Force
            }
        }
    }

    Context "Rotation Statistics Verification" {
        BeforeAll {
            $script:StatsTestPath = Join-Path $TestRoot "stats-test"
            New-Item -Path $StatsTestPath -ItemType Directory -Force | Out-Null

            # Create known number of files
            for ($i = 1; $i -le 5; $i++) {
                $file = Join-Path $StatsTestPath "old-$i.log"
                "Test content for file $i" | Set-Content $file
                (Get-Item $file).LastWriteTime = (Get-Date).AddDays(-35)
            }
        }

        It "Should return accurate compression statistics" {
            $stats = & $RotateScript -LogPath $StatsTestPath -RetentionDays 30 -ArchiveRetentionDays 90

            $stats.FilesCompressed | Should -Be 5
            $stats.FilesScanned | Should -BeGreaterThan 0
            $stats.BytesCompressed | Should -BeGreaterThan 0
        }

        It "Should calculate space freed correctly" {
            $stats = & $RotateScript -LogPath $StatsTestPath -RetentionDays 30 -ArchiveRetentionDays 90

            $stats.BytesFreed | Should -BeGreaterThan 0
        }

        AfterAll {
            if (Test-Path $StatsTestPath) {
                Remove-Item $StatsTestPath -Recurse -Force
            }
        }
    }

    Context "Edge Cases and Error Handling" {
        It "Should handle empty log directory gracefully" {
            $emptyPath = Join-Path $TestRoot "empty-logs"
            New-Item -Path $emptyPath -ItemType Directory -Force | Out-Null

            { & $RotateScript -LogPath $emptyPath -RetentionDays 30 } | Should -Not -Throw

            Remove-Item $emptyPath -Recurse -Force
        }

        It "Should not compress files in archive directory" {
            $archiveProtectPath = Join-Path $TestRoot "archive-protect-test"
            New-Item -Path $archiveProtectPath -ItemType Directory -Force | Out-Null
            $archiveDir = Join-Path $archiveProtectPath "archive"
            New-Item -Path $archiveDir -ItemType Directory -Force | Out-Null

            # Create old log in archive directory
            $archiveLog = Join-Path $archiveDir "should-not-compress.log"
            "content" | Set-Content $archiveLog
            (Get-Item $archiveLog).LastWriteTime = (Get-Date).AddDays(-35)

            & $RotateScript -LogPath $archiveProtectPath -RetentionDays 30

            # File in archive should not be compressed again
            Test-Path $archiveLog | Should -Be $true

            Remove-Item $archiveProtectPath -Recurse -Force
        }

        It "Should handle custom retention periods" {
            $customPath = Join-Path $TestRoot "custom-retention"
            New-Item -Path $customPath -ItemType Directory -Force | Out-Null

            # Create log 10 days old
            $log = Join-Path $customPath "test.log"
            "content" | Set-Content $log
            (Get-Item $log).LastWriteTime = (Get-Date).AddDays(-10)

            # Use 5-day retention - should compress
            & $RotateScript -LogPath $customPath -RetentionDays 5

            Test-Path $log | Should -Be $false

            Remove-Item $customPath -Recurse -Force
        }

        It "Should clean up empty subdirectories" {
            $subdirPath = Join-Path $TestRoot "subdir-test"
            $subdir = Join-Path $subdirPath "subdir"
            New-Item -Path $subdir -ItemType Directory -Force | Out-Null

            # Create old log in subdirectory
            $log = Join-Path $subdir "old.log"
            "content" | Set-Content $log
            (Get-Item $log).LastWriteTime = (Get-Date).AddDays(-35)

            & $RotateScript -LogPath $subdirPath -RetentionDays 30

            # Subdirectory should be removed after log is compressed
            Test-Path $subdir | Should -Be $false

            Remove-Item $subdirPath -Recurse -Force
        }
    }

    Context "Concurrent Rotation Safety" {
        It "Should handle files locked by other processes gracefully" {
            $lockTestPath = Join-Path $TestRoot "lock-test"
            New-Item -Path $lockTestPath -ItemType Directory -Force | Out-Null

            $lockedLog = Join-Path $lockTestPath "locked.log"
            "content" | Set-Content $lockedLog
            (Get-Item $lockedLog).LastWriteTime = (Get-Date).AddDays(-35)

            # Lock the file
            $stream = [System.IO.File]::Open($lockedLog, 'Open', 'Read', 'None')

            try {
                # Rotation should handle locked file gracefully (skip it)
                { & $RotateScript -LogPath $lockTestPath -RetentionDays 30 -ErrorAction SilentlyContinue } | Should -Not -Throw
            } finally {
                $stream.Close()
                $stream.Dispose()
            }

            Remove-Item $lockTestPath -Recurse -Force
        }
    }

    AfterAll {
        if (Test-Path $VerificationLogsPath) {
            Remove-Item $VerificationLogsPath -Recurse -Force
        }
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
