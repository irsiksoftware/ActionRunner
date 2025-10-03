# GitHub Actions Runner Logging Architecture

## Overview

This document describes the logging and audit trail system for GitHub Actions self-hosted runners. The logging infrastructure provides comprehensive monitoring, debugging capabilities, and compliance tracking.

## Logging Components

### 1. Log Collection (`collect-logs.ps1`)

The log collection script gathers logs from multiple sources:

#### Collected Log Types

- **Runner Service Logs**: Service status, configuration, and operational logs
- **Job Execution Logs**: Workflow run logs and diagnostic information
- **System Performance Logs**: CPU, memory, disk, and network metrics
- **Security Audit Logs**: Authentication events, privilege changes, and security-related activities
- **Windows Event Logs**: Application and system events related to runner operations
- **Docker Logs**: Container logs and Docker events (if available)
- **Health Check Logs**: Runner health monitoring data

#### Usage

```powershell
# Basic collection (default: last 7 days)
.\scripts\collect-logs.ps1

# Include system and security logs
.\scripts\collect-logs.ps1 -IncludeSystem -IncludeSecurity

# Custom output path and retention
.\scripts\collect-logs.ps1 -OutputPath "C:\logs\archive" -Days 30

# Create compressed archive
.\scripts\collect-logs.ps1 -CreateArchive
```

#### Output Structure

```
logs/
└── collected/
    └── 20251003-120000/
        ├── collection-log.txt          # Collection process log
        ├── summary.json                # Summary statistics
        ├── runner-services.json        # Service information
        ├── runner-services.txt         # Human-readable service status
        ├── health-check.log            # Health monitoring logs
        ├── monitor-runner.log          # Runner monitoring logs
        ├── system-info.json            # System performance data
        ├── runner-diag/                # Runner diagnostic logs
        │   └── *.log
        ├── job-logs/                   # Job execution logs
        │   └── *.log
        ├── event-logs/                 # Windows Event Logs
        │   ├── application-events.csv
        │   └── system-events.csv
        ├── security-logs/              # Security audit logs
        │   └── security-events.csv
        └── docker-logs/                # Docker logs (if available)
            ├── docker-info.txt
            ├── docker-events.txt
            └── *_container.log
```

### 2. Log Rotation (`rotate-logs.ps1`)

Implements automated log rotation to prevent disk space issues while maintaining compliance.

#### Rotation Policies

- **Age-based rotation**: Archives logs older than retention period (default: 30 days)
- **Size-based rotation**: Rotates large log files exceeding 100MB
- **Compression**: Compresses archived logs using GZip to save disk space
- **Cleanup**: Removes very old archives (retention + 30 days)

#### Usage

```powershell
# Basic rotation (default: 30 days retention)
.\scripts\rotate-logs.ps1

# Custom retention period
.\scripts\rotate-logs.ps1 -RetentionDays 90

# Dry run (preview without making changes)
.\scripts\rotate-logs.ps1 -DryRun

# Custom directories
.\scripts\rotate-logs.ps1 -LogDirectory "C:\runner\logs" -ArchiveDirectory "D:\archive"

# Disable compression
.\scripts\rotate-logs.ps1 -CompressLogs:$false
```

#### Rotation Process

1. **Scan**: Identifies log files in the log directory
2. **Archive Old Files**: Moves files older than retention period to archive
3. **Compress**: Applies GZip compression to archived files
4. **Rotate Large Files**: Handles large active log files (>100MB)
5. **Cleanup**: Removes very old archives to prevent indefinite growth
6. **Report**: Generates statistics on space saved and files processed

### 3. Log Analysis (`analyze-logs.ps1`)

Analyzes collected logs to identify patterns, issues, and trends.

#### Analysis Features

- **Error Pattern Detection**: Identifies common errors and exceptions
- **Job Success Metrics**: Calculates job success rates
- **System Health**: Analyzes performance and resource usage
- **Security Events**: Reviews security-related activities
- **Recommendations**: Provides actionable recommendations

#### Usage

```powershell
# Basic analysis
.\scripts\analyze-logs.ps1

# Analyze specific collection
.\scripts\analyze-logs.ps1 -LogPath "logs\collected\20251003-120000"

# Extended analysis period
.\scripts\analyze-logs.ps1 -Days 30

# Generate HTML report
.\scripts\analyze-logs.ps1 -Format html

# Custom output location
.\scripts\analyze-logs.ps1 -OutputPath "reports"
```

#### Output Formats

- **Text**: Human-readable analysis report
- **JSON**: Machine-readable structured data
- **HTML**: Interactive web-based report with visualizations

## Log Retention Policy

### Default Retention Periods

| Log Type | Active Retention | Archive Retention | Total Retention |
|----------|------------------|-------------------|-----------------|
| Runner Service Logs | 7 days | 30 days | 37 days |
| Job Execution Logs | 7 days | 30 days | 37 days |
| System Performance | 7 days | 30 days | 37 days |
| Security Audit Logs | 14 days | 60 days | 74 days |
| Health Check Logs | 30 days | 60 days | 90 days |

### Storage Requirements

Estimated storage requirements vary based on runner activity:

- **Low Activity** (1-5 jobs/day): ~1-2 GB/month
- **Medium Activity** (10-20 jobs/day): ~5-10 GB/month
- **High Activity** (50+ jobs/day): ~20-50 GB/month

Compression typically reduces storage by 70-80%.

## Automation

### Scheduled Log Collection

Create a Windows Scheduled Task to run log collection daily:

