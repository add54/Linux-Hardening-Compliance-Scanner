# File System Security Scanner Module

function Invoke-FileSystemScan {
    [CmdletBinding()]
    param()
    
    Write-Verbose "Starting File System security scan..."
    
    # 1. Check for world-writable files
    Test-WorldWritableFiles
    
    # 2. Check for world-writable directories
    Test-WorldWritableDirectories
    
    # 3. Check SUID/SGID binaries
    Test-SuidSgidBinaries
    
    # 4. Check critical file permissions
    Test-CriticalFilePermissions
    
    # 5. Check for unowned files
    Test-UnownedFiles
    
    # 6. Check mount options
    Test-MountOptions
    
    # 7. Check /tmp permissions
    Test-TmpPermissions
    
    # 8. Check sticky bit
    Test-StickyBit
    
    # 9. Check file integrity
    Test-FileIntegrityChecks
    
    # 10. Check disk encryption
    Test-DiskEncryption
    
    Write-Verbose "File System security scan completed."
}

function Test-WorldWritableFiles {
    $check = Register-Check -ID "FS-001" -Name "World-writable files" -Category "FileSystem" -Severity "High" -Reference "CIS 1.1.21"
    
    Invoke-SecurityCheck -Check $check -TestScript {
        $worldWritableFiles = @()
        
        # Exclude common directories
        $excludePaths = @('/proc/', '/sys/', '/dev/', '/run/', '/tmp/', '/var/tmp/')
        
        # Build find command
        $findCmd = "find / -type f -perm -0002"
        foreach ($path in $excludePaths) {
            $findCmd += " ! -path '$path*'"
        }
        $findCmd += " 2>/dev/null | head -20"
        
        $files = Invoke-Expression $findCmd
        return $files.Count -eq 0
        
    } -SuccessMessage "No world-writable files found (excluding /tmp, /proc, etc.)" `
      -FailureMessage "Found world-writable files" `
      -Remediation "Remove world-writable permissions: chmod o-w <file>"
}

function Test-WorldWritableDirectories {
    $check = Register-Check -ID "FS-002" -Name "World-writable directories" -Category "FileSystem" -Severity "Medium" -Reference "CIS 1.1.22"
    
    Invoke-SecurityCheck -Check $check -TestScript {
        # Allowed world-writable directories
        $allowedDirs = @('/tmp', '/var/tmp', '/dev/shm', '/run/lock')
        
        $findCmd = "find / -type d -perm -0002"
        foreach ($dir in $allowedDirs) {
            $findCmd += " ! -path '$dir'"
        }
        $findCmd += " 2>/dev/null | head -20"
        
        $dirs = Invoke-Expression $findCmd
        return $dirs.Count -eq 0
        
    } -SuccessMessage "No unauthorized world-writable directories found" `
      -FailureMessage "Found world-writable directories" `
      -Remediation "Review and remove unnecessary world-writable permissions: chmod o-w <directory>"
}

function Test-SuidSgidBinaries {
    $check = Register-Check -ID "FS-003" -Name "SUID/SGID binaries" -Category "FileSystem" -Severity "High" -Reference "CIS 1.1.20"
    
    Invoke-SecurityCheck -Check $check -TestScript {
        # Expected SUID/SGID binaries
        $expectedBinaries = @(
            '/bin/mount', '/bin/ping', '/bin/su', '/bin/umount',
            '/usr/bin/chage', '/usr/bin/chfn', '/usr/bin/chsh',
            '/usr/bin/gpasswd', '/usr/bin/newgrp', '/usr/bin/passwd',
            '/usr/bin/sudo', '/usr/sbin/pam_timestamp_check',
            '/usr/sbin/unix_chkpwd'
        )
        
        $findCmd = "find / -type f \( -perm -4000 -o -perm -2000 \) ! -path '/proc/*' ! -path '/sys/*' ! -path '/dev/*' 2>/dev/null"
        $allBinaries = Invoke-Expression $findCmd
        
        $unexpected = @()
        foreach ($binary in $allBinaries) {
            if ($binary -notin $expectedBinaries) {
                $unexpected += $binary
            }
        }
        
        return $unexpected.Count -eq 0
        
    } -SuccessMessage "No unexpected SUID/SGID binaries found" `
      -FailureMessage "Found unexpected SUID/SGID binaries" `
      -Remediation "Review and remove SUID/SGID bits if not needed: chmod u-s,g-s <file>"
}

function Test-CriticalFilePermissions {
    $check = Register-Check -ID "FS-004" -Name "Critical file permissions" -Category "FileSystem" -Severity "Critical" -Reference "CIS 5.1.2-5.1.8"
    
    Invoke-SecurityCheck -Check $check -TestScript {
        $criticalFiles = @{
            '/etc/passwd' = '644'
            '/etc/shadow' = '640'
            '/etc/group' = '644'
            '/etc/gshadow' = '640'
            '/etc/sudoers' = '440'
            '/etc/ssh/sshd_config' = '600'
            '/etc/crontab' = '644'
        }
        
        $failures = @()
        foreach ($file in $criticalFiles.Keys) {
            if (Test-Path $file) {
                $perms = Get-FilePermission -Path $file
                if ($perms.Permissions -ne $criticalFiles[$file]) {
                    $failures += "$file: expected $($criticalFiles[$file]), got $($perms.Permissions)"
                }
            }
        }
        
        return $failures.Count -eq 0
        
    } -SuccessMessage "All critical files have correct permissions" `
      -FailureMessage "Incorrect permissions found on critical files" `
      -Remediation "Set correct permissions: chmod <expected> <file>"
}

