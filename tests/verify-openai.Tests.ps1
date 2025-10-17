#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-openai.ps1'
}

Describe "verify-openai.ps1 - Script Validation" {
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

Describe "verify-openai.ps1 - Parameter Validation" {
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

    It "Has MinimumPythonVersion string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumPythonVersion' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "MinimumPythonVersion has default value of 3.8" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumPythonVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '3.8'
    }

    It "Has MinimumPythonOpenAIVersion string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumPythonOpenAIVersion' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "MinimumPythonOpenAIVersion has default value of 1.0.0" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumPythonOpenAIVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '1.0.0'
    }

    It "Has MinimumNodeVersion string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumNodeVersion' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "MinimumNodeVersion has default value of 16.0" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumNodeVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '16.0'
    }

    It "Has MinimumNodeOpenAIVersion string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumNodeOpenAIVersion' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "MinimumNodeOpenAIVersion has default value of 4.0.0" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumNodeOpenAIVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '4.0.0'
    }
}

Describe "verify-openai.ps1 - Function Definitions" {
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

Describe "verify-openai.ps1 - Python OpenAI Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains Python version check" {
        $script:Content | Should -Match 'python --version'
    }

    It "Contains pip check" {
        $script:Content | Should -Match 'python -m pip --version'
    }

    It "Contains Python OpenAI import check" {
        $script:Content | Should -Match 'import openai'
    }

    It "Contains Python OpenAI version check" {
        $script:Content | Should -Match 'openai\.__version__'
    }

    It "Contains Python OpenAI client import" {
        $script:Content | Should -Match 'from openai import OpenAI'
    }

    It "Contains Python OpenAI client instantiation test" {
        $script:Content | Should -Match 'OpenAI\(api_key='
    }

    It "Uses proper error handling" {
        $script:Content | Should -Match '\$ErrorActionPreference'
    }

    It "Includes cleanup logic for temporary directories" {
        $script:Content | Should -Match 'Remove-Item.*-Recurse.*-Force'
    }
}

Describe "verify-openai.ps1 - Node.js OpenAI Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains Node.js version check" {
        $script:Content | Should -Match 'node --version'
    }

    It "Contains npm check" {
        $script:Content | Should -Match 'npm --version'
    }

    It "Contains Node.js OpenAI import check" {
        $script:Content | Should -Match "import.*openai|require.*openai"
    }

    It "Contains Node.js OpenAI client instantiation test" {
        $script:Content | Should -Match 'new OpenAI\('
    }

    It "Contains npm install test" {
        $script:Content | Should -Match 'npm install'
    }

    It "Has JSON output support" {
        $script:Content | Should -Match 'ConvertTo-Json'
    }

    It "Has proper exit code handling" {
        $script:Content | Should -Match 'exit 1'
        $script:Content | Should -Match 'exit 0'
    }
}

