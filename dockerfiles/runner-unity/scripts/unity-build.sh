#!/bin/bash
# Unity Build Script for GitHub Actions
# Supports building Unity projects with various target platforms

set -e

# Default values
PROJECT_PATH="${UNITY_PROJECT_PATH:-.}"
BUILD_TARGET="${UNITY_BUILD_TARGET:-StandaloneLinux64}"
BUILD_PATH="${UNITY_BUILD_PATH:-./build}"
LOG_FILE="${UNITY_LOG_FILE:-/tmp/unity-build.log}"
UNITY_VERSION="${UNITY_VERSION:-2021.3.31f1}"
UNITY_EXECUTABLE="/opt/unity/${UNITY_VERSION}/Editor/Unity"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Unity license is activated
check_license() {
    log_info "Checking Unity license..."
    if [ ! -f "/root/.local/share/unity3d/Unity/Unity_lic.ulf" ] && \
       [ -z "$UNITY_LICENSE" ] && \
       [ -z "$UNITY_USERNAME" ]; then
        log_error "Unity license not found. Please provide license file or credentials."
        log_error "Mount license file: -v /path/to/Unity_lic.ulf:/root/.local/share/unity3d/Unity/Unity_lic.ulf"
        log_error "Or set environment variables: UNITY_USERNAME, UNITY_PASSWORD, UNITY_SERIAL"
        exit 1
    fi
    log_info "License check passed"
}

# Activate Unity license (if credentials provided)
activate_license() {
    if [ -n "$UNITY_USERNAME" ] && [ -n "$UNITY_PASSWORD" ] && [ -n "$UNITY_SERIAL" ]; then
        log_info "Activating Unity license..."
        xvfb-run --auto-servernum --server-args='-screen 0 1024x768x24' \
            "$UNITY_EXECUTABLE" \
            -batchmode \
            -nographics \
            -silent-crashes \
            -quit \
            -username "$UNITY_USERNAME" \
            -password "$UNITY_PASSWORD" \
            -serial "$UNITY_SERIAL" || {
            log_error "Failed to activate Unity license"
            exit 1
        }
        log_info "License activated successfully"
    fi
}

# Build Unity project
build_project() {
    log_info "Starting Unity build..."
    log_info "Project: $PROJECT_PATH"
    log_info "Target: $BUILD_TARGET"
    log_info "Output: $BUILD_PATH"

    # Create build directory
    mkdir -p "$BUILD_PATH"

    # Run Unity build
    xvfb-run --auto-servernum --server-args='-screen 0 1024x768x24' \
        "$UNITY_EXECUTABLE" \
        -batchmode \
        -nographics \
        -silent-crashes \
        -projectPath "$PROJECT_PATH" \
        -buildTarget "$BUILD_TARGET" \
        -executeMethod BuildScript.Build \
        -logFile "$LOG_FILE" \
        -quit || {
        log_error "Unity build failed. Check log file: $LOG_FILE"
        if [ -f "$LOG_FILE" ]; then
            tail -n 50 "$LOG_FILE"
        fi
        exit 1
    }

    log_info "Build completed successfully"
}

# Return Unity license (for floating licenses)
return_license() {
    if [ -n "$UNITY_USERNAME" ] && [ -n "$UNITY_PASSWORD" ]; then
        log_info "Returning Unity license..."
        xvfb-run --auto-servernum --server-args='-screen 0 1024x768x24' \
            "$UNITY_EXECUTABLE" \
            -batchmode \
            -quit \
            -returnlicense || {
            log_warn "Failed to return Unity license"
        }
    fi
}

# Main execution
main() {
    log_info "Unity Build Script v1.0"

    # Trap to ensure license is returned on exit
    trap return_license EXIT

    check_license
    activate_license
    build_project

    log_info "All operations completed successfully"
}

# Run main function
main "$@"
