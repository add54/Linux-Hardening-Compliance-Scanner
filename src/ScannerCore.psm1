# Scanner Core Module
# Contains core functions and data structures

class CheckResult {
    [string]$ID
    [string]$Name
    [string]$Category
    [string]$Severity
    [string]$Status
    [string]$Message
    [string]$Remediation
    [string]$Reference
    [string]$Command
    [string]$Output
    [datetime]$Timestamp
    [hashtable]$Metadata

    CheckResult() {
        $this.Timestamp = [DateTime]::Now
        $this.Metadata = @{}
    }
}

class ComplianceProfile {
    [string]$Name
    [string]$Version
    [string]$Description
    [hashtable]$Settings
    [array]$Modules
    [hashtable]$Checks
    [int]$RequiredScore

    ComplianceProfile() {
        $this.Settings = @{}
        $this.Modules = @()
        $this.Checks = @{}
    }
}

class ScanReport {
    [string]$ScanID
    [datetime]$Timestamp
    [hashtable]$SystemInfo
    [string]$Profile
    [array]$Checks
    [hashtable]$Summary
    [int]$ComplianceScore
    [string]$RiskLevel
    [timespan]$ScanDuration

    ScanReport() {
        $this.Checks = @()
        $this.Summary = @{}
        $this.SystemInfo = @{}
    }
}

# Global check registry
$Global:CheckRegistry = @()

function Register-Check {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ID,

        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [ValidateSet('FileSystem', 'Authentication', 'Networking', 'Services', 'Kernel', 'Logging', 'Custom')]
        [string]$Category,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Critical', 'High', 'Medium', 'Low', 'Info')]
        [string]$Severity,

        [string]$Reference,

        [string]$Command
    )

    $check = [CheckResult]::new()
    $check.ID = $ID
    $check.Name = $Name
    $check.Category = $Category
    $check.Severity = $Severity
    $check.Reference = $Reference
    $check.Command = $Command

    $Global:CheckRegistry += $check
    return $check
}

function Update-Check {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [CheckResult]$Check,

        [Parameter(Mandatory=$true)]
        [ValidateSet('PASS', 'FAIL', 'WARN', 'SKIP', 'ERROR')]
        [string]$Status,

        [Parameter(Mandatory=$true)]
        [string]$Message,

        [string]$Remediation,

        [string]$Output
    )

    $Check.Status = $Status
    $Check.Message = $Message
    $Check.Remediation = $Remediation
    $Check.Output = $Output

    # Add to global results
    $Global:ScanResults.Checks += $Check

    # Log based on severity and status
    $logMessage = "[$($Check.ID)] $($Check.Name): $Status - $Message"

    switch ($Status) {
        'PASS' {
            if (-not $Global:ScannerConfig.Quiet) {
                Write-Host "  ✓ $($Check.Name)" -ForegroundColor Green
            }
        }
        'FAIL' {
            $color = switch ($Check.Severity) {
                'Critical' { 'Red' }
                'High' { 'DarkRed' }
                'Medium' { 'Yellow' }
                'Low' { 'Gray' }
                default { 'White' }
            }
            Write-Host "  ✗ $($Check.Name)" -ForegroundColor $color
            if ($Global:ScannerConfig.Verbose) {
                Write-Host "    $Message" -ForegroundColor Gray
                if ($Remediation) {
                    Write-Host "    Remediation: $Remediation" -ForegroundColor DarkYellow
                }
            }
        }
        'WARN' {
            Write-Host "  ! $($Check.Name)" -ForegroundColor Yellow
            if ($Global:ScannerConfig.Verbose) {
                Write-Host "    $Message" -ForegroundColor Gray
            }
        }
        'SKIP' {
            Write-Host "  » $($Check.Name)" -ForegroundColor Gray
        }
    }

    return $Check
}

function Invoke-SecurityCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [CheckResult]$Check,

        [Parameter(Mandatory=$true)]
        [scriptblock]$TestScript,

        [string]$SuccessMessage = "Check passed",

        [string]$FailureMessage = "Check failed",

        [string]$Remediation,

        [string]$Reference
    )

    try {
        $result = & $TestScript

        if ($result -eq $true) {
            Update-Check -Check $Check -Status 'PASS' -Message $SuccessMessage -Remediation $Remediation
        } else {
            Update-Check -Check $Check -Status 'FAIL' -Message $FailureMessage -Remediation $Remediation -Reference $Reference
        }
    }
    catch {
        Update-Check -Check $Check -Status 'ERROR' -Message "Check error: $_" -Remediation $Remediation
    }
}

