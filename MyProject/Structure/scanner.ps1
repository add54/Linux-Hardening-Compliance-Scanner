#!/usr/bin/env pwsh
# Linux Hardening & Compliance Scanner - PowerShell Edition
# Version: 2.0.0

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet('cis_level1', 'cis_level2', 'pci_dss', 'nist_800_53', 'custom')]
    [string]$Profile = 'cis_level1',
    
    [Parameter()]
    [ValidateSet('Text', 'JSON', 'HTML', 'CSV', 'XML')]
    [string]$OutputFormat = 'Text',
    
    [Parameter()]
    [string]$OutputFile,
    
    [Parameter()]
    [switch]$Fix,
    
    [Parameter()]
    [switch]$Verbose,
    
    [Parameter()]
    [switch]$Quiet,
    
    [Parameter()]
    [switch]$NoColor,
    
    [Parameter()]
    [switch]$Export,
    
    [Parameter()]
    [string[]]$Exclude,
    
    [Parameter()]
    [string[]]$IncludeOnly,
    
    [Parameter()]
    [switch]$SkipModules,
    
    [Parameter()]
    [int]$Timeout = 3600,
    
    [Parameter()]
    [switch]$Version,
    
    [Parameter()]
    [switch]$Help
)

# Set strict mode
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# Import modules
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. $ScriptDir\src\ScannerCore.psm1
. $ScriptDir\src\Utilities\OutputFormatter.psm1
. $ScriptDir\src\Utilities\ComplianceScorer.psm1
. $ScriptDir\src\Utilities\DistroDetector.psm1

# Global variables
$Global:ScannerConfig = @{
    ScanID = [DateTime]::Now.ToString('yyyyMMdd_HHmmss')
    StartTime = [DateTime]::Now
    Profile = $Profile
    OutputFormat = $OutputFormat
    OutputFile = $OutputFile
    FixMode = $Fix
    Verbose = $Verbose
    Quiet = $Quiet
    NoColor = $NoColor
    Export = $Export
    Exclude = $Exclude
    IncludeOnly = $IncludeOnly
    Timeout = $Timeout
}

# Results storage
$Global:ScanResults = @{
    Checks = @()
    Summary = @{
        TotalChecks = 0
        Passed = 0
        Failed = 0
        Warning = 0
        Skipped = 0
        Critical = 0
        High = 0
        Medium = 0
        Low = 0
    }
    SystemInfo = @{}
    ComplianceScore = 0
    RiskLevel = 'Unknown'
}

function Show-Help {
    @"
Linux Hardening & Compliance Scanner - PowerShell Edition
Version: 2.0.0

Usage: scanner.ps1 [OPTIONS]

Options:
  -Profile <profile>       Compliance profile (cis_level1, cis_level2, pci_dss, nist_800_53, custom)
  -OutputFormat <format>   Output format (Text, JSON, HTML, CSV, XML)
  -OutputFile <file>       Write output to file
  -Fix                     Attempt automatic remediation (experimental)
  -Verbose                 Show detailed output
  -Quiet                   Suppress non-essential output
  -NoColor                 Disable colored output
  -Export                  Export results to results/ directory
  -Exclude <modules>       Exclude specific modules (comma-separated)
  -IncludeOnly <modules>   Include only specific modules
  -SkipModules             Skip module loading (for debugging)
  -Timeout <seconds>       Maximum scan duration (default: 3600)
  -Version                 Show version information
  -Help                    Show this help message

Examples:
  .\scanner.ps1 -Profile cis_level1
  .\scanner.ps1 -Profile pci_dss -OutputFormat JSON -OutputFile scan.json
  .\scanner.ps1 -Profile cis_level1 -Verbose -Export
  .\scanner.ps1 -Profile custom -Exclude "Networking,Services"

Compliance Profiles:
  cis_level1    - CIS Level 1 Benchmark (Basic security)
  cis_level2    - CIS Level 2 Benchmark (Enhanced security)
  pci_dss       - PCI DSS Compliance
  nist_800_53   - NIST 800-53 Controls
  custom        - Custom profile from config/Custom-Profile.json

Modules:
  FileSystem      - File permissions, SUID/SGID, mount options
  Authentication  - Users, passwords, SSH, PAM, sudo
  Networking      - Firewall, ports, kernel parameters
  Services        - Running services, service hardening
  Kernel          - Kernel parameters, module hardening
  Logging         - Audit configuration, log management

Exit Codes:
  0 - Scan completed successfully, no critical failures
  1 - Scan completed with critical failures
  2 - Invalid arguments or configuration error
  3 - Scanner initialization failed
  4 - Timeout or execution error
"@
}

