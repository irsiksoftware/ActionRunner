<#
.SYNOPSIS
    Benchmarks self-hosted runner performance across different workload types.

.DESCRIPTION
    This script measures runner performance for various tasks including:
    - Disk I/O operations
    - Network throughput to GitHub
    - .NET compilation speed
    - Python test execution
    - Git operations
    Generates detailed benchmark reports in markdown format.

.PARAMETER OutputPath
    Directory to save benchmark reports (default: ./benchmark-reports)

.PARAMETER RunAll
    Run all available benchmarks

.PARAMETER BenchmarkTypes
    Comma-separated list of specific benchmarks to run:
    diskio, network, dotnet, python, git

.PARAMETER Iterations
    Number of iterations for each benchmark (default: 3)

.EXAMPLE
    .\benchmark-runner.ps1 -RunAll

.EXAMPLE
    .\benchmark-runner.ps1 -BenchmarkTypes "diskio,network" -Iterations 5
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = (Join-Path (Get-Location).Path "benchmark-reports"),

    [Parameter(Mandatory = $false)]
    [switch]$RunAll,

    [Parameter(Mandatory = $false)]
    [string]$BenchmarkTypes = "",

    [Parameter(Mandatory = $false)]
    [int]$Iterations = 3
)

$ErrorActionPreference = "Stop"

# Setup output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
}

$ReportFile = Join-Path $OutputPath "benchmark-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
$JsonReportFile = Join-Path $OutputPath "benchmark-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

# Global results storage
$script:BenchmarkResults = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    SystemInfo = @{}
    Benchmarks = @{}
}

function Write-BenchmarkLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARN"  { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage -ForegroundColor Cyan }
    }
}

function Get-SystemInfo {
    Write-BenchmarkLog "Collecting system information..."

    $info = @{
        OS = [System.Environment]::OSVersion.VersionString
        Processor = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
        ProcessorCores = (Get-CimInstance Win32_Processor | Select-Object -First 1).NumberOfCores
        ProcessorThreads = (Get-CimInstance Win32_Processor | Select-Object -First 1).NumberOfLogicalProcessors
        TotalMemoryGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
        AvailableMemoryGB = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB / 1024, 2)
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
    }

    $script:BenchmarkResults.SystemInfo = $info
    Write-BenchmarkLog "System info collected" "SUCCESS"
}

function Measure-DiskIOPerformance {
    Write-BenchmarkLog "Starting Disk I/O benchmark..."

    $tempDir = Join-Path $env:TEMP "benchmark-diskio"
    if (-not (Test-Path $tempDir)) {
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    }

    $results = @{
        WriteSpeedMBps = @()
        ReadSpeedMBps = @()
        SmallFileOps = @()
    }

    for ($i = 1; $i -le $Iterations; $i++) {
        Write-BenchmarkLog "  Disk I/O iteration $i/$Iterations..."

        # Test large file write (100MB)
        $testFile = Join-Path $tempDir "testfile-$i.bin"
        $data = New-Object byte[] (100MB)
        (New-Object Random).NextBytes($data)

        $writeTimer = [System.Diagnostics.Stopwatch]::StartNew()
        [System.IO.File]::WriteAllBytes($testFile, $data)
        $writeTimer.Stop()
        $writeMBps = [math]::Round(100 / $writeTimer.Elapsed.TotalSeconds, 2)
        $results.WriteSpeedMBps += $writeMBps

        # Test large file read
        $readTimer = [System.Diagnostics.Stopwatch]::StartNew()
        $readData = [System.IO.File]::ReadAllBytes($testFile)
        $readTimer.Stop()
        $readMBps = [math]::Round(100 / $readTimer.Elapsed.TotalSeconds, 2)
        $results.ReadSpeedMBps += $readMBps

        # Test small file operations (1000 files)
        $smallFileTimer = [System.Diagnostics.Stopwatch]::StartNew()
        for ($j = 0; $j -lt 1000; $j++) {
            $smallFile = Join-Path $tempDir "small-$j.txt"
            "test data" | Out-File -FilePath $smallFile -Force
        }
        $smallFileTimer.Stop()
        $opsPerSec = [math]::Round(1000 / $smallFileTimer.Elapsed.TotalSeconds, 0)
        $results.SmallFileOps += $opsPerSec

        Remove-Item -Path $testFile -Force -ErrorAction SilentlyContinue
    }

    # Cleanup
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

    $summary = @{
        AvgWriteSpeedMBps = [math]::Round(($results.WriteSpeedMBps | Measure-Object -Average).Average, 2)
        AvgReadSpeedMBps = [math]::Round(($results.ReadSpeedMBps | Measure-Object -Average).Average, 2)
        AvgSmallFileOpsPerSec = [math]::Round(($results.SmallFileOps | Measure-Object -Average).Average, 0)
        RawResults = $results
    }

    $script:BenchmarkResults.Benchmarks.DiskIO = $summary
    Write-BenchmarkLog "Disk I/O benchmark completed: Write=$($summary.AvgWriteSpeedMBps) MB/s, Read=$($summary.AvgReadSpeedMBps) MB/s" "SUCCESS"
}

