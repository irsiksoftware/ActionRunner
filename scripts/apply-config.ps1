#Requires -Version 5.1

<#
.SYNOPSIS
    Applies runner configuration from YAML files to GitHub Actions self-hosted runners.

.DESCRIPTION
    This script reads configuration from YAML files and applies settings to:
    - Runner environment variables
    - System paths and directories
    - Resource limits
    - Monitoring thresholds
    - Security settings
    - Docker configuration

    Supports validation, backup, and rollback functionality.

.PARAMETER ConfigFile
    Path to the configuration YAML file (default: config/runner-config.general.yaml)

.PARAMETER Environment
    Environment preset to use (dev, prod, gpu, unity, general)

.PARAMETER Validate
    Only validate the configuration without applying changes

.PARAMETER Backup
    Create backup of current configuration before applying

.PARAMETER Restore
    Restore configuration from backup file

.PARAMETER BackupFile
    Path to backup file for restore operation

.PARAMETER DryRun
    Show what would be changed without making actual changes

.EXAMPLE
    .\apply-config.ps1
    Apply default general configuration

.EXAMPLE
    .\apply-config.ps1 -Environment prod
    Apply production environment configuration

.EXAMPLE
    .\apply-config.ps1 -ConfigFile "config\runner-config.gpu.yaml" -Validate
    Validate GPU configuration without applying

.EXAMPLE
    .\apply-config.ps1 -Environment unity -Backup
    Apply Unity configuration with backup

.EXAMPLE
    .\apply-config.ps1 -Restore -BackupFile "config\backups\config-20251003-120000.yaml"
    Restore configuration from backup

.NOTES
    Author: GitHub Actions Runner Team
    Version: 1.0.0
    Requires: PowerShell-Yaml module (Install-Module -Name powershell-yaml)
#>

[CmdletBinding(DefaultParameterSetName='Apply')]
param(
    [Parameter(ParameterSetName='Apply', Mandatory=$false)]
    [string]$ConfigFile = "config\runner-config.general.yaml",

    [Parameter(ParameterSetName='Apply', Mandatory=$false)]
    [ValidateSet('dev', 'prod', 'gpu', 'unity', 'general')]
    [string]$Environment,

    [Parameter(ParameterSetName='Apply', Mandatory=$false)]
    [switch]$Validate,

    [Parameter(ParameterSetName='Apply', Mandatory=$false)]
    [switch]$Backup,

    [Parameter(ParameterSetName='Restore', Mandatory=$true)]
    [switch]$Restore,

    [Parameter(ParameterSetName='Restore', Mandatory=$false)]
    [string]$BackupFile,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Import PowerShell-Yaml module
if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Write-Host "Installing powershell-yaml module..." -ForegroundColor Yellow
    try {
        Install-Module -Name powershell-yaml -Force -Scope CurrentUser -ErrorAction Stop
    } catch {
        Write-Error "Failed to install powershell-yaml module. Please install manually: Install-Module -Name powershell-yaml"
        exit 1
    }
}

Import-Module powershell-yaml -ErrorAction Stop

Write-Host "`n=== GitHub Actions Runner Configuration Manager ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# Function to log messages
function Write-ConfigLog {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'SUCCESS', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        'ERROR' { Write-Host $logMessage -ForegroundColor Red }
        'WARN' { Write-Host $logMessage -ForegroundColor Yellow }
        'SUCCESS' { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }
}

