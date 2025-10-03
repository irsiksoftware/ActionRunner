#!/bin/bash

#############################################################################
# Jesus Project Development Stack Installation Script
#
# This script installs the full development stack required for the Jesus
# MCP Agentic AI Platform project on a GitHub Actions self-hosted runner.
#
# Stack Components:
# - Node.js 20.x with pnpm 9.x
# - Python 3.11 with pip, pip-audit, detect-secrets
# - Docker Engine with BuildKit support
# - OSV Scanner for security scanning
#
# Requirements:
#   - Ubuntu 20.04+ or Debian 11+ (other distros may work with modifications)
#   - sudo access
#   - Internet connectivity
#   - 100GB+ free disk space (500GB+ recommended)
#
# Usage:
#   sudo ./install-runner-devstack.sh [options]
#
# Options:
#   --skip-nodejs      Skip Node.js installation
#   --skip-python      Skip Python installation
#   --skip-docker      Skip Docker installation
#   --skip-security    Skip security tools installation
#   --help             Show this help message
#
# Example:
#   sudo ./install-runner-devstack.sh
#   sudo ./install-runner-devstack.sh --skip-docker
#
#############################################################################

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

SKIP_NODEJS=false
SKIP_PYTHON=false
SKIP_DOCKER=false
SKIP_SECURITY=false
LOG_FILE="/tmp/devstack-install-$(date +%Y%m%d-%H%M%S).log"

# Versions
NODEJS_VERSION="20"
PNPM_VERSION="9"
PYTHON_VERSION="3.11"

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

This script installs the full development stack for the Jesus MCP Agentic AI Platform.

Options:
  --skip-nodejs       Skip Node.js 20.x and pnpm 9.x installation
  --skip-python       Skip Python 3.11 installation
  --skip-docker       Skip Docker Engine installation
  --skip-security     Skip security tools (OSV Scanner, pip-audit, detect-secrets)
  --help              Show this help message

Example:
  sudo $0
  sudo $0 --skip-docker

EOF
    exit 0
}

# ============================================================================
# COMMAND-LINE PARSING
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-nodejs)
            SKIP_NODEJS=true
            shift
            ;;
        --skip-python)
            SKIP_PYTHON=true
            shift
            ;;
        --skip-docker)
            SKIP_DOCKER=true
            shift
            ;;
        --skip-security)
            SKIP_SECURITY=true
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

# ============================================================================
# PREREQUISITE CHECKS
# ============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log ERROR "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_os() {
    log INFO "Detecting operating system..."

    if [[ ! -f /etc/os-release ]]; then
        log ERROR "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi

    . /etc/os-release

    log INFO "OS: $NAME $VERSION"

    case "$ID" in
        ubuntu)
            OS_FAMILY="ubuntu"
            if [[ "${VERSION_ID}" < "20.04" ]]; then
                log WARN "Ubuntu 20.04+ recommended. Current: $VERSION_ID"
            fi
            ;;
        debian)
            OS_FAMILY="debian"
            if [[ "${VERSION_ID}" < "11" ]]; then
                log WARN "Debian 11+ recommended. Current: $VERSION_ID"
            fi
            ;;
        *)
            log WARN "Untested OS: $ID. Proceeding with Ubuntu/Debian assumptions."
            OS_FAMILY="debian"
            ;;
    esac
}

check_disk_space() {
    log INFO "Checking disk space..."
    AVAILABLE_SPACE=$(df -BG /home | awk 'NR==2 {print $4}' | sed 's/G//')

    if [[ "$AVAILABLE_SPACE" -lt 100 ]]; then
        log ERROR "Insufficient disk space. Required: 100GB+, Available: ${AVAILABLE_SPACE}GB"
        exit 1
    else
        log SUCCESS "Available disk space: ${AVAILABLE_SPACE}GB"
    fi
}

# ============================================================================
# NODE.JS INSTALLATION
# ============================================================================

