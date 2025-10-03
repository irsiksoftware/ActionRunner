# GitHub Actions Runner Logging and Audit Trail

This document describes the logging architecture, tools, and best practices for monitoring and debugging GitHub Actions self-hosted runners.

## Overview

The logging system provides comprehensive monitoring, audit trails, and debugging capabilities for runner operations. It includes automated log collection, rotation, and analysis tools.

## Architecture

### Log Types

1. **Runner Service Logs**
   - Service status and health information
   - Runner registration and configuration
   - Service lifecycle events

2. **Job Execution Logs**
   - Individual job run details
   - Step-by-step execution traces
   - Diagnostic information from `_diag` directory

3. **System Performance Logs**
   - CPU usage metrics
   - Memory availability
   - Disk I/O statistics
   - Network throughput

4. **Security Audit Logs**
   - Windows Event Log entries
   - Authentication events
   - Permission changes
   - Security-related activities

### Directory Structure

```
logs/
├── .gitkeep                    # Keeps directory in version control
├── .gitignore                  # Excludes log files from git
├── README.md                   # Log directory documentation
├── archive/                    # Compressed archived logs
│   └── *.zip                  # Compressed log archives
├── runner-logs-*.json         # Collected log data
├── rotation-report-*.json     # Log rotation reports
└── analysis-report-*.*        # Analysis reports (JSON/HTML)
```

## Log Management Tools

### 1. Log Collection (`scripts/collect-logs.ps1`)

Collects logs from various sources into a centralized location.

#### Usage

```powershell
# Basic usage - collect last 7 days
.\scripts\collect-logs.ps1

# Collect last 30 days with custom output path
.\scripts\collect-logs.ps1 -OutputPath "C:\Logs\Runner" -DaysToCollect 30

# Collect without system logs
.\scripts\collect-logs.ps1 -IncludeSystemLogs $false
```

#### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `OutputPath` | Directory for collected logs | `.\logs` |
| `IncludeSystemLogs` | Include performance and security logs | `$true` |
| `DaysToCollect` | Number of days to collect | `7` |

#### Output Files

- `runner-logs-{timestamp}-service-info.json` - Service status
- `runner-logs-{timestamp}-job-logs.json` - Job execution details
- `runner-logs-{timestamp}-performance.json` - Performance metrics
- `runner-logs-{timestamp}-eventlog-*.json` - Windows Event Logs
- `runner-logs-{timestamp}-summary.json` - Collection summary

### 2. Log Rotation (`scripts/rotate-logs.ps1`)

Manages log file lifecycle to prevent disk space issues.

#### Usage

```powershell
# Basic usage - default settings
.\scripts\rotate-logs.ps1

# Custom retention and compression
.\scripts\rotate-logs.ps1 -RetentionDays 60 -CompressAfterDays 14

# Delete old archives after 180 days
.\scripts\rotate-logs.ps1 -DeleteArchivesAfterDays 180
```

#### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `LogPath` | Directory containing logs | `.\logs` |
| `RetentionDays` | Days to keep uncompressed logs | `30` |
| `CompressAfterDays` | Compress logs older than N days | `7` |
| `ArchivePath` | Directory for compressed archives | `.\logs\archive` |
| `DeleteArchivesAfterDays` | Delete archives older than N days | `90` |

#### Rotation Policy

1. **Day 1-7**: Logs kept uncompressed for quick access
2. **Day 8-30**: Logs compressed and moved to archive
3. **Day 31-90**: Compressed archives retained
4. **Day 90+**: Archives automatically deleted

### 3. Log Analysis (`scripts/analyze-logs.ps1`)

Analyzes logs to identify patterns, errors, and trends.

#### Usage

```powershell
# Console output
.\scripts\analyze-logs.ps1

# Generate JSON report
.\scripts\analyze-logs.ps1 -OutputFormat JSON

# Generate HTML report
.\scripts\analyze-logs.ps1 -DaysToAnalyze 30 -GenerateReport $true

# Analyze specific period
.\scripts\analyze-logs.ps1 -DaysToAnalyze 14 -OutputFormat HTML
```

#### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `LogPath` | Directory containing logs | `.\logs` |
| `OutputFormat` | Output format (Console, JSON, HTML) | `Console` |
| `DaysToAnalyze` | Days of logs to analyze | `7` |
| `GenerateReport` | Generate detailed HTML report | `$false` |

#### Analysis Features

- **Error Pattern Detection**: Identifies recurring errors
- **Job Statistics**: Success/failure rates
- **Performance Metrics**: CPU and memory trends
- **Recommendations**: Actionable insights based on patterns

## Windows Event Log Integration

The runner logs important events to Windows Event Log under:

- **Application Log**: Runner service events
- **System Log**: Service lifecycle events
- **Security Log**: Authentication and permission events (admin required)

### Viewing Events

```powershell
# View recent runner-related events
Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='actions.runner.*'} -MaxEvents 50

# Search for errors in last 7 days
Get-WinEvent -FilterHashtable @{
    LogName='Application'
    Level=2
    StartTime=(Get-Date).AddDays(-7)
} | Where-Object { $_.Message -match 'GitHub|Actions' }
```

## Automated Log Management

### Scheduled Tasks

Set up Windows Task Scheduler to run log management tasks automatically:

#### Daily Log Collection

