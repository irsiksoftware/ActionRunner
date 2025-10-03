#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-jesus-environment.ps1'
}

Describe "verify-jesus-environment.ps1 - Script Validation" {
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

Describe "verify-jesus-environment.ps1 - Parameter Validation" {
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

Describe "verify-jesus-environment.ps1 - Function Definitions" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
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

Describe "verify-jesus-environment.ps1 - Dependency Checks" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Checks for Node.js 20.x" {
        $script:ScriptContent | Should -Match 'Node\.js 20\.x'
        $script:ScriptContent | Should -Match 'node --version'
    }

    It "Checks for pnpm 9.x" {
        $script:ScriptContent | Should -Match 'pnpm 9\.x'
        $script:ScriptContent | Should -Match 'pnpm --version'
    }

    It "Checks for Python 3.11" {
        $script:ScriptContent | Should -Match 'Python 3\.11'
        $script:ScriptContent | Should -Match 'python --version'
    }

    It "Checks for pip" {
        $script:ScriptContent | Should -Match 'pip --version'
    }

    It "Checks for Docker" {
        $script:ScriptContent | Should -Match 'docker --version'
        $script:ScriptContent | Should -Match 'docker ps'
    }

    It "Checks for Docker Buildx" {
        $script:ScriptContent | Should -Match 'docker buildx version'
    }

    It "Checks for pip-audit" {
        $script:ScriptContent | Should -Match 'pip-audit --version'
    }

    It "Checks for detect-secrets" {
        $script:ScriptContent | Should -Match 'detect-secrets --version'
    }

    It "Checks for OSV Scanner" {
        $script:ScriptContent | Should -Match 'osv-scanner'
    }

    It "Checks for curl" {
        $script:ScriptContent | Should -Match 'curl --version'
    }

    It "Checks disk space" {
        $script:ScriptContent | Should -Match 'Disk Space'
        $script:ScriptContent | Should -Match '100GB'
    }
}

Describe "verify-jesus-environment.ps1 - Results Collection" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Initializes results hashtable" {
        $script:ScriptContent | Should -Match '\$results = @\{'
    }

    It "Tracks timestamp" {
        $script:ScriptContent | Should -Match 'timestamp.*Get-Date'
    }

    It "Tracks passed count" {
        $script:ScriptContent | Should -Match 'passed = 0'
    }

    It "Tracks failed count" {
        $script:ScriptContent | Should -Match 'failed = 0'
    }

    It "Tracks warnings count" {
        $script:ScriptContent | Should -Match 'warnings = 0'
    }

    It "Collects check results" {
        $script:ScriptContent | Should -Match 'checks = @\(\)'
    }
}

Describe "verify-jesus-environment.ps1 - Output Formats" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Supports JSON output" {
        $script:ScriptContent | Should -Match 'if \(\$JsonOutput\)'
        $script:ScriptContent | Should -Match 'ConvertTo-Json'
    }

    It "Has colored console output" {
        $script:ScriptContent | Should -Match 'Write-Host.*-ForegroundColor Green'
        $script:ScriptContent | Should -Match 'Write-Host.*-ForegroundColor Red'
        $script:ScriptContent | Should -Match 'Write-Host.*-ForegroundColor Yellow'
    }

    It "Uses checkmark emojis for success" {
        $script:ScriptContent | Should -Match '✅'
    }

    It "Uses cross mark emojis for errors" {
        $script:ScriptContent | Should -Match '❌'
    }

    It "Uses warning emojis for warnings" {
        $script:ScriptContent | Should -Match '⚠️'
    }
}

Describe "verify-jesus-environment.ps1 - Exit Behavior" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Exits with code 1 on failure when ExitOnFailure is set" {
        $script:ScriptContent | Should -Match 'if \(\$ExitOnFailure -and \$results\.failed -gt 0\)'
        $script:ScriptContent | Should -Match 'exit 1'
    }

    It "Exits with code 0 on success" {
        $script:ScriptContent | Should -Match 'exit 0'
    }
}

