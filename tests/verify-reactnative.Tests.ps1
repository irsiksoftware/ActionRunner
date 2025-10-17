#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-reactnative.ps1'
}

Describe "verify-reactnative.ps1 - Script Validation" {
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

Describe "verify-reactnative.ps1 - Parameter Validation" {
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

    It "Has MinimumNodeVersion string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumNodeVersion' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "Has MinimumReactNativeVersion string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumReactNativeVersion' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "MinimumNodeVersion has default value of 16.0" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumNodeVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '16.0'
    }

    It "MinimumReactNativeVersion has default value of 0.70.0" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumReactNativeVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '0.70.0'
    }
}

Describe "verify-reactnative.ps1 - Function Definitions" {
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

Describe "verify-reactnative.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains Node.js version check" {
        $script:Content | Should -Match 'node --version'
    }

    It "Contains npm availability check" {
        $script:Content | Should -Match 'npm --version'
    }

    It "Contains React Native CLI check" {
        $script:Content | Should -Match 'react-native --version'
    }

    It "Contains npx react-native check" {
        $script:Content | Should -Match 'npx react-native'
    }

    It "Contains Watchman check" {
        $script:Content | Should -Match 'watchman --version'
    }

    It "Contains Android SDK check" {
        $script:Content | Should -Match 'ANDROID_HOME'
        $script:Content | Should -Match 'ANDROID_SDK_ROOT'
    }

    It "Contains adb platform tools check" {
        $script:Content | Should -Match 'adb --version'
    }

    It "Contains Java runtime check" {
        $script:Content | Should -Match 'java -version'
    }

    It "Contains Xcode tools check for macOS" {
        $script:Content | Should -Match 'xcode-select'
    }

    It "Contains CocoaPods check for iOS" {
        $script:Content | Should -Match 'pod --version'
    }

    It "Contains React Native project initialization test" {
        $script:Content | Should -Match 'react-native init'
    }

    It "Contains npm install test" {
        $script:Content | Should -Match 'npm install'
    }

    It "Contains Metro bundler check" {
        $script:Content | Should -Match 'Metro bundler'
    }

    It "Contains Android build setup check" {
        $script:Content | Should -Match 'gradlew'
    }

    It "Contains iOS build setup check" {
        $script:Content | Should -Match 'Podfile'
    }

    It "References dependency on Issue #9 (Node.js)" {
        $script:Content | Should -Match 'Issue #9'
    }

    It "References dependency on Issue #25 (Android SDK)" {
        $script:Content | Should -Match 'Issue #25'
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

Describe "verify-reactnative.ps1 - Execution Tests" {
    Context "When Node.js is not available" {
        BeforeAll {
            # Mock node command by temporarily renaming PATH
            $script:OriginalPath = $env:PATH
            $env:PATH = ""
        }

        AfterAll {
            $env:PATH = $script:OriginalPath
        }

        It "Should handle missing Node.js gracefully" {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }
    }

    Context "When Node.js is available" {
        BeforeAll {
            # Check if node is available
            $script:NodeAvailable = $null -ne (Get-Command node -ErrorAction SilentlyContinue)
            $script:NpmAvailable = $null -ne (Get-Command npm -ErrorAction SilentlyContinue)
        }

        It "Should execute without errors when node is available" -Skip:(-not $script:NodeAvailable) {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" -Skip:(-not $script:NodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" -Skip:(-not $script:NodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" -Skip:(-not $script:NodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include passed/failed/warnings counts in JSON output" -Skip:(-not $script:NodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.passed | Should -BeOfType [int]
            $json.failed | Should -BeOfType [int]
            $json.warnings | Should -BeOfType [int]
        }

        It "Should perform Node.js command availability check" -Skip:(-not $script:NodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $nodeCheck = $json.checks | Where-Object { $_.name -eq 'Node.js Command Available' }
            $nodeCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Node.js version check" -Skip:(-not $script:NodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $versionCheck = $json.checks | Where-Object { $_.name -eq 'Node.js Version' }
            $versionCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform npm command availability check" -Skip:(-not $script:NodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $npmCheck = $json.checks | Where-Object { $_.name -eq 'npm Command Available' }
            $npmCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform React Native CLI check" -Skip:(-not $script:NodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $rnCheck = $json.checks | Where-Object { $_.name -eq 'React Native CLI Available' }
            $rnCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform React Native CLI version check" -Skip:(-not $script:NodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $rnVersionCheck = $json.checks | Where-Object { $_.name -eq 'React Native CLI Version' }
            $rnVersionCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Watchman check" -Skip:(-not $script:NodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $watchmanCheck = $json.checks | Where-Object { $_.name -eq 'Watchman File Watcher' }
            $watchmanCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Android SDK configuration check" -Skip:(-not $script:NodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $androidCheck = $json.checks | Where-Object { $_.name -eq 'Android SDK Configuration' }
            $androidCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Android Platform Tools check" -Skip:(-not $script:NodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $adbCheck = $json.checks | Where-Object { $_.name -eq 'Android Platform Tools' }
            $adbCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Java Runtime check" -Skip:(-not $script:NodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $javaCheck = $json.checks | Where-Object { $_.name -eq 'Java Runtime' }
            $javaCheck | Should -Not -BeNullOrEmpty
        }

        It "Should accept MinimumNodeVersion parameter" -Skip:(-not $script:NodeAvailable) {
            { & $script:ScriptPath -MinimumNodeVersion "16.0" -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should accept MinimumReactNativeVersion parameter" -Skip:(-not $script:NodeAvailable) {
            { & $script:ScriptPath -MinimumReactNativeVersion "0.70.0" -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should exit with code 1 when -ExitOnFailure is used and checks fail" {
            # Force a failure by requiring a very high version
            $result = & $script:ScriptPath -MinimumNodeVersion "999.0" -ExitOnFailure -JsonOutput 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Output Formatting" {
        BeforeAll {
            $script:NodeAvailable = $null -ne (Get-Command node -ErrorAction SilentlyContinue)
        }

        It "Should display checkmarks for passed tests (non-JSON mode)" -Skip:(-not $script:NodeAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match '✅|✓|PASS'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:NodeAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }
    }
}

Describe "verify-reactnative.ps1 - Security and Best Practices" {
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

Describe "verify-reactnative.ps1 - React Native Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Tests React Native project initialization" {
        $script:Content | Should -Match 'react-native init'
    }

    It "Tests npm package installation" {
        $script:Content | Should -Match 'npm install'
    }

    It "Checks for package.json creation" {
        $script:Content | Should -Match 'package\.json'
    }

    It "Checks for node_modules directory" {
        $script:Content | Should -Match 'node_modules'
    }

    It "Validates Metro bundler configuration" {
        $script:Content | Should -Match 'scripts\.start'
    }

    It "Checks Android project structure" {
        $script:Content | Should -Match 'android'
    }

    It "Checks iOS project structure for macOS" {
        $script:Content | Should -Match 'ios'
    }

    It "Validates Gradle wrapper for Android" {
        $script:Content | Should -Match 'gradlew'
    }

    It "Validates Podfile for iOS" {
        $script:Content | Should -Match 'Podfile'
    }

    It "Checks platform detection for macOS" {
        $script:Content | Should -Match 'Darwin|IsMacOS'
    }

    It "Uses --skip-install flag for faster project creation" {
        $script:Content | Should -Match '--skip-install'
    }

    It "Validates Node.js version comparison" {
        $script:Content | Should -Match '\[version\]'
    }
}

Describe "verify-reactnative.ps1 - Dependency References" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Documents dependency on Node.js (Issue #9)" {
        $script:Content | Should -Match 'Issue.*#9|Issue.*9'
    }

    It "Documents dependency on Android SDK (Issue #25)" {
        $script:Content | Should -Match 'Issue.*#25|Issue.*25'
    }

    It "Mentions dependencies in help documentation" {
        $script:Content | Should -Match '\.NOTES[\s\S]*Dependencies'
    }
}
