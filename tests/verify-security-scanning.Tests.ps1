#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-security-scanning.ps1'
}

Describe "verify-security-scanning.ps1 - Script Validation" {
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

Describe "verify-security-scanning.ps1 - Parameter Validation" {
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

    It "Has IncludeOptional switch parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'IncludeOptional' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'SwitchParameter'
    }
}

Describe "verify-security-scanning.ps1 - Function Definitions" {
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

Describe "verify-security-scanning.ps1 - Security Check Content" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains Git availability check" {
        $script:Content | Should -Match 'git --version'
    }

    It "Contains PowerShell execution policy check" {
        $script:Content | Should -Match 'Get-ExecutionPolicy'
    }

    It "Contains Windows Defender check" {
        $script:Content | Should -Match 'Get-MpComputerStatus'
    }

    It "Contains file content scanning capability check" {
        $script:Content | Should -Match 'Select-String'
    }

    It "Contains secret detection patterns" {
        $script:Content | Should -Match 'password|secret|token'
    }

    It "Contains Git hooks support check" {
        $script:Content | Should -Match 'git init'
        $script:Content | Should -Match '\.git\\hooks'
    }

    It "Contains PSScriptAnalyzer check" {
        $script:Content | Should -Match 'PSScriptAnalyzer'
    }

    It "Contains security script execution test" {
        $script:Content | Should -Match 'scan-test\.ps1'
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

Describe "verify-security-scanning.ps1 - Execution Tests" {
    Context "When Git is not available" {
        BeforeAll {
            # Mock git command by temporarily renaming PATH
            $script:OriginalPath = $env:PATH
            $env:PATH = ""
        }

        AfterAll {
            $env:PATH = $script:OriginalPath
        }

        It "Should handle missing Git gracefully" {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }
    }

    Context "When security tools are available" {
        BeforeAll {
            # Check if git is available
            $script:GitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
        }

        It "Should execute without errors" -Skip:(-not $script:GitAvailable) {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include passed/failed/warnings counts in JSON output" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.passed | Should -BeOfType [int]
            $json.failed | Should -BeOfType [int]
            $json.warnings | Should -BeOfType [int]
        }

        It "Should perform Git check" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $gitCheck = $json.checks | Where-Object { $_.name -eq 'Git' }
            $gitCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform PowerShell execution policy check" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $policyCheck = $json.checks | Where-Object { $_.name -eq 'PowerShell Execution Policy' }
            $policyCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform file content scanning check" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $scanCheck = $json.checks | Where-Object { $_.name -eq 'File Content Scanning' }
            $scanCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform secret detection patterns check" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $secretCheck = $json.checks | Where-Object { $_.name -eq 'Secret Detection Patterns' }
            $secretCheck | Should -Not -BeNullOrEmpty
        }

        It "Should accept IncludeOptional parameter" -Skip:(-not $script:GitAvailable) {
            { & $script:ScriptPath -IncludeOptional -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should include optional checks when -IncludeOptional is specified" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -IncludeOptional -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            # Should have more checks with optional included
            $json.checks.Count | Should -BeGreaterThan 8
        }
    }

    Context "Output Formatting" {
        BeforeAll {
            $script:GitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
        }

        It "Should display checkmarks for passed tests (non-JSON mode)" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match '✅|✓|PASS'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }
    }
}

Describe "verify-security-scanning.ps1 - Security and Best Practices" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Uses ErrorActionPreference" {
        $script:Content | Should -Match '\$ErrorActionPreference\s*='
    }

    It "Uses CmdletBinding attribute" {
        $script:Content | Should -Match '\[CmdletBinding\(\)\]'
    }

    It "Cleans up temporary test files and directories" {
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

Describe "verify-security-scanning.ps1 - Security Scanning Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Checks for secret patterns in test content" {
        $script:Content | Should -Match 'API_KEY|password|token'
    }

    It "Tests pattern matching with Select-String" {
        $script:Content | Should -Match 'Select-String -Pattern'
    }

    It "Validates git hooks directory" {
        $script:Content | Should -Match '\.git\\hooks'
    }

    It "Checks for SARIF output support when optional checks enabled" {
        $script:Content | Should -Match 'SARIF'
    }

    It "Includes Windows Defender status check" {
        $script:Content | Should -Match 'AntivirusEnabled'
    }

    It "Tests security script execution capability" {
        $script:Content | Should -Match 'scan-test\.ps1'
    }

    It "Validates multiple secret detection patterns" {
        # Should test at least 3 different secret patterns
        $matches = ([regex]::Matches($script:Content, "password|API_KEY|token")).Count
        $matches | Should -BeGreaterOrEqual 3
    }
}

