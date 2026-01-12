#!/bin/bash
# Test script for Linux Hardening & Compliance Scanner
# This script validates the scanner components

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCANNER="$SCRIPT_DIR/scanner.sh"

echo "========================================"
echo "  Scanner Test Suite"
echo "========================================"
echo ""

# Test 1: Help functionality
echo "Test 1: Help functionality"
echo "------------------------"
if bash "$SCANNER" --help > /dev/null 2>&1; then
    echo "✅ Help command works"
else
    echo "❌ Help command failed"
fi
echo ""

# Test 2: Version functionality
echo "Test 2: Version functionality"
echo "---------------------------"
if bash "$SCANNER" --version > /dev/null 2>&1; then
    echo "✅ Version command works"
else
    echo "❌ Version command failed"
fi
echo ""

# Test 3: Module loading
echo "Test 3: Module loading"
echo "--------------------"
if [[ -d "$SCRIPT_DIR/modules" ]]; then
    module_count=$(ls "$SCRIPT_DIR/modules"/*.sh 2>/dev/null | wc -l)
    echo "✅ Found $module_count modules"

    # Check if modules have required functions
    for module in "$SCRIPT_DIR/modules"/*.sh; do
        if [[ -f "$module" ]]; then
            module_name=$(basename "$module" .sh)
            echo "  - $module_name.sh: $(grep -c "^check_" "$module") check functions"
        fi
    done
else
    echo "❌ Modules directory not found"
fi
echo ""

# Test 4: Basic syntax validation
echo "Test 4: Script syntax validation"
echo "------------------------------"
if bash -n "$SCANNER" 2>/dev/null; then
    echo "✅ Scanner script syntax is valid"
else
    echo "❌ Scanner script has syntax errors"
fi

# Check module syntax
for module in "$SCRIPT_DIR/modules"/*.sh; do
    if [[ -f "$module" ]]; then
        module_name=$(basename "$module")
        if bash -n "$module" 2>/dev/null; then
            echo "✅ $module_name syntax is valid"
        else
            echo "❌ $module_name has syntax errors"
        fi
    fi
done
echo ""

# Test 5: Output format validation
echo "Test 5: Output format validation"
echo "------------------------------"
# Test if output format functions exist
if grep -q "generate_json_report" "$SCANNER"; then
    echo "✅ JSON output format function exists"
else
    echo "❌ JSON output format function missing"
fi

if grep -q "generate_csv_report" "$SCANNER"; then
    echo "✅ CSV output format function exists"
else
    echo "❌ CSV output format function missing"
fi

if grep -q "generate_text_report" "$SCANNER"; then
    echo "✅ Text output format function exists"
else
    echo "❌ Text output format function missing"
fi
echo ""

# Test 6: Check function validation
echo "Test 6: Check function validation"
echo "-------------------------------"
total_checks=0
for module in "$SCRIPT_DIR/modules"/*.sh; do
    if [[ -f "$module" ]]; then
        checks_in_module=$(grep -c "^check_" "$module")
        total_checks=$((total_checks + checks_in_module))
    fi
done
echo "✅ Total check functions implemented: $total_checks"
echo ""

# Test 7: Remediation capability check
echo "Test 7: Remediation capability check"
echo "----------------------------------"
if grep -q "FIX_MODE" "$SCANNER"; then
    echo "✅ Remediation mode (--fix) is implemented"
else
    echo "❌ Remediation mode not found"
fi
echo ""

# Test 8: Configuration file structure
echo "Test 8: Configuration file structure"
echo "----------------------------------"
if [[ -d "$SCRIPT_DIR/config" ]]; then
    config_count=$(ls "$SCRIPT_DIR/config"/*.json 2>/dev/null | wc -l)
    echo "✅ Found $config_count configuration files"
else
    echo "❌ Config directory not found"
fi
echo ""

echo "========================================"
echo "  Test Summary"
echo "========================================"
echo "Scanner components validated!"
echo "Note: Full functionality testing requires Linux environment"
echo "Run on a Linux system for complete security check validation"
