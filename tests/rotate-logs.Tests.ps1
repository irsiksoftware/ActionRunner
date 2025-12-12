BeforeAll {
    $script:TestRoot = $PSScriptRoot
    $script:ProjectRoot = Split-Path $TestRoot -Parent
    $script:ScriptsPath = Join-Path $ProjectRoot "scripts"
    $script:scriptPath = Join-Path $ScriptsPath "rotate-logs.ps1"
}

Describe "rotate-logs.ps1" {
    BeforeEach {
        # Create test logs structure
        $script:testRoot = Join-Path $TestDrive "logs-test-$(Get-Random)"
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

        It "Script should support -LogPath parameter" {
            $help = Get-Help $scriptPath
            $help.parameters.parameter.name | Should -Contain 'LogPath'
        }

        It "Script should support -RetentionDays parameter" {
            $help = Get-Help $scriptPath
            $help.parameters.parameter.name | Should -Contain 'RetentionDays'
        }

        It "Script should support -ArchiveRetentionDays parameter" {
            $help = Get-Help $scriptPath
            $help.parameters.parameter.name | Should -Contain 'ArchiveRetentionDays'
        }

        It "Script should support -DryRun parameter" {
            $help = Get-Help $scriptPath
            $help.parameters.parameter.name | Should -Contain 'DryRun'
        }
    }

    Context "Log Path Validation" {
        It "Should exit with error if log path does not exist" {
            $nonExistentPath = Join-Path $script:testRoot "nonexistent"

            $result = & $scriptPath -LogPath $nonExistentPath 2>&1
            $LASTEXITCODE | Should -Be 1
        }

        It "Should create archive directory if it does not exist" {
            $archivePath = Join-Path $script:testRoot "archive"

            & $scriptPath -LogPath $script:testRoot

            Test-Path $archivePath | Should -Be $true
        }

        It "Should not create archive directory in dry run mode" {
            # Use a fresh test directory that definitely has no archive folder
            $freshTestRoot = Join-Path $TestDrive "fresh-logs-test"
            New-Item -ItemType Directory -Path $freshTestRoot -Force | Out-Null
            $archivePath = Join-Path $freshTestRoot "archive"

            & $scriptPath -LogPath $freshTestRoot -DryRun

            Test-Path $archivePath | Should -Be $false
        }
    }

    Context "Log Compression" {
        It "Should compress logs older than retention days" {
            # Create old log file
            $logFile = Join-Path $script:testRoot "old.log"
            "test log content" | Out-File -FilePath $logFile
            (Get-Item $logFile).LastWriteTime = (Get-Date).AddDays(-35)

            & $scriptPath -LogPath $script:testRoot -RetentionDays 30

            # Original should be gone
            Test-Path $logFile | Should -Be $false
            # Archive should exist
            $archiveFiles = Get-ChildItem -Path (Join-Path $script:testRoot "archive") -Filter "*.zip"
            $archiveFiles.Count | Should -BeGreaterThan 0
        }

        It "Should not compress logs within retention period" {
            # Create recent log file
            $logFile = Join-Path $script:testRoot "recent.log"
            "test log content" | Out-File -FilePath $logFile
            (Get-Item $logFile).LastWriteTime = (Get-Date).AddDays(-10)

            & $scriptPath -LogPath $script:testRoot -RetentionDays 30

            # Original should still exist
            Test-Path $logFile | Should -Be $true
        }

        It "Should compress .txt files" {
            $logFile = Join-Path $script:testRoot "old.txt"
            "test content" | Out-File -FilePath $logFile
            (Get-Item $logFile).LastWriteTime = (Get-Date).AddDays(-35)

            & $scriptPath -LogPath $script:testRoot -RetentionDays 30

            Test-Path $logFile | Should -Be $false
        }

        It "Should compress .json files" {
            $logFile = Join-Path $script:testRoot "old.json"
            '{"test": "content"}' | Out-File -FilePath $logFile
            (Get-Item $logFile).LastWriteTime = (Get-Date).AddDays(-35)

            & $scriptPath -LogPath $script:testRoot -RetentionDays 30

            Test-Path $logFile | Should -Be $false
        }

        It "Should not compress files in archive directory" {
            # Create archive directory and put a log file in it
            $archivePath = Join-Path $script:testRoot "archive"
            New-Item -ItemType Directory -Path $archivePath -Force | Out-Null
            $logFile = Join-Path $archivePath "archived.log"
            "archived content" | Out-File -FilePath $logFile
            (Get-Item $logFile).LastWriteTime = (Get-Date).AddDays(-35)

            & $scriptPath -LogPath $script:testRoot -RetentionDays 30

            # File in archive should be untouched (it's a .log, not .zip, but excluded by directory)
            Test-Path $logFile | Should -Be $true
        }

        It "Should handle subdirectories recursively" {
            $subDir = Join-Path $script:testRoot "subdir"
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null
            $logFile = Join-Path $subDir "nested.log"
            "nested log content" | Out-File -FilePath $logFile
            (Get-Item $logFile).LastWriteTime = (Get-Date).AddDays(-35)

            & $scriptPath -LogPath $script:testRoot -RetentionDays 30

            Test-Path $logFile | Should -Be $false
        }
    }

    Context "Archive Deletion" {
        It "Should delete archives older than archive retention days" {
            $archivePath = Join-Path $script:testRoot "archive"
            New-Item -ItemType Directory -Path $archivePath -Force | Out-Null
            $oldArchive = Join-Path $archivePath "old_2024-01-01.zip"
            "fake zip content" | Out-File -FilePath $oldArchive
            (Get-Item $oldArchive).LastWriteTime = (Get-Date).AddDays(-100)

            & $scriptPath -LogPath $script:testRoot -ArchiveRetentionDays 90

            Test-Path $oldArchive | Should -Be $false
        }

        It "Should not delete archives within archive retention period" {
            $archivePath = Join-Path $script:testRoot "archive"
            New-Item -ItemType Directory -Path $archivePath -Force | Out-Null
            $recentArchive = Join-Path $archivePath "recent_2024-01-01.zip"
            "fake zip content" | Out-File -FilePath $recentArchive
            (Get-Item $recentArchive).LastWriteTime = (Get-Date).AddDays(-60)

            & $scriptPath -LogPath $script:testRoot -ArchiveRetentionDays 90

            Test-Path $recentArchive | Should -Be $true
        }
    }

    Context "Empty Directory Cleanup" {
        It "Should remove empty directories after compression" {
            $subDir = Join-Path $script:testRoot "emptyafter"
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null
            $logFile = Join-Path $subDir "only.log"
            "content" | Out-File -FilePath $logFile
            (Get-Item $logFile).LastWriteTime = (Get-Date).AddDays(-35)

            & $scriptPath -LogPath $script:testRoot -RetentionDays 30

            Test-Path $subDir | Should -Be $false
        }

        It "Should not remove non-empty directories" {
            $subDir = Join-Path $script:testRoot "notempty"
            New-Item -ItemType Directory -Path $subDir -Force | Out-Null
            $logFile = Join-Path $subDir "recent.log"
            "content" | Out-File -FilePath $logFile
            # Keep it recent so it doesn't get compressed
            (Get-Item $logFile).LastWriteTime = (Get-Date).AddDays(-5)

            & $scriptPath -LogPath $script:testRoot -RetentionDays 30

            Test-Path $subDir | Should -Be $true
        }

        It "Should not remove archive directory" {
            $archivePath = Join-Path $script:testRoot "archive"
            New-Item -ItemType Directory -Path $archivePath -Force | Out-Null

            & $scriptPath -LogPath $script:testRoot -RetentionDays 30

            Test-Path $archivePath | Should -Be $true
        }
    }

    Context "Dry Run Mode" {
        It "Should not compress files in dry run mode" {
            $logFile = Join-Path $script:testRoot "old.log"
            "test log content" | Out-File -FilePath $logFile
            (Get-Item $logFile).LastWriteTime = (Get-Date).AddDays(-35)

            & $scriptPath -LogPath $script:testRoot -RetentionDays 30 -DryRun

            Test-Path $logFile | Should -Be $true
        }

        It "Should not delete archives in dry run mode" {
            $archivePath = Join-Path $script:testRoot "archive"
            New-Item -ItemType Directory -Path $archivePath -Force | Out-Null
            $oldArchive = Join-Path $archivePath "old_2024-01-01.zip"
            "fake zip content" | Out-File -FilePath $oldArchive
            (Get-Item $oldArchive).LastWriteTime = (Get-Date).AddDays(-100)

            & $scriptPath -LogPath $script:testRoot -ArchiveRetentionDays 90 -DryRun

            Test-Path $oldArchive | Should -Be $true
        }

        It "Should not remove empty directories in dry run mode" {
            $emptyDir = Join-Path $script:testRoot "emptydir"
            New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null

            & $scriptPath -LogPath $script:testRoot -DryRun

            Test-Path $emptyDir | Should -Be $true
        }
    }

    Context "Statistics Return" {
        It "Should return statistics hashtable" {
            $result = & $scriptPath -LogPath $script:testRoot

            $result | Should -BeOfType [hashtable]
            $result.Keys | Should -Contain 'FilesScanned'
            $result.Keys | Should -Contain 'FilesCompressed'
            $result.Keys | Should -Contain 'FilesDeleted'
            $result.Keys | Should -Contain 'BytesFreed'
            $result.Keys | Should -Contain 'BytesCompressed'
        }

        It "Should accurately count compressed files" {
            # Create multiple old log files
            for ($i = 1; $i -le 3; $i++) {
                $logFile = Join-Path $script:testRoot "old$i.log"
                "test content $i" | Out-File -FilePath $logFile
                (Get-Item $logFile).LastWriteTime = (Get-Date).AddDays(-35)
            }

            $result = & $scriptPath -LogPath $script:testRoot -RetentionDays 30

            $result.FilesCompressed | Should -Be 3
        }

        It "Should accurately count deleted archives" {
            $archivePath = Join-Path $script:testRoot "archive"
            New-Item -ItemType Directory -Path $archivePath -Force | Out-Null
            for ($i = 1; $i -le 2; $i++) {
                $archive = Join-Path $archivePath "old$i.zip"
                "fake zip content" | Out-File -FilePath $archive
                (Get-Item $archive).LastWriteTime = (Get-Date).AddDays(-100)
            }

            $result = & $scriptPath -LogPath $script:testRoot -ArchiveRetentionDays 90

            $result.FilesDeleted | Should -Be 2
        }
    }

    Context "Error Handling" {
        It "Should continue on compression errors and not crash" {
            # Create a valid log file
            $logFile = Join-Path $script:testRoot "valid.log"
            "content" | Out-File -FilePath $logFile
            (Get-Item $logFile).LastWriteTime = (Get-Date).AddDays(-35)

            # Script should complete without throwing
            { & $scriptPath -LogPath $script:testRoot -RetentionDays 30 } | Should -Not -Throw
        }

        It "Should handle missing archive directory gracefully" {
            # Just run against fresh directory with no archive
            { & $scriptPath -LogPath $script:testRoot } | Should -Not -Throw
        }
    }

    Context "Custom Retention Values" {
        It "Should respect custom retention days" {
            $logFile = Join-Path $script:testRoot "custom.log"
            "content" | Out-File -FilePath $logFile
            # 10 days old
            (Get-Item $logFile).LastWriteTime = (Get-Date).AddDays(-10)

            # With 7 day retention, should be compressed
            & $scriptPath -LogPath $script:testRoot -RetentionDays 7

            Test-Path $logFile | Should -Be $false
        }

        It "Should respect custom archive retention days" {
            $archivePath = Join-Path $script:testRoot "archive"
            New-Item -ItemType Directory -Path $archivePath -Force | Out-Null
            $archive = Join-Path $archivePath "test.zip"
            "fake zip" | Out-File -FilePath $archive
            # 50 days old
            (Get-Item $archive).LastWriteTime = (Get-Date).AddDays(-50)

            # With 45 day archive retention, should be deleted
            & $scriptPath -LogPath $script:testRoot -ArchiveRetentionDays 45

            Test-Path $archive | Should -Be $false
        }
    }
}
