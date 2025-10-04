#!/bin/bash
#
# Builds the multi-Python Docker image for containerized GitHub Actions workflows on Linux.
#
# Usage:
#   ./build-python-image-linux.sh [OPTIONS]
#
# Options:
#   --registry REGISTRY   Push to registry (e.g., "ghcr.io/dakotairsik")
#   --tag TAG            Image tag (default: "latest")
#   --no-build           Skip build, only push existing image
#   --help               Show this help message
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Default values
IMAGE_NAME="runner-python-multi"
TAG="latest"
REGISTRY=""
NO_BUILD=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        --tag)
            TAG="$2"
            shift 2
            ;;
        --no-build)
            NO_BUILD=true
            shift
            ;;
        --help)
            echo "Usage: ./build-python-image-linux.sh [OPTIONS]"
            echo ""
            echo "Builds a multi-Python Docker image with versions 3.9-3.12"
            echo ""
            echo "Options:"
            echo "  --registry REGISTRY   Push to registry (e.g., 'ghcr.io/dakotairsik')"
            echo "  --tag TAG            Image tag (default: 'latest')"
            echo "  --no-build           Skip build, only push existing image"
            echo "  --help               Show this help message"
            echo ""
            echo "Examples:"
            echo "  ./build-python-image-linux.sh"
            echo "  ./build-python-image-linux.sh --registry ghcr.io/dakotairsik --tag v1.0"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Run with --help for usage"
            exit 1
            ;;
    esac
done

# Determine full image name
if [[ -n "$REGISTRY" ]]; then
    FULL_IMAGE_NAME="$REGISTRY/$IMAGE_NAME:$TAG"
    LOCAL_IMAGE_NAME="$IMAGE_NAME:$TAG"
else
    FULL_IMAGE_NAME="$IMAGE_NAME:$TAG"
    LOCAL_IMAGE_NAME="$FULL_IMAGE_NAME"
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DOCKERFILE_PATH="$REPO_DIR/docker/Dockerfile.python-multi-linux"
BUILD_CONTEXT="$REPO_DIR/docker"

echo -e "${CYAN}=== Python Multi-Version Docker Image Builder (Linux) ===${NC}"
echo ""

# Verify Docker is running
echo -e "${YELLOW}Checking Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Install Docker and try again"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker is not running${NC}"
    echo "Start Docker and try again"
    exit 1
fi

echo -e "${GREEN}✓ Docker is running${NC}"

# Build image
if [[ "$NO_BUILD" == false ]]; then
    echo ""
    echo -e "${YELLOW}Building image: $LOCAL_IMAGE_NAME${NC}"
    echo -e "${GRAY}Dockerfile: $DOCKERFILE_PATH${NC}"
    echo -e "${GRAY}This will take 5-10 minutes (downloading base image + installing Python versions)...${NC}"
    echo ""

    if [[ ! -f "$DOCKERFILE_PATH" ]]; then
        echo -e "${RED}Error: Dockerfile not found at $DOCKERFILE_PATH${NC}"
        exit 1
    fi

    docker build \
        -t "$LOCAL_IMAGE_NAME" \
        -f "$DOCKERFILE_PATH" \
        "$BUILD_CONTEXT"

    echo ""
    echo -e "${GREEN}✓ Image built successfully: $LOCAL_IMAGE_NAME${NC}"
fi

# Tag for registry if needed
if [[ -n "$REGISTRY" ]] && [[ "$LOCAL_IMAGE_NAME" != "$FULL_IMAGE_NAME" ]]; then
    echo ""
    echo -e "${YELLOW}Tagging image for registry...${NC}"
    docker tag "$LOCAL_IMAGE_NAME" "$FULL_IMAGE_NAME"
    echo -e "${GREEN}✓ Tagged as: $FULL_IMAGE_NAME${NC}"
fi

# Push to registry
if [[ -n "$REGISTRY" ]]; then
    echo ""
    echo -e "${YELLOW}Pushing to registry: $REGISTRY${NC}"
    echo -e "${GRAY}Image: $FULL_IMAGE_NAME${NC}"
    echo ""

    if docker push "$FULL_IMAGE_NAME"; then
        echo ""
        echo -e "${GREEN}✓ Image pushed successfully!${NC}"
        echo ""
        echo -e "${CYAN}Use in workflows with:${NC}"
        echo -e "${NC}  container:"
        echo -e "${NC}    image: $FULL_IMAGE_NAME"
    else
        echo ""
        echo -e "${RED}Failed to push image${NC}"
        echo ""
        echo -e "${YELLOW}If you haven't logged in, run:${NC}"
        echo -e "${NC}  docker login $REGISTRY"
        exit 1
    fi
fi

# Show image info
echo ""
echo -e "${CYAN}=== Image Information ===${NC}"
docker images "$LOCAL_IMAGE_NAME" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

echo ""
echo -e "${CYAN}=== Test the Image ===${NC}"
echo -e "${YELLOW}Run verification:${NC}"
echo -e "${NC}  docker run --rm $LOCAL_IMAGE_NAME"
echo ""
echo -e "${YELLOW}Test Python 3.10:${NC}"
echo -e "${NC}  docker run --rm $LOCAL_IMAGE_NAME python3.10 --version"
echo ""
echo -e "${YELLOW}Interactive shell:${NC}"
echo -e "${NC}  docker run --rm -it $LOCAL_IMAGE_NAME"

echo ""
echo -e "${GREEN}✓ Build complete!${NC}"
