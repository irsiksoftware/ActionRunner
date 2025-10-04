#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-gradle.ps1'
}

Describe "verify-gradle.ps1 - Script Validation" {
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

Describe "verify-gradle.ps1 - Parameter Validation" {
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

    It "MinimumVersion has default value of 6.0" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '6.0'
    }
}

Describe "verify-gradle.ps1 - Function Definitions" {
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

Describe "verify-gradle.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains Gradle version check" {
        $script:Content | Should -Match 'gradle --version'
    }

    It "Contains Java version check" {
        $script:Content | Should -Match 'java -version'
    }

    It "Contains JAVA_HOME check" {
        $script:Content | Should -Match '\$env:JAVA_HOME'
    }

    It "Contains Gradle home check" {
        $script:Content | Should -Match 'GRADLE_HOME'
    }

    It "Contains Gradle user home check" {
        $script:Content | Should -Match '\.gradle'
    }

    It "Contains Gradle daemon check" {
        $script:Content | Should -Match 'gradle --status'
    }

    It "Contains build.gradle creation" {
        $script:Content | Should -Match 'build\.gradle'
    }

    It "Contains build.gradle.kts creation (Kotlin DSL)" {
        $script:Content | Should -Match 'build\.gradle\.kts'
    }

    It "Contains Gradle build command" {
        $script:Content | Should -Match 'gradle build'
    }

    It "Contains Gradle wrapper command" {
        $script:Content | Should -Match 'gradle wrapper'
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

    It "Uses --no-daemon flag to avoid daemon issues in tests" {
        $script:Content | Should -Match '--no-daemon'
    }
}

Describe "verify-gradle.ps1 - Execution Tests" {
    Context "When Gradle is not available" {
        BeforeAll {
            # Mock gradle command by temporarily renaming PATH
            $script:OriginalPath = $env:PATH
            $env:PATH = ""
        }

        AfterAll {
            $env:PATH = $script:OriginalPath
        }

        It "Should handle missing Gradle gracefully" {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }
    }

    Context "When Gradle is available" {
        BeforeAll {
            # Check if gradle is available
            $script:GradleAvailable = $null -ne (Get-Command gradle -ErrorAction SilentlyContinue)
        }

        It "Should execute without errors when gradle is available" -Skip:(-not $script:GradleAvailable) {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" -Skip:(-not $script:GradleAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" -Skip:(-not $script:GradleAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" -Skip:(-not $script:GradleAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include passed/failed/warnings counts in JSON output" -Skip:(-not $script:GradleAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.passed | Should -BeOfType [int]
            $json.failed | Should -BeOfType [int]
            $json.warnings | Should -BeOfType [int]
        }

        It "Should perform Gradle installation check" -Skip:(-not $script:GradleAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $gradleCheck = $json.checks | Where-Object { $_.name -eq 'Gradle Installation' }
            $gradleCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Java runtime check" -Skip:(-not $script:GradleAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $javaCheck = $json.checks | Where-Object { $_.name -eq 'Java Runtime' }
            $javaCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform JAVA_HOME check" -Skip:(-not $script:GradleAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $javaHomeCheck = $json.checks | Where-Object { $_.name -eq 'JAVA_HOME Configuration' }
            $javaHomeCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Gradle build test with Groovy DSL" -Skip:(-not $script:GradleAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $buildCheck = $json.checks | Where-Object { $_.name -eq 'Gradle Build Test (Groovy DSL)' }
            $buildCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Gradle build test with Kotlin DSL" -Skip:(-not $script:GradleAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $buildCheck = $json.checks | Where-Object { $_.name -eq 'Gradle Build Test (Kotlin DSL)' }
            $buildCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Gradle wrapper test" -Skip:(-not $script:GradleAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $wrapperCheck = $json.checks | Where-Object { $_.name -eq 'Gradle Wrapper Test' }
            $wrapperCheck | Should -Not -BeNullOrEmpty
        }

        It "Should accept MinimumVersion parameter" -Skip:(-not $script:GradleAvailable) {
            { & $script:ScriptPath -MinimumVersion "6.0" -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should exit with code 1 when -ExitOnFailure is used and checks fail" {
            # Force a failure by requiring a very high version
            $result = & $script:ScriptPath -MinimumVersion "99.0" -ExitOnFailure -JsonOutput 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Output Formatting" {
        It "Should display checkmarks for passed tests (non-JSON mode)" -Skip:(-not $script:GradleAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match '✅|✓|PASS'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:GradleAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }
    }
}

Describe "verify-gradle.ps1 - Security and Best Practices" {
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

Describe "verify-gradle.ps1 - Gradle Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Creates a Gradle build file for testing (Groovy)" {
        $script:Content | Should -Match 'build\.gradle'
    }

    It "Creates a Gradle build file for testing (Kotlin DSL)" {
        $script:Content | Should -Match 'build\.gradle\.kts'
    }

    It "Tests Gradle project structure" {
        $script:Content | Should -Match 'src\\main\\java'
    }

    It "Creates Java source files" {
        $script:Content | Should -Match '\.java'
    }

    It "Tests Gradle build goal" {
        $script:Content | Should -Match 'build\\classes'
    }

    It "Tests Gradle wrapper generation" {
        $script:Content | Should -Match 'gradlew\.bat'
    }

    It "Uses proper Gradle build configuration" {
        $script:Content | Should -Match 'plugins'
        $script:Content | Should -Match 'repositories'
    }

    It "Checks for .gradle directory" {
        $script:Content | Should -Match '\.gradle'
    }

    It "Tests both Groovy and Kotlin DSL" {
        $script:Content | Should -Match 'Groovy DSL'
        $script:Content | Should -Match 'Kotlin DSL'
    }
}
