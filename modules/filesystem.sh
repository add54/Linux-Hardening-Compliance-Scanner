#!/bin/bash
# File System Security Module
# Contains functions for filesystem security checks

# Function to check for world-writable files
check_world_writable_files() {
    log_verbose "Checking for world-writable files..."

    # Find world-writable files, excluding common system directories
    local world_writable_files
    world_writable_files=$(find / -type f -perm -o+w \
        -not -path '/proc/*' \
        -not -path '/sys/*' \
        -not -path '/dev/*' \
        -not -path '/run/*' \
        -not -path '/tmp/*' \
        -not -path '/var/tmp/*' \
        2>/dev/null | wc -l)

    if [[ $world_writable_files -eq 0 ]]; then
        log_verbose "No world-writable files found"
        return 0  # PASS
    else
        log_verbose "Found $world_writable_files world-writable files"
        # For remediation, we'd list the files
        if [[ "$FIX_MODE" == true ]]; then
            find / -type f -perm -o+w \
                -not -path '/proc/*' \
                -not -path '/sys/*' \
                -not -path '/dev/*' \
                -not -path '/run/*' \
                -not -path '/tmp/*' \
                -not -path '/var/tmp/*' \
                -exec chmod o-w {} \; 2>/dev/null
            log_verbose "Removed world-write permissions from $world_writable_files files"
        fi
        return 1  # FAIL - world-writable files found
    fi
}

# Function to check for world-writable directories
check_world_writable_dirs() {
    log_verbose "Checking for world-writable directories..."

    # Find world-writable directories, excluding common system directories
    local world_writable_dirs
    world_writable_dirs=$(find / -type d -perm -o+w \
        -not -path '/proc/*' \
        -not -path '/sys/*' \
        -not -path '/dev/*' \
        -not -path '/run/*' \
        -not -path '/tmp/*' \
        -not -path '/var/tmp/*' \
        2>/dev/null | wc -l)

    if [[ $world_writable_dirs -eq 0 ]]; then
        log_verbose "No world-writable directories found"
        return 0  # PASS
    else
        log_verbose "Found $world_writable_dirs world-writable directories"
        # For remediation, we'd remove write permissions
        if [[ "$FIX_MODE" == true ]]; then
            find / -type d -perm -o+w \
                -not -path '/proc/*' \
                -not -path '/sys/*' \
                -not -path '/dev/*' \
                -not -path '/run/*' \
                -not -path '/tmp/*' \
                -not -path '/var/tmp/*' \
                -exec chmod o-w {} \; 2>/dev/null
            log_verbose "Removed world-write permissions from $world_writable_dirs directories"
        fi
        return 1  # FAIL - world-writable directories found
    fi
}

# Function to check SUID/SGID binaries
check_suid_sgid_binaries() {
    log_verbose "Checking SUID/SGID binaries..."

    # Find SUID/SGID binaries
    local suid_files
    local sgid_files

    suid_files=$(find / -type f -perm -4000 2>/dev/null | wc -l)
    sgid_files=$(find / -type f -perm -2000 2>/dev/null | wc -l)

    local total_special=$((suid_files + sgid_files))

    log_verbose "Found $suid_files SUID files and $sgid_files SGID files"

    # Some SUID/SGID files are legitimate, so we'll warn rather than fail
    if [[ $total_special -gt 50 ]]; then
        # Too many special files - likely a problem
        return 1  # FAIL
    elif [[ $total_special -gt 20 ]]; then
        # Moderate number - warn
        return 2  # WARN
    else
        # Reasonable number - pass
        return 0  # PASS
    fi
}

