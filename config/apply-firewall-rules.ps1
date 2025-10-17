# GitHub Actions Runner - Firewall Rules Application Script
# Applies Windows Firewall rules based on firewall-rules.yaml configuration

#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Applies Windows Firewall rules for GitHub Actions Runner security.

.DESCRIPTION
    This script configures Windows Firewall to implement defense-in-depth network security
    for the GitHub Actions self-hosted runner. It creates rules based on the firewall-rules.yaml
    configuration file.

.PARAMETER ConfigFile
    Path to the firewall rules YAML configuration file.

.PARAMETER RemoveExisting
    Remove existing runner firewall rules before applying new ones.

.PARAMETER DryRun
    Show what would be changed without making actual changes.

.EXAMPLE
    .\apply-firewall-rules.ps1
    Applies firewall rules from the default config file

.EXAMPLE
    .\apply-firewall-rules.ps1 -DryRun
    Shows what rules would be created without applying them

.EXAMPLE
    .\apply-firewall-rules.ps1 -RemoveExisting
    Removes existing rules and applies new ones

.NOTES
    - Requires Administrator privileges
    - Review rules before applying in production
    - Customize IP addresses and ranges for your environment
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = (Join-Path $PSScriptRoot "firewall-rules.yaml"),

    [Parameter(Mandatory=$false)]
    [switch]$RemoveExisting,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Color output functions
function Write-Success { param([string]$Message) Write-Host "[✓] $Message" -ForegroundColor Green }
function Write-Warning { param([string]$Message) Write-Host "[!] $Message" -ForegroundColor Yellow }
function Write-Info { param([string]$Message) Write-Host "[i] $Message" -ForegroundColor Cyan }
function Write-Error { param([string]$Message) Write-Host "[✗] $Message" -ForegroundColor Red }

# Validate prerequisites
function Test-Prerequisites {
    Write-Info "Validating prerequisites..."

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "This script requires Administrator privileges"
        exit 1
    }

    if (-not (Test-Path $ConfigFile)) {
        Write-Error "Configuration file not found: $ConfigFile"
        exit 1
    }

    Write-Success "Prerequisites validated"
}

# Remove existing runner firewall rules
function Remove-ExistingRules {
    Write-Info "Removing existing GitHub Actions Runner firewall rules..."

    $existingRules = Get-NetFirewallRule -DisplayName "GitHub Actions Runner*" -ErrorAction SilentlyContinue

    if ($existingRules) {
        if ($DryRun) {
            Write-Info "[DRY RUN] Would remove $($existingRules.Count) existing rules"
            return
        }

        foreach ($rule in $existingRules) {
            Remove-NetFirewallRule -Name $rule.Name
            Write-Success "Removed rule: $($rule.DisplayName)"
        }
    }
    else {
        Write-Info "No existing rules found"
    }
}

