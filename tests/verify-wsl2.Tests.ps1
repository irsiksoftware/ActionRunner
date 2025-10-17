#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-wsl2.ps1'
}

Describe "verify-wsl2.ps1 - Script Validation" {
    It "Script file exists" {
        Test-Path $script:ScriptPath | Should -Be $true
    }

    It "Script has valid PowerShell syntax" {
        $parseErrors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize(
            (Get-Content $script:ScriptPath -Raw),
            [ref]$parseErrors
        )
        $parseErrors.Count | Should -Be 0
    }

    It "Script requires PowerShell 5.1 or higher" {
        $content = Get-Content $script:ScriptPath -Raw
        $content | Should -Match '#Requires -Version 5.1'
    }

    It "Script has proper comment-based help" {
        $content = Get-Content $script:ScriptPath -Raw
        $content | Should -Match '\.SYNOPSIS'
        $content | Should -Match '\.DESCRIPTION'
        $content | Should -Match '\.EXAMPLE'
    }
}

Describe "verify-wsl2.ps1 - Parameter Validation" {
    BeforeAll {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:ScriptPath,
            [ref]$null,
            [ref]$null
        )
        $script:Params = $ast.ParamBlock.Parameters
    }

    It "Has ExitOnFailure switch parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'ExitOnFailure' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'SwitchParameter'
    }

    It "Has JsonOutput switch parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'JsonOutput' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'SwitchParameter'
    }

    It "Has DistroName string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'DistroName' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }
}

Describe "verify-wsl2.ps1 - Function Definitions" {
    BeforeAll {
        $script:ScriptContent = Get-Content $script:ScriptPath -Raw
    }

    It "Defines Test-Requirement function" {
        $script:ScriptContent | Should -Match 'function Test-Requirement'
    }

    It "Test-Requirement function has Name parameter" {
        $script:ScriptContent | Should -Match '\[string\]\$Name'
    }

    It "Test-Requirement function has Check parameter as scriptblock" {
        $script:ScriptContent | Should -Match '\[scriptblock\]\$Check'
    }

    It "Test-Requirement function has Expected parameter" {
        $script:ScriptContent | Should -Match '\[string\]\$Expected'
    }

    It "Test-Requirement function has FailureMessage parameter" {
        $script:ScriptContent | Should -Match '\[string\]\$FailureMessage'
    }

    It "Test-Requirement function has Severity parameter" {
        $script:ScriptContent | Should -Match '\[string\]\$Severity'
    }
}

Describe "verify-wsl2.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains WSL command availability check" {
        $script:Content | Should -Match 'Get-Command wsl'
    }

    It "Contains WSL installation check" {
        $script:Content | Should -Match 'wsl --status'
    }

    It "Contains WSL default version check" {
        $script:Content | Should -Match 'Default Version'
    }

    It "Contains distro list check" {
        $script:Content | Should -Match 'wsl --list'
    }

    It "Contains specific distro existence check" {
        $script:Content | Should -Match "Distro.*DistroName"
    }

    It "Contains WSL2 version check" {
        $script:Content | Should -Match 'wsl --list --verbose'
    }

    It "Contains distro state check" {
        $script:Content | Should -Match 'wsl -d \$DistroName echo'
    }

    It "Contains Docker in WSL2 check" {
        $script:Content | Should -Match 'which docker'
    }

    It "Contains Docker daemon accessibility check" {
        $script:Content | Should -Match 'docker version'
    }

    It "Contains WSL kernel version check" {
        $script:Content | Should -Match 'uname -r'
    }

    It "Contains systemd support check" {
        $script:Content | Should -Match 'which systemctl'
    }

    It "Contains network connectivity check" {
        $script:Content | Should -Match 'ping -c 1'
    }

    It "Uses proper error handling" {
        $script:Content | Should -Match '\$ErrorActionPreference'
    }

    It "Has JSON output support" {
        $script:Content | Should -Match 'ConvertTo-Json'
    }

    It "Has proper exit code handling" {
        $script:Content | Should -Match 'exit 1'
        $script:Content | Should -Match 'exit 0'
    }
}

