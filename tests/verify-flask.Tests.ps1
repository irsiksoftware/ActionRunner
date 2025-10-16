#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-flask.ps1'
}

Describe "verify-flask.ps1 - Script Validation" {
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

Describe "verify-flask.ps1 - Parameter Validation" {
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

    It "MinimumVersion has default value of 2.0" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '2.0'
    }
}

Describe "verify-flask.ps1 - Function Definitions" {
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

Describe "verify-flask.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains Flask import check" {
        $script:Content | Should -Match 'import flask'
    }

    It "Contains Flask version check" {
        $script:Content | Should -Match 'flask.__version__|flask --version'
    }

    It "Contains Flask application creation check" {
        $script:Content | Should -Match 'Flask\(__name__\)'
    }

    It "Contains Flask route decorator check" {
        $script:Content | Should -Match '@app\.route'
    }

    It "Contains Flask run capability check" {
        $script:Content | Should -Match 'app\.run'
    }

    It "Contains Flask request handling check" {
        $script:Content | Should -Match 'from flask import.*request'
    }

    It "Contains Flask response handling check" {
        $script:Content | Should -Match 'jsonify|make_response'
    }

    It "Contains Flask template rendering check" {
        $script:Content | Should -Match 'render_template'
    }

    It "Contains Flask config check" {
        $script:Content | Should -Match 'app\.config'
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

Describe "verify-flask.ps1 - Execution Tests" {
    Context "When Flask is not available" {
        BeforeAll {
            $script:OriginalPath = $env:PATH
            $env:PATH = ""
        }

        AfterAll {
            $env:PATH = $script:OriginalPath
        }

        It "Should handle missing Flask gracefully" {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }
    }

    Context "When Flask is available" {
        BeforeAll {
            $script:PythonAvailable = $null -ne (Get-Command python -ErrorAction SilentlyContinue)
            if ($script:PythonAvailable) {
                $flaskCheck = python -c "import flask; print('ok')" 2>$null
                $script:FlaskAvailable = $flaskCheck -eq 'ok'
            } else {
                $script:FlaskAvailable = $false
            }
        }

        It "Should execute without errors when Flask is available" -Skip:(-not $script:FlaskAvailable) {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" -Skip:(-not $script:FlaskAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" -Skip:(-not $script:FlaskAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" -Skip:(-not $script:FlaskAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include passed/failed/warnings counts in JSON output" -Skip:(-not $script:FlaskAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.passed | Should -BeOfType [int]
            $json.failed | Should -BeOfType [int]
            $json.warnings | Should -BeOfType [int]
        }

        It "Should perform Flask import check" -Skip:(-not $script:FlaskAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $importCheck = $json.checks | Where-Object { $_.name -match 'Flask.*Import|Flask.*Available' }
            $importCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Flask version check" -Skip:(-not $script:FlaskAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $versionCheck = $json.checks | Where-Object { $_.name -match 'Flask.*Version' }
            $versionCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Flask application creation check" -Skip:(-not $script:FlaskAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $appCheck = $json.checks | Where-Object { $_.name -match 'Flask.*Application|App.*Creation' }
            $appCheck | Should -Not -BeNullOrEmpty
        }

        It "Should accept MinimumVersion parameter" -Skip:(-not $script:FlaskAvailable) {
            { & $script:ScriptPath -MinimumVersion "2.0" -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should exit with code 1 when -ExitOnFailure is used and checks fail" {
            $result = & $script:ScriptPath -MinimumVersion "999.0" -ExitOnFailure -JsonOutput 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Output Formatting" {
        It "Should display checkmarks for passed tests (non-JSON mode)" -Skip:(-not $script:FlaskAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match '✅|✓|PASS'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:FlaskAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }
    }
}

Describe "verify-flask.ps1 - Security and Best Practices" {
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

Describe "verify-flask.ps1 - Flask Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Creates a temporary Flask application for testing" {
        $script:Content | Should -Match 'Flask\(__name__\)|app = Flask'
    }

    It "Tests Flask route creation" {
        $script:Content | Should -Match '@app\.route'
    }

    It "Tests Flask request context" {
        $script:Content | Should -Match 'with app\.test_request_context|app\.test_client'
    }

    It "Tests Flask JSON response capability" {
        $script:Content | Should -Match 'jsonify'
    }

    It "Tests Flask template rendering" {
        $script:Content | Should -Match 'render_template_string|render_template'
    }

    It "Tests Flask configuration management" {
        $script:Content | Should -Match 'app\.config\['
    }

    It "Tests Flask blueprint support" {
        $script:Content | Should -Match 'Blueprint|flask\.blueprints'
    }

    It "Tests Flask extensions availability" {
        $script:Content | Should -Match 'flask\.|from flask import'
    }
}
