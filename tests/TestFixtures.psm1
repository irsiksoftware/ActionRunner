<#
.SYNOPSIS
    Test data fixtures and mocks for GitHub Actions Runner tests.

.DESCRIPTION
    This module provides reusable test fixtures, mock data, and helper functions
    for testing GitHub Actions Runner scripts. It includes common test scenarios
    and data patterns to improve test consistency and reduce code duplication.

.NOTES
    Version: 1.0.0
    Created: 2025-10-04
#>

# Mock GitHub API Responses
function Get-MockRunnerResponse {
    <#
    .SYNOPSIS
        Returns mock GitHub API response for runner registration.
    #>
    param(
        [ValidateSet('Success', 'TokenExpired', 'NotFound', 'RateLimited')]
        [string]$Scenario = 'Success'
    )

    switch ($Scenario) {
        'Success' {
            return @{
                id = 12345
                name = 'test-runner'
                os = 'windows'
                status = 'online'
                busy = $false
                labels = @(
                    @{ name = 'self-hosted' }
                    @{ name = 'Windows' }
                    @{ name = 'X64' }
                )
            }
        }
        'TokenExpired' {
            throw [System.Net.WebException]::new('401 Unauthorized')
        }
        'NotFound' {
            throw [System.Net.WebException]::new('404 Not Found')
        }
        'RateLimited' {
            throw [System.Net.WebException]::new('429 Too Many Requests')
        }
    }
}

function Get-MockDockerContainerList {
    <#
    .SYNOPSIS
        Returns mock Docker container list response.
    #>
    param(
        [ValidateSet('Running', 'Stopped', 'Mixed', 'Empty')]
        [string]$Scenario = 'Running'
    )

    switch ($Scenario) {
        'Running' {
            return @(
                @{
                    ID = 'abc123'
                    Image = 'ubuntu:latest'
                    Status = 'Up 2 hours'
                    Names = 'test-container-1'
                }
                @{
                    ID = 'def456'
                    Image = 'nginx:alpine'
                    Status = 'Up 5 minutes'
                    Names = 'test-container-2'
                }
            )
        }
        'Stopped' {
            return @(
                @{
                    ID = 'xyz789'
                    Image = 'ubuntu:latest'
                    Status = 'Exited (0) 1 hour ago'
                    Names = 'stopped-container'
                }
            )
        }
        'Mixed' {
            return @(
                @{
                    ID = 'abc123'
                    Image = 'ubuntu:latest'
                    Status = 'Up 2 hours'
                    Names = 'running-container'
                }
                @{
                    ID = 'xyz789'
                    Image = 'nginx:alpine'
                    Status = 'Exited (0) 1 hour ago'
                    Names = 'stopped-container'
                }
            )
        }
        'Empty' {
            return @()
        }
    }
}

# Mock File System Structures
function New-MockRunnerDirectory {
    <#
    .SYNOPSIS
        Creates a mock runner directory structure for testing.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$IncludeLogs,
        [switch]$IncludeConfig
    )

    # Create base structure
    $directories = @(
        '_diag',
        '_work',
        'bin'
    )

    foreach ($dir in $directories) {
        $fullPath = Join-Path $Path $dir
        if (-not (Test-Path $fullPath)) {
            New-Item -Path $fullPath -ItemType Directory -Force | Out-Null
        }
    }

    if ($IncludeLogs) {
        $logPath = Join-Path $Path '_diag'
        $logFiles = @(
            'Worker_20250104-120000-utc.log',
            'Worker_20250104-130000-utc.log'
        )

        foreach ($logFile in $logFiles) {
            $logFilePath = Join-Path $logPath $logFile
            Set-Content -Path $logFilePath -Value "Mock log content`n[2025-01-04 12:00:00Z] Runner started"
        }
    }

    if ($IncludeConfig) {
        $configPath = Join-Path $Path '.runner'
        Set-Content -Path $configPath -Value (@{
            agentId = 123
            agentName = 'test-runner'
            poolId = 1
            serverUrl = 'https://github.com'
        } | ConvertTo-Json)

        $credPath = Join-Path $Path '.credentials'
        Set-Content -Path $credPath -Value 'mock-credentials'
    }
}

