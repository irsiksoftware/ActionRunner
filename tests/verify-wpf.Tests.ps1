#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-wpf.ps1'
}

Describe "verify-wpf.ps1 - Script Validation" {
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

Describe "verify-wpf.ps1 - Parameter Validation" {
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

Describe "verify-wpf.ps1 - Function Definitions" {
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

Describe "verify-wpf.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains Windows OS check" {
        $script:Content | Should -Match 'Windows'
    }

    It "Contains .NET SDK installation check" {
        $script:Content | Should -Match 'dotnet'
    }

    It "Contains Windows Desktop SDK check" {
        $script:Content | Should -Match 'Windows Desktop SDK'
    }

    It "Contains WPF template check" {
        $script:Content | Should -Match 'wpf'
    }

    It "Contains .NET Framework check" {
        $script:Content | Should -Match '\.NET Framework'
    }

    It "Contains Visual Studio check" {
        $script:Content | Should -Match 'Visual Studio'
    }

    It "Contains MSBuild check" {
        $script:Content | Should -Match 'MSBuild'
    }

    It "Contains WPF project creation test" {
        $script:Content | Should -Match 'dotnet new wpf'
    }

    It "Contains project restore test" {
        $script:Content | Should -Match 'dotnet restore'
    }

    It "Contains project build test" {
        $script:Content | Should -Match 'dotnet build'
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

    It "Includes capability identifier" {
        $script:Content | Should -Match 'capability.*=.*"wpf"'
    }
}

Describe "verify-wpf.ps1 - Execution Tests" {
    Context "When .NET SDK is not available" {
        BeforeAll {
            # Mock dotnet command by temporarily renaming PATH
            $script:OriginalPath = $env:PATH
            $env:PATH = ""
        }

        AfterAll {
            $env:PATH = $script:OriginalPath
        }

        It "Should handle missing .NET SDK gracefully" {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }
    }

    Context "When .NET SDK is available" {
        BeforeAll {
            # Check if dotnet is available and on Windows
            $script:DotnetAvailable = $null -ne (Get-Command dotnet -ErrorAction SilentlyContinue)
            $script:OnWindows = $IsWindows -or ($env:OS -match 'Windows')
        }

        It "Should execute without errors when dotnet is available" -Skip:(-not $script:DotnetAvailable) {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" -Skip:(-not $script:DotnetAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" -Skip:(-not $script:DotnetAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" -Skip:(-not $script:DotnetAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include capability identifier in JSON output" -Skip:(-not $script:DotnetAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.capability | Should -Be 'wpf'
        }

        It "Should include summary in JSON output" -Skip:(-not $script:DotnetAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.summary | Should -Not -BeNullOrEmpty
            $json.summary.total | Should -BeOfType [int]
            $json.summary.passed | Should -BeOfType [int]
            $json.summary.failed | Should -BeOfType [int]
        }

        It "Should accept MinimumVersion parameter" -Skip:(-not $script:DotnetAvailable) {
            { & $script:ScriptPath -MinimumVersion "6.0" -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should exit with code 1 when -ExitOnFailure is used and checks fail" {
            # Force a failure by requiring a very high version
            $result = & $script:ScriptPath -MinimumVersion "99.0" -ExitOnFailure -JsonOutput 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Output Formatting" {
        BeforeAll {
            $script:DotnetAvailable = $null -ne (Get-Command dotnet -ErrorAction SilentlyContinue)
        }

        It "Should display checkmarks for passed tests (non-JSON mode)" -Skip:(-not $script:DotnetAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match '✅|✓|PASS|passed'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:DotnetAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }
    }
}

Describe "verify-wpf.ps1 - Security and Best Practices" {
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

Describe "verify-wpf.ps1 - WPF Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Tests Windows OS requirement" {
        $script:Content | Should -Match 'Windows'
    }

    It "Tests WPF project template" {
        $script:Content | Should -Match 'dotnet new wpf'
    }

    It "Tests project restore capability" {
        $script:Content | Should -Match 'dotnet restore'
    }

    It "Tests project build capability" {
        $script:Content | Should -Match 'dotnet build'
    }

    It "Validates .csproj file creation" {
        $script:Content | Should -Match '\.csproj'
    }

    It "Checks for MSBuild availability" {
        $script:Content | Should -Match 'msbuild'
    }

    It "Checks for .NET Framework 4.x" {
        $script:Content | Should -Match 'v4\.0'
    }

    It "Validates SDK version comparison" {
        $script:Content | Should -Match 'System\.Version'
    }

    It "Uses vswhere for Visual Studio detection" {
        $script:Content | Should -Match 'vswhere'
    }
}
