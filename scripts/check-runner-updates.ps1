#Requires -Version 5.1

<#
.SYNOPSIS
    Check for GitHub Actions runner updates and optionally send notifications.

.DESCRIPTION
    This script checks for available runner updates and can:
    - Display update availability in console
    - Send email notifications
    - Write results to a file for automation
    - Check specific or latest versions
    - Exit with status code indicating update availability

.PARAMETER RunnerPath
    Path to runner installation directory (default: C:\actions-runner)

.PARAMETER EmailTo
    Email address to send notifications to

.PARAMETER EmailFrom
    Email address to send notifications from

.PARAMETER SmtpServer
    SMTP server for sending email notifications

.PARAMETER SmtpPort
    SMTP server port (default: 587)

.PARAMETER SmtpCredential
    PSCredential object for SMTP authentication

.PARAMETER OutputFile
    Path to write update check results (JSON format)

.PARAMETER Quiet
    Suppress console output (useful for automation)

.EXAMPLE
    .\check-runner-updates.ps1
    Check for updates and display in console

.EXAMPLE
    .\check-runner-updates.ps1 -EmailTo "admin@example.com" -EmailFrom "runner@example.com" -SmtpServer "smtp.gmail.com"
    Check for updates and send email notification if available

.EXAMPLE
    .\check-runner-updates.ps1 -OutputFile "C:\temp\update-check.json" -Quiet
    Check for updates silently and write results to JSON file

.NOTES
    Author: GitHub Actions Runner Team
    Version: 1.0.0
    Exit Codes:
        0 - No update available or check failed
        1 - Update available
#>

