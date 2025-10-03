# Runner Upgrade Guide

This guide covers the process of updating the GitHub Actions self-hosted runner to newer versions safely and reliably.

## Overview

The runner update process is automated through the `update-runner.ps1` script, which handles:
- Version checking and availability
- Graceful job completion waiting
- Configuration backup and preservation
- Safe installation and rollback
- Service restart and verification

## Update Methods

### Automated Update (Recommended)

Use the update script for a safe, automated update process:

```powershell
# Update to latest version with default settings
.\scripts\update-runner.ps1

# Update to a specific version
.\scripts\update-runner.ps1 -Version "2.311.0"

# Force update without prompts
.\scripts\update-runner.ps1 -Force

# Dry run to check what would happen
.\scripts\update-runner.ps1 -DryRun
```

### Manual Update

For manual updates or troubleshooting:

1. Stop the runner service
2. Backup configuration files
3. Download new runner package
4. Extract and replace files
5. Restart service

See [Manual Update Process](#manual-update-process) below.

## Pre-Update Checklist

Before updating, ensure:

- [ ] Administrator privileges available
- [ ] Minimum 5GB free disk space
- [ ] No critical jobs scheduled during update window
- [ ] Recent configuration backup exists
- [ ] Update window allows for rollback if needed (30+ minutes)

## Update Script Usage

### Basic Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-RunnerPath` | String | `C:\actions-runner` | Runner installation directory |
| `-Force` | Switch | `false` | Skip confirmation prompts |
| `-SkipBackup` | Switch | `false` | Skip configuration backup (not recommended) |
| `-Version` | String | `latest` | Specific version to install |
| `-MaxWaitMinutes` | Integer | `60` | Max time to wait for jobs to complete |
| `-DryRun` | Switch | `false` | Simulate update without changes |

### Examples

#### Check for Available Updates

```powershell
# See what version is available without installing
.\scripts\update-runner.ps1 -DryRun
```

#### Update During Maintenance Window

```powershell
# Update with extended wait time for long-running jobs
.\scripts\update-runner.ps1 -MaxWaitMinutes 120
```

#### Emergency Update

```powershell
# Force immediate update (stops runner after timeout)
.\scripts\update-runner.ps1 -Force -MaxWaitMinutes 10
```

## Update Process Flow

The script follows this process:

### 1. Pre-Update Validation

- ✅ Verify runner path exists
- ✅ Check administrator privileges
- ✅ Validate disk space (minimum 5GB)
- ✅ Detect current runner version
- ✅ Check for latest available version

### 2. Version Comparison

- Compare current vs. latest version
- Display release notes
- Prompt for confirmation (unless `-Force`)
- Exit if already up-to-date

### 3. Job Completion Wait

- Monitor runner for active jobs
- Wait up to `MaxWaitMinutes` for completion
- Check every 30 seconds
- Warn if timeout approaching

### 4. Service Stop

- Gracefully stop runner service
- Wait for complete shutdown
- Verify process termination

### 5. Configuration Backup

- Backup `.runner` configuration file
- Backup `.credentials` file
- Backup `.path` file
- Store in timestamped backup directory
- Skip if `-SkipBackup` specified

### 6. Download and Install

- Download runner package from GitHub
- Verify download integrity
- Extract to temporary location
- Preserve configuration files
- Move new files to runner directory

### 7. Verification

- Verify runner binary exists
- Check configuration integrity
- Validate service registration

### 8. Service Restart

- Start runner service
- Monitor startup process
- Verify runner comes online
- Check version confirmation

### 9. Rollback (If Failure)

- Detect installation failures
- Restore from backup automatically
- Restart with previous version
- Log rollback actions

## Rollback Mechanism

The script includes automatic rollback on failure:

### When Rollback Triggers

- Download fails
- Extraction errors
- Service won't start
- Configuration corruption
- Version verification fails

### Rollback Process

1. Stop runner service
2. Remove failed installation files
3. Restore from backup directory
4. Restart service with old version
5. Verify successful rollback
6. Log rollback details

### Manual Rollback

If automatic rollback fails:

```powershell
# 1. Stop the runner service
Stop-Service -Name "actions.runner.*"

# 2. Find backup directory (sorted by date)
$backupDir = Get-ChildItem "C:\actions-runner\backups" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

# 3. Restore configuration files
Copy-Item "$backupDir\.runner" "C:\actions-runner\" -Force
Copy-Item "$backupDir\.credentials" "C:\actions-runner\" -Force
Copy-Item "$backupDir\.path" "C:\actions-runner\" -Force

# 4. Restart service
Start-Service -Name "actions.runner.*"
```

## Maintenance Mode

To temporarily disable the runner:

### Enable Maintenance Mode

```powershell
# Stop accepting new jobs
Stop-Service -Name "actions.runner.*"

# Verify no jobs are running
Get-Process | Where-Object { $_.ProcessName -like "*Runner*" }
```

### Disable Maintenance Mode

```powershell
# Resume accepting jobs
Start-Service -Name "actions.runner.*"

# Verify runner is online
Get-Service -Name "actions.runner.*"
```

### Schedule Maintenance Window

```powershell
# Create scheduled task for maintenance mode
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-Command Stop-Service -Name 'actions.runner.*'"

$trigger = New-ScheduledTaskTrigger -Once -At "2:00 AM"

Register-ScheduledTask -TaskName "Runner-MaintenanceMode" `
    -Action $action -Trigger $trigger
```

## Update Notifications

### Check for Update Availability

The script can be run in check-only mode:

```powershell
# Check for updates without installing
$result = .\scripts\update-runner.ps1 -DryRun

# Parse output to determine if update available
if ($result -match "Update available") {
    Write-Host "New runner version available!"
}
```

### Automated Update Checks

Create a scheduled task to check for updates:

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-File C:\Code\ActionRunner\scripts\update-runner.ps1 -DryRun"

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At "9:00AM"

Register-ScheduledTask -TaskName "Runner-UpdateCheck" `
    -Action $action -Trigger $trigger -Description "Weekly runner update check"
```

### Email Notifications

Configure email alerts for update availability:

```powershell
# Add to update-runner.ps1 or create wrapper script
if ($updateAvailable) {
    Send-MailMessage -To "admin@example.com" `
        -From "runner@example.com" `
        -Subject "Runner Update Available" `
        -Body "New runner version $latestVersion is available" `
        -SmtpServer "smtp.example.com"
}
```

## Manual Update Process

For cases where the automated script cannot be used:

### 1. Stop Runner

```powershell
# Stop the service
Stop-Service -Name "actions.runner.*"

# Verify process stopped
Get-Process | Where-Object { $_.ProcessName -like "*Runner*" }
```

### 2. Backup Configuration

```powershell
# Create backup directory
$backupPath = "C:\actions-runner\backups\manual-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
New-Item -ItemType Directory -Path $backupPath -Force

# Backup configuration files
Copy-Item "C:\actions-runner\.runner" $backupPath
Copy-Item "C:\actions-runner\.credentials" $backupPath
Copy-Item "C:\actions-runner\.path" $backupPath
```

### 3. Download New Version

```powershell
# Get latest version URL
$apiUrl = "https://api.github.com/repos/actions/runner/releases/latest"
$release = Invoke-RestMethod -Uri $apiUrl
$downloadUrl = ($release.assets | Where-Object { $_.name -like "*win-x64-*.zip" }).browser_download_url

# Download runner package
$packagePath = "C:\Temp\actions-runner-win-x64.zip"
Invoke-WebRequest -Uri $downloadUrl -OutFile $packagePath
```

### 4. Install New Version

```powershell
# Extract to temporary location
$tempPath = "C:\Temp\runner-extract"
Expand-Archive -Path $packagePath -DestinationPath $tempPath -Force

# Remove old files (keep config and data)
Get-ChildItem "C:\actions-runner" -File |
    Where-Object { $_.Name -notin @('.runner', '.credentials', '.path') } |
    Remove-Item -Force

# Copy new files
Copy-Item "$tempPath\*" "C:\actions-runner\" -Recurse -Force

# Restore configuration
Copy-Item "$backupPath\*" "C:\actions-runner\" -Force
```

### 5. Restart Service

```powershell
# Start the service
Start-Service -Name "actions.runner.*"

# Verify service is running
Get-Service -Name "actions.runner.*" | Format-List

# Check runner version
& "C:\actions-runner\config.cmd" --version
```

## Troubleshooting

### Update Fails to Download

**Symptom**: Download errors or timeout

**Solution**:
```powershell
# Check internet connectivity
Test-NetConnection github.com -Port 443

# Try manual download with proxy
$proxy = [System.Net.WebRequest]::GetSystemWebProxy()
$proxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
Invoke-WebRequest -Uri $downloadUrl -OutFile $packagePath -Proxy $proxy.GetProxy($downloadUrl)
```

### Service Won't Start After Update

**Symptom**: Service fails to start or crashes immediately

**Solution**:
```powershell
# Check service status and error
Get-Service -Name "actions.runner.*" | Format-List
Get-EventLog -LogName Application -Source "actions.runner.*" -Newest 10

# Verify configuration files
Test-Path "C:\actions-runner\.runner"
Test-Path "C:\actions-runner\.credentials"

# Try reconfiguring
cd C:\actions-runner
.\config.cmd remove
.\config.cmd --url <repo-url> --token <token>
```

### Version Mismatch After Update

**Symptom**: Runner reports old version after update

**Solution**:
```powershell
# Force service restart
Restart-Service -Name "actions.runner.*" -Force

# Verify binary version
& "C:\actions-runner\Runner.Listener.exe" --version

# Check if update actually applied
Get-ChildItem "C:\actions-runner\*.exe" | Select-Object Name, LastWriteTime
```

### Rollback Fails

**Symptom**: Automatic rollback doesn't work

**Solution**:
```powershell
# Manual rollback from backup
$latestBackup = Get-ChildItem "C:\actions-runner\backups" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

# Stop service
Stop-Service -Name "actions.runner.*"

# Restore all files from backup
Copy-Item "$($latestBackup.FullName)\*" "C:\actions-runner\" -Recurse -Force

# Restart service
Start-Service -Name "actions.runner.*"
```

## Update Logs

All update operations are logged to:

```
C:\actions-runner\logs\update-YYYYMMDD-HHMMSS.log
```

### Log Contents

- Pre-update checks
- Version information
- Job wait status
- Download progress
- Installation steps
- Verification results
- Rollback actions (if triggered)
- Service status changes

### Analyzing Update Logs

```powershell
# View recent update logs
Get-ChildItem "C:\actions-runner\logs" -Filter "update-*.log" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 5

# Search for errors in update logs
Get-ChildItem "C:\actions-runner\logs" -Filter "update-*.log" |
    Select-String -Pattern "ERROR" -Context 2, 2
```

## Best Practices

### Update Scheduling

1. **Regular Updates**: Update monthly or when security patches released
2. **Maintenance Windows**: Schedule updates during low-activity periods
3. **Testing**: Test updates on non-production runner first
4. **Communication**: Notify team before planned updates

### Backup Strategy

1. **Automatic Backups**: Let script create backups (don't use `-SkipBackup`)
2. **Retention**: Keep last 10 backup sets
3. **Verification**: Periodically test backup restoration
4. **External Copy**: Store critical configs offsite

### Monitoring

1. **Version Tracking**: Log current version in monitoring system
2. **Update History**: Maintain changelog of updates
3. **Health Checks**: Run health check after updates
4. **Job Success Rate**: Monitor job failures post-update

### Rollback Criteria

Rollback if:
- Runner fails to start after 3 attempts
- Job failure rate increases >50%
- Critical jobs fail immediately post-update
- Configuration corruption detected

## Related Documentation

- [Maintenance Guide](./maintenance.md) - Routine maintenance procedures
- [Health Monitoring](./health-monitoring.md) - Runner health checks
- [Troubleshooting Guide](./troubleshooting.md) - Common issues and solutions

## Support

For update-related issues:
1. Check update logs in `C:\actions-runner\logs`
2. Review error messages and context
3. Attempt rollback if unstable
4. Consult troubleshooting section above
5. Check GitHub Actions status: https://www.githubstatus.com
