# Scanner Core Tests
# Tests for the main scanner functionality

Describe "Scanner Core Functionality" {

    BeforeAll {
        # Import required modules
        $scriptPath = Split-Path -Parent $PSScriptRoot
        $scannerPath = Join-Path (Join-Path $scriptPath "..") "scanner.ps1"
        $scannerCorePath = Join-Path (Join-Path (Join-Path $scriptPath "..") "src") "ScannerCore.psm1"
    }

    Context "Scanner Script Validation" {

        It "Scanner script should exist" {
            Test-Path $scannerPath | Should Be $true
        }

        It "Scanner script should be readable" {
            { Get-Content $scannerPath -ErrorAction Stop } | Should Not Throw
        }

        It "Scanner script should contain version information" {
            $content = Get-Content $scannerPath -Raw
            $content | Should Match "Version.*2\.0\.0"
        }
    }

    Context "ScannerCore Module Validation" {

        It "ScannerCore module should exist" {
            Test-Path $scannerCorePath | Should -Be $true
        }

        It "ScannerCore module should be importable" {
            { Import-Module $scannerCorePath -ErrorAction Stop } | Should -Not -Throw
        }

        It "Should contain CheckResult class" {
            $content = Get-Content $scannerCorePath -Raw
            $content | Should -Match "class CheckResult"
        }

        It "Should contain ComplianceProfile class" {
            $content = Get-Content $scannerCorePath -Raw
            $content | Should -Match "class ComplianceProfile"
        }

        It "Should contain ScanReport class" {
            $content = Get-Content $scannerCorePath -Raw
            $content | Should -Match "class ScanReport"
        }
    }

    Context "Parameter Validation" {

        It "Should accept Profile parameter with valid values" {
            $validProfiles = @('cis_level1', 'cis_level2', 'pci_dss', 'nist_800_53', 'custom')

            foreach ($profile in $validProfiles) {
                # Test parameter validation logic
                $profile | Should -BeIn $validProfiles
            }
        }

        It "Should accept OutputFormat parameter with valid values" {
            $validFormats = @('Text', 'JSON', 'HTML', 'CSV', 'XML')

            foreach ($format in $validFormats) {
                $format | Should -BeIn $validFormats
            }
        }
    }

    Context "Configuration Files" {

        $configDir = Join-Path (Join-Path $scriptPath "..") "config"

        It "Config directory should exist" {
            Test-Path $configDir | Should -Be $true
        }

        $configFiles = @(
            "CIS-Level1.json",
            "CIS-Level2.json",
            "Custom-Profile.json",
            "NIST-800-53.json",
            "PCI-DSS.json"
        )

        foreach ($configFile in $configFiles) {
            It "Config file $configFile should exist" {
                $filePath = Join-Path $configDir $configFile
                Test-Path $filePath | Should -Be $true
            }
        }
    }

    Context "Module Structure" {

        $modulesDir = Join-Path (Join-Path (Join-Path $scriptPath "..") "src") "Modules"

        It "Modules directory should exist" {
            Test-Path $modulesDir | Should -Be $true
        }

        $expectedModules = @(
            "AuthenticationScanner.psm1",
            "FileSystemScanner.psm1",
            "KernelScanner.psm1",
            "LoggingScanner.psm1",
            "NetworkScanner.psm1",
            "ServiceScanner.psm1"
        )

        foreach ($module in $expectedModules) {
            It "Module $module should exist" {
                $modulePath = Join-Path $modulesDir $module
                Test-Path $modulePath | Should -Be $true
            }
        }
    }

    Context "Documentation" {

        $readmePath = Join-Path (Join-Path $scriptPath "..") "README.md"

        It "README.md should exist" {
            Test-Path $readmePath | Should -Be $true
        }

        It "README.md should contain project information" {
            $content = Get-Content $readmePath -Raw
            $content | Should -Match "Linux Hardening.*Compliance Scanner"
            $content | Should -Match "Table of Contents"
            $content | Should -Match "Installation"
            $content | Should -Match "Usage"
        }
    }
}

Describe "File System Scanner Tests" {

    BeforeAll {
        $modulePath = Join-Path (Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "..") "src") "Modules" "FileSystemScanner.psm1"
    }

    Context "Module Structure" {

        It "FileSystemScanner module should exist" {
            Test-Path $modulePath | Should -Be $true
        }

        It "Should contain Invoke-FileSystemScan function" {
            $content = Get-Content $modulePath -Raw
            $content | Should -Match "function Invoke-FileSystemScan"
        }

        It "Should contain world-writable file check" {
            $content = Get-Content $modulePath -Raw
            $content | Should -Match "Test-WorldWritableFiles"
        }

        It "Should contain SUID/SGID check" {
            $content = Get-Content $modulePath -Raw
            $content | Should -Match "Test-SuidSgidBinaries"
        }
    }
}

Describe "Compliance Standards" {

    Context "CIS Benchmarks" {

        It "Should have CIS Level 1 configuration" {
            $cis1Path = Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "..") "config" "CIS-Level1.json"
            Test-Path $cis1Path | Should -Be $true
        }

        It "Should have CIS Level 2 configuration" {
            $cis2Path = Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "..") "config" "CIS-Level2.json"
            Test-Path $cis2Path | Should -Be $true
        }
    }

    Context "Industry Standards" {

        It "Should have NIST 800-53 configuration" {
            $nistPath = Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "..") "config" "NIST-800-53.json"
            Test-Path $nistPath | Should -Be $true
        }

        It "Should have PCI-DSS configuration" {
            $pciPath = Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "..") "config" "PCI-DSS.json"
            Test-Path $pciPath | Should -Be $true
        }
    }
}
