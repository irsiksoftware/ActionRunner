<#
.SYNOPSIS
    Standardized error handling module for GitHub Actions Runner PowerShell scripts.

.DESCRIPTION
    Provides consistent error handling, logging, and exception management across all
    PowerShell scripts in the ActionRunner project.

.NOTES
    Author: GitHub Actions Runner Team
    Version: 1.0.0
    Last Modified: 2025-10-04
#>

#Requires -Version 5.1

# Module-level variables
$script:ErrorLog = $null
$script:ErrorContext = @{}
$script:StrictMode = $false

<#
.SYNOPSIS
    Initializes the error handling module for a script.

.PARAMETER ScriptName
    Name of the script using error handling

.PARAMETER LogPath
    Optional path to error log file

.PARAMETER StrictMode
    If enabled, all errors will cause script termination

.EXAMPLE
    Initialize-ErrorHandling -ScriptName "install-runner" -LogPath "C:\logs\install-runner.log"
#>
function Initialize-ErrorHandling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptName,

        [Parameter(Mandatory = $false)]
        [string]$LogPath,

        [Parameter(Mandatory = $false)]
        [switch]$StrictMode
    )

    $script:ErrorContext = @{
        ScriptName = $ScriptName
        StartTime = Get-Date
        ErrorCount = 0
        WarningCount = 0
    }

    $script:StrictMode = $StrictMode.IsPresent

    if ($LogPath) {
        $script:ErrorLog = $LogPath
        $logDir = Split-Path -Parent $LogPath
        if ($logDir -and -not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
    }

    # Set global error action preference based on mode
    $Global:ErrorActionPreference = if ($StrictMode) { "Stop" } else { "Continue" }

    Write-LogMessage "Error handling initialized for: $ScriptName" -Level "INFO"
}

<#
.SYNOPSIS
    Writes a standardized log message with consistent formatting.

.PARAMETER Message
    The message to log

.PARAMETER Level
    Log level: INFO, SUCCESS, WARN, ERROR, DEBUG

.PARAMETER Exception
    Optional exception object to include details

.EXAMPLE
    Write-LogMessage "Operation completed" -Level "SUCCESS"

.EXAMPLE
    Write-LogMessage "Failed to connect" -Level "ERROR" -Exception $_.Exception
#>
function Write-LogMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO",

        [Parameter(Mandatory = $false)]
        [System.Exception]$Exception
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Add exception details if provided
    if ($Exception) {
        $logMessage += "`n  Exception: $($Exception.Message)"
        if ($Exception.StackTrace) {
            $logMessage += "`n  Stack Trace: $($Exception.StackTrace)"
        }
    }

    # Console output with color coding
    $color = switch ($Level) {
        "ERROR"   { "Red" }
        "WARN"    { "Yellow" }
        "SUCCESS" { "Green" }
        "DEBUG"   { "Gray" }
        default   { "White" }
    }

    Write-Host $logMessage -ForegroundColor $color

    # File logging if configured
    if ($script:ErrorLog) {
        Add-Content -Path $script:ErrorLog -Value $logMessage -ErrorAction SilentlyContinue
    }

    # Update context counters
    if ($Level -eq "ERROR") {
        $script:ErrorContext.ErrorCount++
    }
    elseif ($Level -eq "WARN") {
        $script:ErrorContext.WarningCount++
    }
}

<#
.SYNOPSIS
    Invokes a script block with standardized error handling.

.PARAMETER ScriptBlock
    The code to execute

.PARAMETER ErrorMessage
    Custom error message prefix

.PARAMETER ContinueOnError
    If true, continue execution even on error (overrides StrictMode for this operation)

.PARAMETER SuppressErrors
    If true, suppress error output (still logs)

.OUTPUTS
    Returns the result of the script block if successful, $null on error

.EXAMPLE
    Invoke-WithErrorHandling -ScriptBlock { Get-Service "nonexistent" } -ErrorMessage "Failed to get service"

.EXAMPLE
    $result = Invoke-WithErrorHandling -ScriptBlock { docker ps } -ErrorMessage "Docker command failed" -ContinueOnError
