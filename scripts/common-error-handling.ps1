<#
.SYNOPSIS
    Common error handling utilities for ActionRunner PowerShell scripts

.DESCRIPTION
    Provides standardized error handling functions and exception types for consistent
    error messages and behaviors across all ActionRunner PowerShell scripts.

.NOTES
    This module should be dot-sourced at the beginning of scripts that require
    standardized error handling:
    . "$PSScriptRoot\common-error-handling.ps1"
#>

# Standard error categories for ActionRunner scripts
enum ErrorCategory {
    Configuration
    Network
    Authentication
    FileSystem
    Validation
    External
    Runtime
}

# Custom exception class for ActionRunner errors
class ActionRunnerException : System.Exception {
    [ErrorCategory]$Category
    [string]$Remedy

    ActionRunnerException([string]$message, [ErrorCategory]$category, [string]$remedy) : base($message) {
        $this.Category = $category
        $this.Remedy = $remedy
    }
}

<#
.SYNOPSIS
    Throws a standardized ActionRunner error

.PARAMETER Message
    The error message describing what went wrong

.PARAMETER Category
    The category of error (Configuration, Network, Authentication, etc.)

.PARAMETER Remedy
    Suggested remedy or next steps to fix the issue

.EXAMPLE
    Throw-ActionRunnerError -Message "Failed to connect to GitHub API" -Category Network -Remedy "Check internet connection and firewall settings"
#>
function Throw-ActionRunnerError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [ErrorCategory]$Category,

        [Parameter(Mandatory = $false)]
        [string]$Remedy = "Review script logs and documentation for troubleshooting steps"
    )

    throw [ActionRunnerException]::new($Message, $Category, $Remedy)
}

<#
.SYNOPSIS
    Validates that required parameters are not null or empty

.PARAMETER Parameters
    Hashtable of parameter names and values to validate

.EXAMPLE
    Assert-RequiredParameters @{
        "OrgOrRepo" = $OrgOrRepo
        "Token" = $Token
    }
#>
function Assert-RequiredParameters {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Parameters
    )

    foreach ($param in $Parameters.GetEnumerator()) {
        if ([string]::IsNullOrWhiteSpace($param.Value)) {
            Throw-ActionRunnerError `
                -Message "Required parameter '$($param.Key)' is null or empty" `
                -Category Validation `
                -Remedy "Provide a valid value for parameter -$($param.Key)"
        }
    }
}

<#
.SYNOPSIS
    Validates that a path exists

.PARAMETER Path
    The path to validate

.PARAMETER PathType
    The expected type: 'File', 'Directory', or 'Any' (default: Any)

.EXAMPLE
    Assert-PathExists -Path "C:\actions-runner" -PathType Directory
#>
function Assert-PathExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [ValidateSet('File', 'Directory', 'Any')]
        [string]$PathType = 'Any'
    )

    if (-not (Test-Path $Path)) {
        Throw-ActionRunnerError `
            -Message "Path does not exist: $Path" `
            -Category FileSystem `
            -Remedy "Verify the path is correct and accessible"
    }

    if ($PathType -eq 'File' -and -not (Test-Path $Path -PathType Leaf)) {
        Throw-ActionRunnerError `
            -Message "Path is not a file: $Path" `
            -Category FileSystem `
            -Remedy "Ensure the path points to a file, not a directory"
    }

    if ($PathType -eq 'Directory' -and -not (Test-Path $Path -PathType Container)) {
        Throw-ActionRunnerError `
            -Message "Path is not a directory: $Path" `
            -Category FileSystem `
            -Remedy "Ensure the path points to a directory, not a file"
    }
}

<#
.SYNOPSIS
    Validates network connectivity to a host

.PARAMETER HostName
    The hostname or IP address to test

.PARAMETER Port
    The port to test (default: 443)

.EXAMPLE
    Assert-NetworkConnectivity -HostName "github.com" -Port 443
