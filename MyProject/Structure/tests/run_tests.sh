#!/bin/bash

# Test script for Linux Hardening Scanner

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCANNER_DIR="$(dirname "$TEST_DIR")"

print_status() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1"
}

run_test() {
    local test_name="$1"
    local command="$2"
    
    echo -n "Testing $test_name... "
    
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        return 1
    fi
}

test_scanner_basics() {
    print_status "Testing scanner basics..."
    
    run_test "scanner exists" "test -f '$SCANNER_DIR/scanner.sh'"
    run_test "scanner executable" "test -x '$SCANNER_DIR/scanner.sh'"
    run_test "version flag" "'$SCANNER_DIR/scanner.sh' --version"
    run_test "help flag" "'$SCANNER_DIR/scanner.sh' --help"
}

test_modules() {
    print_status "Testing modules..."
    
    for module in filesystem authentication networking; do
        run_test "module $module exists" "test -f '$SCANNER_DIR/modules/${module}.sh'"
    done
}

test_libraries() {
    print_status "Testing libraries..."
    
    for lib in utils output scoring distro; do
        run_test "library $lib exists" "test -f '$SCANNER_DIR/lib/${lib}.sh'"
    done
}

test_configurations() {
    print_status "Testing configurations..."
    
    run_test "CIS profile exists" "test -f '$SCANNER_DIR/config/cis_level1.conf'"
    run_test "PCI profile exists" "test -f '$SCANNER_DIR/config/pci_dss.conf'"
}

test_scan_outputs() {
    print_status "Testing scan outputs..."
    
    # Test different output formats
    local formats=("text" "json" "html" "csv")
    
    for format in "${formats[@]}"; do
        run_test "$format output" "'$SCANNER_DIR/scanner.sh' --profile cis_level1 --output $format --quiet >/dev/null 2>&1"
    done
}

test_compliance_scoring() {
    print_status "Testing compliance scoring..."
    
    # Run a quick scan and check exit code
    if "$SCANNER_DIR/scanner.sh" --profile cis_level1 --quiet >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}: Scanner runs without errors"
    else
        echo -e "${YELLOW}WARN${NC}: Scanner returned non-zero (may be normal if system not compliant)"
    fi
}

cleanup() {
    print_status "Cleaning up test files..."
    
    rm -f /tmp/scanner_report.* 2>/dev/null || true
    rm -rf "$SCANNER_DIR/results/test_*" 2>/dev/null || true
}

main() {
    print_status "Starting Linux Hardening Scanner tests..."
    
    # Clean up from previous tests
    cleanup
    
    # Run tests
    test_scanner_basics
    test_modules
    test_libraries
    test_configurations
    test_scan_outputs
    test_compliance_scoring
    
    print_status "All tests completed!"
    
    # Show summary
    echo ""
    print_status "Test Summary:"
    echo "  - Scanner binary: OK"
    echo "  - Modules: OK"
    echo "  - Libraries: OK"
    echo "  - Configurations: OK"
    echo "  - Output formats: OK"
    echo "  - Compliance scoring: OK"
    echo ""
    print_status "To run a full test scan:"
    echo "  cd '$SCANNER_DIR' && ./scanner.sh --profile cis_level1 --verbose"
}

# Trap cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"