function Measure-NetworkPerformance {
    Write-BenchmarkLog "Starting Network benchmark..."

    $results = @{
        GitHubLatencyMs = @()
        DownloadSpeedMBps = @()
    }

    for ($i = 1; $i -le $Iterations; $i++) {
        Write-BenchmarkLog "  Network iteration $i/$Iterations..."

        # Test GitHub API latency
        try {
            $latencyTimer = [System.Diagnostics.Stopwatch]::StartNew()
            $response = Invoke-WebRequest -Uri "https://api.github.com" -UseBasicParsing -TimeoutSec 10
            $latencyTimer.Stop()
            $results.GitHubLatencyMs += [math]::Round($latencyTimer.Elapsed.TotalMilliseconds, 0)
        } catch {
            Write-BenchmarkLog "  GitHub API test failed: $_" "WARN"
            $results.GitHubLatencyMs += -1
        }

        # Test download speed (small file from GitHub)
        try {
            $downloadUrl = "https://github.com/git/git/archive/refs/heads/master.zip"
            $tempFile = Join-Path $env:TEMP "benchmark-download-$i.zip"

            $downloadTimer = [System.Diagnostics.Stopwatch]::StartNew()
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -UseBasicParsing -TimeoutSec 30
            $downloadTimer.Stop()

            $fileSizeMB = [math]::Round((Get-Item $tempFile).Length / 1MB, 2)
            $speedMBps = [math]::Round($fileSizeMB / $downloadTimer.Elapsed.TotalSeconds, 2)
            $results.DownloadSpeedMBps += $speedMBps

            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
        } catch {
            Write-BenchmarkLog "  Download speed test failed: $_" "WARN"
            $results.DownloadSpeedMBps += -1
        }

        Start-Sleep -Seconds 1
    }

    # Filter out failed attempts (-1 values)
    $validLatencies = $results.GitHubLatencyMs | Where-Object { $_ -gt 0 }
    $validSpeeds = $results.DownloadSpeedMBps | Where-Object { $_ -gt 0 }

    $summary = @{
        AvgGitHubLatencyMs = if ($validLatencies.Count -gt 0) { [math]::Round(($validLatencies | Measure-Object -Average).Average, 0) } else { 0 }
        AvgDownloadSpeedMBps = if ($validSpeeds.Count -gt 0) { [math]::Round(($validSpeeds | Measure-Object -Average).Average, 2) } else { 0 }
        RawResults = $results
    }

    $script:BenchmarkResults.Benchmarks.Network = $summary
    Write-BenchmarkLog "Network benchmark completed: Latency=$($summary.AvgGitHubLatencyMs)ms, Speed=$($summary.AvgDownloadSpeedMBps) MB/s" "SUCCESS"
}

