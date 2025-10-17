#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-aspnetcore.ps1'
}

Describe "verify-aspnetcore.ps1 - Script Validation" {
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

Describe "verify-aspnetcore.ps1 - Parameter Validation" {
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

Describe "verify-aspnetcore.ps1 - Function Definitions" {
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

Describe "verify-aspnetcore.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains .NET SDK version check" {
        $script:Content | Should -Match 'dotnet --version'
    }

    It "Contains .NET runtime list check" {
        $script:Content | Should -Match 'dotnet --list-runtimes'
    }

    It "Contains ASP.NET Core runtime check" {
        $script:Content | Should -Match 'Microsoft\.AspNetCore\.App'
    }

    It "Contains .NET SDK list check" {
        $script:Content | Should -Match 'dotnet --list-sdks'
    }

    It "Contains dotnet CLI functionality check" {
        $script:Content | Should -Match 'dotnet --info'
    }

    It "Contains webapi project creation test" {
        $script:Content | Should -Match 'dotnet new webapi'
    }

    It "Contains project build test" {
        $script:Content | Should -Match 'dotnet build'
    }

    It "Contains NuGet restore test" {
        $script:Content | Should -Match 'dotnet restore'
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

    It "Uses --no-https flag for test projects" {
        $script:Content | Should -Match '--no-https'
    }

    It "Checks for .csproj file creation" {
        $script:Content | Should -Match '\.csproj'
    }
}

Describe "verify-aspnetcore.ps1 - Execution Tests" {
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
            # Check if dotnet is available
            $script:DotnetAvailable = $null -ne (Get-Command dotnet -ErrorAction SilentlyContinue)
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

        It "Should include passed/failed/warnings counts in JSON output" -Skip:(-not $script:DotnetAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.passed | Should -BeOfType [int]
            $json.failed | Should -BeOfType [int]
            $json.warnings | Should -BeOfType [int]
        }

        It "Should perform .NET SDK version check" -Skip:(-not $script:DotnetAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $sdkCheck = $json.checks | Where-Object { $_.name -eq '.NET SDK' }
            $sdkCheck | Should -Not -BeNullOrEmpty
        }

        It "Should check for ASP.NET Core runtime" -Skip:(-not $script:DotnetAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $runtimeCheck = $json.checks | Where-Object { $_.name -eq 'ASP.NET Core Runtime' }
            $runtimeCheck | Should -Not -BeNullOrEmpty
        }

        It "Should verify dotnet CLI functionality" -Skip:(-not $script:DotnetAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $cliCheck = $json.checks | Where-Object { $_.name -eq 'dotnet CLI' }
            $cliCheck | Should -Not -BeNullOrEmpty
        }

        It "Should verify ASP.NET Core SDK workload" -Skip:(-not $script:DotnetAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $workloadCheck = $json.checks | Where-Object { $_.name -eq 'ASP.NET Core SDK Workload' }
            $workloadCheck | Should -Not -BeNullOrEmpty
        }

        It "Should test web project creation" -Skip:(-not $script:DotnetAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $createCheck = $json.checks | Where-Object { $_.name -eq 'Web Project Creation' }
            $createCheck | Should -Not -BeNullOrEmpty
        }

        It "Should test web project build" -Skip:(-not $script:DotnetAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $buildCheck = $json.checks | Where-Object { $_.name -eq 'Web Project Build' }
            $buildCheck | Should -Not -BeNullOrEmpty
        }

        It "Should test NuGet package restore" -Skip:(-not $script:DotnetAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $restoreCheck = $json.checks | Where-Object { $_.name -eq 'NuGet Package Restore' }
            $restoreCheck | Should -Not -BeNullOrEmpty
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
            $output | Should -Match '✅|✓|PASS'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:DotnetAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }
    }
}

Describe "verify-aspnetcore.ps1 - Security and Best Practices" {
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

Describe "verify-aspnetcore.ps1 - ASP.NET Core Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Tests webapi template" {
        $script:Content | Should -Match 'webapi'
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

    It "Checks .NET CLI info output" {
        $script:Content | Should -Match 'dotnet --info'
    }

    It "Validates SDK version comparison" {
        $script:Content | Should -Match 'System\.Version'
    }

    It "Uses --configuration Release for builds" {
        $script:Content | Should -Match '--configuration Release'
    }

    It "Verifies ASP.NET Core runtime specifically" {
        $script:Content | Should -Match 'Microsoft\.AspNetCore\.App'
    }
}