install_nodejs() {
    log INFO "Installing Node.js ${NODEJS_VERSION}.x..."

    # Check if Node.js is already installed
    if command -v node &> /dev/null; then
        CURRENT_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$CURRENT_VERSION" == "$NODEJS_VERSION" ]]; then
            log SUCCESS "Node.js ${NODEJS_VERSION}.x already installed: $(node --version)"
            return 0
        else
            log WARN "Node.js version mismatch. Current: v${CURRENT_VERSION}, Required: v${NODEJS_VERSION}"
            log INFO "Installing Node.js ${NODEJS_VERSION}.x..."
        fi
    fi

    # Install prerequisites
    apt-get update -qq
    apt-get install -y -qq curl ca-certificates gnupg

    # Add NodeSource repository
    log INFO "Adding NodeSource repository..."
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
        gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODEJS_VERSION}.x nodistro main" | \
        tee /etc/apt/sources.list.d/nodesource.list

    # Install Node.js
    apt-get update -qq
    apt-get install -y -qq nodejs

    # Verify installation
    if command -v node &> /dev/null; then
        log SUCCESS "Node.js installed: $(node --version)"
    else
        log ERROR "Node.js installation failed"
        exit 1
    fi
}

install_pnpm() {
    log INFO "Installing pnpm ${PNPM_VERSION}.x..."

    # Check if pnpm is already installed
    if command -v pnpm &> /dev/null; then
        CURRENT_VERSION=$(pnpm --version | cut -d'.' -f1)
        if [[ "$CURRENT_VERSION" == "$PNPM_VERSION" ]]; then
            log SUCCESS "pnpm ${PNPM_VERSION}.x already installed: $(pnpm --version)"
            return 0
        else
            log INFO "Upgrading pnpm to version ${PNPM_VERSION}.x..."
        fi
    fi

    # Install pnpm globally
    npm install -g pnpm@${PNPM_VERSION}

    # Verify installation
    if command -v pnpm &> /dev/null; then
        log SUCCESS "pnpm installed: $(pnpm --version)"

        # Configure pnpm cache
        log INFO "Configuring pnpm cache directory..."
        mkdir -p /home/actions-runner/.pnpm-store
        chown -R actions-runner:actions-runner /home/actions-runner/.pnpm-store 2>/dev/null || true

    else
        log ERROR "pnpm installation failed"
        exit 1
    fi
}

# ============================================================================
# PYTHON INSTALLATION
# ============================================================================

install_python() {
    log INFO "Installing Python ${PYTHON_VERSION}..."

    # Check if Python 3.11 is already installed
    if command -v python3.11 &> /dev/null; then
        log SUCCESS "Python 3.11 already installed: $(python3.11 --version)"
    else
        # Add deadsnakes PPA for Python 3.11
        log INFO "Adding deadsnakes PPA..."
        apt-get update -qq
        apt-get install -y -qq software-properties-common
        add-apt-repository -y ppa:deadsnakes/ppa
        apt-get update -qq

        # Install Python 3.11
        log INFO "Installing Python 3.11 packages..."
        apt-get install -y -qq python3.11 python3.11-venv python3.11-dev python3-pip

        # Verify installation
        if command -v python3.11 &> /dev/null; then
            log SUCCESS "Python installed: $(python3.11 --version)"
        else
            log ERROR "Python 3.11 installation failed"
            exit 1
        fi
    fi

    # Set Python 3.11 as default python3
    log INFO "Setting Python 3.11 as default..."
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 || true

    # Verify pip
    if command -v pip &> /dev/null; then
        log SUCCESS "pip installed: $(pip --version)"
    else
        log WARN "pip not found, attempting to install..."
        apt-get install -y -qq python3-pip
    fi
}

install_python_security_tools() {
    log INFO "Installing Python security tools..."

    # Install pip-audit
    log INFO "Installing pip-audit..."
    pip install --quiet pip-audit

    # Install detect-secrets
    log INFO "Installing detect-secrets..."
    pip install --quiet detect-secrets

    # Verify installations
    if command -v pip-audit &> /dev/null; then
        log SUCCESS "pip-audit installed: $(pip-audit --version 2>&1 | head -n1)"
    else
        log ERROR "pip-audit installation failed"
    fi

    if command -v detect-secrets &> /dev/null; then
        log SUCCESS "detect-secrets installed: $(detect-secrets --version 2>&1 | head -n1)"
    else
        log ERROR "detect-secrets installation failed"
    fi
}

# ============================================================================
# DOCKER INSTALLATION
# ============================================================================

