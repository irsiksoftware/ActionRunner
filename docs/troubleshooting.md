# Troubleshooting Guide

Comprehensive troubleshooting documentation for Dakota's self-hosted GitHub Actions runners.

## Quick Diagnosis

**Use this decision tree to quickly identify your issue:**

```
Runner Issue?
│
├─ Not showing up in GitHub?
│  └─ See: Runner Offline/Not Connecting
│
├─ Jobs stuck in queue?
│  └─ See: Jobs Stuck in Queue
│
├─ Jobs failing?
│  ├─ Permission errors? → See: Permission Errors
│  ├─ Network issues? → See: Network Connectivity Issues
│  ├─ Disk space? → See: Disk Space Exhaustion
│  └─ GPU not found? → See: GPU Not Detected
│
├─ Service won't start?
│  └─ See: Service Startup Failures
│
└─ System unresponsive?
   └─ See: Emergency Runbooks
```

## Common Issues

### Runner Offline/Not Connecting

**Symptoms:**
- Runner shows as offline in GitHub repository settings
- New jobs aren't being picked up
- "Waiting for a runner to pick up this job" message

**Diagnostic Commands:**
```powershell
# Check if runner service is running
Get-Service actions.runner.* | Select-Object Name, Status, StartType

# Check runner process
Get-Process *Runner.Listener* -ErrorAction SilentlyContinue

# Check recent logs
Get-Content C:\actions-runner\_diag\Runner_*.log -Tail 50

# Test GitHub connectivity
Test-NetConnection github.com -Port 443
```

**Solutions:**

1. **Service stopped - Restart it:**
   ```powershell
   Get-Service actions.runner.* | Start-Service

   # Verify it started
   Get-Service actions.runner.* | Select-Object Name, Status
   ```

2. **Service running but runner offline - Check logs:**
   ```powershell
   # Collect all logs
   .\scripts\collect-logs.ps1

   # Check collected logs in logs/collected/ directory
   # Look for connection errors, authentication failures, or crashes
   ```

3. **Token expired - Regenerate:**
   ```powershell
   # Stop service
   Stop-Service actions.runner.*

   # Remove and reconfigure runner
   cd C:\actions-runner
   .\config.cmd remove --token YOUR-REMOVAL-TOKEN
   .\config.cmd --url https://github.com/DakotaIrsik/YOUR-REPO --token YOUR-NEW-TOKEN --runasservice

   # Start service
   Start-Service actions.runner.*
   ```

4. **Firewall blocking - Verify rules:**
   ```powershell
   # Check firewall rules are active
   Get-NetFirewallRule -DisplayName "GitHub Actions Runner*" | Select-Object DisplayName, Enabled, Action

   # Re-apply firewall rules if needed
   .\config\apply-firewall-rules.ps1
   ```

5. **Check Windows Event Logs:**
   ```powershell
   Get-EventLog -LogName Application -Source "actions.runner.*" -Newest 20 | Format-Table -AutoSize
   ```

### Jobs Stuck in Queue

**Symptoms:**
- Jobs show "Queued" status indefinitely
- "Waiting for a runner to pick up this job" message
- Runner is online but not picking up jobs

**Diagnostic Commands:**
```powershell
# Check if runner is busy with another job
Get-Process *Runner.Worker* -ErrorAction SilentlyContinue

# Check runner labels
Get-Content C:\actions-runner\.runner | ConvertFrom-Json | Select-Object -ExpandProperty labels

# Check service account
Get-Service actions.runner.* | Select-Object Name, StartName
```

**Solutions:**

1. **Label mismatch - Verify workflow labels:**
   - Check your workflow file uses correct labels: `[self-hosted, windows, unity]`
   - Verify runner has the required labels in GitHub settings
   - Re-configure runner with correct labels if needed

2. **Runner busy - Wait or add capacity:**
   ```powershell
   # Check running jobs
   Get-Process *Runner.Worker* | Select-Object Id, CPU, WorkingSet

   # If stuck on long job, consider:
   # - Waiting for current job to complete
   # - Setting up additional runner
   # - Canceling stuck job in GitHub UI
   ```

