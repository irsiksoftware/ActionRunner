Describe "update-runner.ps1 Script Tests" {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot "..\scripts\update-runner.ps1"
        $scriptContent = Get-Content $scriptPath -Raw
    }

    Context "Parameter Validation" {
        It "Should have RunnerPath parameter" {
            $scriptContent | Should -Match 'param\s*\('
            $scriptContent | Should -Match '\[string\]\$RunnerPath'
        }

        It "Should have Force switch parameter" {
            $scriptContent | Should -Match '\[switch\]\$Force'
        }

        It "Should have SkipBackup switch parameter" {
            $scriptContent | Should -Match '\[switch\]\$SkipBackup'
        }

        It "Should have Version parameter" {
            $scriptContent | Should -Match '\[string\]\$Version'
        }

        It "Should have MaxWaitMinutes parameter" {
            $scriptContent | Should -Match '\[int\]\$MaxWaitMinutes'
        }

        It "Should have DryRun switch parameter" {
            $scriptContent | Should -Match '\[switch\]\$DryRun'
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

    Context "Logging Functionality" {
        It "Should create log file with timestamp" {
            $scriptContent | Should -Match '\$logFile.*Get-Date.*Format'
        }

        It "Should have Write-UpdateLog function" {
            $scriptContent | Should -Match 'function Write-UpdateLog'
        }

        It "Should support multiple log levels" {
            $scriptContent | Should -Match 'ValidateSet.*INFO.*SUCCESS.*WARN.*ERROR'
        }

        It "Should write to both file and console" {
            $scriptContent | Should -Match 'Add-Content.*\$logFile'
            $scriptContent | Should -Match 'Write-Host'
        }
    }

    Context "Version Management Functions" {
        It "Should have Get-CurrentRunnerVersion function" {
            $scriptContent | Should -Match 'function Get-CurrentRunnerVersion'
        }

        It "Should check .runner configuration file" {
            $scriptContent | Should -Match '\.runner'
            $scriptContent | Should -Match 'ConvertFrom-Json'
        }

        It "Should have Get-LatestRunnerVersion function" {
            $scriptContent | Should -Match 'function Get-LatestRunnerVersion'
        }

        It "Should query GitHub API for latest version" {
            $scriptContent | Should -Match 'api\.github\.com/repos/actions/runner/releases/latest'
            $scriptContent | Should -Match 'Invoke-RestMethod'
        }

        It "Should extract version from tag name" {
            $scriptContent | Should -Match 'tag_name.*-replace.*\^v'
        }

        It "Should find Windows x64 download URL" {
            $scriptContent | Should -Match 'win-x64-.*\.zip'
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

    Context "Service Management Functions" {
        It "Should have Stop-RunnerService function" {
            $scriptContent | Should -Match 'function Stop-RunnerService'
        }

        It "Should have Start-RunnerService function" {
            $scriptContent | Should -Match 'function Start-RunnerService'
        }

        It "Should stop service gracefully" {
            $scriptContent | Should -Match 'Stop-Service'
        }

        It "Should start service after update" {
            $scriptContent | Should -Match 'Start-Service'
        }

        It "Should handle service not found scenario" {
            $scriptContent | Should -Match 'No runner service found'
        }

        It "Should support DryRun mode for service operations" {
            $scriptContent | Should -Match '\[DRY RUN\].*Would stop service'
            $scriptContent | Should -Match '\[DRY RUN\].*Would start service'
        }
    }

    Context "Backup and Restore Functions" {
        It "Should have New-RunnerBackup function" {
            $scriptContent | Should -Match 'function New-RunnerBackup'
        }

        It "Should create backup directory with timestamp" {
            $scriptContent | Should -Match 'runner-backup-.*timestamp'
        }

        It "Should backup critical configuration files" {
            $scriptContent | Should -Match '\.runner'
            $scriptContent | Should -Match '\.credentials'
            $scriptContent | Should -Match '\.credentials_rsaparams'
            $scriptContent | Should -Match '\.path'
        }

        It "Should backup config directory" {
            $scriptContent | Should -Match 'Copy-Item.*config.*-Recurse'
        }

        It "Should have Restore-FromBackup function" {
            $scriptContent | Should -Match 'function Restore-FromBackup'
        }

        It "Should restore backed up files on failure" {
            $scriptContent | Should -Match 'Copy-Item.*\$file\.FullName'
        }

        It "Should support SkipBackup parameter" {
            $scriptContent | Should -Match 'if.*-not \$SkipBackup'
        }
    }

    Context "Installation Functions" {
        It "Should have Install-RunnerUpdate function" {
            $scriptContent | Should -Match 'function Install-RunnerUpdate'
        }

        It "Should download runner package" {
            $scriptContent | Should -Match 'Invoke-WebRequest.*-OutFile'
        }

        It "Should extract to runner path" {
            $scriptContent | Should -Match 'Expand-Archive.*-DestinationPath.*\$RunnerPath'
        }

        It "Should clean up downloaded zip file" {
            $scriptContent | Should -Match 'Remove-Item.*downloadPath'
        }

        It "Should support DryRun mode for installation" {
            $scriptContent | Should -Match '\[DRY RUN\].*Would download'
        }

        It "Should have Test-RunnerInstallation function" {
            $scriptContent | Should -Match 'function Test-RunnerInstallation'
        }

        It "Should verify required files exist" {
            $scriptContent | Should -Match 'run\.cmd'
            $scriptContent | Should -Match 'config\.cmd'
            $scriptContent | Should -Match 'Runner\.Listener\.exe'
        }
    }

    Context "Pre-flight Checks" {
        It "Should verify runner path exists" {
            $scriptContent | Should -Match 'Test-Path.*\$RunnerPath'
            $scriptContent | Should -Match 'Runner path not found'
        }

        It "Should check disk space before update" {
            $scriptContent | Should -Match 'Get-PSDrive.*Free'
            $scriptContent | Should -Match 'freeSpaceGB'
        }

        It "Should require minimum 5 GB free space" {
            $scriptContent | Should -Match 'freeSpaceGB.*-lt 5'
            $scriptContent | Should -Match 'Insufficient disk space'
        }

        It "Should get current version before update" {
            $scriptContent | Should -Match '\$currentVersion = Get-CurrentRunnerVersion'
        }
    }

    Context "Update Logic" {
        It "Should skip update if already up to date" {
            $scriptContent | Should -Match 'if.*\$currentVersion -eq \$targetVersion'
            $scriptContent | Should -Match 'already up to date'
        }

        It "Should support forcing update of same version" {
            $scriptContent | Should -Match 'Forcing reinstall of same version'
        }

        It "Should support specific version installation" {
            $scriptContent | Should -Match 'if.*\$Version'
            $scriptContent | Should -Match 'Target version specified'
        }

        It "Should require confirmation unless Force is used" {
            $scriptContent | Should -Match 'if.*-not \$Force.*-and.*-not \$DryRun'
            $scriptContent | Should -Match 'Read-Host.*Continue with update'
        }

        It "Should wait for runner to be idle before update" {
            $scriptContent | Should -Match 'Wait-RunnerIdle.*-MaxMinutes'
        }

        It "Should allow forcing update during active jobs" {
            $scriptContent | Should -Match 'Use -Force to update anyway'
            $scriptContent | Should -Match 'Forcing update despite active jobs'
        }
    }

    Context "Rollback Logic" {
        It "Should rollback on installation failure" {
            $scriptContent | Should -Match 'if.*-not.*Install-RunnerUpdate'
            $scriptContent | Should -Match 'Attempting to restore from backup'
        }

        It "Should rollback on verification failure" {
            $scriptContent | Should -Match 'if.*-not.*Test-RunnerInstallation'
            $scriptContent | Should -Match 'Installation verification failed'
        }

        It "Should restart runner after rollback" {
            $scriptContent | Should -Match 'Restore-FromBackup'
            $scriptContent | Should -Match 'Start-RunnerService'
        }
    }

    Context "Error Handling" {
        It "Should use try-catch for main execution" {
            $scriptContent | Should -Match 'try\s*\{'
            $scriptContent | Should -Match '\}\s*catch\s*\{'
        }

        It "Should log fatal errors" {
            $scriptContent | Should -Match 'Fatal error during update'
            $scriptContent | Should -Match 'ScriptStackTrace'
        }

        It "Should attempt to restart runner even on failure" {
            $scriptContent | Should -Match '\} catch \{'
            $scriptContent | Should -Match 'catch.*\{'
        }

        It "Should exit with appropriate codes" {
            $scriptContent | Should -Match 'exit 0'
            $scriptContent | Should -Match 'exit 1'
        }
    }

    Context "Success Reporting" {
        It "Should display success message on completion" {
            $scriptContent | Should -Match 'Update Completed Successfully'
        }

        It "Should show version upgrade information" {
            $scriptContent | Should -Match 'Previous version:.*\$currentVersion'
            $scriptContent | Should -Match 'New version:.*\$targetVersion'
        }

        It "Should display backup location" {
            $scriptContent | Should -Match 'Backup location:.*\$backupPath'
        }

        It "Should log successful completion" {
            $scriptContent | Should -Match 'Runner update completed successfully'
        }
    }

    Context "DryRun Mode" {
        It "Should support dry run mode throughout script" {
            $scriptContent | Should -Match 'if.*\$DryRun'
        }

        It "Should skip actual changes in dry run" {
            $scriptContent | Should -Match '\[DRY RUN\].*Would'
        }

        It "Should not stop service in dry run" {
            $scriptContent | Should -Match '\[DRY RUN\].*Would stop service'
        }

        It "Should not download in dry run" {
            $scriptContent | Should -Match '\[DRY RUN\].*Would download'
        }

        It "Should not create backup in dry run" {
            $scriptContent | Should -Match '\[DRY RUN\].*Would create backup'
        }
    }

    Context "Security Considerations" {
        It "Should download from GitHub official releases only" {
            $scriptContent | Should -Match 'github\.com/actions/runner/releases'
        }

        It "Should verify installation after download" {
            $scriptContent | Should -Match 'Test-RunnerInstallation'
        }

        It "Should preserve credentials during update" {
            $scriptContent | Should -Match '\.credentials'
        }

        It "Should maintain existing configuration" {
            $scriptContent | Should -Match 'Backup.*config'
        }
    }

    Context "Documentation Quality" {
        It "Should document all parameters in help" {
            $scriptContent | Should -Match '\.PARAMETER RunnerPath'
            $scriptContent | Should -Match '\.PARAMETER Force'
            $scriptContent | Should -Match '\.PARAMETER SkipBackup'
            $scriptContent | Should -Match '\.PARAMETER Version'
            $scriptContent | Should -Match '\.PARAMETER MaxWaitMinutes'
            $scriptContent | Should -Match '\.PARAMETER DryRun'
        }

        It "Should include multiple usage examples" {
            $examples = [regex]::Matches($scriptContent, '\.EXAMPLE')
            $examples.Count | Should -BeGreaterThan 2
        }

        It "Should have notes section" {
            $scriptContent | Should -Match '\.NOTES'
        }
    }
}
