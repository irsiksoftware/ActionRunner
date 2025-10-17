<#
.SYNOPSIS
    Test GitHub runner API endpoints for runner management.

.DESCRIPTION
    This script provides test endpoints for GitHub Actions runner API operations.
    It validates the ability to interact with GitHub's runner API including:
    - Retrieving registration tokens
    - Listing runners
    - Checking runner status
    - Removing runners

.PARAMETER Token
    GitHub Personal Access Token (PAT) with admin:org or repo permissions
    For organization: requires admin:org scope
    For repository: requires repo scope

.PARAMETER OrgOrRepo
    The organization name (e.g., "myorg") or full repository path (e.g., "owner/repo")

.PARAMETER IsOrg
    Switch to indicate this is an organization-level runner

.PARAMETER RunnerId
    Specific runner ID to query or remove (optional)

.PARAMETER Operation
    The API operation to test:
    - GetToken: Get a registration token
    - ListRunners: List all runners
    - GetRunner: Get specific runner details
    - RemoveRunner: Remove a runner (requires RunnerId)
    - GetRunnerApplication: Get runner application downloads

.EXAMPLE
    .\test-github-runner-api.ps1 -Token "ghp_xxx" -OrgOrRepo "myorg" -IsOrg -Operation GetToken

.EXAMPLE
    .\test-github-runner-api.ps1 -Token "ghp_xxx" -OrgOrRepo "owner/repo" -Operation ListRunners

.EXAMPLE
    .\test-github-runner-api.ps1 -Token "ghp_xxx" -OrgOrRepo "myorg" -IsOrg -Operation RemoveRunner -RunnerId 123

.NOTES
    Requires valid GitHub PAT token with appropriate permissions.
    GitHub API documentation: https://docs.github.com/en/rest/actions/self-hosted-runners
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Token,

    [Parameter(Mandatory = $true)]
    [string]$OrgOrRepo,

    [Parameter(Mandatory = $false)]
    [switch]$IsOrg,

    [Parameter(Mandatory = $false)]
    [int]$RunnerId,

    [Parameter(Mandatory = $true)]
    [ValidateSet("GetToken", "ListRunners", "GetRunner", "RemoveRunner", "GetRunnerApplication")]
    [string]$Operation
)

$ErrorActionPreference = "Stop"

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

# Validate token format
if ($Token -notmatch '^(ghp_|github_pat_)') {
    Write-Log "Invalid token format. Token should start with 'ghp_' or 'github_pat_'" "ERROR"
    exit 1
}

# Build API base URL
if ($IsOrg) {
    $apiBase = "https://api.github.com/orgs/$OrgOrRepo/actions/runners"
    $entityType = "organization"
} else {
    $apiBase = "https://api.github.com/repos/$OrgOrRepo/actions/runners"
    $entityType = "repository"
}

Write-Log "Testing GitHub Runner API" "INFO"
Write-Log "Entity: $OrgOrRepo ($entityType)" "INFO"
Write-Log "Operation: $Operation" "INFO"

# Build request headers
$headers = @{
    "Accept" = "application/vnd.github+json"
    "Authorization" = "Bearer $Token"
    "X-GitHub-Api-Version" = "2022-11-28"
}

try {
    switch ($Operation) {
        "GetToken" {
            Write-Log "Requesting registration token..." "INFO"
            $url = "$apiBase/registration-token"

            $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers

            Write-Log "Successfully obtained registration token" "SUCCESS"
            Write-Log "Token: $($response.token.Substring(0, 20))..." "INFO"
            Write-Log "Expires at: $($response.expires_at)" "INFO"

            return @{
                success = $true
                token = $response.token
                expires_at = $response.expires_at
            }
        }

        "ListRunners" {
            Write-Log "Listing runners..." "INFO"
            $url = $apiBase

            $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

            Write-Log "Found $($response.total_count) runner(s)" "SUCCESS"

            foreach ($runner in $response.runners) {
                Write-Host ""
                Write-Host "Runner ID: $($runner.id)" -ForegroundColor Cyan
                Write-Host "  Name: $($runner.name)" -ForegroundColor White
                Write-Host "  OS: $($runner.os)" -ForegroundColor White
                Write-Host "  Status: $($runner.status)" -ForegroundColor $(if ($runner.status -eq "online") { "Green" } else { "Yellow" })
                Write-Host "  Busy: $($runner.busy)" -ForegroundColor White
                Write-Host "  Labels: $($runner.labels.name -join ', ')" -ForegroundColor White
            }

            return @{
                success = $true
                total_count = $response.total_count
                runners = $response.runners
            }
        }

        "GetRunner" {
            if (-not $RunnerId) {
                Write-Log "RunnerId parameter is required for GetRunner operation" "ERROR"
                exit 1
            }

            Write-Log "Getting runner details for ID: $RunnerId..." "INFO"
            $url = "$apiBase/$RunnerId"

            $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

            Write-Log "Runner details retrieved successfully" "SUCCESS"
            Write-Host ""
            Write-Host "Runner ID: $($response.id)" -ForegroundColor Cyan
            Write-Host "  Name: $($response.name)" -ForegroundColor White
            Write-Host "  OS: $($response.os)" -ForegroundColor White
            Write-Host "  Status: $($response.status)" -ForegroundColor $(if ($response.status -eq "online") { "Green" } else { "Yellow" })
            Write-Host "  Busy: $($response.busy)" -ForegroundColor White
            Write-Host "  Labels: $($response.labels.name -join ', ')" -ForegroundColor White

            return @{
                success = $true
                runner = $response
            }
        }

        "RemoveRunner" {
            if (-not $RunnerId) {
                Write-Log "RunnerId parameter is required for RemoveRunner operation" "ERROR"
                exit 1
            }

            Write-Log "Removing runner ID: $RunnerId..." "WARN"
            $url = "$apiBase/$RunnerId"

            $response = Invoke-RestMethod -Uri $url -Method Delete -Headers $headers

            Write-Log "Runner removed successfully" "SUCCESS"

            return @{
                success = $true
                message = "Runner $RunnerId removed"
            }
        }

        "GetRunnerApplication" {
            Write-Log "Getting runner application downloads..." "INFO"
            $url = "$apiBase/downloads"

            $response = Invoke-RestMethod -Uri $url -Method Get -Headers $headers

            Write-Log "Found $($response.Count) runner application(s)" "SUCCESS"

            foreach ($app in $response) {
                Write-Host ""
                Write-Host "OS: $($app.os)" -ForegroundColor Cyan
                Write-Host "  Architecture: $($app.architecture)" -ForegroundColor White
                Write-Host "  Download URL: $($app.download_url)" -ForegroundColor White
                Write-Host "  Filename: $($app.filename)" -ForegroundColor White
            }

            return @{
                success = $true
                applications = $response
            }
        }
    }
} catch {
    Write-Log "API request failed: $($_.Exception.Message)" "ERROR"

    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Log "HTTP Status Code: $statusCode" "ERROR"

        if ($statusCode -eq 401) {
            Write-Log "Authentication failed. Check your token and permissions." "ERROR"
        } elseif ($statusCode -eq 404) {
            Write-Log "Resource not found. Check the organization/repository name." "ERROR"
        } elseif ($statusCode -eq 403) {
            Write-Log "Forbidden. Your token may not have the required permissions." "ERROR"
        }
    }

    return @{
        success = $false
        error = $_.Exception.Message
    }
}

Write-Log "API test completed successfully" "SUCCESS"