function Initialize-Scanner {
    [CmdletBinding()]
    param()
    
    Write-Host "`n================================================" -ForegroundColor Cyan
    Write-Host "    LINUX HARDENING COMPLIANCE SCANNER" -ForegroundColor Cyan
    Write-Host "    PowerShell Edition v2.0.0" -ForegroundColor Cyan
    Write-Host "================================================`n" -ForegroundColor Cyan
    
    # Check if running on Linux
    if ($IsLinux -eq $false) {
        Write-Warning "This scanner is designed for Linux systems. Some checks may not work on other platforms."
    }
    
    # Check for required commands
    $requiredCommands = @('bash', 'grep', 'awk', 'sed', 'find', 'stat')
    $missingCommands = @()
    
    foreach ($cmd in $requiredCommands) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            $missingCommands += $cmd
        }
    }
    
    if ($missingCommands.Count -gt 0) {
        Write-Warning "Missing required commands: $($missingCommands -join ', ')"
        Write-Warning "Some checks may not work properly."
    }
    
    # Load profile
    $profilePath = Join-Path $ScriptDir "config\$($Profile.ToUpper() -replace '_', '-').json"
    if (Test-Path $profilePath) {
        $profileConfig = Get-Content $profilePath | ConvertFrom-Json
        $Global:ScannerConfig.ProfileConfig = $profileConfig
        Write-Verbose "Loaded profile: $Profile"
    } else {
        Write-Error "Profile not found: $Profile"
        Write-Host "Available profiles:" -ForegroundColor Yellow
        Get-ChildItem (Join-Path $ScriptDir "config\*.json") | ForEach-Object {
            Write-Host "  - $($_.BaseName)" -ForegroundColor Gray
        }
        exit 2
    }
    
    # Gather system information
    $Global:ScanResults.SystemInfo = Get-SystemInfo
    
    Write-Host "Scan ID:      $($Global:ScannerConfig.ScanID)" -ForegroundColor Gray
    Write-Host "Profile:      $Profile" -ForegroundColor Gray
    Write-Host "Hostname:     $($Global:ScanResults.SystemInfo.Hostname)" -ForegroundColor Gray
    Write-Host "Distribution: $($Global:ScanResults.SystemInfo.Distribution)" -ForegroundColor Gray
    Write-Host "Kernel:       $($Global:ScanResults.SystemInfo.KernelVersion)" -ForegroundColor Gray
    Write-Host ""
}

