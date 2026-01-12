# Linux Hardening & Compliance Scanner - PowerShell Runner
# Windows-compatible alternative to Makefile

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("help", "setup", "build", "test", "webapp", "cli", "deploy", "clean",
                 "docker-build", "docker-up", "docker-down", "docker-logs", "docker-cli", "docker-test",
                 "lint", "format", "docs", "info")]
    [string]$Command = "help",

    [Parameter(Mandatory=$false)]
    [string]$Profile = "filesystem"
)

$PROJECT_ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
$DOCKER_COMPOSE_DEV = "docker-compose.dev.yml"
$DOCKER_COMPOSE_PROD = "docker-compose.prod.yml"

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
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

function Test-Docker {
    try {
        $null = docker --version 2>$null
        return $true
    } catch {
        return $false
    }
}

function Test-Python {
    try {
        $version = python --version 2>$null
        if ($version -match "Python 3\.[6-9]") {
            return $true
        }
        return $false
    } catch {
        return $false
    }
}

function Show-Help {
    Write-Header "Linux Hardening & Compliance Scanner"

    Write-Host "Available commands:" -ForegroundColor Yellow
    Write-Host "  help          - Show this help message"
    Write-Host "  setup         - Setup development environment"
    Write-Host "  build         - Build all components"
    Write-Host "  test          - Run all tests"
    Write-Host "  webapp        - Start web application"
    Write-Host "  cli           - Run CLI scanner (use -Profile parameter)"
    Write-Host "  deploy        - Deploy full stack"
    Write-Host "  clean         - Clean up resources"
    Write-Host ""
    Write-Host "Docker Development:" -ForegroundColor Yellow
    Write-Host "  docker-build  - Build Docker images"
    Write-Host "  docker-up     - Start development environment"
    Write-Host "  docker-down   - Stop development environment"
    Write-Host "  docker-logs   - Show development logs"
    Write-Host "  docker-cli    - Run CLI scanner in Docker"
    Write-Host "  docker-test   - Run tests in Docker"
    Write-Host ""
    Write-Host "Development Tools:" -ForegroundColor Yellow
    Write-Host "  lint          - Run code linting"
    Write-Host "  format        - Format code"
    Write-Host "  docs          - Generate documentation"
    Write-Host "  info          - Show system information"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\run.ps1 -Command docker-build"
    Write-Host "  .\run.ps1 -Command docker-up"
    Write-Host "  .\run.ps1 -Command cli -Profile ssh"
    Write-Host "  .\run.ps1 docker-test"
    Write-Host ""
    Write-Host "Prerequisites:" -ForegroundColor Magenta
    Write-Host "  - Docker Desktop (for Docker commands)"
    Write-Host "  - Python 3.6+ (for direct commands)"
    Write-Host "  - Git"
}

function Invoke-Setup {
    Write-Header "Setting up development environment"

    if (!(Test-Python)) {
        Write-Error "Python 3.6+ is required. Please install Python from https://python.org"
        return
    }

    Write-Info "Installing Python dependencies..."
    try {
        & python -m pip install --upgrade pip
        & pip install -r "$PROJECT_ROOT\requirements.txt"
        & pip install pytest pytest-cov black flake8 mypy
        Write-Success "Python dependencies installed"
    } catch {
        Write-Error "Failed to install Python dependencies: $_"
        return
    }

    Write-Info "Making scripts executable..."
    # On Windows, we'll handle this in the scripts themselves

    Write-Success "Development environment ready!"
}

function Invoke-Build {
    Write-Header "Building all components"

    if (!(Test-Docker)) {
        Write-Error "Docker is required for building. Please install Docker Desktop."
        return
    }

    Write-Info "Building Docker images..."
    try {
        Push-Location $PROJECT_ROOT
        & docker-compose -f $DOCKER_COMPOSE_DEV build
        Write-Success "Docker images built successfully"
    } catch {
        Write-Error "Failed to build Docker images: $_"
    } finally {
        Pop-Location
    }
}

