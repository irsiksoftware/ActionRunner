# Error Handling Standards

This document outlines the standardized error handling approach used across all ActionRunner PowerShell scripts.

## Overview

ActionRunner uses a consistent error handling framework to ensure:
- Uniform error messages across all scripts
- Clear categorization of error types
- Actionable remediation guidance
- Simplified debugging and troubleshooting

## Common Error Handling Module

All scripts should utilize the `scripts/common-error-handling.ps1` module by dot-sourcing it at the beginning:

```powershell
. "$PSScriptRoot\common-error-handling.ps1"
```

## Error Categories

The framework defines the following error categories:

| Category | Description | Use Cases |
|----------|-------------|-----------|
| `Configuration` | Configuration-related errors | Invalid config files, missing settings |
| `Network` | Network connectivity issues | API failures, unreachable hosts |
| `Authentication` | Authentication/authorization failures | Invalid tokens, insufficient permissions |
| `FileSystem` | File system operations | Missing files, permission denied |
| `Validation` | Input validation failures | Invalid parameters, missing requirements |
| `External` | External tool/dependency errors | Missing commands, tool failures |
| `Runtime` | Runtime execution errors | Unexpected failures, operation errors |

## Standard Functions

### Throw-ActionRunnerError

Throws a standardized error with category and remedy information.

```powershell
Throw-ActionRunnerError `
    -Message "Failed to connect to GitHub API" `
    -Category Network `
    -Remedy "Check internet connection and firewall settings"
```

### Assert-RequiredParameters

Validates that required parameters are not null or empty.

```powershell
Assert-RequiredParameters @{
    "OrgOrRepo" = $OrgOrRepo
    "Token" = $Token
}
```

### Assert-PathExists

Validates that a path exists and is of the expected type.

```powershell
# Validate directory exists
Assert-PathExists -Path "C:\actions-runner" -PathType Directory

# Validate file exists
Assert-PathExists -Path "C:\config.json" -PathType File

# Validate path exists (any type)
Assert-PathExists -Path "C:\some-path" -PathType Any
```

### Assert-NetworkConnectivity

Validates network connectivity to a host and port.

```powershell
Assert-NetworkConnectivity -HostName "github.com" -Port 443
```

### Assert-CommandExists

Validates that a command exists in PATH.

```powershell
Assert-CommandExists `
    -CommandName "git" `
    -InstallInstructions "Install from https://git-scm.com/"
```

### Invoke-ActionRunnerWebRequest

Invokes a web request with standardized error handling.

```powershell
$response = Invoke-ActionRunnerWebRequest `
    -Uri "https://api.github.com/user" `
    -Method GET `
    -Headers @{
        "Authorization" = "Bearer $token"
    }
```

### Invoke-WithRetry

Executes a script block with retry logic.

```powershell
Invoke-WithRetry `
    -ScriptBlock { docker pull image:latest } `
    -MaxRetries 3 `
    -RetryDelaySeconds 5 `
    -ErrorMessage "Failed to pull Docker image"
```

### Assert-Administrator

Validates administrator privileges.

```powershell
# Throw error if not administrator
Assert-Administrator -Required $true

# Check without throwing
$isAdmin = Assert-Administrator -Required $false
```

## Best Practices

### 1. Use Standardized Functions

**Do:**
```powershell
Assert-PathExists -Path $ConfigPath -PathType File
```

**Don't:**
```powershell
if (-not (Test-Path $ConfigPath)) {
    throw "Config file not found"
}
```

### 2. Provide Clear Error Messages

**Do:**
```powershell
Throw-ActionRunnerError `
    -Message "Failed to download runner version $version from GitHub" `
    -Category Network `
    -Remedy "Check internet connection and verify GitHub is accessible"
```

**Don't:**
```powershell
throw "Download failed"
```

### 3. Categorize Errors Appropriately

Choose the correct error category to help with troubleshooting:

```powershell
# Configuration issue
Throw-ActionRunnerError `
    -Message "Invalid runner configuration in config.json" `
    -Category Configuration `
    -Remedy "Verify configuration file format and required fields"

# Network issue
Throw-ActionRunnerError `
    -Message "Cannot reach Docker registry" `
    -Category Network `
    -Remedy "Check network connectivity and proxy settings"