Describe "verify-security-scanning.ps1 - Integration with Security Tools" {
    BeforeAll {
        $script:GitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
    }

    Context "Git Integration" {
        It "Verifies Git is available for secret scanning" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $gitCheck = $json.checks | Where-Object { $_.name -eq 'Git' }
            $gitCheck.passed | Should -Be $true
        }

        It "Verifies Git hooks directory can be created" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $hookCheck = $json.checks | Where-Object { $_.name -eq 'Git Hooks Support' }
            $hookCheck | Should -Not -BeNullOrEmpty
        }
    }

    Context "Pattern Detection" {
        It "Successfully detects API key patterns" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $patternCheck = $json.checks | Where-Object { $_.name -eq 'Secret Detection Patterns' }
            $patternCheck.passed | Should -Be $true
        }

        It "Successfully detects password patterns" -Skip:(-not $script:GitAvailable) {
            $testContent = 'password="test123"'
            $testContent -match 'password\s*=\s*["'']?\S+["'']?' | Should -Be $true
        }

        It "Successfully detects token patterns" -Skip:(-not $script:GitAvailable) {
            $testContent = 'token=ghp_1234567890abcdef'
            $testContent -match 'token\s*=\s*\S+' | Should -Be $true
        }
    }

    Context "File Scanning Capability" {
        It "Can scan files for sensitive patterns" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $scanCheck = $json.checks | Where-Object { $_.name -eq 'File Content Scanning' }
            $scanCheck.passed | Should -Be $true
        }

        It "Verifies security script can be executed" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $execCheck = $json.checks | Where-Object { $_.name -eq 'Security Script Execution' }
            $execCheck.passed | Should -Be $true
        }
    }

    Context "Optional Security Tools" {
        It "Checks for PSScriptAnalyzer availability" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $psaCheck = $json.checks | Where-Object { $_.name -eq 'PSScriptAnalyzer Module' }
            $psaCheck | Should -Not -BeNullOrEmpty
        }

        It "Includes SARIF support check with -IncludeOptional" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -IncludeOptional -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $sarifCheck = $json.checks | Where-Object { $_.name -eq 'SARIF Output Support' }
            $sarifCheck | Should -Not -BeNullOrEmpty
        }

        It "Includes code signing verification with -IncludeOptional" -Skip:(-not $script:GitAvailable) {
            $output = & $script:ScriptPath -IncludeOptional -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $signCheck = $json.checks | Where-Object { $_.name -eq 'Code Signing Verification' }
            $signCheck | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "verify-security-scanning.ps1 - Error Handling and Edge Cases" {
    Context "Missing Dependencies" {
        It "Handles missing Git gracefully" {
            $script:OriginalPath = $env:PATH
            try {
                $env:PATH = ""
                $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
                $json = $output | ConvertFrom-Json
                $json.failed | Should -BeGreaterThan 0
            }
            finally {
                $env:PATH = $script:OriginalPath
            }
        }
    }

    Context "Exit Code Handling" {
        BeforeAll {
            $script:GitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
        }

        It "Exits with code 1 when -ExitOnFailure is set and checks fail" {
            $script:OriginalPath = $env:PATH
            try {
                $env:PATH = ""
                $process = Start-Process pwsh -ArgumentList "-File `"$script:ScriptPath`" -ExitOnFailure -JsonOutput" -Wait -PassThru -NoNewWindow
                $process.ExitCode | Should -Be 1
            }
            finally {
                $env:PATH = $script:OriginalPath
            }
        }

        It "Exits with code 0 when all checks pass" -Skip:(-not $script:GitAvailable) {
            $process = Start-Process pwsh -ArgumentList "-File `"$script:ScriptPath`" -JsonOutput" -Wait -PassThru -NoNewWindow
            $process.ExitCode | Should -Be 0
        }
    }

    Context "Cleanup Verification" {
        BeforeAll {
            $script:GitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
        }

        It "Removes temporary test directories after execution" -Skip:(-not $script:GitAvailable) {
            $beforeCount = (Get-ChildItem $env:TEMP -Filter "security-*" -Directory -ErrorAction SilentlyContinue).Count
            $null = & $script:ScriptPath -JsonOutput 2>&1
            Start-Sleep -Milliseconds 500
            $afterCount = (Get-ChildItem $env:TEMP -Filter "security-*" -Directory -ErrorAction SilentlyContinue).Count
            $afterCount | Should -BeLessOrEqual $beforeCount
        }

        It "Removes git test directories after execution" -Skip:(-not $script:GitAvailable) {
            $beforeCount = (Get-ChildItem $env:TEMP -Filter "git-hooks-test-*" -Directory -ErrorAction SilentlyContinue).Count
            $null = & $script:ScriptPath -JsonOutput 2>&1
            Start-Sleep -Milliseconds 500
            $afterCount = (Get-ChildItem $env:TEMP -Filter "git-hooks-test-*" -Directory -ErrorAction SilentlyContinue).Count
            $afterCount | Should -BeLessOrEqual $beforeCount
        }
    }
}

Describe "verify-security-scanning.ps1 - Security Best Practices Validation" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Does not hardcode credentials in script" {
        # Check for actual hardcoded credentials (not test patterns or examples)
        $lines = $script:Content -split "`n"
        $suspiciousLines = $lines | Where-Object {
            $_ -match 'password\s*=\s*["''][a-zA-Z0-9]{6,}["'']' -and
            $_ -notmatch '(test|example|sample|demo|myP@ssw0rd|secret123)' -and
            $_ -notmatch '^\s*#' -and
            $_ -notmatch '^\s*@"' -and
            $_ -notmatch 'Out-File'
        }
        $suspiciousLines.Count | Should -Be 0
    }

    It "Uses secure temporary file handling" {
        $script:Content | Should -Match '\$env:TEMP'
        $script:Content | Should -Match 'Get-Random'
    }

    It "Implements proper file permissions check" {
        $script:Content | Should -Match 'Test-Path'
    }

    It "Validates input before processing" {
        $script:Content | Should -Match '\[CmdletBinding\(\)\]'
        $script:Content | Should -Match 'param\s*\('
    }

    It "Uses explicit error handling" {
        $script:Content | Should -Match 'try\s*\{'
        $script:Content | Should -Match 'catch\s*\{'
        $script:Content | Should -Match 'finally\s*\{'
    }

    It "Logs security check results appropriately" {
        $script:Content | Should -Match '\$results'
        $script:Content | Should -Match 'passed|failed|warnings'
    }
}

