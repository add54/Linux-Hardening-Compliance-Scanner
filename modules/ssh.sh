#!/bin/bash
# SSH Hardening Module
# Contains functions for SSH security configuration checks

SSH_CONFIG="/etc/ssh/sshd_config"

# Function to check SSH root login policy
check_ssh_root_login() {
    log_verbose "Checking SSH root login policy..."

    if [[ ! -f "$SSH_CONFIG" ]]; then
        log_verbose "SSH config file not found: $SSH_CONFIG"
        return 1  # FAIL - cannot check
    fi

    # Check for PermitRootLogin setting
    local permit_root_login
    permit_root_login=$(grep -E "^PermitRootLogin" "$SSH_CONFIG" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')

    # If not set, default is 'prohibit-password' in newer versions, 'yes' in older
    if [[ -z "$permit_root_login" ]]; then
        # Check SSH version to determine default
        local ssh_version
        ssh_version=$(ssh -V 2>&1 | awk '{print $1}' | cut -d'_' -f2 | cut -d'.' -f1)

        if [[ $ssh_version -ge 7 ]]; then
            log_verbose "PermitRootLogin not set, using default 'prohibit-password' (SSH v7+)"
            return 0  # PASS - default is secure
        else
            log_verbose "PermitRootLogin not set, using default 'yes' (SSH v6-)"
            if [[ "$FIX_MODE" == true ]]; then
                echo "PermitRootLogin no" >> "$SSH_CONFIG"
                log_verbose "Added 'PermitRootLogin no' to SSH config"
                return 0
            else
                return 1  # FAIL - insecure default
            fi
        fi
    elif [[ "$permit_root_login" == "no" ]]; then
        log_verbose "Root login is properly disabled"
        return 0  # PASS
    elif [[ "$permit_root_login" == "prohibit-password" ]]; then
        log_verbose "Root login allows key-based authentication only"
        return 0  # PASS
    else
        log_verbose "Root login is allowed: $permit_root_login"
        if [[ "$FIX_MODE" == true ]]; then
            # Comment out the existing line and add secure setting
            sed -i 's/^PermitRootLogin/#&/' "$SSH_CONFIG"
            echo "PermitRootLogin no" >> "$SSH_CONFIG"
            log_verbose "Disabled root login in SSH config"
            return 0
        else
            return 1  # FAIL - root login allowed
        fi
    fi
}

# Function to check SSH password authentication
check_ssh_password_auth() {
    log_verbose "Checking SSH password authentication..."

    if [[ ! -f "$SSH_CONFIG" ]]; then
        log_verbose "SSH config file not found: $SSH_CONFIG"
        return 1  # FAIL - cannot check
    fi

    # Check for PasswordAuthentication setting
    local password_auth
    password_auth=$(grep -E "^PasswordAuthentication" "$SSH_CONFIG" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')

    if [[ -z "$password_auth" ]]; then
        log_verbose "PasswordAuthentication not set, using default 'yes'"
        if [[ "$FIX_MODE" == true ]]; then
            echo "PasswordAuthentication no" >> "$SSH_CONFIG"
            log_verbose "Disabled password authentication in SSH config"
            return 0
        else
            return 1  # FAIL - password auth enabled by default
        fi
    elif [[ "$password_auth" == "no" ]]; then
        log_verbose "Password authentication is properly disabled"
        return 0  # PASS
    else
        log_verbose "Password authentication is enabled"
        if [[ "$FIX_MODE" == true ]]; then
            # Comment out the existing line and add secure setting
            sed -i 's/^PasswordAuthentication/#&/' "$SSH_CONFIG"
            echo "PasswordAuthentication no" >> "$SSH_CONFIG"
            log_verbose "Disabled password authentication in SSH config"
            return 0
        else
            return 1  # FAIL - password auth enabled
        fi
    fi
}

# Function to check SSH MaxAuthTries
check_ssh_max_auth_tries() {
    log_verbose "Checking SSH MaxAuthTries setting..."

    if [[ ! -f "$SSH_CONFIG" ]]; then
        log_verbose "SSH config file not found: $SSH_CONFIG"
        return 1  # FAIL - cannot check
    fi

    # Check for MaxAuthTries setting
    local max_auth_tries
    max_auth_tries=$(grep -E "^MaxAuthTries" "$SSH_CONFIG" | awk '{print $2}')

    if [[ -z "$max_auth_tries" ]]; then
        log_verbose "MaxAuthTries not set, using default (6)"
        if [[ "$FIX_MODE" == true ]]; then
            echo "MaxAuthTries 3" >> "$SSH_CONFIG"
            log_verbose "Set MaxAuthTries to 3 in SSH config"
            return 0
        else
            return 2  # WARN - default might be too high
        fi
    elif [[ $max_auth_tries -le 3 ]]; then
        log_verbose "MaxAuthTries is set to secure value: $max_auth_tries"
        return 0  # PASS
    elif [[ $max_auth_tries -le 5 ]]; then
        log_verbose "MaxAuthTries is moderately secure: $max_auth_tries"
        return 2  # WARN - could be lower
    else
        log_verbose "MaxAuthTries is too high: $max_auth_tries"
        if [[ "$FIX_MODE" == true ]]; then
            # Comment out the existing line and add secure setting
            sed -i 's/^MaxAuthTries/#&/' "$SSH_CONFIG"
            echo "MaxAuthTries 3" >> "$SSH_CONFIG"
            log_verbose "Set MaxAuthTries to 3 in SSH config"
            return 0
        else
            return 1  # FAIL - too many attempts allowed
        fi
    fi
}

# Function to check SSH protocol version
check_ssh_protocol_version() {
    log_verbose "Checking SSH protocol version..."

    if [[ ! -f "$SSH_CONFIG" ]]; then
        log_verbose "SSH config file not found: $SSH_CONFIG"
        return 1  # FAIL - cannot check
    fi

    # Check for Protocol setting
    local protocol
    protocol=$(grep -E "^Protocol" "$SSH_CONFIG" | awk '{print $2}')

    if [[ -z "$protocol" ]]; then
        log_verbose "Protocol not specified, using default (2)"
        return 0  # PASS - SSH v2 is default
    elif [[ "$protocol" == "2" ]]; then
        log_verbose "SSH protocol version 2 is properly configured"
        return 0  # PASS
    else
        log_verbose "SSH protocol version is set to: $protocol (should be 2)"
        if [[ "$FIX_MODE" == true ]]; then
            # Comment out the existing line and add secure setting
            sed -i 's/^Protocol/#&/' "$SSH_CONFIG"
            echo "Protocol 2" >> "$SSH_CONFIG"
            log_verbose "Set SSH protocol to version 2"
            return 0
        else
            return 1  # FAIL - wrong protocol version
        fi
    fi
}

# Function to check SSH X11 forwarding
check_ssh_x11_forwarding() {
    log_verbose "Checking SSH X11 forwarding..."

    if [[ ! -f "$SSH_CONFIG" ]]; then
        log_verbose "SSH config file not found: $SSH_CONFIG"
        return 1  # FAIL - cannot check
    fi

    # Check for X11Forwarding setting
    local x11_forwarding
    x11_forwarding=$(grep -E "^X11Forwarding" "$SSH_CONFIG" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')

    if [[ -z "$x11_forwarding" ]]; then
        log_verbose "X11Forwarding not set, using default 'no'"
        return 0  # PASS - default is secure
    elif [[ "$x11_forwarding" == "no" ]]; then
        log_verbose "X11 forwarding is properly disabled"
        return 0  # PASS
    else
        log_verbose "X11 forwarding is enabled"
        if [[ "$FIX_MODE" == true ]]; then
            # Comment out the existing line and add secure setting
            sed -i 's/^X11Forwarding/#&/' "$SSH_CONFIG"
            echo "X11Forwarding no" >> "$SSH_CONFIG"
            log_verbose "Disabled X11 forwarding in SSH config"
            return 0
        else
            return 2  # WARN - X11 forwarding enabled
        fi
    fi
}

# Function to check SSH PermitEmptyPasswords
check_ssh_empty_passwords() {
    log_verbose "Checking SSH PermitEmptyPasswords..."

    if [[ ! -f "$SSH_CONFIG" ]]; then
        log_verbose "SSH config file not found: $SSH_CONFIG"
        return 1  # FAIL - cannot check
    fi

    # Check for PermitEmptyPasswords setting
    local permit_empty
    permit_empty=$(grep -E "^PermitEmptyPasswords" "$SSH_CONFIG" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')

    if [[ -z "$permit_empty" ]]; then
        log_verbose "PermitEmptyPasswords not set, using default 'no'"
        return 0  # PASS - default is secure
    elif [[ "$permit_empty" == "no" ]]; then
        log_verbose "Empty passwords are properly not permitted"
        return 0  # PASS
    else
        log_verbose "Empty passwords are permitted"
        if [[ "$FIX_MODE" == true ]]; then
            # Comment out the existing line and add secure setting
            sed -i 's/^PermitEmptyPasswords/#&/' "$SSH_CONFIG"
            echo "PermitEmptyPasswords no" >> "$SSH_CONFIG"
            log_verbose "Disabled empty passwords in SSH config"
            return 0
        else
            return 1  # FAIL - empty passwords allowed
        fi
    fi
}

# Function to check SSH UsePAM
check_ssh_use_pam() {
    log_verbose "Checking SSH UsePAM setting..."

    if [[ ! -f "$SSH_CONFIG" ]]; then
        log_verbose "SSH config file not found: $SSH_CONFIG"
        return 1  # FAIL - cannot check
    fi

    # Check for UsePAM setting
    local use_pam
    use_pam=$(grep -E "^UsePAM" "$SSH_CONFIG" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')

    if [[ -z "$use_pam" ]]; then
        log_verbose "UsePAM not set, using default 'yes'"
        return 0  # PASS - PAM is good
    elif [[ "$use_pam" == "yes" ]]; then
        log_verbose "PAM is properly enabled"
        return 0  # PASS
    else
        log_verbose "PAM is disabled"
        return 2  # WARN - PAM should be enabled
    fi
}

log_verbose "SSH Hardening Module loaded"