[CmdletBinding()]
param(
    [string]$RunnerPath = "C:\actions-runner",
    [string]$EmailTo,
    [string]$EmailFrom,
    [string]$SmtpServer,
    [int]$SmtpPort = 587,
    [System.Management.Automation.PSCredential]$SmtpCredential,
    [string]$OutputFile,
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

# Function to write output
function Write-UpdateMessage {
    param(
        [string]$Message,
        [string]$Color = "White"
    )

    if (-not $Quiet) {
        Write-Host $Message -ForegroundColor $Color
    }
}

# Function to get current runner version
function Get-CurrentRunnerVersion {
    $configPath = Join-Path $RunnerPath ".runner"

    if (-not (Test-Path $configPath)) {
        return $null
    }

    try {
        $config = Get-Content $configPath | ConvertFrom-Json
        return $config.agentVersion
    } catch {
        return $null
    }
}

# Function to get latest runner version from GitHub API
function Get-LatestRunnerVersion {
    try {
        $apiUrl = "https://api.github.com/repos/actions/runner/releases/latest"
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get

        $latestVersion = $response.tag_name -replace '^v', ''
        $downloadUrl = ($response.assets | Where-Object { $_.name -like "*win-x64-*.zip" }).browser_download_url

        return @{
            Version = $latestVersion
            DownloadUrl = $downloadUrl
            ReleaseNotes = $response.body
            PublishedAt = $response.published_at
            HtmlUrl = $response.html_url
        }
    } catch {
        Write-UpdateMessage "Failed to check for updates: $_" "Red"
        return $null
    }
}

# Function to compare versions
function Compare-RunnerVersion {
    param(
        [string]$CurrentVersion,
        [string]$LatestVersion
    )

    if (-not $CurrentVersion) {
        return $true  # Treat unknown current version as needing update
    }

    try {
        $current = [version]$CurrentVersion
        $latest = [version]$LatestVersion
        return $latest -gt $current
    } catch {
        # Fallback to string comparison if version parsing fails
        return $CurrentVersion -ne $LatestVersion
    }
}

# Function to send email notification
function Send-UpdateNotification {
    param(
        [hashtable]$UpdateInfo
    )

    if (-not $EmailTo -or -not $EmailFrom -or -not $SmtpServer) {
        Write-UpdateMessage "Email parameters not fully specified. Skipping notification." "Yellow"
        return
    }

    try {
        $subject = "GitHub Actions Runner Update Available: v$($UpdateInfo.LatestVersion)"

        $body = @"
A new version of GitHub Actions Runner is available!

Current Version: $($UpdateInfo.CurrentVersion)
Latest Version: $($UpdateInfo.LatestVersion)
Published: $($UpdateInfo.PublishedAt)

Release Notes:
$($UpdateInfo.ReleaseNotes)

Download: $($UpdateInfo.HtmlUrl)

To update the runner, run:
.\scripts\update-runner.ps1

This is an automated notification from the runner update checker.
"@

        $mailParams = @{
            To = $EmailTo
            From = $EmailFrom
            Subject = $subject
            Body = $body
            SmtpServer = $SmtpServer
            Port = $SmtpPort
        }

        if ($SmtpCredential) {
            $mailParams['Credential'] = $SmtpCredential
            $mailParams['UseSsl'] = $true
        }

        Send-MailMessage @mailParams

        Write-UpdateMessage "Email notification sent to $EmailTo" "Green"
    } catch {
        Write-UpdateMessage "Failed to send email notification: $_" "Red"
    }
}

# Function to write output to file
function Write-UpdateOutputFile {
    param(
        [hashtable]$UpdateInfo,
        [string]$FilePath
    )

    try {
        $UpdateInfo | ConvertTo-Json -Depth 5 | Set-Content -Path $FilePath
        Write-UpdateMessage "Update check results written to: $FilePath" "Gray"
    } catch {
        Write-UpdateMessage "Failed to write output file: $_" "Red"
    }
}

# Main execution
try {
    Write-UpdateMessage "`n=== GitHub Actions Runner Update Check ===" "Cyan"
    Write-UpdateMessage "Checking for runner updates..." "Gray"

    # Verify runner path exists
    if (-not (Test-Path $RunnerPath)) {
        Write-UpdateMessage "Runner path not found: $RunnerPath" "Red"
        exit 0
    }

    # Get current version
    $currentVersion = Get-CurrentRunnerVersion

    if ($currentVersion) {
        Write-UpdateMessage "Current version: $currentVersion" "Gray"
    } else {
        Write-UpdateMessage "Could not determine current runner version" "Yellow"
    }

    # Get latest version
    $latest = Get-LatestRunnerVersion

    if (-not $latest) {
        Write-UpdateMessage "Failed to check for latest version" "Red"
        exit 0
    }

    Write-UpdateMessage "Latest version: $($latest.Version)" "Gray"

    # Compare versions
    $updateAvailable = Compare-RunnerVersion -CurrentVersion $currentVersion -LatestVersion $latest.Version

    # Prepare update info
    $updateInfo = @{
        CurrentVersion = $currentVersion
        LatestVersion = $latest.Version
        UpdateAvailable = $updateAvailable
        DownloadUrl = $latest.DownloadUrl
        ReleaseNotes = $latest.ReleaseNotes
        PublishedAt = $latest.PublishedAt
        HtmlUrl = $latest.HtmlUrl
        CheckedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }

    # Display results
    if ($updateAvailable) {
        Write-UpdateMessage "`nUpdate Available!" "Green"
        Write-UpdateMessage "You can update from v$currentVersion to v$($latest.Version)" "Yellow"
        Write-UpdateMessage "`nTo update, run: .\scripts\update-runner.ps1" "Cyan"

        # Send email notification if configured
        if ($EmailTo) {
            Send-UpdateNotification -UpdateInfo $updateInfo
        }

        # Write to output file if specified
        if ($OutputFile) {
            Write-UpdateOutputFile -UpdateInfo $updateInfo -FilePath $OutputFile
        }

        Write-UpdateMessage ""
        exit 1  # Exit code 1 indicates update available
    } else {
        Write-UpdateMessage "`nRunner is up to date!" "Green"

        # Write to output file if specified
        if ($OutputFile) {
            Write-UpdateOutputFile -UpdateInfo $updateInfo -FilePath $OutputFile
        }

        Write-UpdateMessage ""
        exit 0  # Exit code 0 indicates no update available
    }

} catch {
    Write-UpdateMessage "Error during update check: $_" "Red"
    exit 0
}
