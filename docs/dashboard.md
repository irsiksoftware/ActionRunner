# Runner Dashboard and Reporting

Web-based dashboard for monitoring GitHub Actions self-hosted runner status, performance metrics, and job history.

## Features

### Dashboard
- **Real-time Monitoring**: Live runner status and metrics
- **Performance Metrics**: Job statistics, success rates, and execution times
- **Resource Monitoring**: Disk space usage and system resources
- **Job History**: Recent job executions with status tracking
- **Visual Charts**: Jobs per day and disk space trends

### Reporting
- **Automated Reports**: Daily, weekly, or custom date range reports
- **Multiple Formats**: JSON data and HTML visualizations
- **Comprehensive Statistics**: Job success rates, resource utilization, cost analysis
- **Performance Tracking**: Average job duration, jobs per day metrics

## Quick Start

### Starting the Dashboard

1. **Open PowerShell as Administrator**

2. **Navigate to the dashboard directory:**
   ```powershell
   cd C:\Code\ActionRunner\dashboard
   ```

3. **Start the dashboard server:**
   ```powershell
   .\server.ps1
   ```

4. **Access the dashboard:**
   - Open your browser to: http://localhost:8080
   - Default port is 8080, can be changed with `-Port` parameter

### Custom Port

```powershell
.\server.ps1 -Port 3000
```

Then access at: http://localhost:3000

## Generating Reports

### Daily Report

Generate a report for the last 24 hours:

```powershell
.\scripts\generate-report.ps1 -ReportType Daily
```

### Weekly Report

Generate a report for the last 7 days:

```powershell
.\scripts\generate-report.ps1 -ReportType Weekly
```

### Custom Date Range

Generate a report for a specific date range:

```powershell
.\scripts\generate-report.ps1 -ReportType Custom -StartDate "2025-09-01" -EndDate "2025-10-01"
```

### Custom Output Directory

Specify where to save reports:

```powershell
.\scripts\generate-report.ps1 -ReportType Daily -OutputPath "C:\Reports"
```

## Dashboard Components

### Status Bar
- **Online/Offline Indicator**: Shows current runner status with animated dot
- **Refresh Button**: Manually refresh dashboard data

### Metrics Cards
1. **Total Jobs Today**: Number of jobs executed in the last 24 hours
2. **Success Rate**: Percentage of successful job completions
3. **Disk Space**: Available disk space on the runner machine
4. **Average Job Duration**: Mean execution time for jobs
5. **Queue Length**: Number of jobs waiting in the queue
6. **Uptime**: Runner system uptime

### Charts
1. **Jobs Per Day**: Bar chart showing job volume over the last 7 days
2. **Disk Space Over Time**: Trend chart for available disk space

### Recent Jobs
- Lists the 10 most recent job executions
- Shows job name, status (success/failure/running), and duration
- Real-time updates every 30 seconds

## Report Contents

### Runner Information
- Hostname
- Operating system and version
- Processor count
- Total memory
- Current status

### Job Statistics
- Total jobs executed
- Successful jobs count
- Failed jobs count
- Success rate percentage
- Jobs by day breakdown

### Resource Utilization
- Disk space used (GB)
- Disk space free (GB)
- Disk total capacity (GB)
- Disk usage percentage

### Performance Metrics
- Average job duration (seconds)
- Jobs per day
- Peak jobs in a single day

### Cost Analysis
- Estimated running hours
- Power consumption (kWh)
- Estimated electricity cost
- Time saved vs. manual execution

## API Endpoints

The dashboard server provides the following API endpoints:

### GET /api/dashboard-data

Returns real-time dashboard data in JSON format.

**Response Example:**
```json
{
  "status": "online",
  "timestamp": "2025-10-03T10:30:00Z",
  "metrics": {
    "totalJobsToday": 15,
    "successfulJobs": 14,
    "failedJobs": 1,
    "successRate": 93,
    "diskFreeGB": 180.5,
    "diskTotalGB": 250,
    "avgJobDuration": 245,
    "queueLength": 2,
    "uptimeHours": 48.5
  },
  "charts": {
    "jobsPerDay": [...],
    "diskPerDay": [...]
  },
  "recentJobs": [...]
}
```

