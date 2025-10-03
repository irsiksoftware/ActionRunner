# Runner Configuration Management

This guide explains how to configure and manage your GitHub Actions self-hosted runner using the centralized configuration system.

## Overview

The configuration management system provides a YAML-based approach to managing runner settings, labels, resource limits, and environment variables. It supports multiple environments and workload profiles.

## Table of Contents

- [Configuration Files](#configuration-files)
- [Configuration Structure](#configuration-structure)
- [Using the Configuration Tool](#using-the-configuration-tool)
- [Environment-Specific Configurations](#environment-specific-configurations)
- [Workload Profiles](#workload-profiles)
- [Backup and Restore](#backup-and-restore)
- [Validation](#validation)
- [Best Practices](#best-practices)

## Configuration Files

Configuration files are located in the `config/` directory:

- **`runner-config.yaml`** - Default configuration template
- **`runner-config.dev.yaml`** - Development environment settings
- **`runner-config.prod.yaml`** - Production environment settings
- **`runner-config.gpu.yaml`** - GPU-focused workload profile
- **`runner-config.unity.yaml`** - Unity build workload profile
- **`runner-config.general.yaml`** - General-purpose workload profile

## Configuration Structure

### Runner Identity

```yaml
runner:
  name: "action-runner-01"
  labels:
    - "self-hosted"
    - "Windows"
    - "X64"
    - "gpu-enabled"
  group: "Default"
```

**Fields:**
- `name`: Unique identifier for the runner (leave empty to use hostname)
- `labels`: Array of labels for workflow targeting
- `group`: Runner group name (default: "Default")

### Working Directories

```yaml
paths:
  runner_home: "C:\\actions-runner"
  work_directory: "C:\\actions-runner\\_work"
  temp_directory: "C:\\Temp"
  log_directory: "C:\\actions-runner\\logs"
```

**Fields:**
- `runner_home`: Runner installation directory
- `work_directory`: Directory for job execution
- `temp_directory`: Temporary files location
- `log_directory`: Log files location

### Resource Limits

```yaml
resources:
  max_concurrent_jobs: 1
  cpu:
    max_cores: 0  # 0 = all available
    affinity: ""
  memory:
    max_memory_gb: 0  # 0 = unlimited
    reserved_memory_gb: 4
  disk:
    min_free_space_gb: 100
    auto_cleanup: true
    cleanup_per_job: true
```

**CPU Settings:**
- `max_cores`: Maximum CPU cores to use (0 = all available)
- `affinity`: CPU core affinity (comma-separated core numbers)

**Memory Settings:**
- `max_memory_gb`: Maximum memory allocation (0 = unlimited)
- `reserved_memory_gb`: Reserved system memory

**Disk Settings:**
- `min_free_space_gb`: Minimum required free space
- `auto_cleanup`: Enable automatic workspace cleanup
- `cleanup_per_job`: Clean up after each job

### Timeout Settings

```yaml
timeouts:
  job_timeout_minutes: 360
  queue_timeout_minutes: 30
  step_timeout_minutes: 60
```

### Environment Variables

```yaml
environment:
  system:
    DOTNET_ROOT: "C:\\Program Files\\dotnet"
    JAVA_HOME: "C:\\Program Files\\Java\\jdk-11"
  runner:
    ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT: "1"
  custom:
    CUSTOM_VAR: "value"
```

### GPU Configuration

```yaml
gpu:
  enabled: true
  cuda_version: "12.0"
  vram:
    reserved_vram_gb: 2
    max_vram_gb: 0
  compute_mode: "default"
```

### Docker Configuration

```yaml
docker:
  enabled: true
  socket_path: "npipe:////./pipe/docker_engine"
  isolation_mode: "process"
  container_limits:
    memory_gb: 8
    cpu_cores: 4
  auto_cleanup_containers: true
  auto_cleanup_images: false
```

### Monitoring & Health Checks

```yaml
monitoring:
  enabled: true
  health_check_interval: 300
  alert_webhook: ""
  alerts:
    runner_offline: true
    low_disk_space: true
    high_cpu_usage: true
  thresholds:
    cpu_warning_percent: 80
    cpu_critical_percent: 95
    memory_warning_percent: 85
    disk_warning_gb: 150
```

### Security Settings

```yaml
security:
  firewall_enabled: true
  allowed_networks:
    - "192.168.1.0/24"
  block_external_access: false
  audit_logging: true
  audit_log_path: "C:\\actions-runner\\logs\\audit.log"
```

## Using the Configuration Tool

### Apply Configuration

Apply the default configuration:

```powershell
.\scripts\apply-config.ps1
```

Apply a specific configuration file:

```powershell
.\scripts\apply-config.ps1 -ConfigPath "config\runner-config.prod.yaml"
```

Apply without confirmation:

```powershell
.\scripts\apply-config.ps1 -Force
```

### Validate Configuration

Validate configuration without applying:

```powershell
.\scripts\apply-config.ps1 -Validate
```

### Dry Run

Preview changes without applying:

```powershell
.\scripts\apply-config.ps1 -DryRun
```

### Create Backup

Apply with automatic backup:

```powershell
.\scripts\apply-config.ps1 -Backup
```

## Environment-Specific Configurations

### Development Environment

Use relaxed settings for development:

```powershell
.\scripts\apply-config.ps1 -ConfigPath "config\runner-config.dev.yaml"
```

**Characteristics:**
- Lower resource limits
- Relaxed security settings
- Debug logging enabled
- No maintenance windows
- Faster timeouts

### Production Environment

Use strict settings for production:

```powershell
.\scripts\apply-config.ps1 -ConfigPath "config\runner-config.prod.yaml"
```

**Characteristics:**
- Higher resource limits
- Strict security enforcement
- Automated maintenance windows
- Extended timeouts
- Auto-updates enabled

## Workload Profiles

### GPU-Focused Profile

Optimized for GPU-intensive workloads:

```powershell
.\scripts\apply-config.ps1 -ConfigPath "config\runner-config.gpu.yaml"
```

**Features:**
- GPU acceleration enabled
- High VRAM allocation
- CUDA toolkit configured
- Optimized for machine learning

### Unity Build Profile

Optimized for Unity game development:

```powershell
.\scripts\apply-config.ps1 -ConfigPath "config\runner-config.unity.yaml"
```

**Features:**
- Unity editor paths configured
- License management
- Batch mode builds
- Multiple Unity versions supported

### General-Purpose Profile

Balanced configuration for mixed workloads:

```powershell
.\scripts\apply-config.ps1 -ConfigPath "config\runner-config.general.yaml"
```

**Features:**
- Moderate resource allocation
- All tools enabled
- Balanced timeouts
- Standard security

## Backup and Restore

### Automatic Backups

Backups are automatically created in `config\backups\` when using the `-Backup` flag:

```powershell
config\backups\runner-config_2024-01-15_14-30-00.yaml
```

### Manual Backup

Create a manual backup:

```powershell
Copy-Item config\runner-config.yaml config\backups\runner-config_backup.yaml
```

### Restore from Backup

Restore a previous configuration:

```powershell
.\scripts\apply-config.ps1 -ConfigPath "config\backups\runner-config_2024-01-15_14-30-00.yaml"
```

## Validation

The configuration tool performs automatic validation:

### Structural Validation
- Checks for required sections
- Validates field types
- Ensures value ranges

### Resource Validation
- Verifies memory limits against available RAM
- Checks disk space requirements
- Validates CPU core counts

### Path Validation
- Ensures directories exist or can be created
- Validates write permissions
- Checks for path conflicts

### Common Validation Errors

**Missing Required Section:**
```
ERROR: Missing required section: runner
```
*Solution:* Add the missing section to your configuration file.

**Invalid Resource Limit:**
```
WARNING: Max memory (64 GB) exceeds available memory (32 GB)
```
*Solution:* Reduce the `max_memory_gb` value.

**Invalid Path:**
```
WARNING: Runner home directory does not exist: C:\invalid\path
```
*Solution:* Create the directory or update the path.

## Best Practices

### 1. Version Control

Store configuration files in version control:

```bash
git add config/runner-config*.yaml
git commit -m "Update runner configuration"
```

### 2. Environment Separation

Use separate configurations for different environments:
- Development: Low resources, relaxed security
- Staging: Mid-range resources, moderate security
- Production: High resources, strict security

### 3. Regular Backups

Enable automatic backups before applying changes:

```powershell
.\scripts\apply-config.ps1 -Backup
```

### 4. Validation First

Always validate before applying to production:

```powershell
.\scripts\apply-config.ps1 -ConfigPath "config\runner-config.prod.yaml" -Validate
```

### 5. Incremental Changes

Make small, incremental changes and test thoroughly:

1. Update configuration file
2. Validate configuration
3. Run dry run
4. Apply to development
5. Test thoroughly
6. Apply to production

### 6. Documentation

Document custom settings:

```yaml
# Custom configuration for ML workloads
# Updated: 2024-01-15
# Author: DevOps Team
runner:
  name: "ml-runner-01"
  # Using GPU labels for CUDA-enabled workflows
  labels:
    - "self-hosted"
    - "gpu"
    - "cuda-12.0"
```

### 7. Monitoring

Enable monitoring and health checks:

```yaml
monitoring:
  enabled: true
  health_check_interval: 300
  alerts:
    runner_offline: true
    low_disk_space: true
```

### 8. Security

Follow security best practices:

```yaml
security:
  firewall_enabled: true
  allowed_networks:
    - "10.0.0.0/8"  # Internal network only
  audit_logging: true
  block_external_access: true  # For sensitive workloads
```

### 9. Resource Planning

Set appropriate resource limits:

```yaml
resources:
  # Reserve resources for system operations
  memory:
    reserved_memory_gb: 4
  cpu:
    # Leave some cores for system
    max_cores: 14  # On a 16-core system
```

### 10. Maintenance Windows

Schedule maintenance during low-usage periods:

```yaml
maintenance:
  maintenance_window: "0 2 * * 0"  # 2 AM every Sunday
  backup_before_update: true
  auto_update: true
```

## Troubleshooting

### Configuration Not Applied

**Issue:** Changes don't take effect after applying configuration.

**Solution:** Restart the runner service:

```powershell
Restart-Service -Name 'actions.runner.*' -Force
```

### Validation Fails

**Issue:** Configuration validation fails.

**Solution:** Check the error message and review the configuration structure. Use the `--validate` flag to see detailed errors.

### Environment Variables Not Set

**Issue:** Environment variables are not available in jobs.

**Solution:** Ensure environment variables are set at the Machine level and restart the runner service.

### Permission Errors

**Issue:** Cannot create directories or write files.

**Solution:** Run PowerShell as Administrator:

```powershell
Start-Process powershell -Verb runAs
```

## Advanced Topics

### Custom Workload Profiles

Create custom profiles by copying and modifying existing templates:

```powershell
Copy-Item config\runner-config.yaml config\runner-config.custom.yaml
# Edit runner-config.custom.yaml
.\scripts\apply-config.ps1 -ConfigPath "config\runner-config.custom.yaml"
```

### Integration with CI/CD

Apply configuration as part of runner provisioning:

```yaml
- name: Apply Runner Configuration
  run: |
    .\scripts\apply-config.ps1 `
      -ConfigPath "config\runner-config.prod.yaml" `
      -Force `
      -Backup
```

### Configuration Templates

Use templates for consistent configuration across multiple runners:

```powershell
# Template with placeholders
$template = Get-Content config\runner-config.template.yaml
$config = $template -replace '{{RUNNER_NAME}}', 'runner-01'
Set-Content config\runner-config.yaml $config
```

## Support

For issues or questions:

1. Check the [Troubleshooting Guide](troubleshooting.md)
2. Review the [Maintenance Documentation](maintenance.md)
3. Open an issue on GitHub
4. Contact the DevOps team

## Related Documentation

- [Installation Guide](installation.md)
- [Maintenance Guide](maintenance.md)
- [Troubleshooting Guide](troubleshooting.md)
- [Security Best Practices](security.md)
