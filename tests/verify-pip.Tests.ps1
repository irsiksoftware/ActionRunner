#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-pip.ps1'
}

Describe "verify-pip.ps1 - Script Validation" {
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

Describe "verify-pip.ps1 - Parameter Validation" {
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

    It "Has MinimumVersion string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumVersion' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "MinimumVersion has default value of 20.0" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '20.0'
    }
}

Describe "verify-pip.ps1 - Function Definitions" {
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

Describe "verify-pip.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains pip version check" {
        $script:Content | Should -Match 'pip --version'
    }

    It "Contains pip configuration check" {
        $script:Content | Should -Match 'pip config'
    }

    It "Contains pip list check" {
        $script:Content | Should -Match 'pip list'
    }

    It "Contains pip install capability check" {
        $script:Content | Should -Match 'pip install'
    }

    It "Contains pip show check" {
        $script:Content | Should -Match 'pip show'
    }

    It "Contains pip check for dependencies" {
        $script:Content | Should -Match 'pip check'
    }

    It "Contains pip freeze check" {
        $script:Content | Should -Match 'pip freeze'
    }

    It "Contains requirements.txt test" {
        $script:Content | Should -Match 'requirements\.txt'
    }

    It "Contains virtual environment support check" {
        $script:Content | Should -Match 'venv'
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

Describe "verify-pip.ps1 - Execution Tests" {
    Context "When pip is not available" {
        BeforeAll {
            # Mock pip command by temporarily renaming PATH
            $script:OriginalPath = $env:PATH
            $env:PATH = ""
        }

        AfterAll {
            $env:PATH = $script:OriginalPath
        }

        It "Should handle missing pip gracefully" {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }
    }

    Context "When pip is available" {
        BeforeAll {
            # Check if pip is available
            $script:PipAvailable = $null -ne (Get-Command pip -ErrorAction SilentlyContinue)
        }

        It "Should execute without errors when pip is available" -Skip:(-not $script:PipAvailable) {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" -Skip:(-not $script:PipAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" -Skip:(-not $script:PipAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" -Skip:(-not $script:PipAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include passed/failed/warnings counts in JSON output" -Skip:(-not $script:PipAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.passed | Should -BeOfType [int]
            $json.failed | Should -BeOfType [int]
            $json.warnings | Should -BeOfType [int]
        }

        It "Should perform pip command availability check" -Skip:(-not $script:PipAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $pipCheck = $json.checks | Where-Object { $_.name -eq 'pip Command Available' }
            $pipCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform pip version check" -Skip:(-not $script:PipAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $versionCheck = $json.checks | Where-Object { $_.name -eq 'pip Version' }
            $versionCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform pip configuration check" -Skip:(-not $script:PipAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $configCheck = $json.checks | Where-Object { $_.name -eq 'pip Configuration' }
            $configCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform pip list packages check" -Skip:(-not $script:PipAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $listCheck = $json.checks | Where-Object { $_.name -eq 'pip List Packages' }
            $listCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform pip install capability check" -Skip:(-not $script:PipAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $installCheck = $json.checks | Where-Object { $_.name -eq 'pip Install Capability' }
            $installCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform pip show package info check" -Skip:(-not $script:PipAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $showCheck = $json.checks | Where-Object { $_.name -eq 'pip Show Package Info' }
            $showCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform pip check dependencies" -Skip:(-not $script:PipAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $checkDeps = $json.checks | Where-Object { $_.name -eq 'pip Check Dependencies' }
            $checkDeps | Should -Not -BeNullOrEmpty
        }

        It "Should perform pip freeze export check" -Skip:(-not $script:PipAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $freezeCheck = $json.checks | Where-Object { $_.name -eq 'pip Freeze Export' }
            $freezeCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform requirements file support check" -Skip:(-not $script:PipAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $reqCheck = $json.checks | Where-Object { $_.name -eq 'Requirements File Support' }
            $reqCheck | Should -Not -BeNullOrEmpty
        }

        It "Should accept MinimumVersion parameter" -Skip:(-not $script:PipAvailable) {
            { & $script:ScriptPath -MinimumVersion "20.0" -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should exit with code 1 when -ExitOnFailure is used and checks fail" {
            # Force a failure by requiring a very high version
            $result = & $script:ScriptPath -MinimumVersion "999.0" -ExitOnFailure -JsonOutput 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Output Formatting" {
        It "Should display checkmarks for passed tests (non-JSON mode)" -Skip:(-not $script:PipAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match '✅|✓|PASS'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:PipAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }
    }
}

Describe "verify-pip.ps1 - Security and Best Practices" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Uses ErrorActionPreference" {
        $script:Content | Should -Match '\$ErrorActionPreference\s*='
    }

    It "Uses CmdletBinding attribute" {
        $script:Content | Should -Match '\[CmdletBinding\(\)\]'
    }

    It "Cleans up temporary test files" {
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

Describe "verify-pip.ps1 - pip Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Creates a temporary requirements.txt file for testing" {
        $script:Content | Should -Match 'requirements\.txt'
    }

    It "Tests requirements file processing" {
        $script:Content | Should -Match 'pip install.*-r'
    }

    It "Uses dry-run for non-destructive testing" {
        $script:Content | Should -Match '--dry-run'
    }

    It "Tests package index accessibility" {
        $script:Content | Should -Match 'pip index|pip download'
    }

    It "Validates JSON format for pip list" {
        $script:Content | Should -Match '--format=json'
    }

    It "Tests virtual environment module availability" {
        $script:Content | Should -Match 'python -m venv'
    }

    It "Checks pip self-upgrade capability" {
        $script:Content | Should -Match 'pip install --upgrade'
    }
}
