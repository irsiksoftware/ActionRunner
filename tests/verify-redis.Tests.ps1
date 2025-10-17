#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-redis.ps1'
}

Describe "verify-redis.ps1 - Script Validation" {
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

Describe "verify-redis.ps1 - Parameter Validation" {
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

    It "Has SkipConnectionTest switch parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'SkipConnectionTest' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'SwitchParameter'
    }

    It "Has MinimumPythonVersion string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumPythonVersion' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "MinimumPythonVersion has default value of 3.8" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumPythonVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '3.8'
    }

    It "Has MinimumRedisVersion string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumRedisVersion' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "MinimumRedisVersion has default value of 4.0.0" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumRedisVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '4.0.0'
    }

    It "Has RedisHost string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'RedisHost' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "RedisHost has default value of localhost" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'RedisHost' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be 'localhost'
    }

    It "Has RedisPort integer parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'RedisPort' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'Int32'
    }

    It "RedisPort has default value of 6379" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'RedisPort' }
        $defaultValue = $param.DefaultValue.Extent.Text
        $defaultValue | Should -Be '6379'
    }

    It "Has Database integer parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'Database' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'Int32'
    }

    It "Database has default value of 0" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'Database' }
        $defaultValue = $param.DefaultValue.Extent.Text
        $defaultValue | Should -Be '0'
    }

    It "Has Password string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'Password' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }
}

