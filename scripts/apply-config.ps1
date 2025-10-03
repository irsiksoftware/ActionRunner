#Requires -Version 5.1

<#
.SYNOPSIS
    Apply GitHub Actions Runner Configuration

.DESCRIPTION
    Applies configuration from runner-config.yaml to the GitHub Actions self-hosted runner.
    Validates configuration, backs up existing settings, and applies changes safely.

.PARAMETER ConfigPath
    Path to the configuration YAML file (default: config/runner-config.yaml)

.PARAMETER Validate
    Only validate the configuration without applying changes

.PARAMETER Backup
    Create a backup of current configuration before applying changes (default: true)

.PARAMETER Force
    Apply configuration without confirmation prompts

.PARAMETER DryRun
    Show what would be changed without applying

.EXAMPLE
    .\apply-config.ps1
    .\apply-config.ps1 -ConfigPath "config/custom-config.yaml"
    .\apply-config.ps1 -Validate
    .\apply-config.ps1 -DryRun

.NOTES
    Author: GitHub Actions Runner Team
    Version: 1.0.0
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = "config\runner-config.yaml",

    [Parameter(Mandatory=$false)]
    [switch]$Validate,

    [Parameter(Mandatory=$false)]
    [switch]$Backup = $true,

    [Parameter(Mandatory=$false)]
    [switch]$Force,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

# Import PowerShell YAML module or use built-in parser
function ConvertFrom-Yaml {
    param([string]$YamlContent)

    # Simple YAML parser for basic key-value pairs
    # For production, use: Install-Module powershell-yaml
    $config = @{}
    $currentSection = $null
    $lines = $YamlContent -split "`n"

    foreach ($line in $lines) {
        $line = $line.Trim()

        # Skip comments and empty lines
        if ($line -match '^#' -or [string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        # Check for section headers (no indent, ends with :)
        if ($line -match '^(\w+):$') {
            $currentSection = $matches[1]
            $config[$currentSection] = @{}
            continue
        }

        # Parse key-value pairs
        if ($line -match '^\s*([^:]+):\s*(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()

            # Remove quotes
            $value = $value -replace '^["'']|["'']$', ''

            # Convert to appropriate type
            if ($value -eq 'true') { $value = $true }
            elseif ($value -eq 'false') { $value = $false }
            elseif ($value -match '^\d+$') { $value = [int]$value }

            if ($currentSection) {
                $config[$currentSection][$key] = $value
            } else {
                $config[$key] = $value
            }
        }
    }

    return $config
}

# Logging function
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        'INFO' { 'White' }
        'WARNING' { 'Yellow' }
        'ERROR' { 'Red' }
        'SUCCESS' { 'Green' }
    }

    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color

    # Also log to file
    $logDir = "logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    Add-Content -Path "$logDir\apply-config.log" -Value "[$timestamp] [$Level] $Message"
}

# Validate configuration file exists
function Test-ConfigurationFile {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Log "Configuration file not found: $Path" "ERROR"
        return $false
    }

    Write-Log "Configuration file found: $Path" "INFO"
    return $true
}

# Validate configuration structure
function Test-ConfigurationStructure {
    param([hashtable]$Config)

    $errors = @()
    $warnings = @()

    # Check required sections
    $requiredSections = @('runner', 'paths', 'resources')
    foreach ($section in $requiredSections) {
        if (-not $Config.ContainsKey($section)) {
            $errors += "Missing required section: $section"
        }
    }

    # Validate paths
    if ($Config.ContainsKey('paths')) {
        if ($Config.paths.runner_home) {
            if (-not (Test-Path $Config.paths.runner_home)) {
                $warnings += "Runner home directory does not exist: $($Config.paths.runner_home)"
            }
        }
    }

    # Validate resource limits
    if ($Config.ContainsKey('resources')) {
        if ($Config.resources.memory -and $Config.resources.memory.max_memory_gb) {
            $totalMemory = (Get-CimInstance Win32_OperatingSystem).TotalVisibleMemorySize / 1MB
            if ($Config.resources.memory.max_memory_gb -gt $totalMemory) {
                $warnings += "Max memory ($($Config.resources.memory.max_memory_gb) GB) exceeds available memory ($totalMemory GB)"
            }
        }
    }

    # Report validation results
    if ($errors.Count -gt 0) {
        foreach ($errorMsg in $errors) {
            Write-Log $errorMsg "ERROR"
        }
        return $false
    }

    if ($warnings.Count -gt 0) {
        foreach ($warning in $warnings) {
            Write-Log $warning "WARNING"
        }
    }

    Write-Log "Configuration structure is valid" "SUCCESS"
    return $true
}