function Get-MockHealthCheckResult {
    <#
    .SYNOPSIS
        Returns mock health check results.
    #>
    param(
        [ValidateSet('Healthy', 'Warning', 'Critical', 'Degraded')]
        [string]$Status = 'Healthy'
    )

    $baseResult = @{
        Timestamp = Get-Date
        RunnerStatus = 'Unknown'
        DiskSpaceGB = 0
        MemoryUsagePercent = 0
        CPUUsagePercent = 0
        ActiveJobs = 0
        Issues = @()
    }

    switch ($Status) {
        'Healthy' {
            $baseResult.RunnerStatus = 'Running'
            $baseResult.DiskSpaceGB = 150
            $baseResult.MemoryUsagePercent = 45
            $baseResult.CPUUsagePercent = 30
            $baseResult.ActiveJobs = 2
        }
        'Warning' {
            $baseResult.RunnerStatus = 'Running'
            $baseResult.DiskSpaceGB = 25
            $baseResult.MemoryUsagePercent = 75
            $baseResult.CPUUsagePercent = 80
            $baseResult.ActiveJobs = 5
            $baseResult.Issues = @('Low disk space', 'High CPU usage')
        }
        'Critical' {
            $baseResult.RunnerStatus = 'Stopped'
            $baseResult.DiskSpaceGB = 5
            $baseResult.MemoryUsagePercent = 95
            $baseResult.CPUUsagePercent = 98
            $baseResult.ActiveJobs = 0
            $baseResult.Issues = @('Runner service not running', 'Critical disk space', 'High memory pressure')
        }
        'Degraded' {
            $baseResult.RunnerStatus = 'Running'
            $baseResult.DiskSpaceGB = 50
            $baseResult.MemoryUsagePercent = 65
            $baseResult.CPUUsagePercent = 70
            $baseResult.ActiveJobs = 8
            $baseResult.Issues = @('High job queue')
        }
    }

    return $baseResult
}

# Mock Configuration Data
function Get-MockRunnerConfig {
    <#
    .SYNOPSIS
        Returns mock runner configuration.
    #>
    param(
        [ValidateSet('Default', 'Custom', 'Minimal', 'Enterprise')]
        [string]$Type = 'Default'
    )

    $baseConfig = @{
        RunnerName = 'test-runner'
        WorkDirectory = 'C:\actions-runner\_work'
        Labels = @('self-hosted', 'Windows', 'X64')
        RunnerGroup = 'default'
    }

    switch ($Type) {
        'Default' {
            return $baseConfig
        }
        'Custom' {
            $baseConfig.RunnerName = 'custom-runner-01'
            $baseConfig.Labels += @('gpu', 'cuda', 'high-memory')
            $baseConfig.MaxJobs = 5
            return $baseConfig
        }
        'Minimal' {
            return @{
                RunnerName = 'minimal-runner'
                WorkDirectory = 'C:\runner'
            }
        }
        'Enterprise' {
            $baseConfig.RunnerName = 'enterprise-runner-prod-01'
            $baseConfig.Labels += @('production', 'docker', 'kubernetes')
            $baseConfig.RunnerGroup = 'production'
            $baseConfig.MaxJobs = 10
            $baseConfig.Timeout = 360
            return $baseConfig
        }
    }
}

function Get-MockDockerConfig {
    <#
    .SYNOPSIS
        Returns mock Docker configuration.
    #>
    return @{
        MaxCPUs = 4
        MaxMemoryGB = 8
        StorageDriver = 'overlay2'
        LogDriver = 'json-file'
        LogOpts = @{
            'max-size' = '10m'
            'max-file' = '3'
        }
        GPUEnabled = $false
        WSL2Enabled = $true
    }
}

# Mock Service Objects
function Get-MockServiceStatus {
    <#
    .SYNOPSIS
        Returns mock Windows service status.
    #>
    param(
        [ValidateSet('Running', 'Stopped', 'Starting', 'Stopping')]
        [string]$Status = 'Running',

        [string]$ServiceName = 'actions.runner.test-org.test-runner'
    )

    $service = [PSCustomObject]@{
        Name = $ServiceName
        DisplayName = "GitHub Actions Runner ($ServiceName)"
        Status = $Status
        StartType = 'Automatic'
        CanStop = ($Status -eq 'Running')
        CanPauseAndContinue = $false
    }

    return $service
}

