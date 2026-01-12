#!/bin/bash
# Docker Integration Tests for Linux Hardening & Compliance Scanner
# This script tests the scanner functionality within Docker containers

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCANNER_IMAGE="linux-scanner-test"
TEST_RESULTS_DIR="./test-results"
REPORTS_DIR="./reports"

# Create directories
mkdir -p "$TEST_RESULTS_DIR"
mkdir -p "$REPORTS_DIR"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_failure() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

run_test() {
    local test_name="$1"
    local test_command="$2"

    ((TESTS_RUN++))
    log_info "Running test: $test_name"

    if eval "$test_command"; then
        log_success "$test_name"
        return 0
    else
        log_failure "$test_name"
        return 1
    fi
}

# ========================================
# Test Functions
# ========================================

test_docker_build() {
    log_info "Testing Docker image build..."

    # Build test image
    if docker build -t "$SCANNER_IMAGE" -f Dockerfile . --target test-env; then
        log_success "Docker image built successfully"
        return 0
    else
        log_failure "Docker image build failed"
        return 1
    fi
}

test_scanner_help() {
    run_test "Scanner help command" \
        "docker run --rm $SCANNER_IMAGE ./scanner.sh --help > /dev/null"
}

test_scanner_version() {
    run_test "Scanner version command" \
        "docker run --rm $SCANNER_IMAGE ./scanner.sh --version > /dev/null"
}

test_module_loading() {
    run_test "Module loading verification" \
        "docker run --rm $SCANNER_IMAGE bash -c 'ls modules/*.sh | wc -l' | grep -q '3'"
}

test_filesystem_scan() {
    log_info "Testing filesystem scan..."

    local container_name="test-scan-$(date +%s)"
    local result_file="$TEST_RESULTS_DIR/filesystem_scan_$(date +%s).txt"

    # Run scan in container
    if docker run --name "$container_name" --rm -v "$(pwd)/$TEST_RESULTS_DIR:/opt/scanner/results" \
        "$SCANNER_IMAGE" ./scanner.sh filesystem -q -o "/opt/scanner/results/$(basename "$result_file")" 2>/dev/null; then

        # Check if result file was created
        if [[ -f "$result_file" ]]; then
            log_success "Filesystem scan completed and result file created"
            return 0
        else
            log_failure "Filesystem scan completed but no result file found"
            return 1
        fi
    else
        log_failure "Filesystem scan failed to execute"
        return 1
    fi
}

test_webapp_startup() {
    log_info "Testing web application startup..."

    local container_name="test-webapp-$(date +%s)"

    # Start webapp in background
    docker run -d --name "$container_name" --rm -p 5001:5000 "$SCANNER_IMAGE" python run_webapp.py

    # Wait for startup
    sleep 10

    # Test health endpoint
    if curl -f http://localhost:5001/api/scans/summary >/dev/null 2>&1; then
        log_success "Web application started successfully"
        docker stop "$container_name" >/dev/null 2>&1 || true
        return 0
    else
        log_failure "Web application failed to start or health check failed"
        docker stop "$container_name" >/dev/null 2>&1 || true
        docker logs "$container_name" || true
        return 1
    fi
}

