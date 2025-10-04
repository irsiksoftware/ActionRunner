#Requires -Version 5.1

<#
.SYNOPSIS
    Generates default configuration templates for GitHub Actions self-hosted runners.

.DESCRIPTION
    This script generates YAML and JSON configuration templates for different runner types:
    - General purpose runners
    - Production environment runners
    - GPU-enabled runners
    - Unity game development runners
    - Development/test runners

    Templates can be customized with specific parameters and validated before saving.

.PARAMETER TemplateType
    Type of configuration template to generate (general, prod, gpu, unity, dev)

.PARAMETER OutputPath
    Path where the configuration template will be saved

.PARAMETER Format
    Output format (yaml or json). Default: yaml

.PARAMETER Validate
    Validate the generated template before saving

.PARAMETER Interactive
    Prompt for custom values instead of using defaults

.PARAMETER Force
    Overwrite existing configuration files without prompting

.EXAMPLE
    .\generate-config-template.ps1 -TemplateType general
    Generate a general purpose runner configuration template

.EXAMPLE
    .\generate-config-template.ps1 -TemplateType prod -OutputPath "C:\custom\config.yaml"
    Generate production configuration at custom path

.EXAMPLE
    .\generate-config-template.ps1 -TemplateType gpu -Format json
    Generate GPU configuration in JSON format

.EXAMPLE
    .\generate-config-template.ps1 -TemplateType unity -Interactive
    Generate Unity configuration with interactive prompts

.NOTES
    Author: GitHub Actions Runner Team
    Version: 1.0.0
    Requires: PowerShell-Yaml module (Install-Module -Name powershell-yaml)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('general', 'prod', 'gpu', 'unity', 'dev')]
    [string]$TemplateType = 'general',

    [Parameter(Mandatory=$false)]
    [string]$OutputPath,

    [Parameter(Mandatory=$false)]
    [ValidateSet('yaml', 'json')]
    [string]$Format = 'yaml',

    [Parameter(Mandatory=$false)]
    [switch]$Validate,

    [Parameter(Mandatory=$false)]
    [switch]$Interactive,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Import PowerShell-Yaml module if format is YAML
if ($Format -eq 'yaml') {
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
}

Write-Host "`n=== GitHub Actions Runner Configuration Template Generator ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Template Type: $TemplateType" -ForegroundColor Cyan
Write-Host "Output Format: $Format" -ForegroundColor Cyan

