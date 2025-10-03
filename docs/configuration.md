# Runner Configuration Guide

Complete guide for configuring your GitHub Actions self-hosted runner using the centralized configuration system.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Configuration File Structure](#configuration-file-structure)
- [Configuration Options](#configuration-options)
- [Templates](#templates)
- [Applying Configuration](#applying-configuration)
- [Backup and Restore](#backup-and-restore)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

The runner configuration system provides a centralized YAML-based configuration for managing all aspects of your self-hosted GitHub Actions runner, including:

- Runner identity and labels
- Resource limits (CPU, memory, disk)
- Environment variables
- GPU and CUDA settings
- Unity configuration
- Docker settings
- Monitoring and alerts
- Security settings

## Quick Start

1. **Choose a configuration template** based on your workload:
   ```powershell
   # For GPU/ML workloads
   Copy-Item config\templates\gpu-focused.yaml config\runner-config.yaml

   # For Unity development
   Copy-Item config\templates\unity-focused.yaml config\runner-config.yaml

   # For general-purpose CI/CD
   Copy-Item config\templates\general-purpose.yaml config\runner-config.yaml
   ```

2. **Edit the configuration** file to match your environment:
   ```powershell
   notepad config\runner-config.yaml
   ```

3. **Validate the configuration**:
   ```powershell
   .\scripts\apply-config.ps1 -Validate
   ```

4. **Apply the configuration**:
   ```powershell
   .\scripts\apply-config.ps1
   ```

## Configuration File Structure

```yaml
# config/runner-config.yaml

runner:          # Runner identity and registration
paths:           # Directory paths
resources:       # Resource limits
timeouts:        # Job and step timeouts
environment:     # Environment variables
gpu:             # GPU/CUDA configuration
unity:           # Unity-specific settings
docker:          # Docker configuration
monitoring:      # Health checks and alerts
security:        # Security settings
logging:         # Log configuration
maintenance:     # Update and maintenance
webhooks:        # Notification webhooks
features:        # Feature flags
```

## Configuration Options

### Runner Identity

```yaml
runner:
  name: "my-runner"              # Leave empty to use hostname
  labels:                         # Runner labels for workflow targeting
    - self-hosted
    - windows
    - X64
    - gpu
  group: "Default"                # Runner group
```

**Common Labels:**
- `self-hosted` - Required for self-hosted runners
- `windows`, `linux`, `macos` - Operating system
- `X64`, `ARM64` - Architecture
- `gpu`, `cuda` - GPU availability
- `unity` - Unity support
- `docker` - Docker support

### Paths

```yaml
paths:
  runner_home: "C:\\actions-runner"
  work_directory: "C:\\actions-runner\\_work"
  temp_directory: "C:\\Temp"
  log_directory: "C:\\actions-runner\\logs"
```

### Resource Limits

```yaml
resources:
  max_concurrent_jobs: 1           # Number of concurrent jobs

  cpu:
    max_cores: 0                   # 0 = use all available
    affinity: ""                   # CPU affinity (e.g., "0,1,2,3")

  memory:
    max_memory_gb: 0               # 0 = unlimited
    reserved_memory_gb: 4          # Memory to reserve

  disk:
    min_free_space_gb: 100         # Minimum free space required
    auto_cleanup: true             # Enable automatic cleanup
    cleanup_per_job: true          # Cleanup after each job
```

### Timeouts

```yaml
timeouts:
  job_timeout_minutes: 360         # 6 hours
  queue_timeout_minutes: 30
  step_timeout_minutes: 60
```

### Environment Variables

```yaml
environment:
  system:                          # System environment variables
    DOTNET_ROOT: "C:\\Program Files\\dotnet"
    JAVA_HOME: "C:\\Program Files\\Java\\jdk-11"
    NODE_VERSION: "20.x"
    PYTHON_VERSION: "3.11"

  runner:                          # Runner-specific variables
    ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT: "1"

  custom:                          # Your custom variables
    MY_CUSTOM_VAR: "value"
```

### GPU Configuration

```yaml
gpu:
  enabled: true
  cuda_version: "12.0"

  vram:
    reserved_vram_gb: 2            # VRAM to reserve
    max_vram_gb: 0                 # 0 = unlimited

  compute_mode: "default"          # default, exclusive, prohibited
```

**CUDA Compute Modes:**
- `default` - Multiple processes can use the GPU
- `exclusive` - Only one process can use the GPU
- `prohibited` - No processes can use the GPU

### Unity Configuration

```yaml
unity:
  enabled: true

  installations:                   # Unity editor installations
    - version: "2022.3.x"
      path: "C:\\Program Files\\Unity\\Hub\\Editor\\2022.3.x"
    - version: "2023.2.x"
      path: "C:\\Program Files\\Unity\\Hub\\Editor\\2023.2.x"

  license:
    type: "professional"           # personal, professional, enterprise
    file_path: ""                  # Leave empty for default

  build:
    batch_mode: true
    quit_after_build: true
    accept_api_update: true
```

### Docker Configuration

```yaml
docker:
  enabled: true
  socket_path: "npipe:////./pipe/docker_engine"
  isolation_mode: "process"        # process, hyperv

  container_limits:
    memory_gb: 8
    cpu_cores: 4

  auto_cleanup_containers: true
  auto_cleanup_images: false
```

### Monitoring and Alerts

```yaml
monitoring:
  enabled: true
  health_check_interval: 300       # Seconds

  alert_webhook: "https://hooks.slack.com/..."  # Webhook URL

  alerts:
    runner_offline: true
    low_disk_space: true
    high_cpu_usage: true
    high_memory_usage: true
    job_failure: false

  thresholds:
    cpu_warning_percent: 80
    cpu_critical_percent: 95
    memory_warning_percent: 85
    memory_critical_percent: 95
    disk_warning_gb: 150
    disk_critical_gb: 100
```

**Supported Webhooks:**
- Slack
- Discord
- Microsoft Teams
- Custom webhooks

### Security Settings

```yaml
security:
  firewall_enabled: true

  allowed_networks:                # CIDR notation
    - "192.168.1.0/24"
    - "10.0.0.0/8"

  block_external_access: false     # Block during jobs
  audit_logging: true
  audit_log_path: "C:\\actions-runner\\logs\\audit.log"
```

### Logging

```yaml
logging:
  level: "info"                    # debug, info, warning, error
  retention_days: 30
  max_file_size_mb: 100
  rotation_enabled: true
  console_output: true
```

### Maintenance

```yaml
maintenance:
  auto_update: false
  update_check_interval_hours: 24
  backup_before_update: true
  maintenance_window: "0 2 * * 0" # Cron expression (2 AM Sundays)
```

## Templates

### GPU-Focused Template

Optimized for:
- Machine learning training
- CUDA workloads
- GPU-intensive computations

```powershell
Copy-Item config\templates\gpu-focused.yaml config\runner-config.yaml
```

**Features:**
- Exclusive GPU compute mode
- Extended timeouts for training jobs
- ML-specific environment variables
- High disk space requirements

### Unity-Focused Template

Optimized for:
- Unity game development
- Unity builds (Windows, Android, iOS)
- Asset processing

```powershell
Copy-Item config\templates\unity-focused.yaml config\runner-config.yaml
```

**Features:**
- Multiple Unity editor versions
- Unity-specific environment variables
- Extended build timeouts
- Large disk space allocation

### General-Purpose Template

Optimized for:
- Standard CI/CD workflows
- Multi-language builds
- Docker-based workflows

```powershell
Copy-Item config\templates\general-purpose.yaml config\runner-config.yaml
```

**Features:**
- Balanced resource allocation
- Docker support enabled
- Standard timeout values
- Moderate disk space requirements

## Applying Configuration

### Validate Configuration

```powershell
.\scripts\apply-config.ps1 -Validate
```

### Dry Run (Preview Changes)

```powershell
.\scripts\apply-config.ps1 -DryRun
```

### Apply Configuration

```powershell
# With confirmation prompt
.\scripts\apply-config.ps1

# Without confirmation
.\scripts\apply-config.ps1 -Force

# Custom configuration file
.\scripts\apply-config.ps1 -ConfigPath "config\custom.yaml"

# Apply without backup
.\scripts\apply-config.ps1 -Backup:$false
```

### Restart Runner Service

After applying configuration, restart the runner service:

```powershell
Restart-Service -Name "actions.runner.*"
```

## Backup and Restore

### Automatic Backups

Backups are automatically created when applying configuration (unless `-Backup:$false` is used):

```
config\backups\runner-config_2024-01-15_14-30-45.yaml
```

### Manual Backup

```powershell
Copy-Item config\runner-config.yaml config\backups\runner-config_manual.yaml
```

### Restore from Backup

```powershell
# List backups
Get-ChildItem config\backups\

# Restore specific backup
Copy-Item config\backups\runner-config_2024-01-15_14-30-45.yaml config\runner-config.yaml

# Apply restored configuration
.\scripts\apply-config.ps1
```

## Best Practices

### 1. Use Version Control

```bash
git add config/runner-config.yaml
git commit -m "Update runner configuration"
```

### 2. Test Configuration Changes

Always use dry run before applying:

```powershell
.\scripts\apply-config.ps1 -DryRun
```

### 3. Monitor Resource Usage

After configuration changes:
- Monitor CPU, memory, and disk usage
- Check runner health with `.\scripts\health-check.ps1`
- Review logs in `logs\apply-config.log`

### 4. Environment-Specific Configurations

Create separate configurations for different environments:

```
config\runner-config.dev.yaml
config\runner-config.staging.yaml
config\runner-config.prod.yaml
```

Apply with:
```powershell
.\scripts\apply-config.ps1 -ConfigPath "config\runner-config.prod.yaml"
```

### 5. Security Considerations

- Store sensitive values (API keys, tokens) in environment variables, not in config
- Use restrictive firewall rules
- Enable audit logging for compliance
- Regularly review security settings

### 6. Resource Allocation Guidelines

**CPU Cores:**
- Single-threaded jobs: 2-4 cores
- Parallel builds: 8+ cores
- ML training: All available cores

**Memory:**
- Basic CI/CD: 4-8 GB
- Docker builds: 8-16 GB
- Unity builds: 16-32 GB
- ML training: 32+ GB

**Disk Space:**
- Minimum: 100 GB
- Recommended: 250 GB
- ML/Unity: 500 GB+

## Troubleshooting

### Configuration Not Applied

1. Check validation:
   ```powershell
   .\scripts\apply-config.ps1 -Validate
   ```

2. Review logs:
   ```powershell
   Get-Content logs\apply-config.log -Tail 50
   ```

3. Verify runner service status:
   ```powershell
   Get-Service -Name "actions.runner.*"
   ```

### Environment Variables Not Set

Environment variables are set at machine level. May require:
- Runner service restart
- System restart (for some variables)

### GPU Not Detected

1. Verify NVIDIA driver installation:
   ```powershell
   nvidia-smi
   ```

2. Check CUDA installation:
   ```powershell
   nvcc --version
   ```

3. Review GPU configuration in config file

### Permission Errors

Run PowerShell as Administrator:
```powershell
Start-Process powershell -Verb RunAs
```

### Invalid YAML Syntax

Use a YAML validator or linter:
- VS Code with YAML extension
- Online validators (e.g., yamllint.com)

## Advanced Configuration

### Custom Configuration Schema

For advanced users, extend the configuration schema:

```yaml
custom:
  my_feature:
    enabled: true
    settings:
      option1: "value1"
      option2: 42
```

### Integration with External Tools

Export configuration for external tools:

```powershell
# Convert to JSON
Get-Content config\runner-config.yaml | ConvertFrom-Yaml | ConvertTo-Json -Depth 10
```

### Automated Configuration Updates

Schedule configuration updates:

```powershell
# Create scheduled task
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File .\scripts\apply-config.ps1 -Force"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2am
Register-ScheduledTask -TaskName "UpdateRunnerConfig" -Action $action -Trigger $trigger
```

## Support

For issues or questions:
- Check logs in `logs\apply-config.log`
- Run health check: `.\scripts\health-check.ps1`
- Review GitHub Issues
- Contact your DevOps team
