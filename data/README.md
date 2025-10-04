# Benchmark Baseline Data

This directory contains baseline performance metrics used for comparing runner benchmark results.

## Files

### benchmark-baseline.json

Contains reference performance thresholds for various benchmark categories:

- **DiskIO**: Minimum acceptable disk read/write speeds and file operation rates
- **Network**: Maximum acceptable latency and minimum download speeds
- **DotNet**: Maximum acceptable build times for simple projects
- **Python**: Maximum acceptable startup and execution times
- **Git**: Maximum acceptable clone and status operation times

## Usage

The baseline data is automatically loaded by `scripts/benchmark-runner.ps1` when generating reports. Benchmark results are compared against these thresholds to identify performance issues.

## Baseline Structure

```json
{
  "version": "1.0",
  "baselines": {
    "DiskIO": {
      "MinWriteSpeedMBps": 100,
      "MinReadSpeedMBps": 150,
      ...
    },
    ...
  },
  "performanceGrades": {
    "DiskIO": {
      "WriteSpeed": {
        "Excellent": 500,
        "Good": 200,
        ...
      }
    }
  }
}
```

## Updating Baselines

To update baseline thresholds:

1. Review current infrastructure capabilities
2. Run benchmarks on representative systems
3. Update `benchmark-baseline.json` with appropriate values
4. Run tests to validate: `Invoke-Pester tests/benchmark-baseline.Tests.ps1`

## Performance Grades

Performance grades help categorize results:

- **Excellent**: Exceeds typical requirements significantly
- **Good**: Meets typical CI/CD requirements well
- **Adequate**: Meets minimum acceptable thresholds
- **Poor**: Below minimum acceptable thresholds

## Notes

- Baselines are intentionally conservative to ensure broad compatibility
- Update baselines periodically based on infrastructure improvements
- Failed benchmark attempts (marked with -1 values) are excluded from baseline comparisons
