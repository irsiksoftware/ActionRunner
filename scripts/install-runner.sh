#!/bin/bash

#############################################################################
# GitHub Actions Self-Hosted Runner Installation Script (Linux/macOS)
#
# This script automates the installation and configuration of a GitHub
# Actions self-hosted runner on Linux and macOS systems.
#
# Features:
# - Prerequisites validation (Git, curl, disk space)
# - Latest runner download and installation
# - Runner configuration with organization/repository access
# - Optional systemd service setup (Linux)
# - Optional launchd service setup (macOS)
# - Firewall configuration assistance
# - Comprehensive error handling and logging
#
# Usage:
#   ./install-runner.sh --org-or-repo <org/repo> --token <ghp_xxx> [options]
#
# Examples:
#   # Organization-level runner with service
#   ./install-runner.sh --org-or-repo "myorg" --token "ghp_xxx" --is-org --install-service
#
#   # Repository-level runner
#   ./install-runner.sh --org-or-repo "owner/repo" --token "ghp_xxx"
#
# Requirements:
#   - Linux: Ubuntu 20.04+, RHEL 8+, or compatible
#   - macOS: 11.0+ (Big Sur or later)
#   - 8GB+ RAM, 50GB+ free disk space
#   - sudo access for service installation
#
# See docs/hardware-specs.md for recommended specifications
# GitHub documentation: https://docs.github.com/en/actions/hosting-your-own-runners
#############################################################################

set -e

# ============================================================================
# CONFIGURATION DEFAULTS
# ============================================================================

ORG_OR_REPO=""
TOKEN=""
RUNNER_NAME="${HOSTNAME}"
LABELS="self-hosted,linux,dotnet,python,docker"
WORK_FOLDER="${HOME}/actions-runner"
CACHE_FOLDER="${HOME}/actions-runner-cache"
IS_ORG=false
INSTALL_SERVICE=false
SKIP_PREREQUISITES=false
SKIP_FIREWALL=false
LOG_FILE="/tmp/runner-install-$(date +%Y%m%d-%H%M%S).log"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Color codes
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_message="[$timestamp] [$level] $message"

    case $level in
        ERROR)
            echo -e "${RED}${log_message}${NC}" >&2
            ;;
        WARN)
            echo -e "${YELLOW}${log_message}${NC}"
            ;;
        SUCCESS)
            echo -e "${GREEN}${log_message}${NC}"
            ;;
        INFO)
            echo -e "${WHITE}${log_message}${NC}"
            ;;
    esac

    echo "$log_message" >> "$LOG_FILE"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Required:
  --org-or-repo <value>    GitHub organization or repository (e.g., 'myorg' or 'owner/repo')
  --token <value>          GitHub Personal Access Token (PAT) with admin:org or repo permissions

Optional:
  --runner-name <value>    Custom runner name (default: hostname)
  --labels <value>         Comma-separated labels (default: self-hosted,linux,dotnet,python,docker)
  --work-folder <value>    Working directory (default: ~/actions-runner)
  --cache-folder <value>   Cache directory (default: ~/actions-runner-cache)
  --is-org                 Configure as organization-level runner
  --install-service        Install as system service (systemd/launchd)
  --skip-prerequisites     Skip prerequisites validation (not recommended)
  --skip-firewall          Skip firewall configuration
  --help                   Show this help message

Examples:
  $0 --org-or-repo "myorg" --token "ghp_xxx" --is-org --install-service
  $0 --org-or-repo "owner/repo" --token "ghp_xxx" --labels "self-hosted,linux,docker"

EOF
    exit 0
}

# ============================================================================
# COMMAND-LINE PARSING
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --org-or-repo)
            ORG_OR_REPO="$2"
            shift 2
            ;;
        --token)
            TOKEN="$2"
            shift 2
            ;;
        --runner-name)
            RUNNER_NAME="$2"
            shift 2
            ;;
        --labels)
            LABELS="$2"
            shift 2
            ;;
        --work-folder)
            WORK_FOLDER="$2"
            shift 2
            ;;
        --cache-folder)
            CACHE_FOLDER="$2"
            shift 2
            ;;
        --is-org)
            IS_ORG=true
            shift
            ;;
        --install-service)
            INSTALL_SERVICE=true
            shift
            ;;
        --skip-prerequisites)
            SKIP_PREREQUISITES=true
            shift
            ;;
        --skip-firewall)
            SKIP_FIREWALL=true
            shift
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

# Validate required parameters
if [[ -z "$ORG_OR_REPO" ]] || [[ -z "$TOKEN" ]]; then
    echo "Error: --org-or-repo and --token are required"
    usage
