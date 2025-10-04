#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-docker.ps1'
}

Describe "verify-docker.ps1 - Script Validation" {
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

Describe "verify-docker.ps1 - Parameter Validation" {
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

    It "Has SkipDockerBuild switch parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'SkipDockerBuild' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'SwitchParameter'
    }
}

Describe "verify-docker.ps1 - Function Definitions" {
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

Describe "verify-docker.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains Docker command availability check" {
        $script:Content | Should -Match 'Get-Command docker'
    }

    It "Contains Docker daemon running check" {
        $script:Content | Should -Match 'docker version'
    }

    It "Contains Docker version check" {
        $script:Content | Should -Match 'Docker version 20\.10\.0'
    }

    It "Contains Docker info check" {
        $script:Content | Should -Match 'docker info'
    }

    It "Contains image pull test" {
        $script:Content | Should -Match 'docker pull'
    }

    It "Contains container run test" {
        $script:Content | Should -Match 'docker run.*--rm'
    }

    It "Contains Docker build test" {
        $script:Content | Should -Match 'docker build'
    }

    It "Contains storage driver check" {
        $script:Content | Should -Match 'Storage Driver'
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

    It "Uses hello-world image for testing" {
        $script:Content | Should -Match 'hello-world'
    }

    It "Cleans up test images" {
        $script:Content | Should -Match 'docker rmi'
    }
}

Describe "verify-docker.ps1 - Execution Tests" {
    Context "When Docker is not available" {
        BeforeAll {
            # Mock docker command by temporarily clearing PATH
            $script:OriginalPath = $env:PATH
            $env:PATH = ""
        }

        AfterAll {
            $env:PATH = $script:OriginalPath
        }

        It "Should handle missing Docker gracefully" {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should report Docker as not available" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.failed | Should -BeGreaterThan 0
        }
    }

    Context "When Docker is available" {
        BeforeAll {
            # Check if docker is available and daemon is running
            $script:DockerAvailable = $null -ne (Get-Command docker -ErrorAction SilentlyContinue)
            if ($script:DockerAvailable) {
                $null = docker version 2>&1
                $script:DockerRunning = $LASTEXITCODE -eq 0
            } else {
                $script:DockerRunning = $false
            }
        }

        It "Should execute without errors when docker is available" -Skip:(-not $script:DockerRunning) {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" -Skip:(-not $script:DockerRunning) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" -Skip:(-not $script:DockerRunning) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" -Skip:(-not $script:DockerRunning) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include passed/failed/warnings counts in JSON output" -Skip:(-not $script:DockerRunning) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.passed | Should -BeOfType [int]
            $json.failed | Should -BeOfType [int]
            $json.warnings | Should -BeOfType [int]
        }

        It "Should perform Docker command check" -Skip:(-not $script:DockerRunning) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $dockerCheck = $json.checks | Where-Object { $_.name -eq 'Docker Command' }
            $dockerCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Docker daemon check" -Skip:(-not $script:DockerRunning) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $daemonCheck = $json.checks | Where-Object { $_.name -eq 'Docker Daemon' }
            $daemonCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform Docker version check" -Skip:(-not $script:DockerRunning) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $versionCheck = $json.checks | Where-Object { $_.name -eq 'Docker Version' }
            $versionCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform image pull test" -Skip:(-not $script:DockerRunning) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $pullCheck = $json.checks | Where-Object { $_.name -eq 'Image Pull Test' }
            $pullCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform container run test" -Skip:(-not $script:DockerRunning) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $runCheck = $json.checks | Where-Object { $_.name -eq 'Container Run Test' }
            $runCheck | Should -Not -BeNullOrEmpty
        }

        It "Should skip Docker build when -SkipDockerBuild is used" -Skip:(-not $script:DockerRunning) {
            $output = & $script:ScriptPath -SkipDockerBuild -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $buildCheck = $json.checks | Where-Object { $_.name -eq 'Docker Build Test' }
            $buildCheck | Should -BeNullOrEmpty
        }

        It "Should perform storage driver check" -Skip:(-not $script:DockerRunning) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $storageCheck = $json.checks | Where-Object { $_.name -eq 'Storage Driver' }
            $storageCheck | Should -Not -BeNullOrEmpty
        }
    }

    Context "Output Formatting" {
        BeforeAll {
            $script:DockerAvailable = $null -ne (Get-Command docker -ErrorAction SilentlyContinue)
            if ($script:DockerAvailable) {
                $null = docker version 2>&1
                $script:DockerRunning = $LASTEXITCODE -eq 0
            } else {
                $script:DockerRunning = $false
            }
        }

        It "Should display checkmarks for passed tests (non-JSON mode)" -Skip:(-not $script:DockerRunning) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match '✅|✓|PASS'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:DockerRunning) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }

        It "Should show passed count in summary" -Skip:(-not $script:DockerRunning) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Passed:'
        }

        It "Should show failed count in summary" -Skip:(-not $script:DockerRunning) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Failed:'
        }

        It "Should show warnings count in summary" -Skip:(-not $script:DockerRunning) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Warnings:'
        }
    }
}

Describe "verify-docker.ps1 - Security and Best Practices" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Uses ErrorActionPreference" {
        $script:Content | Should -Match '\$ErrorActionPreference\s*='
    }

    It "Uses CmdletBinding attribute" {
        $script:Content | Should -Match '\[CmdletBinding\(\)\]'
    }

    It "Cleans up temporary directories" {
        $script:Content | Should -Match 'Remove-Item.*-Recurse.*-Force'
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

    It "Removes test Docker images after build test" {
        $script:Content | Should -Match 'docker rmi docker-verify-test'
    }

    It "Uses --rm flag for container cleanup" {
        $script:Content | Should -Match 'docker run --rm'
    }
}

Describe "verify-docker.ps1 - Docker Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Creates a minimal Dockerfile for testing" {
        $script:Content | Should -Match 'FROM alpine:latest'
    }

    It "Tests Docker build functionality" {
        $script:Content | Should -Match 'docker build -t'
    }

    It "Validates Docker daemon accessibility" {
        $script:Content | Should -Match 'Docker daemon is running and accessible'
    }

    It "Tests image registry connectivity" {
        $script:Content | Should -Match 'Docker can pull images from registry'
    }

    It "Tests container execution capability" {
        $script:Content | Should -Match 'Docker can create and run containers'
    }

    It "Checks storage driver configuration" {
        $script:Content | Should -Match 'Docker storage driver is configured'
    }

    It "Has minimum version requirement" {
        $script:Content | Should -Match '20\.10\.0'
    }
}

Describe "verify-docker.ps1 - Error Handling" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Handles Docker command not found" {
        $script:Content | Should -Match 'Docker command not found'
    }

    It "Handles Docker daemon not running" {
        $script:Content | Should -Match 'Docker daemon is not running'
    }

    It "Handles network/registry access issues" {
        $script:Content | Should -Match 'Check network and registry access'
    }

    It "Handles build failures" {
        $script:Content | Should -Match 'Cannot build Docker images'
    }

    It "Uses try-catch blocks" {
        $script:Content | Should -Match 'try\s*\{[\s\S]*?\}\s*catch\s*\{'
    }

    It "Handles LASTEXITCODE checks" {
        $script:Content | Should -Match '\$LASTEXITCODE'
    }
}