Describe "verify-jesus-environment.ps1 - Error Handling" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Sets ErrorActionPreference to Continue" {
        $script:ScriptContent | Should -Match '\$ErrorActionPreference\s*=\s*[''"]Continue[''"]'
    }

    It "Has try-catch blocks for checks" {
        $script:ScriptContent | Should -Match 'try\s*\{[\s\S]*\}\s*catch'
    }

    It "Uses ErrorAction SilentlyContinue for command checks" {
        $script:ScriptContent | Should -Match 'Get-Command.*-ErrorAction SilentlyContinue'
    }
}

Describe "verify-jesus-environment.ps1 - User Guidance" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Provides installation URLs for missing dependencies" {
        $script:ScriptContent | Should -Match 'https://nodejs\.org'
        $script:ScriptContent | Should -Match 'https://www\.python\.org'
        $script:ScriptContent | Should -Match 'https://docker\.com'
    }

    It "Suggests pip install commands" {
        $script:ScriptContent | Should -Match 'pip install pip-audit'
        $script:ScriptContent | Should -Match 'pip install detect-secrets'
    }

    It "Suggests npm install command for pnpm" {
        $script:ScriptContent | Should -Match 'npm install -g pnpm@9'
    }

    It "References setup-jesus-runner.ps1 script" {
        $script:ScriptContent | Should -Match 'setup-jesus-runner\.ps1'
    }
}

Describe "verify-jesus-environment.ps1 - Summary Display" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Displays verification summary header" {
        $script:ScriptContent | Should -Match 'Verification Summary'
    }

    It "Shows passed count" {
        $script:ScriptContent | Should -Match 'Passed:.*\$results\.passed'
    }

    It "Shows warnings count" {
        $script:ScriptContent | Should -Match 'Warnings:.*\$results\.warnings'
    }

    It "Shows failed count" {
        $script:ScriptContent | Should -Match 'Failed:.*\$results\.failed'
    }

    It "Displays overall success message" {
        $script:ScriptContent | Should -Match 'Environment is ready for Jesus project'
    }

    It "Displays overall failure message" {
        $script:ScriptContent | Should -Match 'Environment verification failed'
    }
}

Describe "verify-jesus-environment.ps1 - Version Matching" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Matches Node.js v20.x pattern" {
        $script:ScriptContent | Should -Match '\^v20\\\.'
    }

    It "Matches pnpm 9.x pattern" {
        $script:ScriptContent | Should -Match '\^9\\\.'
    }

    It "Matches Python 3.11 pattern" {
        $script:ScriptContent | Should -Match '3\\\.11\\\.'
    }
}

Describe "verify-jesus-environment.ps1 - Severity Levels" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Supports Error severity" {
        $script:ScriptContent | Should -Match 'Severity = [''"]Error[''"]'
    }

    It "Supports Warning severity" {
        $script:ScriptContent | Should -Match 'Severity = [''"]Warning[''"]'
    }

    It "Handles severity in result processing" {
        $script:ScriptContent | Should -Match 'if \(\$Severity -eq [''"]Error[''"]'
    }

    It "Increments warnings counter for Warning severity" {
        $script:ScriptContent | Should -Match '\$script:results\.warnings\+\+'
    }

    It "Increments failed counter for Error severity" {
        $script:ScriptContent | Should -Match '\$script:results\.failed\+\+'
    }
}

Describe "verify-jesus-environment.ps1 - Check Results Structure" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Stores check name in results" {
        $script:ScriptContent | Should -Match 'name = \$Name'
    }

    It "Stores expected value in results" {
        $script:ScriptContent | Should -Match 'expected = \$Expected'
    }

    It "Stores actual value in results" {
        $script:ScriptContent | Should -Match 'actual = \$result\.Value'
    }

    It "Stores passed status in results" {
        $script:ScriptContent | Should -Match 'passed = \$result\.Passed'
    }

    It "Stores message in results" {
        $script:ScriptContent | Should -Match 'message = '
    }

    It "Stores severity in results" {
        $script:ScriptContent | Should -Match 'severity = '
    }
}

