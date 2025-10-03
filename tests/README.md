# Test Suite for GitHub Actions Runner Security Setup

This directory contains comprehensive Pester tests for validating the security configuration scripts and YAML files.

## Test Coverage

### 1. register-runner.Tests.ps1
Tests for the runner registration script (`scripts/register-runner.ps1`):

- **Parameter Validation**: Verifies script accepts organization/repo, token, and optional parameters
- **Token Format**: Tests validation of GitHub PAT format (ghp_ and github_pat_ prefixes)
- **Default Values**: Tests default runner name, labels, and work folder
- **Label Validation**: Validates custom and default label configurations
- **URL Construction**: Tests GitHub URL construction for orgs and repos
- **API Interaction**: Validates GitHub API calls for runner registration
- **Error Handling**: Tests graceful handling of API failures and missing assets
- **Service Installation**: Validates admin privilege checks and service setup
- **Cleanup**: Tests removal of temporary installation files
- **Logging**: Validates logging with timestamps and severity levels

### 2. runner-user-setup.Tests.ps1
Tests for the service account setup script (`config/runner-user-setup.ps1`):

- **Parameter Validation**: Verifies script accepts default and custom parameters
- **Security Functions**: Tests secure password generation and complexity requirements
- **DryRun Mode**: Ensures no changes are made in dry-run mode
- **Prerequisites**: Validates admin privileges and PowerShell version checks
- **Error Handling**: Confirms proper error handling and exit codes
- **File System Operations**: Tests directory creation and ACL configuration
- **Service Configuration**: Validates service account assignment
- **Integration**: Full end-to-end dry-run execution

### 3. apply-firewall-rules.Tests.ps1
Tests for the firewall configuration script (`config/apply-firewall-rules.ps1`):

- **Parameter Validation**: Validates ConfigFile, RemoveExisting, and DryRun parameters
- **DryRun Mode**: Ensures no firewall rules are created/modified in dry-run
- **Security Rules**: Validates implementation of defense-in-depth rules:
  - Default deny inbound
  - DNS, HTTPS, Windows Update, NTP outbound allow rules
  - Default deny outbound for all other traffic
- **Firewall Logging**: Tests logging configuration for all profiles
- **Error Handling**: Validates admin privilege requirements
- **Rule Management**: Tests removal of existing rules
- **Integration**: Full script execution in dry-run mode

### 4. firewall-rules-config.Tests.ps1
Tests for the YAML configuration file (`config/firewall-rules.yaml`):

- **File Structure**: Validates YAML syntax and required sections
- **Inbound Rules**:
  - Default deny policy
  - RDP/SSH/WinRM disabled by default
  - IP restriction configuration
- **Outbound Rules**:
  - Default deny policy
  - Essential services allowed (DNS, HTTPS, NTP, Windows Update)
  - GitHub IP ranges configuration
  - Package managers disabled by default
- **Logging**: Validates logging is enabled for dropped and allowed packets
- **Maintenance**: Checks maintenance schedules defined
- **Compliance**: Verifies references to NIST, CIS, SOC 2, ISO 27001
- **Defense in Depth**: Validates layered security approach
- **Documentation**: Ensures customization warnings and notes present

### 5. setup-docker.Tests.ps1
Tests for the Docker setup script (`scripts/setup-docker.ps1`):

- **Parameter Validation**: Verifies SkipInstall, ConfigureGPU, MaxCPUs, MaxMemoryGB parameters
- **Prerequisites**: Validates Docker Desktop installation checks
- **WSL2 Configuration**: Tests WSL2 enablement and configuration
- **Resource Limits**: Validates CPU and memory limit configuration
- **GPU Support**: Tests NVIDIA GPU detection and configuration
- **Container Images**: Validates building of Unity, Python, .NET, GPU images
- **Error Handling**: Confirms proper error handling for missing prerequisites
- **DryRun Mode**: Ensures no changes are made when appropriate

### 6. collect-logs.Tests.ps1
Tests for the log collection script (`scripts/collect-logs.ps1`):

- **Parameter Validation**: Verifies OutputPath, IncludeSystemLogs, DaysToCollect parameters
- **Log Collection**: Tests gathering logs from runner service, job execution, performance metrics
- **Windows Event Log**: Validates Event Log collection and filtering
- **Output Format**: Tests JSON output structure and file creation
- **Date Filtering**: Validates collection of logs within specified date range
- **Error Handling**: Tests handling of missing log directories or permission issues

### 7. rotate-logs.Tests.ps1
Tests for the log rotation script (`scripts/rotate-logs.ps1`):