```powershell
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
    -Argument '-ExecutionPolicy Bypass -File "C:\actions-runner\scripts\collect-logs.ps1" -IncludeSystem -IncludeSecurity'

$trigger = New-ScheduledTaskTrigger -Daily -At 2:00AM

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "GitHubRunner-LogCollection" `
    -Action $action -Trigger $trigger -Principal $principal `
    -Description "Daily GitHub Actions runner log collection"
```

### Scheduled Log Rotation

Create a scheduled task for weekly log rotation:

```powershell
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' `
    -Argument '-ExecutionPolicy Bypass -File "C:\actions-runner\scripts\rotate-logs.ps1" -RetentionDays 30'

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3:00AM

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "GitHubRunner-LogRotation" `
    -Action $action -Trigger $trigger -Principal $principal `
    -Description "Weekly GitHub Actions runner log rotation"
```

## Monitoring and Alerting

### Key Metrics to Monitor

1. **Disk Space Usage**: Monitor `/logs` directory size
2. **Error Rates**: Track error frequency in logs
3. **Job Success Rate**: Monitor job completion success
4. **Service Health**: Track runner service uptime
5. **Security Events**: Monitor authentication and privilege changes

### Alert Thresholds

- **Critical**: Disk space <10%, job success rate <50%, service down
- **Warning**: Disk space <20%, job success rate <80%, high error rate
- **Info**: Regular operational events

## Security Considerations

### Sensitive Data

Logs may contain sensitive information:

- Environment variables (tokens, passwords)
- Repository URLs and paths
- System configuration details
- User account information

### Protection Measures

1. **Access Control**: Restrict log file permissions to administrators only
2. **Encryption**: Consider encrypting logs at rest for compliance
3. **Redaction**: Avoid logging sensitive credentials (handled by runner)
4. **Secure Transmission**: Use secure methods for log shipping
5. **Audit Trail**: Log access to logs themselves for compliance

### Compliance

- **GDPR**: Personal data in logs should follow retention policies
- **SOC 2**: Maintain audit trails for access and changes
- **HIPAA**: Encrypt logs containing health information
- **ISO 27001**: Implement log monitoring and review procedures

## Troubleshooting

### Common Issues

#### Issue: Log Collection Fails

**Symptoms**: `collect-logs.ps1` exits with errors

**Solutions**:
1. Check PowerShell execution policy: `Get-ExecutionPolicy`
2. Run as Administrator for Event Log access
3. Verify runner paths exist
4. Check disk space availability

#### Issue: Logs Not Rotating

**Symptoms**: Disk space fills up, old logs remain

**Solutions**:
1. Verify scheduled task is enabled and running
2. Check task execution history in Task Scheduler
3. Run `rotate-logs.ps1 -DryRun` to preview rotation
4. Verify archive directory permissions

#### Issue: Cannot Access Event Logs

**Symptoms**: "Access denied" errors when collecting Event Logs

**Solutions**:
1. Run scripts as Administrator
2. Verify user has "Read" permission on Event Logs
3. Check Windows Event Log service is running

#### Issue: Large Archive Sizes

**Symptoms**: Archive directory consuming too much space

**Solutions**:
1. Enable compression: `rotate-logs.ps1 -CompressLogs`
2. Reduce retention period
3. Review and clean old archives manually
4. Implement external log shipping

## Best Practices

1. **Regular Collection**: Run log collection daily or after significant events
2. **Automated Rotation**: Schedule weekly rotation to prevent disk issues
3. **Monitor Disk Usage**: Set up alerts for disk space thresholds
4. **Review Analysis Reports**: Weekly review of analysis reports
5. **Test Recovery**: Periodically test log restoration from archives
6. **Document Changes**: Update this documentation when modifying logging
7. **Secure Storage**: Store production logs on secure, backed-up storage
8. **External Shipping**: Consider shipping logs to SIEM/log management systems

## Integration with External Systems

### Elasticsearch/Kibana

Ship logs to Elasticsearch for centralized analysis:

```powershell
# Example: Send logs to Elasticsearch
$logs = Get-Content "logs\collected\20251003-120000\summary.json" | ConvertFrom-Json
Invoke-RestMethod -Uri "http://elasticsearch:9200/runner-logs/_doc" `
    -Method Post -Body ($logs | ConvertTo-Json) `
    -ContentType "application/json"
```

### Splunk

Forward logs to Splunk for monitoring:

```powershell
# Configure Splunk Universal Forwarder to monitor logs directory
[monitor://C:\actions-runner\logs\]
disabled = false
index = github_runners
sourcetype = github:runner:logs
```

### Azure Monitor

Send logs to Azure Log Analytics:

```powershell
# Use Azure Monitor Agent or custom ingestion
$CustomerId = "<workspace-id>"
$SharedKey = "<workspace-key>"
$LogType = "GitHubRunnerLogs"

# Send-AzMonitorCustomLogs function (requires Az.OperationalInsights)
```

## Future Enhancements

- [ ] Real-time log streaming to external systems
- [ ] Advanced anomaly detection using ML
- [ ] Interactive dashboards for log visualization
- [ ] Integration with GitHub Actions insights API
- [ ] Automated incident response based on log patterns
- [ ] Multi-runner log aggregation
- [ ] Cost optimization analysis from logs

## References

- [GitHub Actions Runner Documentation](https://docs.github.com/en/actions/hosting-your-own-runners)
- [PowerShell Logging Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-logging)
- [Windows Event Log Reference](https://docs.microsoft.com/en-us/windows/win32/eventlog/event-logging)
- [Log Rotation Best Practices](https://en.wikipedia.org/wiki/Log_rotation)

---

**Document Version**: 1.0.0
**Last Updated**: 2025-10-03
**Maintained By**: GitHub Actions Runner Team
