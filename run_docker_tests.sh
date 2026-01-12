#!/bin/bash
# Run Docker Tests for Linux Hardening & Compliance Scanner
# This script provides easy commands to test the scanner in Docker

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PROJECT_NAME="linux-scanner"
IMAGE_NAME="${PROJECT_NAME}:latest"
WEBAPP_IMAGE="${PROJECT_NAME}-webapp:latest"
CLI_IMAGE="${PROJECT_NAME}-cli:latest"
TEST_IMAGE="${PROJECT_NAME}-test:latest"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

show_usage() {
    cat << EOF
Linux Hardening & Compliance Scanner - Docker Test Runner

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    build           Build all Docker images
    test            Run comprehensive test suite
    webapp          Start web application only
    cli             Run CLI scanner
    integration     Run integration tests with multiple containers
    clean           Clean up Docker resources
    deploy          Deploy full stack locally
    help            Show this help message

OPTIONS:
    -v, --verbose   Enable verbose output
    -q, --quiet     Suppress output
    -h, --help      Show help

EXAMPLES:
    $0 build                    # Build all images
    $0 test                     # Run all tests
    $0 webapp                   # Start web interface
    $0 cli filesystem           # Run filesystem scan via CLI
    $0 integration              # Test with multiple containers
    $0 clean                    # Clean up everything

DOCKER IMAGES:
    ${PROJECT_NAME}-webapp      Web application with Flask UI
    ${PROJECT_NAME}-cli         Command-line scanner only
    ${PROJECT_NAME}-test        Testing environment

For more information, see README.md and WEBAPP_README.md
EOF
}

# Build Docker images
build_images() {
    log_info "Building Docker images..."

    # Build webapp image
    log_info "Building webapp image..."
    docker build -t "$WEBAPP_IMAGE" --target webapp .

    # Build CLI image
    log_info "Building CLI image..."
    docker build -t "$CLI_IMAGE" --target scanner-cli .

    # Build test image
    log_info "Building test image..."
    docker build -t "$TEST_IMAGE" --target test-env .

    log_success "All images built successfully!"
}

# Run comprehensive tests
run_tests() {
    log_info "Running comprehensive test suite..."

    # Build images first
    build_images

    # Run integration tests
    log_info "Running integration tests..."
    chmod +x tests/docker-integration-test.sh
    ./tests/docker-integration-test.sh
}

# Start web application
start_webapp() {
    log_info "Starting web application..."

    # Check if port 5000 is available
    if lsof -i :5000 >/dev/null 2>&1; then
        log_error "Port 5000 is already in use. Please stop other services or use a different port."
        exit 1
    fi

    # Create necessary directories
    mkdir -p results logs uploads

    # Start webapp
    log_info "Starting Flask web application on http://localhost:5000"
    log_info "Press Ctrl+C to stop"

    docker run --rm \
        -p 5000:5000 \
        -v "$(pwd)/results:/opt/scanner/results" \
        -v "$(pwd)/logs:/opt/scanner/logs" \
        -v "$(pwd)/uploads:/opt/scanner/uploads" \
        "$WEBAPP_IMAGE"
}

# Run CLI scanner
run_cli() {
    local scan_type="${1:-filesystem}"

    log_info "Running CLI scanner with profile: $scan_type"

    # Create results directory
    mkdir -p results

    # Run scanner
    docker run --rm \
        -v "$(pwd)/results:/opt/scanner/results" \
        "$CLI_IMAGE" \
        ./scanner.sh "$scan_type" -o "/opt/scanner/results/scan_$(date +%Y%m%d_%H%M%S).txt"

    log_success "Scan completed! Results saved to results/ directory"
}

# Run integration tests with multiple containers
run_integration() {
    log_info "Running integration tests with multiple containers..."

    # Start target systems
    log_info "Starting target systems..."
    docker-compose --profile target up -d target-ubuntu target-centos

    # Wait for targets to be ready
    sleep 5

    # Run scanner against targets
    log_info "Running scanner against target systems..."

    # Test Ubuntu target
    log_info "Testing Ubuntu target..."
    docker run --rm \
        --network linux-scanner-network \
        -v "$(pwd)/results:/opt/scanner/results" \
        "$CLI_IMAGE" \
        ./scanner.sh filesystem -q -o "/opt/scanner/results/ubuntu_scan_$(date +%Y%m%d_%H%M%S).txt"

    # Test CentOS target
    log_info "Testing CentOS target..."
    docker run --rm \
        --network linux-scanner-network \
        -v "$(pwd)/results:/opt/scanner/results" \
        "$CLI_IMAGE" \
        ./scanner.sh filesystem -q -o "/opt/scanner/results/centos_scan_$(date +%Y%m%d_%H%M%S).txt"

    # Clean up
    log_info "Cleaning up target systems..."
    docker-compose --profile target down

    log_success "Integration tests completed!"
}

# Deploy full stack locally
deploy_stack() {
    log_info "Deploying full scanner stack locally..."

    # Build images
    build_images

    # Start services
    log_info "Starting services..."
    docker-compose up -d

    log_success "Stack deployed successfully!"
    log_info "Web interface: http://localhost:5000"
    log_info "To stop: docker-compose down"
}

# Clean up Docker resources
cleanup() {
    log_info "Cleaning up Docker resources..."

    # Stop and remove containers
    docker-compose down -v --remove-orphans 2>/dev/null || true

    # Remove images
    docker rmi "$WEBAPP_IMAGE" "$CLI_IMAGE" "$TEST_IMAGE" 2>/dev/null || true

    # Remove dangling images
    docker image prune -f >/dev/null 2>&1 || true

    # Remove unused volumes
    docker volume prune -f >/dev/null 2>&1 || true

    # Clean up test results
    rm -rf test-results/ 2>/dev/null || true

    log_success "Cleanup completed!"
}

# Main command processing
main() {
    local command="${1:-help}"

    case "$command" in
        build)
            build_images
            ;;
        test)
            run_tests
            ;;
        webapp)
            start_webapp
            ;;
        cli)
            shift
            run_cli "$@"
            ;;
        integration)
            run_integration
            ;;
        deploy)
            deploy_stack
            ;;
        clean)
            cleanup
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            echo
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
