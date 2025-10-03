# Runner Performance Guide

## Overview

This guide helps you measure, monitor, and optimize the performance of your self-hosted GitHub Actions runner.

## Running Benchmarks

### Quick Start

Run all benchmarks with default settings:

```powershell
.\scripts\benchmark-runner.ps1 -RunAll
```

### Custom Benchmarks

Run specific benchmark types:

```powershell
# Run only disk I/O and network tests
.\scripts\benchmark-runner.ps1 -BenchmarkTypes "diskio,network"

# Run with more iterations for accuracy
.\scripts\benchmark-runner.ps1 -RunAll -Iterations 5

# Specify custom output directory
.\scripts\benchmark-runner.ps1 -RunAll -OutputPath "C:\benchmark-results"
```

## Benchmark Types

### 1. Disk I/O Performance

**What it measures:**
- Large file write speed (100MB files)
- Large file read speed
- Small file operations (1000 files)

**Why it matters:**
- Build artifacts and dependencies require fast disk access
- Node modules, NuGet packages, and build outputs create many small files
- Slow disk I/O increases build times significantly

**Expected performance:**
- **Excellent:** >500 MB/s write (NVMe SSD)
- **Good:** 200-500 MB/s write (SATA SSD)
- **Adequate:** 100-200 MB/s write (older SSD)
- **Poor:** <100 MB/s write (HDD - not recommended)

### 2. Network Performance

**What it measures:**
- Latency to GitHub API
- Download speed from GitHub

**Why it matters:**
- Clone repositories and download dependencies
- Push build artifacts and test results
- API calls for workflow status updates

**Expected performance:**
- **Excellent:** <50ms latency to GitHub
- **Good:** 50-150ms latency
- **Adequate:** 150-300ms latency
- **Poor:** >300ms latency

**Optimization tips:**
- Use wired connection instead of Wi-Fi
- Consider runner location relative to GitHub data centers
- Use caching to minimize network operations

### 3. .NET Compilation

**What it measures:**
- Time to build a simple .NET console application

**Why it matters:**
- Measures .NET SDK performance
- Indicates CPU and disk performance for compilation tasks

**Expected performance:**
- **Excellent:** <2 seconds for simple project
- **Good:** 2-4 seconds
- **Adequate:** 4-6 seconds
- **Poor:** >6 seconds

**Requirements:**
- .NET SDK installed (any version)
- Skipped if .NET not available

### 4. Python Performance

**What it measures:**
- Python interpreter startup time
- Simple computation execution time

**Why it matters:**
- Many CI/CD tools use Python (pip-audit, detect-secrets, etc.)
- Fast Python startup reduces overhead for test runners

**Expected performance:**
- **Excellent:** <50ms startup time
- **Good:** 50-100ms startup time
- **Adequate:** 100-200ms startup time
- **Poor:** >200ms startup time

**Requirements:**
- Python 3.x installed
- Skipped if Python not available

### 5. Git Operations

**What it measures:**
- Repository clone time (small repository)
- Git status command time

**Why it matters:**
- Every workflow starts with git checkout
- Fast git operations reduce workflow startup time

**Expected performance:**
- **Excellent:** <5 seconds to clone github/gitignore
- **Good:** 5-10 seconds
- **Adequate:** 10-20 seconds
- **Poor:** >20 seconds

## Understanding Results

### Report Format

Benchmarks generate two report files:

1. **Markdown Report** (`benchmark-YYYYMMDD-HHmmss.md`)
   - Human-readable summary
   - Performance ratings
   - Recommendations for improvements

2. **JSON Report** (`benchmark-YYYYMMDD-HHmmss.json`)
   - Machine-readable data
   - Raw measurements for all iterations
   - Useful for tracking trends over time

### Interpreting Results

#### System Information
Check available memory and CPU specs to understand baseline capacity.

#### Performance Metrics
Each benchmark reports average values across multiple iterations:
- Lower variance between iterations = more consistent performance
- Check raw results in JSON for detailed analysis

#### Recommendations
The report includes actionable recommendations based on:
- Disk speed below thresholds
- High network latency
- Low available memory

## Baseline Performance Expectations

### Minimum Requirements for CI/CD

For typical GitHub Actions workflows:

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 2 cores | 4+ cores |
| RAM | 8 GB | 16+ GB |
| Disk | SATA SSD | NVMe SSD |
| Disk Write | 200 MB/s | 500+ MB/s |
| Network | 10 Mbps | 100+ Mbps |
| GitHub Latency | <300ms | <100ms |

### Performance by Workload Type

**Node.js Projects (npm/pnpm):**
- Disk I/O is critical (node_modules has thousands of small files)
- Expect 2-5x faster builds with NVMe vs SATA SSD

**Docker Builds:**
- Disk I/O and CPU are critical
- Network speed matters for base image pulls
- Consider local registry for frequently used images

**Python Projects:**
- Moderate disk I/O (fewer files than npm)
- CPU important for test execution
- Virtual environments benefit from fast disk

**.NET Projects:**
- CPU critical for compilation
- Moderate disk I/O for NuGet packages
- Good performance even on SATA SSD

## Performance Monitoring

### Regular Benchmarking

Run benchmarks periodically to track performance:

