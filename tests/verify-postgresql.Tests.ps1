#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-postgresql.ps1'
}

Describe "verify-postgresql.ps1 - Script Validation" {
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

Describe "verify-postgresql.ps1 - Parameter Validation" {
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

    It "MinimumVersion has default value of 12.0" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '12.0'
    }

    It "Has Host string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'Host' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "Host has default value of localhost" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'Host' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be 'localhost'
    }

    It "Has Port integer parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'Port' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'Int32'
    }

    It "Port has default value of 5432" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'Port' }
        $defaultValue = $param.DefaultValue.Extent.Text
        $defaultValue | Should -Be '5432'
    }

    It "Has Database string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'Database' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "Database has default value of postgres" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'Database' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be 'postgres'
    }

    It "Has Username string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'Username' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "Has Password string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'Password' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "Has SkipConnectionTest switch parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'SkipConnectionTest' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'SwitchParameter'
    }
}

Describe "verify-postgresql.ps1 - Function Definitions" {
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

Describe "verify-postgresql.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains psql version check" {
        $script:Content | Should -Match 'psql --version'
    }

    It "Contains pg_isready check" {
        $script:Content | Should -Match 'pg_isready'
    }

    It "Contains PostgreSQL server status check" {
        $script:Content | Should -Match 'pg_isready -h'
    }

    It "Contains environment variable checks" {
        $script:Content | Should -Match 'PGHOST'
        $script:Content | Should -Match 'PGPORT'
        $script:Content | Should -Match 'PGUSER'
        $script:Content | Should -Match 'PGDATABASE'
    }

    It "Contains Docker container check" {
        $script:Content | Should -Match 'docker ps'
    }

    It "Contains connection test with psql" {
        $script:Content | Should -Match 'psql -h'
    }

    It "Contains version query" {
        $script:Content | Should -Match 'SELECT version\(\)'
    }

    It "Contains SQL operations tests" {
        $script:Content | Should -Match 'CREATE TEMP TABLE'
        $script:Content | Should -Match 'INSERT INTO'
        $script:Content | Should -Match 'SELECT COUNT'
    }

    It "Contains extensions query" {
        $script:Content | Should -Match 'pg_available_extensions'
    }

    It "Contains pg_dump check" {
        $script:Content | Should -Match 'pg_dump'
    }

    It "Uses password environment variable" {
        $script:Content | Should -Match 'PGPASSWORD'
    }

    It "Clears password from environment" {
        $script:Content | Should -Match 'Remove-Item Env:PGPASSWORD'
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

Describe "verify-postgresql.ps1 - Execution Tests" {
    Context "When PostgreSQL is not available" {
        BeforeAll {
            $script:OriginalPath = $env:PATH
            $env:PATH = ""
        }

        AfterAll {
            $env:PATH = $script:OriginalPath
        }

        It "Should handle missing PostgreSQL gracefully" {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }
    }

    Context "When PostgreSQL client is available" {
        BeforeAll {
            $script:PsqlAvailable = $null -ne (Get-Command psql -ErrorAction SilentlyContinue)
        }

        It "Should execute without errors when psql is available" -Skip:(-not $script:PsqlAvailable) {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" -Skip:(-not $script:PsqlAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" -Skip:(-not $script:PsqlAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" -Skip:(-not $script:PsqlAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include passed/failed/warnings counts in JSON output" -Skip:(-not $script:PsqlAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.passed | Should -BeOfType [int]
            $json.failed | Should -BeOfType [int]
            $json.warnings | Should -BeOfType [int]
        }

        It "Should perform psql client check" -Skip:(-not $script:PsqlAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $psqlCheck = $json.checks | Where-Object { $_.name -eq 'PostgreSQL Client (psql)' }
            $psqlCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform pg_isready utility check" -Skip:(-not $script:PsqlAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $pgIsReadyCheck = $json.checks | Where-Object { $_.name -eq 'pg_isready Utility' }
            $pgIsReadyCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform server status check" -Skip:(-not $script:PsqlAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $serverCheck = $json.checks | Where-Object { $_.name -eq 'PostgreSQL Server Status' }
            $serverCheck | Should -Not -BeNullOrEmpty
        }

        It "Should accept MinimumVersion parameter" -Skip:(-not $script:PsqlAvailable) {
            { & $script:ScriptPath -MinimumVersion "12.0" -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should accept Host parameter" -Skip:(-not $script:PsqlAvailable) {
            { & $script:ScriptPath -Host "localhost" -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should accept Port parameter" -Skip:(-not $script:PsqlAvailable) {
            { & $script:ScriptPath -Port 5432 -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should accept Database parameter" -Skip:(-not $script:PsqlAvailable) {
            { & $script:ScriptPath -Database "postgres" -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should accept Username and Password parameters" -Skip:(-not $script:PsqlAvailable) {
            { & $script:ScriptPath -Username "test" -Password "test" -SkipConnectionTest -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should accept SkipConnectionTest parameter" -Skip:(-not $script:PsqlAvailable) {
            { & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should exit with code 1 when -ExitOnFailure is used and checks fail" {
            $result = & $script:ScriptPath -MinimumVersion "999.0" -ExitOnFailure -JsonOutput 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Output Formatting" {
        BeforeAll {
            $script:PsqlAvailable = $null -ne (Get-Command psql -ErrorAction SilentlyContinue)
        }

        It "Should display checkmarks for passed tests (non-JSON mode)" -Skip:(-not $script:PsqlAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match '✅|✓|PASS'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:PsqlAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }
    }
}

Describe "verify-postgresql.ps1 - Security and Best Practices" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Uses ErrorActionPreference" {
        $script:Content | Should -Match '\$ErrorActionPreference\s*='
    }

    It "Uses CmdletBinding attribute" {
        $script:Content | Should -Match '\[CmdletBinding\(\)\]'
    }

    It "Clears password environment variable after use" {
        $script:Content | Should -Match 'Remove-Item Env:PGPASSWORD.*ErrorAction SilentlyContinue'
    }

    It "Uses try-finally for password cleanup" {
        $script:Content | Should -Match 'try\s*\{[\s\S]*?\}\s*finally\s*\{'
    }

    It "Uses ErrorAction SilentlyContinue for cleanup" {
        $script:Content | Should -Match 'ErrorAction\s+SilentlyContinue'
    }
}

Describe "verify-postgresql.ps1 - PostgreSQL Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Checks psql client version" {
        $script:Content | Should -Match 'psql --version'
    }

    It "Checks pg_isready utility" {
        $script:Content | Should -Match 'Get-Command pg_isready'
    }

    It "Tests server connectivity with pg_isready" {
        $script:Content | Should -Match 'pg_isready -h \$Host -p \$Port'
    }

    It "Tests database connection with credentials" {
        $script:Content | Should -Match 'psql -h \$Host -p \$Port -U \$Username -d \$Database'
    }

    It "Executes version query" {
        $script:Content | Should -Match 'SELECT version\(\)'
    }

    It "Tests CREATE TABLE operation" {
        $script:Content | Should -Match 'CREATE TEMP TABLE'
    }

    It "Tests INSERT operation" {
        $script:Content | Should -Match 'INSERT INTO'
    }

    It "Tests SELECT operation" {
        $script:Content | Should -Match 'SELECT COUNT\(\*\)'
    }

    It "Queries available extensions" {
        $script:Content | Should -Match 'pg_available_extensions'
    }

    It "Checks pg_dump utility" {
        $script:Content | Should -Match 'Get-Command pg_dump'
    }

    It "Uses random table names to avoid conflicts" {
        $script:Content | Should -Match 'Get-Random'
    }

    It "Uses temporary tables" {
        $script:Content | Should -Match 'CREATE TEMP TABLE'
    }
}