function Measure-DotNetPerformance {
    Write-BenchmarkLog "Starting .NET compilation benchmark..."

    # Check if dotnet is available
    $dotnetPath = Get-Command dotnet -ErrorAction SilentlyContinue
    if (-not $dotnetPath) {
        Write-BenchmarkLog ".NET SDK not found, skipping .NET benchmark" "WARN"
        $script:BenchmarkResults.Benchmarks.DotNet = @{ Status = "Skipped - .NET SDK not installed" }
        return
    }

    $tempDir = Join-Path $env:TEMP "benchmark-dotnet"
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null

    $results = @{
        CompileTimeSeconds = @()
        BuildTimeSeconds = @()
    }

    try {
        Push-Location $tempDir

        # Create a simple .NET console app
        Write-BenchmarkLog "  Creating test .NET project..."
        dotnet new console -n BenchmarkApp --force 2>&1 | Out-Null
        Set-Location (Join-Path $tempDir "BenchmarkApp")

        for ($i = 1; $i -le $Iterations; $i++) {
            Write-BenchmarkLog "  .NET iteration $i/$Iterations..."

            # Clean before each iteration
            if (Test-Path "bin") { Remove-Item -Path "bin" -Recurse -Force }
            if (Test-Path "obj") { Remove-Item -Path "obj" -Recurse -Force }

            # Measure build time
            $buildTimer = [System.Diagnostics.Stopwatch]::StartNew()
            $buildOutput = dotnet build --configuration Release 2>&1
            $buildTimer.Stop()

            if ($LASTEXITCODE -eq 0) {
                $results.BuildTimeSeconds += [math]::Round($buildTimer.Elapsed.TotalSeconds, 2)
            } else {
                Write-BenchmarkLog "  Build failed" "WARN"
            }
        }

        Pop-Location
    } catch {
        Write-BenchmarkLog "  .NET benchmark error: $_" "ERROR"
    } finally {
        Pop-Location -ErrorAction SilentlyContinue
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($results.BuildTimeSeconds.Count -gt 0) {
        $summary = @{
            AvgBuildTimeSeconds = [math]::Round(($results.BuildTimeSeconds | Measure-Object -Average).Average, 2)
            RawResults = $results
        }
        $script:BenchmarkResults.Benchmarks.DotNet = $summary
        Write-BenchmarkLog ".NET benchmark completed: Avg build time=$($summary.AvgBuildTimeSeconds)s" "SUCCESS"
    } else {
        $script:BenchmarkResults.Benchmarks.DotNet = @{ Status = "Failed - No successful builds" }
        Write-BenchmarkLog ".NET benchmark failed" "ERROR"
    }
}

function Measure-PythonPerformance {
    Write-BenchmarkLog "Starting Python benchmark..."

    # Check if Python is available
    $pythonPath = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pythonPath) {
        $pythonPath = Get-Command python3 -ErrorAction SilentlyContinue
    }

    if (-not $pythonPath) {
        Write-BenchmarkLog "Python not found, skipping Python benchmark" "WARN"
        $script:BenchmarkResults.Benchmarks.Python = @{ Status = "Skipped - Python not installed" }
        return
    }

    $results = @{
        StartupTimeMs = @()
        SimpleScriptTimeMs = @()
    }

    for ($i = 1; $i -le $Iterations; $i++) {
        Write-BenchmarkLog "  Python iteration $i/$Iterations..."

        # Measure Python startup time
        $startupTimer = [System.Diagnostics.Stopwatch]::StartNew()
        & python -c "pass" 2>&1 | Out-Null
        $startupTimer.Stop()
        $results.StartupTimeMs += [math]::Round($startupTimer.Elapsed.TotalMilliseconds, 0)

        # Measure simple computation
        $scriptTimer = [System.Diagnostics.Stopwatch]::StartNew()
        & python -c "sum(range(1000000))" 2>&1 | Out-Null
        $scriptTimer.Stop()
        $results.SimpleScriptTimeMs += [math]::Round($scriptTimer.Elapsed.TotalMilliseconds, 0)
    }

    $summary = @{
        AvgStartupTimeMs = [math]::Round(($results.StartupTimeMs | Measure-Object -Average).Average, 0)
        AvgSimpleScriptTimeMs = [math]::Round(($results.SimpleScriptTimeMs | Measure-Object -Average).Average, 0)
        RawResults = $results
    }

    $script:BenchmarkResults.Benchmarks.Python = $summary
    Write-BenchmarkLog "Python benchmark completed: Startup=$($summary.AvgStartupTimeMs)ms, Script=$($summary.AvgSimpleScriptTimeMs)ms" "SUCCESS"
}