```powershell
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument '-File C:\Code\ActionRunner\scripts\collect-logs.ps1'

$trigger = New-ScheduledTaskTrigger -Daily -At 2:00AM

Register-ScheduledTask -TaskName "Runner-LogCollection" `
    -Action $action -Trigger $trigger -User "SYSTEM"
```

#### Weekly Log Rotation

```powershell
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument '-File C:\Code\ActionRunner\scripts\rotate-logs.ps1'

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 3:00AM

Register-ScheduledTask -TaskName "Runner-LogRotation" `
    -Action $action -Trigger $trigger -User "SYSTEM"
```

#### Monthly Log Analysis

```powershell
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument '-File C:\Code\ActionRunner\scripts\analyze-logs.ps1 -GenerateReport $true'

$trigger = New-ScheduledTaskTrigger -Monthly -DaysOfMonth 1 -At 1:00AM

Register-ScheduledTask -TaskName "Runner-LogAnalysis" `
    -Action $action -Trigger $trigger -User "SYSTEM"
```

## Log Retention Policy

### Recommended Retention Periods

| Log Type | Uncompressed | Compressed | Rationale |
|----------|--------------|------------|-----------|
| Service Logs | 7 days | 90 days | Troubleshooting recent issues |
| Job Logs | 14 days | 60 days | Debugging workflow failures |
| Performance Logs | 7 days | 30 days | Capacity planning |
| Security Logs | 30 days | 365 days | Compliance and audit requirements |

### Compliance Considerations

For organizations with compliance requirements:

- **SOC 2**: Retain audit logs for 1 year minimum
- **ISO 27001**: Retain security logs for 6-12 months
- **GDPR**: Consider data retention limits (typically 90 days unless justified)
- **PCI DSS**: Retain audit logs for 1 year, with 3 months immediately available

Adjust retention periods in `rotate-logs.ps1` parameters accordingly.

## Troubleshooting

### Log Collection Issues

**Problem**: No logs collected
```powershell
# Check runner service status
Get-Service -Name "actions.runner.*"

# Verify runner directory
Test-Path "$env:USERPROFILE\actions-runner"
```

**Problem**: Permission denied errors
```powershell
# Run PowerShell as Administrator
# Or adjust execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Log Rotation Issues

**Problem**: Logs not compressing
```powershell
# Verify .NET compression is available
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Check available disk space
Get-PSDrive C
```

### Analysis Issues

**Problem**: No patterns detected
```powershell
# Verify log files exist
Get-ChildItem .\logs -Filter "*.log"

# Check date range
Get-ChildItem .\logs | Where-Object { $_.LastWriteTime -ge (Get-Date).AddDays(-7) }
```

## Best Practices

1. **Regular Collection**: Run log collection daily to ensure all events are captured
2. **Timely Rotation**: Compress logs weekly to save disk space
3. **Periodic Analysis**: Review analysis reports monthly to identify trends
4. **Monitor Disk Usage**: Set up alerts when log directory exceeds size threshold
5. **Secure Storage**: Ensure log files have appropriate access controls
6. **Backup Archives**: Consider backing up compressed archives to external storage
7. **Review Retention**: Regularly review and adjust retention policies based on needs

## Monitoring Dashboard

For real-time monitoring, consider setting up:

1. **Performance Counters**: Monitor CPU, memory, disk, and network
2. **Custom Alerts**: Set up alerts for critical errors or service failures
3. **Log Shipping**: Send logs to centralized logging system (Splunk, ELK, etc.)
4. **Metrics Export**: Export metrics to monitoring tools (Prometheus, Grafana)

### Example: Set Up Performance Monitoring

```powershell
# Create a performance monitor data collector
$counterSet = @(
    '\Processor(_Total)\% Processor Time',
    '\Memory\Available MBytes',
    '\PhysicalDisk(_Total)\% Disk Time'
)

# Sample every 15 seconds, run for 24 hours
$dataCollectorSet = New-Object -COM Pla.DataCollectorSet
$dataCollectorSet.DisplayName = "GitHub Actions Runner Monitoring"
# Configure as needed...
```

## Integration with External Systems

### Shipping Logs to SIEM

```powershell
# Example: Send logs to Splunk HTTP Event Collector
$splunkUrl = "https://splunk.example.com:8088/services/collector"
$token = "your-hec-token"

$logs = Get-Content .\logs\runner-logs-latest.json | ConvertFrom-Json
$body = $logs | ConvertTo-Json
Invoke-RestMethod -Uri $splunkUrl -Method Post -Headers @{Authorization="Splunk $token"} -Body $body
```

### Alerting on Critical Events

```powershell
# Example: Send alert email on high error rate
$analysis = Get-Content .\logs\analysis-report-latest.json | ConvertFrom-Json

if ($analysis.Summary.Errors -gt 100) {
    Send-MailMessage -To "admin@example.com" `
        -Subject "Runner Alert: High Error Rate" `
        -Body "Detected $($analysis.Summary.Errors) errors in the last analysis period." `
        -SmtpServer "smtp.example.com"
}
```

## Summary

The logging and audit trail system provides comprehensive visibility into runner operations. By following the practices outlined in this document and using the provided tools, you can:

- Maintain detailed audit trails for compliance
- Quickly diagnose and resolve issues
- Monitor performance and capacity
- Identify and address recurring problems
- Ensure secure and reliable CI/CD operations

For additional support, refer to the troubleshooting guide or review the GitHub Actions Runner documentation.