#>
function Invoke-WithErrorHandling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage = "Operation failed",

        [Parameter(Mandatory = $false)]
        [switch]$ContinueOnError,

        [Parameter(Mandatory = $false)]
        [switch]$SuppressErrors
    )

    try {
        $result = & $ScriptBlock
        return $result
    }
    catch {
        $exceptionMessage = "$ErrorMessage`: $($_.Exception.Message)"

        if (-not $SuppressErrors) {
            Write-LogMessage -Message $exceptionMessage -Level "ERROR" -Exception $_.Exception
        }

        # Throw if in strict mode and not continuing on error
        if ($script:StrictMode -and -not $ContinueOnError) {
            throw
        }

        return $null
    }
}

<#
.SYNOPSIS
    Throws a standardized fatal error and exits the script.

.PARAMETER Message
    Error message

.PARAMETER Exception
    Optional exception object

.PARAMETER ExitCode
    Exit code (default: 1)

.EXAMPLE
    Invoke-FatalError -Message "Critical dependency missing" -ExitCode 2
#>
function Invoke-FatalError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [System.Exception]$Exception,

        [Parameter(Mandatory = $false)]
        [int]$ExitCode = 1
    )

    Write-LogMessage -Message "FATAL: $Message" -Level "ERROR" -Exception $Exception

    # Write summary before exit
    if ($script:ErrorContext) {
        Write-ErrorSummary
    }

    exit $ExitCode
}

<#
.SYNOPSIS
    Tests if a prerequisite condition is met and throws error if not.

.PARAMETER Condition
    The condition to test (should evaluate to boolean)

.PARAMETER ErrorMessage
    Error message if condition fails

.PARAMETER ExitOnFailure
    Exit script on failure (default: false)

.OUTPUTS
    Returns $true if condition passes

.EXAMPLE
    Assert-Prerequisite -Condition (Test-Path "C:\required-file.txt") -ErrorMessage "Required file not found"

.EXAMPLE
    Assert-Prerequisite -Condition ($env:TOKEN -ne $null) -ErrorMessage "TOKEN environment variable required" -ExitOnFailure
#>
function Assert-Prerequisite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,

        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage,

        [Parameter(Mandatory = $false)]
        [switch]$ExitOnFailure
    )

    if (-not $Condition) {
        if ($ExitOnFailure) {
            Invoke-FatalError -Message $ErrorMessage
        }
        else {
            Write-LogMessage -Message $ErrorMessage -Level "ERROR"
            if ($script:StrictMode) {
                throw $ErrorMessage
            }
            return $false
        }
    }

    return $true
}

<#
.SYNOPSIS
    Writes a summary of errors and warnings encountered.

.EXAMPLE
    Write-ErrorSummary
#>
function Write-ErrorSummary {
    [CmdletBinding()]
    param()

    if (-not $script:ErrorContext) {
        return
    }

    $duration = (Get-Date) - $script:ErrorContext.StartTime
    $durationStr = "{0:hh\:mm\:ss}" -f $duration

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Error Handling Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Script: $($script:ErrorContext.ScriptName)"
    Write-Host "Duration: $durationStr"
    Write-Host "Errors: $($script:ErrorContext.ErrorCount)" -ForegroundColor $(if ($script:ErrorContext.ErrorCount -gt 0) { "Red" } else { "Green" })
    Write-Host "Warnings: $($script:ErrorContext.WarningCount)" -ForegroundColor $(if ($script:ErrorContext.WarningCount -gt 0) { "Yellow" } else { "Green" })

    if ($script:ErrorLog) {
        Write-Host "Log file: $($script:ErrorLog)"
    }

    Write-Host "========================================`n" -ForegroundColor Cyan
}

<#
.SYNOPSIS
    Gets the current error statistics.

.OUTPUTS
    Returns hashtable with error context information

.EXAMPLE
    $stats = Get-ErrorStatistics
    if ($stats.ErrorCount -gt 0) { exit 1 }
#>
function Get-ErrorStatistics {
    [CmdletBinding()]
    param()

    return $script:ErrorContext.Clone()
}

<#
.SYNOPSIS
    Resets error and warning counters.

.EXAMPLE
    Reset-ErrorCounters
#>
function Reset-ErrorCounters {
    [CmdletBinding()]
    param()

    if ($script:ErrorContext) {
        $script:ErrorContext.ErrorCount = 0
        $script:ErrorContext.WarningCount = 0
    }
}

# Export module functions
Export-ModuleMember -Function @(
    'Initialize-ErrorHandling',
    'Write-LogMessage',
    'Invoke-WithErrorHandling',
    'Invoke-FatalError',
    'Assert-Prerequisite',
    'Write-ErrorSummary',
    'Get-ErrorStatistics',
    'Reset-ErrorCounters'
)