function Test-UnownedFiles {
    $check = Register-Check -ID "FS-005" -Name "Unowned files" -Category "FileSystem" -Severity "Medium" -Reference "CIS 1.1.11"
    
    Invoke-SecurityCheck -Check $check -TestScript {
        $findCmd = "find / -nouser -o -nogroup ! -path '/proc/*' ! -path '/sys/*' ! -path '/dev/*' 2>/dev/null | head -20"
        $unowned = Invoke-Expression $findCmd
        return $unowned.Count -eq 0
        
    } -SuccessMessage "No unowned files found" `
      -FailureMessage "Found unowned files" `
      -Remediation "Assign proper ownership or remove files"
}

function Test-MountOptions {
    $check = Register-Check -ID "FS-006" -Name "Mount options" -Category "FileSystem" -Severity "High" -Reference "CIS 1.1.2-1.1.6"
    
    Invoke-SecurityCheck -Check $check -TestScript {
        $mounts = Get-Content '/proc/mounts'
        $failures = @()
        
        foreach ($line in $mounts) {
            $parts = $line -split ' '
            if ($parts.Count -ge 4) {
                $mountpoint = $parts[1]
                $options = $parts[3]
                
                switch ($mountpoint) {
                    '/' {
                        if ($options -notmatch 'nosuid') {
                            $failures += "$mountpoint: missing nosuid option"
                        }
                    }
                    '/home' {
                        if ($options -notmatch 'nosuid') {
                            $failures += "$mountpoint: missing nosuid option"
                        }
                        if ($options -notmatch 'nodev') {
                            $failures += "$mountpoint: missing nodev option"
                        }
                    }
                    '/tmp' {
                        if ($options -notmatch 'nosuid') {
                            $failures += "$mountpoint: missing nosuid option"
                        }
                        if ($options -notmatch 'noexec') {
                            $failures += "$mountpoint: missing noexec option"
                        }
                        if ($options -notmatch 'nodev') {
                            $failures += "$mountpoint: missing nodev option"
                        }
                    }
                    '/var/tmp' {
                        if ($options -notmatch 'nosuid') {
                            $failures += "$mountpoint: missing nosuid option"
                        }
                        if ($options -notmatch 'noexec') {
                            $failures += "$mountpoint: missing noexec option"
                        }
                        if ($options -notmatch 'nodev') {
                            $failures += "$mountpoint: missing nodev option"
                        }
                    }
                }
            }
        }
        
        return $failures.Count -eq 0
        
    } -SuccessMessage "All critical mount points have appropriate options" `
      -FailureMessage "Missing mount options on critical partitions" `
      -Remediation "Add options in /etc/fstab: nosuid,noexec,nodev as appropriate"
}

function Test-TmpPermissions {
    $check = Register-Check -ID "FS-007" -Name "/tmp permissions" -Category "FileSystem" -Severity "Medium" -Reference "CIS 1.1.8"
    
    Invoke-SecurityCheck -Check $check -TestScript {
        if (Test-Path '/tmp') {
            $perms = Get-FilePermission -Path '/tmp'
            return $perms.Permissions -in @('1777', '1770')
        }
        return $false
        
    } -SuccessMessage "/tmp has correct permissions (sticky bit set)" `
      -FailureMessage "/tmp permissions are incorrect" `
      -Remediation "Set correct permissions: chmod 1777 /tmp"
}

function Test-StickyBit {
    $check = Register-Check -ID "FS-008" -Name "Sticky bit on world-writable dirs" -Category "FileSystem" -Severity "Medium" -Reference "CIS 1.1.23"
    
    Invoke-SecurityCheck -Check $check -TestScript {
        $findCmd = "find / -type d -perm -0002 ! -path '/proc/*' ! -path '/sys/*' ! -path '/dev/*' 2>/dev/null"
        $dirs = Invoke-Expression $findCmd
        
        $noSticky = @()
        foreach ($dir in $dirs) {
            $perms = Get-FilePermission -Path $dir
            if ($perms.Permissions -notmatch '1$') {
                $noSticky += $dir
            }
        }
        
        return $noSticky.Count -eq 0
        
    } -SuccessMessage "All world-writable directories have sticky bit set" `
      -FailureMessage "Found world-writable directories without sticky bit" `
      -Remediation "Set sticky bit: chmod +t <directory>"
}

function Test-FileIntegrityChecks {
    $check = Register-Check -ID "FS-009" -Name "File integrity monitoring" -Category "FileSystem" -Severity "High" -Reference "CIS 1.3.1"
    
    Invoke-SecurityCheck -Check $check -TestScript {
        # Check for AIDE or Tripwire
        $hasAIDE = Test-CommandExists 'aide'
        $hasTripwire = Test-CommandExists 'tripwire'
        $hasOssec = Test-Path '/var/ossec'
        
        return $hasAIDE -or $hasTripwire -or $hasOssec
        
    } -SuccessMessage "File integrity monitoring is configured" `
      -FailureMessage "No file integrity monitoring tool detected" `
      -Remediation "Install and configure AIDE or Tripwire for file integrity monitoring"
}

function Test-DiskEncryption {
    $check = Register-Check -ID "FS-010" -Name "Disk encryption" -Category "FileSystem" -Severity "High" -Reference "CIS 1.4.1"
    
    Invoke-SecurityCheck -Check $check -TestScript {
        # Check for LUKS encryption
        $luksDevices = lsblk -f 2>/dev/null | Select-String 'crypt'
        $hasLUKS = $luksDevices.Count -gt 0
        
        # Check for encrypted swap
        $swapEncrypted = swapon -s 2>/dev/null | Select-String 'crypt'
        
        return $hasLUKS -or $swapEncrypted
        
    } -SuccessMessage "Disk encryption is configured" `
      -FailureMessage "Disk encryption not detected" `
      -Remediation "Configure LUKS encryption for sensitive partitions"
}

Export-ModuleMember -Function Invoke-FileSystemScan