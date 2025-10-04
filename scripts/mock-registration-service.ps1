<#
.SYNOPSIS
    Mock GitHub runner registration service for testing purposes.

.DESCRIPTION
    This script provides a mock HTTP server that simulates the GitHub Actions runner
    registration API. It allows testing of runner registration workflows without
    requiring a real GitHub API token or repository access.

.PARAMETER Port
    The port number to run the mock service on (default: 8080)

.PARAMETER LogFile
    Path to log file for recording requests (default: logs/mock-registration.log)

.PARAMETER EnableAuth
    Enable basic token validation (default: true)

.EXAMPLE
    .\mock-registration-service.ps1 -Port 8080

.EXAMPLE
    .\mock-registration-service.ps1 -Port 9000 -EnableAuth:$false

.NOTES
    This is for testing purposes only. Not intended for production use.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$Port = 8080,

    [Parameter(Mandatory = $false)]
    [string]$LogFile = "logs/mock-registration.log",

    [Parameter(Mandatory = $false)]
    [bool]$EnableAuth = $true
)

$ErrorActionPreference = "Stop"

# Ensure logs directory exists
$logDir = Split-Path $LogFile -Parent
if ($logDir -and -not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }

    Write-Host $logEntry -ForegroundColor $color

    if ($LogFile) {
        Add-Content -Path $LogFile -Value $logEntry
    }
}

# Mock data store for registered runners
$script:RegisteredRunners = @()
$script:RequestCount = 0

# Generate mock registration token
function New-MockRegistrationToken {
    # Use RNGCryptoServiceProvider for compatibility with PowerShell 5.1
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $tokenBytes = [byte[]]::new(32)
    $rng.GetBytes($tokenBytes)
    $rng.Dispose()
    $token = [Convert]::ToBase64String($tokenBytes)
    return "MOCK_REG_$token"
}

# Validate authorization header
function Test-Authorization {
    param([string]$AuthHeader)

    if (-not $EnableAuth) {
        return $true
    }

    if ([string]::IsNullOrEmpty($AuthHeader)) {
        return $false
    }

    # Accept any Bearer token that looks like a GitHub token
    if ($AuthHeader -match '^Bearer (ghp_|github_pat_)') {
        return $true
    }

    return $false
}

# Handle registration token endpoint
function Get-RegistrationTokenResponse {
    param(
        [string]$OrgOrRepo,
        [bool]$IsOrg
    )

    $token = New-MockRegistrationToken
    $expiresAt = (Get-Date).AddHours(1).ToString("yyyy-MM-ddTHH:mm:ssZ")

    Write-Log "Generated registration token for $OrgOrRepo (IsOrg: $IsOrg)" "SUCCESS"

    return @{
        token = $token
        expires_at = $expiresAt
    } | ConvertTo-Json
}

# Handle runner registration
function Register-MockRunner {
    param(
        [string]$Name,
        [string]$Labels,
        [string]$OrgOrRepo
    )

    $runner = @{
        id = [System.Random]::new().Next(1000, 9999)
        name = $Name
        os = "windows"
        status = "online"
        labels = $Labels -split ','
        busy = $false
        created_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    }

    $script:RegisteredRunners += $runner
    Write-Log "Registered runner: $Name with labels: $Labels" "SUCCESS"

    return $runner | ConvertTo-Json
}

# Handle runner list endpoint
function Get-RunnersResponse {
    param([string]$OrgOrRepo)

    Write-Log "Listing runners for $OrgOrRepo" "INFO"

    return @{
        total_count = $script:RegisteredRunners.Count
        runners = $script:RegisteredRunners
    } | ConvertTo-Json -Depth 5
}

# Handle latest runner release endpoint
function Get-LatestRunnerRelease {
    $mockVersion = "2.311.0"

    return @{
        tag_name = "v$mockVersion"
        name = "v$mockVersion"
        assets = @(
            @{
                name = "actions-runner-win-x64-$mockVersion.zip"
                browser_download_url = "https://github.com/actions/runner/releases/download/v$mockVersion/actions-runner-win-x64-$mockVersion.zip"
                size = 123456789
            },
            @{
                name = "actions-runner-linux-x64-$mockVersion.tar.gz"
                browser_download_url = "https://github.com/actions/runner/releases/download/v$mockVersion/actions-runner-linux-x64-$mockVersion.tar.gz"
                size = 123456789
            }
        )
    } | ConvertTo-Json -Depth 5
}

