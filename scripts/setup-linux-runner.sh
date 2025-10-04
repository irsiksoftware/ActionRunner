#!/bin/bash
#
# Setup script for self-hosted GitHub Actions runner on Linux
# Installs Docker, configures runner, and builds Python multi-version container
#
# Usage:
#   sudo ./setup-linux-runner.sh --repo-url https://github.com/USER/REPO --token YOUR_TOKEN
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
RUNNER_NAME="${HOSTNAME}-runner"
RUNNER_LABELS="self-hosted,linux,docker"
RUNNER_DIR="$HOME/actions-runner"
RUNNER_VERSION="2.311.0"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --repo-url)
            REPO_URL="$2"
            shift 2
            ;;
        --token)
            RUNNER_TOKEN="$2"
            shift 2
            ;;
        --name)
            RUNNER_NAME="$2"
            shift 2
            ;;
        --labels)
            RUNNER_LABELS="$2"
            shift 2
            ;;
        --help)
            echo "Usage: sudo ./setup-linux-runner.sh --repo-url URL --token TOKEN [OPTIONS]"
            echo ""
            echo "Required:"
            echo "  --repo-url URL    GitHub repository URL"
            echo "  --token TOKEN     Runner registration token"
            echo ""
            echo "Optional:"
            echo "  --name NAME       Runner name (default: hostname-runner)"
            echo "  --labels LABELS   Runner labels (default: self-hosted,linux,docker)"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Check required arguments
if [[ -z "$REPO_URL" ]] || [[ -z "$RUNNER_TOKEN" ]]; then
    echo -e "${RED}Error: --repo-url and --token are required${NC}"
    echo "Run with --help for usage information"
    exit 1
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root (use sudo)${NC}"
   exit 1
fi

echo -e "${CYAN}=== Linux Self-Hosted Runner Setup ===${NC}"
echo -e "${YELLOW}Repository: $REPO_URL${NC}"
echo -e "${YELLOW}Runner Name: $RUNNER_NAME${NC}"
echo -e "${YELLOW}Labels: $RUNNER_LABELS${NC}"
echo ""

# Step 1: Install Docker
echo -e "${CYAN}Step 1: Installing Docker...${NC}"

if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓ Docker already installed${NC}"
else
    echo "Installing Docker..."

    # Update package index
    apt-get update

    # Install prerequisites
    apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker's official GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # Set up the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker Engine
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Start Docker
    systemctl start docker
    systemctl enable docker

    echo -e "${GREEN}✓ Docker installed successfully${NC}"
fi

# Verify Docker
docker --version
echo -e "${GREEN}✓ Docker is running${NC}"

# Step 2: Create runner user (non-root for security)
echo ""
echo -e "${CYAN}Step 2: Creating runner user...${NC}"

if id "runner" &>/dev/null; then
    echo -e "${GREEN}✓ Runner user already exists${NC}"
else
    useradd -m -s /bin/bash runner
    usermod -aG docker runner
    echo -e "${GREEN}✓ Created runner user and added to docker group${NC}"
fi

# Step 3: Download and configure runner
echo ""
echo -e "${CYAN}Step 3: Setting up GitHub Actions runner...${NC}"

# Create runner directory
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

# Download runner if not already present
if [[ ! -f "$RUNNER_DIR/config.sh" ]]; then
    echo "Downloading runner version $RUNNER_VERSION..."
    curl -o actions-runner-linux-x64-$RUNNER_VERSION.tar.gz \
        -L https://github.com/actions/runner/releases/download/v$RUNNER_VERSION/actions-runner-linux-x64-$RUNNER_VERSION.tar.gz

    tar xzf actions-runner-linux-x64-$RUNNER_VERSION.tar.gz
    rm actions-runner-linux-x64-$RUNNER_VERSION.tar.gz

    echo -e "${GREEN}✓ Runner downloaded${NC}"
else
    echo -e "${GREEN}✓ Runner already downloaded${NC}"
fi

# Change ownership to runner user
chown -R runner:runner "$RUNNER_DIR"

# Configure runner as runner user
echo "Configuring runner..."
su - runner -c "cd $RUNNER_DIR && ./config.sh --url $REPO_URL --token $RUNNER_TOKEN --name $RUNNER_NAME --labels $RUNNER_LABELS --work _work --unattended"

echo -e "${GREEN}✓ Runner configured${NC}"

# Step 4: Install as systemd service
echo ""
echo -e "${CYAN}Step 4: Installing runner as systemd service...${NC}"

cd "$RUNNER_DIR"
./svc.sh install runner
./svc.sh start

echo -e "${GREEN}✓ Runner service installed and started${NC}"

# Step 5: Build Python multi-version Docker image
echo ""
echo -e "${CYAN}Step 5: Building Python multi-version Docker image...${NC}"

# Get the ActionRunner repo directory (assuming this script is in scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DOCKERFILE_PATH="$REPO_DIR/docker/Dockerfile.python-multi-linux"

if [[ -f "$DOCKERFILE_PATH" ]]; then
    echo "Building runner-python-multi:latest (this may take 10-15 minutes)..."
    docker build -t runner-python-multi:latest -f "$DOCKERFILE_PATH" "$REPO_DIR/docker/"

    echo -e "${GREEN}✓ Docker image built successfully${NC}"
else
    echo -e "${YELLOW}⚠ Dockerfile not found at $DOCKERFILE_PATH${NC}"
    echo -e "${YELLOW}  You can build it manually later with:${NC}"
    echo -e "${YELLOW}  docker build -t runner-python-multi:latest -f /path/to/Dockerfile.python-multi-linux .${NC}"
fi

# Final status
echo ""
echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo ""
echo "Runner Status:"
systemctl status actions.runner.* --no-pager
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo "1. Verify runner appears in GitHub: $REPO_URL/settings/actions/runners"
echo "2. Test the Python image:"
echo "   docker run --rm runner-python-multi:latest"
echo ""
echo "3. Update your workflows to use the containerized runner:"
echo "   runs-on: [self-hosted, linux, docker]"
echo "   container:"
echo "     image: runner-python-multi:latest"
echo ""
echo -e "${GREEN}✓ Your Linux runner is ready!${NC}"
