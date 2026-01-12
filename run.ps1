# Linux Hardening & Compliance Scanner - PowerShell Runner
# Windows-compatible alternative to Makefile

param(
    [Parameter(Mandatory=$false)]
    [string]$Command = "help",
    [Parameter(Mandatory=$false)]
    [string]$Profile = "filesystem"
)

$PROJECT_ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
$DOCKER_COMPOSE_DEV = "docker-compose.dev.yml"

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Help {
    Write-Header "Linux Hardening & Compliance Scanner - Windows Runner"

    Write-Host "Available commands:"
    Write-Host "  help          - Show this help message"
    Write-Host "  docker-build  - Build Docker images"
    Write-Host "  docker-up     - Start development environment"
    Write-Host "  docker-down   - Stop development environment"
    Write-Host "  docker-cli    - Run CLI scanner in Docker"
    Write-Host "  docker-test   - Run tests in Docker"
    Write-Host "  info          - Show system information"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\run.ps1 docker-build"
    Write-Host "  .\run.ps1 docker-up"
    Write-Host "  .\run.ps1 docker-cli filesystem"
    Write-Host "  .\run.ps1 docker-test"
    Write-Host ""
    Write-Host "Prerequisites:"
    Write-Host "  - Docker Desktop"
    Write-Host "  - Git"
}

# Main command processing
switch ($Command) {
    "help" { Show-Help }
    "docker-build" {
        Write-Header "Building Docker Images"
        Write-Host "Building Docker images for development..." -ForegroundColor Blue
        Push-Location $PROJECT_ROOT
        & docker-compose -f $DOCKER_COMPOSE_DEV build
        Pop-Location
        Write-Host "SUCCESS: Docker images built successfully" -ForegroundColor Green
    }
    "docker-up" {
        Write-Header "Starting Development Environment"
        Write-Host "Starting development environment..." -ForegroundColor Blue
        Push-Location $PROJECT_ROOT
        & docker-compose -f $DOCKER_COMPOSE_DEV up -d scanner-webapp
        Pop-Location
        Write-Host "SUCCESS: Development environment started!" -ForegroundColor Green
        Write-Host "Web interface: http://localhost:5000" -ForegroundColor Blue
        Write-Host "To stop: .\run.ps1 docker-down" -ForegroundColor Blue
    }
    "docker-down" {
        Write-Header "Stopping Development Environment"
        Write-Host "Stopping development environment..." -ForegroundColor Blue
        Push-Location $PROJECT_ROOT
        & docker-compose -f $DOCKER_COMPOSE_DEV down
        Pop-Location
        Write-Host "SUCCESS: Development environment stopped" -ForegroundColor Green
    }
    "docker-cli" {
        Write-Header "Running CLI Scanner in Docker"
        Write-Host "Running CLI scanner with profile: $Profile" -ForegroundColor Blue
        Push-Location $PROJECT_ROOT
        & docker-compose -f $DOCKER_COMPOSE_DEV --profile cli run --rm scanner-cli "./scanner.sh $Profile -q"
        Pop-Location
        Write-Host "SUCCESS: CLI scan completed" -ForegroundColor Green
    }
    "docker-test" {
        Write-Header "Running Tests in Docker"
        Write-Host "Running comprehensive tests in Docker..." -ForegroundColor Blue
        Push-Location $PROJECT_ROOT
        & docker-compose -f $DOCKER_COMPOSE_DEV --profile test run --rm scanner-test
        Pop-Location
        Write-Host "SUCCESS: Docker tests completed" -ForegroundColor Green
    }
    "info" {
        Write-Header "System Information"
        Write-Host "OS: $([System.Environment]::OSVersion.VersionString)"
        Write-Host "PowerShell: $($PSVersionTable.PSVersion)"

        try {
            $dockerVersion = & docker --version 2>$null
            Write-Host "Docker: $dockerVersion"
        } catch {
            Write-Host "Docker: Not found" -ForegroundColor Red
        }

        try {
            $gitVersion = & git --version 2>$null
            Write-Host "Git: $gitVersion"
        } catch {
            Write-Host "Git: Not found" -ForegroundColor Red
        }

        Write-Host ""
        Write-Host "Project Information:"
        Write-Host "==================="

        if (Test-Path "$PROJECT_ROOT\scanner.sh") {
            Write-Host "Scanner: Available" -ForegroundColor Green
        } else {
            Write-Host "Scanner: Not found" -ForegroundColor Red
        }

        if (Test-Path "$PROJECT_ROOT\app.py") {
            Write-Host "Web App: Available" -ForegroundColor Green
        } else {
            Write-Host "Web App: Not found" -ForegroundColor Red
        }

        $moduleCount = (Get-ChildItem "$PROJECT_ROOT\modules\*.sh" -ErrorAction SilentlyContinue).Count
        Write-Host "Modules: $moduleCount"

        $configCount = (Get-ChildItem "$PROJECT_ROOT\config\*.json" -ErrorAction SilentlyContinue).Count
        Write-Host "Config Files: $configCount"
    }
    default {
        Write-Host "ERROR: Unknown command: $Command" -ForegroundColor Red
        Show-Help
    }
}