# Function to validate configuration
function Test-Configuration {
    param([hashtable]$Config)

    Write-ConfigLog "Validating configuration..." "INFO"
    $errors = @()

    # Validate runner section
    if (-not $Config.runner) {
        $errors += "Missing required 'runner' section"
    } else {
        if (-not $Config.runner.name) {
            $errors += "Missing required 'runner.name'"
        }
        if (-not $Config.runner.labels) {
            $errors += "Missing required 'runner.labels'"
        }
    }

    # Validate paths
    if (-not $Config.paths) {
        $errors += "Missing required 'paths' section"
    } else {
        if (-not $Config.paths.runner_home) {
            $errors += "Missing required 'paths.runner_home'"
        }
        if (-not $Config.paths.work_directory) {
            $errors += "Missing required 'paths.work_directory'"
        }
    }

    # Validate resources
    if ($Config.resources) {
        if ($Config.resources.cpu -and $Config.resources.cpu.max_cores) {
            if ($Config.resources.cpu.max_cores -lt 1) {
                $errors += "Invalid cpu.max_cores: must be >= 1"
            }
        }
        if ($Config.resources.memory -and $Config.resources.memory.max_memory_gb) {
            if ($Config.resources.memory.max_memory_gb -lt 1) {
                $errors += "Invalid memory.max_memory_gb: must be >= 1"
            }
        }
    }

    # Validate timeouts
    if ($Config.timeouts) {
        if ($Config.timeouts.job_timeout_minutes -and $Config.timeouts.job_timeout_minutes -lt 1) {
            $errors += "Invalid job_timeout_minutes: must be >= 1"
        }
    }

    if ($errors.Count -gt 0) {
        Write-ConfigLog "Configuration validation failed with $($errors.Count) error(s):" "ERROR"
        foreach ($validationError in $errors) {
            Write-ConfigLog "  - $validationError" "ERROR"
        }
        return $false
    }

    Write-ConfigLog "Configuration validation passed" "SUCCESS"
    return $true
}

# Function to create backup
function New-ConfigBackup {
    param([string]$Source)

    $backupDir = "config\backups"
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = Join-Path $backupDir "config-backup-$timestamp.yaml"

    try {
        Copy-Item -Path $Source -Destination $backupPath -Force
        Write-ConfigLog "Backup created: $backupPath" "SUCCESS"
        return $backupPath
    } catch {
        Write-ConfigLog "Failed to create backup: $_" "ERROR"
        throw
    }
}

# Function to apply environment variables
function Set-EnvironmentVariables {
    param([hashtable]$EnvConfig)

    if (-not $EnvConfig) {
        Write-ConfigLog "No environment variables to configure" "INFO"
        return
    }

    Write-ConfigLog "Configuring environment variables..." "INFO"

    foreach ($category in @('system', 'runner', 'custom')) {
        if ($EnvConfig[$category]) {
            Write-ConfigLog "  Setting $category environment variables" "INFO"

            foreach ($key in $EnvConfig[$category].Keys) {
                $value = $EnvConfig[$category][$key]

                if ($DryRun) {
                    Write-ConfigLog "    [DRY RUN] Would set $key = $value" "INFO"
                } else {
                    try {
                        [System.Environment]::SetEnvironmentVariable($key, $value, [System.EnvironmentVariableTarget]::Machine)
                        Write-ConfigLog "    Set $key = $value" "SUCCESS"
                    } catch {
                        Write-ConfigLog "    Failed to set ${key}: $_" "WARN"
                    }
                }
            }
        }
    }
}

# Function to create directories
function Initialize-Directories {
    param([hashtable]$Paths)

    if (-not $Paths) {
        Write-ConfigLog "No paths to configure" "INFO"
        return
    }

    Write-ConfigLog "Initializing directories..." "INFO"

    foreach ($pathKey in $Paths.Keys) {
        $pathValue = $Paths[$pathKey]

        if ($pathValue -and $pathValue -match '^[A-Z]:\\') {
            if (-not (Test-Path $pathValue)) {
                if ($DryRun) {
                    Write-ConfigLog "  [DRY RUN] Would create directory: $pathValue" "INFO"
                } else {
                    try {
                        New-Item -ItemType Directory -Path $pathValue -Force | Out-Null
                        Write-ConfigLog "  Created directory: $pathValue" "SUCCESS"
                    } catch {
                        Write-ConfigLog "  Failed to create directory $pathValue : $_" "WARN"
                    }
                }
            } else {
                Write-ConfigLog "  Directory exists: $pathValue" "INFO"
            }
        }
    }
}