- **Parameter Validation**: Verifies LogPath, RetentionDays, CompressAfterDays parameters
- **Compression**: Tests log file compression to ZIP archives
- **Archive Management**: Validates moving compressed logs to archive directory
- **Retention Policy**: Tests deletion of logs older than retention period
- **Archive Cleanup**: Validates deletion of old archives based on DeleteArchivesAfterDays
- **Disk Space**: Tests handling of low disk space scenarios

### 8. analyze-logs.Tests.ps1
Tests for the log analysis script (`scripts/analyze-logs.ps1`):

- **Parameter Validation**: Verifies LogPath, OutputFormat, DaysToAnalyze, GenerateReport parameters
- **Pattern Detection**: Tests identification of error patterns and anomalies
- **Job Statistics**: Validates calculation of success/failure rates
- **Performance Analysis**: Tests CPU, memory, and resource usage analysis
- **Report Generation**: Validates Console, JSON, and HTML output formats
- **Recommendations**: Tests generation of actionable insights

## Running the Tests

### Prerequisites

```powershell
# Check Pester version (3.4.0+ required)
Get-Module -ListAvailable Pester

# Install latest Pester if needed (PowerShell 5.0+)
Install-Module -Name Pester -Force -SkipPublisherCheck
```

### Run All Tests

```powershell
# Run all tests in the tests directory
Invoke-Pester -Path .\tests\

# Run with detailed output
Invoke-Pester -Path .\tests\ -Output Detailed

# Generate code coverage report
Invoke-Pester -Path .\tests\ -CodeCoverage .\config\*.ps1
```

### Run Individual Test Files

```powershell
# Test runner registration script
Invoke-Pester -Path .\tests\register-runner.Tests.ps1

# Test service account setup script
Invoke-Pester -Path .\tests\runner-user-setup.Tests.ps1

# Test firewall rules script
Invoke-Pester -Path .\tests\apply-firewall-rules.Tests.ps1

# Test YAML configuration
Invoke-Pester -Path .\tests\firewall-rules-config.Tests.ps1
```

### Run Specific Tests

```powershell
# Run only security-related tests
Invoke-Pester -Path .\tests\ -Tag Security

# Run only DryRun mode tests
Invoke-Pester -Path .\tests\ -Tag DryRun
```

## Test Output

Expected output format:
```
Describing apply-firewall-rules.ps1 Tests
  Context Parameter Validation
    [+] Should use default config file path 125ms
    [+] Should accept custom config file path 89ms
    [+] Should support RemoveExisting switch 45ms
    [+] Should support DryRun switch 38ms
  Context Security Rule Validation
    [+] Should implement default deny for inbound traffic 67ms
    [+] Should allow DNS outbound 52ms
    ...

Tests completed in 3.45s
Tests Passed: 87, Failed: 0, Skipped: 0
```

## CI/CD Integration

### GitHub Actions Workflow Example

```yaml
name: Security Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Pester Tests
        shell: powershell
        run: |
          Install-Module -Name Pester -Force -SkipPublisherCheck
          Invoke-Pester -Path .\tests\ -Output Detailed -CI

      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: testResults.xml
```

## Coverage Goals

- **Unit Tests**: 80%+ coverage of PowerShell functions
- **Integration Tests**: 100% coverage of script execution paths
- **Configuration Tests**: 100% validation of YAML structure

## Adding New Tests

When adding new security scripts or configurations:

1. Create a corresponding `.Tests.ps1` file
2. Include tests for:
   - Parameter validation
   - DryRun mode (if applicable)
   - Security controls
   - Error handling
   - Integration scenarios
3. Document the tests in this README
4. Run all tests before committing

## Security Testing Best Practices

1. **Never run tests with actual credentials** - Use mocks and dry-run mode
2. **Test in isolated environment** - Don't modify production firewall rules
3. **Validate security defaults** - Ensure deny-by-default is tested
4. **Test failure scenarios** - Not just happy paths
5. **Mock privileged operations** - Tests should not require admin rights (except where testing admin checks)

## Troubleshooting

### Common Issues

**Tests fail with "Administrator privileges required"**
- Some integration tests check for admin mode but should mock it
- Run tests in elevated PowerShell only when testing admin checks

**YAML parsing errors**
- Ensure `firewall-rules.yaml` exists in `config/` directory
- Check YAML syntax with online validator

**Pester version conflicts**
- Use Pester 5.x for best results
- Uninstall old versions: `Uninstall-Module Pester -AllVersions`

## Contributing

When contributing tests:
1. Follow existing test structure and naming conventions
2. Use descriptive test names that explain what is being tested
3. Include both positive and negative test cases
4. Document any external dependencies or prerequisites
5. Ensure tests are deterministic and don't depend on external state

## References

- [Pester Documentation](https://pester.dev/)
- [PowerShell Testing Best Practices](https://pester.dev/docs/usage/test-file-structure)
- [GitHub Actions Runner Security](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#self-hosted-runner-security)