fi

# ============================================================================
# PREREQUISITE CHECKS
# ============================================================================

check_prerequisites() {
    log INFO "Validating prerequisites..."
    local errors=0

    # Detect OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS_TYPE="linux"
        log SUCCESS "Operating System: Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS_TYPE="macos"
        log SUCCESS "Operating System: macOS"
    else
        log ERROR "Unsupported operating system: $OSTYPE"
        ((errors++))
    fi

    # Check architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        RUNNER_ARCH="x64"
        log SUCCESS "Architecture: x86_64"
    elif [[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "arm64" ]]; then
        RUNNER_ARCH="arm64"
        log SUCCESS "Architecture: ARM64"
    else
        log ERROR "Unsupported architecture: $ARCH"
        ((errors++))
    fi

    # Check bash version
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        log WARN "Bash 4.0+ recommended (current: ${BASH_VERSION})"
    else
        log SUCCESS "Bash version: ${BASH_VERSION}"
    fi

    # Check Git
    if command -v git &> /dev/null; then
        GIT_VERSION=$(git --version)
        log SUCCESS "Git installed: $GIT_VERSION"
    else
        log ERROR "Git is not installed"
        ((errors++))
    fi

    # Check curl
    if command -v curl &> /dev/null; then
        CURL_VERSION=$(curl --version | head -n1)
        log SUCCESS "curl installed: $CURL_VERSION"
    else
        log ERROR "curl is not installed"
        ((errors++))
    fi

    # Check tar
    if command -v tar &> /dev/null; then
        log SUCCESS "tar is available"
    else
        log ERROR "tar is not installed"
        ((errors++))
    fi

    # Check disk space
    AVAILABLE_SPACE=$(df -BG "$HOME" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [[ "$AVAILABLE_SPACE" -lt 50 ]]; then
        log ERROR "Insufficient disk space. Required: 50GB, Available: ${AVAILABLE_SPACE}GB"
        ((errors++))
    else
        log SUCCESS "Available disk space: ${AVAILABLE_SPACE}GB"
    fi

    # Check RAM
    if [[ "$OS_TYPE" == "linux" ]]; then
        TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
    else
        TOTAL_RAM=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
    fi

    if [[ "$TOTAL_RAM" -lt 8 ]]; then
        log WARN "Low RAM. Recommended: 32GB+, Minimum: 8GB, Available: ${TOTAL_RAM}GB"
    else
        log SUCCESS "Total RAM: ${TOTAL_RAM}GB"
    fi

    # Check internet connectivity
    if curl -s --max-time 10 https://api.github.com > /dev/null; then
        log SUCCESS "Internet connectivity to GitHub: OK"
    else
        log ERROR "Cannot reach GitHub API. Check internet connection."
        ((errors++))
    fi

    if [[ $errors -gt 0 ]]; then
        log ERROR "Prerequisites validation failed with $errors error(s)"
        return 1
    fi

    log SUCCESS "All prerequisites validated successfully"
    return 0
}

# ============================================================================
# RUNNER INSTALLATION
# ============================================================================

install_runner() {
    log INFO "Starting runner installation..."

    # Create work folders
    for folder in "$WORK_FOLDER" "$CACHE_FOLDER"; do
        if [[ ! -d "$folder" ]]; then
            log INFO "Creating folder: $folder"
            mkdir -p "$folder"
        else
            log WARN "Folder already exists: $folder"
        fi
    done

    cd "$WORK_FOLDER"

    # Download latest runner
    log INFO "Fetching latest runner version from GitHub..."

    RELEASE_DATA=$(curl -s https://api.github.com/repos/actions/runner/releases/latest)
    VERSION=$(echo "$RELEASE_DATA" | grep -o '"tag_name": *"[^"]*"' | sed 's/.*"v\(.*\)".*/\1/')

    if [[ -z "$VERSION" ]]; then
        log ERROR "Failed to fetch runner version"
        exit 1
    fi

    # Determine download URL based on OS and architecture
    if [[ "$OS_TYPE" == "linux" ]]; then
        DOWNLOAD_FILE="actions-runner-linux-${RUNNER_ARCH}-${VERSION}.tar.gz"
    else
        DOWNLOAD_FILE="actions-runner-osx-${RUNNER_ARCH}-${VERSION}.tar.gz"
    fi

    DOWNLOAD_URL="https://github.com/actions/runner/releases/download/v${VERSION}/${DOWNLOAD_FILE}"

    log INFO "Downloading runner version $VERSION..."
    log INFO "URL: $DOWNLOAD_URL"

    if ! curl -L -o "$DOWNLOAD_FILE" "$DOWNLOAD_URL"; then
        log ERROR "Failed to download runner"
        exit 1
    fi

    log SUCCESS "Download completed successfully"

    # Verify download
    FILE_SIZE=$(du -h "$DOWNLOAD_FILE" | cut -f1)
    log INFO "Downloaded file size: $FILE_SIZE"

    # Extract runner
    log INFO "Extracting runner package..."

    if [[ -d "./bin" ]]; then
        log WARN "Runner binaries already exist, removing old installation..."
        rm -rf ./bin ./externals
    fi

    if ! tar xzf "$DOWNLOAD_FILE"; then
        log ERROR "Failed to extract runner"
        exit 1
    fi

    log SUCCESS "Extraction completed successfully"

    # Verify extraction
    if [[ ! -f "./config.sh" ]]; then
        log ERROR "Runner extraction incomplete - config.sh not found"
        exit 1
    fi

    # Make scripts executable
    chmod +x ./config.sh ./run.sh

    # Cleanup downloaded archive
    rm -f "$DOWNLOAD_FILE"
    log INFO "Cleaned up installation files"

    echo "$VERSION"
}

# ============================================================================
# RUNNER REGISTRATION
# ============================================================================

register_runner() {
    local version=$1

    log INFO "Configuring runner registration..."

    # Validate token format
    if [[ ! "$TOKEN" =~ ^(ghp_|github_pat_) ]]; then
        log ERROR "Invalid token format. Token should start with 'ghp_' or 'github_pat_'"
        exit 1
    fi

    # Determine runner URL
    if [[ "$IS_ORG" == true ]]; then
        TOKEN_URL="https://api.github.com/orgs/${ORG_OR_REPO}/actions/runners/registration-token"
        RUNNER_URL="https://github.com/${ORG_OR_REPO}"
        log INFO "Configuring as organization-level runner for: $ORG_OR_REPO"
    else
        TOKEN_URL="https://api.github.com/repos/${ORG_OR_REPO}/actions/runners/registration-token"
        RUNNER_URL="https://github.com/${ORG_OR_REPO}"
        log INFO "Configuring as repository-level runner for: $ORG_OR_REPO"
    fi

    # Get registration token from GitHub API
    log INFO "Requesting registration token from GitHub..."

    RESPONSE=$(curl -s -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "$TOKEN_URL")

    REGISTRATION_TOKEN=$(echo "$RESPONSE" | grep -o '"token": *"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')

    if [[ -z "$REGISTRATION_TOKEN" ]]; then
        log ERROR "Failed to get registration token"
        log ERROR "Response: $RESPONSE"
        log ERROR "Ensure your token has correct permissions:"
        log ERROR "  - For organizations: admin:org scope"
        log ERROR "  - For repositories: repo scope"
        exit 1
    fi

    log SUCCESS "Successfully obtained registration token"

    # Configure runner
    log INFO "Configuring runner with the following settings:"
    log INFO "  Runner Name: $RUNNER_NAME"
    log INFO "  Labels: $LABELS"
    log INFO "  Work Folder: ${WORK_FOLDER}/_work"
    log INFO "  Runner URL: $RUNNER_URL"

    log INFO "Executing runner configuration..."

    ./config.sh \
        --url "$RUNNER_URL" \
        --token "$REGISTRATION_TOKEN" \
        --name "$RUNNER_NAME" \
        --labels "$LABELS" \
        --work "_work" \
        --unattended \
        --replace

    if [[ $? -ne 0 ]]; then
        log ERROR "Runner configuration failed"
        exit 1
    fi

    log SUCCESS "Runner configured successfully"
}

# ============================================================================
# SERVICE INSTALLATION
# ============================================================================

install_service() {
    log INFO "Installing runner as system service..."

    if [[ "$OS_TYPE" == "linux" ]]; then
        install_systemd_service
    else
        install_launchd_service
    fi
}

install_systemd_service() {
    log INFO "Installing systemd service (Linux)..."

    # Check for sudo
    if [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
        log ERROR "sudo access required for service installation"
        log ERROR "Please run with sudo or omit --install-service"
        exit 1
    fi

    # Install service
    sudo ./svc.sh install

    if [[ $? -ne 0 ]]; then
        log ERROR "Service installation failed"
        exit 1
    fi

    log INFO "Starting runner service..."
    sudo ./svc.sh start

    if [[ $? -ne 0 ]]; then
        log ERROR "Service start failed"
        exit 1
    fi

    # Verify service
    sleep 2
    if sudo ./svc.sh status | grep -q "active (running)"; then
        log SUCCESS "Runner service installed and running"
    else
        log WARN "Service installed but status verification failed"
    fi
}

install_launchd_service() {
    log INFO "Installing launchd service (macOS)..."

    # Install service
    ./svc.sh install

    if [[ $? -ne 0 ]]; then
        log ERROR "Service installation failed"
        exit 1
    fi

    log INFO "Starting runner service..."
    ./svc.sh start

    if [[ $? -ne 0 ]]; then
        log ERROR "Service start failed"
        exit 1
    fi

    log SUCCESS "Runner service installed and started"
}

# ============================================================================
# FIREWALL CONFIGURATION
# ============================================================================

configure_firewall() {
    log INFO "Firewall configuration guidance..."

    if [[ "$OS_TYPE" == "linux" ]]; then
        log INFO "For Linux firewall configuration, allow outbound HTTPS (port 443) to GitHub IP ranges:"
        log INFO "  - 140.82.112.0/20"
        log INFO "  - 143.55.64.0/20"
        log INFO "  - 185.199.108.0/22"
        log INFO "  - 192.30.252.0/22"
        log INFO ""
        log INFO "Example with ufw:"
        log INFO "  sudo ufw allow out 443/tcp"
        log INFO ""
        log INFO "Example with iptables:"
        log INFO "  sudo iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT"
    else
        log INFO "For macOS firewall configuration, ensure outbound connections are allowed"
        log INFO "System Preferences > Security & Privacy > Firewall > Firewall Options"
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

echo -e "\n${CYAN}========================================"
echo "GitHub Actions Runner Installation"
echo -e "========================================${NC}\n"

log INFO "Installation log: $LOG_FILE"
log INFO "Started at: $(date '+%Y-%m-%d %H:%M:%S')"

# Check prerequisites
if [[ "$SKIP_PREREQUISITES" == false ]]; then
    if ! check_prerequisites; then
        log ERROR "Prerequisites check failed. Use --skip-prerequisites to bypass (not recommended)"
        exit 1
    fi
else
    log WARN "Skipping prerequisites check (not recommended)"
fi

# Check sudo for service installation
if [[ "$INSTALL_SERVICE" == true ]] && [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
    log ERROR "Service installation requires sudo access"
    log ERROR "Please run with sudo or omit --install-service"
    exit 1
fi

# Install runner
VERSION=$(install_runner)

# Register runner
register_runner "$VERSION"

# Install as service
if [[ "$INSTALL_SERVICE" == true ]]; then
    install_service
else
    log INFO "Runner configured but not installed as service"
    log INFO "To run the runner manually: ./run.sh"
    log INFO "To install as service later: sudo ./svc.sh install"
fi

# Configure firewall
if [[ "$SKIP_FIREWALL" == false ]]; then
    configure_firewall
fi

# Display success message
echo -e "\n${GREEN}========================================"
echo "INSTALLATION COMPLETE!"
echo -e "========================================${NC}\n"

log INFO "Runner Name: $RUNNER_NAME"
log INFO "Labels: $LABELS"
log INFO "Work Folder: $WORK_FOLDER"
log INFO "Cache Folder: $CACHE_FOLDER"
log INFO "Runner URL: https://github.com/$ORG_OR_REPO"

# Display next steps
echo -e "\n${CYAN}=== NEXT STEPS ===${NC}"
echo -e "${WHITE}1. Verify runner status:${NC}"
echo -e "${GRAY}   https://github.com/$ORG_OR_REPO/settings/actions/runners${NC}"
echo -e "\n${WHITE}2. Update your workflows to use self-hosted runner:${NC}"
echo -e "${GRAY}   runs-on: [self-hosted, linux, <your-labels>]${NC}"
echo -e "\n${WHITE}3. Monitor runner logs:${NC}"
echo -e "${GRAY}   tail -f ${WORK_FOLDER}/_diag/Runner_*.log${NC}"
echo -e "\n${WHITE}4. Set up workspace cleanup (recommended):${NC}"
echo -e "${GRAY}   See docs/installation.md for automation scripts${NC}"
echo -e "\n${WHITE}5. Review security and configuration:${NC}"
echo -e "${GRAY}   See docs/troubleshooting.md for detailed guidance${NC}"
echo ""

log INFO "Installation log saved to: $LOG_FILE"
log SUCCESS "Completed at: $(date '+%Y-%m-%d %H:%M:%S')"

exit 0