## Automation and Scheduling

### Schedule Daily Reports

Create a scheduled task to generate daily reports:

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\Code\ActionRunner\scripts\generate-report.ps1 -ReportType Daily -OutputPath C:\Reports"
$trigger = New-ScheduledTaskTrigger -Daily -At 9am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "RunnerDailyReport" -Description "Generate daily runner report"
```

### Auto-start Dashboard on Boot

1. Create a shortcut to `server.ps1`
2. Place in: `C:\Users\<Username>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup`

Or use Task Scheduler:

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\Code\ActionRunner\dashboard\server.ps1"
$trigger = New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "RunnerDashboard" -Description "Start runner dashboard server"
```

## Network Access

### Access from Other Devices

To access the dashboard from other devices on your network:

1. **Update the server script** to listen on all interfaces:
   ```powershell
   # Edit dashboard\server.ps1
   # Change: $listener.Prefixes.Add("http://localhost:$Port/")
   # To: $listener.Prefixes.Add("http://+:$Port/")
   ```

2. **Run PowerShell as Administrator** (required for network binding)

3. **Configure Windows Firewall:**
   ```powershell
   New-NetFirewallRule -DisplayName "Runner Dashboard" -Direction Inbound -Protocol TCP -LocalPort 8080 -Action Allow
   ```

4. **Access from other devices:**
   - Find your IP address: `ipconfig`
   - Access at: `http://<your-ip>:8080`

## Troubleshooting

### Dashboard Not Loading
- Ensure PowerShell is running as Administrator
- Check if port 8080 is already in use
- Try a different port: `.\server.ps1 -Port 3000`

### No Job Data
- Verify runner logs exist in: `C:\actions-runner\_diag`
- Check log file permissions
- Ensure runner has executed jobs recently

### Reports Not Generating
- Verify output directory exists or script can create it
- Check disk space availability
- Run with `-Verbose` for detailed output

### Performance Issues
- Reduce auto-refresh interval in `dashboard.js`
- Limit number of days in charts
- Clear old log files

## Configuration

### Customize Auto-refresh Rate

Edit `dashboard/dashboard.js`:

```javascript
// Change refresh interval (default: 30000ms = 30 seconds)
refreshInterval = setInterval(loadDashboard, 60000); // 60 seconds
```

### Customize Report Output

Edit `scripts/generate-report.ps1` to modify:
- Report sections
- Metrics calculations
- HTML styling
- Cost analysis parameters

### Dashboard Styling

Edit `dashboard/index.html` to customize:
- Colors and themes
- Layout and grid
- Chart appearance
- Metric card design

## Security Considerations

### Production Use
- Use HTTPS for network access
- Implement authentication
- Restrict network access with firewall rules
- Use reverse proxy (IIS, nginx) for advanced features

### Data Privacy
- Reports may contain sensitive job information
- Secure report output directories
- Implement access controls for dashboard

## Testing

Run the dashboard tests:

```powershell
Invoke-Pester -Path .\tests\dashboard.Tests.ps1
```

## Best Practices

1. **Regular Reports**: Schedule daily or weekly reports for trend analysis
2. **Monitor Disk Space**: Set up alerts when disk usage exceeds threshold
3. **Review Success Rates**: Investigate when success rate drops below 90%
4. **Archive Old Reports**: Move old reports to archive storage
5. **Keep Dashboard Updated**: Refresh regularly for accurate real-time data

## Future Enhancements

- Email/Slack notifications for failures
- Multi-runner support
- Historical data persistence
- Advanced filtering and search
- Custom alert thresholds
- Integration with monitoring tools (Prometheus, Grafana)

## Support

For issues or questions:
- Check GitHub Issues: https://github.com/DakotaIrsik/ActionRunner/issues
- Review runner logs: `C:\actions-runner\_diag`
- Enable verbose logging for troubleshooting
