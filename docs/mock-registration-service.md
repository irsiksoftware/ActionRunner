# Mock Runner Registration Service

## Overview

The Mock Runner Registration Service is a PowerShell-based HTTP server that simulates the GitHub Actions runner registration API. It enables testing of runner registration workflows without requiring a real GitHub API token or repository access.

## Features

- **Token Generation**: Simulates GitHub API registration token generation
- **Runner Management**: Tracks registered mock runners
- **Authentication**: Optional Bearer token validation
- **Multiple Endpoints**: Supports organization and repository registration flows
- **Health Monitoring**: Built-in health check endpoint
- **Request Logging**: Comprehensive logging of all API requests
- **Reset Capability**: Reset mock data for clean test runs

## Usage

### Starting the Service

```powershell
# Start with default settings (port 8080)
.\scripts\mock-registration-service.ps1

# Start on custom port
.\scripts\mock-registration-service.ps1 -Port 9000

# Start without authentication
.\scripts\mock-registration-service.ps1 -EnableAuth $false

# Specify custom log file
.\scripts\mock-registration-service.ps1 -LogFile "logs/custom-mock.log"
```

### Available Endpoints

#### Health Check
```powershell
Invoke-RestMethod -Uri "http://localhost:8080/health" -Method Get
```

Response:
```json
{
  "status": "healthy",
  "uptime": "00:05:23.1234567",
  "request_count": 10,
  "registered_runners": 2
}
```

#### Get Latest Runner Release
```powershell
Invoke-RestMethod -Uri "http://localhost:8080/repos/actions/runner/releases/latest" -Method Get
```

Response:
```json
{
  "tag_name": "v2.311.0",
  "name": "v2.311.0",
  "assets": [
    {
      "name": "actions-runner-win-x64-2.311.0.zip",
      "browser_download_url": "https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-win-x64-2.311.0.zip",
      "size": 123456789
    }
  ]
}
```

#### Organization Registration Token
```powershell
$headers = @{ "Authorization" = "Bearer ghp_test123" }
Invoke-RestMethod -Uri "http://localhost:8080/orgs/my-org/actions/runners/registration-token" -Method Post -Headers $headers
```

Response:
```json
{
  "token": "MOCK_REG_abc123...",
  "expires_at": "2024-01-01T13:00:00Z"
}
```

#### Repository Registration Token
```powershell
$headers = @{ "Authorization" = "Bearer ghp_test123" }
Invoke-RestMethod -Uri "http://localhost:8080/repos/owner/repo/actions/runners/registration-token" -Method Post -Headers $headers
```

Response:
```json
{
  "token": "MOCK_REG_xyz789...",
  "expires_at": "2024-01-01T13:00:00Z"
}
```

#### List Runners (Organization)
```powershell
$headers = @{ "Authorization" = "Bearer ghp_test123" }
Invoke-RestMethod -Uri "http://localhost:8080/orgs/my-org/actions/runners" -Method Get -Headers $headers
```

Response:
```json
{
  "total_count": 2,
  "runners": [
    {
      "id": 1234,
      "name": "runner-1",
      "os": "windows",
      "status": "online",
      "labels": ["self-hosted", "windows", "dotnet"],
      "busy": false,
      "created_at": "2024-01-01T12:00:00Z"
    }
  ]
}
```

#### Reset Mock Data
```powershell
Invoke-RestMethod -Uri "http://localhost:8080/reset" -Method Post
```

Response:
```json
{
  "message": "Mock data reset successfully"
}
```

## Testing with register-runner.ps1

You can test the `register-runner.ps1` script against the mock service by modifying the GitHub API URLs:

### Step 1: Start Mock Service
```powershell
.\scripts\mock-registration-service.ps1 -Port 8080 -EnableAuth $false
```

### Step 2: Modify register-runner.ps1 (for testing only)
Temporarily change the API URLs in `register-runner.ps1`:

