#!/bin/bash
# Linux Hardening & Compliance Scanner
# Version: 1.0.0
# A native Bash-based security scanner for Linux systems

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAN_ID=$(date +%Y%m%d_%H%M%S)
START_TIME=$(date +%s)
VERBOSE=false
QUIET=false
FIX_MODE=false
OUTPUT_FORMAT="text"
OUTPUT_FILE=""
PROFILE="default"
EXCLUDE_CHECKS=""
INCLUDE_ONLY=""
TIMEOUT=3600

# Results storage
declare -A SCAN_RESULTS
declare -A SUMMARY_COUNTS=(
    [total]=0
    [pass]=0
    [warn]=0
    [fail]=0
    [skip]=0
)

# Function to print colored output
print_status() {
    local status="$1"
    local message="$2"

    case "$status" in
        "PASS")
            echo -e "${GREEN}[PASS]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "FAIL")
            echo -e "${RED}[FAIL]${NC} $message"
            ;;
        "SKIP")
            echo -e "${BLUE}[SKIP]${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        *)
            echo "$message"
            ;;
    esac
}

# Function to log verbose messages
log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1" >&2
    fi
}

# Function to run a security check
run_check() {
    local check_id="$1"
    local check_name="$2"
    local severity="$3"
    local check_function="$4"
    local remediation="${5:-}"

    log_verbose "Running check: $check_id - $check_name"

    # Check if this check should be excluded
    if [[ -n "$EXCLUDE_CHECKS" ]] && [[ "$EXCLUDE_CHECKS" =~ (^|,)$check_id(,|$) ]]; then
        print_status "SKIP" "$check_id: $check_name (excluded)"
        SCAN_RESULTS["$check_id"]="SKIP:$check_name:Excluded"
        ((SUMMARY_COUNTS[skip]++))
        return
    fi

    # Check if only specific checks should be included
    if [[ -n "$INCLUDE_ONLY" ]] && [[ ! "$INCLUDE_ONLY" =~ (^|,)$check_id(,|$) ]]; then
        print_status "SKIP" "$check_id: $check_name (not included)"
        SCAN_RESULTS["$check_id"]="SKIP:$check_name:Not included"
        ((SUMMARY_COUNTS[skip]++))
        return
    fi

    ((SUMMARY_COUNTS[total]++))

    # Run the check function
    if $check_function; then
        local status="PASS"
        ((SUMMARY_COUNTS[pass]++))
        SCAN_RESULTS["$check_id"]="PASS:$check_name:$severity"
    else
        local exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
            # Warning condition
            local status="WARN"
            ((SUMMARY_COUNTS[warn]++))
            SCAN_RESULTS["$check_id"]="WARN:$check_name:$severity:$remediation"
        else
            # Failure condition
            local status="FAIL"
            ((SUMMARY_COUNTS[fail]++))
            SCAN_RESULTS["$check_id"]="FAIL:$check_name:$severity:$remediation"
        fi
    fi

    if [[ "$QUIET" != true ]]; then
        print_status "$status" "$check_id: $check_name"
        if [[ "$status" != "PASS" ]] && [[ -n "$remediation" ]]; then
            echo -e "         Remediation: $remediation"
        fi
    fi
}

