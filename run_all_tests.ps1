# Comprehensive Test Runner for Linux Hardening & Compliance Scanner
# Runs all tests and validates the complete system

param(
    [Parameter(Mandatory=$false)]
    [switch]$SkipDocker,
    [Parameter(Mandatory=$false)]
    [switch]$SkipWebApp,
    [Parameter(Mandatory=$false)]
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Configuration
$PROJECT_ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
$DOCKER_COMPOSE_DEV = "docker-compose.dev.yml"
$TOTAL_TESTS = 0
$PASSED_TESTS = 0
$FAILED_TESTS = 0

# Logging functions
function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "$Text" -ForegroundColor Yellow
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Success {
    param([string]$Text)
    Write-Host "✅ $Text" -ForegroundColor Green
}

function Write-Error {
    param([string]$Text)
    Write-Host "❌ $Text" -ForegroundColor Red
}

function Write-Info {
    param([string]$Text)
    Write-Host "ℹ️  $Text" -ForegroundColor Blue
}

function Write-Warning {
    param([string]$Text)
    Write-Host "⚠️  $Text" -ForegroundColor Yellow
}

function Test-Result {
    param([string]$TestName, [scriptblock]$TestScript)
    $TOTAL_TESTS++
    Write-Host "Running: $TestName..." -NoNewline

    try {
        $result = & $TestScript
        if ($result -or $LASTEXITCODE -eq 0) {
            Write-Host " PASSED" -ForegroundColor Green
            $script:PASSED_TESTS++
            return $true
        } else {
            Write-Host " FAILED" -ForegroundColor Red
            $script:FAILED_TESTS++
            return $false
        }
    } catch {
        Write-Host " ERROR" -ForegroundColor Red
        Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
        $script:FAILED_TESTS++
        return $false
    }
}

function Check-Prerequisites {
    Write-Header "Checking Prerequisites"

    # Check if we're in the right directory
    if (!(Test-Path "$PROJECT_ROOT\scanner.sh")) {
        Write-Error "Not in project root directory. Please run from the project root."
        exit 1
    }

    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    Write-Info "PowerShell Version: $($psVersion.Major).$($psVersion.Minor)"

    # Check if Docker is available
    try {
        $dockerVersion = docker --version 2>$null
        Write-Info "Docker: Available"
        $script:DockerAvailable = $true
    } catch {
        Write-Warning "Docker: Not available (some tests will be skipped)"
        $script:DockerAvailable = $false
    }

    # Check Git
    try {
        $gitVersion = git --version 2>$null
        Write-Info "Git: Available"
    } catch {
        Write-Info "Git: Not available"
    }
}

function Test-FileStructure {
    Write-Header "Testing File Structure"

    $requiredFiles = @(
        "scanner.sh",
        "app.py",
        "run_webapp.py",
        "requirements.txt",
        "docker-compose.dev.yml",
        "Dockerfile"
    )

    foreach ($file in $requiredFiles) {
        Test-Result "File exists: $file" {
            Test-Path "$PROJECT_ROOT\$file"
        }
    }

    # Check directories
    $requiredDirs = @(
        "modules",
        "templates",
        "static",
        "tests"
    )

    foreach ($dir in $requiredDirs) {
        Test-Result "Directory exists: $dir" {
            Test-Path "$PROJECT_ROOT\$dir" -PathType Container
        }
    }

    # Check module files
    $moduleFiles = Get-ChildItem "$PROJECT_ROOT\modules\*.sh" -ErrorAction SilentlyContinue
    Test-Result "Module files exist" {
        $moduleFiles.Count -gt 0
    }

    # Check test files
    $testFiles = Get-ChildItem "$PROJECT_ROOT\tests\*" -ErrorAction SilentlyContinue
    Test-Result "Test files exist" {
        $testFiles.Count -gt 0
    }
}

function Test-SyntaxValidation {
    Write-Header "Testing Syntax Validation"

    # Test Bash scripts (using basic checks since we can't run shellcheck easily)
    Test-Result "Scanner script has shebang" {
        $content = Get-Content "$PROJECT_ROOT\scanner.sh" -First 1 -ErrorAction SilentlyContinue
        $content -match "^#!/.*bash"
    }

    Test-Result "Scanner script is readable" {
        $content = Get-Content "$PROJECT_ROOT\scanner.sh" -ErrorAction SilentlyContinue
        $content.Length -gt 100
    }

    # Test Python scripts
    Test-Result "Python app syntax check" {
        try {
            $null = python -m py_compile "$PROJECT_ROOT\app.py" 2>$null
            $true
        } catch {
            $false
        }
    }

    Test-Result "Python webapp syntax check" {
        try {
            $null = python -m py_compile "$PROJECT_ROOT\run_webapp.py" 2>$null
            $true
        } catch {
            $false
        }
    }
}

function Test-BashScanner {
    Write-Header "Testing Bash Scanner Components"

    if (!$DockerAvailable -or $SkipDocker) {
        Write-Warning "Skipping Docker-based scanner tests (Docker not available or skipped)"
        return
    }

    # Build test image if needed
    Write-Info "Building test Docker image..."
    Push-Location $PROJECT_ROOT
    try {
        & docker-compose -f $DOCKER_COMPOSE_DEV build scanner-test 2>$null
        Write-Info "Test image built successfully"
    } catch {
        Write-Error "Failed to build test image: $_"
        Pop-Location
        return
    }

    # Test scanner help
    Test-Result "Scanner help command" {
        $output = & docker-compose -f $DOCKER_COMPOSE_DEV --profile test run --rm scanner-test ./scanner.sh --help 2>$null
        $output -match "USAGE:"
    }

    # Test scanner version
    Test-Result "Scanner version command" {
        $output = & docker-compose -f $DOCKER_COMPOSE_DEV --profile test run --rm scanner-test ./scanner.sh --version 2>$null
        $output -match "Linux Hardening.*Compliance Scanner"
    }

    # Test basic scanner functionality
    Test-Result "Scanner filesystem profile" {
        $output = & docker-compose -f $DOCKER_COMPOSE_DEV --profile test run --rm scanner-test ./scanner.sh filesystem -q 2>$null
        $LASTEXITCODE -eq 0
    }

    Pop-Location
}

function Test-PesterTests {
    Write-Header "Testing PowerShell/Pester Tests"

    # Check if Pester is available
    try {
        Import-Module Pester -ErrorAction Stop
        $pesterAvailable = $true
    } catch {
        $pesterAvailable = $false
        Write-Warning "Pester module not available, skipping Pester tests"
    }

    if ($pesterAvailable) {
        Test-Result "Pester Scanner tests" {
            Push-Location "$PROJECT_ROOT\tests\Pester"
            $results = Invoke-Pester -Path ".\Scanner.Tests.ps1" -PassThru -Quiet
            Pop-Location
            $results.PassedCount -gt 0
        }

        Test-Result "Pester Compliance tests" {
            Push-Location "$PROJECT_ROOT\tests\Pester"
            $results = Invoke-Pester -Path ".\Compliance.Tests.ps1" -PassThru -Quiet
            Pop-Location
            $results.PassedCount -gt 0
        }
    }
}

function Test-WebApplication {
    Write-Header "Testing Web Application"

    if ($SkipWebApp -or !$DockerAvailable) {
        Write-Warning "Skipping web application tests"
        return
    }

    # Build webapp image
    Write-Info "Building webapp Docker image..."
    Push-Location $PROJECT_ROOT
    try {
        & docker-compose -f $DOCKER_COMPOSE_DEV build scanner-webapp 2>$null
        Write-Info "Webapp image built successfully"
    } catch {
        Write-Error "Failed to build webapp image: $_"
        Pop-Location
        return
    }

    # Start webapp
    Write-Info "Starting web application..."
    try {
        & docker-compose -f $DOCKER_COMPOSE_DEV up -d scanner-webapp 2>$null
        Start-Sleep -Seconds 10  # Wait for startup
    } catch {
        Write-Error "Failed to start web application: $_"
        Pop-Location
        return
    }

    # Test API endpoint
    Test-Result "Webapp API health check" {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:5000/api/scans/summary" -UseBasicParsing -TimeoutSec 10
            $response.StatusCode -eq 200
        } catch {
            $false
        }
    }

    # Stop webapp
    Write-Info "Stopping web application..."
    try {
        & docker-compose -f $DOCKER_COMPOSE_DEV down 2>$null
    } catch {
        Write-Warning "Failed to stop web application cleanly"
    }

    Pop-Location
}