install_docker() {
    log INFO "Installing Docker Engine with BuildKit support..."

    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        log SUCCESS "Docker already installed: $(docker --version)"

        # Check BuildKit support
        if docker buildx version &> /dev/null; then
            log SUCCESS "Docker BuildKit already available: $(docker buildx version | head -n1)"
            return 0
        fi
    fi

    # Remove old versions
    log INFO "Removing old Docker versions (if any)..."
    apt-get remove -y -qq docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Install prerequisites
    apt-get update -qq
    apt-get install -y -qq \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker GPG key
    log INFO "Adding Docker GPG key..."
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    log INFO "Adding Docker repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    apt-get update -qq
    log INFO "Installing Docker packages..."
    apt-get install -y -qq \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    # Verify installation
    if command -v docker &> /dev/null; then
        log SUCCESS "Docker installed: $(docker --version)"
    else
        log ERROR "Docker installation failed"
        exit 1
    fi

    if docker buildx version &> /dev/null; then
        log SUCCESS "Docker BuildKit installed: $(docker buildx version | head -n1)"
    else
        log ERROR "Docker BuildKit installation failed"
        exit 1
    fi

    # Enable BuildKit by default
    log INFO "Enabling BuildKit in Docker daemon..."
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << 'EOF'
{
  "features": {
    "buildkit": true
  }
}
EOF

    # Add runner user to docker group
    log INFO "Adding runner user to docker group..."
    if id "actions-runner" &>/dev/null; then
        usermod -aG docker actions-runner
        log SUCCESS "User 'actions-runner' added to docker group"
    else
        log WARN "User 'actions-runner' not found. You may need to add the runner user to docker group manually."
    fi

    # Enable and start Docker
    systemctl enable docker
    systemctl restart docker

    log SUCCESS "Docker configured and started"
}

# ============================================================================
# SECURITY TOOLS INSTALLATION
# ============================================================================

install_osv_scanner() {
    log INFO "Installing OSV Scanner..."

    # Check if already installed
    if command -v osv-scanner &> /dev/null; then
        log SUCCESS "OSV Scanner already installed: $(osv-scanner --version 2>&1 | head -n1)"
        return 0
    fi

    # Detect architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        OSV_ARCH="amd64"
    elif [[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "arm64" ]]; then
        OSV_ARCH="arm64"
    else
        log ERROR "Unsupported architecture for OSV Scanner: $ARCH"
        return 1
    fi

    # Download OSV Scanner
    log INFO "Downloading OSV Scanner for ${OSV_ARCH}..."
    OSV_URL="https://github.com/google/osv-scanner/releases/latest/download/osv-scanner_linux_${OSV_ARCH}"

    curl -Lo /tmp/osv-scanner "$OSV_URL"
    chmod +x /tmp/osv-scanner
    mv /tmp/osv-scanner /usr/local/bin/osv-scanner

    # Verify installation
    if command -v osv-scanner &> /dev/null; then
        log SUCCESS "OSV Scanner installed: $(osv-scanner --version 2>&1 | head -n1)"
    else
        log ERROR "OSV Scanner installation failed"
        return 1
    fi
}

# ============================================================================
# VERIFICATION
# ============================================================================

