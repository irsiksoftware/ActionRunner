#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-mobile.ps1'
}

Describe "verify-mobile.ps1 - Script Validation" {
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

    It "Script references Issue #157" {
        $content = Get-Content $script:ScriptPath -Raw
        $content | Should -Match 'Issue #157'
    }
}

Describe "verify-mobile.ps1 - Parameter Validation" {
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

    It "Has RequireAll switch parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'RequireAll' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'SwitchParameter'
    }
}

Describe "verify-mobile.ps1 - Function Definitions" {
    BeforeAll {
        $script:ScriptContent = Get-Content $script:ScriptPath -Raw
    }

    It "Defines Test-Capability function" {
        $script:ScriptContent | Should -Match 'function Test-Capability'
    }

    It "Test-Capability function has Name parameter" {
        $script:ScriptContent | Should -Match '\[string\]\$Name'
    }

    It "Test-Capability function has Framework parameter" {
        $script:ScriptContent | Should -Match '\[string\]\$Framework'
    }

    It "Test-Capability function has Check parameter as scriptblock" {
        $script:ScriptContent | Should -Match '\[scriptblock\]\$Check'
    }

    It "Defines Write-ColorOutput function" {
        $script:ScriptContent | Should -Match 'function Write-ColorOutput'
    }
}

Describe "verify-mobile.ps1 - Android Detection" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Checks ANDROID_HOME environment variable" {
        $script:Content | Should -Match '\$env:ANDROID_HOME'
    }

    It "Checks Android build-tools" {
        $script:Content | Should -Match 'build-tools'
    }

    It "Checks for adb (platform-tools)" {
        $script:Content | Should -Match 'adb'
    }

    It "Has Android framework identifier" {
        $script:Content | Should -Match '-Framework "Android"'
    }
}

Describe "verify-mobile.ps1 - iOS Detection" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Checks for macOS platform" {
        $script:Content | Should -Match 'Darwin'
    }

    It "Checks for Xcode installation" {
        $script:Content | Should -Match 'xcodebuild'
    }

    It "Checks for iOS SDK" {
        $script:Content | Should -Match 'iphoneos'
    }

    It "Checks for CocoaPods" {
        $script:Content | Should -Match 'pod'
    }

    It "Has iOS framework identifier" {
        $script:Content | Should -Match '-Framework "iOS"'
    }
}

Describe "verify-mobile.ps1 - Flutter Detection" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Checks for Flutter command" {
        $script:Content | Should -Match 'flutter --version'
    }

    It "Checks for Dart SDK" {
        $script:Content | Should -Match 'dart --version'
    }

    It "Has Flutter framework identifier" {
        $script:Content | Should -Match '-Framework "Flutter"'
    }
}

Describe "verify-mobile.ps1 - React Native Detection" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Checks for Node.js" {
        $script:Content | Should -Match 'node --version'
    }

    It "Checks for npm" {
        $script:Content | Should -Match 'npm --version'
    }

    It "Checks for React Native CLI" {
        $script:Content | Should -Match 'react-native'
    }

    It "Checks npx availability for React Native" {
        $script:Content | Should -Match 'npx react-native'
    }

    It "Has ReactNative framework identifier" {
        $script:Content | Should -Match '-Framework "ReactNative"'
    }
}

Describe "verify-mobile.ps1 - Mobile Label Logic" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Tracks mobile capabilities array" {
        $script:Content | Should -Match 'mobileCapabilities\s*=\s*@\(\)'
    }

    It "Tracks recommended labels array" {
        $script:Content | Should -Match 'recommendedLabels\s*=\s*@\(\)'
    }

    It "Determines 'mobile' label qualification" {
        $script:Content | Should -Match 'qualifiesForMobile'
    }

    It "Adds 'mobile' to recommended labels when qualified" {
        $script:Content | Should -Match "recommendedLabels \+= .mobile."
    }

    It "Adds framework-specific labels" {
        $script:Content | Should -Match "recommendedLabels \+= .android."
        $script:Content | Should -Match "recommendedLabels \+= .flutter."
        $script:Content | Should -Match "recommendedLabels \+= .react-native."
    }

    It "Supports RequireAll mode" {
        $script:Content | Should -Match '\$RequireAll'
    }
}

Describe "verify-mobile.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
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

    It "Includes timestamp in results" {
        $script:Content | Should -Match 'timestamp'
    }

    It "Tracks passed/failed counts" {
        $script:Content | Should -Match 'passed\s*=\s*0'
        $script:Content | Should -Match 'failed\s*=\s*0'
    }
}