function Get-SystemInfo {
    [CmdletBinding()]
    param()

    $info = @{}

    try {
        # Hostname
        $info.Hostname = [System.Net.Dns]::GetHostName()

        # OS Information
        if ($IsLinux) {
            if (Test-Path '/etc/os-release') {
                $osRelease = Get-Content '/etc/os-release' -Raw
                $info.Distribution = ($osRelease | Select-String '^PRETTY_NAME="([^"]+)"').Matches.Groups[1].Value
                $info.ID = ($osRelease | Select-String '^ID="?([^"\s]+)"?').Matches.Groups[1].Value
                $info.VersionID = ($osRelease | Select-String '^VERSION_ID="?([^"\s]+)"?').Matches.Groups[1].Value
            }
            $info.KernelVersion = (uname -r).Trim()
        } elseif ($IsWindows) {
            $info.Distribution = "Windows $(Get-CimInstance Win32_OperatingSystem).Caption"
            $info.KernelVersion = [System.Environment]::OSVersion.Version.ToString()
        } elseif ($IsMacOS) {
            $info.Distribution = "macOS $(sw_vers -productVersion)"
            $info.KernelVersion = (uname -r).Trim()
        }

        # Architecture
        $info.Architecture = [System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()

        # Current user
        $info.CurrentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

        # IP Address
        $info.IPAddress = (Test-Connection -ComputerName (hostname) -Count 1).IPv4Address.IPAddressToString

    }
    catch {
        Write-Verbose "Failed to gather system information: $_"
    }

    return $info
}

function Test-CommandExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command
    )

    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Invoke-SafeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,

        [int]$Timeout = 30,

        [switch]$IgnoreErrors
    )

    try {
        $output = Invoke-Expression $Command -ErrorAction Stop 2>&1
        return @{
            Success = $true
            Output = $output
            Error = $null
        }
    }
    catch {
        if ($IgnoreErrors) {
            return @{
                Success = $false
                Output = $null
                Error = $_.Exception.Message
            }
        } else {
            throw
        }
    }
}

function Get-FilePermission {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    try {
        $stat = stat -c "%a %U %G" $Path 2>$null
        if ($stat) {
            $parts = $stat -split ' '
            return @{
                Permissions = $parts[0]
                Owner = $parts[1]
                Group = $parts[2]
            }
        }
    }
    catch {
        # Fallback to PowerShell if stat fails
        $item = Get-Item $Path -Force
        return @{
            Permissions = [Convert]::ToString($item.Mode.value__, 8).PadLeft(3, '0')
            Owner = $item.GetAccessControl().Owner
            Group = 'Unknown'  # PowerShell doesn't easily get group on Linux
        }
    }
}

function Test-FileContains {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string]$Pattern,

        [switch]$ExactMatch
    )

    if (-not (Test-Path $Path)) {
        return $false
    }

    $content = Get-Content $Path -Raw
    if ($ExactMatch) {
        return $content -match "^$Pattern$"
    } else {
        return $content -match $Pattern
    }
}

function Get-ServiceStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ServiceName
    )

    if (Test-CommandExists 'systemctl') {
        $status = systemctl is-active $ServiceName 2>$null
        $enabled = systemctl is-enabled $ServiceName 2>$null

        return @{
            Running = $status -eq 'active'
            Enabled = $enabled -eq 'enabled'
            Status = $status
        }
    }
    elseif (Test-CommandExists 'service') {
        $output = service $ServiceName status 2>&1
        return @{
            Running = $output -match 'running|active'
            Enabled = $false  # Can't easily determine with service command
            Status = $output
        }
    }
    else {
        return @{
            Running = $false
            Enabled = $false
            Status = 'Unknown'
        }
    }
}

