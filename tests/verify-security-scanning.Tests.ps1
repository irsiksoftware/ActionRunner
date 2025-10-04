#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-security-scanning.ps1'
}

Describe "verify-security-scanning.ps1 - Script Validation" {
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

Describe "verify-security-scanning.ps1 - Parameter Validation" {
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

    It "Has IncludeOptional switch parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'IncludeOptional' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'SwitchParameter'
    }
}

Describe "verify-security-scanning.ps1 - Function Definitions" {
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

Describe "verify-security-scanning.ps1 - Security Check Content" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains Git availability check" {
        $script:Content | Should -Match 'git --version'
    }

    It "Contains PowerShell execution policy check" {
        $script:Content | Should -Match 'Get-ExecutionPolicy'
    }

    It "Contains Windows Defender check" {
        $script:Content | Should -Match 'Get-MpComputerStatus'
    }

    It "Contains file content scanning capability check" {
        $script:Content | Should -Match 'Select-String'
    }

    It "Contains secret detection patterns" {
        $script:Content | Should -Match 'password|secret|token'
    }

    It "Contains Git hooks support check" {
        $script:Content | Should -Match 'git init'
        $script:Content | Should -Match '\.git\\hooks'
    }

    It "Contains PSScriptAnalyzer check" {
        $script:Content | Should -Match 'PSScriptAnalyzer'
    }

    It "Contains security script execution test" {
        $script:Content | Should -Match 'scan-test\.ps1'
    }

    It "Uses proper error handling" {
        $script:Content | Should -Match '\$ErrorActionPreference'
    }

    It "Includes cleanup logic for temporary directories" {
        $script:Content | Should -Match 'Remove-Item.*-Recurse.*-Force'
    }

    It "Has JSON output support" {
        $script:Content | Should -Match 'ConvertTo-Json'
    }

    It "Has proper exit code handling" {
        $script:Content | Should -Match 'exit 1'
        $script:Content | Should -Match 'exit 0'
    }
}

Describe "verify-security-scanning.ps1 - Execution Tests" {
    Context "When Git is not available" {
        BeforeAll {
            # Mock git command by temporarily renaming PATH
            $script:OriginalPath = $env:PATH
            $env:PATH = ""
        }

        AfterAll {
            $env:PATH = $script:OriginalPath
        }

        It "Should handle missing Git gracefully" {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }
    }

    Context "When security tools are available" {
        BeforeAll {
            # Check if git is available
            $script:GitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
        }

        It "Should execute without errors" -Skip:(-not $script:GitAvailable) {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include passed/failed/warnings counts in JSON output" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.passed | Should -BeOfType [int]
            $json.failed | Should -BeOfType [int]
            $json.warnings | Should -BeOfType [int]
        }

        It "Should perform Git check" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $gitCheck = $json.checks | Where-Object { $_.name -eq 'Git' }
            $gitCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform PowerShell execution policy check" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $policyCheck = $json.checks | Where-Object { $_.name -eq 'PowerShell Execution Policy' }
            $policyCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform file content scanning check" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $scanCheck = $json.checks | Where-Object { $_.name -eq 'File Content Scanning' }
            $scanCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform secret detection patterns check" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $secretCheck = $json.checks | Where-Object { $_.name -eq 'Secret Detection Patterns' }
            $secretCheck | Should -Not -BeNullOrEmpty
        }

        It "Should accept IncludeOptional parameter" -Skip:(-not $script:GitAvailable) {
            { & $script:ScriptPath -IncludeOptional -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should include optional checks when -IncludeOptional is specified" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -IncludeOptional -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            # Should have more checks with optional included
            $json.checks.Count | Should -BeGreaterThan 8
        }
    }

    Context "Output Formatting" {
        BeforeAll {
            $script:GitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
        }

        It "Should display checkmarks for passed tests (non-JSON mode)" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match '✅|✓|PASS'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }
    }
}

Describe "verify-security-scanning.ps1 - Security and Best Practices" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Uses ErrorActionPreference" {
        $script:Content | Should -Match '\$ErrorActionPreference\s*='
    }

    It "Uses CmdletBinding attribute" {
        $script:Content | Should -Match '\[CmdletBinding\(\)\]'
    }

    It "Cleans up temporary test files and directories" {
        $script:Content | Should -Match 'Remove-Item.*\$testDir'
    }

    It "Uses try-finally for cleanup" {
        $script:Content | Should -Match 'try\s*\{[\s\S]*?\}\s*finally\s*\{'
    }

    It "Uses unique temporary directory names" {
        $script:Content | Should -Match 'Get-Random'
    }

    It "Suppresses errors on cleanup" {
        $script:Content | Should -Match 'ErrorAction\s+SilentlyContinue'
    }
}

Describe "verify-security-scanning.ps1 - Security Scanning Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Checks for secret patterns in test content" {
        $script:Content | Should -Match 'API_KEY|password|token'
    }

    It "Tests pattern matching with Select-String" {
        $script:Content | Should -Match 'Select-String -Pattern'
    }

    It "Validates git hooks directory" {
        $script:Content | Should -Match '\.git\\hooks'
    }

    It "Checks for SARIF output support when optional checks enabled" {
        $script:Content | Should -Match 'SARIF'
    }

    It "Includes Windows Defender status check" {
        $script:Content | Should -Match 'AntivirusEnabled'
    }

    It "Tests security script execution capability" {
        $script:Content | Should -Match 'scan-test\.ps1'
    }

    It "Validates multiple secret detection patterns" {
        # Should test at least 3 different secret patterns
        $matches = ([regex]::Matches($script:Content, "password|API_KEY|token")).Count
        $matches | Should -BeGreaterOrEqual 3
    }
}