```powershell
# Weekly benchmark (automated via scheduled task)
.\scripts\benchmark-runner.ps1 -RunAll -OutputPath "C:\benchmark-history"
```

### Performance Regression Detection

Compare benchmark results over time:

1. Save baseline benchmark when runner is first set up
2. Run monthly benchmarks
3. Compare metrics to detect degradation
4. Investigate if performance drops >20%

**Common causes of performance regression:**
- Disk space running low (affects I/O)
- Background processes consuming resources
- Windows updates pending restart
- Antivirus scanning build directories

### Monitoring During Workflows

Key metrics to watch during actual workflow execution:

- **CPU usage:** Should stay below 80% on average
- **Memory usage:** Should have 2+ GB free during builds
- **Disk queue length:** Should stay below 10
- **Network saturation:** Should not max out bandwidth

Use Windows Performance Monitor or Resource Monitor to track these.

## Optimization Tips

### Disk Performance

1. **Use NVMe SSD if possible**
   - 3-5x faster than SATA SSD for small files
   - Critical for npm/pnpm workloads

2. **Exclude build directories from antivirus**
   - Add `node_modules`, `_work`, `.dotnet` to exclusions
   - Can improve performance by 20-30%

3. **Keep disk space free**
   - Maintain at least 20% free space
   - Set up automated cleanup (issue #5)

### Network Performance

1. **Use wired connection**
   - More stable and faster than Wi-Fi
   - Reduces failed downloads

2. **Configure caching**
   - Use GitHub Actions cache for dependencies
   - Consider local package cache/mirror

3. **Optimize git operations**
   - Use shallow clones when possible
   - Enable git sparse-checkout for large repos

### CPU/Memory Performance

1. **Close unnecessary applications**
   - Free up RAM for build processes
   - Reduce CPU contention

2. **Configure job concurrency**
   - Limit parallel jobs based on CPU cores
   - 1-2 jobs per CPU core is typical

3. **Use build caching**
   - Cache compiled outputs
   - Incremental builds when possible

## Troubleshooting Performance Issues

### Slow Builds

**Symptoms:** Builds taking 2x+ longer than expected

**Diagnosis:**
1. Run benchmark to identify bottleneck
2. Compare to baseline performance
3. Check system resources during build

**Solutions:**
- Disk slow: Upgrade to faster SSD
- Network slow: Check connection, use caching
- CPU slow: Reduce parallel jobs, upgrade hardware

### Inconsistent Performance

**Symptoms:** Build times vary significantly between runs

**Diagnosis:**
1. Check for background processes
2. Monitor resource usage during builds
3. Review Windows scheduled tasks

**Solutions:**
- Disable Windows Search indexing on work directories
- Schedule Windows Updates for off-hours
- Move background tasks to different schedule

### Out of Memory Errors

**Symptoms:** Builds fail with OOM errors

**Diagnosis:**
1. Check available RAM in benchmark
2. Monitor memory during build
3. Identify memory-heavy build steps

**Solutions:**
- Increase system RAM
- Reduce parallel jobs
- Use node --max-old-space-size for Node.js builds
- Split large builds into smaller jobs

## GitHub Actions Workflow Integration

### Scheduled Benchmarking

Create `.github/workflows/benchmark.yml`:

```yaml
name: Runner Performance Benchmark

on:
  schedule:
    # Run weekly on Sunday at 2 AM
    - cron: '0 2 * * 0'
  workflow_dispatch:

jobs:
  benchmark:
    runs-on: self-hosted

    steps:
      - uses: actions/checkout@v4

      - name: Run Benchmarks
        shell: pwsh
        run: |
          .\scripts\benchmark-runner.ps1 -RunAll -Iterations 5

      - name: Upload Results
        uses: actions/upload-artifact@v4
        with:
          name: benchmark-results
          path: benchmark-reports/
          retention-days: 90
```

### Performance Regression Detection

Add to existing workflows:

```yaml
- name: Quick Performance Check
  if: github.event_name == 'pull_request'
  shell: pwsh
  run: |
    # Quick benchmark before running tests
    .\scripts\benchmark-runner.ps1 -BenchmarkTypes "diskio" -Iterations 1
```

## Advanced Topics

### Comparing Multiple Runners

If you have multiple self-hosted runners:

1. Run benchmarks on each runner
2. Save results with runner-specific names
3. Compare JSON files to identify best performer
4. Route workflows to fastest runner using labels

### Performance Metrics Database

For long-term tracking:

1. Collect JSON benchmark results
2. Import into database or spreadsheet
3. Create charts showing trends
4. Alert on performance degradation

### Custom Benchmarks

Extend `benchmark-runner.ps1` for workload-specific tests:

- Unity build simulation
- Large dataset processing
- Containerized builds
- Multi-stage pipelines

## Resources

- [GitHub Actions Runner Documentation](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Windows Performance Monitoring](https://docs.microsoft.com/en-us/windows-server/administration/performance-tuning/)
- [SSD Performance Guide](https://www.crucial.com/articles/about-ssd/ssd-performance-factors)

## Related Documentation

- [Runner Setup Guide](../README.md) - Initial runner installation
- [Maintenance Guide](./upgrade-guide.md) - Regular maintenance procedures
- [Troubleshooting Guide](./troubleshooting.md) - Common issues and solutions