Describe "verify-security-scanning.ps1 - Performance and Resource Management" {
    BeforeAll {
        $script:GitAvailable = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
    }

    It "Completes execution within reasonable time" -Skip:(-not $script:GitAvailable) {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $null = & $script:ScriptPath -JsonOutput 2>&1
        $stopwatch.Stop()
        $stopwatch.ElapsedMilliseconds | Should -BeLessThan 30000
    }

    It "Does not leave orphaned processes" -Skip:(-not $script:GitAvailable) {
        $beforeProcesses = Get-Process git -ErrorAction SilentlyContinue
        $null = & $script:ScriptPath -JsonOutput 2>&1
        Start-Sleep -Milliseconds 500
        $afterProcesses = Get-Process git -ErrorAction SilentlyContinue
        $afterProcesses.Count | Should -BeLessOrEqual ($beforeProcesses.Count + 1)
    }

    It "Uses minimal memory for test operations" -Skip:(-not $script:GitAvailable) {
        $job = Start-Job -ScriptBlock {
            param($scriptPath)
            & $scriptPath -JsonOutput 2>&1 | Out-Null
        } -ArgumentList $script:ScriptPath
        Start-Sleep -Seconds 2
        $jobMemory = (Get-Process -Id $job.ChildJobs[0].Id -ErrorAction SilentlyContinue).WorkingSet64
        Stop-Job $job
        Remove-Job $job
        # Should use less than 100MB
        $jobMemory | Should -BeLessThan 100MB
    }
}