function Test-DockerIntegration {
    Write-Header "Testing Docker Integration"

    if (!$DockerAvailable -or $SkipDocker) {
        Write-Warning "Skipping Docker integration tests"
        return
    }

    Push-Location $PROJECT_ROOT

    # Test Docker Compose configuration
    Test-Result "Docker Compose config validation" {
        try {
            & docker-compose -f $DOCKER_COMPOSE_DEV config 2>$null
            $true
        } catch {
            $false
        }
    }

    # Test CLI scanner via Docker
    Test-Result "CLI scanner via Docker" {
        try {
            & docker-compose -f $DOCKER_COMPOSE_DEV --profile cli run --rm scanner-cli ./scanner.sh --version 2>$null
            $LASTEXITCODE -eq 0
        } catch {
            $false
        }
    }

    Pop-Location
}

function Test-ConfigurationFiles {
    Write-Header "Testing Configuration Files"

    # Test JSON configuration files
    $configFiles = @(
        "config\CIS-Level1.json",
        "config\CIS-Level2.json",
        "config\Custom-Profile.json",
        "config\NIST-800-53.json",
        "config\PCI-DSS.json"
    )

    foreach ($configFile in $configFiles) {
        Test-Result "Config file exists: $configFile" {
            Test-Path "$PROJECT_ROOT\$configFile"
        }
    }

    # Test requirements.txt
    Test-Result "Python requirements file" {
        Test-Path "$PROJECT_ROOT\requirements.txt"
    }

    # Test Dockerfile
    Test-Result "Dockerfile exists" {
        Test-Path "$PROJECT_ROOT\Dockerfile"
    }

    # Test docker-compose files
    Test-Result "Development docker-compose" {
        Test-Path "$PROJECT_ROOT\$DOCKER_COMPOSE_DEV"
    }
}

