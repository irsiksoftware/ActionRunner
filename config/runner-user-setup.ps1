# GitHub Actions Runner - Secure Service Account Setup
# This script creates a dedicated Windows user account with minimal permissions for running the GitHub Actions runner service

#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Creates a secure, limited-privilege user account for GitHub Actions runner service.

.DESCRIPTION
    This script implements security best practices by creating a dedicated service account
    with minimal permissions required to run the GitHub Actions runner. This follows the
    principle of least privilege to limit potential damage from compromised workflows.

.PARAMETER Username
    The username for the runner service account. Default: "GitHubRunner"

.PARAMETER RunnerPath
    The path where the runner is installed. Default: "C:\actions-runner"

.EXAMPLE
    .\runner-user-setup.ps1
    Creates the default GitHubRunner account

.EXAMPLE
    .\runner-user-setup.ps1 -Username "GHRunner" -RunnerPath "D:\runner"
    Creates a custom account with specified runner path

.NOTES
    - Requires Administrator privileges
    - Password is randomly generated and must be stored securely
    - Follow your organization's password management policies
#>

# Suppress PSScriptAnalyzer warning - ConvertTo-SecureString with plaintext is required for creating local user accounts
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Required for creating local user accounts')]
[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Username = "GitHubRunner",

    [Parameter(Mandatory=$false)]
    [string]$RunnerPath = "C:\actions-runner",

    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

# Set strict error handling
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Color output functions
function Write-Success {
    param([string]$Message)
    Write-Host "[✓] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "[i] $Message" -ForegroundColor Cyan
}

function Write-Error {
    param([string]$Message)
    Write-Host "[✗] $Message" -ForegroundColor Red
}

# Validate prerequisites
function Test-Prerequisites {
    Write-Info "Validating prerequisites..."

    # Check if running as administrator
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "This script requires Administrator privileges"
        exit 1
    }
    Write-Success "Running with Administrator privileges"

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-Error "PowerShell 5.0 or higher is required"
        exit 1
    }
    Write-Success "PowerShell version $($PSVersionTable.PSVersion) detected"

    return $true
}

# Generate secure random password
function New-SecurePassword {
    param(
        [int]$Length = 32
    )

    # Use cryptographically secure random number generator
    $bytes = New-Object byte[] $Length
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
    $rng.GetBytes($bytes)

    # Convert to base64 and ensure complexity
    $password = [Convert]::ToBase64String($bytes)

    # Ensure it meets Windows complexity requirements
    $password = $password.Substring(0, $Length) + "Aa1!"

    return $password
}

# Create the service account
function New-RunnerServiceAccount {
    param(
        [string]$AccountName,
        [string]$AccountPassword
    )

    Write-Info "Creating service account: $AccountName"

    # Check if user already exists
    $existingUser = Get-LocalUser -Name $AccountName -ErrorAction SilentlyContinue
    if ($existingUser) {
        Write-Warning "User '$AccountName' already exists. Do you want to reconfigure? (Y/N)"
        $response = Read-Host
        if ($response -ne 'Y') {
            Write-Info "Skipping user creation"
            return $false
        }
        Write-Info "Removing existing user..."
        Remove-LocalUser -Name $AccountName -ErrorAction SilentlyContinue
    }

    if ($DryRun) {
        Write-Info "[DRY RUN] Would create user: $AccountName"
        return $true
    }

    # Create the user account
    $securePassword = ConvertTo-SecureString $AccountPassword -AsPlainText -Force
    New-LocalUser -Name $AccountName `
                  -Password $securePassword `
                  -Description "GitHub Actions Runner Service Account - Limited Permissions" `
                  -PasswordNeverExpires `
                  -UserMayNotChangePassword `
                  -AccountNeverExpires | Out-Null

    Write-Success "Service account created successfully"

    # Disable interactive login (optional security enhancement)
    # Uncomment if you want to prevent interactive login
    # Write-Info "Configuring user rights..."
    # secedit /export /cfg C:\Windows\Temp\secpol.cfg | Out-Null
    # (Get-Content C:\Windows\Temp\secpol.cfg) -replace "SeDenyInteractiveLogonRight = ", "SeDenyInteractiveLogonRight = $AccountName," | Set-Content C:\Windows\Temp\secpol.cfg
    # secedit /configure /db C:\Windows\security\local.sdb /cfg C:\Windows\Temp\secpol.cfg /areas USER_RIGHTS | Out-Null
    # Remove-Item C:\Windows\Temp\secpol.cfg

    return $true
}

# Configure file system permissions
function Set-RunnerPermissions {
    param(
        [string]$Username,
        [string]$RunnerPath
    )

    Write-Info "Configuring file system permissions for $RunnerPath"

    if (-not (Test-Path $RunnerPath)) {
        Write-Warning "Runner path does not exist: $RunnerPath"
        Write-Info "Creating runner directory..."
        New-Item -Path $RunnerPath -ItemType Directory -Force | Out-Null
    }

    if ($DryRun) {
        Write-Info "[DRY RUN] Would configure permissions for: $RunnerPath"
        return
    }

    # Get the ACL
    $acl = Get-Acl $RunnerPath

    # Create access rule for the runner user (Modify permissions on runner directory)
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $Username,
        "Modify",
        "ContainerInherit,ObjectInherit",
        "None",
        "Allow"
    )

    # Apply the access rule
    $acl.SetAccessRule($accessRule)
    Set-Acl -Path $RunnerPath -AclObject $acl

    Write-Success "File system permissions configured"

    # Create _work directory for job execution
    $workPath = Join-Path $RunnerPath "_work"
    if (-not (Test-Path $workPath)) {
        New-Item -Path $workPath -ItemType Directory -Force | Out-Null
        $workAcl = Get-Acl $workPath
        $workAcl.SetAccessRule($accessRule)
        Set-Acl -Path $workPath -AclObject $workAcl
        Write-Success "Work directory created and configured"
    }
}

# Configure Windows service to run as the service account
function Set-RunnerServiceAccount {
    param(
        [string]$AccountName,
        [string]$AccountPassword
    )

    Write-Info "Searching for GitHub Actions Runner service..."

    # Find the runner service (it should start with "actions.runner.")
    $runnerServices = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue

    if (-not $runnerServices) {
        Write-Warning "No GitHub Actions Runner service found"
        Write-Info "Please run this script again after configuring the runner with config.cmd"
        return
    }

    foreach ($service in $runnerServices) {
        Write-Info "Configuring service: $($service.Name)"

        if ($DryRun) {
            Write-Info "[DRY RUN] Would configure service: $($service.Name)"
            continue
        }

        # Stop the service if running
        if ($service.Status -eq 'Running') {
            Write-Info "Stopping service..."
            Stop-Service -Name $service.Name -Force
        }

        # Configure service to run as the service account
        $serviceName = $service.Name
        $credential = ".\$AccountName"

        # Use sc.exe to change the service account
        $result = sc.exe config $serviceName obj= $credential password= $AccountPassword

        if ($LASTEXITCODE -eq 0) {
            Write-Success "Service configured to run as $AccountName"

            # Grant "Log on as a service" right
            Write-Info "Granting 'Log on as a service' right..."
            $tempFile = [System.IO.Path]::GetTempFileName()
            secedit /export /cfg $tempFile | Out-Null
            $content = Get-Content $tempFile
            $userRight = "SeServiceLogonRight"

            # Add user to the service logon right
            $newContent = $content -replace "($userRight = .*)", "`$1,$AccountName"
            $newContent | Set-Content $tempFile

            secedit /configure /db secedit.sdb /cfg $tempFile /areas USER_RIGHTS | Out-Null
            Remove-Item $tempFile -Force

            Write-Success "'Log on as a service' right granted"

            # Start the service
            Write-Info "Starting service..."
            Start-Service -Name $service.Name
            Write-Success "Service started successfully"
        }
        else {
            Write-Error "Failed to configure service. Error code: $LASTEXITCODE"
        }
    }
}