# HTTP request handler
function Handle-Request {
    param(
        [System.Net.HttpListenerContext]$Context
    )

    $script:RequestCount++
    $request = $Context.Request
    $response = $Context.Response

    $method = $request.HttpMethod
    $url = $request.Url.AbsolutePath
    $authHeader = $request.Headers["Authorization"]

    Write-Log "Request #$($script:RequestCount): $method $url" "INFO"

    # Set default response headers
    $response.ContentType = "application/json"
    $response.Headers.Add("X-GitHub-Api-Version", "2022-11-28")

    $responseBody = ""
    $statusCode = 200

    try {
        # Route handling
        switch -Regex ($url) {
            # Latest runner release
            '^/repos/actions/runner/releases/latest$' {
                $responseBody = Get-LatestRunnerRelease
            }

            # Organization registration token
            '^/orgs/([^/]+)/actions/runners/registration-token$' {
                if (-not (Test-Authorization $authHeader)) {
                    $statusCode = 401
                    $responseBody = @{ message = "Requires authentication" } | ConvertTo-Json
                } else {
                    $orgName = $matches[1]
                    $responseBody = Get-RegistrationTokenResponse -OrgOrRepo $orgName -IsOrg $true
                }
            }

            # Repository registration token
            '^/repos/([^/]+)/([^/]+)/actions/runners/registration-token$' {
                if (-not (Test-Authorization $authHeader)) {
                    $statusCode = 401
                    $responseBody = @{ message = "Requires authentication" } | ConvertTo-Json
                } else {
                    $repoPath = "$($matches[1])/$($matches[2])"
                    $responseBody = Get-RegistrationTokenResponse -OrgOrRepo $repoPath -IsOrg $false
                }
            }

            # List organization runners
            '^/orgs/([^/]+)/actions/runners$' {
                if ($method -eq "GET") {
                    if (-not (Test-Authorization $authHeader)) {
                        $statusCode = 401
                        $responseBody = @{ message = "Requires authentication" } | ConvertTo-Json
                    } else {
                        $orgName = $matches[1]
                        $responseBody = Get-RunnersResponse -OrgOrRepo $orgName
                    }
                }
            }

            # List repository runners
            '^/repos/([^/]+)/([^/]+)/actions/runners$' {
                if ($method -eq "GET") {
                    if (-not (Test-Authorization $authHeader)) {
                        $statusCode = 401
                        $responseBody = @{ message = "Requires authentication" } | ConvertTo-Json
                    } else {
                        $repoPath = "$($matches[1])/$($matches[2])"
                        $responseBody = Get-RunnersResponse -OrgOrRepo $repoPath
                    }
                }
            }

            # Health check
            '^/health$' {
                $responseBody = @{
                    status = "healthy"
                    uptime = (Get-Date) - $script:StartTime
                    request_count = $script:RequestCount
                    registered_runners = $script:RegisteredRunners.Count
                } | ConvertTo-Json
            }

            # Reset mock data
            '^/reset$' {
                if ($method -eq "POST") {
                    $script:RegisteredRunners = @()
                    $script:RequestCount = 0
                    $responseBody = @{ message = "Mock data reset successfully" } | ConvertTo-Json
                    Write-Log "Mock data reset" "WARN"
                }
            }

            default {
                $statusCode = 404
                $responseBody = @{
                    message = "Not Found"
                    documentation_url = "https://docs.github.com/rest"
                } | ConvertTo-Json
            }
        }
    } catch {
        Write-Log "Error handling request: $($_.Exception.Message)" "ERROR"
        $statusCode = 500
        $responseBody = @{
            message = "Internal server error"
            error = $_.Exception.Message
        } | ConvertTo-Json
    }

    # Send response
    $response.StatusCode = $statusCode
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseBody)
    $response.ContentLength64 = $buffer.Length
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
    $response.Close()

    Write-Log "Response: $statusCode ($($buffer.Length) bytes)" "INFO"
}

# Main server loop
function Start-MockService {
    $script:StartTime = Get-Date

    Write-Log "Starting mock GitHub runner registration service..." "INFO"
    Write-Log "Port: $Port" "INFO"
    Write-Log "Authentication: $(if ($EnableAuth) { 'Enabled' } else { 'Disabled' })" "INFO"
    Write-Log "Log file: $LogFile" "INFO"

    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$Port/")

    try {
        $listener.Start()
        Write-Log "Mock service started successfully" "SUCCESS"
        Write-Log "Listening on http://localhost:$Port/" "SUCCESS"
        Write-Host ""
        Write-Host "=== AVAILABLE ENDPOINTS ===" -ForegroundColor Cyan
        Write-Host "GET  /health                                                  - Service health check" -ForegroundColor White
        Write-Host "POST /reset                                                   - Reset mock data" -ForegroundColor White
        Write-Host "GET  /repos/actions/runner/releases/latest                    - Get latest runner version" -ForegroundColor White
        Write-Host "POST /orgs/{org}/actions/runners/registration-token          - Get org registration token" -ForegroundColor White
        Write-Host "POST /repos/{owner}/{repo}/actions/runners/registration-token - Get repo registration token" -ForegroundColor White
        Write-Host "GET  /orgs/{org}/actions/runners                             - List org runners" -ForegroundColor White
        Write-Host "GET  /repos/{owner}/{repo}/actions/runners                   - List repo runners" -ForegroundColor White
        Write-Host ""
        Write-Host "Press Ctrl+C to stop the service" -ForegroundColor Yellow
        Write-Host ""

        while ($listener.IsListening) {
            $contextTask = $listener.GetContextAsync()

            while (-not $contextTask.AsyncWaitHandle.WaitOne(200)) {
                # Allow for graceful shutdown
            }

            $context = $contextTask.GetAwaiter().GetResult()
            Handle-Request -Context $context
        }
    } catch {
        Write-Log "Error starting mock service: $($_.Exception.Message)" "ERROR"
        throw
    } finally {
        if ($listener.IsListening) {
            $listener.Stop()
        }
        $listener.Close()
        Write-Log "Mock service stopped" "INFO"
    }
}

# Handle Ctrl+C gracefully
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Write-Log "Shutting down mock service..." "WARN"
}

# Start the service
Start-MockService