```powershell
# Change from:
$tokenUrl = "https://api.github.com/orgs/$OrgOrRepo/actions/runners/registration-token"

# To:
$tokenUrl = "http://localhost:8080/orgs/$OrgOrRepo/actions/runners/registration-token"
```

### Step 3: Test Registration
```powershell
.\scripts\register-runner.ps1 -OrgOrRepo "test-org" -Token "ghp_test123" -IsOrg
```

## Authentication

When authentication is enabled (`-EnableAuth $true`), the service validates Bearer tokens:

- **Valid formats**: `ghp_*` or `github_pat_*`
- **Invalid formats**: Any other token format will return 401 Unauthorized

Example with authentication:
```powershell
# Valid
$headers = @{ "Authorization" = "Bearer ghp_1234567890" }
Invoke-RestMethod -Uri "http://localhost:8080/orgs/test-org/actions/runners/registration-token" -Method Post -Headers $headers

# Invalid - will return 401
$headers = @{ "Authorization" = "Bearer invalid_token" }
Invoke-RestMethod -Uri "http://localhost:8080/orgs/test-org/actions/runners/registration-token" -Method Post -Headers $headers
```

## Logging

The service logs all requests and responses to the specified log file (default: `logs/mock-registration.log`).

Log format:
```
[2024-01-01 12:00:00] [INFO] Starting mock GitHub runner registration service...
[2024-01-01 12:00:00] [SUCCESS] Mock service started successfully
[2024-01-01 12:00:05] [INFO] Request #1: POST /orgs/test-org/actions/runners/registration-token
[2024-01-01 12:00:05] [SUCCESS] Generated registration token for test-org (IsOrg: True)
[2024-01-01 12:00:05] [INFO] Response: 200 (156 bytes)
```

## Running Tests

```powershell
# Run all tests
Invoke-Pester -Path .\tests\mock-registration-service.Tests.ps1

# Run specific test suite
Invoke-Pester -Path .\tests\mock-registration-service.Tests.ps1 -Tag "Integration"

# Run with detailed output
Invoke-Pester -Path .\tests\mock-registration-service.Tests.ps1 -Output Detailed
```

Note: Integration tests that start a real HTTP server are skipped by default. To run them, remove the `-Skip` flag from the test definitions.

## Use Cases

1. **CI/CD Testing**: Test runner registration workflows in automated pipelines
2. **Local Development**: Develop and debug runner scripts without GitHub API access
3. **Integration Testing**: Verify runner registration logic without external dependencies
4. **Load Testing**: Test registration service performance with multiple concurrent requests
5. **Error Scenario Testing**: Simulate various API error conditions

## Limitations

- Mock service is for testing purposes only
- Does not perform actual runner registration with GitHub
- Generated tokens are not valid for real GitHub API
- Does not persist data between restarts
- Single-threaded HTTP server (not suitable for high concurrency)

## Security Notes

- Never expose this service to the internet
- Only run on localhost/trusted networks
- Use authentication (`-EnableAuth $true`) when testing security-sensitive scenarios
- Mock tokens should never be used with real GitHub API

## Troubleshooting

### Port Already in Use
```powershell
# Use a different port
.\scripts\mock-registration-service.ps1 -Port 9000
```

### Service Won't Start
```powershell
# Check if another process is using the port
Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue

# Run with elevated permissions if needed
Start-Process powershell -Verb RunAs -ArgumentList "-File .\scripts\mock-registration-service.ps1"
```

### Authentication Errors
```powershell
# Disable authentication for testing
.\scripts\mock-registration-service.ps1 -EnableAuth $false
```

## Contributing

When adding new endpoints or modifying existing ones:

1. Update the endpoint routing in `Handle-Request` function
2. Add corresponding tests in `mock-registration-service.Tests.ps1`
3. Update this documentation with new endpoint details
4. Ensure backward compatibility with existing tests