Describe "verify-wsl2.ps1 - Execution Tests" {
    Context "When WSL is not available" {
        BeforeAll {
            # Mock wsl command by temporarily clearing PATH
            $script:OriginalPath = $env:PATH
            $env:PATH = ""
        }

        AfterAll {
            $env:PATH = $script:OriginalPath
        }

        It "Should handle missing WSL gracefully" {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should report WSL as not available" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.failed | Should -BeGreaterThan 0
        }
    }

    Context "When WSL is available" {
        BeforeAll {
            # Check if WSL is available
            $script:WslAvailable = $null -ne (Get-Command wsl -ErrorAction SilentlyContinue)
            if ($script:WslAvailable) {
                $null = wsl --status 2>&1
                $script:WslInstalled = $LASTEXITCODE -eq 0
            } else {
                $script:WslInstalled = $false
            }
        }

        It "Should execute without errors when WSL is available" -Skip:(-not $script:WslInstalled) {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include passed/failed/warnings counts in JSON output" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.passed | Should -BeOfType [int]
            $json.failed | Should -BeOfType [int]
            $json.warnings | Should -BeOfType [int]
        }

        It "Should perform WSL command check" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $wslCheck = $json.checks | Where-Object { $_.name -eq 'WSL Command' }
            $wslCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform WSL installation check" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $installCheck = $json.checks | Where-Object { $_.name -eq 'WSL Installation' }
            $installCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform WSL default version check" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $versionCheck = $json.checks | Where-Object { $_.name -eq 'WSL Default Version' }
            $versionCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform distro list check" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $distroCheck = $json.checks | Where-Object { $_.name -eq 'WSL Distros' }
            $distroCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform specific distro check" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $specificDistroCheck = $json.checks | Where-Object { $_.name -match "Distro 'Ubuntu'" }
            $specificDistroCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform WSL2 version check" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $wsl2Check = $json.checks | Where-Object { $_.name -eq 'WSL2 Version' }
            $wsl2Check | Should -Not -BeNullOrEmpty
        }

        It "Should perform distro state check" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $stateCheck = $json.checks | Where-Object { $_.name -eq 'Distro State' }
            $stateCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Docker in WSL2 check" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $dockerCheck = $json.checks | Where-Object { $_.name -eq 'Docker in WSL2' }
            $dockerCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Docker daemon check" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $daemonCheck = $json.checks | Where-Object { $_.name -eq 'Docker Daemon in WSL2' }
            $daemonCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform WSL kernel check" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $kernelCheck = $json.checks | Where-Object { $_.name -eq 'WSL Kernel' }
            $kernelCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform systemd support check" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $systemdCheck = $json.checks | Where-Object { $_.name -eq 'systemd Support' }
            $systemdCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform network connectivity check" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $networkCheck = $json.checks | Where-Object { $_.name -eq 'WSL2 Network' }
            $networkCheck | Should -Not -BeNullOrEmpty
        }

        It "Should accept custom distro name" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath -DistroName "Ubuntu" -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }
    }

    Context "Output Formatting" {
        BeforeAll {
            $script:WslAvailable = $null -ne (Get-Command wsl -ErrorAction SilentlyContinue)
            if ($script:WslAvailable) {
                $null = wsl --status 2>&1
                $script:WslInstalled = $LASTEXITCODE -eq 0
            } else {
                $script:WslInstalled = $false
            }
        }

        It "Should display checkmarks for passed tests (non-JSON mode)" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match '✅|✓|PASS'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }

        It "Should show passed count in summary" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Passed:'
        }

        It "Should show failed count in summary" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Failed:'
        }

        It "Should show warnings count in summary" -Skip:(-not $script:WslInstalled) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Warnings:'
        }
    }
}

