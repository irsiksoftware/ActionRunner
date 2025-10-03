# Runner Logging and Audit Trail System

This document describes the centralized logging system for runner operations, job executions, and system events.

## Overview

The logging system provides comprehensive audit trails and debugging capabilities for the GitHub Actions self-hosted runner environment. It includes automated log collection, rotation, and analysis tools.

## Architecture

### Directory Structure

```
logs/
├── runner/           # Runner service logs
├── jobs/            # Job execution logs
├── performance/     # System performance snapshots
├── security/        # Security audit logs
├── archive/         # Compressed historical logs
└── .gitkeep         # Ensures directory is tracked
```

### Log Types

1. **Runner Service Logs**: GitHub Actions runner daemon logs, service status, and operational events
2. **Job Execution Logs**: Individual workflow job logs, step outputs, and execution results
3. **Performance Logs**: CPU, memory, disk usage, and process metrics
4. **Security Logs**: Authentication events, access control, and firewall status

## Components

### 1. Log Collection (`scripts/collect-logs.ps1`)

Collects logs from various sources into a centralized location.

**Usage:**
```powershell
# Basic collection (last 7 days)
.\scripts\collect-logs.ps1

# Custom time range
.\scripts\collect-logs.ps1 -Days 30

# Include Windows Event Log
.\scripts\collect-logs.ps1 -IncludeWindowsEvents

# Custom output path
.\scripts\collect-logs.ps1 -OutputPath "C:\Logs\Runner"
```

**Parameters:**
- `-OutputPath`: Destination directory (default: `.\logs`)
- `-Days`: Number of days to collect (default: 7)
- `-IncludeWindowsEvents`: Include Windows security events (requires admin)

**Sources Scanned:**
- `$env:RUNNER_ROOT\_diag` - Runner diagnostic logs
- `$env:RUNNER_ROOT\_work` - Job execution logs
- System performance metrics
- Windows Event Log (optional)

**Output:**
Creates a timestamped collection directory with:
- `runner-service.log` - Aggregated runner logs
- `job-executions.log` - Job execution summary
- `system-performance.log` - Performance snapshot
- `security-audit.log` - Security events
- `manifest.json` - Collection metadata

### 2. Log Rotation (`scripts/rotate-logs.ps1`)

Implements automatic log rotation and archival to manage disk space.

**Usage:**
```powershell
# Default rotation (30-day retention)
.\scripts\rotate-logs.ps1

# Custom retention periods
.\scripts\rotate-logs.ps1 -RetentionDays 14 -ArchiveRetentionDays 60

# Dry run (preview changes)
.\scripts\rotate-logs.ps1 -DryRun

# Custom log path
.\scripts\rotate-logs.ps1 -LogPath "C:\Logs\Runner"
```

**Parameters:**
- `-LogPath`: Logs directory (default: `.\logs`)
- `-RetentionDays`: Days to keep uncompressed (default: 30)
- `-ArchiveRetentionDays`: Days to keep archived (default: 90)
- `-DryRun`: Preview without making changes

**Rotation Policy:**
1. **Days 0-30**: Logs remain uncompressed in place
2. **Days 31-90**: Logs compressed and moved to `archive/`
3. **After 90 days**: Archived logs deleted

**Process:**
1. Scans for logs older than retention period
2. Compresses logs to `.zip` format
3. Moves archives to `archive/` directory
4. Deletes archives older than archive retention
5. Cleans up empty directories

### 3. Log Analysis (`scripts/analyze-logs.ps1`)

Analyzes collected logs to identify patterns, errors, and performance trends.

**Usage:**
```powershell
# Basic analysis (last 7 days)
.\scripts\analyze-logs.ps1

# Extended period
.\scripts\analyze-logs.ps1 -Days 30

# JSON output
.\scripts\analyze-logs.ps1 -OutputFormat JSON -ReportPath .\reports\analysis.json

# HTML report
.\scripts\analyze-logs.ps1 -OutputFormat HTML -ReportPath .\reports\analysis.html
```

**Parameters:**
- `-LogPath`: Logs directory (default: `.\logs`)
- `-Days`: Analysis period in days (default: 7)
- `-OutputFormat`: Output format - `Text`, `JSON`, or `HTML` (default: `Text`)
- `-ReportPath`: Save report to file

**Analysis Includes:**
- **Error Detection**: Identifies errors, exceptions, warnings, and failures
- **Job Metrics**: Success/failure rates, execution counts
- **Performance**: CPU and memory usage trends, peak values
- **Security**: Authentication events, access violations
- **Recommendations**: Automated suggestions based on findings

**Error Categories:**
- Errors (High severity)
- Exceptions (High severity)
- Failures (Medium severity)
- Warnings (Low severity)
- Timeouts (Medium severity)
- Access Denied (High severity)

## Windows Event Log Integration

The logging system can integrate with Windows Event Log for enhanced security auditing.

**Event IDs Monitored:**
- `4624`: Successful logon
- `4625`: Failed logon
- `4672`: Special privileges assigned

**Requirements:**
- Administrator privileges
- Enable via `-IncludeWindowsEvents` flag

**Configuration:**
```powershell
# Enable Windows Event Log collection
.\scripts\collect-logs.ps1 -IncludeWindowsEvents

# Analyze security events
.\scripts\analyze-logs.ps1 -Days 30
```