function Invoke-Test {
    Write-Header "Running test suite"

    Write-Info "Running Bash scanner tests..."
    try {
        Push-Location $PROJECT_ROOT
        # Run tests in Docker if available
        if (Test-Docker) {
            & docker-compose -f $DOCKER_COMPOSE_DEV --profile test run --rm scanner-test
        } else {
            Write-Info "Docker not available, running basic tests..."
            # Run basic PowerShell tests
            & Invoke-Pester -Path ".\tests\Pester\" -OutputFormat Text
        }
        Write-Success "Tests completed"
    } catch {
        Write-Error "Tests failed: $_"
    } finally {
        Pop-Location
    }
}

function Invoke-Webapp {
    Write-Header "Starting web application"

    if (!(Test-Docker)) {
        Write-Error "Docker is required. Please install Docker Desktop."
        return
    }

    Write-Info "Starting Flask web application..."
    Write-Info "URL: http://localhost:5000"
    Write-Info "Press Ctrl+C to stop"

    try {
        Push-Location $PROJECT_ROOT
        & docker-compose -f $DOCKER_COMPOSE_DEV up scanner-webapp
    } catch {
        Write-Error "Failed to start web application: $_"
    } finally {
        Pop-Location
    }
}

function Invoke-Cli {
    param([string]$ScanProfile = "filesystem")

    Write-Header "Running CLI scanner"

    if (!(Test-Docker)) {
        Write-Error "Docker is required. Please install Docker Desktop."
        return
    }

    Write-Info "Running scanner with profile: $ScanProfile"

    try {
        Push-Location $PROJECT_ROOT
        & docker-compose -f $DOCKER_COMPOSE_DEV --profile cli run --rm scanner-cli "./scanner.sh $ScanProfile -q"
        Write-Success "Scan completed! Results saved to results/ directory"
    } catch {
        Write-Error "CLI scan failed: $_"
    } finally {
        Pop-Location
    }
}

function Invoke-DockerBuild {
    Write-Header "Building Docker images"

    if (!(Test-Docker)) {
        Write-Error "Docker is required. Please install Docker Desktop."
        return
    }

    Write-Info "Building Docker images for development..."
    try {
        Push-Location $PROJECT_ROOT
        & docker-compose -f $DOCKER_COMPOSE_DEV build
        Write-Success "Docker images built successfully"
    } catch {
        Write-Error "Failed to build Docker images: $_"
    } finally {
        Pop-Location
    }
}

function Invoke-DockerUp {
    Write-Header "Starting development environment"

    if (!(Test-Docker)) {
        Write-Error "Docker is required. Please install Docker Desktop."
        return
    }

    Write-Info "Starting development environment..."
    try {
        Push-Location $PROJECT_ROOT
        & docker-compose -f $DOCKER_COMPOSE_DEV up -d scanner-webapp
        Write-Success "Development environment started!"
        Write-Info "Web interface: http://localhost:5000"
        Write-Info "To stop: .\run.ps1 docker-down"
    } catch {
        Write-Error "Failed to start development environment: $_"
    } finally {
        Pop-Location
    }
}

function Invoke-DockerDown {
    Write-Header "Stopping development environment"

    if (!(Test-Docker)) {
        Write-Warning "Docker not available"
        return
    }

    Write-Info "Stopping development environment..."
    try {
        Push-Location $PROJECT_ROOT
        & docker-compose -f $DOCKER_COMPOSE_DEV down
        Write-Success "Development environment stopped"
    } catch {
        Write-Error "Failed to stop development environment: $_"
    } finally {
        Pop-Location
    }
}

function Invoke-DockerLogs {
    Write-Header "Showing development logs"

    if (!(Test-Docker)) {
        Write-Error "Docker is required. Please install Docker Desktop."
        return
    }

    Write-Info "Showing development logs (press Ctrl+C to exit)..."
    try {
        Push-Location $PROJECT_ROOT
        & docker-compose -f $DOCKER_COMPOSE_DEV logs -f
    } catch {
        Write-Error "Failed to show logs: $_"
    } finally {
        Pop-Location
    }
}

function Invoke-DockerCli {
    Write-Header "Running CLI scanner in Docker"

    if (!(Test-Docker)) {
        Write-Error "Docker is required. Please install Docker Desktop."
        return
    }

    Write-Info "Running CLI scanner with profile: $Profile"

    try {
        Push-Location $PROJECT_ROOT
        & docker-compose -f $DOCKER_COMPOSE_DEV --profile cli run --rm scanner-cli
        Write-Success "CLI scan completed"
    } catch {
        Write-Error "CLI scan failed: $_"
    } finally {
        Pop-Location
    }
}

