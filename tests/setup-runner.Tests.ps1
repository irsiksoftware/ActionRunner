$scriptPath = Join-Path $PSScriptRoot "..\scripts\setup-runner.ps1"

Describe "setup-runner.ps1 Script Tests" {
    Context "Parameter Validation" {
        It "Should have mandatory RepoUrl parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params['RepoUrl'].Attributes.Mandatory | Should -Be $true
        }

        It "Should have mandatory Token parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params['Token'].Attributes.Mandatory | Should -Be $true
        }

        It "Should have optional RunnerName parameter with default" {
            $params = (Get-Command $scriptPath).Parameters
            $params['RunnerName'].Attributes.Mandatory | Should -Be $false
        }

        It "Should have optional Labels parameter with default" {
            $params = (Get-Command $scriptPath).Parameters
            $params['Labels'].Attributes.Mandatory | Should -Be $false
        }

        It "Should have optional WorkDirectory parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params['WorkDirectory'].Attributes.Mandatory | Should -Be $false
        }

        It "Should have optional RunAsService parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params['RunAsService'].Attributes.Mandatory | Should -Be $false
        }
    }

    Context "Script Syntax and Structure" {
        It "Should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize(
                (Get-Content $scriptPath -Raw),
                [ref]$errors
            )
            $errors.Count | Should -Be 0
        }

        It "Should contain comment-based help" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\.SYNOPSIS'
            $content | Should -Match '\.DESCRIPTION'
            $content | Should -Match '\.PARAMETER'
            $content | Should -Match '\.EXAMPLE'
        }

        It "Should set ErrorActionPreference to Stop" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$ErrorActionPreference\s*=\s*"Stop"'
        }

        It "Should have logging function" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'function Write-Log'
        }
    }

    Context "Security Checks" {
        It "Should check for Administrator privileges when RunAsService is true" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\[Security\.Principal\.WindowsPrincipal\]'
            $content | Should -Match 'Administrator'
        }

        It "Should not contain hardcoded tokens or passwords" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Not -Match 'ghp_[a-zA-Z0-9]+'
            $content | Should -Not -Match 'password\s*=\s*"[^"]+"'
        }

        It "Should use HTTPS for downloads" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'https://github\.com/actions/runner'
        }
    }

    Context "Functionality Checks" {
        It "Should create work directory if it doesn't exist" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'New-Item.*-ItemType Directory'
        }

        It "Should download runner from GitHub" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Invoke-WebRequest'
        }

        It "Should extract runner archive" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Expand-Archive'
        }

        It "Should configure runner with required parameters" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '--url'
            $content | Should -Match '--token'
            $content | Should -Match '--name'
            $content | Should -Match '--labels'
        }

        It "Should support service installation" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'svc\.cmd install'
            $content | Should -Match 'svc\.cmd start'
        }
    }

    Context "Logging and Error Handling" {
        It "Should create log file in logs directory" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$LogFile.*logs.*\.log'
        }

        It "Should use try-catch blocks for critical operations" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'try\s*\{'
            $content | Should -Match 'catch\s*\{'
        }

        It "Should log important events" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Write-Log.*Starting'
            $content | Should -Match 'Write-Log.*Complete'
        }
    }

    Context "Runner Configuration" {
        It "Should use latest runner version" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$runnerVersion\s*=\s*"2\.\d+\.\d+"'
        }

        It "Should support custom labels" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$Labels'
            $content | Should -Match '--labels'
        }

        It "Should support custom runner name" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$RunnerName'
            $content | Should -Match '--name'
        }

        It "Should use unattended configuration" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '--unattended'
        }

        It "Should support runner replacement" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '--replace'
        }
    }

    Context "Service Management" {
        It "Should verify service status after installation" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Get-Service.*actions\.runner'
        }

        It "Should provide service management instructions" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Get-Service actions\.runner\.\*'
            $content | Should -Match 'Stop-Service'
            $content | Should -Match 'Start-Service'
        }
    }

    Context "Output and Reporting" {
        It "Should provide setup summary" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'Runner Setup Complete'
        }

        It "Should display success message" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'setup completed successfully'
        }

        It "Should reference GitHub settings for verification" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "Settings.*Actions.*Runners"
        }
    }
}

Describe "setup-runner.ps1 Integration Tests" -Tag "Integration" {

    Context "Dry Run Tests" {
        It "Should validate log directory exists" {
            $logsDir = "C:\Code\ActionRunner\logs"
            Test-Path $logsDir | Should -Be $true
        }

        It "Should be able to create work directory" {
            $testDir = Join-Path $env:TEMP "test-runner-$(Get-Random)"
            New-Item -Path $testDir -ItemType Directory -Force | Out-Null
            $exists = Test-Path $testDir
            Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
            $exists | Should -Be $true
        }
    }
}