#>
function Assert-NetworkConnectivity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName,

        [Parameter(Mandatory = $false)]
        [int]$Port = 443
    )

    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connect = $tcpClient.BeginConnect($HostName, $Port, $null, $null)
        $wait = $connect.AsyncWaitHandle.WaitOne(3000, $false)

        if (-not $wait) {
            throw "Connection timeout"
        }

        $tcpClient.EndConnect($connect)
        $tcpClient.Close()
    }
    catch {
        Throw-ActionRunnerError `
            -Message "Cannot connect to ${HostName}:${Port}" `
            -Category Network `
            -Remedy "Check network connectivity, DNS resolution, and firewall rules"
    }
}

<#
.SYNOPSIS
    Validates that a command exists in PATH

.PARAMETER CommandName
    The name of the command to validate

.PARAMETER InstallInstructions
    Optional installation instructions if command is not found

.EXAMPLE
    Assert-CommandExists -CommandName "git" -InstallInstructions "Install from https://git-scm.com/"
#>
function Assert-CommandExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName,

        [Parameter(Mandatory = $false)]
        [string]$InstallInstructions = "Install the required software and ensure it is in PATH"
    )

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if (-not $command) {
        Throw-ActionRunnerError `
            -Message "Required command not found: $CommandName" `
            -Category Validation `
            -Remedy $InstallInstructions
    }
}

<#
.SYNOPSIS
    Invokes a web request with standardized error handling

.PARAMETER Uri
    The URI to request

.PARAMETER Method
    The HTTP method (default: GET)

.PARAMETER Headers
    Optional headers hashtable

.PARAMETER Body
    Optional request body

.EXAMPLE
    $response = Invoke-ActionRunnerWebRequest -Uri "https://api.github.com" -Headers @{"Authorization" = "Bearer $token"}
#>
function Invoke-ActionRunnerWebRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $false)]
        [string]$Method = "GET",

        [Parameter(Mandatory = $false)]
        [hashtable]$Headers = @{},

        [Parameter(Mandatory = $false)]
        [object]$Body = $null
    )

    try {
        $params = @{
            Uri = $Uri
            Method = $Method
            Headers = $Headers
            UseBasicParsing = $true
        }

        if ($Body) {
            $params.Body = $Body
        }

        return Invoke-RestMethod @params
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $statusDescription = $_.Exception.Response.StatusDescription

        $remedy = switch ($statusCode) {
            401 { "Verify authentication credentials and token permissions" }
            403 { "Check API rate limits and token permissions" }
            404 { "Verify the resource exists and the URL is correct" }
            500 { "Service may be experiencing issues; retry later" }
            default { "Review error details and check service status" }
        }

        Throw-ActionRunnerError `
            -Message "Web request failed: $Method $Uri - $statusCode $statusDescription" `
            -Category Network `
            -Remedy $remedy
    }
}

<#
.SYNOPSIS
    Executes a script block with error handling and optional retry logic

.PARAMETER ScriptBlock
    The script block to execute

.PARAMETER MaxRetries
    Maximum number of retries (default: 0)

.PARAMETER RetryDelaySeconds
    Delay between retries in seconds (default: 5)

.PARAMETER ErrorMessage
    Custom error message if all attempts fail

.EXAMPLE
    Invoke-WithRetry -ScriptBlock { docker pull image:latest } -MaxRetries 3 -ErrorMessage "Failed to pull Docker image"
#>
function Invoke-WithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 0,

        [Parameter(Mandatory = $false)]
        [int]$RetryDelaySeconds = 5,

        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage = "Operation failed after retries"
    )

    $attempt = 0
    $lastError = $null

    while ($attempt -le $MaxRetries) {
        try {
            return & $ScriptBlock
        }
        catch {
            $lastError = $_
            $attempt++

            if ($attempt -le $MaxRetries) {
                Write-Warning "Attempt $attempt failed: $($_.Exception.Message). Retrying in $RetryDelaySeconds seconds..."
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }

    Throw-ActionRunnerError `
        -Message "$ErrorMessage (Attempts: $($attempt)): $($lastError.Exception.Message)" `
        -Category Runtime `
        -Remedy "Review error details and check if the operation can be performed manually"
}

<#
.SYNOPSIS
    Validates administrator privileges

.PARAMETER Required
    If true, throws error when not administrator (default: true)

.EXAMPLE
    Assert-Administrator -Required $true
#>
function Assert-Administrator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [bool]$Required = $true
    )

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin -and $Required) {
        Throw-ActionRunnerError `
            -Message "Administrator privileges required for this operation" `
            -Category Validation `
            -Remedy "Run PowerShell as Administrator and retry the operation"
    }

    return $isAdmin
}

# Note: When dot-sourcing this file, all functions are automatically available
# Export-ModuleMember is only needed when this file is used as a module