function Get-ListeningPorts {
    [CmdletBinding()]
    param()

    $ports = @()

    if (Test-CommandExists 'ss') {
        $output = ss -tuln
        foreach ($line in $output | Select-Object -Skip 1) {
            $parts = $line -split '\s+'
            if ($parts.Count -ge 5) {
                $address = $parts[4]
                if ($address -match ':(.+)$') {
                    $port = $matches[1]
                    $protocol = if ($parts[0] -match 'tcp') { 'TCP' } else { 'UDP' }

                    $ports += @{
                        Protocol = $protocol
                        Port = $port
                        Address = $address
                        Process = if ($parts.Count -ge 6) { $parts[5] } else { 'Unknown' }
                    }
                }
            }
        }
    }
    elseif (Test-CommandExists 'netstat') {
        $output = netstat -tuln
        foreach ($line in $output | Select-Object -Skip 2) {
            $parts = $line -split '\s+'
            if ($parts.Count -ge 4) {
                $address = $parts[3]
                if ($address -match ':(.+)$') {
                    $port = $matches[1]
                    $protocol = if ($parts[0] -match 'tcp') { 'TCP' } else { 'UDP' }

                    $ports += @{
                        Protocol = $protocol
                        Port = $port
                        Address = $address
                        Process = 'Unknown'
                    }
                }
            }
        }
    }

    return $ports
}

function Get-SysctlValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Parameter
    )

    try {
        $value = sysctl -n $Parameter 2>$null
        if ($value) {
            return $value.Trim()
        }

        # Try to read from /proc/sys
        $procPath = "/proc/sys/$($Parameter.Replace('.', '/'))"
        if (Test-Path $procPath) {
            return (Get-Content $procPath -Raw).Trim()
        }
    }
    catch {
        return $null
    }

    return $null
}

function Test-IsRoot {
    [CmdletBinding()]
    param()

    return [bool]([System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem -or
                  (id -u) -eq 0)
}

function Get-InstalledPackages {
    [CmdletBinding()]
    param(
        [string]$Name
    )

    $packages = @()

    if (Test-CommandExists 'dpkg') {
        if ($Name) {
            $output = dpkg -l $Name 2>$null
        } else {
            $output = dpkg -l 2>$null
        }

        foreach ($line in $output | Select-Object -Skip 5) {
            if ($line -match '^ii\s+(\S+)\s+(\S+)\s+(.+)$') {
                $packages += @{
                    Name = $matches[1]
                    Version = $matches[2]
                    Description = $matches[3]
                    Manager = 'dpkg'
                }
            }
        }
    }
    elseif (Test-CommandExists 'rpm') {
        if ($Name) {
            $output = rpm -qi $Name 2>$null
            if ($output -and $output[0] -match '^Name\s+:\s+(.+)$') {
                $packages += @{
                    Name = $matches[1]
                    Version = ($output | Where-Object { $_ -match '^Version\s+:\s+(.+)$' }).Split(':')[1].Trim()
                    Description = ($output | Where-Object { $_ -match '^Summary\s+:\s+(.+)$' }).Split(':')[1].Trim()
                    Manager = 'rpm'
                }
            }
        } else {
            $output = rpm -qa --queryformat '%{NAME}\t%{VERSION}\t%{SUMMARY}\n' 2>$null
            foreach ($line in $output) {
                $parts = $line -split '\t'
                if ($parts.Count -eq 3) {
                    $packages += @{
                        Name = $parts[0]
                        Version = $parts[1]
                        Description = $parts[2]
                        Manager = 'rpm'
                    }
                }
            }
        }
    }

    return $packages
}

function Test-PortOpen {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$Port,

        [string]$ComputerName = 'localhost',

        [int]$Timeout = 1
    )

    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $tcpClient.BeginConnect($ComputerName, $Port, $null, $null)
        $wait = $asyncResult.AsyncWaitHandle.WaitOne($Timeout * 1000, $false)

        if ($wait) {
            $tcpClient.EndConnect($asyncResult)
            $tcpClient.Close()
            return $true
        } else {
            $tcpClient.Close()
            return $false
        }
    }
    catch {
        return $false
    }
}

function Get-UserAccounts {
    [CmdletBinding()]
    param(
        [switch]$SystemAccounts,

        [switch]$HumanAccounts
    )

    $users = @()
    $passwd = Get-Content '/etc/passwd'

    foreach ($line in $passwd) {
        $parts = $line -split ':'
        if ($parts.Count -ge 7) {
            $uid = [int]$parts[2]
            $isSystem = $uid -lt 1000 -or $uid -eq 65534  # nobody

            if (($SystemAccounts -and $isSystem) -or
                ($HumanAccounts -and -not $isSystem) -or
                (-not $SystemAccounts -and -not $HumanAccounts)) {

                $users += @{
                    Username = $parts[0]
                    UID = $uid
                    GID = [int]$parts[3]
                    FullName = $parts[4]
                    Home = $parts[5]
                    Shell = $parts[6]
                    IsSystem = $isSystem
                }
            }
        }
    }

    return $users
}