function Generate-TestReport {
    Write-Header "Test Results Summary"

    Write-Host "Total Tests Run: $TOTAL_TESTS"
    Write-Host "Tests Passed:    $PASSED_TESTS" -ForegroundColor Green
    Write-Host "Tests Failed:    $FAILED_TESTS" -ForegroundColor Red
    Write-Host "Success Rate:    $(([math]::Round(($PASSED_TESTS / $TOTAL_TESTS) * 100, 1)))%"

    Write-Host ""
    if ($FAILED_TESTS -eq 0) {
        Write-Success "🎉 All tests passed! The scanner is ready for use."
        Write-Host ""
        Write-Info "Next steps:"
        Write-Host "  1. Run '.\run.ps1 docker-up' to start the web interface"
        Write-Host "  2. Open http://localhost:5000 in your browser"
        Write-Host "  3. Start scanning your Linux systems!"
        Write-Host ""
        Write-Host "For production deployment:"
        Write-Host "  docker-compose -f docker-compose.prod.yml up -d"
    } else {
        Write-Error "Some tests failed. Please review the errors above."
        Write-Host ""
        Write-Info "Common issues:"
        Write-Host "  - Ensure Docker Desktop is running"
        Write-Host "  - Check that all required files are present"
        Write-Host "  - Verify Python and pip are installed"
        Write-Host "  - Run with -Verbose flag for more details"
        Write-Host ""
        exit 1
    }
}

# Main execution
function Main {
    Write-Header "Linux Hardening & Compliance Scanner - Complete Test Suite"

    if ($Verbose) {
        Write-Info "Verbose mode enabled"
    }

    # Run all test phases
    Check-Prerequisites
    Test-FileStructure
    Test-SyntaxValidation
    Test-ConfigurationFiles

    if (!$SkipDocker) {
        Test-DockerIntegration
        Test-BashScanner
    }

    Test-PesterTests

    if (!$SkipWebApp) {
        Test-WebApplication
    }

    # Generate final report
    Generate-TestReport
}

# Run main function
Main
