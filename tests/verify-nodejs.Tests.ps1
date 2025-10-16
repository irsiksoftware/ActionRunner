#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-nodejs.ps1'
}

Describe "verify-nodejs.ps1 - Script Validation" {
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

Describe "verify-nodejs.ps1 - Parameter Validation" {
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

    It "Has MinimumPnpmVersion string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumPnpmVersion' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "MinimumNodeVersion has default value of 16.0" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumNodeVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '16.0'
    }

    It "MinimumPnpmVersion has default value of 8.0" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumPnpmVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '8.0'
    }
}

Describe "verify-nodejs.ps1 - Function Definitions" {
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

Describe "verify-nodejs.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains Node.js version check" {
        $script:Content | Should -Match 'node --version'
    }

    It "Contains npm availability check" {
        $script:Content | Should -Match 'npm --version'
    }

    It "Contains pnpm availability check" {
        $script:Content | Should -Match 'pnpm --version'
    }

    It "Contains pnpm store path check" {
        $script:Content | Should -Match 'pnpm store path'
    }

    It "Contains pnpm init test" {
        $script:Content | Should -Match 'pnpm init'
    }

    It "Contains pnpm install test" {
        $script:Content | Should -Match 'pnpm install'
    }

    It "Contains pnpm list test" {
        $script:Content | Should -Match 'pnpm list'
    }

    It "Contains pnpm run scripts test" {
        $script:Content | Should -Match 'pnpm run'
    }

    It "Contains pnpm workspace support check" {
        $script:Content | Should -Match 'pnpm-workspace\.yaml'
    }

    It "Contains Node.js execution test" {
        $script:Content | Should -Match 'node -e'
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

Describe "verify-nodejs.ps1 - Execution Tests" {
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
            $script:PnpmAvailable = $null -ne (Get-Command pnpm -ErrorAction SilentlyContinue)
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

        It "Should perform pnpm command availability check" -Skip:(-not $script:NodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $pnpmCheck = $json.checks | Where-Object { $_.name -eq 'pnpm Command Available' }
            $pnpmCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform pnpm version check" -Skip:(-not $script:PnpmAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $pnpmVersionCheck = $json.checks | Where-Object { $_.name -eq 'pnpm Version' }
            $pnpmVersionCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Node.js execution test" -Skip:(-not $script:NodeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $execCheck = $json.checks | Where-Object { $_.name -eq 'Node.js Execution' }
            $execCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform pnpm store path check" -Skip:(-not $script:PnpmAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $storeCheck = $json.checks | Where-Object { $_.name -eq 'pnpm Store Path' }
            $storeCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform pnpm init capability check" -Skip:(-not $script:PnpmAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $initCheck = $json.checks | Where-Object { $_.name -eq 'pnpm Init Capability' }
            $initCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform pnpm install capability check" -Skip:(-not $script:PnpmAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $installCheck = $json.checks | Where-Object { $_.name -eq 'pnpm Install Capability' }
            $installCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform pnpm list packages check" -Skip:(-not $script:PnpmAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $listCheck = $json.checks | Where-Object { $_.name -eq 'pnpm List Packages' }
            $listCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform pnpm run scripts check" -Skip:(-not $script:PnpmAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $runCheck = $json.checks | Where-Object { $_.name -eq 'pnpm Run Scripts' }
            $runCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform pnpm workspace support check" -Skip:(-not $script:PnpmAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $workspaceCheck = $json.checks | Where-Object { $_.name -eq 'pnpm Workspace Support' }
            $workspaceCheck | Should -Not -BeNullOrEmpty
        }

        It "Should accept MinimumNodeVersion parameter" -Skip:(-not $script:NodeAvailable) {
            { & $script:ScriptPath -MinimumNodeVersion "16.0" -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should accept MinimumPnpmVersion parameter" -Skip:(-not $script:PnpmAvailable) {
            { & $script:ScriptPath -MinimumPnpmVersion "8.0" -JsonOutput 2>&1 } | Should -Not -Throw
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

Describe "verify-nodejs.ps1 - Security and Best Practices" {
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

Describe "verify-nodejs.ps1 - Node.js/pnpm Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Tests package.json creation" {
        $script:Content | Should -Match 'package\.json'
    }

    It "Tests pnpm project initialization" {
        $script:Content | Should -Match 'pnpm init'
    }

    It "Tests package installation capability" {
        $script:Content | Should -Match 'pnpm install'
    }

    It "Tests script execution capability" {
        $script:Content | Should -Match 'pnpm run'
    }

    It "Tests workspace configuration" {
        $script:Content | Should -Match 'pnpm-workspace\.yaml'
    }

    It "Validates Node.js version comparison" {
        $script:Content | Should -Match '\[version\]'
    }

    It "Tests pnpm store functionality" {
        $script:Content | Should -Match 'pnpm store'
    }

    It "Includes lodash as test dependency" {
        $script:Content | Should -Match 'lodash'
    }
}