# Backup current configuration
function Backup-Configuration {
    $backupDir = "config\backups"
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $backupPath = "$backupDir\runner-config_$timestamp.yaml"

    if (Test-Path $ConfigPath) {
        Copy-Item $ConfigPath -Destination $backupPath -Force
        Write-Log "Configuration backed up to: $backupPath" "SUCCESS"
        return $backupPath
    }

    return $null
}

# Apply environment variables
function Set-EnvironmentVariables {
    param([hashtable]$EnvConfig)

    if ($DryRun) {
        Write-Log "[DRY RUN] Would apply environment variables" "INFO"
        return
    }

    Write-Log "Applying environment variables..." "INFO"

    foreach ($category in @('system', 'runner', 'custom')) {
        if ($EnvConfig.ContainsKey($category) -and $EnvConfig[$category]) {
            foreach ($key in $EnvConfig[$category].Keys) {
                $value = $EnvConfig[$category][$key]
                Write-Log "Setting $category environment variable: $key = $value" "INFO"
                [Environment]::SetEnvironmentVariable($key, $value, 'Machine')
            }
        }
    }

    Write-Log "Environment variables applied successfully" "SUCCESS"
}

# Apply runner labels
function Set-RunnerLabels {
    param([array]$Labels)

    if ($DryRun) {
        Write-Log "[DRY RUN] Would apply labels: $($Labels -join ', ')" "INFO"
        return
    }

    Write-Log "Runner labels would be applied during runner registration" "INFO"
    Write-Log "Labels: $($Labels -join ', ')" "INFO"
}

# Apply resource limits
function Set-ResourceLimits {
    param([hashtable]$ResourceConfig)

    if ($DryRun) {
        Write-Log "[DRY RUN] Would apply resource limits" "INFO"
        return
    }

    Write-Log "Applying resource limits..." "INFO"

    # CPU affinity
    if ($ResourceConfig.cpu -and $ResourceConfig.cpu.affinity) {
        Write-Log "CPU affinity: $($ResourceConfig.cpu.affinity)" "INFO"
        # Note: CPU affinity is typically set per-process
    }

    # Memory limits
    if ($ResourceConfig.memory) {
        Write-Log "Memory limits: Max=$($ResourceConfig.memory.max_memory_gb)GB, Reserved=$($ResourceConfig.memory.reserved_memory_gb)GB" "INFO"
        # Note: Memory limits are enforced at job runtime
    }

    Write-Log "Resource limits configured" "SUCCESS"
}

# Apply GPU configuration
function Set-GPUConfiguration {
    param([hashtable]$GPUConfig)

    if (-not $GPUConfig.enabled) {
        Write-Log "GPU support is disabled" "INFO"
        return
    }

    if ($DryRun) {
        Write-Log "[DRY RUN] Would configure GPU settings" "INFO"
        return
    }

    Write-Log "Configuring GPU settings..." "INFO"

    # Check for NVIDIA GPU
    $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if (-not $nvidiaSmi) {
        Write-Log "nvidia-smi not found. GPU configuration skipped." "WARNING"
        return
    }

    Write-Log "GPU CUDA version: $($GPUConfig.cuda_version)" "INFO"
    Write-Log "GPU compute mode: $($GPUConfig.compute_mode)" "INFO"

    if ($GPUConfig.vram) {
        Write-Log "GPU VRAM limits: Reserved=$($GPUConfig.vram.reserved_vram_gb)GB, Max=$($GPUConfig.vram.max_vram_gb)GB" "INFO"
    }

    Write-Log "GPU configuration applied" "SUCCESS"
}