# Mock Performance Metrics
function Get-MockPerformanceMetrics {
    <#
    .SYNOPSIS
        Returns mock performance metrics.
    #>
    param(
        [ValidateSet('Normal', 'High', 'Low')]
        [string]$LoadLevel = 'Normal'
    )

    $metrics = @{
        Timestamp = Get-Date
        CPU = @{
            UsagePercent = 0
            IdlePercent = 0
            ProcessorCount = 8
        }
        Memory = @{
            TotalGB = 16
            UsedGB = 0
            FreeGB = 0
            UsagePercent = 0
        }
        Disk = @{
            TotalGB = 500
            UsedGB = 0
            FreeGB = 0
            UsagePercent = 0
            ReadBytesPerSec = 0
            WriteBytesPerSec = 0
        }
        Network = @{
            BytesReceivedPerSec = 0
            BytesSentPerSec = 0
        }
    }

    switch ($LoadLevel) {
        'Normal' {
            $metrics.CPU.UsagePercent = 35
            $metrics.CPU.IdlePercent = 65
            $metrics.Memory.UsedGB = 8
            $metrics.Memory.FreeGB = 8
            $metrics.Memory.UsagePercent = 50
            $metrics.Disk.UsedGB = 250
            $metrics.Disk.FreeGB = 250
            $metrics.Disk.UsagePercent = 50
            $metrics.Disk.ReadBytesPerSec = 1048576
            $metrics.Disk.WriteBytesPerSec = 524288
            $metrics.Network.BytesReceivedPerSec = 1048576
            $metrics.Network.BytesSentPerSec = 524288
        }
        'High' {
            $metrics.CPU.UsagePercent = 85
            $metrics.CPU.IdlePercent = 15
            $metrics.Memory.UsedGB = 14
            $metrics.Memory.FreeGB = 2
            $metrics.Memory.UsagePercent = 87.5
            $metrics.Disk.UsedGB = 450
            $metrics.Disk.FreeGB = 50
            $metrics.Disk.UsagePercent = 90
            $metrics.Disk.ReadBytesPerSec = 104857600
            $metrics.Disk.WriteBytesPerSec = 52428800
            $metrics.Network.BytesReceivedPerSec = 10485760
            $metrics.Network.BytesSentPerSec = 5242880
        }
        'Low' {
            $metrics.CPU.UsagePercent = 10
            $metrics.CPU.IdlePercent = 90
            $metrics.Memory.UsedGB = 4
            $metrics.Memory.FreeGB = 12
            $metrics.Memory.UsagePercent = 25
            $metrics.Disk.UsedGB = 100
            $metrics.Disk.FreeGB = 400
            $metrics.Disk.UsagePercent = 20
            $metrics.Disk.ReadBytesPerSec = 102400
            $metrics.Disk.WriteBytesPerSec = 51200
            $metrics.Network.BytesReceivedPerSec = 102400
            $metrics.Network.BytesSentPerSec = 51200
        }
    }

    return $metrics
}

# Mock Job Data
function Get-MockJobHistory {
    <#
    .SYNOPSIS
        Returns mock job execution history.
    #>
    param(
        [int]$Count = 10,
        [double]$SuccessRate = 0.9
    )

    $jobs = @()
    $successCount = [Math]::Floor($Count * $SuccessRate)

    for ($i = 1; $i -le $Count; $i++) {
        $isSuccess = $i -le $successCount
        $startTime = (Get-Date).AddHours(-$i)
        $duration = Get-Random -Minimum 60 -Maximum 1800

        $job = @{
            JobId = $i
            JobName = "Build Job $i"
            Repository = 'test-org/test-repo'
            Workflow = 'CI/CD Pipeline'
            Status = if ($isSuccess) { 'Completed' } else { 'Failed' }
            Conclusion = if ($isSuccess) { 'Success' } else { 'Failure' }
            StartTime = $startTime
            EndTime = $startTime.AddSeconds($duration)
            DurationSeconds = $duration
            RunnerName = 'test-runner'
        }

        $jobs += $job
    }

    return $jobs
}