# Function to check critical file permissions
check_critical_file_permissions() {
    log_verbose "Checking critical file permissions..."

    local issues_found=0

    # Check /etc/passwd permissions (should be 644)
    if [[ -f /etc/passwd ]]; then
        local passwd_perms
        passwd_perms=$(stat -c '%a' /etc/passwd 2>/dev/null || echo "unknown")
        if [[ "$passwd_perms" != "644" ]]; then
            log_verbose "/etc/passwd has incorrect permissions: $passwd_perms (should be 644)"
            if [[ "$FIX_MODE" == true ]]; then
                chmod 644 /etc/passwd 2>/dev/null && log_verbose "Fixed /etc/passwd permissions"
            else
                ((issues_found++))
            fi
        fi
    fi

    # Check /etc/shadow permissions (should be 600)
    if [[ -f /etc/shadow ]]; then
        local shadow_perms
        shadow_perms=$(stat -c '%a' /etc/shadow 2>/dev/null || echo "unknown")
        if [[ "$shadow_perms" != "600" ]]; then
            log_verbose "/etc/shadow has incorrect permissions: $shadow_perms (should be 600)"
            if [[ "$FIX_MODE" == true ]]; then
                chmod 600 /etc/shadow 2>/dev/null && log_verbose "Fixed /etc/shadow permissions"
            else
                ((issues_found++))
            fi
        fi
    fi

    # Check /etc/group permissions (should be 644)
    if [[ -f /etc/group ]]; then
        local group_perms
        group_perms=$(stat -c '%a' /etc/group 2>/dev/null || echo "unknown")
        if [[ "$group_perms" != "644" ]]; then
            log_verbose "/etc/group has incorrect permissions: $group_perms (should be 644)"
            if [[ "$FIX_MODE" == true ]]; then
                chmod 644 /etc/group 2>/dev/null && log_verbose "Fixed /etc/group permissions"
            else
                ((issues_found++))
            fi
        fi
    fi

    if [[ $issues_found -eq 0 ]]; then
        return 0  # PASS
    else
        return 1  # FAIL
    fi
}

# Function to check for unowned files
check_unowned_files() {
    log_verbose "Checking for unowned files..."

    # Find files with no owner or no group
    local unowned_files
    unowned_files=$(find / -nouser -o -nogroup \
        -not -path '/proc/*' \
        -not -path '/sys/*' \
        -not -path '/dev/*' \
        2>/dev/null | wc -l)

    if [[ $unowned_files -eq 0 ]]; then
        log_verbose "No unowned files found"
        return 0  # PASS
    else
        log_verbose "Found $unowned_files unowned files"
        # This is typically a warning rather than a failure
        return 2  # WARN
    fi
}

# Function to check /tmp permissions
check_tmp_permissions() {
    log_verbose "Checking /tmp permissions..."

    if [[ -d /tmp ]]; then
        local tmp_perms
        tmp_perms=$(stat -c '%a' /tmp 2>/dev/null || echo "unknown")

        # /tmp should have sticky bit and proper permissions
        if [[ "$tmp_perms" == "1777" ]]; then
            log_verbose "/tmp has correct permissions with sticky bit"
            return 0  # PASS
        else
            log_verbose "/tmp has incorrect permissions: $tmp_perms (should be 1777)"
            if [[ "$FIX_MODE" == true ]]; then
                chmod 1777 /tmp 2>/dev/null && log_verbose "Fixed /tmp permissions"
                return 0
            else
                return 1  # FAIL
            fi
        fi
    else
        log_verbose "/tmp directory not found"
        return 1  # FAIL
    fi
}

# Function to check sticky bit on world-writable directories
check_sticky_bit() {
    log_verbose "Checking sticky bit on world-writable directories..."

    # Find world-writable directories without sticky bit
    local bad_dirs
    bad_dirs=$(find / -type d -perm -o+w -not -perm -1000 \
        -not -path '/proc/*' \
        -not -path '/sys/*' \
        -not -path '/dev/*' \
        2>/dev/null | wc -l)

    if [[ $bad_dirs -eq 0 ]]; then
        log_verbose "All world-writable directories have sticky bit set"
        return 0  # PASS
    else
        log_verbose "Found $bad_dirs world-writable directories without sticky bit"
        if [[ "$FIX_MODE" == true ]]; then
            find / -type d -perm -o+w -not -perm -1000 \
                -not -path '/proc/*' \
                -not -path '/sys/*' \
                -not -path '/dev/*' \
                -exec chmod +t {} \; 2>/dev/null
            log_verbose "Set sticky bit on $bad_dirs directories"
            return 0
        else
            return 1  # FAIL
        fi
    fi
}

log_verbose "File System Security Module loaded"
