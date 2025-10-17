BeforeAll {
    $scriptPath = "$PSScriptRoot\..\scripts\test-github-runner-api.ps1"

    # Mock environment variables for testing
    $env:GITHUB_TEST_TOKEN = "ghp_mocktokenfortest1234567890"
    $env:GITHUB_TEST_ORG = "test-org"
    $env:GITHUB_TEST_REPO = "test-owner/test-repo"
}

Describe "test-github-runner-api.ps1 Tests" {
    Context "Parameter Validation" {
        It "Should accept valid token format with ghp_ prefix" {
            { & $scriptPath -Token "ghp_test123" -OrgOrRepo "test-org" -IsOrg -Operation "GetToken" -ErrorAction Stop } |
                Should -Not -Throw
        }

        It "Should accept valid token format with github_pat_ prefix" {
            { & $scriptPath -Token "github_pat_test123" -OrgOrRepo "test-org" -IsOrg -Operation "GetToken" -ErrorAction Stop } |
                Should -Not -Throw
        }

        It "Should reject invalid token format" {
            $result = & $scriptPath -Token "invalid_token" -OrgOrRepo "test-org" -IsOrg -Operation "GetToken" 2>&1 3>&1
            $LASTEXITCODE | Should -Be 1
        }

        It "Should accept valid operations" {
            $validOps = @("GetToken", "ListRunners", "GetRunner", "RemoveRunner", "GetRunnerApplication")

            foreach ($op in $validOps) {
                { & $scriptPath -Token "ghp_test" -OrgOrRepo "test" -Operation $op -ErrorAction Stop } |
                    Should -Not -Throw
            }
        }
    }

    Context "API URL Construction" {
        It "Should construct organization API URL when IsOrg is specified" {
            Mock Invoke-RestMethod { return @{ token = "mock_token"; expires_at = "2025-01-01T00:00:00Z" } }

            & $scriptPath -Token "ghp_test" -OrgOrRepo "myorg" -IsOrg -Operation "GetToken"

            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Uri -eq "https://api.github.com/orgs/myorg/actions/runners/registration-token"
            }
        }

        It "Should construct repository API URL when IsOrg is not specified" {
            Mock Invoke-RestMethod { return @{ token = "mock_token"; expires_at = "2025-01-01T00:00:00Z" } }

            & $scriptPath -Token "ghp_test" -OrgOrRepo "owner/repo" -Operation "GetToken"

            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Uri -eq "https://api.github.com/repos/owner/repo/actions/runners/registration-token"
            }
        }
    }

    Context "GetToken Operation" {
        It "Should request registration token successfully" {
            Mock Invoke-RestMethod {
                return @{
                    token = "MOCK_REGISTRATION_TOKEN_12345"
                    expires_at = "2025-01-01T00:00:00Z"
                }
            }

            $result = & $scriptPath -Token "ghp_test" -OrgOrRepo "test-org" -IsOrg -Operation "GetToken"

            $result.success | Should -Be $true
            $result.token | Should -Be "MOCK_REGISTRATION_TOKEN_12345"
            $result.expires_at | Should -Be "2025-01-01T00:00:00Z"
        }

        It "Should use correct HTTP method and headers" {
            Mock Invoke-RestMethod { return @{ token = "test"; expires_at = "2025-01-01T00:00:00Z" } }

            & $scriptPath -Token "ghp_test" -OrgOrRepo "test-org" -IsOrg -Operation "GetToken"

            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Method -eq "Post" -and
                $Headers["Authorization"] -eq "Bearer ghp_test" -and
                $Headers["Accept"] -eq "application/vnd.github+json" -and
                $Headers["X-GitHub-Api-Version"] -eq "2022-11-28"
            }
        }
    }

    Context "ListRunners Operation" {
        It "Should list runners successfully" {
            Mock Invoke-RestMethod {
                return @{
                    total_count = 2
                    runners = @(
                        @{
                            id = 1
                            name = "runner-1"
                            os = "windows"
                            status = "online"
                            busy = $false
                            labels = @(
                                @{ name = "self-hosted" },
                                @{ name = "windows" }
                            )
                        },
                        @{
                            id = 2
                            name = "runner-2"
                            os = "linux"
                            status = "offline"
                            busy = $false
                            labels = @(
                                @{ name = "self-hosted" },
                                @{ name = "linux" }
                            )
                        }
                    )
                }
            }

            $result = & $scriptPath -Token "ghp_test" -OrgOrRepo "test-org" -IsOrg -Operation "ListRunners"

            $result.success | Should -Be $true
            $result.total_count | Should -Be 2
            $result.runners.Count | Should -Be 2
            $result.runners[0].name | Should -Be "runner-1"
        }

        It "Should use GET method for listing runners" {
            Mock Invoke-RestMethod { return @{ total_count = 0; runners = @() } }

            & $scriptPath -Token "ghp_test" -OrgOrRepo "test-org" -IsOrg -Operation "ListRunners"

            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Method -eq "Get"
            }
        }
    }

    Context "GetRunner Operation" {
        It "Should get specific runner details" {
            Mock Invoke-RestMethod {
                return @{
                    id = 123
                    name = "test-runner"
                    os = "windows"
                    status = "online"
                    busy = $false
                    labels = @(
                        @{ name = "self-hosted" },
                        @{ name = "windows" }
                    )
                }
            }

            $result = & $scriptPath -Token "ghp_test" -OrgOrRepo "test-org" -IsOrg -Operation "GetRunner" -RunnerId 123

            $result.success | Should -Be $true
            $result.runner.id | Should -Be 123
            $result.runner.name | Should -Be "test-runner"
        }

        It "Should require RunnerId parameter" {
            $result = & $scriptPath -Token "ghp_test" -OrgOrRepo "test-org" -IsOrg -Operation "GetRunner" 2>&1 3>&1

            $LASTEXITCODE | Should -Be 1
        }

        It "Should construct correct URL with runner ID" {
            Mock Invoke-RestMethod { return @{ id = 456; name = "test" } }

            & $scriptPath -Token "ghp_test" -OrgOrRepo "test-org" -IsOrg -Operation "GetRunner" -RunnerId 456

            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Uri -eq "https://api.github.com/orgs/test-org/actions/runners/456"
            }
        }
    }

    Context "RemoveRunner Operation" {
        It "Should remove runner successfully" {
            Mock Invoke-RestMethod { return $null }

            $result = & $scriptPath -Token "ghp_test" -OrgOrRepo "test-org" -IsOrg -Operation "RemoveRunner" -RunnerId 123

            $result.success | Should -Be $true
            $result.message | Should -Be "Runner 123 removed"
        }

        It "Should use DELETE method" {
            Mock Invoke-RestMethod { return $null }

            & $scriptPath -Token "ghp_test" -OrgOrRepo "test-org" -IsOrg -Operation "RemoveRunner" -RunnerId 123

            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Method -eq "Delete"
            }
        }

        It "Should require RunnerId parameter" {
            $result = & $scriptPath -Token "ghp_test" -OrgOrRepo "test-org" -IsOrg -Operation "RemoveRunner" 2>&1 3>&1

            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "GetRunnerApplication Operation" {
        It "Should get runner application downloads" {
            Mock Invoke-RestMethod {
                return @(
                    @{
                        os = "win"
                        architecture = "x64"
                        download_url = "https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-win-x64-2.311.0.zip"
                        filename = "actions-runner-win-x64-2.311.0.zip"
                    },
                    @{
                        os = "linux"
                        architecture = "x64"
                        download_url = "https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz"
                        filename = "actions-runner-linux-x64-2.311.0.tar.gz"
                    }
                )
            }

            $result = & $scriptPath -Token "ghp_test" -OrgOrRepo "test-org" -IsOrg -Operation "GetRunnerApplication"

            $result.success | Should -Be $true
            $result.applications.Count | Should -Be 2
            $result.applications[0].os | Should -Be "win"
        }

        It "Should use correct downloads endpoint" {
            Mock Invoke-RestMethod { return @() }

            & $scriptPath -Token "ghp_test" -OrgOrRepo "test-org" -IsOrg -Operation "GetRunnerApplication"

            Should -Invoke Invoke-RestMethod -ParameterFilter {
                $Uri -eq "https://api.github.com/orgs/test-org/actions/runners/downloads"
            }
        }
    }

    Context "Error Handling" {
        It "Should handle 401 authentication errors" {
            Mock Invoke-RestMethod {
                $response = [System.Net.HttpWebResponse]::new()
                $response.StatusCode = [System.Net.HttpStatusCode]::Unauthorized
                throw [System.Net.WebException]::new("Unauthorized", $null, [System.Net.WebExceptionStatus]::ProtocolError, $response)
            }

            $result = & $scriptPath -Token "ghp_test" -OrgOrRepo "test-org" -IsOrg -Operation "GetToken"

            $result.success | Should -Be $false
            $result.error | Should -Not -BeNullOrEmpty
        }

        It "Should handle 404 not found errors" {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new("Not Found")
            }

            $result = & $scriptPath -Token "ghp_test" -OrgOrRepo "nonexistent-org" -IsOrg -Operation "GetToken"

            $result.success | Should -Be $false
        }

        It "Should handle network errors gracefully" {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new("Network error")
            }

            $result = & $scriptPath -Token "ghp_test" -OrgOrRepo "test-org" -IsOrg -Operation "GetToken"

            $result.success | Should -Be $false
            $result.error | Should -Match "Network error"
        }
    }

    Context "Integration with Mock Service" {
        It "Should work with mock registration service" {
            # This test requires the mock service to be running
            # Skip if not available
            $mockUrl = "http://localhost:8080"

            try {
                $health = Invoke-RestMethod -Uri "$mockUrl/health" -Method Get -TimeoutSec 2
                $serviceAvailable = $true
            } catch {
                $serviceAvailable = $false
            }

            if ($serviceAvailable) {
                # Override the API base URL to use mock service
                Mock Invoke-RestMethod {
                    param($Uri, $Method, $Headers)
                    $mockUri = $Uri -replace "https://api.github.com", "http://localhost:8080"
                    Invoke-RestMethod -Uri $mockUri -Method $Method -Headers $Headers
                }

                $result = & $scriptPath -Token "ghp_test" -OrgOrRepo "test-org" -IsOrg -Operation "GetToken"

                $result.success | Should -Be $true
                $result.token | Should -Match "^MOCK_REG_"
            } else {
                Set-ItResult -Skipped -Because "Mock service not running"
            }
        }
    }
}

Describe "Script Output and Logging" {
    BeforeEach {
        $scriptPath = "$PSScriptRoot\..\scripts\test-github-runner-api.ps1"
    }

    It "Should log operation details" {
        Mock Invoke-RestMethod { return @{ token = "test"; expires_at = "2025-01-01T00:00:00Z" } }

        $output = & $scriptPath -Token "ghp_test" -OrgOrRepo "test-org" -IsOrg -Operation "GetToken" 2>&1 3>&1 4>&1 5>&1 6>&1

        $outputString = $output -join "`n"
        $outputString | Should -Match "Testing GitHub Runner API"
        $outputString | Should -Match "Entity: test-org"
        $outputString | Should -Match "Operation: GetToken"
    }

    It "Should provide colored output for different log levels" {
        Mock Invoke-RestMethod { return @{ token = "test"; expires_at = "2025-01-01T00:00:00Z" } }

        $output = & $scriptPath -Token "ghp_test" -OrgOrRepo "test-org" -IsOrg -Operation "GetToken" 2>&1 3>&1 4>&1 5>&1 6>&1

        # Should contain SUCCESS level logs
        $outputString = $output -join "`n"
        $outputString | Should -Match "\[SUCCESS\]"
    }
}
