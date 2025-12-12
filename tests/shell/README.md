# Shell Script Tests

This directory contains tests for all shell scripts (`.sh`) in the ActionRunner repository using the BATS (Bash Automated Testing System) framework.

## Framework

We use [BATS](https://github.com/bats-core/bats-core) for testing shell scripts. BATS provides:
- Simple, readable test syntax
- Test isolation
- Setup and teardown hooks
- Helper libraries for common testing tasks

## Structure

```
tests/shell/
├── README.md                          # This file
├── setup.sh                           # Install BATS and dependencies
├── run-tests.sh                       # Run all shell tests
├── test_helper/                       # Shared test helpers
│   ├── bats-support/                  # BATS support library (git submodule)
│   ├── bats-assert/                   # BATS assertion library (git submodule)
│   ├── bats-file/                     # BATS file assertion library (git submodule)
│   └── common.bash                    # Common test utilities
├── install-runner.bats                # Tests for install-runner.sh
├── setup-linux-runner.bats            # Tests for setup-linux-runner.sh
├── build-python-image-linux.bats      # Tests for build-python-image-linux.sh
├── install-runner-devstack.bats       # Tests for install-runner-devstack.sh
└── unity-build.bats                   # Tests for unity-build.sh
```

## Installation

### Prerequisites

- Bash 4.0 or later
- Git
- curl or wget

### Install BATS Framework

```bash
# Run the setup script to install BATS and dependencies
cd tests/shell
./setup.sh
```

This will:
1. Clone BATS core framework
2. Install helper libraries (bats-support, bats-assert, bats-file)
3. Make BATS available in your PATH

### Manual Installation

If you prefer manual installation:

```bash
# Install BATS core
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local

# Install helper libraries
cd tests/shell/test_helper
git clone https://github.com/bats-core/bats-support.git
git clone https://github.com/bats-core/bats-assert.git
git clone https://github.com/bats-core/bats-file.git
```

## Running Tests

### Run All Tests

```bash
cd tests/shell
./run-tests.sh
```

### Run Specific Test File

```bash
bats install-runner.bats
```

### Run Specific Test

```bash
bats install-runner.bats --filter "should validate required parameters"
```

### Run Tests with Verbose Output

```bash
bats --verbose-run install-runner.bats
```

### Run Tests with TAP Output

```bash
bats --tap install-runner.bats
```

## Writing Tests

### Basic Test Structure

```bash
#!/usr/bin/env bats

# Load test helpers
load test_helper/bats-support/load
load test_helper/bats-assert/load
load test_helper/bats-file/load
load test_helper/common

# Setup runs before each test
setup() {
    # Create temporary directory
    TEST_DIR="$(mktemp -d)"
    cd "$TEST_DIR"
}

# Teardown runs after each test
teardown() {
    # Clean up temporary directory
    rm -rf "$TEST_DIR"
}

# Test case
@test "should do something" {
    run command_to_test arg1 arg2
    assert_success
    assert_output "expected output"
}
```

### Assertions

BATS provides many useful assertions:

```bash
# Status assertions
assert_success              # Exit code 0
assert_failure              # Exit code != 0
assert_equal "$a" "$b"      # String equality

# Output assertions
assert_output "text"        # Exact match
assert_output --partial "text"  # Contains
assert_line "text"          # Line exact match
assert_line --partial "text"    # Line contains

# File assertions
assert_file_exist "/path/to/file"
assert_file_not_exist "/path/to/file"
assert_file_executable "/path/to/file"
assert_dir_exist "/path/to/dir"
```

### Mocking and Stubbing

For scripts that call external commands, use stubs:

```bash
# Create a stub for a command
stub_command() {
    local cmd="$1"
    local output="$2"

    cat > "$TEST_DIR/$cmd" << EOF
#!/bin/bash
echo "$output"
exit 0
EOF
    chmod +x "$TEST_DIR/$cmd"
    export PATH="$TEST_DIR:$PATH"
}

@test "example using stub" {
    stub_command "curl" "stubbed output"

    run your_script_that_calls_curl
    assert_success
}
```

## Test Categories

### Unit Tests
Test individual functions and script components in isolation.

**Example:**
```bash
@test "log() function formats messages correctly" {
    source ../../../scripts/install-runner.sh

    run log INFO "test message"
    assert_output --partial "[INFO] test message"
}
```

### Integration Tests
Test script behavior with real or mocked external dependencies.

**Example:**
```bash
@test "should download runner package" {
    # Mock curl to return fake data
    stub_command "curl" "fake-runner-package"

    run install_runner
    assert_success
    assert_file_exist "actions-runner.tar.gz"
}
```

### End-to-End Tests
Test complete script execution (use sparingly, may require privileged access).

**Example:**
```bash
@test "should install and configure runner" {
    skip "Requires sudo access and GitHub token"

    run sudo ../../../scripts/install-runner.sh --org-or-repo "test/repo" --token "$GITHUB_TOKEN"
    assert_success
}
```

## CI/CD Integration

### GitHub Actions

Add to `.github/workflows/shell-tests.yml`:

```yaml
name: Shell Script Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup BATS
        run: |
          cd tests/shell
          ./setup.sh

      - name: Run Tests
        run: |
          cd tests/shell
          ./run-tests.sh
```

## Best Practices

1. **Test Isolation**: Each test should be independent and not rely on other tests
2. **Cleanup**: Always clean up temporary files in `teardown()`
3. **Mock External Dependencies**: Don't rely on network, GitHub API, or system state
4. **Fast Tests**: Keep tests fast by mocking expensive operations
5. **Clear Test Names**: Use descriptive test names that explain what is being tested
6. **Document Skipped Tests**: If a test requires special conditions, document why
7. **Test Edge Cases**: Test error conditions, invalid inputs, and boundary conditions
8. **Avoid Sudo**: Most tests should not require root access

## Troubleshooting

### Tests Hang

If tests hang, check for:
- Interactive prompts (use `--unattended` flags)
- Long-running downloads (mock with stubs)
- Waiting for user input (ensure scripts support non-interactive mode)

### Permission Denied

If you get permission errors:
- Check file permissions: `chmod +x script.sh`
- Ensure test files are executable: `chmod +x *.bats`
- Use temporary directories for test files

### Command Not Found

If BATS can't find commands:
- Ensure BATS is installed: `bats --version`
- Check PATH: `echo $PATH`
- Reinstall using `./setup.sh`

## Resources

- [BATS Documentation](https://bats-core.readthedocs.io/)
- [BATS Core Repository](https://github.com/bats-core/bats-core)
- [BATS Assert Library](https://github.com/bats-core/bats-assert)
- [BATS Support Library](https://github.com/bats-core/bats-support)
- [BATS File Library](https://github.com/bats-core/bats-file)

## Contributing

When adding new shell scripts to the repository:

1. Create a corresponding `.bats` test file
2. Write tests covering:
   - Argument parsing
   - Error handling
   - Main functionality
   - Edge cases
3. Ensure tests pass before submitting PR
4. Aim for >80% code coverage