function Get-GroupMembership {
    [CmdletBinding()]
    param(
        [string]$Username
    )

    $groups = @()

    if ($Username) {
        $output = groups $Username 2>$null
        if ($output) {
            $groupList = $output -split ' '
            foreach ($group in $groupList) {
                $groups += @{
                    Name = $group
                    Members = @($Username)
                }
            }
        }
    } else {
        $groupFile = Get-Content '/etc/group'
        foreach ($line in $groupFile) {
            $parts = $line -split ':'
            if ($parts.Count -ge 4) {
                $members = if ($parts[3]) { $parts[3] -split ',' } else { @() }
                $groups += @{
                    Name = $parts[0]
                    GID = [int]$parts[2]
                    Members = $members
                }
            }
        }
    }

    return $groups
}

function Test-FileIntegrity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [string]$ExpectedHash,

        [ValidateSet('MD5', 'SHA1', 'SHA256', 'SHA512')]
        [string]$Algorithm = 'SHA256'
    )

    if (-not (Test-Path $Path)) {
        return @{
            Success = $false
            Message = "File not found: $Path"
            Hash = $null
        }
    }

    try {
        $hashAlgo = [System.Security.Cryptography.HashAlgorithm]::Create($Algorithm)
        $fileStream = [System.IO.File]::OpenRead($Path)
        $hash = [BitConverter]::ToString($hashAlgo.ComputeHash($fileStream)) -replace '-', ''
        $fileStream.Close()

        $isValid = if ($ExpectedHash) { $hash -eq $ExpectedHash.ToUpper() } else { $true }

        return @{
            Success = $isValid
            Message = if ($isValid) { "File integrity verified" } else { "File hash mismatch" }
            Hash = $hash
            Algorithm = $Algorithm
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Failed to compute hash: $_"
            Hash = $null
        }
    }
}

function Get-LogFiles {
    [CmdletBinding()]
    param(
        [string]$Pattern = '*.log',

        [string]$Directory = '/var/log'
    )

    $logs = @()

    if (Test-Path $Directory) {
        $files = Get-ChildItem -Path $Directory -Filter $Pattern -Recurse -File -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $logs += @{
                Name = $file.Name
                Path = $file.FullName
                Size = $file.Length
                LastModified = $file.LastWriteTime
                Permissions = Get-FilePermission -Path $file.FullName
            }
        }
    }

    return $logs
}

function Test-AuditRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [string]$User,

        [string]$Permission
    )

    if (-not (Test-Path $Path)) {
        return $false
    }

    try {
        $acl = Get-Acl $Path
        foreach ($rule in $acl.Access) {
            if ((-not $User -or $rule.IdentityReference.Value -eq $User) -and
                (-not $Permission -or $rule.FileSystemRights.ToString() -match $Permission)) {
                return $true
            }
        }
    }
    catch {
        Write-Verbose "Failed to check audit rule: $_"
    }

    return $false
}

function Get-SystemHealth {
    [CmdletBinding()]
    param()

    $health = @{
        CPU = @{}
        Memory = @{}
        Disk = @{}
        Load = @{}
    }

    try {
        # CPU usage
        $cpuStats = Get-Content '/proc/stat' -First 1
        $parts = $cpuStats -split '\s+'
        if ($parts.Count -ge 8) {
            $total = 0
            $idle = [int]$parts[4]
            for ($i = 1; $i -le 7; $i++) {
                $total += [int]$parts[$i]
            }
            $health.CPU.Usage = [math]::Round((($total - $idle) * 100 / $total), 2)
        }

        # Memory usage
        $memInfo = Get-Content '/proc/meminfo'
        $total = ($memInfo | Where-Object { $_ -match '^MemTotal:' } | ForEach-Object { [regex]::Match($_, '\d+').Value })[0]
        $free = ($memInfo | Where-Object { $_ -match '^MemFree:' } | ForEach-Object { [regex]::Match($_, '\d+').Value })[0]
        $available = ($memInfo | Where-Object { $_ -match '^MemAvailable:' } | ForEach-Object { [regex]::Match($_, '\d+').Value })[0]

        if ($total -and $available) {
            $health.Memory.Usage = [math]::Round((($total - $available) * 100 / $total), 2)
            $health.Memory.TotalMB = [math]::Round($total / 1024, 2)
            $health.Memory.AvailableMB = [math]::Round($available / 1024, 2)
        }

        # Load average
        $load = Get-Content '/proc/loadavg'
        $loadParts = $load -split ' '
        $health.Load.Last1Min = [double]$loadParts[0]
        $health.Load.Last5Min = [double]$loadParts[1]
        $health.Load.Last15Min = [double]$loadParts[2]

        # Disk usage
        $diskInfo = df -h / | Select-Object -Skip 1
        if ($diskInfo) {
            $diskParts = $diskInfo -split '\s+'
            $health.Disk.Usage = $diskParts[4].TrimEnd('%')
            $health.Disk.Available = $diskParts[3]
            $health.Disk.Total = $diskParts[1]
            $health.Disk.Used = $diskParts[2]
        }

        # Uptime
        $uptime = (Get-Content '/proc/uptime' -ErrorAction SilentlyContinue) -split ' ' | Select-Object -First 1
        if ($uptime) {
            $health.Uptime = [TimeSpan]::FromSeconds([double]$uptime)
        }

        # Process count
        $health.ProcessCount = (Get-Process).Count

        # Zombie processes
        $zombies = ps aux | Where-Object { $_ -match 'Z' } | Measure-Object
        $health.ZombieProcesses = $zombies.Count

    }
    catch {
        Write-Verbose "Failed to get system health: $_"
    }

    return $health
}