3. **Runner service account issues:**
   ```powershell
   # Verify service account has correct permissions
   icacls C:\actions-runner

   # Re-create service account if needed
   .\config\runner-user-setup.ps1
   ```

### Disk Space Exhaustion

**Symptoms:**
- Jobs fail with "No space left on device" errors
- Build artifacts fail to save
- Runner becomes unresponsive

**Diagnostic Commands:**
```powershell
# Check disk space
Get-PSDrive C | Select-Object Used, Free, @{N='PercentFree';E={[math]::Round($_.Free/$_.Used*100,2)}}

# Find large directories
Get-ChildItem C:\actions-runner -Recurse -Directory |
    Where-Object { (Get-ChildItem $_.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum -gt 1GB } |
    Select-Object FullName, @{N='SizeGB';E={[math]::Round((Get-ChildItem $_.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum/1GB,2)}}

# Check Docker disk usage
docker system df
```

**Solutions:**

1. **Clean up old logs:**
   ```powershell
   .\scripts\rotate-logs.ps1 -Force
   ```

2. **Clean up Docker:**
   ```powershell
   .\scripts\cleanup-docker.ps1

   # For aggressive cleanup (removes all unused images)
   docker system prune -a --volumes -f
   ```

3. **Clean up runner work directory:**
   ```powershell
   # Stop service first
   Stop-Service actions.runner.*

   # Clean work directory (safe - runner will recreate)
   Remove-Item C:\actions-runner\_work\* -Recurse -Force

   # Restart service
   Start-Service actions.runner.*
   ```

4. **Clean up temp files:**
   ```powershell
   # Windows temp
   Remove-Item $env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue

   # Runner temp
   Remove-Item C:\actions-runner\_temp\* -Recurse -Force -ErrorAction SilentlyContinue
   ```

### GPU Not Detected

**Symptoms:**
- `nvidia-smi` fails or shows no devices
- CUDA workloads fail
- GPU-accelerated builds fall back to CPU

**Diagnostic Commands:**
```powershell
# Check NVIDIA driver
nvidia-smi

# Check CUDA installation
nvcc --version

# Check Docker GPU support
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi

# Check Windows GPU
Get-WmiObject -Class Win32_VideoController | Select-Object Name, DriverVersion
```

**Solutions:**

