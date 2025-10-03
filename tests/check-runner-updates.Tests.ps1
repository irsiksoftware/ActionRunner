Describe "check-runner-updates.ps1 Script Tests" {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot "..\scripts\check-runner-updates.ps1"
        $scriptContent = Get-Content $scriptPath -Raw
    }

    Context "Parameter Validation" {
        It "Should have RunnerPath parameter" {
            $scriptContent | Should -Match '\[string\]\$RunnerPath'
        }

        It "Should have EmailTo parameter" {
            $scriptContent | Should -Match '\[string\]\$EmailTo'
        }

        It "Should have EmailFrom parameter" {
            $scriptContent | Should -Match '\[string\]\$EmailFrom'
        }

        It "Should have SmtpServer parameter" {
            $scriptContent | Should -Match '\[string\]\$SmtpServer'
        }

        It "Should have SmtpPort parameter with default" {
            $scriptContent | Should -Match '\[int\]\$SmtpPort = 587'
        }

        It "Should have SmtpCredential parameter" {
            $scriptContent | Should -Match 'PSCredential.*\$SmtpCredential'
        }

        It "Should have OutputFile parameter" {
            $scriptContent | Should -Match '\[string\]\$OutputFile'
        }

        It "Should have Quiet switch parameter" {
            $scriptContent | Should -Match '\[switch\]\$Quiet'
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

    Context "Output Functions" {
        It "Should have Write-UpdateMessage function" {
            $scriptContent | Should -Match 'function Write-UpdateMessage'
        }

        It "Should respect Quiet mode" {
            $scriptContent | Should -Match 'if.*-not \$Quiet'
        }

        It "Should support color output" {
            $scriptContent | Should -Match 'Write-Host.*-ForegroundColor'
        }
    }

    Context "Version Checking Functions" {
        It "Should have Get-CurrentRunnerVersion function" {
            $scriptContent | Should -Match 'function Get-CurrentRunnerVersion'
        }

        It "Should read .runner configuration file" {
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

        It "Should get Windows x64 download URL" {
            $scriptContent | Should -Match 'win-x64-.*\.zip'
        }

        It "Should retrieve release information" {
            $scriptContent | Should -Match 'Version.*='
            $scriptContent | Should -Match 'DownloadUrl'
            $scriptContent | Should -Match 'ReleaseNotes'
            $scriptContent | Should -Match 'PublishedAt'
            $scriptContent | Should -Match 'HtmlUrl'
        }

        It "Should have Compare-RunnerVersion function" {
            $scriptContent | Should -Match 'function Compare-RunnerVersion'
        }

        It "Should compare versions using version type" {
            $scriptContent | Should -Match '\[version\]'
        }

        It "Should handle unknown current version" {
            $scriptContent | Should -Match 'if.*-not \$CurrentVersion'
        }

        It "Should fallback to string comparison" {
            $scriptContent | Should -Match 'Fallback to string comparison'
        }
    }

    Context "Email Notification Functions" {
        It "Should have Send-UpdateNotification function" {
            $scriptContent | Should -Match 'function Send-UpdateNotification'
        }

        It "Should check for required email parameters" {
            $scriptContent | Should -Match 'if.*-not \$EmailTo.*-or.*-not \$EmailFrom.*-or.*-not \$SmtpServer'
        }

        It "Should create email subject with version" {
            $scriptContent | Should -Match 'subject.*Runner Update Available'
        }

        It "Should include version information in email body" {
            $scriptContent | Should -Match 'Current Version:'
            $scriptContent | Should -Match 'Latest Version:'
        }

        It "Should include release notes in email" {
            $scriptContent | Should -Match 'Release Notes:'
        }

        It "Should include update instructions" {
            $scriptContent | Should -Match 'To update the runner, run:'
            $scriptContent | Should -Match 'update-runner\.ps1'
        }

        It "Should use Send-MailMessage cmdlet" {
            $scriptContent | Should -Match 'Send-MailMessage'
        }

        It "Should support SMTP credentials" {
            $scriptContent | Should -Match 'if.*\$SmtpCredential'
            $scriptContent | Should -Match 'Credential.*=.*\$SmtpCredential'
        }

        It "Should use SSL with credentials" {
            $scriptContent | Should -Match 'UseSsl.*=.*\$true'
        }

        It "Should handle email send failures" {
            $scriptContent | Should -Match 'Failed to send email notification'
        }
    }

    Context "File Output Functions" {
        It "Should have Write-UpdateOutputFile function" {
            $scriptContent | Should -Match 'function Write-UpdateOutputFile'
        }

        It "Should write JSON format output" {
            $scriptContent | Should -Match 'ConvertTo-Json'
            $scriptContent | Should -Match 'Set-Content'
        }

        It "Should use appropriate JSON depth" {
            $scriptContent | Should -Match 'ConvertTo-Json.*-Depth'
        }

        It "Should handle file write failures" {
            $scriptContent | Should -Match 'Failed to write output file'
        }
    }

    Context "Main Execution Logic" {
        It "Should verify runner path exists" {
            $scriptContent | Should -Match 'Test-Path.*\$RunnerPath'
            $scriptContent | Should -Match 'Runner path not found'
        }

        It "Should get current version" {
            $scriptContent | Should -Match '\$currentVersion = Get-CurrentRunnerVersion'
        }

        It "Should get latest version" {
            $scriptContent | Should -Match '\$latest = Get-LatestRunnerVersion'
        }

        It "Should compare versions" {
            $scriptContent | Should -Match '\$updateAvailable = Compare-RunnerVersion'
        }

        It "Should create update info hashtable" {
            $scriptContent | Should -Match '\$updateInfo = @\{'
            $scriptContent | Should -Match 'CurrentVersion'
            $scriptContent | Should -Match 'LatestVersion'
            $scriptContent | Should -Match 'UpdateAvailable'
            $scriptContent | Should -Match 'CheckedAt'
        }
    }

    Context "Update Available Scenario" {
        It "Should display update available message" {
            $scriptContent | Should -Match 'Update Available!'
        }

        It "Should show version upgrade path" {
            $scriptContent | Should -Match 'You can update from.*to'
        }

        It "Should show how to update" {
            $scriptContent | Should -Match 'To update, run:.*update-runner\.ps1'
        }

        It "Should send email if configured" {
            $scriptContent | Should -Match 'if.*\$EmailTo'
            $scriptContent | Should -Match 'Send-UpdateNotification'
        }

        It "Should write output file if specified" {
            $scriptContent | Should -Match 'if.*\$OutputFile'
            $scriptContent | Should -Match 'Write-UpdateOutputFile'
        }

        It "Should exit with code 1 when update available" {
            $scriptContent | Should -Match 'exit 1.*# Exit code 1 indicates update available'
        }
    }

    Context "No Update Available Scenario" {
        It "Should display up-to-date message" {
            $scriptContent | Should -Match 'Runner is up to date!'
        }

        It "Should still write output file if specified" {
            $scriptContent | Should -Match 'else.*\{[^}]*Write-UpdateOutputFile'
        }

        It "Should exit with code 0 when up to date" {
            $scriptContent | Should -Match 'exit 0.*# Exit code 0 indicates no update available'
        }
    }

    Context "Error Handling" {
        It "Should use try-catch for main execution" {
            $scriptContent | Should -Match 'try\s*\{'
            $scriptContent | Should -Match '\}\s*catch\s*\{'
        }

        It "Should handle check failures gracefully" {
            $scriptContent | Should -Match 'if.*-not \$latest'
            $scriptContent | Should -Match 'Failed to check for latest version'
        }

        It "Should exit with code 0 on errors" {
            $scriptContent | Should -Match 'catch.*\{[^}]*exit 0'
        }

        It "Should display error messages" {
            $scriptContent | Should -Match 'Error during update check'
        }
    }

    Context "Exit Codes" {
        It "Should document exit codes in help" {
            $scriptContent | Should -Match '\.NOTES'
            $scriptContent | Should -Match 'Exit Codes:'
            $scriptContent | Should -Match '0.*No update available'
            $scriptContent | Should -Match '1.*Update available'
        }

        It "Should have clear exit code comments" {
            $scriptContent | Should -Match 'exit 0.*indicates no update'
            $scriptContent | Should -Match 'exit 1.*indicates update available'
        }
    }

    Context "Automation Support" {
        It "Should support quiet mode for automation" {
            $scriptContent | Should -Match '\[switch\]\$Quiet'
        }

        It "Should support JSON output for parsing" {
            $scriptContent | Should -Match 'ConvertTo-Json'
        }

        It "Should use exit codes for scripting" {
            $scriptContent | Should -Match 'exit 0'
            $scriptContent | Should -Match 'exit 1'
        }

        It "Should write structured data to file" {
            $scriptContent | Should -Match 'OutputFile'
        }
    }

    Context "Security Considerations" {
        It "Should only query GitHub official API" {
            $scriptContent | Should -Match 'api\.github\.com/repos/actions/runner'
        }

        It "Should support SMTP authentication" {
            $scriptContent | Should -Match 'SmtpCredential'
        }

        It "Should use SSL for authenticated SMTP" {
            $scriptContent | Should -Match 'UseSsl'
        }
    }

    Context "Documentation Quality" {
        It "Should document all parameters in help" {
            $scriptContent | Should -Match '\.PARAMETER RunnerPath'
            $scriptContent | Should -Match '\.PARAMETER EmailTo'
            $scriptContent | Should -Match '\.PARAMETER EmailFrom'
            $scriptContent | Should -Match '\.PARAMETER SmtpServer'
            $scriptContent | Should -Match '\.PARAMETER OutputFile'
            $scriptContent | Should -Match '\.PARAMETER Quiet'
        }

        It "Should include multiple usage examples" {
            $examples = [regex]::Matches($scriptContent, '\.EXAMPLE')
            $examples.Count | Should -BeGreaterThan 2
        }

        It "Should have notes section" {
            $scriptContent | Should -Match '\.NOTES'
        }

        It "Should document version" {
            $scriptContent | Should -Match 'Version:.*1\.0\.0'
        }
    }

    Context "Email Content Quality" {
        It "Should include download link in email" {
            $scriptContent | Should -Match 'Download:.*\$.*HtmlUrl'
        }

        It "Should include published date" {
            $scriptContent | Should -Match 'Published:.*\$.*PublishedAt'
        }

        It "Should identify as automated message" {
            $scriptContent | Should -Match 'automated notification'
        }
    }

    Context "Version Comparison Edge Cases" {
        It "Should handle version parsing failures" {
            $scriptContent | Should -Match 'catch.*\{[^}]*Fallback'
        }

        It "Should treat unknown current version as needing update" {
            $scriptContent | Should -Match 'return \$true.*Treat unknown'
        }
    }
}
