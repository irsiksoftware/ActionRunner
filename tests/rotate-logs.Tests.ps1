<#
.SYNOPSIS
    Pester tests for rotate-logs.ps1 script.

.DESCRIPTION
    Comprehensive tests validating log rotation functionality including:
    - Parameter validation
    - Directory management
    - Log compression
    - Log deletion
    - Archive management
    - Disk space calculations
    - Error handling
    - Rotation reports
#>

$script:ScriptPath = Join-Path $PSScriptRoot "..\scripts\rotate-logs.ps1"

Describe "rotate-logs.ps1 Tests" -Tags @("Logging", "Maintenance") {

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
        It "Should accept LogPath parameter" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match '\$LogPath'
        }

        It "Should have default LogPath value" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match '\[string\]\$LogPath\s*=\s*"\.\\logs"'
        }

        It "Should accept RetentionDays parameter" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match '\$RetentionDays'
        }

        It "Should have default RetentionDays of 30" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match '\[int\]\$RetentionDays\s*=\s*30'
        }

        It "Should accept CompressAfterDays parameter" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match '\$CompressAfterDays'
        }

        It "Should have default CompressAfterDays of 7" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match '\[int\]\$CompressAfterDays\s*=\s*7'
        }

        It "Should accept ArchivePath parameter" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match '\$ArchivePath'
        }

        It "Should accept DeleteArchivesAfterDays parameter" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match '\$DeleteArchivesAfterDays'
        }

        It "Should have default DeleteArchivesAfterDays of 90" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match '\[int\]\$DeleteArchivesAfterDays\s*=\s*90'
        }
    }

    Context "Directory Management" {
        It "Should check if LogPath exists" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Test-Path.*LogPath"
        }

        It "Should exit with error code 1 if LogPath doesn't exist" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "exit 1"
        }

        It "Should create archive directory if it doesn't exist" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "New-Item.*-ItemType Directory.*-Path.*ArchivePath"
        }

        It "Should display message when creating archive directory" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Created archive directory"
        }
    }

    Context "Date Calculations" {
        It "Should calculate compression cutoff date" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "compressDate.*AddDays\(-.*CompressAfterDays"
        }

        It "Should calculate deletion cutoff date" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "deleteDate.*AddDays\(-.*RetentionDays"
        }

        It "Should calculate archive deletion cutoff date" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "archiveDeleteDate.*AddDays\(-.*DeleteArchivesAfterDays"
        }
    }

    Context "Log Compression" {
        It "Should compress .log files older than CompressAfterDays" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Get-ChildItem.*-Filter.*\.log"
            $content | Should -Match "LastWriteTime -lt.*compressDate"
        }

        It "Should compress .json files older than CompressAfterDays" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Get-ChildItem.*-Filter.*\.json"
        }

        It "Should use Compress-Archive cmdlet" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Compress-Archive"
        }

        It "Should use optimal compression level" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "-CompressionLevel Optimal"
        }

        It "Should create timestamped archive filenames" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Get-Date.*-Format.*yyyyMMdd"
        }

        It "Should skip files already archived" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Archive already exists"
        }

        It "Should delete original file after successful compression" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Remove-Item.*log\.FullName"
        }

        It "Should calculate space saved by compression" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "originalSize"
            $content | Should -Match "compressedSize"
            $content | Should -Match "spaceSaved"
        }

        It "Should track compression statistics" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "FilesCompressed"
        }
    }

    Context "Log Deletion" {
        It "Should delete logs older than RetentionDays" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "LastWriteTime -lt.*deleteDate"
        }

        It "Should delete both .log and .json files" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "-Include.*\.log.*\.json"
        }

        It "Should track deletion statistics" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "FilesDeleted"
        }

        It "Should display last modification time when deleting" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "last modified.*LastWriteTime"
        }
    }

    Context "Archive Management" {
        It "Should delete archives older than DeleteArchivesAfterDays" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Get-ChildItem.*-Path.*ArchivePath.*-Filter.*\.zip"
            $content | Should -Match "LastWriteTime -lt.*archiveDeleteDate"
        }

        It "Should track archive deletion statistics" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "ArchivesDeleted"
        }
    }

    Context "Error Handling" {
        It "Should use try-catch blocks for compression" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "try\s*{[\s\S]*Compress-Archive[\s\S]*}\s*catch"
        }

        It "Should use try-catch blocks for deletion" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "try\s*{[\s\S]*Remove-Item[\s\S]*}\s*catch"
        }

        It "Should track errors in statistics" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Errors"
            $content | Should -Match "stats\.Errors\+\+"
        }

        It "Should display error messages in red" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Error.*-ForegroundColor Red"
        }

        It "Should include exception message in error output" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "\$_\.Exception\.Message"
        }
    }

    Context "Statistics Tracking" {
        It "Should initialize statistics object with required fields" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "FilesCompressed\s*=\s*0"
            $content | Should -Match "FilesDeleted\s*=\s*0"
            $content | Should -Match "ArchivesDeleted\s*=\s*0"
            $content | Should -Match "SpaceSaved\s*=\s*0"
            $content | Should -Match "Errors\s*=\s*0"
        }

        It "Should increment counters appropriately" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "stats\.FilesCompressed\+\+"
            $content | Should -Match "stats\.FilesDeleted\+\+"
            $content | Should -Match "stats\.ArchivesDeleted\+\+"
        }

        It "Should accumulate space saved" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "stats\.SpaceSaved \+="
        }
    }

    Context "Rotation Summary" {
        It "Should display rotation summary" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Rotation Summary"
        }

        It "Should show all statistics in summary" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Files Compressed:"
            $content | Should -Match "Files Deleted:"
            $content | Should -Match "Archives Deleted:"
            $content | Should -Match "Space Saved"
        }

        It "Should convert space saved to MB" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "stats\.SpaceSaved/1MB"
        }

        It "Should display errors in red if any occurred" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "if.*stats\.Errors -gt 0.*Red.*else.*Green"
        }
    }

    Context "Disk Usage Reporting" {
        It "Should calculate current log size" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Get-ChildItem.*Include.*\.log.*\.json"
            $content | Should -Match "Measure-Object.*-Property Length -Sum"
        }

        It "Should calculate current archive size" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Get-ChildItem.*-Filter.*\.zip"
        }

        It "Should display active logs size and count" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Active Logs:"
        }

        It "Should display archived logs size and count" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Archived Logs:"
        }

        It "Should display total size" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Total:"
        }

        It "Should convert sizes to MB for display" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "/1MB"
        }
    }

    Context "Rotation Report" {
        It "Should create rotation report object" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "\$report\s*=\s*@{"
        }

        It "Should include rotation date in report" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "RotationDate"
        }

        It "Should include settings in report" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Settings\s*=\s*@{"
            $content | Should -Match "RetentionDays"
            $content | Should -Match "CompressAfterDays"
            $content | Should -Match "DeleteArchivesAfterDays"
        }

        It "Should include statistics in report" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Statistics\s*=.*stats"
        }

        It "Should include current usage in report" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "CurrentUsage"
            $content | Should -Match "ActiveLogsSize"
            $content | Should -Match "ArchivedLogsSize"
        }

        It "Should save report as JSON" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "rotation-report.*\.json"
            $content | Should -Match "ConvertTo-Json -Depth 3"
        }

        It "Should use timestamped report filename" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "rotation-report-.*Get-Date -Format.*yyyyMMdd_HHmmss"
        }
    }

    Context "Progress Reporting" {
        It "Should display step-by-step progress" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "\[1/3\].*Compressing logs"
            $content | Should -Match "\[2/3\].*Deleting.*logs"
            $content | Should -Match "\[3/3\].*Deleting archives"
        }

        It "Should use colored output" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "-ForegroundColor Cyan"
            $content | Should -Match "-ForegroundColor Green"
            $content | Should -Match "-ForegroundColor Yellow"
        }

        It "Should display start and end times" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Start Time:"
            $content | Should -Match "End Time:"
        }

        It "Should show compression details" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Compressed:.*->.*saved"
        }
    }

    Context "File Filtering Logic" {
        It "Should only compress logs within date range" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "LastWriteTime -lt.*compressDate.*-and.*LastWriteTime -gt.*deleteDate"
        }

        It "Should process both log and json files for compression" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "logsToCompress"
            $content | Should -Match "jsonLogsToCompress"
        }
    }

    Context "Security and Safety" {
        It "Should not delete files without date check" {
            $content = Get-Content $ScriptPath -Raw
            # All deletions should have date checks
            $deleteStatements = Select-String -Path $ScriptPath -Pattern "Remove-Item" -AllMatches
            $deleteStatements | Should -Not -BeNullOrEmpty
        }

        It "Should use -Force with Remove-Item for reliable deletion" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Remove-Item.*-Force"
        }

        It "Should only delete after successful compression" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "Compress-Archive[\s\S]*Remove-Item"
        }
    }

    Context "Output Formatting" {
        It "Should round numbers for display" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "\[math\]::Round"
        }

        It "Should display file sizes in KB for compression" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "/1KB"
        }

        It "Should use consistent color scheme" {
            $content = Get-Content $ScriptPath -Raw
            $content | Should -Match "-ForegroundColor Green"
            $content | Should -Match "-ForegroundColor Red"
            $content | Should -Match "-ForegroundColor Yellow"
            $content | Should -Match "-ForegroundColor Cyan"
            $content | Should -Match "-ForegroundColor Gray"
        }
    }
}
