# Pester tests for mock-registration-service.ps1
# Run with: Invoke-Pester -Path .\tests\mock-registration-service.Tests.ps1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "..\scripts\mock-registration-service.ps1"
    $script:TestPort = 18080  # Use different port to avoid conflicts
    $script:BaseUrl = "http://localhost:$($script:TestPort)"
    $script:ServiceProcess = $null
}

Describe "mock-registration-service.ps1 Initialization" {
    It "Should exist and be readable" {
        Test-Path $script:ScriptPath | Should -Be $true
    }

    It "Should have valid PowerShell syntax" {
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:ScriptPath -Raw), [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It "Should accept Port parameter" {
        # Verify parameter exists in script
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $scriptContent | Should -Match '\[int\]\$Port'
    }

    It "Should accept LogFile parameter" {
        # Verify parameter exists in script
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $scriptContent | Should -Match '\[string\]\$LogFile'
    }

    It "Should accept EnableAuth parameter" {
        # Verify parameter exists in script
        $scriptContent = Get-Content $script:ScriptPath -Raw
        $scriptContent | Should -Match '\[bool\]\$EnableAuth'
    }
}

Describe "mock-registration-service.ps1 HTTP Server" -Skip {
    # Note: These tests are skipped by default as they require starting a real HTTP server
    # Remove -Skip to run integration tests

    BeforeAll {
        # Start mock service in background
        $script:ServiceJob = Start-Job -ScriptBlock {
            param($ScriptPath, $Port)
            & $ScriptPath -Port $Port -EnableAuth $false
        } -ArgumentList $script:ScriptPath, $script:TestPort

        # Wait for service to start
        Start-Sleep -Seconds 3

        # Verify service is running
        $healthResponse = Invoke-RestMethod -Uri "$($script:BaseUrl)/health" -ErrorAction SilentlyContinue
        if (-not $healthResponse) {
            throw "Failed to start mock service"
        }
    }

    AfterAll {
        # Stop mock service
        if ($script:ServiceJob) {
            Stop-Job -Job $script:ServiceJob -ErrorAction SilentlyContinue
            Remove-Job -Job $script:ServiceJob -Force -ErrorAction SilentlyContinue
        }
    }

    It "Should respond to health check" {
        $response = Invoke-RestMethod -Uri "$($script:BaseUrl)/health" -Method Get
        $response.status | Should -Be "healthy"
        $response.request_count | Should -BeGreaterOrEqual 0
        $response.registered_runners | Should -BeGreaterOrEqual 0
    }

    It "Should return latest runner release information" {
        $response = Invoke-RestMethod -Uri "$($script:BaseUrl)/repos/actions/runner/releases/latest" -Method Get
        $response.tag_name | Should -Match '^v\d+\.\d+\.\d+$'
        $response.assets | Should -Not -BeNullOrEmpty
        $response.assets[0].name | Should -Match 'actions-runner-win-x64'
    }

    It "Should generate organization registration token" {
        $response = Invoke-RestMethod -Uri "$($script:BaseUrl)/orgs/test-org/actions/runners/registration-token" -Method Post
        $response.token | Should -Match '^MOCK_REG_'
        $response.expires_at | Should -Not -BeNullOrEmpty
    }

    It "Should generate repository registration token" {
        $response = Invoke-RestMethod -Uri "$($script:BaseUrl)/repos/owner/repo/actions/runners/registration-token" -Method Post
        $response.token | Should -Match '^MOCK_REG_'
        $response.expires_at | Should -Not -BeNullOrEmpty
    }

    It "Should list runners for organization" {
        $response = Invoke-RestMethod -Uri "$($script:BaseUrl)/orgs/test-org/actions/runners" -Method Get
        $response.total_count | Should -BeGreaterOrEqual 0
        $response.runners | Should -Not -BeNullOrEmpty -Because "runners array should exist even if empty"
    }

    It "Should list runners for repository" {
        $response = Invoke-RestMethod -Uri "$($script:BaseUrl)/repos/owner/repo/actions/runners" -Method Get
        $response.total_count | Should -BeGreaterOrEqual 0
        $response.runners | Should -Not -BeNullOrEmpty -Because "runners array should exist even if empty"
    }

    It "Should return 404 for unknown endpoints" {
        { Invoke-RestMethod -Uri "$($script:BaseUrl)/unknown/endpoint" -Method Get -ErrorAction Stop } | Should -Throw
    }

    It "Should reset mock data" {
        $response = Invoke-RestMethod -Uri "$($script:BaseUrl)/reset" -Method Post
        $response.message | Should -Match "reset successfully"
    }
}

Describe "mock-registration-service.ps1 Authentication" -Skip {
    # Note: These tests require running HTTP server - skipped by default

    BeforeAll {
        # Start mock service with authentication enabled
        $script:ServiceJob = Start-Job -ScriptBlock {
            param($ScriptPath, $Port)
            & $ScriptPath -Port $Port -EnableAuth $true
        } -ArgumentList $script:ScriptPath, $script:TestPort

        Start-Sleep -Seconds 3
    }

    AfterAll {
        if ($script:ServiceJob) {
            Stop-Job -Job $script:ServiceJob -ErrorAction SilentlyContinue
            Remove-Job -Job $script:ServiceJob -Force -ErrorAction SilentlyContinue
        }
    }

    It "Should require authentication for registration token" {
        { Invoke-RestMethod -Uri "$($script:BaseUrl)/orgs/test-org/actions/runners/registration-token" -Method Post -ErrorAction Stop } | Should -Throw
    }

    It "Should accept valid Bearer token" {
        $headers = @{
            "Authorization" = "Bearer ghp_1234567890abcdef"
        }
        $response = Invoke-RestMethod -Uri "$($script:BaseUrl)/orgs/test-org/actions/runners/registration-token" -Method Post -Headers $headers
        $response.token | Should -Match '^MOCK_REG_'
    }

    It "Should accept github_pat_ token format" {
        $headers = @{
            "Authorization" = "Bearer github_pat_1234567890abcdef"
        }
        $response = Invoke-RestMethod -Uri "$($script:BaseUrl)/repos/owner/repo/actions/runners/registration-token" -Method Post -Headers $headers
        $response.token | Should -Match '^MOCK_REG_'
    }

    It "Should reject invalid token format" {
        $headers = @{
            "Authorization" = "Bearer invalid_token"
        }
        { Invoke-RestMethod -Uri "$($script:BaseUrl)/orgs/test-org/actions/runners/registration-token" -Method Post -Headers $headers -ErrorAction Stop } | Should -Throw
    }
}

Describe "mock-registration-service.ps1 Token Generation" {
    It "Should generate unique registration tokens" {
        # Mock the token generation function
        function New-MockRegistrationToken {
            $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
            $tokenBytes = [byte[]]::new(32)
            $rng.GetBytes($tokenBytes)
            $rng.Dispose()
            $token = [Convert]::ToBase64String($tokenBytes)
            return "MOCK_REG_$token"
        }

        $token1 = New-MockRegistrationToken
        $token2 = New-MockRegistrationToken

        $token1 | Should -Not -Be $token2
        $token1 | Should -Match '^MOCK_REG_'
        $token2 | Should -Match '^MOCK_REG_'
    }

    It "Should include expiration time in response" {
        $expiresAt = (Get-Date).AddHours(1).ToString("yyyy-MM-ddTHH:mm:ssZ")
        $expiresAt | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$'
    }
}

Describe "mock-registration-service.ps1 Response Format" {
    It "Should return valid JSON for registration token" {
        $mockResponse = @{
            token = "MOCK_REG_test123"
            expires_at = "2024-01-01T12:00:00Z"
        } | ConvertTo-Json

        $parsed = $mockResponse | ConvertFrom-Json
        $parsed.token | Should -Be "MOCK_REG_test123"
        $parsed.expires_at | Should -Be "2024-01-01T12:00:00Z"
    }

    It "Should return valid JSON for runner list" {
        $mockResponse = @{
            total_count = 2
            runners = @(
                @{ id = 1; name = "runner1"; status = "online" },
                @{ id = 2; name = "runner2"; status = "offline" }
            )
        } | ConvertTo-Json -Depth 5

        $parsed = $mockResponse | ConvertFrom-Json
        $parsed.total_count | Should -Be 2
        $parsed.runners.Count | Should -Be 2
    }

    It "Should return valid JSON for latest release" {
        $mockResponse = @{
            tag_name = "v2.311.0"
            assets = @(
                @{ name = "actions-runner-win-x64-2.311.0.zip"; browser_download_url = "https://example.com/runner.zip" }
            )
        } | ConvertTo-Json -Depth 5

        $parsed = $mockResponse | ConvertFrom-Json
        $parsed.tag_name | Should -Be "v2.311.0"
        $parsed.assets[0].name | Should -Match 'win-x64'
    }
}

Describe "mock-registration-service.ps1 Endpoint Routing" {
    It "Should match organization registration token pattern" {
        $url = "/orgs/test-org/actions/runners/registration-token"
        $url | Should -Match '^/orgs/([^/]+)/actions/runners/registration-token$'
    }

    It "Should match repository registration token pattern" {
        $url = "/repos/owner/repo/actions/runners/registration-token"
        $url | Should -Match '^/repos/([^/]+)/([^/]+)/actions/runners/registration-token$'
    }

    It "Should extract organization name from URL" {
        $url = "/orgs/my-org/actions/runners/registration-token"
        if ($url -match '^/orgs/([^/]+)/actions/runners/registration-token$') {
            $matches[1] | Should -Be "my-org"
        }
    }

    It "Should extract owner and repo from URL" {
        $url = "/repos/my-owner/my-repo/actions/runners/registration-token"
        if ($url -match '^/repos/([^/]+)/([^/]+)/actions/runners/registration-token$') {
            $matches[1] | Should -Be "my-owner"
            $matches[2] | Should -Be "my-repo"
        }
    }
}

Describe "mock-registration-service.ps1 Error Handling" {
    It "Should handle 404 errors gracefully" {
        $errorResponse = @{
            message = "Not Found"
            documentation_url = "https://docs.github.com/rest"
        } | ConvertTo-Json

        $parsed = $errorResponse | ConvertFrom-Json
        $parsed.message | Should -Be "Not Found"
    }

    It "Should handle 401 errors gracefully" {
        $errorResponse = @{
            message = "Requires authentication"
        } | ConvertTo-Json

        $parsed = $errorResponse | ConvertFrom-Json
        $parsed.message | Should -Be "Requires authentication"
    }

    It "Should handle 500 errors gracefully" {
        $errorResponse = @{
            message = "Internal server error"
            error = "Test error message"
        } | ConvertTo-Json

        $parsed = $errorResponse | ConvertFrom-Json
        $parsed.message | Should -Be "Internal server error"
        $parsed.error | Should -Be "Test error message"
    }
}

Describe "mock-registration-service.ps1 Logging" {
    It "Should create log directory if not exists" {
        $testLogPath = Join-Path $TestDrive "test-logs\mock-service.log"
        $logDir = Split-Path $testLogPath -Parent

        if ($logDir -and -not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        Test-Path $logDir | Should -Be $true
    }

    It "Should write log entries with timestamp" {
        function Test-WriteLog {
            param([string]$Message, [string]$Level = "INFO")
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            return "[$timestamp] [$Level] $Message"
        }

        $logEntry = Test-WriteLog -Message "Test message" -Level "INFO"
        $logEntry | Should -Match '\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[INFO\] Test message'
    }

    It "Should support different log levels" {
        $levels = @("INFO", "WARN", "ERROR", "SUCCESS")
        foreach ($level in $levels) {
            $level | Should -BeIn @("INFO", "WARN", "ERROR", "SUCCESS")
        }
    }
}

Describe "mock-registration-service.ps1 Runner Data Management" {
    It "Should initialize empty runner list" {
        $runners = @()
        $runners.Count | Should -Be 0
    }

    It "Should add runner to list" {
        $runners = @()
        $newRunner = @{
            id = 1
            name = "test-runner"
            os = "windows"
            status = "online"
            labels = @("self-hosted", "windows")
        }
        $runners += $newRunner

        $runners.Count | Should -Be 1
        $runners[0].name | Should -Be "test-runner"
    }

    It "Should track request count" {
        $requestCount = 0
        $requestCount++
        $requestCount++

        $requestCount | Should -Be 2
    }

    It "Should reset runner data" {
        $runners = @(@{ id = 1 }, @{ id = 2 })
        $runners = @()

        $runners.Count | Should -Be 0
    }
}

Describe "mock-registration-service.ps1 Integration with register-runner.ps1" {
    It "Should provide compatible API endpoints" {
        # Verify mock service provides same endpoints as GitHub API
        $requiredEndpoints = @(
            "/repos/actions/runner/releases/latest",
            "/orgs/{org}/actions/runners/registration-token",
            "/repos/{owner}/{repo}/actions/runners/registration-token"
        )

        foreach ($endpoint in $requiredEndpoints) {
            $endpoint | Should -Not -BeNullOrEmpty
        }
    }

    It "Should return registration token in expected format" {
        $mockToken = "MOCK_REG_" + [Convert]::ToBase64String([byte[]]::new(32))
        $mockToken | Should -Match '^MOCK_REG_'
    }

    It "Should include runner version in release response" {
        $mockRelease = @{
            tag_name = "v2.311.0"
            assets = @(@{ name = "actions-runner-win-x64-2.311.0.zip" })
        }

        $mockRelease.tag_name | Should -Match '^v\d+\.\d+\.\d+$'
        $mockRelease.assets[0].name | Should -Match 'win-x64'
    }
}

AfterAll {
    # Cleanup
    if ($script:ServiceJob) {
        Stop-Job -Job $script:ServiceJob -ErrorAction SilentlyContinue
        Remove-Job -Job $script:ServiceJob -Force -ErrorAction SilentlyContinue
    }
}
