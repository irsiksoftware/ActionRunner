#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-android.ps1'
}

Describe "verify-android.ps1 - Script Validation" {
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

Describe "verify-android.ps1 - Parameter Validation" {
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

    It "Has MinimumApiLevel int parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumApiLevel' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'Int32'
    }

    It "MinimumApiLevel has default value of 21" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumApiLevel' }
        $defaultValue = $param.DefaultValue.Extent.Text
        $defaultValue | Should -Be '21'
    }

    It "Has MinimumBuildToolsVersion string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumBuildToolsVersion' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "MinimumBuildToolsVersion has default value of 30.0.0" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumBuildToolsVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '30.0.0'
    }
}

Describe "verify-android.ps1 - Function Definitions" {
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

Describe "verify-android.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains ANDROID_HOME check" {
        $script:Content | Should -Match '\$env:ANDROID_HOME'
    }

    It "Contains ANDROID_SDK_ROOT check" {
        $script:Content | Should -Match '\$env:ANDROID_SDK_ROOT'
    }

    It "Contains sdkmanager check" {
        $script:Content | Should -Match 'sdkmanager'
    }

    It "Contains adb check" {
        $script:Content | Should -Match 'adb'
    }

    It "Contains build-tools check" {
        $script:Content | Should -Match 'build-tools'
    }

    It "Contains platforms check" {
        $script:Content | Should -Match 'platforms'
    }

    It "Contains Java version check" {
        $script:Content | Should -Match 'java -version'
    }

    It "Contains Gradle check" {
        $script:Content | Should -Match 'gradle --version'
    }

    It "Contains Android project build test" {
        $script:Content | Should -Match 'AndroidManifest\.xml'
    }

    It "Contains MainActivity creation" {
        $script:Content | Should -Match 'MainActivity'
    }

    It "Contains build.gradle creation" {
        $script:Content | Should -Match 'build\.gradle'
    }

    It "Contains settings.gradle creation" {
        $script:Content | Should -Match 'settings\.gradle'
    }

    It "Contains assembleDebug command" {
        $script:Content | Should -Match 'assembleDebug'
    }

    It "Contains APK file check" {
        $script:Content | Should -Match 'app-debug\.apk'
    }

    It "Contains gradle wrapper creation" {
        $script:Content | Should -Match 'gradle wrapper'
    }

    It "Contains gradlew.bat check" {
        $script:Content | Should -Match 'gradlew\.bat'
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

Describe "verify-android.ps1 - Execution Tests" {
    Context "When Android SDK is not available" {
        BeforeAll {
            # Save original environment variables
            $script:OriginalAndroidHome = $env:ANDROID_HOME
            $script:OriginalPath = $env:PATH

            # Temporarily unset ANDROID_HOME and PATH
            $env:ANDROID_HOME = $null
            $env:PATH = ""
        }

        AfterAll {
            # Restore original environment variables
            $env:ANDROID_HOME = $script:OriginalAndroidHome
            $env:PATH = $script:OriginalPath
        }

        It "Should handle missing Android SDK gracefully" {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }
    }

    Context "When Android SDK is available" {
        BeforeAll {
            # Check if Android SDK is available
            $script:AndroidAvailable = ($null -ne $env:ANDROID_HOME) -and (Test-Path $env:ANDROID_HOME)
        }

        It "Should execute without errors when Android SDK is available" -Skip:(-not $script:AndroidAvailable) {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" -Skip:(-not $script:AndroidAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" -Skip:(-not $script:AndroidAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" -Skip:(-not $script:AndroidAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include passed/failed/warnings counts in JSON output" -Skip:(-not $script:AndroidAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.passed | Should -BeOfType [int]
            $json.failed | Should -BeOfType [int]
            $json.warnings | Should -BeOfType [int]
        }

        It "Should perform ANDROID_HOME check" -Skip:(-not $script:AndroidAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $androidHomeCheck = $json.checks | Where-Object { $_.name -eq 'ANDROID_HOME Configuration' }
            $androidHomeCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform SDK command-line tools check" -Skip:(-not $script:AndroidAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $cmdlineCheck = $json.checks | Where-Object { $_.name -eq 'Android SDK Command-line Tools' }
            $cmdlineCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform platform-tools check" -Skip:(-not $script:AndroidAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $platformToolsCheck = $json.checks | Where-Object { $_.name -eq 'Android Platform Tools' }
            $platformToolsCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform build-tools check" -Skip:(-not $script:AndroidAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $buildToolsCheck = $json.checks | Where-Object { $_.name -eq 'Android Build Tools' }
            $buildToolsCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform SDK platforms check" -Skip:(-not $script:AndroidAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $platformsCheck = $json.checks | Where-Object { $_.name -eq 'Android SDK Platforms' }
            $platformsCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Java runtime check" -Skip:(-not $script:AndroidAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $javaCheck = $json.checks | Where-Object { $_.name -eq 'Java Runtime' }
            $javaCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Android project build test" -Skip:(-not $script:AndroidAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $buildCheck = $json.checks | Where-Object { $_.name -eq 'Android Project Build Test' }
            $buildCheck | Should -Not -BeNullOrEmpty
        }

        It "Should accept MinimumApiLevel parameter" -Skip:(-not $script:AndroidAvailable) {
            { & $script:ScriptPath -MinimumApiLevel 21 -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should accept MinimumBuildToolsVersion parameter" -Skip:(-not $script:AndroidAvailable) {
            { & $script:ScriptPath -MinimumBuildToolsVersion "30.0.0" -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should exit with code 1 when -ExitOnFailure is used and checks fail" {
            # Force a failure by requiring a very high API level
            $result = & $script:ScriptPath -MinimumApiLevel 999 -ExitOnFailure -JsonOutput 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Output Formatting" {
        BeforeAll {
            $script:AndroidAvailable = ($null -ne $env:ANDROID_HOME) -and (Test-Path $env:ANDROID_HOME)
        }

        It "Should display checkmarks for passed tests (non-JSON mode)" -Skip:(-not $script:AndroidAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match '✅|✓|PASS'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:AndroidAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }
    }
}

Describe "verify-android.ps1 - Security and Best Practices" {
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

Describe "verify-android.ps1 - Android Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Creates an Android manifest for testing" {
        $script:Content | Should -Match 'AndroidManifest\.xml'
    }

    It "Creates an Android activity" {
        $script:Content | Should -Match 'MainActivity\.java'
    }

    It "Creates Android project structure" {
        $script:Content | Should -Match 'src\\main\\java'
    }

    It "Creates Android resources" {
        $script:Content | Should -Match 'res\\values'
    }

    It "Creates strings.xml resource file" {
        $script:Content | Should -Match 'strings\.xml'
    }

    It "Tests Android build with Gradle" {
        $script:Content | Should -Match 'assembleDebug'
    }

    It "Verifies APK output" {
        $script:Content | Should -Match 'app-debug\.apk'
    }

    It "Uses Android Gradle plugin" {
        $script:Content | Should -Match 'com\.android\.tools\.build:gradle'
    }

    It "Configures Android SDK versions" {
        $script:Content | Should -Match 'compileSdkVersion'
        $script:Content | Should -Match 'minSdkVersion'
        $script:Content | Should -Match 'targetSdkVersion'
    }

    It "Uses androidx dependencies" {
        $script:Content | Should -Match 'androidx\.appcompat'
    }

    It "Checks for cmdline-tools" {
        $script:Content | Should -Match 'cmdline-tools'
    }

    It "Checks for platform-tools" {
        $script:Content | Should -Match 'platform-tools'
    }
}