function Export-Report {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Results,

        [Parameter(Mandatory=$true)]
        [ValidateSet('JSON', 'XML', 'CSV', 'HTML', 'Text')]
        [string]$Format,

        [string]$Path
    )

    $exportPath = if ($Path) { $Path } else { "scan_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').$($Format.ToLower())" }

    switch ($Format) {
        'JSON' {
            $Results | ConvertTo-Json -Depth 10 | Out-File $exportPath
        }
        'XML' {
            $Results | ConvertTo-Xml -NoTypeInformation | Out-File $exportPath
        }
        'CSV' {
            $Results.Checks | Export-Csv $exportPath -NoTypeInformation
        }
        'HTML' {
            # Generate HTML report
            $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Security Scan Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .pass { background-color: #d4edda; }
        .fail { background-color: #f8d7da; }
        .warn { background-color: #fff3cd; }
        .skip { background-color: #e2e3e5; }
    </style>
</head>
<body>
    <h1>Security Scan Report</h1>
    <p>Generated: $(Get-Date)</p>
    <p>Scan ID: $($Results.ScanID)</p>

    <h2>Summary</h2>
    <table>
        <tr><th>Total Checks</th><td>$($Results.Summary.TotalChecks)</td></tr>
        <tr><th>Passed</th><td>$($Results.Summary.Passed)</td></tr>
        <tr><th>Failed</th><td>$($Results.Summary.Failed)</td></tr>
        <tr><th>Warnings</th><td>$($Results.Summary.Warning)</td></tr>
        <tr><th>Compliance Score</th><td>$($Results.ComplianceScore)%</td></tr>
    </table>

    <h2>Checks</h2>
    <table>
        <tr>
            <th>ID</th><th>Name</th><th>Category</th><th>Severity</th>
            <th>Status</th><th>Message</th>
        </tr>
"@

            foreach ($check in $Results.Checks) {
                $class = $check.Status.ToLower()
                $html += @"
        <tr class="$class">
            <td>$($check.ID)</td>
            <td>$($check.Name)</td>
            <td>$($check.Category)</td>
            <td>$($check.Severity)</td>
            <td>$($check.Status)</td>
            <td>$($check.Message)</td>
        </tr>
"@
            }

            $html += @"
    </table>
</body>
</html>
"@

            $html | Out-File $exportPath
        }
        'Text' {
            $text = @"
SECURITY SCAN REPORT
====================

Scan ID: $($Results.ScanID)
Generated: $(Get-Date)
Profile: $($Results.Profile)

SUMMARY
-------
Total Checks: $($Results.Summary.TotalChecks)
Passed: $($Results.Summary.Passed)
Failed: $($Results.Summary.Failed)
Warnings: $($Results.Summary.Warning)
Compliance Score: $($Results.ComplianceScore)%

CHECKS
------
"@

            foreach ($check in $Results.Checks) {
                $text += @"
[$($check.ID)] $($check.Name)
  Status: $($check.Status)
  Severity: $($check.Severity)
  Message: $($check.Message)
  $($check.Remediation)
"@
            }

            $text | Out-File $exportPath
        }
    }

    Write-Host "Report exported to: $exportPath" -ForegroundColor Green
    return $exportPath
}

# Export module functions
Export-ModuleMember -Function *