Describe "verify-redis.ps1 - Function Definitions" {
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

Describe "verify-redis.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains Python version check" {
        $script:Content | Should -Match 'python --version'
    }

    It "Contains pip check" {
        $script:Content | Should -Match 'python -m pip --version'
    }

    It "Contains redis import check" {
        $script:Content | Should -Match 'import redis'
    }

    It "Contains redis version check" {
        $script:Content | Should -Match 'redis\.__version__'
    }

    It "Contains Redis client import check" {
        $script:Content | Should -Match 'from redis import Redis'
    }

    It "Contains Redis client instantiation" {
        $script:Content | Should -Match 'Redis\('
    }

    It "Contains ping test" {
        $script:Content | Should -Match 'client\.ping\(\)'
    }

    It "Contains server info check" {
        $script:Content | Should -Match "client\.info\('server'\)"
    }

    It "Contains Docker availability check" {
        $script:Content | Should -Match 'docker --version'
    }

    It "Contains Redis container check" {
        $script:Content | Should -Match 'docker ps'
    }

    It "Contains Pipeline support check" {
        $script:Content | Should -Match 'pipeline\(\)'
    }

    It "Contains ConnectionPool support check" {
        $script:Content | Should -Match 'from redis import ConnectionPool'
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

Describe "verify-redis.ps1 - Execution Tests" {
    Context "When Python is not available" {
        BeforeAll {
            $script:OriginalPath = $env:PATH
            $env:PATH = ""
        }

        AfterAll {
            $env:PATH = $script:OriginalPath
        }

        It "Should handle missing Python gracefully" {
            { & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 } | Should -Not -Throw
        }
    }

    Context "When Python is available" {
        BeforeAll {
            $script:PythonAvailable = $null -ne (Get-Command python -ErrorAction SilentlyContinue)
        }

        It "Should execute without errors when python is available" -Skip:(-not $script:PythonAvailable) {
            { & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include passed/failed/warnings counts in JSON output" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.passed | Should -BeOfType [int]
            $json.failed | Should -BeOfType [int]
            $json.warnings | Should -BeOfType [int]
        }

        It "Should perform Python interpreter check" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $pythonCheck = $json.checks | Where-Object { $_.name -eq 'Python Interpreter' }
            $pythonCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform pip package manager check" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $pipCheck = $json.checks | Where-Object { $_.name -eq 'pip Package Manager' }
            $pipCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform redis package check" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $redisCheck = $json.checks | Where-Object { $_.name -eq 'redis Package' }
            $redisCheck | Should -Not -BeNullOrEmpty
        }

        It "Should accept MinimumPythonVersion parameter" -Skip:(-not $script:PythonAvailable) {
            { & $script:ScriptPath -MinimumPythonVersion "3.8" -SkipConnectionTest -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should accept MinimumRedisVersion parameter" -Skip:(-not $script:PythonAvailable) {
            { & $script:ScriptPath -MinimumRedisVersion "4.0.0" -SkipConnectionTest -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should accept RedisHost parameter" -Skip:(-not $script:PythonAvailable) {
            { & $script:ScriptPath -RedisHost "localhost" -SkipConnectionTest -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should accept RedisPort parameter" -Skip:(-not $script:PythonAvailable) {
            { & $script:ScriptPath -RedisPort 6379 -SkipConnectionTest -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should accept Database parameter" -Skip:(-not $script:PythonAvailable) {
            { & $script:ScriptPath -Database 0 -SkipConnectionTest -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should accept Password parameter" -Skip:(-not $script:PythonAvailable) {
            { & $script:ScriptPath -Password "testpass" -SkipConnectionTest -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should accept SkipConnectionTest parameter" -Skip:(-not $script:PythonAvailable) {
            { & $script:ScriptPath -SkipConnectionTest -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should exit with code 1 when -ExitOnFailure is used and checks fail" {
            $result = & $script:ScriptPath -MinimumPythonVersion "99.0" -ExitOnFailure -SkipConnectionTest -JsonOutput 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Output Formatting" {
        BeforeAll {
            $script:PythonAvailable = $null -ne (Get-Command python -ErrorAction SilentlyContinue)
        }

        It "Should display checkmarks for passed tests (non-JSON mode)" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -SkipConnectionTest 2>&1 | Out-String
            $output | Should -Match '✅|✓|PASS'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -SkipConnectionTest 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }
    }
}

Describe "verify-redis.ps1 - Security and Best Practices" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Uses ErrorActionPreference" {
        $script:Content | Should -Match '\$ErrorActionPreference\s*='
    }

    It "Uses CmdletBinding attribute" {
        $script:Content | Should -Match '\[CmdletBinding\(\)\]'
    }

    It "Cleans up temporary test directories" {
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

Describe "verify-redis.ps1 - Redis Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Creates a Python test file for testing" {
        $script:Content | Should -Match 'test_redis\.py'
    }

    It "Tests Redis class" {
        $script:Content | Should -Match 'Redis\('
    }

    It "Checks for Redis import" {
        $script:Content | Should -Match 'from redis import Redis'
    }

    It "Checks for Docker availability" {
        $script:Content | Should -Match 'docker --version'
    }

    It "Checks for Redis container" {
        $script:Content | Should -Match 'ancestor=redis'
    }

    It "Checks for Pipeline class" {
        $script:Content | Should -Match 'pipeline\(\)'
    }

    It "Checks for ConnectionPool class" {
        $script:Content | Should -Match 'from redis import ConnectionPool'
    }

    It "Tests connection with Redis client" {
        $script:Content | Should -Match 'Redis\('
    }

    It "Tests ping method" {
        $script:Content | Should -Match 'client\.ping\(\)'
    }

    It "Tests info method" {
        $script:Content | Should -Match "client\.info\('server'\)"
    }

    It "Tests client.close method" {
        $script:Content | Should -Match 'client\.close\(\)'
    }

    It "Includes skip connection test option" {
        $script:Content | Should -Match 'if \(-not \$SkipConnectionTest\)'
    }

    It "Includes authentication parameter" {
        $script:Content | Should -Match 'Password'
    }

    It "Uses socket_connect_timeout for timeout" {
        $script:Content | Should -Match 'socket_connect_timeout'
    }

    It "Uses decode_responses option" {
        $script:Content | Should -Match 'decode_responses'
    }

    It "Includes database parameter" {
        $script:Content | Should -Match 'db='
    }
}