function Invoke-SecurityScan {
    [CmdletBinding()]
    param()
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        # Determine which modules to run
        $modulesToRun = @()
        
        if ($Global:ScannerConfig.IncludeOnly.Count -gt 0) {
            $modulesToRun = $Global:ScannerConfig.IncludeOnly
        } else {
            # Load all enabled modules from profile
            $modulesToRun = $Global:ScannerConfig.ProfileConfig.Modules | Where-Object { $_.Enabled -eq $true } | Select-Object -ExpandProperty Name
        }
        
        # Apply exclusions
        if ($Global:ScannerConfig.Exclude.Count -gt 0) {
            $modulesToRun = $modulesToRun | Where-Object { $_ -notin $Global:ScannerConfig.Exclude }
        }
        
        Write-Host "Running security checks..." -ForegroundColor Cyan
        Write-Host "Modules: $($modulesToRun -join ', ')`n" -ForegroundColor Gray
        
        # Run modules
        foreach ($module in $modulesToRun) {
            Write-Host "=== $module ===" -ForegroundColor Yellow
            
            $modulePath = Join-Path $ScriptDir "src\Modules\${module}Scanner.psm1"
            if (Test-Path $modulePath) {
                # Import and run module
                . $modulePath
                
                $moduleFunction = "Invoke-${module}Scan"
                if (Get-Command $moduleFunction -ErrorAction SilentlyContinue) {
                    & $moduleFunction
                } else {
                    Write-Warning "Module function not found: $moduleFunction"
                }
                
                # Remove module to avoid conflicts
                Remove-Module -Name "${module}Scanner" -ErrorAction SilentlyContinue
            } else {
                Write-Warning "Module not found: $module"
            }
            
            Write-Host ""
        }
        
        $stopwatch.Stop()
        $Global:ScanResults.ScanDuration = $stopwatch.Elapsed
        
        # Calculate compliance score
        $Global:ScanResults.ComplianceScore = Calculate-ComplianceScore -Results $Global:ScanResults.Checks
        $Global:ScanResults.RiskLevel = Get-RiskLevel -Score $Global:ScanResults.ComplianceScore
        
        # Update summary
        $Global:ScanResults.Summary.TotalChecks = $Global:ScanResults.Checks.Count
        $Global:ScanResults.Summary.Passed = ($Global:ScanResults.Checks | Where-Object { $_.Status -eq 'PASS' }).Count
        $Global:ScanResults.Summary.Failed = ($Global:ScanResults.Checks | Where-Object { $_.Status -eq 'FAIL' }).Count
        $Global:ScanResults.Summary.Warning = ($Global:ScanResults.Checks | Where-Object { $_.Status -eq 'WARN' }).Count
        $Global:ScanResults.Summary.Skipped = ($Global:ScanResults.Checks | Where-Object { $_.Status -eq 'SKIP' }).Count
        $Global:ScanResults.Summary.Critical = ($Global:ScanResults.Checks | Where-Object { $_.Severity -eq 'Critical' -and $_.Status -eq 'FAIL' }).Count
        $Global:ScanResults.Summary.High = ($Global:ScanResults.Checks | Where-Object { $_.Severity -eq 'High' -and $_.Status -eq 'FAIL' }).Count
        $Global:ScanResults.Summary.Medium = ($Global:ScanResults.Checks | Where-Object { $_.Severity -eq 'Medium' -and $_.Status -eq 'FAIL' }).Count
        $Global:ScanResults.Summary.Low = ($Global:ScanResults.Checks | Where-Object { $_.Severity -eq 'Low' -and $_.Status -eq 'FAIL' }).Count
        
        return $true
    }
    catch {
        Write-Error "Scan failed: $_"
        return $false
    }
}

function Export-Results {
    [CmdletBinding()]
    param()
    
    if (-not $Global:ScannerConfig.Export) {
        return
    }
    
    $exportDir = Join-Path $ScriptDir "results\$($Global:ScannerConfig.ScanID)"
    New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
    
    # Export raw results
    $Global:ScanResults | ConvertTo-Json -Depth 10 | Out-File (Join-Path $exportDir "results.json")
    
    # Export summary
    $summary = @"
Scan ID: $($Global:ScannerConfig.ScanID)
Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Profile: $($Global:ScannerConfig.Profile)
Hostname: $($Global:ScanResults.SystemInfo.Hostname)
Distribution: $($Global:ScanResults.SystemInfo.Distribution)
Kernel: $($Global:ScanResults.SystemInfo.KernelVersion)
Scan Duration: $($Global:ScanResults.ScanDuration)
Total Checks: $($Global:ScanResults.Summary.TotalChecks)
Passed: $($Global:ScanResults.Summary.Passed)
Failed: $($Global:ScanResults.Summary.Failed)
Warnings: $($Global:ScanResults.Summary.Warning)
Skipped: $($Global:ScanResults.Summary.Skipped)
Compliance Score: $($Global:ScanResults.ComplianceScore)%
Risk Level: $($Global:ScanResults.RiskLevel)
"@
    
    $summary | Out-File (Join-Path $exportDir "summary.txt")
    
    # Export by category
    $categories = $Global:ScanResults.Checks | Group-Object Category
    foreach ($category in $categories) {
        $categoryResults = $category.Group | Select-Object ID, Name, Severity, Status, Message
        $categoryResults | ConvertTo-Json | Out-File (Join-Path $exportDir "$($category.Name).json")
    }
    
    Write-Host "Results exported to: $exportDir" -ForegroundColor Green
}

