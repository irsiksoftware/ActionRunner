# Runner Maintenance Guide

This guide covers maintenance procedures for self-hosted GitHub Actions runners, focusing on storage management and workspace cleanup.

## Table of Contents

1. [Workspace Cleanup Strategy](#workspace-cleanup-strategy)
2. [Automated Cleanup](#automated-cleanup)
3. [Manual Cleanup](#manual-cleanup)
4. [Storage Monitoring](#storage-monitoring)
5. [Troubleshooting](#troubleshooting)

## Workspace Cleanup Strategy

### Overview

Self-hosted runners accumulate significant disk space over time, especially when building Unity projects, which can generate 100GB+ per project. Our cleanup strategy targets:

- **Unity Library folders**: Can reach 10-50GB per project
- **Build artifacts**: Binary outputs, intermediate files (bin, obj, build, dist)
- **Package caches**: node_modules, .nuget, .gradle (can be 1GB+ each)
- **Temporary files**: .tmp, .temp, .bak, .old files
- **Docker resources**: Stopped containers and dangling images
- **Old logs**: Log files older than 30 days

### Cleanup Thresholds

| Resource Type | Default Age Threshold | Notes |
|--------------|----------------------|-------|
| Unity Libraries | 7 days | Adjustable via `-DaysOld` |
| Build Artifacts | 7 days | Adjustable via `-DaysOld` |
| Package Caches | 7 days | Adjustable via `-DaysOld` |
| Temporary Files | 7 days | Adjustable via `-DaysOld` |
| Log Files | 30 days | Fixed in script |
| Docker Containers | 7 days (stopped) | Only removes stopped containers |

### Storage Targets

- **Minimum Free Space**: 500GB (configurable via `-MinFreeSpaceGB`)
- **Recommended Free Space**: 1TB for Unity projects
- **Critical Threshold**: 200GB (manual intervention required)

## Automated Cleanup

### Scheduled Workflow

The workspace cleanup runs automatically via GitHub Actions:

**Schedule**: Daily at 2 AM UTC

**Configuration**: `.github/workflows/workspace-cleanup.yml`

**What it does**:
1. Runs cleanup script with default parameters
2. Uploads cleanup logs as artifacts
3. Reports disk space after cleanup
4. Notifies on failures

### Manual Trigger

You can manually trigger the cleanup workflow with custom parameters:

1. Go to **Actions** → **Workspace Cleanup** in GitHub
2. Click **Run workflow**
3. Configure parameters:
   - **Dry Run**: Preview changes without deleting
   - **Days Old**: Age threshold (default: 7)
   - **Min Free Space GB**: Target free space (default: 500)
4. Click **Run workflow**

### Viewing Cleanup Logs

1. Go to the workflow run in GitHub Actions
2. Download the `cleanup-logs-*` artifact
3. Review `cleanup.log` for detailed operation history

## Manual Cleanup

### Running the Cleanup Script

#### Basic Usage

```powershell
# Run with default settings (7 days, 500GB minimum)
.\scripts\cleanup-workspace.ps1

# Preview what would be deleted (dry run)
.\scripts\cleanup-workspace.ps1 -DryRun

# More aggressive cleanup (14 days old, 300GB minimum)
.\scripts\cleanup-workspace.ps1 -DaysOld 14 -MinFreeSpaceGB 300

# Protect specific directories
.\scripts\cleanup-workspace.ps1 -ExcludePaths @("C:\important-project", "D:\protected-data")
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-DryRun` | Switch | false | Preview deletions without executing |
| `-DaysOld` | Int | 7 | Age threshold for cleanup (days) |
| `-MinFreeSpaceGB` | Int | 500 | Minimum free space target (GB) |
| `-LogPath` | String | logs\cleanup.log | Path to log file |
| `-ExcludePaths` | String[] | @() | Directories to exclude from cleanup |

#### Examples

**Emergency cleanup** (when disk is nearly full):
```powershell
.\scripts\cleanup-workspace.ps1 -DaysOld 3 -MinFreeSpaceGB 200
```

**Conservative cleanup** (preserve more files):
```powershell
.\scripts\cleanup-workspace.ps1 -DaysOld 30 -MinFreeSpaceGB 800
```

**Dry run before major cleanup**:
```powershell
.\scripts\cleanup-workspace.ps1 -DryRun -DaysOld 7
# Review output, then run for real if acceptable
.\scripts\cleanup-workspace.ps1 -DaysOld 7
```

### Setting Up Windows Task Scheduler

For additional scheduled cleanup beyond GitHub Actions:

```powershell
# Create scheduled task (daily at 3 AM)
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\actions-runner\cleanup-workspace.ps1"

$trigger = New-ScheduledTaskTrigger -Daily -At 3am

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

Register-ScheduledTask -TaskName "RunnerWorkspaceCleanup" `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Description "Automated workspace cleanup for GitHub Actions runner"
```

## Storage Monitoring

### Check Current Disk Space

```powershell
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | ForEach-Object {
    $freeGB = [math]::Round($_.Free / 1GB, 2)
    $totalGB = [math]::Round(($_.Free + $_.Used) / 1GB, 2)
    $percentFree = [math]::Round(($_.Free / ($_.Free + $_.Used)) * 100, 2)
    Write-Host "Drive $($_.Name): $freeGB GB free of $totalGB GB ($percentFree% free)"
}
```

### Find Large Directories

```powershell
# Find top 20 largest directories
Get-ChildItem -Path . -Directory -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object {
        $size = (Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        [PSCustomObject]@{
            Path = $_.FullName
            SizeGB = [math]::Round($size / 1GB, 2)
        }
    } |
    Sort-Object SizeGB -Descending |
    Select-Object -First 20
```

### Monitor Specific Resource Types

```powershell
# Count and size of Unity Library folders
Get-ChildItem -Path . -Directory -Recurse -Filter "Library" -ErrorAction SilentlyContinue |
    Where-Object { Test-Path (Join-Path $_.Parent.FullName "Assets") } |
    ForEach-Object {
        $size = (Get-ChildItem -Path $_.FullName -Recurse -File -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum).Sum
        [PSCustomObject]@{
            Project = $_.Parent.Name
            SizeGB = [math]::Round($size / 1GB, 2)
            LastModified = $_.LastWriteTime
        }
    } |
    Sort-Object SizeGB -Descending
```

## Troubleshooting

### Cleanup Script Fails

**Symptom**: Script exits with errors

**Solutions**:
1. Check logs in `logs\cleanup.log`
2. Verify permissions (run as Administrator if needed)
3. Check for locked files (close Unity, Visual Studio, etc.)
4. Run with `-DryRun` to identify problematic paths

### Insufficient Space After Cleanup

**Symptom**: Still below minimum free space threshold

**Solutions**:
1. Run with more aggressive settings: `-DaysOld 3`
2. Check for large files manually: `Get-ChildItem -Recurse | Sort-Object Length -Descending | Select-Object -First 20`
3. Review excluded paths: Some directories might be protected
4. Clean Docker images: `docker system prune -a --volumes`
5. Check Windows update cache: `cleanmgr.exe`

### Protected Directories Getting Deleted

**Symptom**: Important files are removed

**Solutions**:
1. Use `-ExcludePaths` parameter: `-ExcludePaths @("C:\important")`
2. Update workflow to include exclusions
3. Review cleanup patterns in script (lines 193-230)
4. Keep critical projects in dedicated protected location

### Docker Cleanup Errors

**Symptom**: Docker-related errors in logs

**Solutions**:
1. Ensure Docker Desktop is running
2. Check Docker permissions
3. Manually prune: `docker system prune -af`
4. Skip Docker cleanup by commenting out line 378 in script

### Log File Not Created

**Symptom**: No log file appears

**Solutions**:
1. Verify logs directory exists or can be created
2. Check write permissions
3. Specify custom log path: `-LogPath "C:\temp\cleanup.log"`
4. Run as Administrator

## Best Practices

1. **Run dry run first**: Always use `-DryRun` before major cleanups
2. **Monitor logs**: Review cleanup logs regularly for patterns
3. **Adjust thresholds**: Tune `-DaysOld` based on your workflow frequency
4. **Use exclusions**: Protect active development projects
5. **Schedule wisely**: Run during low-activity periods (e.g., 2-4 AM)
6. **Keep backups**: Ensure critical data is backed up elsewhere
7. **Regular monitoring**: Check disk space weekly
8. **Document exclusions**: Maintain list of protected directories

## Related Documentation

- [Security Guide](./security.md)
- [README](../README.md)

## Support

For issues or questions:
- Review cleanup logs in `logs/cleanup.log`
- Check [GitHub Actions troubleshooting guide](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/monitoring-and-troubleshooting-self-hosted-runners)
- Open issue in repository with log details