# Function to configure monitoring
function Set-MonitoringConfig {
    param([hashtable]$Monitoring)

    if (-not $Monitoring -or -not $Monitoring.enabled) {
        Write-ConfigLog "Monitoring not enabled" "INFO"
        return
    }

    Write-ConfigLog "Configuring monitoring..." "INFO"

    # Create monitoring config file
    $monitoringConfigPath = "config\monitoring-config.json"

    $monitoringSettings = @{
        enabled = $Monitoring.enabled
        health_check_interval = $Monitoring.health_check_interval
        alert_webhook = $Monitoring.alert_webhook
        alerts = $Monitoring.alerts
        thresholds = $Monitoring.thresholds
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }

    if ($DryRun) {
        Write-ConfigLog "  [DRY RUN] Would write monitoring config to $monitoringConfigPath" "INFO"
    } else {
        try {
            $monitoringSettings | ConvertTo-Json -Depth 10 | Out-File -FilePath $monitoringConfigPath -Force
            Write-ConfigLog "  Monitoring configuration saved to $monitoringConfigPath" "SUCCESS"
        } catch {
            Write-ConfigLog "  Failed to save monitoring config: $_" "WARN"
        }
    }
}

# Function to configure Docker
function Set-DockerConfig {
    param([hashtable]$DockerConfig)

    if (-not $DockerConfig -or -not $DockerConfig.enabled) {
        Write-ConfigLog "Docker integration not enabled" "INFO"
        return
    }

    Write-ConfigLog "Configuring Docker..." "INFO"

    # Check if Docker is installed
    $dockerInstalled = Get-Command docker -ErrorAction SilentlyContinue

    if (-not $dockerInstalled) {
        Write-ConfigLog "  Docker is not installed on this system" "WARN"
        return
    }

    # Create Docker config
    $dockerConfigPath = "config\docker-config.json"

    $dockerSettings = @{
        enabled = $DockerConfig.enabled
        socket_path = $DockerConfig.socket_path
        isolation_mode = $DockerConfig.isolation_mode
        container_limits = $DockerConfig.container_limits
        auto_cleanup_containers = $DockerConfig.auto_cleanup_containers
        auto_cleanup_images = $DockerConfig.auto_cleanup_images
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }

    if ($DryRun) {
        Write-ConfigLog "  [DRY RUN] Would write Docker config to $dockerConfigPath" "INFO"
    } else {
        try {
            $dockerSettings | ConvertTo-Json -Depth 10 | Out-File -FilePath $dockerConfigPath -Force
            Write-ConfigLog "  Docker configuration saved to $dockerConfigPath" "SUCCESS"
        } catch {
            Write-ConfigLog "  Failed to save Docker config: $_" "WARN"
        }
    }
}

# Function to apply security settings
function Set-SecurityConfig {
    param([hashtable]$Security)

    if (-not $Security) {
        Write-ConfigLog "No security settings to apply" "INFO"
        return
    }

    Write-ConfigLog "Applying security settings..." "INFO"

    # Create security config
    $securityConfigPath = "config\security-config.json"

    $securitySettings = @{
        firewall_enabled = $Security.firewall_enabled
        allowed_networks = $Security.allowed_networks
        block_external_access = $Security.block_external_access
        audit_logging = $Security.audit_logging
        audit_log_path = $Security.audit_log_path
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }

    if ($DryRun) {
        Write-ConfigLog "  [DRY RUN] Would write security config to $securityConfigPath" "INFO"
    } else {
        try {
            $securitySettings | ConvertTo-Json -Depth 10 | Out-File -FilePath $securityConfigPath -Force
            Write-ConfigLog "  Security configuration saved to $securityConfigPath" "SUCCESS"

            # Apply firewall rules if enabled and script exists
            if ($Security.firewall_enabled) {
                $firewallScript = "config\apply-firewall-rules.ps1"
                if (Test-Path $firewallScript) {
                    Write-ConfigLog "  Applying firewall rules..." "INFO"
                    try {
                        & $firewallScript
                        Write-ConfigLog "  Firewall rules applied" "SUCCESS"
                    } catch {
                        Write-ConfigLog "  Failed to apply firewall rules: $_" "WARN"
                    }
                }
            }
        } catch {
            Write-ConfigLog "  Failed to save security config: $_" "WARN"
        }
    }
}