function Show-Summary {
    [CmdletBinding()]
    param()
    
    $score = $Global:ScanResults.ComplianceScore
    $riskLevel = $Global:ScanResults.RiskLevel
    
    Write-Host "`n================================================" -ForegroundColor Cyan
    Write-Host "                 SCAN SUMMARY" -ForegroundColor Cyan
    Write-Host "================================================`n" -ForegroundColor Cyan
    
    Write-Host "Total Checks: $($Global:ScanResults.Summary.TotalChecks)" -ForegroundColor Gray
    Write-Host "Passed:       $($Global:ScanResults.Summary.Passed)" -ForegroundColor Green
    Write-Host "Failed:       $($Global:ScanResults.Summary.Failed)" -ForegroundColor Red
    Write-Host "Warnings:     $($Global:ScanResults.Summary.Warning)" -ForegroundColor Yellow
    Write-Host "Skipped:      $($Global:ScanResults.Summary.Skipped)" -ForegroundColor Gray
    Write-Host "Scan Duration: $($Global:ScanResults.ScanDuration.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
    
    Write-Host "`n----------------------------------------------" -ForegroundColor DarkGray
    
    # Show compliance score with color
    $scoreColor = switch ($score) {
        { $_ -ge 90 } { 'Green' }
        { $_ -ge 70 } { 'Yellow' }
        default { 'Red' }
    }
    
    Write-Host "COMPLIANCE SCORE: $score%" -ForegroundColor $scoreColor
    Write-Host "RISK LEVEL: $riskLevel" -ForegroundColor $scoreColor
    
    Write-Host "`n----------------------------------------------" -ForegroundColor DarkGray
    
    # Show failed checks by severity
    if ($Global:ScanResults.Summary.Critical -gt 0) {
        Write-Host "Critical Failures: $($Global:ScanResults.Summary.Critical)" -ForegroundColor Red
    }
    if ($Global:ScanResults.Summary.High -gt 0) {
        Write-Host "High Failures:     $($Global:ScanResults.Summary.High)" -ForegroundColor DarkRed
    }
    if ($Global:ScanResults.Summary.Medium -gt 0) {
        Write-Host "Medium Failures:   $($Global:ScanResults.Summary.Medium)" -ForegroundColor Yellow
    }
    if ($Global:ScanResults.Summary.Low -gt 0) {
        Write-Host "Low Failures:      $($Global:ScanResults.Summary.Low)" -ForegroundColor Gray
    }
    
    Write-Host "`n================================================" -ForegroundColor Cyan
    
    # Show critical findings
    $criticalChecks = $Global:ScanResults.Checks | Where-Object { $_.Severity -eq 'Critical' -and $_.Status -eq 'FAIL' }
    if ($criticalChecks.Count -gt 0) {
        Write-Host "`nCRITICAL FINDINGS ($($criticalChecks.Count)):" -ForegroundColor Red
        foreach ($check in $criticalChecks) {
            Write-Host "  [$($check.ID)] $($check.Name)" -ForegroundColor Red
            Write-Host "      $($check.Message)" -ForegroundColor Gray
            if ($check.Remediation) {
                Write-Host "      Remediation: $($check.Remediation)" -ForegroundColor DarkYellow
            }
        }
    }
}

# Main execution flow
function Main {
    # Handle help and version
    if ($Help) {
        Show-Help
        exit 0
    }
    
    if ($Version) {
        Write-Host "Linux Hardening Scanner - PowerShell Edition v2.0.0"
        exit 0
    }
    
    # Initialize scanner
    Initialize-Scanner
    
    # Run security scan
    $scanSuccess = Invoke-SecurityScan
    
    if (-not $scanSuccess) {
        Write-Error "Security scan failed"
        exit 4
    }
    
    # Generate output
    switch ($OutputFormat) {
        'Text' {
            Format-TextReport -Results $Global:ScanResults
        }
        'JSON' {
            Format-JsonReport -Results $Global:ScanResults
        }
        'HTML' {
            Format-HtmlReport -Results $Global:ScanResults
        }
        'CSV' {
            Format-CsvReport -Results $Global:ScanResults
        }
        'XML' {
            Format-XmlReport -Results $Global:ScanResults
        }
    }
    
    # Export results if requested
    Export-Results
    
    # Show summary
    Show-Summary
    
    # Set exit code
    if ($Global:ScanResults.Summary.Critical -gt 0) {
        exit 1
    } else {
        exit 0
    }
}

# Run main function
try {
    Main
}
catch {
    Write-Error "Scanner error: $_"
    Write-Error $_.ScriptStackTrace
    exit 3
}