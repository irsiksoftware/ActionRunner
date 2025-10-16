#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-ios-build.ps1'
}

Describe "verify-ios-build.ps1 - Script Validation" {
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

Describe "verify-ios-build.ps1 - Parameter Validation" {
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
}

Describe "verify-ios-build.ps1 - Function Definitions" {
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

Describe "verify-ios-build.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains macOS platform check" {
        $script:Content | Should -Match 'IsMacOS|Darwin'
    }

    It "Contains Xcode availability check" {
        $script:Content | Should -Match 'xcodebuild -version'
    }

    It "Contains Xcode version check" {
        $script:Content | Should -Match 'Xcode 14\.0'
    }

    It "Contains iOS SDK check" {
        $script:Content | Should -Match 'xcodebuild -showsdks'
    }

    It "Contains CocoaPods check" {
        $script:Content | Should -Match 'pod --version'
    }

    It "Contains Simulator check" {
        $script:Content | Should -Match 'xcrun simctl list'
    }

    It "Contains Command Line Tools check" {
        $script:Content | Should -Match 'xcode-select -p'
    }

    It "Uses proper error handling" {
        $script:Content | Should -Match '\$ErrorActionPreference'
    }

    It "Has JSON output support" {
        $script:Content | Should -Match 'ConvertTo-Json'
    }

    It "Has proper exit code handling" {
        $script:Content | Should -Match 'exit 1'
        $script:Content | Should -Match 'exit 0'
    }
}

Describe "verify-ios-build.ps1 - Execution Tests" {
    Context "When not on macOS" {
        BeforeAll {
            $script:IsOnMacOS = ($PSVersionTable.PSVersion.Major -ge 6) -and ($PSVersionTable.OS -match 'Darwin')
        }

        It "Should report platform mismatch on non-macOS systems" -Skip:($script:IsOnMacOS) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.failed | Should -BeGreaterThan 0
        }

        It "Should handle missing tools gracefully on non-macOS" -Skip:($script:IsOnMacOS) {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }
    }

    Context "When on macOS" {
        BeforeAll {
            $script:IsOnMacOS = ($PSVersionTable.PSVersion.Major -ge 6) -and ($PSVersionTable.OS -match 'Darwin')
            if ($script:IsOnMacOS) {
                $script:XcodeAvailable = $null -ne (Get-Command xcodebuild -ErrorAction SilentlyContinue)
            } else {
                $script:XcodeAvailable = $false
            }
        }

        It "Should execute without errors when on macOS" -Skip:(-not $script:IsOnMacOS) {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" -Skip:(-not $script:IsOnMacOS) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" -Skip:(-not $script:IsOnMacOS) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" -Skip:(-not $script:IsOnMacOS) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include passed/failed/warnings counts in JSON output" -Skip:(-not $script:IsOnMacOS) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.passed | Should -BeOfType [int]
            $json.failed | Should -BeOfType [int]
            $json.warnings | Should -BeOfType [int]
        }

        It "Should perform Xcode command check" -Skip:(-not $script:IsOnMacOS) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $xcodeCheck = $json.checks | Where-Object { $_.name -eq 'Xcode Command' }
            $xcodeCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Xcode version check" -Skip:(-not $script:XcodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $versionCheck = $json.checks | Where-Object { $_.name -eq 'Xcode Version' }
            $versionCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform iOS SDK check" -Skip:(-not $script:XcodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $sdkCheck = $json.checks | Where-Object { $_.name -eq 'iOS SDK' }
            $sdkCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Command Line Tools check" -Skip:(-not $script:XcodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $cltCheck = $json.checks | Where-Object { $_.name -eq 'Command Line Tools' }
            $cltCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform CocoaPods check" -Skip:(-not $script:XcodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $podCheck = $json.checks | Where-Object { $_.name -eq 'CocoaPods' }
            $podCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Simulator check" -Skip:(-not $script:XcodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $simCheck = $json.checks | Where-Object { $_.name -eq 'iOS Simulator' }
            $simCheck | Should -Not -BeNullOrEmpty
        }
    }

    Context "Output Formatting" {
        BeforeAll {
            $script:IsOnMacOS = ($PSVersionTable.PSVersion.Major -ge 6) -and ($PSVersionTable.OS -match 'Darwin')
            if ($script:IsOnMacOS) {
                $script:XcodeAvailable = $null -ne (Get-Command xcodebuild -ErrorAction SilentlyContinue)
            } else {
                $script:XcodeAvailable = $false
            }
        }

        It "Should display checkmarks for passed tests (non-JSON mode)" -Skip:(-not $script:XcodeAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match '✅|✓|PASS'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:XcodeAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }

        It "Should show passed count in summary" -Skip:(-not $script:XcodeAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Passed:'
        }

        It "Should show failed count in summary" -Skip:(-not $script:XcodeAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Failed:'
        }

        It "Should show warnings count in summary" -Skip:(-not $script:XcodeAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Warnings:'
        }
    }
}

Describe "verify-ios-build.ps1 - Security and Best Practices" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Uses ErrorActionPreference" {
        $script:Content | Should -Match '\$ErrorActionPreference\s*='
    }

    It "Uses CmdletBinding attribute" {
        $script:Content | Should -Match '\[CmdletBinding\(\)\]'
    }
}

Describe "verify-ios-build.ps1 - iOS Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Validates Xcode installation" {
        $script:Content | Should -Match 'xcodebuild command is available'
    }

    It "Validates iOS SDK availability" {
        $script:Content | Should -Match 'iOS SDK is available'
    }

    It "Validates Command Line Tools installation" {
        $script:Content | Should -Match 'Command Line Tools are installed'
    }

    It "Checks for CocoaPods dependency manager" {
        $script:Content | Should -Match 'CocoaPods is available'
    }

    It "Validates iOS Simulator availability" {
        $script:Content | Should -Match 'iOS Simulator is available'
    }

    It "Has minimum Xcode version requirement" {
        $script:Content | Should -Match '14\.0'
    }
}

Describe "verify-ios-build.ps1 - Error Handling" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Handles non-macOS platform" {
        $script:Content | Should -Match 'macOS platform required|Darwin|IsMacOS'
    }

    It "Handles Xcode not found" {
        $script:Content | Should -Match 'Xcode not found|xcodebuild'
    }

    It "Handles missing iOS SDK" {
        $script:Content | Should -Match 'iOS SDK|iphoneos'
    }

    It "Handles missing Command Line Tools" {
        $script:Content | Should -Match 'Command Line Tools|xcode-select'
    }

    It "Uses try-catch blocks" {
        $script:Content | Should -Match 'try\s*\{[\s\S]*?\}\s*catch\s*\{'
    }

    It "Handles LASTEXITCODE checks" {
        $script:Content | Should -Match '\$LASTEXITCODE'
    }
}