# Function to load modules
load_modules() {
    local modules_dir="$SCRIPT_DIR/modules"

    if [[ ! -d "$modules_dir" ]]; then
        print_status "WARN" "Modules directory not found: $modules_dir"
        return 1
    fi

    log_verbose "Loading modules from: $modules_dir"

    for module in "$modules_dir"/*.sh; do
        if [[ -f "$module" ]]; then
            log_verbose "Loading module: $(basename "$module")"
            source "$module"
        fi
    done
}

# Function to run filesystem security checks
run_filesystem_checks() {
    print_status "INFO" "Running File System Security Checks..."

    # World-writable files
    run_check "FS-001" "World-writable files check" "HIGH" check_world_writable_files \
        "Remove world-write permissions or review file necessity"

    # World-writable directories
    run_check "FS-002" "World-writable directories check" "HIGH" check_world_writable_dirs \
        "Remove world-write permissions from directories"

    # SUID/SGID binaries
    run_check "FS-003" "SUID/SGID binaries check" "MEDIUM" check_suid_sgid_binaries \
        "Review SUID/SGID binaries for necessity and security"

    # Critical file permissions
    run_check "FS-004" "Critical file permissions" "CRITICAL" check_critical_file_permissions \
        "Set proper permissions on critical system files"

    # Unowned files
    run_check "FS-005" "Unowned files check" "MEDIUM" check_unowned_files \
        "Assign ownership to unowned files or remove them"
}

# Function to run system file validation
run_system_validation() {
    print_status "INFO" "Running System File Validation..."

    # /etc/passwd permissions
    run_check "SYS-001" "/etc/passwd permissions" "CRITICAL" check_passwd_permissions \
        "Set /etc/passwd permissions to 644"

    # /etc/shadow permissions
    run_check "SYS-002" "/etc/shadow permissions" "CRITICAL" check_shadow_permissions \
        "Set /etc/shadow permissions to 600"

    # /etc/group permissions
    run_check "SYS-003" "/etc/group permissions" "HIGH" check_group_permissions \
        "Set /etc/group permissions to 644"

    # /etc/sudoers permissions
    run_check "SYS-004" "/etc/sudoers permissions" "CRITICAL" check_sudoers_permissions \
        "Use visudo to edit sudoers file"
}

# Function to run SSH hardening checks
run_ssh_checks() {
    print_status "INFO" "Running SSH Hardening Checks..."

    # SSH root login
    run_check "SSH-001" "SSH root login disabled" "HIGH" check_ssh_root_login \
        "Set 'PermitRootLogin no' in /etc/ssh/sshd_config"

    # SSH password authentication
    run_check "SSH-002" "SSH password authentication disabled" "HIGH" check_ssh_password_auth \
        "Set 'PasswordAuthentication no' in /etc/ssh/sshd_config"

    # SSH MaxAuthTries
    run_check "SSH-003" "SSH MaxAuthTries limit" "MEDIUM" check_ssh_max_auth_tries \
        "Set 'MaxAuthTries 3' in /etc/ssh/sshd_config"

    # SSH protocol version
    run_check "SSH-004" "SSH protocol version 2 only" "HIGH" check_ssh_protocol_version \
        "Ensure SSH uses protocol version 2"

    # SSH X11 forwarding
    run_check "SSH-005" "SSH X11 forwarding disabled" "LOW" check_ssh_x11_forwarding \
        "Set 'X11Forwarding no' in /etc/ssh/sshd_config"
}

# Function to generate report
generate_report() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local compliance_score=0

    if [[ ${SUMMARY_COUNTS[total]} -gt 0 ]]; then
        compliance_score=$(( (SUMMARY_COUNTS[pass] * 100) / SUMMARY_COUNTS[total] ))
    fi

    case $compliance_score in
        9[0-9]|100) risk_level="LOW" ;;
        7[0-9]|8[0-9]) risk_level="MEDIUM" ;;
        5[0-9]|6[0-9]) risk_level="HIGH" ;;
        *) risk_level="CRITICAL" ;;
    esac

    # Output to file or stdout
    if [[ -n "$OUTPUT_FILE" ]]; then
        exec > "$OUTPUT_FILE"
    fi

    case "$OUTPUT_FORMAT" in
        "json")
            generate_json_report "$duration" "$compliance_score" "$risk_level"
            ;;
        "csv")
            generate_csv_report "$duration" "$compliance_score" "$risk_level"
            ;;
        *)
            generate_text_report "$duration" "$compliance_score" "$risk_level"
            ;;
    esac
}

# Function to generate text report
generate_text_report() {
    local duration="$1"
    local score="$2"
    local risk="$3"

    echo "========================================"
    echo "  Linux Hardening & Compliance Scanner"
    echo "========================================"
    echo "Scan ID: $SCAN_ID"
    echo "Profile: $PROFILE"
    echo "Duration: ${duration}s"
    echo "Compliance Score: ${score}%"
    echo "Risk Level: $risk"
    echo ""
    echo "Summary:"
    echo "--------"
    echo "Total Checks: ${SUMMARY_COUNTS[total]}"
    echo "Passed: ${SUMMARY_COUNTS[pass]}"
    echo "Warnings: ${SUMMARY_COUNTS[warn]}"
    echo "Failed: ${SUMMARY_COUNTS[fail]}"
    echo "Skipped: ${SUMMARY_COUNTS[skip]}"
    echo ""
    echo "Detailed Results:"
    echo "================="

    for check_id in "${!SCAN_RESULTS[@]}"; do
        IFS=':' read -r status name severity remediation <<< "${SCAN_RESULTS[$check_id]}"
        echo "$check_id [$status]: $name"
        if [[ "$status" != "PASS" ]] && [[ -n "$remediation" ]]; then
            echo "  Remediation: $remediation"
        fi
        echo ""
    done
}

# Function to generate JSON report
generate_json_report() {
    local duration="$1"
    local score="$2"
    local risk="$3"

    echo "{"
    echo "  \"scan_id\": \"$SCAN_ID\","
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"profile\": \"$PROFILE\","
    echo "  \"duration_seconds\": $duration,"
    echo "  \"compliance_score\": $score,"
    echo "  \"risk_level\": \"$risk\","
    echo "  \"summary\": {"
    echo "    \"total_checks\": ${SUMMARY_COUNTS[total]},"
    echo "    \"passed\": ${SUMMARY_COUNTS[pass]},"
    echo "    \"warnings\": ${SUMMARY_COUNTS[warn]},"
    echo "    \"failed\": ${SUMMARY_COUNTS[fail]},"
    echo "    \"skipped\": ${SUMMARY_COUNTS[skip]}"
    echo "  },"
    echo "  \"checks\": {"

    local first=true
    for check_id in "${!SCAN_RESULTS[@]}"; do
        if [[ "$first" != true ]]; then
            echo "    },"
        fi
        first=false

        IFS=':' read -r status name severity remediation <<< "${SCAN_RESULTS[$check_id]}"
        echo "    \"$check_id\": {"
        echo "      \"name\": \"$name\","
        echo "      \"status\": \"$status\","
        echo "      \"severity\": \"$severity\""
        if [[ -n "$remediation" ]]; then
            echo "      \"remediation\": \"$remediation\""
        fi
    done

    if [[ ${#SCAN_RESULTS[@]} -gt 0 ]]; then
        echo "    }"
    fi
    echo "  }"
    echo "}"
}

# Function to generate CSV report
generate_csv_report() {
    local duration="$1"
    local score="$2"
    local risk="$3"

    echo "Scan ID,Check ID,Check Name,Status,Severity,Remediation"
    echo "$SCAN_ID,SUMMARY,Summary,$score,$risk,"

    for check_id in "${!SCAN_RESULTS[@]}"; do
        IFS=':' read -r status name severity remediation <<< "${SCAN_RESULTS[$check_id]}"
        echo "$SCAN_ID,$check_id,\"$name\",$status,$severity,\"$remediation\""
    done
}

# Function to show usage
show_usage() {
    cat << EOF
Linux Hardening & Compliance Scanner v1.0.0

USAGE:
    $0 [OPTIONS] [PROFILE]

PROFILES:
    filesystem     Run filesystem security checks only
    system         Run system file validation only
    ssh            Run SSH hardening checks only
    full          Run all checks (default)
    cis            CIS benchmark compliance
    custom         Custom profile from config

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -q, --quiet             Suppress progress messages
    --fix                   Enable automatic remediation
    -o, --output FILE       Save results to file
    -f, --format FORMAT     Output format: text, json, csv (default: text)
    --exclude CHECKS        Exclude specific check IDs (comma-separated)
    --include-only CHECKS   Run only specified check IDs (comma-separated)
    --timeout SECONDS       Scan timeout in seconds (default: 3600)
    --version               Show version information

EXAMPLES:
    $0                          # Run full scan with default settings
    $0 filesystem               # Run only filesystem checks
    $0 --fix ssh               # Run SSH checks with auto-remediation
    $0 -o results.json -f json  # Save results as JSON
    $0 --exclude FS-001,SYS-002 # Exclude specific checks

For more information, visit: https://github.com/add54/Linux-Hardening-Compliance-Scanner
EOF
}

# Function to show version
show_version() {
    echo "Linux Hardening & Compliance Scanner v1.0.0"
    echo "Built with Bash and Linux internals"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            --fix)
                FIX_MODE=true
                shift
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --exclude)
                EXCLUDE_CHECKS="$2"
                shift 2
                ;;
            --include-only)
                INCLUDE_ONLY="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --version)
                show_version
                exit 0
                ;;
            filesystem|system|ssh|full|cis|custom)
                PROFILE="$1"
                shift
                ;;
            *)
                echo "Unknown option: $1" >&2
                echo "Use '$0 --help' for usage information." >&2
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    # Parse command line arguments
    parse_args "$@"

    # Print banner unless quiet
    if [[ "$QUIET" != true ]]; then
        echo "========================================"
        echo "  Linux Hardening & Compliance Scanner"
        echo "========================================"
        echo "Scan ID: $SCAN_ID"
        echo "Profile: $PROFILE"
        echo "Started: $(date)"
        echo ""
    fi

    # Load modules
    load_modules

    # Run checks based on profile
    case "$PROFILE" in
        filesystem)
            run_filesystem_checks
            ;;
        system)
            run_system_validation
            ;;
        ssh)
            run_ssh_checks
            ;;
        cis|custom)
            print_status "INFO" "CIS/Custom profiles not yet implemented"
            run_filesystem_checks
            run_system_validation
            run_ssh_checks
            ;;
        full|*)
            run_filesystem_checks
            run_system_validation
            run_ssh_checks
            ;;
    esac

    # Generate report
    if [[ "$QUIET" != true ]]; then
        echo ""
    fi
    generate_report

    # Print completion message
    if [[ "$QUIET" != true ]]; then
        local end_time=$(date +%s)
        local duration=$((end_time - START_TIME))
        print_status "INFO" "Scan completed in ${duration}s"
    fi
}

# Run main function with all arguments
main "$@"