```

### 4. Validate Early

Validate inputs and prerequisites at the start of scripts:

```powershell
# Validate required parameters
Assert-RequiredParameters @{
    "OrgOrRepo" = $OrgOrRepo
    "Token" = $Token
    "RunnerName" = $RunnerName
}

# Validate required commands
Assert-CommandExists -CommandName "git" -InstallInstructions "Install Git from https://git-scm.com/"
Assert-CommandExists -CommandName "docker" -InstallInstructions "Install Docker Desktop"

# Validate paths
Assert-PathExists -Path $WorkFolder -PathType Directory
```

### 5. Use Retry for Transient Failures

Use retry logic for operations that may fail transiently:

```powershell
# Network operations
$response = Invoke-WithRetry `
    -ScriptBlock {
        Invoke-ActionRunnerWebRequest -Uri $apiUrl -Method GET
    } `
    -MaxRetries 3 `
    -ErrorMessage "Failed to fetch API data"

# Docker operations
Invoke-WithRetry `
    -ScriptBlock { docker pull $imageName } `
    -MaxRetries 3 `
    -RetryDelaySeconds 10 `
    -ErrorMessage "Failed to pull Docker image $imageName"
```

### 6. Set ErrorActionPreference Appropriately

At the start of scripts, set the error action preference:

```powershell
# For strict error handling (recommended for most scripts)
$ErrorActionPreference = "Stop"

# For scripts that need to continue on errors (like health checks)
$ErrorActionPreference = "Continue"
```

## Migration Guide

To migrate existing scripts to use the standardized error handling:

1. **Add the module reference:**
   ```powershell
   . "$PSScriptRoot\common-error-handling.ps1"
   ```

2. **Replace parameter validation:**
   ```powershell
   # Before
   if (-not $Token) {
       throw "Token is required"
   }

   # After
   Assert-RequiredParameters @{ "Token" = $Token }
   ```

3. **Replace path checks:**
   ```powershell
   # Before
   if (-not (Test-Path $ConfigPath)) {
       throw "Config not found"
   }

   # After
   Assert-PathExists -Path $ConfigPath -PathType File
   ```

4. **Replace web requests:**
   ```powershell
   # Before
   try {
       $response = Invoke-RestMethod -Uri $uri
   } catch {
       throw "API call failed: $_"
   }

   # After
   $response = Invoke-ActionRunnerWebRequest -Uri $uri
   ```

5. **Replace error throws:**
   ```powershell
   # Before
   throw "Operation failed: $($_.Exception.Message)"

   # After
   Throw-ActionRunnerError `
       -Message "Operation failed: $($_.Exception.Message)" `
       -Category Runtime `
       -Remedy "Review logs and retry the operation"
   ```

## Testing

All error handling functions are tested in `tests/common-error-handling.Tests.ps1`. Run tests with:

```powershell
Invoke-Pester -Path .\tests\common-error-handling.Tests.ps1
```

## Examples

### Complete Script Example

```powershell
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Example script using standardized error handling
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $true)]
    [string]$ApiToken
)

# Dot-source the error handling module
. "$PSScriptRoot\common-error-handling.ps1"

$ErrorActionPreference = "Stop"

try {
    # Validate parameters
    Assert-RequiredParameters @{
        "ConfigPath" = $ConfigPath
        "ApiToken" = $ApiToken
    }

    # Validate paths
    Assert-PathExists -Path $ConfigPath -PathType File

    # Validate commands
    Assert-CommandExists -CommandName "docker" -InstallInstructions "Install Docker Desktop"

    # Validate network connectivity
    Assert-NetworkConnectivity -HostName "api.github.com" -Port 443

    # Make API request with retry
    $response = Invoke-WithRetry `
        -ScriptBlock {
            Invoke-ActionRunnerWebRequest `
                -Uri "https://api.github.com/user" `
                -Headers @{ "Authorization" = "Bearer $ApiToken" }
        } `
        -MaxRetries 3 `
        -ErrorMessage "Failed to authenticate with GitHub API"

    Write-Host "Success: $($response.login)"
}
catch [ActionRunnerException] {
    Write-Host "Error [$($_.Exception.Category)]: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Remedy: $($_.Exception.Remedy)" -ForegroundColor Yellow
    exit 1
}
catch {
    Write-Host "Unexpected error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
```

## Additional Resources

- [PowerShell Error Handling Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-exceptions)
- [Pester Testing Framework](https://pester.dev/)
- ActionRunner Issue #95: Standardize error handling across all scripts