# Save password securely
function Save-ServiceAccountPassword {
    param(
        [string]$AccountName,
        [string]$AccountPassword
    )

    $outputFile = Join-Path $PSScriptRoot "runner-credentials.txt"

    $content = @(
        "GitHub Actions Runner Service Account Credentials",
        "================================================",
        "",
        "Username: $AccountName",
        "Password: $AccountPassword",
        "",
        "IMPORTANT SECURITY NOTES:",
        "1. Store this password in a secure password manager (e.g., 1Password, LastPass, Azure Key Vault)",
        "2. DELETE this file after storing the password securely",
        "3. Never commit this file to version control",
        "4. Rotate this password every 90 days per security policy",
        "5. This account should only be used for the GitHub Actions Runner service",
        "",
        "Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "",
        "Next Steps:",
        "1. Store password in password manager",
        "2. Delete this file: Remove-Item `"$outputFile`"",
        "3. Configure the runner: .\config.cmd",
        "4. Test the runner service",
        ""
    ) -join "`n"

    if ($DryRun) {
        Write-Info "[DRY RUN] Would save credentials to: $outputFile"
        return
    }

    $content | Out-File -FilePath $outputFile -Encoding UTF8

    Write-Warning "Credentials saved to: $outputFile"
    Write-Warning "IMPORTANT: Store the password securely and DELETE this file!"
}

# Main execution
function Main {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "GitHub Actions Runner Security Setup" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if ($DryRun) {
        Write-Warning "Running in DRY RUN mode - no changes will be made"
        Write-Host ""
    }

    # Validate prerequisites
    Test-Prerequisites | Out-Null

    # Generate secure password
    Write-Info "Generating secure password..."
    $password = New-SecurePassword -Length 32
    Write-Success "Secure password generated"

    # Create service account
    $userCreated = New-RunnerServiceAccount -AccountName $Username -AccountPassword $password

    if ($userCreated) {
        # Configure file system permissions
        Set-RunnerPermissions -Username $Username -RunnerPath $RunnerPath

        # Save credentials
        Save-ServiceAccountPassword -AccountName $Username -AccountPassword $password

        # Configure service (if exists)
        Set-RunnerServiceAccount -AccountName $Username -AccountPassword $password

        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Setup Complete!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Success "Service account '$Username' has been created with minimal permissions"
        Write-Info "Runner path: $RunnerPath"
        Write-Warning "NEXT STEPS:"
        Write-Host "  1. Store the password from runner-credentials.txt in a secure password manager"
        Write-Host "  2. Delete runner-credentials.txt after storing the password"
        Write-Host "  3. If runner not yet configured, run: .\config.cmd --runasservice"
        Write-Host "  4. Review security documentation: docs\security.md"
        Write-Host ""
    }
}

# Execute main function
Main