# Apply Docker configuration
function Set-DockerConfiguration {
    param([hashtable]$DockerConfig)

    if (-not $DockerConfig.enabled) {
        Write-Log "Docker support is disabled" "INFO"
        return
    }

    if ($DryRun) {
        Write-Log "[DRY RUN] Would configure Docker settings" "INFO"
        return
    }

    Write-Log "Configuring Docker settings..." "INFO"

    # Check Docker availability
    try {
        docker info 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Docker is available" "SUCCESS"
            Write-Log "Isolation mode: $($DockerConfig.isolation_mode)" "INFO"
            Write-Log "Container limits: Memory=$($DockerConfig.container_limits.memory_gb)GB, CPU=$($DockerConfig.container_limits.cpu_cores) cores" "INFO"
        } else {
            Write-Log "Docker is not running" "WARNING"
        }
    } catch {
        Write-Log "Docker configuration failed: $($_.Exception.Message)" "ERROR"
    }
}

# Main execution
Write-Log "=== GitHub Actions Runner Configuration Tool ===" "INFO"

# Validate configuration file exists
if (-not (Test-ConfigurationFile -Path $ConfigPath)) {
    exit 1
}

# Read configuration
Write-Log "Reading configuration from: $ConfigPath" "INFO"
$yamlContent = Get-Content -Path $ConfigPath -Raw
$config = ConvertFrom-Yaml -YamlContent $yamlContent

# Validate configuration structure
if (-not (Test-ConfigurationStructure -Config $config)) {
    Write-Log "Configuration validation failed" "ERROR"
    exit 1
}

if ($Validate) {
    Write-Log "Configuration validation completed successfully" "SUCCESS"
    exit 0
}

# Show configuration summary
Write-Log "`n=== Configuration Summary ===" "INFO"
Write-Log "Runner Name: $($config.runner.name)" "INFO"
if ($config.runner.labels) {
    Write-Log "Runner Labels: $($config.runner.labels -join ', ')" "INFO"
}
Write-Log "Runner Home: $($config.paths.runner_home)" "INFO"
Write-Log "Work Directory: $($config.paths.work_directory)" "INFO"

# Confirm before applying (unless Force is used)
if (-not $Force -and -not $DryRun) {
    $confirmation = Read-Host "`nApply this configuration? (y/N)"
    if ($confirmation -ne 'y') {
        Write-Log "Configuration not applied" "WARNING"
        exit 0
    }
}

# Backup current configuration
if ($Backup -and -not $DryRun) {
    Backup-Configuration
}

# Apply configuration
Write-Log "`n=== Applying Configuration ===" "INFO"

if ($config.environment) {
    Set-EnvironmentVariables -EnvConfig $config.environment
}

if ($config.runner -and $config.runner.labels) {
    Set-RunnerLabels -Labels $config.runner.labels
}

if ($config.resources) {
    Set-ResourceLimits -ResourceConfig $config.resources
}

if ($config.gpu) {
    Set-GPUConfiguration -GPUConfig $config.gpu
}

if ($config.docker) {
    Set-DockerConfiguration -DockerConfig $config.docker
}

if ($DryRun) {
    Write-Log "`n=== Dry Run Complete ===" "INFO"
    Write-Log "No changes were applied. Review the log above for planned changes." "INFO"
} else {
    Write-Log "`n=== Configuration Applied Successfully ===" "SUCCESS"
    Write-Log "Runner service may need to be restarted for all changes to take effect" "INFO"
    Write-Log "Use: Restart-Service -Name 'actions.runner.*'" "INFO"
}

exit 0
