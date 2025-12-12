#!/bin/bash
#############################################################################
# BATS Test Framework Setup Script
#
# This script installs BATS (Bash Automated Testing System) and its
# helper libraries for testing shell scripts in the ActionRunner repository.
#
# Usage:
#   ./setup.sh [--prefix PATH]
#
# Options:
#   --prefix PATH    Installation prefix (default: /usr/local)
#   --help           Show this help message
#
#############################################################################

set -e

# Default values
PREFIX="/usr/local"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_HELPER_DIR="$SCRIPT_DIR/test_helper"
TEMP_DIR="$(mktemp -d)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Install BATS and helper libraries for shell script testing.

Options:
  --prefix PATH    Installation prefix (default: /usr/local)
  --help           Show this help message

Example:
  $0
  $0 --prefix /usr/local

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Cleanup on exit
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "========================================="
echo "BATS Framework Setup"
echo "========================================="
echo ""

# Check prerequisites
log_info "Checking prerequisites..."

if ! command -v git &> /dev/null; then
    log_error "git is not installed. Please install git and try again."
    exit 1
fi

if ! command -v bash &> /dev/null; then
    log_error "bash is not installed."
    exit 1
fi

BASH_VERSION_MAJOR="${BASH_VERSINFO[0]}"
if [[ "$BASH_VERSION_MAJOR" -lt 4 ]]; then
    log_warn "Bash 4.0+ recommended. Current: ${BASH_VERSION}"
fi

log_info "Prerequisites check passed"
echo ""

# Install BATS core
log_info "Installing BATS core..."

cd "$TEMP_DIR"

if ! git clone --depth 1 https://github.com/bats-core/bats-core.git; then
    log_error "Failed to clone bats-core repository"
    exit 1
fi

cd bats-core

# Check if we need sudo
if [[ -w "$PREFIX" ]]; then
    ./install.sh "$PREFIX"
else
    if command -v sudo &> /dev/null; then
        log_warn "Installing to $PREFIX requires sudo"
        sudo ./install.sh "$PREFIX"
    else
        log_error "Cannot write to $PREFIX and sudo is not available"
        log_error "Either run with sudo or specify --prefix to a writable location"
        exit 1
    fi
fi

# Verify BATS installation
if command -v bats &> /dev/null; then
    log_info "BATS installed successfully: $(bats --version)"
else
    log_error "BATS installation failed"
    exit 1
fi

echo ""

# Install helper libraries
log_info "Installing BATS helper libraries..."

mkdir -p "$TEST_HELPER_DIR"
cd "$TEST_HELPER_DIR"

# Install bats-support
if [[ -d "bats-support" ]]; then
    log_warn "bats-support already exists, updating..."
    cd bats-support
    git pull
    cd ..
else
    log_info "Cloning bats-support..."
    git clone --depth 1 https://github.com/bats-core/bats-support.git
fi

# Install bats-assert
if [[ -d "bats-assert" ]]; then
    log_warn "bats-assert already exists, updating..."
    cd bats-assert
    git pull
    cd ..
else
    log_info "Cloning bats-assert..."
    git clone --depth 1 https://github.com/bats-core/bats-assert.git
fi

# Install bats-file
if [[ -d "bats-file" ]]; then
    log_warn "bats-file already exists, updating..."
    cd bats-file
    git pull
    cd ..
else
    log_info "Cloning bats-file..."
    git clone --depth 1 https://github.com/bats-core/bats-file.git
fi

log_info "Helper libraries installed successfully"
echo ""

# Create common.bash helper
log_info "Creating common test helper..."

cat > "$TEST_HELPER_DIR/common.bash" << 'EOF'
#!/bin/bash
# Common test helper functions for BATS tests

# Load environment variables from .env if it exists
load_env() {
    if [[ -f "$BATS_TEST_DIRNAME/.env" ]]; then
        set -a
        source "$BATS_TEST_DIRNAME/.env"
        set +a
    fi
}

# Create a stub for an external command
stub_command() {
    local cmd="$1"
    local output="${2:-}"
    local exit_code="${3:-0}"

    mkdir -p "$BATS_TEST_TMPDIR/bin"

    cat > "$BATS_TEST_TMPDIR/bin/$cmd" << STUB_EOF
#!/bin/bash
echo "$output"
exit $exit_code
STUB_EOF

    chmod +x "$BATS_TEST_TMPDIR/bin/$cmd"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

# Remove a command stub
unstub_command() {
    local cmd="$1"
    rm -f "$BATS_TEST_TMPDIR/bin/$cmd"
}

# Mock a file
mock_file() {
    local file_path="$1"
    local content="${2:-}"

    mkdir -p "$(dirname "$file_path")"
    echo "$content" > "$file_path"
}

# Skip test if not running on Linux
skip_if_not_linux() {
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        skip "Test only runs on Linux"
    fi
}

# Skip test if not running on macOS
skip_if_not_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        skip "Test only runs on macOS"
    fi
}

# Skip test if not running as root
skip_if_not_root() {
    if [[ $EUID -ne 0 ]]; then
        skip "Test requires root access"
    fi
}

# Skip test if command not available
skip_if_command_missing() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        skip "$cmd is not installed"
    fi
}

# Assert file contains text
assert_file_contains() {
    local file="$1"
    local text="$2"

    if ! grep -q "$text" "$file"; then
        echo "File $file does not contain: $text"
        echo "Contents:"
        cat "$file"
        return 1
    fi
}

# Assert file does not contain text
assert_file_not_contains() {
    local file="$1"
    local text="$2"

    if grep -q "$text" "$file"; then
        echo "File $file should not contain: $text"
        echo "Contents:"
        cat "$file"
        return 1
    fi
}

# Set up a fake git repository
setup_fake_git_repo() {
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "test" > README.md
    git add README.md
    git commit -m "Initial commit"
}

# Mock GitHub API response
mock_github_api() {
    local endpoint="$1"
    local response="$2"

    stub_command "curl" "$response"
}
EOF

log_info "Common helper created"
echo ""

# Verification
echo "========================================="
echo "Installation Complete!"
echo "========================================="
echo ""

log_info "Verifying installation..."
echo ""

echo "BATS version:"
bats --version
echo ""

echo "Helper libraries installed:"
for lib in bats-support bats-assert bats-file; do
    if [[ -d "$TEST_HELPER_DIR/$lib" ]]; then
        echo "  ✓ $lib"
    else
        echo "  ✗ $lib (missing)"
    fi
done
echo ""

log_info "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Review the README: tests/shell/README.md"
echo "  2. Run tests: cd tests/shell && ./run-tests.sh"
echo "  3. Write new tests following examples in *.bats files"
echo ""