## Automation

### Scheduled Log Collection

Create a scheduled task to collect logs daily:

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-File C:\Code\ActionRunner\scripts\collect-logs.ps1"

$trigger = New-ScheduledTaskTrigger -Daily -At "02:00AM"

Register-ScheduledTask -TaskName "Runner-LogCollection" `
    -Action $action -Trigger $trigger -Description "Daily runner log collection"
```

### Automated Log Rotation

Schedule weekly log rotation:

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-File C:\Code\ActionRunner\scripts\rotate-logs.ps1"

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "03:00AM"

Register-ScheduledTask -TaskName "Runner-LogRotation" `
    -Action $action -Trigger $trigger -Description "Weekly log rotation and archival"
```

### Automated Analysis

Schedule weekly analysis reports:

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-File C:\Code\ActionRunner\scripts\analyze-logs.ps1 -Days 7 -OutputFormat HTML -ReportPath C:\Reports\weekly-analysis.html"

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At "08:00AM"

Register-ScheduledTask -TaskName "Runner-LogAnalysis" `
    -Action $action -Trigger $trigger -Description "Weekly log analysis report"
```

## Log Retention Policy

### Default Policy

| Stage | Duration | Location | Format | Action |
|-------|----------|----------|--------|--------|
| Active | 0-30 days | `logs/` | Uncompressed | Keep in place |
| Archive | 31-90 days | `logs/archive/` | Compressed (.zip) | Keep compressed |
| Expired | >90 days | - | - | Delete |

### Custom Policy

Adjust retention periods based on compliance requirements:

```powershell
# Extended retention for compliance
.\scripts\rotate-logs.ps1 -RetentionDays 90 -ArchiveRetentionDays 365

# Minimal retention for space constraints
.\scripts\rotate-logs.ps1 -RetentionDays 7 -ArchiveRetentionDays 30
```

## Monitoring and Alerts

### Disk Space Monitoring

Monitor log directory size:

```powershell
$logSize = (Get-ChildItem -Path .\logs -Recurse | Measure-Object -Property Length -Sum).Sum
$logSizeGB = [math]::Round($logSize / 1GB, 2)

if ($logSizeGB -gt 5) {
    Write-Warning "Log directory exceeds 5GB ($logSizeGB GB). Run rotation."
}
```

### Error Rate Monitoring

Monitor error trends:

```powershell
$analysis = .\scripts\analyze-logs.ps1 -Days 1 -OutputFormat JSON | ConvertFrom-Json

if ($analysis.Errors.TotalCount -gt 50) {
    Write-Warning "High error count detected: $($analysis.Errors.TotalCount) errors"
}

if ($analysis.Jobs.SuccessRate -lt 80) {
    Write-Warning "Low job success rate: $($analysis.Jobs.SuccessRate)%"
}
```

## Log Shipping (Future Enhancement)

Future versions will support shipping logs to external systems:

- **Elasticsearch**: For centralized log aggregation
- **Splunk**: For enterprise log analysis
- **Azure Log Analytics**: For cloud-based monitoring
- **Syslog**: For standard syslog servers

## Troubleshooting

### Common Issues

**Issue: "Access Denied" when collecting logs**
```powershell
# Run with administrator privileges
Start-Process powershell -Verb RunAs -ArgumentList "-File .\scripts\collect-logs.ps1"
```

**Issue: Large log directory size**
```powershell
# Run immediate rotation
.\scripts\rotate-logs.ps1 -RetentionDays 7

# Check current size
Get-ChildItem -Path .\logs -Recurse | Measure-Object -Property Length -Sum
```

**Issue: Missing runner logs**
```powershell
# Check runner paths
$env:RUNNER_ROOT
Get-ChildItem "$env:RUNNER_ROOT\_diag" -Recurse
```

**Issue: Analysis returns no data**
```powershell
# Verify logs exist and are recent
Get-ChildItem -Path .\logs -Recurse -File | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-7) }

# Run collection first
.\scripts\collect-logs.ps1
```

## Security Considerations

1. **Access Control**: Restrict log directory access to runner service account and administrators
2. **Sensitive Data**: Logs may contain sensitive information - implement appropriate access controls
3. **Encryption**: Consider encrypting archived logs for compliance
4. **Audit Trail**: Log collection and rotation activities are logged for audit purposes

## Best Practices

1. **Regular Collection**: Schedule daily log collection during off-peak hours
2. **Consistent Rotation**: Run weekly rotation to manage disk space
3. **Periodic Analysis**: Generate weekly or monthly analysis reports
4. **Monitor Trends**: Track error rates and performance metrics over time
5. **Archive Important Logs**: Extend retention for critical periods (releases, incidents)
6. **Document Incidents**: Cross-reference logs with incident reports
7. **Test Recovery**: Periodically verify log archives can be restored

## Related Documentation

- [Configuration Management](./configuration.md)
- [Health Monitoring](./health-monitoring.md)
- [Security Best Practices](./security.md)

## Support

For issues or questions about the logging system:
1. Check logs in `logs/` directory
2. Run analysis: `.\scripts\analyze-logs.ps1`
3. Review error patterns and recommendations
4. Consult troubleshooting section above