# Main execution
try {
    # Handle restore operation
    if ($Restore) {
        if (-not $BackupFile) {
            # Find most recent backup
            $backupDir = "config\backups"
            if (Test-Path $backupDir) {
                $latestBackup = Get-ChildItem -Path $backupDir -Filter "*.yaml" |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1

                if ($latestBackup) {
                    $BackupFile = $latestBackup.FullName
                    Write-ConfigLog "Using latest backup: $BackupFile" "INFO"
                } else {
                    Write-ConfigLog "No backup files found in $backupDir" "ERROR"
                    exit 1
                }
            } else {
                Write-ConfigLog "Backup directory does not exist: $backupDir" "ERROR"
                exit 1
            }
        }

        if (-not (Test-Path $BackupFile)) {
            Write-ConfigLog "Backup file not found: $BackupFile" "ERROR"
            exit 1
        }

        $ConfigFile = $BackupFile
        Write-ConfigLog "Restoring configuration from: $BackupFile" "INFO"
    }

    # Determine config file from environment preset
    if ($Environment) {
        if ($Environment -eq 'dev') {
            $ConfigFile = "config\runner-config.general.yaml"  # Use general for dev
        } else {
            $ConfigFile = "config\runner-config.$Environment.yaml"
        }
        Write-ConfigLog "Using $Environment environment configuration: $ConfigFile" "INFO"
    }

    # Verify config file exists
    if (-not (Test-Path $ConfigFile)) {
        Write-ConfigLog "Configuration file not found: $ConfigFile" "ERROR"
        exit 1
    }

    Write-ConfigLog "Loading configuration from: $ConfigFile" "INFO"

    # Load YAML configuration
    try {
        $configContent = Get-Content -Path $ConfigFile -Raw
        $config = ConvertFrom-Yaml $configContent
    } catch {
        Write-ConfigLog "Failed to parse YAML configuration: $_" "ERROR"
        exit 1
    }

    # Validate configuration
    $validationResult = Test-Configuration -Config $config

    if (-not $validationResult) {
        Write-ConfigLog "Configuration validation failed. Please fix errors and try again." "ERROR"
        exit 1
    }

    if ($Validate) {
        Write-ConfigLog "Validation completed successfully. No changes applied." "SUCCESS"
        exit 0
    }

    # Create backup if requested
    if ($Backup -and -not $Restore) {
        $backupPath = New-ConfigBackup -Source $ConfigFile
    }

    if ($DryRun) {
        Write-Host "`n=== DRY RUN MODE - No changes will be applied ===" -ForegroundColor Yellow
    }

    # Apply configuration
    Write-ConfigLog "`nApplying configuration..." "INFO"

    # 1. Initialize directories
    Initialize-Directories -Paths $config.paths

    # 2. Set environment variables
    Set-EnvironmentVariables -EnvConfig $config.environment

    # 3. Configure monitoring
    Set-MonitoringConfig -Monitoring $config.monitoring

    # 4. Configure Docker
    Set-DockerConfig -DockerConfig $config.docker

    # 5. Apply security settings
    Set-SecurityConfig -Security $config.security

    # 6. Save applied configuration metadata
    if (-not $DryRun) {
        $appliedConfigPath = "config\applied-config.json"
        $appliedMetadata = @{
            source_file = $ConfigFile
            applied_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            runner_name = $config.runner.name
            environment = if ($Environment) { $Environment } else { "custom" }
            dry_run = $false
        }

        $appliedMetadata | ConvertTo-Json -Depth 5 | Out-File -FilePath $appliedConfigPath -Force
        Write-ConfigLog "Applied configuration metadata saved to $appliedConfigPath" "SUCCESS"
    }

    # Summary
    Write-Host "`n=== Configuration Applied Successfully ===" -ForegroundColor Green
    Write-Host "Configuration file: $ConfigFile" -ForegroundColor Cyan
    Write-Host "Runner name: $($config.runner.name)" -ForegroundColor Cyan
    Write-Host "Labels: $($config.runner.labels -join ', ')" -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "`nDRY RUN completed - no changes were made" -ForegroundColor Yellow
    }

    if ($Backup -and $backupPath) {
        Write-Host "Backup saved: $backupPath" -ForegroundColor Gray
    }

    Write-Host ""
    Write-ConfigLog "Configuration application completed" "SUCCESS"

    exit 0

} catch {
    Write-ConfigLog "Fatal error during configuration application: $_" "ERROR"
    Write-ConfigLog $_.ScriptStackTrace "ERROR"
    exit 1
}