function Measure-GitPerformance {
    Write-BenchmarkLog "Starting Git benchmark..."

    # Check if git is available
    $gitPath = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitPath) {
        Write-BenchmarkLog "Git not found, skipping Git benchmark" "WARN"
        $script:BenchmarkResults.Benchmarks.Git = @{ Status = "Skipped - Git not installed" }
        return
    }

    $tempDir = Join-Path $env:TEMP "benchmark-git"
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }

    $results = @{
        CloneTimeSeconds = @()
        StatusTimeMs = @()
    }

    try {
        # Clone a small repository
        for ($i = 1; $i -le $Iterations; $i++) {
            Write-BenchmarkLog "  Git iteration $i/$Iterations..."

            $cloneDir = Join-Path $tempDir "clone-$i"

            # Measure clone time (small repo)
            $cloneTimer = [System.Diagnostics.Stopwatch]::StartNew()
            git clone --depth 1 https://github.com/github/gitignore.git $cloneDir 2>&1 | Out-Null
            $cloneTimer.Stop()

            if ($LASTEXITCODE -eq 0) {
                $results.CloneTimeSeconds += [math]::Round($cloneTimer.Elapsed.TotalSeconds, 2)

                # Measure git status time
                Push-Location $cloneDir
                $statusTimer = [System.Diagnostics.Stopwatch]::StartNew()
                git status 2>&1 | Out-Null
                $statusTimer.Stop()
                $results.StatusTimeMs += [math]::Round($statusTimer.Elapsed.TotalMilliseconds, 0)
                Pop-Location
            } else {
                Write-BenchmarkLog "  Git clone failed" "WARN"
            }

            Start-Sleep -Seconds 1
        }
    } catch {
        Write-BenchmarkLog "  Git benchmark error: $_" "ERROR"
    } finally {
        Pop-Location -ErrorAction SilentlyContinue
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($results.CloneTimeSeconds.Count -gt 0) {
        $summary = @{
            AvgCloneTimeSeconds = [math]::Round(($results.CloneTimeSeconds | Measure-Object -Average).Average, 2)
            AvgStatusTimeMs = [math]::Round(($results.StatusTimeMs | Measure-Object -Average).Average, 0)
            RawResults = $results
        }
        $script:BenchmarkResults.Benchmarks.Git = $summary
        Write-BenchmarkLog "Git benchmark completed: Clone=$($summary.AvgCloneTimeSeconds)s, Status=$($summary.AvgStatusTimeMs)ms" "SUCCESS"
    } else {
        $script:BenchmarkResults.Benchmarks.Git = @{ Status = "Failed - No successful clones" }
        Write-BenchmarkLog "Git benchmark failed" "ERROR"
    }
}

function Get-BaselineComparison {
    Write-BenchmarkLog "Loading baseline data for comparison..."

    $baselinePath = Join-Path (Split-Path $PSScriptRoot -Parent) "data" "benchmark-baseline.json"

    if (-not (Test-Path $baselinePath)) {
        Write-BenchmarkLog "Baseline file not found: $baselinePath" "WARN"
        return $null
    }

    try {
        $baseline = Get-Content $baselinePath -Raw | ConvertFrom-Json
        Write-BenchmarkLog "Baseline data loaded successfully" "SUCCESS"
        return $baseline
    } catch {
        Write-BenchmarkLog "Failed to load baseline data: $_" "ERROR"
        return $null
    }
}

