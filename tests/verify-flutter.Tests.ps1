#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-flutter.ps1'
}

Describe "verify-flutter.ps1 - Script Validation" {
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

Describe "verify-flutter.ps1 - Parameter Validation" {
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

    It "Has MinimumFlutterVersion string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumFlutterVersion' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "MinimumFlutterVersion has default value" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumFlutterVersion' }
        $param.DefaultValue | Should -Not -BeNullOrEmpty
    }
}

Describe "verify-flutter.ps1 - Function Definitions" {
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

Describe "verify-flutter.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains flutter command check" {
        $script:Content | Should -Match 'flutter --version'
    }

    It "Contains dart command check" {
        $script:Content | Should -Match 'dart --version'
    }

    It "Contains Flutter SDK path check" {
        $script:Content | Should -Match 'flutter.bat|flutter\.exe|FLUTTER_HOME|flutter sdk'
    }

    It "Contains flutter doctor check" {
        $script:Content | Should -Match 'flutter doctor'
    }

    It "Contains flutter create command" {
        $script:Content | Should -Match 'flutter create'
    }

    It "Contains flutter pub get check" {
        $script:Content | Should -Match 'flutter pub get'
    }

    It "Contains flutter build check" {
        $script:Content | Should -Match 'flutter build'
    }

    It "Contains flutter test check" {
        $script:Content | Should -Match 'flutter test'
    }

    It "Contains pubspec.yaml check" {
        $script:Content | Should -Match 'pubspec\.yaml'
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

Describe "verify-flutter.ps1 - Execution Tests" {
    Context "When Flutter is not available" {
        BeforeAll {
            # Save original environment variables
            $script:OriginalPath = $env:PATH

            # Temporarily modify PATH to exclude Flutter
            $env:PATH = ""
        }

        AfterAll {
            # Restore original environment variables
            $env:PATH = $script:OriginalPath
        }

        It "Should handle missing Flutter SDK gracefully" {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }
    }

    Context "When Flutter is available" {
        BeforeAll {
            # Check if Flutter is available
            $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
            $script:FlutterAvailable = $null -ne $flutterCommand
        }

        It "Should execute without errors when Flutter is available" -Skip:(-not $script:FlutterAvailable) {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" -Skip:(-not $script:FlutterAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" -Skip:(-not $script:FlutterAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" -Skip:(-not $script:FlutterAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include passed/failed/warnings counts in JSON output" -Skip:(-not $script:FlutterAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.passed | Should -BeOfType [int]
            $json.failed | Should -BeOfType [int]
            $json.warnings | Should -BeOfType [int]
        }

        It "Should perform Flutter installation check" -Skip:(-not $script:FlutterAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $flutterCheck = $json.checks | Where-Object { $_.name -match 'Flutter' }
            $flutterCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Dart SDK check" -Skip:(-not $script:FlutterAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $dartCheck = $json.checks | Where-Object { $_.name -match 'Dart' }
            $dartCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform flutter doctor check" -Skip:(-not $script:FlutterAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $doctorCheck = $json.checks | Where-Object { $_.name -match 'doctor' }
            $doctorCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Flutter project build test" -Skip:(-not $script:FlutterAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $buildCheck = $json.checks | Where-Object { $_.name -match 'build|project' }
            $buildCheck | Should -Not -BeNullOrEmpty
        }

        It "Should accept MinimumFlutterVersion parameter" -Skip:(-not $script:FlutterAvailable) {
            { & $script:ScriptPath -MinimumFlutterVersion "3.0.0" -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should exit with code 1 when -ExitOnFailure is used and checks fail" {
            # Force a failure by requiring a very high Flutter version
            $result = & $script:ScriptPath -MinimumFlutterVersion "999.0.0" -ExitOnFailure -JsonOutput 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Output Formatting" {
        BeforeAll {
            $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
            $script:FlutterAvailable = $null -ne $flutterCommand
        }

        It "Should display checkmarks for passed tests (non-JSON mode)" -Skip:(-not $script:FlutterAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match '✅|✓|PASS'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:FlutterAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }
    }
}

Describe "verify-flutter.ps1 - Security and Best Practices" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Uses ErrorActionPreference" {
        $script:Content | Should -Match '\$ErrorActionPreference\s*='
    }

    It "Uses CmdletBinding attribute" {
        $script:Content | Should -Match '\[CmdletBinding\(\)\]'
    }

    It "Cleans up temporary test projects" {
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

Describe "verify-flutter.ps1 - Flutter Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Creates a Flutter project for testing" {
        $script:Content | Should -Match 'flutter create'
    }

    It "Checks for pubspec.yaml" {
        $script:Content | Should -Match 'pubspec\.yaml'
    }

    It "Verifies Flutter project structure" {
        $script:Content | Should -Match 'pubspec\.yaml'
    }

    It "Tests Flutter dependencies installation" {
        $script:Content | Should -Match 'flutter pub get'
    }

    It "Tests Flutter project build" {
        $script:Content | Should -Match 'flutter build'
    }

    It "Tests Flutter unit tests" {
        $script:Content | Should -Match 'flutter test'
    }

    It "Checks Flutter version" {
        $script:Content | Should -Match 'flutter --version'
    }

    It "Checks Dart version" {
        $script:Content | Should -Match 'dart --version'
    }

    It "Runs flutter doctor for environment check" {
        $script:Content | Should -Match 'flutter doctor'
    }

    It "Verifies Flutter SDK installation" {
        $script:Content | Should -Match 'flutter sdk|FLUTTER_HOME|flutter\.bat'
    }

}
