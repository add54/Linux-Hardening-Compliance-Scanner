#!/bin/bash
# System File Validation Module
# Contains functions for validating critical system file permissions and security

# Function to check /etc/passwd permissions
check_passwd_permissions() {
    log_verbose "Checking /etc/passwd permissions..."

    if [[ ! -f /etc/passwd ]]; then
        log_verbose "/etc/passwd file not found"
        return 1  # FAIL - critical file missing
    fi

    local passwd_perms
    passwd_perms=$(stat -c '%a' /etc/passwd 2>/dev/null || echo "unknown")

    if [[ "$passwd_perms" == "644" ]]; then
        log_verbose "/etc/passwd has correct permissions (644)"
        return 0  # PASS
    else
        log_verbose "/etc/passwd has incorrect permissions: $passwd_perms (should be 644)"
        if [[ "$FIX_MODE" == true ]]; then
            if chmod 644 /etc/passwd 2>/dev/null; then
                log_verbose "Fixed /etc/passwd permissions to 644"
                return 0
            else
                log_verbose "Failed to fix /etc/passwd permissions"
                return 1
            fi
        else
            return 1  # FAIL
        fi
    fi
}

# Function to check /etc/shadow permissions
check_shadow_permissions() {
    log_verbose "Checking /etc/shadow permissions..."

    if [[ ! -f /etc/shadow ]]; then
        log_verbose "/etc/shadow file not found"
        return 1  # FAIL - critical file missing
    fi

    local shadow_perms
    shadow_perms=$(stat -c '%a' /etc/shadow 2>/dev/null || echo "unknown")

    if [[ "$shadow_perms" == "600" ]]; then
        log_verbose "/etc/shadow has correct permissions (600)"
        return 0  # PASS
    else
        log_verbose "/etc/shadow has incorrect permissions: $shadow_perms (should be 600)"
        if [[ "$FIX_MODE" == true ]]; then
            if chmod 600 /etc/shadow 2>/dev/null; then
                log_verbose "Fixed /etc/shadow permissions to 600"
                return 0
            else
                log_verbose "Failed to fix /etc/shadow permissions"
                return 1
            fi
        else
            return 1  # FAIL
        fi
    fi
}

# Function to check /etc/group permissions
check_group_permissions() {
    log_verbose "Checking /etc/group permissions..."

    if [[ ! -f /etc/group ]]; then
        log_verbose "/etc/group file not found"
        return 1  # FAIL - critical file missing
    fi

    local group_perms
    group_perms=$(stat -c '%a' /etc/group 2>/dev/null || echo "unknown")

    if [[ "$group_perms" == "644" ]]; then
        log_verbose "/etc/group has correct permissions (644)"
        return 0  # PASS
    else
        log_verbose "/etc/group has incorrect permissions: $group_perms (should be 644)"
        if [[ "$FIX_MODE" == true ]]; then
            if chmod 644 /etc/group 2>/dev/null; then
                log_verbose "Fixed /etc/group permissions to 644"
                return 0
            else
                log_verbose "Failed to fix /etc/group permissions"
                return 1
            fi
        else
            return 1  # FAIL
        fi
    fi
}

# Function to check /etc/sudoers permissions
check_sudoers_permissions() {
    log_verbose "Checking /etc/sudoers permissions..."

    if [[ ! -f /etc/sudoers ]]; then
        log_verbose "/etc/sudoers file not found"
        return 1  # FAIL - critical file missing
    fi

    local sudoers_perms
    sudoers_perms=$(stat -c '%a' /etc/sudoers 2>/dev/null || echo "unknown")

    if [[ "$sudoers_perms" == "440" ]]; then
        log_verbose "/etc/sudoers has correct permissions (440)"
        return 0  # PASS
    else
        log_verbose "/etc/sudoers has incorrect permissions: $sudoers_perms (should be 440)"
        # Note: We don't auto-fix sudoers permissions as it could break sudo
        # visudo should be used to edit sudoers
        return 1  # FAIL
    fi
}

# Function to check for empty passwords in /etc/shadow
check_empty_passwords() {
    log_verbose "Checking for empty passwords in /etc/shadow..."

    if [[ ! -f /etc/shadow ]]; then
        log_verbose "/etc/shadow file not found"
        return 1  # FAIL - cannot check
    fi

    # Count accounts with empty passwords (password field is empty or starts with ! or *)
    local empty_passwords
    empty_passwords=$(awk -F: '($2 == "" || $2 == "!" || $2 == "*") && $1 != "root" {print $1}' /etc/shadow 2>/dev/null | wc -l)

    if [[ $empty_passwords -eq 0 ]]; then
        log_verbose "No accounts with empty passwords found"
        return 0  # PASS
    else
        log_verbose "Found $empty_passwords accounts with empty passwords"
        return 1  # FAIL - security risk
    fi
}

# Function to check for accounts without passwords
check_accounts_without_passwords() {
    log_verbose "Checking for accounts without passwords..."

    if [[ ! -f /etc/shadow ]]; then
        log_verbose "/etc/shadow file not found"
        return 1  # FAIL - cannot check
    fi

    # Find accounts that exist in passwd but not in shadow
    local accounts_no_shadow
    accounts_no_shadow=$(awk -F: 'NR==FNR {users[$1]=1; next} !($1 in users)' /etc/shadow /etc/passwd 2>/dev/null | wc -l)

    if [[ $accounts_no_shadow -eq 0 ]]; then
        log_verbose "All accounts have shadow entries"
        return 0  # PASS
    else
        log_verbose "Found $accounts_no_shadow accounts without shadow entries"
        return 2  # WARN - potential issue
    fi
}

# Function to check root account security
check_root_account() {
    log_verbose "Checking root account security..."

    # Check if root account is locked (password starts with !)
    if [[ -f /etc/shadow ]]; then
        local root_password
        root_password=$(awk -F: '$1=="root" {print $2}' /etc/shadow 2>/dev/null)

        if [[ "$root_password" == "!"* ]] || [[ "$root_password" == "*" ]]; then
            log_verbose "Root account is locked"
            return 0  # PASS - root locked
        else
            log_verbose "Root account has active password"
            return 2  # WARN - root has password
        fi
    else
        log_verbose "/etc/shadow not accessible"
        return 1  # FAIL - cannot check
    fi
}

# Function to check for duplicate UIDs
check_duplicate_uids() {
    log_verbose "Checking for duplicate UIDs..."

    if [[ ! -f /etc/passwd ]]; then
        log_verbose "/etc/passwd file not found"
        return 1  # FAIL - cannot check
    fi

    local duplicate_uids
    duplicate_uids=$(cut -d: -f3 /etc/passwd | sort | uniq -d | wc -l)

    if [[ $duplicate_uids -eq 0 ]]; then
        log_verbose "No duplicate UIDs found"
        return 0  # PASS
    else
        log_verbose "Found $duplicate_uids duplicate UIDs"
        return 1  # FAIL - security issue
    fi
}

# Function to check for duplicate GIDs
check_duplicate_gids() {
    log_verbose "Checking for duplicate GIDs..."

    if [[ ! -f /etc/group ]]; then
        log_verbose "/etc/group file not found"
        return 1  # FAIL - cannot check
    fi

    local duplicate_gids
    duplicate_gids=$(cut -d: -f3 /etc/group | sort | uniq -d | wc -l)

    if [[ $duplicate_gids -eq 0 ]]; then
        log_verbose "No duplicate GIDs found"
        return 0  # PASS
    else
        log_verbose "Found $duplicate_gids duplicate GIDs"
        return 1  # FAIL - security issue
    fi
}

log_verbose "System File Validation Module loaded"