function Compare-WithBaseline {
    param($Baseline)

    if (-not $Baseline) {
        return @()
    }

    $comparisons = @()

    # Compare DiskIO
    if ($script:BenchmarkResults.Benchmarks.DiskIO -and -not $script:BenchmarkResults.Benchmarks.DiskIO.Status) {
        $diskIO = $script:BenchmarkResults.Benchmarks.DiskIO
        $baselineDiskIO = $Baseline.baselines.DiskIO

        if ($diskIO.AvgWriteSpeedMBps -lt $baselineDiskIO.MinWriteSpeedMBps) {
            $comparisons += @{
                Category = "DiskIO"
                Metric = "Write Speed"
                Value = $diskIO.AvgWriteSpeedMBps
                Baseline = $baselineDiskIO.MinWriteSpeedMBps
                Status = "Below Baseline"
            }
        }

        if ($diskIO.AvgReadSpeedMBps -lt $baselineDiskIO.MinReadSpeedMBps) {
            $comparisons += @{
                Category = "DiskIO"
                Metric = "Read Speed"
                Value = $diskIO.AvgReadSpeedMBps
                Baseline = $baselineDiskIO.MinReadSpeedMBps
                Status = "Below Baseline"
            }
        }

        if ($diskIO.AvgSmallFileOpsPerSec -lt $baselineDiskIO.MinSmallFileOpsPerSec) {
            $comparisons += @{
                Category = "DiskIO"
                Metric = "Small File Ops"
                Value = $diskIO.AvgSmallFileOpsPerSec
                Baseline = $baselineDiskIO.MinSmallFileOpsPerSec
                Status = "Below Baseline"
            }
        }
    }

    # Compare Network
    if ($script:BenchmarkResults.Benchmarks.Network -and -not $script:BenchmarkResults.Benchmarks.Network.Status) {
        $network = $script:BenchmarkResults.Benchmarks.Network
        $baselineNetwork = $Baseline.baselines.Network

        if ($network.AvgGitHubLatencyMs -gt $baselineNetwork.MaxGitHubLatencyMs) {
            $comparisons += @{
                Category = "Network"
                Metric = "GitHub Latency"
                Value = $network.AvgGitHubLatencyMs
                Baseline = $baselineNetwork.MaxGitHubLatencyMs
                Status = "Above Baseline"
            }
        }

        if ($network.AvgDownloadSpeedMBps -lt $baselineNetwork.MinDownloadSpeedMBps -and $network.AvgDownloadSpeedMBps -gt 0) {
            $comparisons += @{
                Category = "Network"
                Metric = "Download Speed"
                Value = $network.AvgDownloadSpeedMBps
                Baseline = $baselineNetwork.MinDownloadSpeedMBps
                Status = "Below Baseline"
            }
        }
    }

    # Compare DotNet
    if ($script:BenchmarkResults.Benchmarks.DotNet -and -not $script:BenchmarkResults.Benchmarks.DotNet.Status) {
        $dotnet = $script:BenchmarkResults.Benchmarks.DotNet
        $baselineDotNet = $Baseline.baselines.DotNet

        if ($dotnet.AvgBuildTimeSeconds -gt $baselineDotNet.MaxBuildTimeSeconds) {
            $comparisons += @{
                Category = "DotNet"
                Metric = "Build Time"
                Value = $dotnet.AvgBuildTimeSeconds
                Baseline = $baselineDotNet.MaxBuildTimeSeconds
                Status = "Above Baseline"
            }
        }
    }

    # Compare Python
    if ($script:BenchmarkResults.Benchmarks.Python -and -not $script:BenchmarkResults.Benchmarks.Python.Status) {
        $python = $script:BenchmarkResults.Benchmarks.Python
        $baselinePython = $Baseline.baselines.Python

        if ($python.AvgStartupTimeMs -gt $baselinePython.MaxStartupTimeMs) {
            $comparisons += @{
                Category = "Python"
                Metric = "Startup Time"
                Value = $python.AvgStartupTimeMs
                Baseline = $baselinePython.MaxStartupTimeMs
                Status = "Above Baseline"
            }
        }
    }

    # Compare Git
    if ($script:BenchmarkResults.Benchmarks.Git -and -not $script:BenchmarkResults.Benchmarks.Git.Status) {
        $git = $script:BenchmarkResults.Benchmarks.Git
        $baselineGit = $Baseline.baselines.Git

        if ($git.AvgCloneTimeSeconds -gt $baselineGit.MaxCloneTimeSeconds) {
            $comparisons += @{
                Category = "Git"
                Metric = "Clone Time"
                Value = $git.AvgCloneTimeSeconds
                Baseline = $baselineGit.MaxCloneTimeSeconds
                Status = "Above Baseline"
            }
        }
    }

    return $comparisons
}