1. **Update NVIDIA drivers:**
   - Download latest drivers from [NVIDIA website](https://www.nvidia.com/download/index.aspx)
   - Install and reboot

2. **Reinstall CUDA toolkit:**
   ```powershell
   # Download from https://developer.nvidia.com/cuda-downloads
   # Install CUDA toolkit
   # Verify installation
   nvcc --version
   ```

3. **Fix Docker GPU support:**
   ```powershell
   # Reinstall Docker with GPU support
   .\scripts\setup-docker.ps1 -ConfigureGPU -Force
   ```

4. **Check GPU is not disabled:**
   ```powershell
   # Device Manager check
   Get-PnpDevice -Class Display | Select-Object Status, FriendlyName
   ```

### Network Connectivity Issues

**Symptoms:**
- "Failed to connect to github.com" errors
- Timeout errors during checkout or artifact upload
- DNS resolution failures

**Diagnostic Commands:**
```powershell
# Test GitHub connectivity
Test-NetConnection github.com -Port 443

# Test DNS resolution
Resolve-DnsName github.com

# Check active connections
Get-NetTCPConnection -RemoteAddress *github.com* -State Established

# Check firewall rules
Get-NetFirewallRule -DisplayName "GitHub Actions Runner*" | Get-NetFirewallPortFilter

# Test with curl
curl -v https://github.com
```

**Solutions:**

1. **DNS issues - Flush DNS and retry:**
   ```powershell
   ipconfig /flushdns
   Clear-DnsClientCache

   # Test again
   Resolve-DnsName github.com
   ```

2. **Firewall blocking - Check rules:**
   ```powershell
   # Verify outbound HTTPS allowed
   Get-NetFirewallRule -DisplayName "GitHub Actions Runner - Outbound HTTPS" |
       Get-NetFirewallApplicationFilter

   # Re-apply firewall rules
   .\config\apply-firewall-rules.ps1
   ```

3. **Proxy issues - Configure proxy:**
   ```powershell
   # Set proxy for runner (if needed)
   # Edit C:\actions-runner\.env
   # Add:
   # http_proxy=http://your-proxy:port
   # https_proxy=http://your-proxy:port

   # Restart service
   Restart-Service actions.runner.*
   ```

4. **GitHub IP ranges changed - Update firewall:**
   ```powershell
   # Edit config/firewall-rules.yaml with new IP ranges
   # Get current ranges: https://api.github.com/meta

   # Re-apply rules
   .\config\apply-firewall-rules.ps1
   ```

### Permission Errors

**Symptoms:**
- "Access denied" errors during builds
- Unable to write files
- Service won't start due to permissions

**Diagnostic Commands:**
```powershell
# Check service account
Get-Service actions.runner.* | Select-Object Name, StartName

# Check directory permissions
icacls C:\actions-runner

# Check current user context
whoami /all

# Check file system permissions on specific file
icacls "path\to\file"
```

**Solutions:**

1. **Runner directory permissions:**
   ```powershell
   # Grant GitHubRunner account full control
   icacls C:\actions-runner /grant "GitHubRunner:(OI)(CI)F" /T
   ```

2. **Work directory permissions:**
   ```powershell
   # Ensure service account can write to work directory
   $workDir = "C:\actions-runner\_work"
   icacls $workDir /grant "GitHubRunner:(OI)(CI)F" /T
   ```

3. **Re-create service account:**
   ```powershell
   # Stop and remove service
   Stop-Service actions.runner.*
   cd C:\actions-runner
   .\config.cmd remove --token YOUR-TOKEN

   # Re-create service account
   .\config\runner-user-setup.ps1

   # Re-configure runner
   .\config.cmd --url https://github.com/DakotaIrsik/YOUR-REPO --token YOUR-TOKEN --runasservice
   ```

4. **Specific tool permissions (e.g., Unity):**
   ```powershell
   # Grant service account access to Unity
   icacls "C:\Program Files\Unity" /grant "GitHubRunner:(OI)(CI)RX" /T
   ```

### Service Startup Failures

**Symptoms:**
- Service fails to start
- Service starts then immediately stops
- "Error 1067: The process terminated unexpectedly"

**Diagnostic Commands:**
```powershell
# Check service status
Get-Service actions.runner.* | Format-List *

# Check Windows Event Log
Get-EventLog -LogName Application -Source "actions.runner.*" -Newest 10 | Format-List *

# Try running manually (as test)
cd C:\actions-runner
.\run.cmd

# Check dependencies
Get-Service actions.runner.* | Select-Object -ExpandProperty DependentServices
```

**Solutions:**

1. **Configuration file corrupted:**
   ```powershell
   # Check .runner file exists and is valid JSON
   Get-Content C:\actions-runner\.runner | ConvertFrom-Json

   # If corrupted, reconfigure
   cd C:\actions-runner
   .\config.cmd remove --token YOUR-REMOVAL-TOKEN
   .\config.cmd --url https://github.com/DakotaIrsik/YOUR-REPO --token YOUR-TOKEN --runasservice
   ```

2. **Service account password expired:**
   ```powershell
   # Reset GitHubRunner account password
   $password = ConvertTo-SecureString "NEW-SECURE-PASSWORD" -AsPlainText -Force
   Set-LocalUser -Name "GitHubRunner" -Password $password

   # Update service credentials
   $cred = Get-Credential -UserName ".\GitHubRunner"
   $service = Get-Service actions.runner.*
   sc.exe config $service.Name obj= ".\GitHubRunner" password= "NEW-SECURE-PASSWORD"

   # Start service
   Start-Service $service
   ```

3. **Dependency missing:**
   ```powershell
   # Ensure .NET runtime installed
   dotnet --version

   # If missing, install .NET runtime
   # Download from: https://dotnet.microsoft.com/download
   ```

4. **Port conflict:**
   ```powershell
   # Check if another service is using runner's ports
   Get-NetTCPConnection -LocalPort 80,443 -State Listen

   # Stop conflicting service if found
   ```

## Emergency Runbooks

### RUNBOOK 1: Runner Completely Unresponsive

**Severity: Critical**

**Symptoms:**
- Runner service won't respond
- Can't stop or restart service
- System resource exhaustion

**Immediate Actions:**

1. **Force kill runner processes:**
   ```powershell
   # Kill all runner processes
   Get-Process *Runner* | Stop-Process -Force

   # Verify they're gone
   Get-Process *Runner* -ErrorAction SilentlyContinue
   ```

2. **Collect diagnostics before cleanup:**
   ```powershell
   # Quick log collection
   Copy-Item C:\actions-runner\_diag\* C:\temp\runner-crash-logs\ -Recurse -Force

   # Export Windows Event Log
   wevtutil epl Application C:\temp\runner-crash-logs\Application.evtx "/q:*[System[Provider[@Name='actions.runner.*']]]"
   ```

3. **Remove and reinstall service:**
   ```powershell
   # Stop service forcefully
   Stop-Service actions.runner.* -Force -NoWait
   Start-Sleep -Seconds 5

   # Remove service
   cd C:\actions-runner
   .\config.cmd remove --token YOUR-REMOVAL-TOKEN

   # Clean up work directory
   Remove-Item _work\* -Recurse -Force -ErrorAction SilentlyContinue

   # Reinstall
   .\config.cmd --url https://github.com/DakotaIrsik/YOUR-REPO --token YOUR-TOKEN --runasservice

   # Start service
   Start-Service actions.runner.*
   ```

4. **Verify recovery:**
   ```powershell
   # Check service
   Get-Service actions.runner.* | Format-List *

   # Check in GitHub UI that runner is online
   ```

### RUNBOOK 2: Critical Storage Failure

**Severity: Critical**

**Symptoms:**
- Disk full or failing
- Jobs failing with I/O errors
- System warnings about disk space

**Immediate Actions:**

1. **Free up space immediately:**
   ```powershell
   # Stop runner to prevent more writes
   Stop-Service actions.runner.*

   # Emergency cleanup
   Remove-Item C:\actions-runner\_work\* -Recurse -Force
   Remove-Item C:\actions-runner\_diag\*.log -Recurse -Force
   Remove-Item $env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue

   # Docker cleanup (if Docker installed)
   docker system prune -a --volumes -f

   # Check space freed
   Get-PSDrive C | Select-Object Used, Free
   ```

2. **Identify space hogs:**
   ```powershell
   # Find large files
   Get-ChildItem C:\actions-runner -Recurse -File |
       Where-Object Length -gt 100MB |
       Sort-Object Length -Descending |
       Select-Object FullName, @{N='SizeGB';E={[math]::Round($_.Length/1GB,2)}} -First 20
   ```

3. **Archive logs:**
   ```powershell
   # Archive and compress old logs
   .\scripts\rotate-logs.ps1 -Force -Compress
   ```

4. **Restart runner:**
   ```powershell
   Start-Service actions.runner.*

   # Monitor space usage
   while ($true) {
       Get-PSDrive C | Select-Object @{N='Time';E={Get-Date}}, Used, Free
       Start-Sleep 300  # Every 5 minutes
   }
   ```

### RUNBOOK 3: Job Causing System Crash

**Severity: High**

**Symptoms:**
- System becomes unresponsive during specific job
- Excessive memory/CPU usage
- System requires hard reboot

**Immediate Actions:**

1. **Identify problematic job:**
   ```powershell
   # Check recent logs for job that was running
   .\scripts\collect-logs.ps1

   # Look in logs/collected/ for the job name/ID
   Get-ChildItem logs\collected\*.log | Get-Content | Select-String "Running job"
   ```

2. **Kill running job:**
   ```powershell
   # Find worker process
   Get-Process *Runner.Worker* | Select-Object Id, CPU, WorkingSet, StartTime

   # Kill it
   Get-Process *Runner.Worker* | Stop-Process -Force
   ```

3. **Cancel job in GitHub:**
   - Go to GitHub Actions UI
   - Find the running workflow
   - Click "Cancel workflow"

4. **Prevent job from running again:**
   - Add resource limits to workflow:
   ```yaml
   jobs:
     problematic-job:
       runs-on: [self-hosted, windows, docker]  # Use Docker isolation
       steps:
         - name: Run in container with limits
           run: |
             .\scripts\run-in-docker.ps1 `
               -Image "actionrunner/python:latest" `
               -Command "your-command" `
               -MaxCPUs 4 `
               -MaxMemoryGB 8 `
               -ResourceLimits
   ```

5. **Monitor system:**
   ```powershell
   # Watch resource usage
   while ($true) {
       Get-Process *Runner* | Select-Object Name, CPU, WorkingSet
       Get-PSDrive C | Select-Object Used, Free
       Start-Sleep 10
   }
   ```

### RUNBOOK 4: Security Incident Response

**Severity: Critical**

**Symptoms:**
- Suspicious activity detected
- Unauthorized access attempts
- Malicious code execution suspected

**Immediate Actions:**

1. **ISOLATE - Stop runner immediately:**
   ```powershell
   # Stop service
   Stop-Service actions.runner.* -Force

   # Kill all runner processes
   Get-Process *Runner* | Stop-Process -Force

   # Disable network (if needed)
   Disable-NetAdapter -Name "Ethernet" -Confirm:$false
   ```

2. **PRESERVE - Collect evidence:**
   ```powershell
   # Create incident folder
   $incident = "C:\incident-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
   New-Item -Path $incident -ItemType Directory

   # Collect all logs
   Copy-Item C:\actions-runner\_diag\* $incident\logs\ -Recurse
   .\scripts\collect-logs.ps1
   Copy-Item logs\collected\* $incident\logs\ -Recurse

   # Export event logs
   wevtutil epl Application "$incident\Application.evtx"
   wevtutil epl Security "$incident\Security.evtx"

   # Capture running processes
   Get-Process | Export-Csv "$incident\processes.csv"

   # Capture network connections
   Get-NetTCPConnection | Export-Csv "$incident\network-connections.csv"

   # Capture file system changes (if audit enabled)
   Get-WinEvent -FilterHashtable @{LogName='Security';Id=4663} -MaxEvents 1000 |
       Export-Csv "$incident\file-access.csv"
   ```

3. **ANALYZE - Review logs:**
   ```powershell
   # Analyze logs for suspicious activity
   .\scripts\analyze-logs.ps1

   # Check for suspicious patterns
   Get-Content $incident\logs\*.log | Select-String -Pattern "Failed|Error|Unauthorized|Denied"
   ```

4. **CONTAIN - Revoke access:**
   - Revoke runner token in GitHub immediately
   - Rotate all secrets used by runner
   - Remove runner from repository:
   ```powershell
   cd C:\actions-runner
   .\config.cmd remove --token YOUR-REMOVAL-TOKEN
   ```

5. **RECOVER - Clean and rebuild:**
   ```powershell
   # Full system scan
   # Manual malware scan recommended

   # Rebuild runner from scratch
   # 1. Backup evidence to external drive
   # 2. Format runner directory
   # 3. Follow fresh installation steps
   # 4. Apply all security configurations
   # 5. Generate new tokens
   # 6. Re-configure runner
   ```

6. **Document incident:**
   - Create incident report with timeline
   - Document what was accessed
   - List all secrets that need rotation
   - Update security procedures based on findings

## Diagnostic Commands Reference

### Runner Status
```powershell
# Service status
Get-Service actions.runner.* | Select-Object Name, Status, StartType

# Process status
Get-Process *Runner* | Select-Object Name, Id, CPU, WorkingSet

# Runner configuration
Get-Content C:\actions-runner\.runner | ConvertFrom-Json

# Check runner version
C:\actions-runner\bin\Runner.Listener.exe --version
```

### Logs
```powershell
# Collect all logs
.\scripts\collect-logs.ps1

# View recent runner logs
Get-Content C:\actions-runner\_diag\Runner_*.log -Tail 100

# View worker logs
Get-Content C:\actions-runner\_diag\Worker_*.log -Tail 100

# Analyze logs for issues
.\scripts\analyze-logs.ps1

# Windows Event Log
Get-EventLog -LogName Application -Source "actions.runner.*" -Newest 50
```

### System Resources
```powershell
# Disk space
Get-PSDrive C | Select-Object Used, Free, @{N='PercentFree';E={[math]::Round($_.Free/($_.Used+$_.Free)*100,2)}}

# Memory usage
Get-Process *Runner* | Measure-Object WorkingSet -Sum |
    Select-Object @{N='TotalMemoryMB';E={[math]::Round($_.Sum/1MB,2)}}

# CPU usage
Get-Process *Runner* | Select-Object Name, CPU, @{N='CPUPercent';E={(Get-Counter "\Process($_. Name)\% Processor Time").CounterSamples.CookedValue}}

# Network usage
Get-NetTCPConnection -OwningProcess (Get-Process *Runner.Listener*).Id
```

### Docker
```powershell
# Docker status
docker info

# Container list
docker ps -a

# Image list
docker images

# Disk usage
docker system df

# Clean up
.\scripts\cleanup-docker.ps1
```

### Network
```powershell
# Test GitHub connectivity
Test-NetConnection github.com -Port 443

# DNS resolution
Resolve-DnsName github.com

# Active connections
Get-NetTCPConnection -State Established | Where-Object {$_.RemoteAddress -like "*github*"}

# Firewall rules
Get-NetFirewallRule -DisplayName "GitHub Actions Runner*"
```

## Log Locations

| Log Type | Location | Description |
|----------|----------|-------------|
| Runner Logs | `C:\actions-runner\_diag\Runner_*.log` | Main runner service logs |
| Worker Logs | `C:\actions-runner\_diag\Worker_*.log` | Individual job execution logs |
| Collected Logs | `logs\collected\` | Aggregated logs from collect-logs.ps1 |
| Archived Logs | `logs\archive\` | Rotated and compressed old logs |
| Windows Event Log | Application Log (Source: actions.runner.*) | Windows service events |
| Security Audit | `logs\audit\` | Security-related events |
| Docker Logs | `docker logs <container-id>` | Container execution logs |

## Common Error Messages

### "The runner process exited with code null"
**Cause:** Runner crashed or was forcefully terminated
**Solution:** Check Windows Event Log for crash details, restart service

### "Unable to connect to GitHub"
**Cause:** Network connectivity issue or token expired
**Solution:** Check network, verify firewall rules, regenerate token if needed

### "Access to the path is denied"
**Cause:** Service account lacks permissions
**Solution:** Check directory permissions with icacls, grant GitHubRunner account access

### "No space left on device"
**Cause:** Disk full
**Solution:** Clean up work directory, rotate logs, clean Docker

### "Job timeout"
**Cause:** Job exceeded timeout limit
**Solution:** Increase timeout in workflow or optimize job

### "GPU not found" / "CUDA not available"
**Cause:** NVIDIA drivers not installed or Docker GPU support missing
**Solution:** Install/update NVIDIA drivers, reconfigure Docker with GPU support

## Prevention and Maintenance

### Daily
- Monitor runner status in GitHub UI
- Check that jobs are completing successfully

### Weekly
```powershell
# Review logs for issues
.\scripts\analyze-logs.ps1

# Check service health
Get-Service actions.runner.* | Format-List *

# Check disk space
Get-PSDrive C | Select-Object Used, Free
```

### Monthly
```powershell
# Rotate logs
.\scripts\rotate-logs.ps1

# Clean up Docker
.\scripts\cleanup-docker.ps1

# Update runner tokens
# Regenerate in GitHub settings and reconfigure

# Review security logs
Get-EventLog -LogName Security -Newest 1000 |
    Where-Object {$_.Source -like "*runner*"}
```

### Quarterly
- Full system security audit
- Update NVIDIA drivers (for GPU runners)
- Review and update firewall rules
- Test incident response procedures
- Update runner to latest version

## Getting Help

1. **Check logs first:**
   ```powershell
   .\scripts\collect-logs.ps1
   # Review logs/collected/ directory
   ```

2. **Run diagnostics:**
   ```powershell
   .\scripts\analyze-logs.ps1
   ```

3. **Consult documentation:**
   - [Security Guide](security.md)
   - [Docker Isolation](docker-isolation.md)
   - [Logging System](logging.md)

4. **GitHub Actions Documentation:**
   - [Self-hosted runner troubleshooting](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/monitoring-and-troubleshooting-self-hosted-runners)
   - [Runner application](https://github.com/actions/runner)

---

**Last Updated:** 2025-10-03 | Dakota Irsik's Internal Infrastructure