function Invoke-DockerTest {
    Write-Header "Running tests in Docker"

    if (!(Test-Docker)) {
        Write-Error "Docker is required. Please install Docker Desktop."
        return
    }

    Write-Info "Running comprehensive tests in Docker..."
    try {
        Push-Location $PROJECT_ROOT
        & docker-compose -f $DOCKER_COMPOSE_DEV --profile test run --rm scanner-test
        Write-Success "Docker tests completed"
    } catch {
        Write-Error "Docker tests failed: $_"
    } finally {
        Pop-Location
    }
}

function Invoke-Info {
    Write-Header "System Information"

    Write-Host "OS: $([System.Environment]::OSVersion.VersionString)"
    Write-Host "Architecture: $([System.Environment]::GetEnvironmentVariable('PROCESSOR_ARCHITECTURE'))"
    Write-Host "PowerShell: $($PSVersionTable.PSVersion)"

    if (Test-Python) {
        $pythonVersion = & python --version 2>$null
        Write-Host "Python: $pythonVersion"
    } else {
        Write-Host "Python: Not found"
    }

    if (Test-Docker) {
        $dockerVersion = & docker --version 2>$null
        Write-Host "Docker: $dockerVersion"
    } else {
        Write-Host "Docker: Not found"
    }

    $gitVersion = & git --version 2>$null
    Write-Host "Git: $gitVersion"

    Write-Host ""
    Write-Host "Project Information:" -ForegroundColor Yellow
    Write-Host "=================="

    if (Test-Path "$PROJECT_ROOT\scanner.sh") {
        $scannerVersion = Select-String -Path "$PROJECT_ROOT\scanner.sh" -Pattern "Version:" | Select-Object -First 1
        Write-Host "Scanner Version: $($scannerVersion.Line.Trim() -replace '.*Version:\s*')"
    }

    if (Test-Path "$PROJECT_ROOT\app.py") {
        $webappVersion = Select-String -Path "$PROJECT_ROOT\app.py" -Pattern "version=" | Select-Object -First 1
        Write-Host "Webapp Version: $($webappVersion.Line.Trim() -replace '.*version=\s*['"'"'"])')"
    }

    $moduleCount = (Get-ChildItem "$PROJECT_ROOT\modules\*.sh" -ErrorAction SilentlyContinue).Count
    Write-Host "Modules: $moduleCount"

    $configCount = (Get-ChildItem "$PROJECT_ROOT\config\*.json" -ErrorAction SilentlyContinue).Count
    Write-Host "Config Files: $configCount"

    $testCount = (Get-ChildItem "$PROJECT_ROOT\tests\*.sh", "$PROJECT_ROOT\tests\*.ps1" -Recurse -ErrorAction SilentlyContinue).Count
    Write-Host "Test Files: $testCount"
}

# Main command processing
switch ($Command) {
    "help" { Show-Help }
    "setup" { Invoke-Setup }
    "build" { Invoke-Build }
    "test" { Invoke-Test }
    "webapp" { Invoke-Webapp }
    "cli" { Invoke-Cli -ScanProfile $Profile }
    "deploy" { Invoke-Build; Invoke-DockerUp }  # Simplified deploy
    "clean" {
        Invoke-DockerDown
        Write-Info "Cleanup completed"
    }
    "docker-build" { Invoke-DockerBuild }
    "docker-up" { Invoke-DockerUp }
    "docker-down" { Invoke-DockerDown }
    "docker-logs" { Invoke-DockerLogs }
    "docker-cli" { Invoke-DockerCli }
    "docker-test" { Invoke-DockerTest }
    "lint" {
        Write-Header "Code Linting"
        Write-Info "Linting not yet implemented for Windows"
        Write-Info "Consider using WSL or installing Python tools"
    }
    "format" {
        Write-Header "Code Formatting"
        Write-Info "Formatting not yet implemented for Windows"
        Write-Info "Consider using WSL or installing Python tools"
    }
    "docs" {
        Write-Header "Documentation"
        Write-Info "Documentation generation not yet implemented"
        Write-Info "See README.md and WEBAPP_README.md for current docs"
    }
    "info" { Invoke-Info }
    default {
        Write-Error "Unknown command: $Command"
        Show-Help
    }
}