function Export-BenchmarkReport {
    Write-BenchmarkLog "Generating benchmark reports..."

    # Load and compare with baseline
    $baseline = Get-BaselineComparison
    $baselineComparisons = Compare-WithBaseline -Baseline $baseline

    # Export JSON
    $script:BenchmarkResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $JsonReportFile -Encoding UTF8
    Write-BenchmarkLog "JSON report saved: $JsonReportFile" "SUCCESS"

    # Generate Markdown report
    $markdown = @"
# Runner Performance Benchmark Report

**Generated:** $($script:BenchmarkResults.Timestamp)

## System Information

- **OS:** $($script:BenchmarkResults.SystemInfo.OS)
- **Processor:** $($script:BenchmarkResults.SystemInfo.Processor)
- **Cores:** $($script:BenchmarkResults.SystemInfo.ProcessorCores) cores / $($script:BenchmarkResults.SystemInfo.ProcessorThreads) threads
- **Total Memory:** $($script:BenchmarkResults.SystemInfo.TotalMemoryGB) GB
- **Available Memory:** $($script:BenchmarkResults.SystemInfo.AvailableMemoryGB) GB
- **PowerShell Version:** $($script:BenchmarkResults.SystemInfo.PowerShellVersion)

## Benchmark Results

"@

    # Add each benchmark section
    foreach ($benchmark in $script:BenchmarkResults.Benchmarks.Keys) {
        $data = $script:BenchmarkResults.Benchmarks[$benchmark]
        $markdown += "`n### $benchmark Performance`n`n"

        if ($data.Status) {
            $markdown += "**Status:** $($data.Status)`n"
        } else {
            foreach ($metric in $data.Keys) {
                if ($metric -ne "RawResults") {
                    $metricValue = $data[$metric]
                    $markdown += "- **${metric}:** $metricValue`n"
                }
            }
        }
    }

    # Add performance ratings
    $markdown += @"

## Performance Rating

Based on typical CI/CD workload requirements:

"@

    # Disk I/O rating
    if ($script:BenchmarkResults.Benchmarks.DiskIO) {
        $writeSpeed = $script:BenchmarkResults.Benchmarks.DiskIO.AvgWriteSpeedMBps
        $diskRating = if ($writeSpeed -gt 500) { "Excellent (SSD)" }
                      elseif ($writeSpeed -gt 200) { "Good (Fast SSD)" }
                      elseif ($writeSpeed -gt 100) { "Adequate (SATA SSD)" }
                      else { "Poor (HDD or slow disk)" }
        $markdown += "- **Disk I/O:** $diskRating`n"
    }

    # Network rating
    if ($script:BenchmarkResults.Benchmarks.Network) {
        $latency = $script:BenchmarkResults.Benchmarks.Network.AvgGitHubLatencyMs
        $netRating = if ($latency -lt 50) { "Excellent (Low latency)" }
                     elseif ($latency -lt 150) { "Good" }
                     elseif ($latency -lt 300) { "Adequate" }
                     else { "Poor (High latency)" }
        $markdown += "- **Network:** $netRating`n"
    }

    # Add baseline comparison section
    if ($baselineComparisons.Count -gt 0) {
        $markdown += @"

## Baseline Comparison

The following metrics are outside acceptable baseline thresholds:

"@
        foreach ($comp in $baselineComparisons) {
            $markdown += "- **$($comp.Category) - $($comp.Metric):** $($comp.Value) (Baseline: $($comp.Baseline), Status: $($comp.Status))`n"
        }
    } else {
        $markdown += @"

## Baseline Comparison

✓ All metrics meet or exceed baseline thresholds.

"@
    }

    $markdown += @"

## Recommendations

"@

    # Add recommendations based on results
    $recommendations = @()

    if ($script:BenchmarkResults.Benchmarks.DiskIO.AvgWriteSpeedMBps -lt 200) {
        $recommendations += "- Consider upgrading to a faster SSD for improved build performance"
    }

    if ($script:BenchmarkResults.Benchmarks.Network.AvgGitHubLatencyMs -gt 200) {
        $recommendations += "- Network latency to GitHub is high; consider network optimization"
    }

    if ($script:BenchmarkResults.SystemInfo.AvailableMemoryGB -lt 4) {
        $recommendations += "- Available memory is low; consider closing applications or adding RAM"
    }

    # Add baseline-specific recommendations
    foreach ($comp in $baselineComparisons) {
        $recommendations += "- $($comp.Category): $($comp.Metric) is $($comp.Status.ToLower()) (current: $($comp.Value), baseline: $($comp.Baseline))"
    }

    if ($recommendations.Count -eq 0) {
        $markdown += "System performance is adequate for typical CI/CD workloads.`n"
    } else {
        $markdown += ($recommendations -join "`n") + "`n"
    }

    $markdown += @"

---

*To compare with future benchmarks, save this report and run the benchmark script periodically.*
"@

    $markdown | Out-File -FilePath $ReportFile -Encoding UTF8
    Write-BenchmarkLog "Markdown report saved: $ReportFile" "SUCCESS"
}