Describe "verify-mobile.ps1 - Execution Tests" {
    Context "Script execution" {
        It "Should execute without throwing errors" {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include mobileCapabilities in JSON output" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            # mobileCapabilities exists (can be empty array or have items)
            $json.PSObject.Properties.Name | Should -Contain 'mobileCapabilities'
        }

        It "Should include recommendedLabels in JSON output" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            # recommendedLabels exists (can be empty array or have items)
            $json.PSObject.Properties.Name | Should -Contain 'recommendedLabels'
        }

        It "Should include qualifiesForMobile boolean in JSON output" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.qualifiesForMobile | Should -BeIn @($true, $false)
        }

        It "Should include passed/failed/warnings counts" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            # JSON converts integers to [long] in PowerShell, so check for numeric type
            $json.passed | Should -BeOfType [System.ValueType]
            $json.failed | Should -BeOfType [System.ValueType]
            $json.warnings | Should -BeOfType [System.ValueType]
        }
    }

    Context "Android capability detection" {
        BeforeAll {
            $script:AndroidAvailable = ($null -ne $env:ANDROID_HOME) -and (Test-Path $env:ANDROID_HOME -ErrorAction SilentlyContinue)
        }

        It "Should detect Android capability when ANDROID_HOME is set" -Skip:(-not $script:AndroidAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.mobileCapabilities | Should -Contain "Android"
        }

        It "Should recommend 'android' label when Android is detected" -Skip:(-not $script:AndroidAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.recommendedLabels | Should -Contain "android"
        }
    }

    Context "Flutter capability detection" {
        BeforeAll {
            $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
            $script:FlutterAvailable = $null -ne $flutterCmd
        }

        It "Should detect Flutter capability when Flutter is installed" -Skip:(-not $script:FlutterAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.mobileCapabilities | Should -Contain "Flutter"
        }

        It "Should recommend 'flutter' label when Flutter is detected" -Skip:(-not $script:FlutterAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.recommendedLabels | Should -Contain "flutter"
        }
    }

    Context "React Native capability detection" {
        BeforeAll {
            $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
            $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
            $script:ReactNativeAvailable = ($null -ne $nodeCmd) -and ($null -ne $npmCmd)
        }

        It "Should detect React Native capability when Node.js and npm are installed" -Skip:(-not $script:ReactNativeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.mobileCapabilities | Should -Contain "ReactNative"
        }

        It "Should recommend 'react-native' label when React Native is detected" -Skip:(-not $script:ReactNativeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.recommendedLabels | Should -Contain "react-native"
        }
    }

    Context "Mobile label qualification" {
        It "Should qualify for 'mobile' label if any capability is detected" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json

            if ($json.mobileCapabilities.Count -gt 0) {
                $json.qualifiesForMobile | Should -Be $true
                $json.recommendedLabels | Should -Contain "mobile"
            }
        }

        It "Should not qualify for 'mobile' label if no capability is detected" {
            # Save and clear environment
            $originalAndroidHome = $env:ANDROID_HOME
            $originalPath = $env:PATH

            $env:ANDROID_HOME = $null
            $env:PATH = ""

            try {
                $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
                $json = $output | ConvertFrom-Json
                $json.qualifiesForMobile | Should -Be $false
            }
            finally {
                $env:ANDROID_HOME = $originalAndroidHome
                $env:PATH = $originalPath
            }
        }
    }

    Context "Output formatting (non-JSON mode)" {
        It "Should display section headers" {
            # Capture all output streams
            $output = & $script:ScriptPath *>&1 | Out-String
            $output | Should -Match 'Mobile Development Capability Detection'
        }

        It "Should display capability summary" {
            $output = & $script:ScriptPath *>&1 | Out-String
            $output | Should -Match 'Mobile Capability Summary'
        }

        It "Should display label eligibility" {
            $output = & $script:ScriptPath *>&1 | Out-String
            $output | Should -Match "mobile.*Label Eligibility"
        }
    }
}

Describe "verify-mobile.ps1 - Security and Best Practices" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Uses ErrorActionPreference" {
        $script:Content | Should -Match '\$ErrorActionPreference\s*='
    }

    It "Uses CmdletBinding attribute" {
        $script:Content | Should -Match '\[CmdletBinding\(\)\]'
    }

    It "Uses SilentlyContinue for optional command checks" {
        $script:Content | Should -Match 'ErrorAction\s+SilentlyContinue'
    }

    It "Has try-catch blocks for error handling" {
        $script:Content | Should -Match 'try\s*\{'
        $script:Content | Should -Match 'catch\s*\{'
    }
}

Describe "verify-mobile.ps1 - Framework Coverage" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Covers Android SDK detection" {
        $script:Content | Should -Match 'ANDROID SDK DETECTION'
    }

    It "Covers iOS/Xcode detection" {
        $script:Content | Should -Match 'iOS/XCODE DETECTION'
    }

    It "Covers Flutter SDK detection" {
        $script:Content | Should -Match 'FLUTTER SDK DETECTION'
    }

    It "Covers React Native detection" {
        $script:Content | Should -Match 'REACT NATIVE DETECTION'
    }

    It "Has mobile label eligibility section" {
        $script:Content | Should -Match 'DETERMINE MOBILE LABEL ELIGIBILITY'
    }
}
