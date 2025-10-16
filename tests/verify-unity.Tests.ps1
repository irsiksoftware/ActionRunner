#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-unity.ps1'
}

Describe "verify-unity.ps1 - Script Validation" {
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

Describe "verify-unity.ps1 - Parameter Validation" {
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

    It "MinimumVersion has default value of 2021.3.0f1" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '2021.3.0f1'
    }
}

Describe "verify-unity.ps1 - Function Definitions" {
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

Describe "verify-unity.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains Unity Hub check" {
        $script:Content | Should -Match 'Unity Hub'
    }

    It "Contains Unity Editor check" {
        $script:Content | Should -Match 'Unity\.exe|Unity\.app'
    }

    It "Contains Unity version check" {
        $script:Content | Should -Match 'version'
    }

    It "Contains Unity license check" {
        $script:Content | Should -Match 'Unity_lic\.ulf'
    }

    It "Contains Android build support check" {
        $script:Content | Should -Match 'AndroidPlayer'
    }

    It "Contains iOS build support check" {
        $script:Content | Should -Match 'iOSSupport'
    }

    It "Contains project structure creation" {
        $script:Content | Should -Match 'Assets'
        $script:Content | Should -Match 'ProjectSettings'
    }

    It "Contains Unity C# script creation" {
        $script:Content | Should -Match 'MonoBehaviour'
        $script:Content | Should -Match '\.cs'
    }

    It "Contains ProjectVersion.txt creation" {
        $script:Content | Should -Match 'ProjectVersion\.txt'
    }

    It "Contains ProjectSettings.asset creation" {
        $script:Content | Should -Match 'ProjectSettings\.asset'
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

    It "Checks Windows Unity paths" {
        $script:Content | Should -Match 'C:\\Program Files\\Unity'
    }

    It "Checks macOS Unity paths" {
        $script:Content | Should -Match '/Applications/Unity'
    }

    It "Handles cross-platform checks" {
        $script:Content | Should -Match '\$IsWindows|\$env:OS'
    }
}

Describe "verify-unity.ps1 - Execution Tests" {
    Context "When Unity is not available" {
        BeforeAll {
            # Mock Unity by temporarily renaming PATH
            $script:OriginalPath = $env:PATH
            $env:PATH = ""
        }

        AfterAll {
            $env:PATH = $script:OriginalPath
        }

        It "Should handle missing Unity gracefully" {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }
    }

    Context "When Unity is available" {
        BeforeAll {
            # Check if Unity is available
            $script:UnityAvailable = $null -ne (Get-Command "Unity.exe" -ErrorAction SilentlyContinue) -or
                                     $null -ne (Get-Item "C:\Program Files\Unity\Hub\Editor\*\Editor\Unity.exe" -ErrorAction SilentlyContinue) -or
                                     $null -ne (Get-Command "unity" -ErrorAction SilentlyContinue)
        }

        It "Should execute without errors when Unity is available" -Skip:(-not $script:UnityAvailable) {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" -Skip:(-not $script:UnityAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" -Skip:(-not $script:UnityAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" -Skip:(-not $script:UnityAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include passed/failed/warnings counts in JSON output" -Skip:(-not $script:UnityAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.passed | Should -BeOfType [int]
            $json.failed | Should -BeOfType [int]
            $json.warnings | Should -BeOfType [int]
        }

        It "Should perform Unity Hub installation check" -Skip:(-not $script:UnityAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $hubCheck = $json.checks | Where-Object { $_.name -eq 'Unity Hub Installation' }
            $hubCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Unity Editor installation check" -Skip:(-not $script:UnityAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $editorCheck = $json.checks | Where-Object { $_.name -eq 'Unity Editor Installation' }
            $editorCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Unity version check" -Skip:(-not $script:UnityAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $versionCheck = $json.checks | Where-Object { $_.name -eq 'Unity Version Check' }
            $versionCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Unity license check" -Skip:(-not $script:UnityAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $licenseCheck = $json.checks | Where-Object { $_.name -eq 'Unity License Status' }
            $licenseCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Android build support check" -Skip:(-not $script:UnityAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $androidCheck = $json.checks | Where-Object { $_.name -eq 'Android Build Support' }
            $androidCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform iOS build support check" -Skip:(-not $script:UnityAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $iosCheck = $json.checks | Where-Object { $_.name -eq 'iOS Build Support' }
            $iosCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Unity project structure creation test" -Skip:(-not $script:UnityAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $projectCheck = $json.checks | Where-Object { $_.name -eq 'Unity Project Structure Creation' }
            $projectCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Unity build script validation test" -Skip:(-not $script:UnityAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $scriptCheck = $json.checks | Where-Object { $_.name -eq 'Unity Build Script Validation' }
            $scriptCheck | Should -Not -BeNullOrEmpty
        }

        It "Should accept MinimumVersion parameter" -Skip:(-not $script:UnityAvailable) {
            { & $script:ScriptPath -MinimumVersion "2021.3.0f1" -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should exit with code 1 when -ExitOnFailure is used and checks fail" {
            # Force a failure by requiring a very high version
            $result = & $script:ScriptPath -MinimumVersion "9999.0.0f1" -ExitOnFailure -JsonOutput 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Output Formatting" {
        It "Should display checkmarks for passed tests (non-JSON mode)" -Skip:(-not $script:UnityAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match '✅|✓|PASS'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:UnityAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }
    }
}

Describe "verify-unity.ps1 - Security and Best Practices" {
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

Describe "verify-unity.ps1 - Unity Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Creates Unity project structure for testing" {
        $script:Content | Should -Match 'Assets'
        $script:Content | Should -Match 'ProjectSettings'
    }

    It "Creates Unity project version file" {
        $script:Content | Should -Match 'ProjectVersion\.txt'
        $script:Content | Should -Match 'm_EditorVersion'
    }

    It "Creates Unity project settings file" {
        $script:Content | Should -Match 'ProjectSettings\.asset'
        $script:Content | Should -Match 'PlayerSettings'
    }

    It "Creates Unity C# script" {
        $script:Content | Should -Match '\.cs'
        $script:Content | Should -Match 'MonoBehaviour'
    }

    It "Checks for Unity Hub executable" {
        $script:Content | Should -Match 'Unity Hub\.exe|unity-hub'
    }

    It "Checks for Unity Editor executable" {
        $script:Content | Should -Match 'Unity\.exe|Unity\.app'
    }

    It "Validates Unity project structure" {
        $script:Content | Should -Match 'Test-Path.*Assets'
        $script:Content | Should -Match 'Test-Path.*ProjectSettings'
    }

    It "Checks for mobile build targets" {
        $script:Content | Should -Match 'AndroidPlayer'
        $script:Content | Should -Match 'iOSSupport'
    }

    It "Validates Unity script syntax" {
        $script:Content | Should -Match 'void Start'
        $script:Content | Should -Match 'Debug\.Log'
    }

    It "Checks Unity license file location" {
        $script:Content | Should -Match 'Unity_lic\.ulf'
    }

    It "Supports both Windows and macOS paths" {
        $script:Content | Should -Match 'C:\\Program Files\\Unity'
        $script:Content | Should -Match '/Applications/Unity'
    }
}
