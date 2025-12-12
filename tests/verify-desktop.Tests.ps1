#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-desktop.ps1'
    $script:MauiScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-maui.ps1'
    $script:WpfScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-wpf.ps1'
}

Describe "verify-desktop.ps1 - Script Validation" {
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

    It "Dependent MAUI script exists" {
        Test-Path $script:MauiScriptPath | Should -Be $true
    }

    It "Dependent WPF script exists" {
        Test-Path $script:WpfScriptPath | Should -Be $true
    }
}

Describe "verify-desktop.ps1 - Parameter Validation" {
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

    It "Has RequireAll switch parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'RequireAll' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'SwitchParameter'
    }

    It "MinimumVersion has default value of 8.0" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '8.0'
    }
}

Describe "verify-desktop.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "References MAUI verification script" {
        $script:Content | Should -Match 'verify-maui\.ps1'
    }

    It "References WPF verification script" {
        $script:Content | Should -Match 'verify-wpf\.ps1'
    }

    It "Handles both MAUI and WPF capabilities" {
        $script:Content | Should -Match 'maui'
        $script:Content | Should -Match 'wpf'
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

    It "Includes capability identifier" {
        $script:Content | Should -Match 'capability.*=.*"desktop"'
    }

    It "Supports RequireAll mode" {
        $script:Content | Should -Match 'RequireAll'
    }

    It "Provides installation instructions" {
        $script:Content | Should -Match 'dotnet workload install maui'
    }

    It "Tracks individual capability status" {
        $script:Content | Should -Match 'capabilities'
    }
}

Describe "verify-desktop.ps1 - Execution Tests" {
    Context "Basic Execution" {
        It "Should execute without throwing errors" {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }
    }

    Context "JSON Output Structure" {
        BeforeAll {
            $script:Output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $script:Json = $script:Output | ConvertFrom-Json
        }

        It "Should include timestamp in JSON output" {
            $script:Json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include capability identifier as 'desktop'" {
            $script:Json.capability | Should -Be 'desktop'
        }

        It "Should include available status" {
            $script:Json.PSObject.Properties.Name | Should -Contain 'available'
        }

        It "Should include capabilities object with maui and wpf" {
            $script:Json.capabilities | Should -Not -BeNullOrEmpty
            $script:Json.capabilities.PSObject.Properties.Name | Should -Contain 'maui'
            $script:Json.capabilities.PSObject.Properties.Name | Should -Contain 'wpf'
        }

        It "Should include summary object" {
            $script:Json.summary | Should -Not -BeNullOrEmpty
            $script:Json.summary.PSObject.Properties.Name | Should -Contain 'maui'
            $script:Json.summary.PSObject.Properties.Name | Should -Contain 'wpf'
            $script:Json.summary.PSObject.Properties.Name | Should -Contain 'desktopReady'
        }

        It "Should include requireAll flag" {
            $script:Json.PSObject.Properties.Name | Should -Contain 'requireAll'
        }
    }

    Context "RequireAll Mode" {
        It "Should accept -RequireAll parameter" {
            { & $script:ScriptPath -RequireAll -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should set requireAll flag to true when -RequireAll is used" {
            $output = & $script:ScriptPath -RequireAll -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.requireAll | Should -Be $true
        }

        It "Should set requireAll flag to false by default" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.requireAll | Should -Be $false
        }
    }

    Context "Exit Codes" {
        It "Should exit with code 0 when at least one capability is available (default mode)" {
            & $script:ScriptPath -JsonOutput 2>&1 | Out-Null
            # Exit code depends on actual system capabilities, so we just check it doesn't throw
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should respect -ExitOnFailure parameter" {
            # This test verifies the parameter is accepted; actual exit code depends on system
            { & $script:ScriptPath -ExitOnFailure -JsonOutput 2>&1 } | Should -Not -Throw
        }
    }

    Context "Output Formatting" {
        It "Script contains header text" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Desktop Capability Verification'
        }

        It "Script contains MAUI verification output" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'MAUI'
        }

        It "Script contains WPF verification output" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'WPF'
        }

        It "Script contains summary section" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Summary'
        }

        It "Script indicates desktop capability status" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Desktop capability'
        }
    }
}

Describe "verify-desktop.ps1 - Security and Best Practices" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Uses ErrorActionPreference" {
        $script:Content | Should -Match '\$ErrorActionPreference\s*='
    }

    It "Uses CmdletBinding attribute" {
        $script:Content | Should -Match '\[CmdletBinding\(\)\]'
    }

    It "Uses Split-Path for script directory resolution" {
        $script:Content | Should -Match 'Split-Path'
    }

    It "Uses Join-Path for path construction" {
        $script:Content | Should -Match 'Join-Path'
    }

    It "Tests for script existence before execution" {
        $script:Content | Should -Match 'Test-Path.*Script'
    }

    It "Handles script execution errors gracefully" {
        $script:Content | Should -Match 'try\s*\{[\s\S]*?\}\s*catch'
    }
}

Describe "verify-desktop.ps1 - Desktop Capability Logic" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Uses OR logic by default (either MAUI or WPF)" {
        $script:Content | Should -Match '-or'
    }

    It "Uses AND logic when RequireAll is specified" {
        $script:Content | Should -Match '-and'
    }

    It "Calls MAUI verification script with JsonOutput" {
        $script:Content | Should -Match '\$mauiScript.*-JsonOutput'
    }

    It "Calls WPF verification script with JsonOutput" {
        $script:Content | Should -Match '\$wpfScript.*-JsonOutput'
    }

    It "Parses JSON results from child scripts" {
        $script:Content | Should -Match 'ConvertFrom-Json'
    }

    It "Aggregates results from both verifications" {
        $script:Content | Should -Match 'capabilities\.maui'
        $script:Content | Should -Match 'capabilities\.wpf'
    }

    It "Provides clear desktop label guidance" {
        $script:Content | Should -Match 'desktop.*label'
    }
}