# Function to log messages
function Write-TemplateLog {
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

# Function to prompt for value if interactive mode
function Get-ConfigValue {
    param(
        [string]$Prompt,
        [string]$DefaultValue,
        [switch]$IsRequired
    )

    if (-not $Interactive) {
        return $DefaultValue
    }

    $userInput = Read-Host "$Prompt [$DefaultValue]"

    if ([string]::IsNullOrWhiteSpace($userInput)) {
        if ($IsRequired -and [string]::IsNullOrWhiteSpace($DefaultValue)) {
            Write-TemplateLog "Value is required" "ERROR"
            return Get-ConfigValue -Prompt $Prompt -DefaultValue $DefaultValue -IsRequired:$IsRequired
        }
        return $DefaultValue
    }

    return $userInput
}

# Function to generate general purpose template
function New-GeneralTemplate {
    Write-TemplateLog "Generating general purpose runner template..." "INFO"

    $runnerName = Get-ConfigValue -Prompt "Runner name" -DefaultValue "action-runner-general"
    $runnerHome = Get-ConfigValue -Prompt "Runner home directory" -DefaultValue "C:\actions-runner"
    $maxConcurrentJobs = Get-ConfigValue -Prompt "Max concurrent jobs" -DefaultValue "3"

    return @{
        runner = @{
            name = $runnerName
            labels = @("self-hosted", "Windows", "X64", "general")
            group = "Default"
        }
        paths = @{
            runner_home = $runnerHome
            work_directory = "$runnerHome\_work"
            temp_directory = "C:\Temp"
            log_directory = "$runnerHome\logs"
        }
        resources = @{
            max_concurrent_jobs = [int]$maxConcurrentJobs
            cpu = @{
                max_cores = 8
                affinity = ""
            }
            memory = @{
                max_memory_gb = 16
                reserved_memory_gb = 4
            }
            disk = @{
                min_free_space_gb = 100
                auto_cleanup = $true
                cleanup_per_job = $true
            }
        }
        timeouts = @{
            job_timeout_minutes = 360
            queue_timeout_minutes = 30
            step_timeout_minutes = 60
        }
        environment = @{
            system = @{
                DOTNET_ROOT = "C:\Program Files\dotnet"
                JAVA_HOME = "C:\Program Files\Java\jdk-17"
                PYTHON_PATH = "C:\Python311"
                NODE_PATH = "C:\Program Files\nodejs"
                DOCKER_HOST = "npipe:////./pipe/docker_engine"
            }
            runner = @{
                ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT = "1"
                RUNNER_ALLOW_RUNASROOT = "0"
            }
            custom = @{}
        }
        gpu = @{
            enabled = $false
        }
        unity = @{
            enabled = $false
        }
        docker = @{
            enabled = $true
            socket_path = "npipe:////./pipe/docker_engine"
            isolation_mode = "process"
            container_limits = @{
                memory_gb = 8
                cpu_cores = 4
            }
            auto_cleanup_containers = $true
            auto_cleanup_images = $true
        }
        monitoring = @{
            enabled = $true
            health_check_interval = 300
            alert_webhook = ""
            alerts = @{
                runner_offline = $true
                low_disk_space = $true
                high_cpu_usage = $true
                high_memory_usage = $true
                job_failure = $false
            }
            thresholds = @{
                cpu_warning_percent = 80
                cpu_critical_percent = 95
                memory_warning_percent = 85
                memory_critical_percent = 95
                disk_warning_gb = 150
                disk_critical_gb = 100
            }
        }
        security = @{
            firewall_enabled = $true
            allowed_networks = @("192.168.1.0/24", "10.0.0.0/8")
            block_external_access = $false
            audit_logging = $true
            audit_log_path = "$runnerHome\logs\audit.log"
        }
        logging = @{
            level = "info"
            retention_days = 30
            max_file_size_mb = 100
            rotation_enabled = $true
            console_output = $true
        }
        maintenance = @{
            auto_update = $true
            update_check_interval_hours = 24
            backup_before_update = $true
            maintenance_window = "0 2 * * 0"
        }
        webhooks = @{
            endpoints = @(
                @{
                    name = "notifications"
                    url = ""
                    events = @("runner_stopped", "job_failed", "health_check_failed")
                }
            )
        }
        features = @{
            experimental = @{
                new_job_engine = $false
                job_queueing = $true
            }
            disabled = @{
                artifact_upload = $false
                cache = $false
            }
        }
    }
}

# Function to generate production template
function New-ProductionTemplate {
    Write-TemplateLog "Generating production runner template..." "INFO"

    $runnerName = Get-ConfigValue -Prompt "Runner name" -DefaultValue "action-runner-prod"
    $runnerHome = Get-ConfigValue -Prompt "Runner home directory" -DefaultValue "C:\actions-runner"

    return @{
        runner = @{
            name = $runnerName
            labels = @("self-hosted", "Windows", "X64", "production")
        }
        paths = @{
            runner_home = $runnerHome
            work_directory = "$runnerHome\_work"
            temp_directory = "$runnerHome\_temp"
            log_directory = "$runnerHome\_logs"
            config_backup_directory = "$runnerHome\config-backups"
        }
        resources = @{
            max_concurrent_jobs = 5
            cpu = @{
                max_cores = 16
                reserved_percent = 15
            }
            memory = @{
                max_memory_gb = 32
                reserved_memory_gb = 4
            }
            disk = @{
                min_free_space_gb = 200
                auto_cleanup = $true
                cleanup_per_job = $true
            }
        }
        timeouts = @{
            job_timeout_minutes = 480
            queue_timeout_minutes = 30
            step_timeout_minutes = 90
            idle_timeout_minutes = 30
            cleanup_timeout_minutes = 20
        }
        environment = @{
            system = @{
                DOTNET_ROOT = "C:\Program Files\dotnet"
                JAVA_HOME = "C:\Program Files\Java\jdk-17"
                PYTHON_PATH = "C:\Python311"
                NODE_PATH = "C:\Program Files\nodejs"
                DOCKER_HOST = "npipe:////./pipe/docker_engine"
            }
            runner = @{
                ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT = "1"
                RUNNER_ALLOW_RUNASROOT = "0"
                ACTIONS_RUNNER_HOOK_JOB_STARTED = "$runnerHome\hooks\job-started.ps1"
                ACTIONS_RUNNER_HOOK_JOB_COMPLETED = "$runnerHome\hooks\job-completed.ps1"
            }
            custom = @{}
        }
        docker = @{
            enabled = $true
            socket_path = "npipe:////./pipe/docker_engine"
            isolation_mode = "process"
            container_limits = @{
                memory_gb = 16
                cpu_cores = 8
            }
            auto_cleanup_containers = $true
            auto_cleanup_images = $true
        }
        monitoring = @{
            enabled = $true
            health_check_interval = 180
            alert_webhook = ""
            alerts = @{
                runner_offline = $true
                low_disk_space = $true
                high_cpu_usage = $true
                high_memory_usage = $true
                job_failure = $true
            }
            thresholds = @{
                cpu_warning_percent = 75
                cpu_critical_percent = 90
                memory_warning_percent = 80
                memory_critical_percent = 95
                disk_warning_gb = 200
                disk_critical_gb = 150
            }
        }
        security = @{
            firewall_enabled = $true
            allowed_networks = @("10.0.0.0/8")
            block_external_access = $false
            audit_logging = $true
            audit_log_path = "$runnerHome\logs\audit.log"
            allow_privileged_containers = $false
            enforce_code_signing = $true
            scan_dependencies = $true
        }
        logging = @{
            level = "info"
            retention_days = 90
            max_file_size_mb = 500
            rotation_enabled = $true
            console_output = $true
        }
        maintenance = @{
            auto_update = $true
            update_check_interval_hours = 12
            backup_before_update = $true
            maintenance_window = "0 2 * * 0,2,4"
            auto_restart = $true
        }
        features = @{
            docker_isolation = $true
            health_checks = $true
            metrics_collection = $true
            workspace_cleanup = $true
        }
    }
}

# Function to generate GPU template
function New-GPUTemplate {
    Write-TemplateLog "Generating GPU runner template..." "INFO"

    $runnerName = Get-ConfigValue -Prompt "Runner name" -DefaultValue "action-runner-gpu"
    $runnerHome = Get-ConfigValue -Prompt "Runner home directory" -DefaultValue "C:\actions-runner-gpu"
    $cudaVersion = Get-ConfigValue -Prompt "CUDA version" -DefaultValue "12.0"

    return @{
        runner = @{
            name = $runnerName
            labels = @("self-hosted", "Windows", "X64", "gpu", "cuda", "nvidia", "ml")
            group = "GPU-Runners"
        }
        paths = @{
            runner_home = $runnerHome
            work_directory = "D:\gpu-work"
            temp_directory = "D:\gpu-temp"
            log_directory = "$runnerHome\logs"
        }
        resources = @{
            max_concurrent_jobs = 1
            cpu = @{
                max_cores = 0
                affinity = ""
            }
            memory = @{
                max_memory_gb = 0
                reserved_memory_gb = 8
            }
            disk = @{
                min_free_space_gb = 200
                auto_cleanup = $true
                cleanup_per_job = $true
            }
        }
        timeouts = @{
            job_timeout_minutes = 720
            queue_timeout_minutes = 60
            step_timeout_minutes = 480
        }
        environment = @{
            system = @{
                DOTNET_ROOT = "C:\Program Files\dotnet"
                PYTHON_PATH = "C:\Python311"
                CUDA_PATH = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v$cudaVersion"
                CUDNN_PATH = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v$cudaVersion"
                PATH = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v$cudaVersion\bin;%PATH%"
            }
            runner = @{
                ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT = "1"
            }
            custom = @{
                TF_FORCE_GPU_ALLOW_GROWTH = "true"
                PYTORCH_CUDA_ALLOC_CONF = "max_split_size_mb:512"
            }
        }
        gpu = @{
            enabled = $true
            cuda_version = $cudaVersion
            vram = @{
                reserved_vram_gb = 2
                max_vram_gb = 0
            }
            compute_mode = "default"
        }
        unity = @{
            enabled = $false
        }
        docker = @{
            enabled = $true
            socket_path = "npipe:////./pipe/docker_engine"
            isolation_mode = "process"
            container_limits = @{
                memory_gb = 32
                cpu_cores = 16
            }
            auto_cleanup_containers = $true
            auto_cleanup_images = $false
        }
        monitoring = @{
            enabled = $true
            health_check_interval = 180
            alert_webhook = ""
            alerts = @{
                runner_offline = $true
                low_disk_space = $true
                high_cpu_usage = $false
                high_memory_usage = $false
            }
            thresholds = @{
                cpu_warning_percent = 90
                memory_warning_percent = 90
                disk_warning_gb = 200
            }
        }
        security = @{
            firewall_enabled = $true
            allowed_networks = @("10.0.0.0/8")
            block_external_access = $false
            audit_logging = $true
            audit_log_path = "$runnerHome\logs\audit.log"
        }
        logging = @{
            level = "info"
            retention_days = 14
            max_file_size_mb = 500
            rotation_enabled = $true
            console_output = $true
        }
        maintenance = @{
            auto_update = $false
            backup_before_update = $true
            maintenance_window = "0 3 * * 6"
        }
        features = @{
            experimental = @{
                new_job_engine = $false
                job_queueing = $true
            }
            disabled = @{
                artifact_upload = $false
                cache = $false
            }
        }
    }
}

# Function to generate Unity template
function New-UnityTemplate {
    Write-TemplateLog "Generating Unity runner template..." "INFO"

    $runnerName = Get-ConfigValue -Prompt "Runner name" -DefaultValue "action-runner-unity"
    $runnerHome = Get-ConfigValue -Prompt "Runner home directory" -DefaultValue "C:\actions-runner-unity"
    $unityVersion = Get-ConfigValue -Prompt "Unity version" -DefaultValue "2022.3.0f1"

    return @{
        runner = @{
            name = $runnerName
            labels = @("self-hosted", "Windows", "X64", "unity", "game-dev")
            group = "Unity-Runners"
        }
        paths = @{
            runner_home = $runnerHome
            work_directory = "D:\unity-work"
            temp_directory = "D:\unity-temp"
            log_directory = "$runnerHome\logs"
            unity_cache_directory = "D:\unity-cache"
        }
        resources = @{
            max_concurrent_jobs = 2
            cpu = @{
                max_cores = 12
                affinity = ""
            }
            memory = @{
                max_memory_gb = 24
                reserved_memory_gb = 8
            }
            disk = @{
                min_free_space_gb = 300
                auto_cleanup = $true
                cleanup_per_job = $true
            }
        }
        timeouts = @{
            job_timeout_minutes = 600
            queue_timeout_minutes = 45
            step_timeout_minutes = 240
        }
        environment = @{
            system = @{
                UNITY_PATH = "C:\Program Files\Unity\Hub\Editor\$unityVersion\Editor\Unity.exe"
                UNITY_LICENSE_FILE = "C:\ProgramData\Unity\Unity_lic.ulf"
                DOTNET_ROOT = "C:\Program Files\dotnet"
            }
            runner = @{
                ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT = "1"
                RUNNER_ALLOW_RUNASROOT = "0"
            }
            custom = @{}
        }
        gpu = @{
            enabled = $false
        }
        unity = @{
            enabled = $true
            version = $unityVersion
            license_type = "Professional"
            build_targets = @("Windows", "Android", "iOS", "WebGL")
            cache_server_enabled = $false
            cache_server_endpoint = ""
        }
        docker = @{
            enabled = $false
        }
        monitoring = @{
            enabled = $true
            health_check_interval = 300
            alert_webhook = ""
            alerts = @{
                runner_offline = $true
                low_disk_space = $true
                high_cpu_usage = $false
                high_memory_usage = $true
            }
            thresholds = @{
                cpu_warning_percent = 85
                memory_warning_percent = 90
                disk_warning_gb = 300
            }
        }
        security = @{
            firewall_enabled = $true
            allowed_networks = @("10.0.0.0/8", "192.168.1.0/24")
            block_external_access = $false
            audit_logging = $true
            audit_log_path = "$runnerHome\logs\audit.log"
        }
        logging = @{
            level = "info"
            retention_days = 30
            max_file_size_mb = 200
            rotation_enabled = $true
            console_output = $true
        }
        maintenance = @{
            auto_update = $true
            update_check_interval_hours = 24
            backup_before_update = $true
            maintenance_window = "0 3 * * 0"
        }
        features = @{
            experimental = @{
                incremental_builds = $true
                parallel_asset_import = $true
            }
            disabled = @{
                artifact_upload = $false
                cache = $false
            }
        }
    }
}

# Function to generate development template
function New-DevelopmentTemplate {
    Write-TemplateLog "Generating development runner template..." "INFO"

    $runnerName = Get-ConfigValue -Prompt "Runner name" -DefaultValue "action-runner-dev"
    $runnerHome = Get-ConfigValue -Prompt "Runner home directory" -DefaultValue "C:\actions-runner-dev"

    return @{
        runner = @{
            name = $runnerName
            labels = @("self-hosted", "Windows", "X64", "development", "test")
            group = "Development"
        }
        paths = @{
            runner_home = $runnerHome
            work_directory = "$runnerHome\_work"
            temp_directory = "C:\Temp"
            log_directory = "$runnerHome\logs"
        }
        resources = @{
            max_concurrent_jobs = 2
            cpu = @{
                max_cores = 4
                affinity = ""
            }
            memory = @{
                max_memory_gb = 8
                reserved_memory_gb = 2
            }
            disk = @{
                min_free_space_gb = 50
                auto_cleanup = $true
                cleanup_per_job = $true
            }
        }
        timeouts = @{
            job_timeout_minutes = 180
            queue_timeout_minutes = 15
            step_timeout_minutes = 30
        }
        environment = @{
            system = @{
                DOTNET_ROOT = "C:\Program Files\dotnet"
                JAVA_HOME = "C:\Program Files\Java\jdk-17"
                PYTHON_PATH = "C:\Python311"
                NODE_PATH = "C:\Program Files\nodejs"
            }
            runner = @{
                ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT = "1"
                RUNNER_ALLOW_RUNASROOT = "0"
            }
            custom = @{}
        }
        docker = @{
            enabled = $true
            socket_path = "npipe:////./pipe/docker_engine"
            isolation_mode = "process"
            container_limits = @{
                memory_gb = 4
                cpu_cores = 2
            }
            auto_cleanup_containers = $true
            auto_cleanup_images = $true
        }
        monitoring = @{
            enabled = $true
            health_check_interval = 600
            alert_webhook = ""
            alerts = @{
                runner_offline = $true
                low_disk_space = $true
            }
            thresholds = @{
                cpu_warning_percent = 90
                memory_warning_percent = 90
                disk_warning_gb = 50
            }
        }
        security = @{
            firewall_enabled = $false
            allowed_networks = @()
            block_external_access = $false
            audit_logging = $false
        }
        logging = @{
            level = "debug"
            retention_days = 7
            max_file_size_mb = 50
            rotation_enabled = $true
            console_output = $true
        }
        maintenance = @{
            auto_update = $false
            update_check_interval_hours = 168
            backup_before_update = $false
            maintenance_window = ""
        }
        features = @{
            experimental = @{
                new_job_engine = $true
                job_queueing = $true
            }
            disabled = @{
                artifact_upload = $false
                cache = $false
            }
        }
    }
}

# Function to validate template
function Test-Template {
    param([hashtable]$Template)

    Write-TemplateLog "Validating template..." "INFO"
    $errors = @()

    # Validate runner section
    if (-not $Template.runner) {
        $errors += "Missing required 'runner' section"
    } else {
        if (-not $Template.runner.name) {
            $errors += "Missing required 'runner.name'"
        }
        if (-not $Template.runner.labels) {
            $errors += "Missing required 'runner.labels'"
        }
    }

    # Validate paths
    if (-not $Template.paths) {
        $errors += "Missing required 'paths' section"
    }

    # Validate resources
    if (-not $Template.resources) {
        $errors += "Missing required 'resources' section"
    }

    if ($errors.Count -gt 0) {
        Write-TemplateLog "Template validation failed with $($errors.Count) error(s):" "ERROR"
        foreach ($validationError in $errors) {
            Write-TemplateLog "  - $validationError" "ERROR"
        }
        return $false
    }

    Write-TemplateLog "Template validation passed" "SUCCESS"
    return $true
}

# Main execution
try {
    # Generate template based on type
    $template = switch ($TemplateType) {
        'general' { New-GeneralTemplate }
        'prod' { New-ProductionTemplate }
        'gpu' { New-GPUTemplate }
        'unity' { New-UnityTemplate }
        'dev' { New-DevelopmentTemplate }
        default {
            Write-TemplateLog "Invalid template type: $TemplateType" "ERROR"
            exit 1
        }
    }

    # Validate template if requested
    if ($Validate) {
        $validationResult = Test-Template -Template $template
        if (-not $validationResult) {
            Write-TemplateLog "Template validation failed" "ERROR"
            exit 1
        }
    }

    # Determine output path
    if (-not $OutputPath) {
        $extension = if ($Format -eq 'yaml') { 'yaml' } else { 'json' }
        $OutputPath = "config\runner-config.$TemplateType.$extension"
    }

    # Check if file exists and prompt if not forcing
    if ((Test-Path $OutputPath) -and -not $Force) {
        $response = Read-Host "File already exists at $OutputPath. Overwrite? (y/n)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-TemplateLog "Operation cancelled by user" "WARN"
            exit 0
        }
    }

    # Create output directory if needed
    $outputDir = Split-Path -Parent $OutputPath
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        Write-TemplateLog "Created output directory: $outputDir" "INFO"
    }

    # Save template
    Write-TemplateLog "Saving template to: $OutputPath" "INFO"

    if ($Format -eq 'yaml') {
        $yamlContent = ConvertTo-Yaml $template
        # Add header comment
        $header = @"
# GitHub Actions Self-Hosted Runner Configuration - $($TemplateType.ToUpper())
# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Template Type: $TemplateType

"@
        $fullContent = $header + $yamlContent
        $fullContent | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
    } else {
        $template | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
    }

    Write-Host "`n=== Template Generated Successfully ===" -ForegroundColor Green
    Write-Host "Template Type: $TemplateType" -ForegroundColor Cyan
    Write-Host "Output Format: $Format" -ForegroundColor Cyan
    Write-Host "Output Path: $OutputPath" -ForegroundColor Cyan
    Write-Host "Runner Name: $($template.runner.name)" -ForegroundColor Cyan
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "1. Review and customize the generated configuration" -ForegroundColor Gray
    Write-Host "2. Apply the configuration: .\scripts\apply-config.ps1 -ConfigFile $OutputPath" -ForegroundColor Gray
    Write-Host ""

    Write-TemplateLog "Template generation completed" "SUCCESS"
    exit 0

} catch {
    Write-TemplateLog "Fatal error during template generation: $_" "ERROR"
    Write-TemplateLog $_.ScriptStackTrace "ERROR"
    exit 1
}
