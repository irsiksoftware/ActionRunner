#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-django.ps1'
}

Describe "verify-django.ps1 - Script Validation" {
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

Describe "verify-django.ps1 - Parameter Validation" {
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

    It "MinimumVersion has default value of 3.2" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '3.2'
    }
}

Describe "verify-django.ps1 - Function Definitions" {
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

Describe "verify-django.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains Django import check" {
        $script:Content | Should -Match 'import django'
    }

    It "Contains Django version check" {
        $script:Content | Should -Match 'django\.VERSION|django\.get_version|django --version'
    }

    It "Contains Django project creation check" {
        $script:Content | Should -Match 'django-admin startproject'
    }

    It "Contains Django app creation check" {
        $script:Content | Should -Match 'startapp'
    }

    It "Contains Django settings check" {
        $script:Content | Should -Match 'settings|INSTALLED_APPS'
    }

    It "Contains Django ORM check" {
        $script:Content | Should -Match 'models\.Model|from django\.db import models'
    }

    It "Contains Django migrations check" {
        $script:Content | Should -Match 'makemigrations|migrate'
    }

    It "Contains Django admin check" {
        $script:Content | Should -Match 'django\.contrib\.admin|admin\.site'
    }

    It "Contains Django URL routing check" {
        $script:Content | Should -Match 'urlpatterns|path|url'
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

Describe "verify-django.ps1 - Execution Tests" {
    Context "When Django is not available" {
        BeforeAll {
            $script:OriginalPath = $env:PATH
            $env:PATH = ""
        }

        AfterAll {
            $env:PATH = $script:OriginalPath
        }

        It "Should handle missing Django gracefully" {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }
    }

    Context "When Django is available" {
        BeforeAll {
            $script:PythonAvailable = $null -ne (Get-Command python -ErrorAction SilentlyContinue)
            if ($script:PythonAvailable) {
                $djangoCheck = python -c "import django; print('ok')" 2>$null
                $script:DjangoAvailable = $djangoCheck -eq 'ok'
            } else {
                $script:DjangoAvailable = $false
            }
        }

        It "Should execute without errors when Django is available" -Skip:(-not $script:DjangoAvailable) {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" -Skip:(-not $script:DjangoAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" -Skip:(-not $script:DjangoAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" -Skip:(-not $script:DjangoAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include passed/failed/warnings counts in JSON output" -Skip:(-not $script:DjangoAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.passed | Should -BeOfType [int]
            $json.failed | Should -BeOfType [int]
            $json.warnings | Should -BeOfType [int]
        }

        It "Should perform Django import check" -Skip:(-not $script:DjangoAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $importCheck = $json.checks | Where-Object { $_.name -match 'Django.*Import|Django.*Available' }
            $importCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Django version check" -Skip:(-not $script:DjangoAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $versionCheck = $json.checks | Where-Object { $_.name -match 'Django.*Version' }
            $versionCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Django admin command check" -Skip:(-not $script:DjangoAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $adminCheck = $json.checks | Where-Object { $_.name -match 'django-admin|Admin.*Command' }
            $adminCheck | Should -Not -BeNullOrEmpty
        }

        It "Should accept MinimumVersion parameter" -Skip:(-not $script:DjangoAvailable) {
            { & $script:ScriptPath -MinimumVersion "3.2" -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should exit with code 1 when -ExitOnFailure is used and checks fail" {
            $result = & $script:ScriptPath -MinimumVersion "999.0" -ExitOnFailure -JsonOutput 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Output Formatting" {
        It "Should display checkmarks for passed tests (non-JSON mode)" -Skip:(-not $script:DjangoAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match '✅|✓|PASS'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:DjangoAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }
    }
}

Describe "verify-django.ps1 - Security and Best Practices" {
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

Describe "verify-django.ps1 - Django Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Tests django-admin startproject command" {
        $script:Content | Should -Match 'django-admin startproject'
    }

    It "Tests Django settings module" {
        $script:Content | Should -Match 'DJANGO_SETTINGS_MODULE|settings'
    }

    It "Tests Django model creation" {
        $script:Content | Should -Match 'models\.Model|class.*Model'
    }

    It "Tests Django migrations" {
        $script:Content | Should -Match 'makemigrations|migrate'
    }

    It "Tests Django URL configuration" {
        $script:Content | Should -Match 'urlpatterns|path\('
    }

    It "Tests Django views" {
        $script:Content | Should -Match 'from django\.http import|HttpResponse'
    }

    It "Tests Django template system" {
        $script:Content | Should -Match 'render|template'
    }

    It "Tests Django ORM queries" {
        $script:Content | Should -Match 'objects\.all|objects\.filter'
    }
}
