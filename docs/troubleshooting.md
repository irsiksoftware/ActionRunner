# Troubleshooting Guide

Comprehensive troubleshooting guide for GitHub Actions self-hosted runner issues. This guide provides diagnostic steps, common solutions, and emergency procedures.

## Table of Contents

- [Quick Diagnostic Commands](#quick-diagnostic-commands)
- [Common Issues](#common-issues)
  - [Runner Offline/Not Connecting](#runner-offlinenot-connecting)
  - [Jobs Stuck in Queue](#jobs-stuck-in-queue)
  - [Disk Space Exhaustion](#disk-space-exhaustion)
  - [GPU Not Detected](#gpu-not-detected)
  - [Network Connectivity Issues](#network-connectivity-issues)
  - [Permission Errors](#permission-errors)
  - [Service Startup Failures](#service-startup-failures)
- [Emergency Runbooks](#emergency-runbooks)
- [Error Message Reference](#error-message-reference)
- [Diagnostic Decision Tree](#diagnostic-decision-tree)

## Quick Diagnostic Commands

Run these commands to gather initial diagnostic information:

```powershell
# Check runner service status
Get-Service -Name "actions.runner.*" | Format-Table Name, Status, StartType

# Check disk space
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | Select-Object Name, @{N="Free(GB)";E={[math]::Round($_.Free/1GB,2)}}, @{N="Used(GB)";E={[math]::Round($_.Used/1GB,2)}}

# Check memory usage
Get-CimInstance Win32_OperatingSystem | Select-Object @{N="FreeMemory(GB)";E={[math]::Round($_.FreePhysicalMemory/1MB,2)}}, @{N="TotalMemory(GB)";E={[math]::Round($_.TotalVisibleMemorySize/1MB,2)}}

# Check Docker status (if using Docker isolation)
docker info
docker ps -a

# Check recent runner logs (replace with actual service name)
Get-EventLog -LogName Application -Source "actions.runner.*" -Newest 20 | Format-Table TimeGenerated, EntryType, Message -AutoSize

# Check firewall rules
Get-NetFirewallRule -DisplayName "*GitHub*" | Format-Table DisplayName, Enabled, Direction, Action

# Test GitHub connectivity
Test-NetConnection -ComputerName github.com -Port 443
Test-NetConnection -ComputerName api.github.com -Port 443
```

## Common Issues

### Runner Offline/Not Connecting

**Symptoms:**
- Runner shows as "Offline" in GitHub repository settings
- Jobs remain queued indefinitely
- No runner logs being generated

**Diagnostic Steps:**

1. **Check runner service status:**
   ```powershell
   Get-Service -Name "actions.runner.*"
   ```

2. **Check runner process:**
   ```powershell
   Get-Process | Where-Object { $_.ProcessName -like "*Runner*" }
   ```

3. **Review runner logs:**
   ```powershell
   # Logs typically located in runner installation directory
   Get-Content "C:\actions-runner\_diag\*.log" -Tail 50
   ```

**Solutions:**

**A. Service Not Running:**
```powershell
# Start the runner service
Start-Service -Name "actions.runner.DakotaIrsik-ActionRunner.*"

# Or restart it
Restart-Service -Name "actions.runner.DakotaIrsik-ActionRunner.*"

# Enable automatic startup
Set-Service -Name "actions.runner.DakotaIrsik-ActionRunner.*" -StartupType Automatic
```

**B. Network/Firewall Issues:**
```powershell
# Test GitHub connectivity
Test-NetConnection -ComputerName github.com -Port 443

# Check if proxy is interfering
$env:https_proxy
$env:http_proxy

# Temporarily disable firewall to test (re-enable after testing!)
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
# Re-enable: Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
```

**C. Authentication Token Expired:**
```powershell
# Re-configure runner with fresh token
cd C:\actions-runner
.\config.cmd remove --token <REMOVAL-TOKEN>
.\config.cmd --url https://github.com/DakotaIrsik/ActionRunner --token <NEW-TOKEN>
.\run.cmd install
.\run.cmd start
```

**D. Runner Registration Issues:**
- Generate new runner token from GitHub: Settings → Actions → Runners → New self-hosted runner
- Remove old runner registration and re-register
- Verify runner labels match workflow requirements

---

### Jobs Stuck in Queue

**Symptoms:**
- Workflows show "Queued" status for extended period
- "Waiting for a runner" message displayed
- No jobs executing despite runner being online

**Diagnostic Steps:**

1. **Verify runner is online:**
   - Check repository Settings → Actions → Runners
   - Should show green "Active" status

2. **Check runner labels:**
   ```powershell
   # View runner configuration
   Get-Content "C:\actions-runner\.runner" | ConvertFrom-Json
   ```

3. **Check concurrent job limits:**
   ```powershell
   # See if runner is at capacity
   docker ps -q | Measure-Object  # If using Docker isolation
   Get-Process | Where-Object { $_.ProcessName -like "*Runner.Worker*" } | Measure-Object
   ```

**Solutions:**

**A. Label Mismatch:**
```yaml
# In workflow file, ensure labels match runner labels
jobs:
  build:
    runs-on: [self-hosted, windows]  # Must match runner labels exactly
```

**B. Runner At Capacity:**
- Default runners handle 1 job at a time
- Wait for current job to complete, or
- Add additional runner instances:
  ```powershell
  # Install second runner in different directory
  cd C:\actions-runner-2
  .\config.cmd --url https://github.com/DakotaIrsik/ActionRunner --token <TOKEN> --name runner-2
  ```

**C. Repository Runner Access:**
- For organization runners, verify repository has access
- Check organization settings → Actions → Runner groups

**D. Workflow File Errors:**
```powershell
# Validate workflow syntax
gh workflow view <workflow-name>

# Check workflow runs for errors
gh run list --workflow=<workflow-name>
```

---

### Disk Space Exhaustion

**Symptoms:**
- Jobs failing with "No space left on device" errors
- Runner health checks failing
- Docker operations failing with space errors

**Diagnostic Steps:**

1. **Check disk space:**
   ```powershell
   Get-PSDrive C | Select-Object Used, Free, @{N="PercentFree";E={[math]::Round($_.Free/($_.Used+$_.Free)*100,2)}}
   ```

2. **Identify space consumers:**
   ```powershell
   # Check workspace directory
   Get-ChildItem C:\actions-runner\_work -Recurse |
     Measure-Object -Property Length -Sum |
     Select-Object @{N="Size(GB)";E={[math]::Round($_.Sum/1GB,2)}}

   # Check Docker storage
   docker system df

   # Check logs directory
   Get-ChildItem .\logs -Recurse |
     Measure-Object -Property Length -Sum
   ```

**Solutions:**

**A. Clean Workspace:**
```powershell
# Run workspace cleanup script
.\scripts\cleanup-workspace.ps1 -DaysOld 7 -MinFreeSpaceGB 100

# Or manually clean old workspaces
Get-ChildItem C:\actions-runner\_work -Directory |
  Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
  Remove-Item -Recurse -Force
```

**B. Clean Docker Resources:**
```powershell
# Remove stopped containers
docker container prune -f

# Remove unused images
docker image prune -a -f

# Remove build cache
docker builder prune -a -f

# Complete cleanup (caution: removes all unused data)
docker system prune -a --volumes -f
```

**C. Rotate Logs:**
```powershell
# Run log rotation script
.\scripts\rotate-logs.ps1 -RetentionDays 30

# Or manually compress old logs
Get-ChildItem .\logs -Filter *.log |
  Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } |
  Compress-Archive -DestinationPath .\logs\archive\logs-$(Get-Date -Format 'yyyy-MM-dd').zip

# Delete very old logs
Get-ChildItem .\logs -Filter *.log |
  Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-90) } |
  Remove-Item -Force
```

**D. Temporary Files:**
```powershell
# Clean Windows temp directory
Remove-Item C:\Windows\Temp\* -Recurse -Force -ErrorAction SilentlyContinue

# Clean user temp directory
Remove-Item $env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue
```

---

### GPU Not Detected

**Symptoms:**
- CUDA jobs failing with "No GPU found" errors
- `nvidia-smi` not working in containers
- AI/ML workflows failing

**Diagnostic Steps:**

1. **Check GPU on host:**
   ```powershell
   nvidia-smi
   ```

2. **Check Docker GPU support:**
   ```powershell
   docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
   ```

3. **Verify NVIDIA Container Toolkit:**
   ```powershell
   docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
   ```

**Solutions:**

**A. Install/Update NVIDIA Drivers:**
```powershell
# Download latest drivers from NVIDIA website
# Or use Windows Update for driver updates

# Verify installation
nvidia-smi

# Check driver version
Get-WmiObject Win32_VideoController | Where-Object { $_.Name -like "*NVIDIA*" } | Select-Object Name, DriverVersion
```

**B. Install NVIDIA Container Toolkit:**
```powershell
# For Docker Desktop on Windows with WSL2:
# 1. Install NVIDIA drivers in Windows
# 2. Install NVIDIA drivers in WSL2 Ubuntu:
wsl -d Ubuntu
sudo apt-get update
sudo apt-get install -y nvidia-cuda-toolkit

# Verify in WSL2
nvidia-smi
```

**C. Configure Docker for GPU:**
```powershell
# Ensure Docker Desktop is using WSL2 backend
# Settings → General → Use WSL2 based engine (enabled)

# Test GPU access
docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
```

**D. Workflow Configuration:**
```yaml
# Ensure workflow uses GPU-enabled runner and container
jobs:
  ai-job:
    runs-on: [self-hosted, windows, gpu]
    container:
      image: nvidia/cuda:11.8.0-runtime-ubuntu22.04
      options: --gpus all
```

---

### Network Connectivity Issues

**Symptoms:**
- Git clone operations timing out
- Docker pull failures
- Artifact upload/download failures
- Intermittent job failures with network errors

**Diagnostic Steps:**

1. **Test basic connectivity:**
   ```powershell
   Test-NetConnection -ComputerName github.com -Port 443
   Test-NetConnection -ComputerName api.github.com -Port 443
   Test-NetConnection -ComputerName docker.io -Port 443
   ```

2. **Check DNS resolution:**
   ```powershell
   Resolve-DnsName github.com
   Resolve-DnsName api.github.com
   ```

3. **Check proxy settings:**
   ```powershell
   [System.Net.WebRequest]::DefaultWebProxy
   $env:HTTP_PROXY
   $env:HTTPS_PROXY
   ```

**Solutions:**

**A. Firewall Configuration:**
```powershell
# Apply firewall rules
.\scripts\apply-firewall-rules.ps1

# Or manually allow GitHub domains
New-NetFirewallRule -DisplayName "GitHub HTTPS" -Direction Outbound -Protocol TCP -RemotePort 443 -Action Allow
New-NetFirewallRule -DisplayName "GitHub SSH" -Direction Outbound -Protocol TCP -RemotePort 22 -Action Allow
```

**B. DNS Issues:**
```powershell
# Flush DNS cache
Clear-DnsClientCache

# Use Google DNS
Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses 8.8.8.8,8.8.4.4

# Test again
Resolve-DnsName github.com
```

**C. Proxy Configuration:**
```powershell
# If behind corporate proxy, configure runner:
# Edit .env file in runner directory
# Add:
# HTTP_PROXY=http://proxy.company.com:8080
# HTTPS_PROXY=http://proxy.company.com:8080
# NO_PROXY=localhost,127.0.0.1

# For Git proxy:
git config --global http.proxy http://proxy.company.com:8080
git config --global https.proxy http://proxy.company.com:8080
```

**D. Rate Limiting:**
```powershell
# If hitting GitHub API rate limits:
# Use authenticated requests (runner should do this automatically)
# Check rate limit status:
gh api rate_limit

# For Docker Hub rate limits:
# Login to Docker Hub
docker login
```

---

### Permission Errors

**Symptoms:**
- "Access denied" errors during file operations
- "Permission denied" when running scripts
- Service startup failures due to insufficient privileges

**Diagnostic Steps:**

1. **Check runner user account:**
   ```powershell
   whoami
   ```

2. **Check file permissions:**
   ```powershell
   Get-Acl C:\actions-runner | Format-List
   ```

3. **Check service account:**
   ```powershell
   Get-CimInstance Win32_Service | Where-Object { $_.Name -like "*actions.runner*" } | Select-Object Name, StartName
   ```

**Solutions:**

**A. Run as Administrator:**
```powershell
# For interactive troubleshooting, start PowerShell as admin

# For service, configure to run as admin user:
sc.exe config "actions.runner.DakotaIrsik-ActionRunner.*" obj= ".\Administrator" password= "PASSWORD"
```

**B. Grant Necessary Permissions:**
```powershell
# Grant runner user full control over runner directory
$acl = Get-Acl C:\actions-runner
$permission = "BUILTIN\Administrators","FullControl","ContainerInherit,ObjectInherit","None","Allow"
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
$acl.SetAccessRule($rule)
Set-Acl C:\actions-runner $acl

# Grant permissions to workspace directory
icacls "C:\actions-runner\_work" /grant "Users:(OI)(CI)F" /T
```

**C. PowerShell Execution Policy:**
```powershell
# Check current policy
Get-ExecutionPolicy

# Set to allow script execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine

# Or for current user only
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**D. Docker Permissions:**
```powershell
# Add runner user to docker-users group
Add-LocalGroupMember -Group "docker-users" -Member "runner-user"

# Restart Docker Desktop or service
Restart-Service docker
```

---

### Service Startup Failures

**Symptoms:**
- Runner service fails to start
- Service starts then immediately stops
- Error in Windows Event Log

**Diagnostic Steps:**

1. **Check Windows Event Log:**
   ```powershell
   Get-EventLog -LogName Application -Source "actions.runner.*" -Newest 10 | Format-List
   ```

2. **Check service status and error code:**
   ```powershell
   Get-Service -Name "actions.runner.*" | Select-Object Name, Status, StartType
   sc.exe query "actions.runner.DakotaIrsik-ActionRunner.*"
   ```

3. **Try running interactively:**
   ```powershell
   cd C:\actions-runner
   .\run.cmd
   ```

**Solutions:**

**A. Configuration Issues:**
```powershell
# Reconfigure runner
cd C:\actions-runner
.\config.cmd remove --token <REMOVAL-TOKEN>
.\config.cmd --url https://github.com/DakotaIrsik/ActionRunner --token <TOKEN>

# Reinstall service
.\svc.sh install
.\svc.sh start
```

**B. Dependency Issues:**
```powershell
# Check if .NET runtime is installed
dotnet --version

# Install .NET if missing (download from Microsoft)

# Check dependencies
Get-ChildItem C:\actions-runner\bin -Filter *.dll
```

**C. Corrupted Installation:**
```powershell
# Backup runner configuration
Copy-Item C:\actions-runner\.runner -Destination C:\backup\

# Remove and reinstall
cd C:\actions-runner
.\config.cmd remove --token <REMOVAL-TOKEN>
Remove-Item C:\actions-runner\* -Recurse -Force

# Download fresh runner
Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/latest/download/actions-runner-win-x64-*.zip" -OutFile runner.zip
Expand-Archive runner.zip -DestinationPath C:\actions-runner

# Reconfigure
.\config.cmd --url https://github.com/DakotaIrsik/ActionRunner --token <TOKEN>
.\run.cmd install
.\run.cmd start
```

**D. Port Conflicts:**
```powershell
# Check if required ports are in use
Get-NetTCPConnection | Where-Object { $_.LocalPort -eq 443 }

# Kill conflicting processes if necessary
Stop-Process -Id <PID> -Force
```

---

## Emergency Runbooks

### Runbook 1: Runner Completely Unresponsive

**Severity:** Critical
**Estimated Recovery Time:** 15-30 minutes

**Steps:**

1. **Immediate Assessment (2 minutes)**
   ```powershell
   # Check system responsiveness
   Get-Process | Sort-Object CPU -Descending | Select-Object -First 10
   Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10
   ```

2. **Kill Hung Processes (3 minutes)**
   ```powershell
   # Kill runner processes
   Get-Process | Where-Object { $_.ProcessName -like "*Runner*" } | Stop-Process -Force

   # Kill hung Docker containers
   docker ps -q | ForEach-Object { docker kill $_ }
   ```

3. **Stop Runner Service (2 minutes)**
   ```powershell
   Stop-Service -Name "actions.runner.*" -Force
   ```

4. **Clean Temporary State (5 minutes)**
   ```powershell
   # Remove temporary work directories
   Get-ChildItem C:\actions-runner\_work -Directory |
     Where-Object { $_.Name -ne "_actions" -and $_.Name -ne "_temp" } |
     Remove-Item -Recurse -Force -ErrorAction Continue

   # Clean Docker
   docker system prune -a -f
   ```

5. **Restart System (5 minutes)**
   ```powershell
   Restart-Computer -Force
   ```

6. **Verify Recovery (8 minutes)**
   ```powershell
   # After reboot, check service status
   Get-Service -Name "actions.runner.*"

   # Check runner shows as online in GitHub
   # Trigger a test workflow
   gh workflow run test-workflow.yml
   ```

7. **Post-Incident Review**
   - Review logs: `Get-Content C:\actions-runner\_diag\*.log`
   - Check which job caused the hang
   - Add resource limits if needed
   - Document in incident log

---

### Runbook 2: Critical Storage Failure

**Severity:** Critical
**Estimated Recovery Time:** 10-20 minutes

**Steps:**

1. **Immediate Triage (2 minutes)**
   ```powershell
   # Check disk space
   Get-PSDrive C | Select-Object @{N="Free(GB)";E={[math]::Round($_.Free/1GB,2)}}

   # Check if drive is failing
   Get-PhysicalDisk | Get-StorageReliabilityCounter
   ```

2. **Emergency Cleanup (5 minutes)**
   ```powershell
   # Stop runner to prevent new jobs
   Stop-Service -Name "actions.runner.*"

   # Emergency space recovery
   docker system prune -a --volumes -f

   # Delete old workspaces
   Get-ChildItem C:\actions-runner\_work -Directory |
     Where-Object { $_.LastWriteTime -lt (Get-Date).AddHours(-1) } |
     Remove-Item -Recurse -Force

   # Clear temp files
   Remove-Item C:\Windows\Temp\* -Recurse -Force -ErrorAction SilentlyContinue
   Remove-Item $env:TEMP\* -Recurse -Force -ErrorAction SilentlyContinue
   ```

3. **Verify Space Recovered (2 minutes)**
   ```powershell
   Get-PSDrive C | Select-Object @{N="Free(GB)";E={[math]::Round($_.Free/1GB,2)}}
   ```

4. **If Space Still Critical:**
   ```powershell
   # Move logs to external storage
   Move-Item C:\actions-runner\_diag\*.log D:\backup\logs\

   # Archive old builds
   Compress-Archive -Path C:\actions-runner\_work\* -DestinationPath D:\backup\workspaces.zip
   Remove-Item C:\actions-runner\_work\* -Recurse -Force
   ```

5. **Restart Runner (2 minutes)**
   ```powershell
   Start-Service -Name "actions.runner.*"
   Get-Service -Name "actions.runner.*"
   ```

6. **Monitor (ongoing)**
   ```powershell
   # Set up alert for low disk space
   $threshold = 100GB
   while ($true) {
     $free = (Get-PSDrive C).Free
     if ($free -lt $threshold) {
       Write-Warning "Disk space below threshold: $([math]::Round($free/1GB,2)) GB"
     }
     Start-Sleep -Seconds 300  # Check every 5 minutes
   }
   ```

---

### Runbook 3: Job Causing System Crash

**Severity:** High
**Estimated Recovery Time:** 20-30 minutes

**Steps:**

1. **Identify Problem Job (5 minutes)**
   ```powershell
   # Check recent workflow runs
   gh run list --limit 10

   # Get details of failed/running jobs
   gh run view <run-id>

   # Check which repository/workflow
   Get-Content C:\actions-runner\_diag\Worker_*.log | Select-String -Pattern "Running job"
   ```

2. **Stop Job Immediately (2 minutes)**
   ```powershell
   # Cancel the workflow run
   gh run cancel <run-id>

   # Kill any remaining processes
   Get-Process | Where-Object { $_.ProcessName -like "*Runner.Worker*" } | Stop-Process -Force
   ```

3. **Prevent Job from Re-running (3 minutes)**
   ```yaml
   # Disable the problematic workflow
   # In GitHub: Repository → Actions → Select workflow → Disable

   # Or edit workflow file to add condition:
   if: false  # Temporarily disable
   ```

4. **Clean Up Resources (5 minutes)**
   ```powershell
   # Kill related containers
   docker ps -a --filter "label=job=<job-id>" -q | ForEach-Object { docker rm -f $_ }

   # Clear workspace
   Remove-Item "C:\actions-runner\_work\<repo>\<workflow>\*" -Recurse -Force
   ```

5. **Add Resource Limits (10 minutes)**
   ```yaml
   # Update workflow to use resource constraints
   jobs:
     problematic-job:
       runs-on: [self-hosted, windows]
       timeout-minutes: 30  # Add timeout
       container:
         image: <image>
         options: --cpus 2 --memory 4g  # Add resource limits
   ```

6. **Test with Constraints (5 minutes)**
   ```powershell
   # Re-enable and test workflow
   gh workflow enable <workflow-name>
   gh workflow run <workflow-name>

   # Monitor resource usage
   while ($true) {
     Get-Process | Sort-Object CPU -Descending | Select-Object -First 5
     Start-Sleep -Seconds 5
   }
   ```

7. **Document and Prevent Recurrence**
   - Add to workflow documentation: maximum resource usage expectations
   - Set up monitoring alerts for resource spikes
   - Consider adding pre-job resource checks

---

### Runbook 4: Security Incident Response

**Severity:** Critical
**Estimated Recovery Time:** 30-60 minutes

**Steps:**

1. **Immediate Containment (5 minutes)**
   ```powershell
   # Stop runner service immediately
   Stop-Service -Name "actions.runner.*" -Force

   # Cancel all running workflows
   gh run list --status in_progress --json databaseId --jq '.[].databaseId' |
     ForEach-Object { gh run cancel $_ }

   # Block network access (if necessary)
   Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultOutboundAction Block
   ```

2. **Collect Evidence (10 minutes)**
   ```powershell
   # Create evidence directory
   $evidenceDir = "C:\security-incident-$(Get-Date -Format 'yyyy-MM-dd-HHmmss')"
   New-Item -ItemType Directory -Path $evidenceDir

   # Copy logs
   Copy-Item C:\actions-runner\_diag\*.log -Destination $evidenceDir\
   Copy-Item C:\actions-runner\_work\ -Destination $evidenceDir\workspace -Recurse

   # Export running processes
   Get-Process | Export-Csv "$evidenceDir\processes.csv"

   # Export network connections
   Get-NetTCPConnection | Export-Csv "$evidenceDir\network-connections.csv"

   # Export recent Event Log entries
   Get-EventLog -LogName Security -Newest 1000 | Export-Csv "$evidenceDir\security-events.csv"
   Get-EventLog -LogName Application -Newest 1000 | Export-Csv "$evidenceDir\application-events.csv"

   # Docker info if applicable
   docker ps -a > "$evidenceDir\docker-containers.txt"
   docker images > "$evidenceDir\docker-images.txt"
   ```

3. **Assess Scope (10 minutes)**
   ```powershell
   # Check for unauthorized code execution
   Get-ChildItem C:\actions-runner\_work -Recurse -File |
     Where-Object { $_.Extension -in '.exe','.ps1','.bat','.cmd' } |
     Select-Object FullName, CreationTime, LastWriteTime

   # Check for data exfiltration
   Get-Content C:\actions-runner\_diag\*.log | Select-String -Pattern "upload|curl|wget|invoke-webrequest"

   # Check for modified system files
   Get-ChildItem C:\Windows\System32 |
     Where-Object { $_.LastWriteTime -gt (Get-Date).AddHours(-24) }
   ```

4. **Revoke Access (5 minutes)**
   ```powershell
   # Remove runner from GitHub
   cd C:\actions-runner
   .\config.cmd remove --token <REMOVAL-TOKEN>

   # Rotate all secrets in GitHub
   # Repository → Settings → Secrets and variables → Actions
   # Update all secrets

   # Rotate runner registration token
   # Generate new token in GitHub → Settings → Actions → Runners
   ```

5. **Clean Compromised System (15 minutes)**
   ```powershell
   # Remove all workspaces
   Remove-Item C:\actions-runner\_work\* -Recurse -Force

   # Remove all Docker containers and images
   docker stop $(docker ps -aq)
   docker rm $(docker ps -aq)
   docker rmi $(docker images -q) -f

   # Run antivirus scan
   Start-MpScan -ScanType FullScan

   # Consider full system reinstall if compromise is severe
   ```

6. **Restore from Clean State (10 minutes)**
   ```powershell
   # Reinstall runner
   Remove-Item C:\actions-runner\* -Recurse -Force
   # Download fresh runner from GitHub
   # Configure with new token
   # Restore only verified clean configurations

   # Restore firewall rules
   .\scripts\apply-firewall-rules.ps1

   # Re-enable network (with firewall)
   Set-NetFirewallProfile -Profile Domain,Public,Private -DefaultOutboundAction Allow
   ```

7. **Verify and Monitor (5 minutes)**
   ```powershell
   # Start runner service
   Start-Service -Name "actions.runner.*"

   # Monitor closely for 24-48 hours
   # Enable enhanced logging
   # Run test workflows only
   ```

8. **Post-Incident Actions**
   - Document timeline and attack vector
   - Review workflow permissions and security settings
   - Implement additional security controls
   - Consider requiring workflow approval for public PRs
   - Notify stakeholders as appropriate

---

## Error Message Reference

Common error messages and their solutions:

### "The runner process terminated unexpectedly"
**Cause:** Runner crashed or was killed
**Solution:** Check system logs, ensure adequate resources, restart runner service

### "unable to access 'https://github.com/': Failed to connect"
**Cause:** Network connectivity issue
**Solution:** Check firewall, DNS, proxy settings

### "Error: No space left on device"
**Cause:** Disk full
**Solution:** Run cleanup scripts, remove old workspaces, prune Docker

### "Error: Cannot assign requested address"
**Cause:** Network interface issue or port exhaustion
**Solution:** Restart network adapter, check for port conflicts

### "Error response from daemon: pull access denied"
**Cause:** Docker Hub rate limit or authentication issue
**Solution:** Login to Docker Hub, wait for rate limit reset

### "##[error]Unable to locate executable file: docker"
**Cause:** Docker not installed or not in PATH
**Solution:** Install Docker, add to PATH, restart runner

### "CUDA error: no kernel image available"
**Cause:** CUDA version mismatch
**Solution:** Update NVIDIA drivers, match CUDA version in container

### "Error: The service did not start due to a logon failure"
**Cause:** Service account credentials invalid
**Solution:** Update service credentials, grant necessary permissions

---

## Diagnostic Decision Tree

```
Job not running?
│
├─ Runner showing as offline?
│  ├─ YES → Check service status → See "Runner Offline/Not Connecting"
│  └─ NO → Continue
│
├─ Job queued for >5 minutes?
│  ├─ YES → Check runner labels → See "Jobs Stuck in Queue"
│  └─ NO → Continue
│
├─ Job failing during execution?
│  ├─ Disk space error? → See "Disk Space Exhaustion"
│  ├─ GPU error? → See "GPU Not Detected"
│  ├─ Network error? → See "Network Connectivity Issues"
│  ├─ Permission error? → See "Permission Errors"
│  └─ Other → Check job logs: gh run view <run-id> --log
│
└─ System unresponsive?
   └─ YES → See "Emergency Runbooks - Runner Completely Unresponsive"
```

### Quick Decision Guide

1. **Is the runner showing as online in GitHub?**
   - NO → Service issue → Check service status
   - YES → Continue

2. **Can you ping github.com?**
   - NO → Network issue → Check firewall/DNS
   - YES → Continue

3. **Is disk space >10% free?**
   - NO → Storage issue → Run cleanup
   - YES → Continue

4. **Are jobs starting but failing?**
   - YES → Workflow/environment issue → Check job logs
   - NO → Queue issue → Check labels and capacity

5. **Is system responsive?**
   - NO → Critical issue → See emergency runbooks
   - YES → Review specific error messages

---

## Log Locations

Important log locations for troubleshooting:

```powershell
# Runner diagnostic logs
C:\actions-runner\_diag\

# Runner worker logs (per job)
C:\actions-runner\_diag\Worker_*.log

# Windows Event Logs
Get-EventLog -LogName Application -Source "actions.runner.*"

# Docker logs
docker logs <container-id>

# IIS logs (if applicable)
C:\inetpub\logs\LogFiles\

# Custom script logs
C:\actions-runner\logs\

# Windows System logs
C:\Windows\System32\winevt\Logs\
```

---

## Related Scripts

Automation scripts for common troubleshooting tasks:

- `scripts/cleanup-workspace.ps1` - Workspace cleanup
- `scripts/rotate-logs.ps1` - Log rotation
- `scripts/collect-logs.ps1` - Diagnostic log collection
- `scripts/analyze-logs.ps1` - Log analysis
- `scripts/apply-firewall-rules.ps1` - Firewall configuration
- `.github/workflows/runner-health.yml` - Automated health checks

---

## Additional Resources

- [GitHub Actions Self-Hosted Runner Documentation](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Docker Troubleshooting](https://docs.docker.com/config/daemon/)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- [Windows Event Logs](https://docs.microsoft.com/en-us/windows/win32/eventlog/event-logging)

## Related Documentation

- [Security Guide](./security.md)
- [Maintenance Guide](./maintenance.md)
- [Hardware Specifications](./hardware-specs.md)
- [Self-Hosted Runner Setup](../README.md)

---

**Last Updated:** 2025-10-03
**Maintained By:** Dakota Irsik
**Version:** 1.0
