BeforeAll {
    . "$PSScriptRoot\..\scripts\common-error-handling.ps1"
}

Describe "Common Error Handling Module" {
    Context "Throw-ActionRunnerError" {
        It "Should throw ActionRunnerException with correct properties" {
            {
                Throw-ActionRunnerError -Message "Test error" -Category Configuration -Remedy "Fix config"
            } | Should -Throw -ExceptionType ([ActionRunnerException])
        }

        It "Should include message in exception" {
            try {
                Throw-ActionRunnerError -Message "Custom error message" -Category Network -Remedy "Check network"
            }
            catch {
                $_.Exception.Message | Should -Be "Custom error message"
            }
        }

        It "Should include category in exception" {
            try {
                Throw-ActionRunnerError -Message "Test" -Category Authentication -Remedy "Login again"
            }
            catch {
                $_.Exception.Category | Should -Be ([ErrorCategory]::Authentication)
            }
        }

        It "Should include remedy in exception" {
            try {
                Throw-ActionRunnerError -Message "Test" -Category Validation -Remedy "Validate input"
            }
            catch {
                $_.Exception.Remedy | Should -Be "Validate input"
            }
        }
    }

    Context "Assert-RequiredParameters" {
        It "Should not throw when all parameters have values" {
            {
                Assert-RequiredParameters @{
                    "Param1" = "value1"
                    "Param2" = "value2"
                }
            } | Should -Not -Throw
        }

        It "Should throw when parameter is null" {
            {
                Assert-RequiredParameters @{
                    "Param1" = $null
                }
            } | Should -Throw -ExceptionType ([ActionRunnerException])
        }

        It "Should throw when parameter is empty string" {
            {
                Assert-RequiredParameters @{
                    "Param1" = ""
                }
            } | Should -Throw -ExceptionType ([ActionRunnerException])
        }

        It "Should throw when parameter is whitespace" {
            {
                Assert-RequiredParameters @{
                    "Param1" = "   "
                }
            } | Should -Throw -ExceptionType ([ActionRunnerException])
        }
    }

    Context "Assert-PathExists" {
        It "Should not throw when path exists (Any)" {
            {
                Assert-PathExists -Path $PSScriptRoot -PathType Any
            } | Should -Not -Throw
        }

        It "Should not throw when directory exists" {
            {
                Assert-PathExists -Path $PSScriptRoot -PathType Directory
            } | Should -Not -Throw
        }

        It "Should not throw when file exists" {
            {
                Assert-PathExists -Path $PSCommandPath -PathType File
            } | Should -Not -Throw
        }

        It "Should throw when path does not exist" {
            {
                Assert-PathExists -Path "C:\NonExistentPath\Test" -PathType Any
            } | Should -Throw -ExceptionType ([ActionRunnerException])
        }

        It "Should throw when file expected but directory provided" {
            {
                Assert-PathExists -Path $PSScriptRoot -PathType File
            } | Should -Throw -ExceptionType ([ActionRunnerException])
        }

        It "Should throw when directory expected but file provided" {
            {
                Assert-PathExists -Path $PSCommandPath -PathType Directory
            } | Should -Throw -ExceptionType ([ActionRunnerException])
        }
    }

    Context "Assert-NetworkConnectivity" {
        It "Should not throw when connection succeeds" {
            {
                Assert-NetworkConnectivity -HostName "github.com" -Port 443
            } | Should -Not -Throw
        }

        It "Should throw when connection fails" {
            {
                Assert-NetworkConnectivity -HostName "invalid.host.local" -Port 443
            } | Should -Throw -ExceptionType ([ActionRunnerException])
        }

        It "Should throw when port is not accessible" {
            {
                Assert-NetworkConnectivity -HostName "github.com" -Port 12345
            } | Should -Throw -ExceptionType ([ActionRunnerException])
        }
    }

    Context "Assert-CommandExists" {
        It "Should not throw when command exists" {
            {
                Assert-CommandExists -CommandName "powershell"
            } | Should -Not -Throw
        }

        It "Should throw when command does not exist" {
            {
                Assert-CommandExists -CommandName "nonexistent-command-xyz"
            } | Should -Throw -ExceptionType ([ActionRunnerException])
        }

        It "Should include install instructions in error" {
            try {
                Assert-CommandExists -CommandName "nonexistent-cmd" -InstallInstructions "Install from example.com"
            }
            catch {
                $_.Exception.Remedy | Should -Be "Install from example.com"
            }
        }
    }

    Context "Invoke-WithRetry" {
        It "Should succeed on first attempt when script block succeeds" {
            $result = Invoke-WithRetry -ScriptBlock { "success" } -MaxRetries 3
            $result | Should -Be "success"
        }

        It "Should retry on failure and eventually succeed" {
            $script:attemptCount = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptCount++
                if ($script:attemptCount -lt 3) { throw "Temporary failure" }
                "success"
            } -MaxRetries 3 -RetryDelaySeconds 1

            $result | Should -Be "success"
            $script:attemptCount | Should -Be 3
        }

        It "Should throw after max retries exceeded" {
            $script:attemptCount = 0
            {
                Invoke-WithRetry -ScriptBlock {
                    $script:attemptCount++
                    throw "Persistent failure"
                } -MaxRetries 2 -RetryDelaySeconds 1 -ErrorMessage "Operation failed"
            } | Should -Throw -ExceptionType ([ActionRunnerException])

            $script:attemptCount | Should -Be 3  # Initial attempt + 2 retries
        }
    }

    Context "Assert-Administrator" {
        It "Should return boolean indicating admin status" {
            $result = Assert-Administrator -Required $false
            $result | Should -BeOfType [bool]
        }

        It "Should not throw when not admin and not required" {
            # Run in non-admin context if possible, otherwise just verify it doesn't throw
            {
                $result = Assert-Administrator -Required $false
            } | Should -Not -Throw
        }
    }

    Context "Invoke-ActionRunnerWebRequest" {
        It "Should return response on successful request" {
            Mock Invoke-RestMethod { return @{ status = "ok" } }

            $result = Invoke-ActionRunnerWebRequest -Uri "https://api.github.com"
            $result.status | Should -Be "ok"
        }

        It "Should throw ActionRunnerException on request failure" {
            Mock Invoke-RestMethod {
                $response = [PSCustomObject]@{
                    StatusCode = @{ value__ = 404 }
                    StatusDescription = "Not Found"
                }
                $exception = New-Object System.Net.WebException("Error")
                $exception | Add-Member -NotePropertyName Response -NotePropertyValue $response -Force
                throw $exception
            }

            {
                Invoke-ActionRunnerWebRequest -Uri "https://api.github.com/invalid"
            } | Should -Throw -ExceptionType ([ActionRunnerException])
        }
    }
}