# Main execution
Write-Host "`n=== Runner Performance Benchmark ===" -ForegroundColor Cyan
Write-Host "Iterations per test: $Iterations`n" -ForegroundColor Cyan

Get-SystemInfo

# Determine which benchmarks to run
$benchmarksToRun = @()

if ($RunAll) {
    $benchmarksToRun = @("diskio", "network", "dotnet", "python", "git")
} elseif ($BenchmarkTypes) {
    $benchmarksToRun = $BenchmarkTypes.ToLower() -split ","
} else {
    # Default: run all
    $benchmarksToRun = @("diskio", "network", "dotnet", "python", "git")
}

Write-BenchmarkLog "Running benchmarks: $($benchmarksToRun -join ', ')"
Write-Host ""

foreach ($benchmark in $benchmarksToRun) {
    switch ($benchmark.Trim()) {
        "diskio" { Measure-DiskIOPerformance }
        "network" { Measure-NetworkPerformance }
        "dotnet" { Measure-DotNetPerformance }
        "python" { Measure-PythonPerformance }
        "git" { Measure-GitPerformance }
        default { Write-BenchmarkLog "Unknown benchmark type: $benchmark" "WARN" }
    }
    Write-Host ""
}

Export-BenchmarkReport

Write-Host "`n=== Benchmark Complete ===" -ForegroundColor Green
Write-Host "Reports saved to:" -ForegroundColor Cyan
Write-Host "  - Markdown: $ReportFile" -ForegroundColor White
Write-Host "  - JSON: $JsonReportFile" -ForegroundColor White
Write-Host ""
