#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-weaviate.ps1'
}

Describe "verify-weaviate.ps1 - Script Validation" {
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

Describe "verify-weaviate.ps1 - Parameter Validation" {
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

    It "Has SkipConnectionTest switch parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'SkipConnectionTest' }
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

    It "Has MinimumWeaviateVersion string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumWeaviateVersion' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "MinimumWeaviateVersion has default value of 3.0.0" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumWeaviateVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '3.0.0'
    }

    It "Has WeaviateUrl string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'WeaviateUrl' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "WeaviateUrl has default value of http://localhost:8080" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'WeaviateUrl' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be 'http://localhost:8080'
    }

    It "Has ApiKey string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'ApiKey' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }
}

Describe "verify-weaviate.ps1 - Function Definitions" {
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

Describe "verify-weaviate.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains Python version check" {
        $script:Content | Should -Match 'python --version'
    }

    It "Contains pip check" {
        $script:Content | Should -Match 'python -m pip --version'
    }

    It "Contains Weaviate import check" {
        $script:Content | Should -Match 'import weaviate'
    }

    It "Contains Weaviate version check" {
        $script:Content | Should -Match 'weaviate\.__version__'
    }

    It "Contains Weaviate client import check" {
        $script:Content | Should -Match 'import weaviate'
    }

    It "Contains Weaviate classes import check" {
        $script:Content | Should -Match 'from weaviate\.classes\.config import Configure'
    }

    It "Contains Docker availability check" {
        $script:Content | Should -Match 'docker --version'
    }

    It "Contains Weaviate container check" {
        $script:Content | Should -Match 'docker ps'
    }

    It "Contains NumPy check" {
        $script:Content | Should -Match 'import numpy'
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

Describe "verify-weaviate.ps1 - Execution Tests" {
    Context "When Python is not available" {
        BeforeAll {
            $script:OriginalPath = $env:PATH
            $env:PATH = ""
        }

        AfterAll {
            $env:PATH = $script:OriginalPath
        }

        It "Should handle missing Python gracefully" {
            { & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 } | Should -Not -Throw
        }
    }

    Context "When Python is available" {
        BeforeAll {
            $script:PythonAvailable = $null -ne (Get-Command python -ErrorAction SilentlyContinue)
        }

        It "Should execute without errors when python is available" -Skip:(-not $script:PythonAvailable) {
            { & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include passed/failed/warnings counts in JSON output" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.passed | Should -BeOfType [int]
            $json.failed | Should -BeOfType [int]
            $json.warnings | Should -BeOfType [int]
        }

        It "Should perform Python interpreter check" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $pythonCheck = $json.checks | Where-Object { $_.name -eq 'Python Interpreter' }
            $pythonCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform pip package manager check" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $pipCheck = $json.checks | Where-Object { $_.name -eq 'pip Package Manager' }
            $pipCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Weaviate client package check" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $weaviateCheck = $json.checks | Where-Object { $_.name -eq 'Weaviate Client Package' }
            $weaviateCheck | Should -Not -BeNullOrEmpty
        }

        It "Should accept MinimumPythonVersion parameter" -Skip:(-not $script:PythonAvailable) {
            { & $script:ScriptPath -MinimumPythonVersion "3.8" -SkipConnectionTest -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should accept MinimumWeaviateVersion parameter" -Skip:(-not $script:PythonAvailable) {
            { & $script:ScriptPath -MinimumWeaviateVersion "3.0.0" -SkipConnectionTest -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should accept WeaviateUrl parameter" -Skip:(-not $script:PythonAvailable) {
            { & $script:ScriptPath -WeaviateUrl "http://localhost:8080" -SkipConnectionTest -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should accept SkipConnectionTest parameter" -Skip:(-not $script:PythonAvailable) {
            { & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should exit with code 1 when -ExitOnFailure is used and checks fail" {
            $result = & $script:ScriptPath -MinimumPythonVersion "99.0" -ExitOnFailure -SkipConnectionTest -JsonOutput 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Output Formatting" {
        BeforeAll {
            $script:PythonAvailable = $null -ne (Get-Command python -ErrorAction SilentlyContinue)
        }

        It "Should display checkmarks for passed tests (non-JSON mode)" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -SkipConnectionTest 2>&1 | Out-String
            $output | Should -Match '✅|✓|PASS'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -SkipConnectionTest 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }
    }
}

Describe "verify-weaviate.ps1 - Security and Best Practices" {
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

Describe "verify-weaviate.ps1 - Weaviate Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Creates a Python test file for testing" {
        $script:Content | Should -Match 'test_weaviate\.py'
    }

    It "Tests Weaviate client class" {
        $script:Content | Should -Match 'WeaviateClient\(\)'
    }

    It "Checks for Weaviate classes import" {
        $script:Content | Should -Match 'from weaviate\.classes\.config import Configure'
    }

    It "Checks for Docker availability" {
        $script:Content | Should -Match 'docker --version'
    }

    It "Checks for Weaviate container" {
        $script:Content | Should -Match 'semitechnologies/weaviate'
    }

    It "Checks for NumPy package" {
        $script:Content | Should -Match 'import numpy'
    }

    It "Tests connection with connect_to_local" {
        $script:Content | Should -Match 'connect_to_local'
    }

    It "Tests is_ready method" {
        $script:Content | Should -Match 'is_ready\(\)'
    }

    It "Tests get_meta method" {
        $script:Content | Should -Match 'get_meta\(\)'
    }

    It "Includes skip connection test option" {
        $script:Content | Should -Match 'if \(-not \$SkipConnectionTest\)'
    }
}