Describe "verify-wsl2.ps1 - Security and Best Practices" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Uses ErrorActionPreference" {
        $script:Content | Should -Match '\$ErrorActionPreference\s*='
    }

    It "Uses CmdletBinding attribute" {
        $script:Content | Should -Match '\[CmdletBinding\(\)\]'
    }

    It "Uses try-catch blocks" {
        $script:Content | Should -Match 'try\s*\{[\s\S]*?\}\s*catch\s*\{'
    }

    It "Handles LASTEXITCODE checks" {
        $script:Content | Should -Match '\$LASTEXITCODE'
    }

    It "Suppresses errors appropriately" {
        $script:Content | Should -Match 'ErrorAction\s+SilentlyContinue'
    }
}

Describe "verify-wsl2.ps1 - WSL2 Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Checks for WSL command availability" {
        $script:Content | Should -Match 'WSL command is available in PATH'
    }

    It "Validates WSL installation" {
        $script:Content | Should -Match 'WSL is installed and accessible'
    }

    It "Verifies WSL 2 is default version" {
        $script:Content | Should -Match 'WSL 2 is set as default version'
    }

    It "Checks for at least one distro" {
        $script:Content | Should -Match 'At least one WSL distro is installed'
    }

    It "Validates specific distro existence" {
        $script:Content | Should -Match "DistroName.*distro is installed"
    }

    It "Verifies distro is WSL2 not WSL1" {
        $script:Content | Should -Match "DistroName.*is running WSL 2"
    }

    It "Checks distro can execute commands" {
        $script:Content | Should -Match "DistroName.*can be started"
    }

    It "Validates Docker availability in WSL2" {
        $script:Content | Should -Match "Docker command is available.*DistroName"
    }

    It "Checks Docker daemon accessibility" {
        $script:Content | Should -Match "Docker daemon is accessible.*DistroName"
    }

    It "Verifies WSL2 kernel version" {
        $script:Content | Should -Match 'WSL2 kernel version is available'
    }

    It "Checks systemd support for runner service" {
        $script:Content | Should -Match "systemd is available.*DistroName"
    }

    It "Validates network connectivity" {
        $script:Content | Should -Match 'WSL2 has network connectivity'
    }

    It "Has default distro name parameter" {
        $script:Content | Should -Match '\[string\]\$DistroName = "Ubuntu"'
    }
}

Describe "verify-wsl2.ps1 - Error Handling" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Handles WSL command not found" {
        $script:Content | Should -Match 'WSL command not found'
    }

    It "Handles WSL not installed" {
        $script:Content | Should -Match "Run 'wsl --install' and restart"
    }

    It "Handles no distros found" {
        $script:Content | Should -Match 'No WSL distros found'
    }

    It "Handles specific distro not found" {
        $script:Content | Should -Match 'Install from Microsoft Store or specify different distro'
    }

    It "Handles WSL1 instead of WSL2" {
        $script:Content | Should -Match 'wsl --set-version'
    }

    It "Handles Docker not available in WSL2" {
        $script:Content | Should -Match 'Enable WSL integration in Docker Desktop'
    }

    It "Handles Docker daemon not running" {
        $script:Content | Should -Match 'Start Docker Desktop'
    }

    It "Handles network connectivity issues" {
        $script:Content | Should -Match 'Check network settings'
    }

    It "Uses try-catch for error handling" {
        $script:Content | Should -Match 'try\s*\{[\s\S]*?\}\s*catch\s*\{'
    }

    It "Checks LASTEXITCODE for command success" {
        $script:Content | Should -Match '\$LASTEXITCODE -eq 0'
    }
}

Describe "verify-wsl2.ps1 - Integration with GitHub Actions" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Mentions GitHub Actions runner in description" {
        $script:Content | Should -Match 'GitHub Actions'
    }

    It "Checks systemd for runner service installation" {
        $script:Content | Should -Match 'systemctl'
    }

    It "Validates Docker integration for containerized workflows" {
        $script:Content | Should -Match 'Docker'
    }

    It "Supports JSON output for CI/CD integration" {
        $script:Content | Should -Match 'JsonOutput'
    }

    It "Supports exit on failure for CI/CD pipelines" {
        $script:Content | Should -Match 'ExitOnFailure'
    }
}