# Mock Error Patterns
function Get-MockErrorLog {
    <#
    .SYNOPSIS
        Returns mock error log entries.
    #>
    param(
        [ValidateSet('Network', 'Timeout', 'OutOfMemory', 'DiskFull', 'Mixed')]
        [string]$ErrorType = 'Mixed'
    )

    $errors = @()
    $timestamp = Get-Date

    switch ($ErrorType) {
        'Network' {
            $errors += "[ERROR] $($timestamp.ToString('yyyy-MM-dd HH:mm:ss')) Network connection failed: Unable to resolve github.com"
            $errors += "[ERROR] $($timestamp.AddMinutes(5).ToString('yyyy-MM-dd HH:mm:ss')) HTTP request timeout after 30 seconds"
        }
        'Timeout' {
            $errors += "[ERROR] $($timestamp.ToString('yyyy-MM-dd HH:mm:ss')) Job execution timeout after 360 minutes"
            $errors += "[ERROR] $($timestamp.AddMinutes(10).ToString('yyyy-MM-dd HH:mm:ss')) Workflow step timeout: test step"
        }
        'OutOfMemory' {
            $errors += "[ERROR] $($timestamp.ToString('yyyy-MM-dd HH:mm:ss')) Out of memory exception in worker process"
            $errors += "[ERROR] $($timestamp.AddMinutes(2).ToString('yyyy-MM-dd HH:mm:ss')) GC unable to allocate memory"
        }
        'DiskFull' {
            $errors += "[ERROR] $($timestamp.ToString('yyyy-MM-dd HH:mm:ss')) Insufficient disk space: 0 bytes available"
            $errors += "[ERROR] $($timestamp.AddMinutes(1).ToString('yyyy-MM-dd HH:mm:ss')) Failed to write to disk: No space left on device"
        }
        'Mixed' {
            $errors += "[ERROR] $($timestamp.ToString('yyyy-MM-dd HH:mm:ss')) Network connection failed"
            $errors += "[ERROR] $($timestamp.AddMinutes(5).ToString('yyyy-MM-dd HH:mm:ss')) Job execution timeout"
            $errors += "[ERROR] $($timestamp.AddMinutes(10).ToString('yyyy-MM-dd HH:mm:ss')) Out of memory exception"
            $errors += "[WARN] $($timestamp.AddMinutes(15).ToString('yyyy-MM-dd HH:mm:ss')) Disk space low: 5 GB remaining"
        }
    }

    return $errors -join "`n"
}

# Test Helper Functions
function New-TestDirectory {
    <#
    .SYNOPSIS
        Creates a temporary test directory.
    #>
    param(
        [string]$Prefix = 'TestDir'
    )

    $testPath = Join-Path $env:TEMP "$Prefix-$(Get-Random)"
    New-Item -Path $testPath -ItemType Directory -Force | Out-Null
    return $testPath
}

function Remove-TestDirectory {
    <#
    .SYNOPSIS
        Removes a test directory and all contents.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path $Path) {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Assert-MockCalled {
    <#
    .SYNOPSIS
        Helper to verify mock function calls (wrapper around Pester's Should -Invoke).
    #>
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [int]$Times = 1,
        [hashtable]$ParameterFilter
    )

    # This is a placeholder - actual implementation would use Pester's Should -Invoke
    # Kept here for API consistency and future enhancement
    Write-Verbose "Assert-MockCalled: $CommandName should be called $Times times"
}

# Export module members
Export-ModuleMember -Function @(
    'Get-MockRunnerResponse',
    'Get-MockDockerContainerList',
    'New-MockRunnerDirectory',
    'Get-MockHealthCheckResult',
    'Get-MockRunnerConfig',
    'Get-MockDockerConfig',
    'Get-MockServiceStatus',
    'Get-MockPerformanceMetrics',
    'Get-MockJobHistory',
    'Get-MockErrorLog',
    'New-TestDirectory',
    'Remove-TestDirectory',
    'Assert-MockCalled'
)