verify_installation() {
    log INFO "Verifying installation..."
    local errors=0

    echo -e "\n${CYAN}=== Installation Verification ===${NC}\n"

    # Node.js
    if [[ "$SKIP_NODEJS" == false ]]; then
        if command -v node &> /dev/null; then
            echo -e "${GREEN}✓ Node.js:${NC} $(node --version)"
        else
            echo -e "${RED}✗ Node.js: Not found${NC}"
            ((errors++))
        fi

        if command -v pnpm &> /dev/null; then
            echo -e "${GREEN}✓ pnpm:${NC} $(pnpm --version)"
        else
            echo -e "${RED}✗ pnpm: Not found${NC}"
            ((errors++))
        fi
    fi

    # Python
    if [[ "$SKIP_PYTHON" == false ]]; then
        if command -v python3.11 &> /dev/null; then
            echo -e "${GREEN}✓ Python 3.11:${NC} $(python3.11 --version)"
        else
            echo -e "${RED}✗ Python 3.11: Not found${NC}"
            ((errors++))
        fi

        if command -v pip &> /dev/null; then
            echo -e "${GREEN}✓ pip:${NC} $(pip --version | cut -d' ' -f1-2)"
        else
            echo -e "${RED}✗ pip: Not found${NC}"
            ((errors++))
        fi
    fi

    # Docker
    if [[ "$SKIP_DOCKER" == false ]]; then
        if command -v docker &> /dev/null; then
            echo -e "${GREEN}✓ Docker:${NC} $(docker --version | cut -d',' -f1)"
        else
            echo -e "${RED}✗ Docker: Not found${NC}"
            ((errors++))
        fi

        if docker buildx version &> /dev/null; then
            echo -e "${GREEN}✓ Docker BuildKit:${NC} $(docker buildx version | head -n1 | cut -d' ' -f1-2)"
        else
            echo -e "${RED}✗ Docker BuildKit: Not found${NC}"
            ((errors++))
        fi
    fi

    # Security Tools
    if [[ "$SKIP_SECURITY" == false ]]; then
        if command -v osv-scanner &> /dev/null; then
            echo -e "${GREEN}✓ OSV Scanner:${NC} Installed"
        else
            echo -e "${YELLOW}⚠ OSV Scanner: Not found${NC}"
        fi

        if command -v pip-audit &> /dev/null; then
            echo -e "${GREEN}✓ pip-audit:${NC} Installed"
        else
            echo -e "${YELLOW}⚠ pip-audit: Not found${NC}"
        fi

        if command -v detect-secrets &> /dev/null; then
            echo -e "${GREEN}✓ detect-secrets:${NC} Installed"
        else
            echo -e "${YELLOW}⚠ detect-secrets: Not found${NC}"
        fi
    fi

    echo ""

    if [[ $errors -gt 0 ]]; then
        log ERROR "Verification failed with $errors critical error(s)"
        return 1
    else
        log SUCCESS "All components verified successfully"
        return 0
    fi
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

echo -e "\n${CYAN}========================================================================"
echo "Jesus Project Development Stack Installation"
echo "======================================================================${NC}\n"

log INFO "Installation log: $LOG_FILE"
log INFO "Started at: $(date '+%Y-%m-%d %H:%M:%S')"

# Check prerequisites
check_root
check_os
check_disk_space

# Install components
if [[ "$SKIP_NODEJS" == false ]]; then
    install_nodejs
    install_pnpm
else
    log INFO "Skipping Node.js installation"
fi

if [[ "$SKIP_PYTHON" == false ]]; then
    install_python
    if [[ "$SKIP_SECURITY" == false ]]; then
        install_python_security_tools
    fi
else
    log INFO "Skipping Python installation"
fi

if [[ "$SKIP_DOCKER" == false ]]; then
    install_docker
else
    log INFO "Skipping Docker installation"
fi

if [[ "$SKIP_SECURITY" == false ]]; then
    install_osv_scanner
else
    log INFO "Skipping security tools installation"
fi

# Verify installation
verify_installation

# Display success message
echo -e "\n${GREEN}========================================================================"
echo "INSTALLATION COMPLETE!"
echo "======================================================================${NC}\n"

# Display next steps
echo -e "${CYAN}=== NEXT STEPS ===${NC}\n"
echo -e "${WHITE}1. Restart your shell or log out and back in for group changes to take effect${NC}"
echo -e "${GRAY}   (Required if Docker was installed)${NC}"
echo -e "\n${WHITE}2. Verify the runner user has docker access:${NC}"
echo -e "${GRAY}   su - actions-runner${NC}"
echo -e "${GRAY}   docker ps${NC}"
echo -e "\n${WHITE}3. Configure runner labels to include:${NC}"
echo -e "${GRAY}   self-hosted, linux, nodejs, python, docker${NC}"
echo -e "\n${WHITE}4. Update Jesus project workflows:${NC}"
echo -e "${GRAY}   runs-on: [self-hosted, linux, nodejs, python, docker]${NC}"
echo -e "\n${WHITE}5. Test the setup:${NC}"
echo -e "${GRAY}   node --version  # Should be v20.x${NC}"
echo -e "${GRAY}   pnpm --version  # Should be 9.x${NC}"
echo -e "${GRAY}   python3 --version  # Should be 3.11.x${NC}"
echo -e "${GRAY}   docker --version${NC}"
echo -e "${GRAY}   docker buildx version${NC}"
echo ""

log INFO "Installation log saved to: $LOG_FILE"
log SUCCESS "Completed at: $(date '+%Y-%m-%d %H:%M:%S')"

exit 0