Describe "verify-openai.ps1 - Execution Tests" {
    Context "When Python is not available" {
        BeforeAll {
            # Mock python command by temporarily clearing PATH
            $script:OriginalPath = $env:PATH
            $env:PATH = ""
        }

        AfterAll {
            $env:PATH = $script:OriginalPath
        }

        It "Should handle missing Python gracefully" {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }
    }

    Context "When Python is available" {
        BeforeAll {
            # Check if python is available
            $script:PythonAvailable = $null -ne (Get-Command python -ErrorAction SilentlyContinue)
        }

        It "Should execute without errors when python is available" -Skip:(-not $script:PythonAvailable) {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include passed/failed/warnings counts in JSON output" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.passed | Should -BeOfType [int]
            $json.failed | Should -BeOfType [int]
            $json.warnings | Should -BeOfType [int]
        }

        It "Should perform Python interpreter check" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $pythonCheck = $json.checks | Where-Object { $_.name -eq 'Python Interpreter' }
            $pythonCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform pip package manager check" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $pipCheck = $json.checks | Where-Object { $_.name -eq 'pip Package Manager' }
            $pipCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Python OpenAI package check" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $openaiCheck = $json.checks | Where-Object { $_.name -eq 'Python OpenAI Package' }
            $openaiCheck | Should -Not -BeNullOrEmpty
        }

        It "Should accept MinimumPythonVersion parameter" -Skip:(-not $script:PythonAvailable) {
            { & $script:ScriptPath -MinimumPythonVersion "3.8" -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should accept MinimumPythonOpenAIVersion parameter" -Skip:(-not $script:PythonAvailable) {
            { & $script:ScriptPath -MinimumPythonOpenAIVersion "1.0.0" -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should exit with code 1 when -ExitOnFailure is used and checks fail" {
            # Force a failure by requiring a very high Python version
            $result = & $script:ScriptPath -MinimumPythonVersion "99.0" -ExitOnFailure -JsonOutput 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "When Node.js is available" {
        BeforeAll {
            $script:NodeAvailable = $null -ne (Get-Command node -ErrorAction SilentlyContinue)
        }

        It "Should perform Node.js interpreter check" -Skip:(-not $script:NodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $nodeCheck = $json.checks | Where-Object { $_.name -eq 'Node.js Interpreter' }
            $nodeCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform npm package manager check" -Skip:(-not $script:NodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $npmCheck = $json.checks | Where-Object { $_.name -eq 'npm Package Manager' }
            $npmCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Node.js OpenAI package check" -Skip:(-not $script:NodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $openaiCheck = $json.checks | Where-Object { $_.name -match 'Node\.js OpenAI' }
            $openaiCheck | Should -Not -BeNullOrEmpty
        }

        It "Should accept MinimumNodeVersion parameter" -Skip:(-not $script:NodeAvailable) {
            { & $script:ScriptPath -MinimumNodeVersion "16.0" -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should accept MinimumNodeOpenAIVersion parameter" -Skip:(-not $script:NodeAvailable) {
            { & $script:ScriptPath -MinimumNodeOpenAIVersion "4.0.0" -JsonOutput 2>&1 } | Should -Not -Throw
        }
    }

    Context "Output Formatting" {
        BeforeAll {
            $script:PythonOrNodeAvailable = ($null -ne (Get-Command python -ErrorAction SilentlyContinue)) -or ($null -ne (Get-Command node -ErrorAction SilentlyContinue))
        }

        It "Should display checkmarks for passed tests (non-JSON mode)" -Skip:(-not $script:PythonOrNodeAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match '✅|✓|PASS'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:PythonOrNodeAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }
    }
}

Describe "verify-openai.ps1 - Security and Best Practices" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Uses ErrorActionPreference" {
        $script:Content | Should -Match '\$ErrorActionPreference\s*='
    }

    It "Uses CmdletBinding attribute" {
        $script:Content | Should -Match '\[CmdletBinding\(\)\]'
    }

    It "Cleans up temporary test directories" {
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

Describe "verify-openai.ps1 - OpenAI SDK Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Creates Python test files for testing" {
        $script:Content | Should -Match 'test_openai_import\.py|test_version\.py|test_imports\.py|test_client\.py'
    }

    It "Tests Python OpenAI client class" {
        $script:Content | Should -Match 'OpenAI\(api_key='
    }

    It "Tests Python OpenAI version checking" {
        $script:Content | Should -Match 'openai\.__version__'
    }

    It "Creates Node.js test files for testing" {
        $script:Content | Should -Match '\.mjs'
    }

    It "Tests Node.js OpenAI client instantiation" {
        $script:Content | Should -Match 'new OpenAI\('
    }

    It "Uses test API keys for verification" {
        $script:Content | Should -Match 'sk-test-key-for-verification'
    }

    It "Tests package installation capability" {
        $script:Content | Should -Match 'npm install'
    }

    It "Checks both Python and Node.js implementations" {
        $script:Content | Should -Match 'Python OpenAI'
        $script:Content | Should -Match 'Node\.js OpenAI'
    }
}