# Apply firewall rules
function Set-FirewallRules {
    Write-Info "Applying firewall rules..."

    # INBOUND RULES

    # Block all inbound by default
    if ($DryRun) {
        Write-Info "[DRY RUN] Would create inbound block rule"
    }
    else {
        New-NetFirewallRule -DisplayName "GitHub Actions Runner - Block All Inbound" `
            -Description "Default deny all inbound traffic to runner" `
            -Direction Inbound `
            -Action Block `
            -Protocol Any `
            -Profile Any `
            -Enabled True | Out-Null
        Write-Success "Created: Block All Inbound"
    }

    # Allow RDP from specific IP (CUSTOMIZE THIS)
    Write-Warning "IMPORTANT: Customize the RemoteAddress parameter for your environment!"
    if ($DryRun) {
        Write-Info "[DRY RUN] Would create RDP allow rule"
    }
    else {
        # Uncomment and customize after reviewing your network requirements
        <#
        New-NetFirewallRule -DisplayName "GitHub Actions Runner - RDP Admin Access" `
            -Description "Allow RDP for administrative access" `
            -Direction Inbound `
            -Action Allow `
            -Protocol TCP `
            -LocalPort 3389 `
            -RemoteAddress "10.0.1.10" `
            -Profile Domain,Private `
            -Enabled True | Out-Null
        Write-Success "Created: RDP Admin Access"
        #>
        Write-Warning "RDP rule commented out - customize RemoteAddress in script first"
    }

    # OUTBOUND RULES

    # Allow DNS
    if ($DryRun) {
        Write-Info "[DRY RUN] Would create DNS allow rule"
    }
    else {
        New-NetFirewallRule -DisplayName "GitHub Actions Runner - DNS" `
            -Description "Allow DNS queries" `
            -Direction Outbound `
            -Action Allow `
            -Protocol UDP `
            -RemotePort 53 `
            -Profile Any `
            -Enabled True | Out-Null
        Write-Success "Created: DNS Outbound"
    }

    # Allow HTTPS to GitHub (all IPs - customize for stricter control)
    if ($DryRun) {
        Write-Info "[DRY RUN] Would create GitHub HTTPS allow rule"
    }
    else {
        New-NetFirewallRule -DisplayName "GitHub Actions Runner - GitHub HTTPS" `
            -Description "Allow HTTPS to GitHub services" `
            -Direction Outbound `
            -Action Allow `
            -Protocol TCP `
            -RemotePort 443 `
            -Profile Any `
            -Enabled True | Out-Null
        Write-Success "Created: GitHub HTTPS Outbound"
    }

    # Allow Windows Update
    if ($DryRun) {
        Write-Info "[DRY RUN] Would create Windows Update allow rule"
    }
    else {
        New-NetFirewallRule -DisplayName "GitHub Actions Runner - Windows Update" `
            -Description "Allow Windows Update" `
            -Direction Outbound `
            -Action Allow `
            -Protocol TCP `
            -RemotePort 443 `
            -Program "%SystemRoot%\System32\svchost.exe" `
            -Service wuauserv `
            -Profile Any `
            -Enabled True | Out-Null
        Write-Success "Created: Windows Update Outbound"
    }

    # Allow NTP
    if ($DryRun) {
        Write-Info "[DRY RUN] Would create NTP allow rule"
    }
    else {
        New-NetFirewallRule -DisplayName "GitHub Actions Runner - NTP" `
            -Description "Allow NTP time synchronization" `
            -Direction Outbound `
            -Action Allow `
            -Protocol UDP `
            -RemotePort 123 `
            -Profile Any `
            -Enabled True | Out-Null
        Write-Success "Created: NTP Outbound"
    }

    # Block all other outbound
    if ($DryRun) {
        Write-Info "[DRY RUN] Would create outbound block rule"
    }
    else {
        New-NetFirewallRule -DisplayName "GitHub Actions Runner - Block All Other Outbound" `
            -Description "Default deny all other outbound traffic" `
            -Direction Outbound `
            -Action Block `
            -Protocol Any `
            -Profile Any `
            -Enabled True | Out-Null
        Write-Success "Created: Block All Other Outbound"
    }
}

# Enable firewall logging
function Enable-FirewallLogging {
    Write-Info "Enabling firewall logging..."

    if ($DryRun) {
        Write-Info "[DRY RUN] Would enable firewall logging"
        return
    }

    # Enable logging for all profiles
    Set-NetFirewallProfile -Profile Domain,Public,Private -LogAllowed True -LogBlocked True -LogMaxSizeKilobytes 16384

    $logPath = "$env:SystemRoot\System32\LogFiles\Firewall\pfirewall.log"
    Write-Success "Firewall logging enabled: $logPath"
}

# Display summary
function Show-Summary {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Firewall Configuration Summary" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green

    $rules = Get-NetFirewallRule -DisplayName "GitHub Actions Runner*" -ErrorAction SilentlyContinue

    if ($rules) {
        Write-Host ""
        Write-Host "Active Rules:" -ForegroundColor Cyan
        foreach ($rule in $rules) {
            $status = if ($rule.Enabled) { "Enabled" } else { "Disabled" }
            Write-Host "  - $($rule.DisplayName) [$status]" -ForegroundColor $(if ($rule.Enabled) { "Green" } else { "Yellow" })
        }
    }

    Write-Host ""
    Write-Warning "IMPORTANT NEXT STEPS:"
    Write-Host "  1. Review the created rules: Get-NetFirewallRule -DisplayName 'GitHub Actions Runner*'"
    Write-Host "  2. Customize IP addresses for your environment in firewall-rules.yaml"
    Write-Host "  3. Test runner connectivity to GitHub"
    Write-Host "  4. Monitor firewall logs: $env:SystemRoot\System32\LogFiles\Firewall\pfirewall.log"
    Write-Host "  5. Update GitHub IP ranges monthly from https://api.github.com/meta"
    Write-Host ""
}

# Main execution
function Main {
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "GitHub Actions Runner Firewall Setup" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if ($DryRun) {
        Write-Warning "Running in DRY RUN mode - no changes will be made"
    }

    Test-Prerequisites

    if ($RemoveExisting) {
        Remove-ExistingRules
    }

    Set-FirewallRules

    Enable-FirewallLogging

    Show-Summary
}

# Call Main function to execute the script
Main