Describe "verify-jesus-environment.ps1 - Documentation Quality" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Has author information" {
        $script:ScriptContent | Should -Match '\.NOTES'
        $script:ScriptContent | Should -Match 'Author:'
    }

    It "Has version information" {
        $script:ScriptContent | Should -Match 'Version:'
    }

    It "Documents issue number" {
        $script:ScriptContent | Should -Match 'Issue #30'
    }

    It "Provides multiple usage examples" {
        $script:ScriptContent | Should -Match '\.EXAMPLE'
    }

    It "Documents ExitOnFailure parameter" {
        $script:ScriptContent | Should -Match '\.PARAMETER ExitOnFailure'
    }

    It "Documents JsonOutput parameter" {
        $script:ScriptContent | Should -Match '\.PARAMETER JsonOutput'
    }
}

Describe "verify-jesus-environment.ps1 - Disk Space Check" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Gets current drive location" {
        $script:ScriptContent | Should -Match 'Get-Location.*Drive'
    }

    It "Calculates free space in GB" {
        $script:ScriptContent | Should -Match 'Free.*1GB'
    }

    It "Checks for minimum 100GB" {
        $script:ScriptContent | Should -Match 'freeGB -ge 100'
    }

    It "Formats disk space in results" {
        $script:ScriptContent | Should -Match 'GB free'
    }
}

Describe "verify-jesus-environment.ps1 - Python Command Variants" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Checks multiple Python command variants" {
        $script:ScriptContent | Should -Match 'pythonCmds = @\('
    }

    It "Tries 'python' command" {
        $script:ScriptContent | Should -Match '[''"]python[''"]'
    }

    It "Tries 'python3' command" {
        $script:ScriptContent | Should -Match '[''"]python3[''"]'
    }

    It "Tries 'python3.11' command" {
        $script:ScriptContent | Should -Match '[''"]python3\.11[''"]'
    }
}

Describe "verify-jesus-environment.ps1 - Docker Daemon Check" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Tests Docker daemon is running" {
        $script:ScriptContent | Should -Match 'docker ps'
    }

    It "Checks LASTEXITCODE for Docker command" {
        $script:ScriptContent | Should -Match '\$LASTEXITCODE -eq 0'
    }

    It "Differentiates between installed and running" {
        $script:ScriptContent | Should -Match 'Installed but not running'
    }
}

Describe "verify-jesus-environment.ps1 - Optional Dependencies" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Marks OSV Scanner as optional" {
        $script:ScriptContent | Should -Match 'OSV Scanner.*optional'
    }

    It "Allows warnings for optional components" {
        $script:ScriptContent | Should -Match 'Some optional components are missing'
    }
}

Describe "verify-jesus-environment.ps1 - Integration Tests" -Tag 'Integration' {
    It "Runs without errors" {
        $output = & powershell -File $script:ScriptPath -ErrorAction SilentlyContinue
        $LASTEXITCODE | Should -BeIn @(0, 1)
    }

    It "Accepts ExitOnFailure parameter" {
        $output = & powershell -File $script:ScriptPath -ExitOnFailure -ErrorAction SilentlyContinue
        $LASTEXITCODE | Should -BeIn @(0, 1)
    }

    It "Accepts JsonOutput parameter" {
        $output = & powershell -File $script:ScriptPath -JsonOutput
        $LASTEXITCODE | Should -Be 0
    }

    It "Produces valid JSON when JsonOutput is specified" {
        $output = & powershell -File $script:ScriptPath -JsonOutput
        { $output | ConvertFrom-Json } | Should -Not -Throw
    }

    It "JSON output contains required fields" {
        $output = & powershell -File $script:ScriptPath -JsonOutput
        $json = $output | ConvertFrom-Json

        $json.timestamp | Should -Not -BeNullOrEmpty
        $json.checks | Should -Not -BeNullOrEmpty
        $json.PSObject.Properties.Name | Should -Contain 'passed'
        $json.PSObject.Properties.Name | Should -Contain 'failed'
        $json.PSObject.Properties.Name | Should -Contain 'warnings'
    }
}