test_bash_syntax() {
    log_info "Testing Bash script syntax..."

    local syntax_errors=0

    # Test main scanner script
    if bash -n scanner.sh; then
        log_success "scanner.sh syntax check passed"
    else
        log_failure "scanner.sh syntax check failed"
        ((syntax_errors++))
    fi

    # Test module scripts
    for module in modules/*.sh; do
        if [[ -f "$module" ]]; then
            if bash -n "$module"; then
                log_success "$(basename "$module") syntax check passed"
            else
                log_failure "$(basename "$module") syntax check failed"
                ((syntax_errors++))
            fi
        fi
    done

    return $((syntax_errors > 0 ? 1 : 0))
}

test_python_syntax() {
    log_info "Testing Python script syntax..."

    local syntax_errors=0

    # Test Python files
    for pyfile in app.py run_webapp.py; do
        if [[ -f "$pyfile" ]]; then
            if python3 -m py_compile "$pyfile"; then
                log_success "$pyfile syntax check passed"
            else
                log_failure "$pyfile syntax check failed"
                ((syntax_errors++))
            fi
        fi
    done

    return $((syntax_errors > 0 ? 1 : 0))
}

test_dependencies() {
    log_info "Testing dependency installation..."

    # Create a temporary container to test dependency installation
    local container_name="test-deps-$(date +%s)"

    if docker run --name "$container_name" --rm "$SCANNER_IMAGE" \
        bash -c "python3 -c 'import flask, werkzeug, jinja2; print(\"Dependencies OK\")'" >/dev/null 2>&1; then
        log_success "Python dependencies installed correctly"
        docker rm "$container_name" >/dev/null 2>&1 || true
        return 0
    else
        log_failure "Python dependencies not installed correctly"
        docker logs "$container_name" || true
        docker rm "$container_name" >/dev/null 2>&1 || true
        return 1
    fi
}

test_output_formats() {
    log_info "Testing output formats..."

    local container_name="test-output-$(date +%s)"
    local base_dir="/opt/scanner/test-output"

    # Test different output formats
    local formats=("text" "json" "csv")
    local format_errors=0

    for format in "${formats[@]}"; do
        local output_file="$TEST_RESULTS_DIR/test_output_$format.$(date +%s).$format"

        if docker run --name "$container_name" --rm \
            -v "$(pwd)/$TEST_RESULTS_DIR:$base_dir" \
            "$SCANNER_IMAGE" \
            ./scanner.sh filesystem -q -f "$format" -o "$base_dir/$(basename "$output_file")" 2>/dev/null; then

            if [[ -f "$output_file" ]]; then
                log_success "$format output format works"
            else
                log_failure "$format output format failed - no file created"
                ((format_errors++))
            fi
        else
            log_failure "$format output format failed - command error"
            ((format_errors++))
        fi

        # Clean up container
        docker rm "$container_name" >/dev/null 2>&1 || true
        local container_name="test-output-$(date +%s)"
    done

    return $((format_errors > 0 ? 1 : 0))
}

test_configuration_files() {
    log_info "Testing configuration file structure..."

    local config_errors=0
    local expected_configs=("CIS-Level1.json" "CIS-Level2.json" "Custom-Profile.json" "NIST-800-53.json" "PCI-DSS.json")

    for config in "${expected_configs[@]}"; do
        if [[ -f "config/$config" ]]; then
            log_success "Configuration file $config exists"
        else
            log_failure "Configuration file $config missing"
            ((config_errors++))
        fi
    done

    # Test JSON syntax (even if empty)
    for config in config/*.json; do
        if [[ -f "$config" ]]; then
            if [[ -s "$config" ]]; then
                if python3 -m json.tool "$config" >/dev/null 2>&1; then
                    log_success "$(basename "$config") JSON syntax is valid"
                else
                    log_failure "$(basename "$config") JSON syntax is invalid"
                    ((config_errors++))
                fi
            else
                log_success "$(basename "$config") exists (empty JSON file)"
            fi
        fi
    done

    return $((config_errors > 0 ? 1 : 0))
}

# ========================================
# Main Test Execution
# ========================================

main() {
    log_info "Starting Docker Integration Tests for Linux Security Scanner"
    log_info "Test results will be saved to: $TEST_RESULTS_DIR"
    echo

    # Basic setup tests
    test_docker_build
    echo

    # Scanner functionality tests
    test_scanner_help
    test_scanner_version
    test_module_loading
    echo

    # Scan execution tests
    test_filesystem_scan
    echo

    # Web application tests
    test_webapp_startup
    echo

    # Syntax and dependency tests
    test_bash_syntax
    echo

    test_python_syntax
    echo

    test_dependencies
    echo

    test_output_formats
    echo

    test_configuration_files
    echo

    # ========================================
    # Test Summary
    # ========================================

    echo "========================================="
    echo "  Docker Integration Test Results"
    echo "========================================="
    echo "Tests Run:    $TESTS_RUN"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    echo

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed! ✅"
        echo
        log_info "Scanner is ready for deployment in Docker containers."
        echo
        echo "Next steps:"
        echo "  1. Push Docker images to registry"
        echo "  2. Deploy using docker-compose"
        echo "  3. Configure production environment"
        echo "  4. Set up monitoring and logging"
        echo
        exit 0
    else
        log_failure "Some tests failed. Please review the errors above."
        echo
        log_info "Common issues:"
        echo "  - Check Docker installation and permissions"
        echo "  - Verify scanner.sh has execute permissions"
        echo "  - Review Docker build logs for errors"
        echo "  - Check network connectivity for curl tests"
        echo
        exit 1
    fi
}

# Run main function
main "$@"
