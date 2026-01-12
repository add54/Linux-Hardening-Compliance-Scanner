@echo off
REM Linux Hardening & Compliance Scanner - Windows Batch Runner
REM Alternative to PowerShell script for Windows users

setlocal enabledelayedexpansion

set "PROJECT_ROOT=%~dp0"
set "DOCKER_COMPOSE_DEV=docker-compose.dev.yml"

if "%1"=="" goto :help

REM Parse command
set "COMMAND=%1"
shift

REM Parse profile for CLI commands
set "PROFILE=filesystem"
if "%COMMAND%"=="cli" if not "%1"=="" set "PROFILE=%1"

goto :%COMMAND%

:help
echo ========================================
echo Linux Hardening ^& Compliance Scanner
echo ========================================
echo.
echo Windows Batch Runner
echo ====================
echo.
echo Available commands:
echo   help          - Show this help message
echo   docker-build  - Build Docker images
echo   docker-up     - Start development environment
echo   docker-down   - Stop development environment
echo   docker-logs   - Show development logs
echo   docker-cli    - Run CLI scanner in Docker
echo   docker-test   - Run tests in Docker
echo   clean         - Clean up resources
echo   info          - Show system information
echo.
echo Examples:
echo   run.bat docker-build
echo   run.bat docker-up
echo   run.bat docker-cli filesystem
echo   run.bat docker-test
echo   run.bat clean
echo.
echo Prerequisites:
echo   - Docker Desktop
echo   - Git
goto :end

:docker-build
echo ========================================
echo Building Docker Images
echo ========================================
echo.
cd /d "%PROJECT_ROOT%"
docker-compose -f %DOCKER_COMPOSE_DEV% build
if %errorlevel% neq 0 (
    echo ERROR: Failed to build Docker images
    goto :end
)
echo.
echo SUCCESS: Docker images built successfully
goto :end

:docker-up
echo ========================================
echo Starting Development Environment
echo ========================================
echo.
cd /d "%PROJECT_ROOT%"
docker-compose -f %DOCKER_COMPOSE_DEV% up -d scanner-webapp
if %errorlevel% neq 0 (
    echo ERROR: Failed to start development environment
    goto :end
)
echo.
echo SUCCESS: Development environment started
echo Web interface: http://localhost:5000
echo To stop: run.bat docker-down
goto :end

:docker-down
echo ========================================
echo Stopping Development Environment
echo ========================================
echo.
cd /d "%PROJECT_ROOT%"
docker-compose -f %DOCKER_COMPOSE_DEV% down
if %errorlevel% neq 0 (
    echo ERROR: Failed to stop development environment
    goto :end
)
echo.
echo SUCCESS: Development environment stopped
goto :end

:docker-logs
echo ========================================
echo Development Logs
echo ========================================
echo Press Ctrl+C to exit
echo.
cd /d "%PROJECT_ROOT%"
docker-compose -f %DOCKER_COMPOSE_DEV% logs -f
goto :end

:docker-cli
echo ========================================
echo Running CLI Scanner in Docker
echo ========================================
echo Profile: %PROFILE%
echo.
cd /d "%PROJECT_ROOT%"
docker-compose -f %DOCKER_COMPOSE_DEV% --profile cli run --rm scanner-cli ./scanner.sh %PROFILE% -q
if %errorlevel% neq 0 (
    echo ERROR: CLI scan failed
    goto :end
)
echo.
echo SUCCESS: CLI scan completed
goto :end

:docker-test
echo ========================================
echo Running Tests in Docker
echo ========================================
echo.
cd /d "%PROJECT_ROOT%"
docker-compose -f %DOCKER_COMPOSE_DEV% --profile test run --rm scanner-test
if %errorlevel% neq 0 (
    echo ERROR: Tests failed
    goto :end
)
echo.
echo SUCCESS: Tests completed
goto :end

:clean
echo ========================================
echo Cleaning Up Resources
echo ========================================
echo.
cd /d "%PROJECT_ROOT%"

REM Stop containers
docker-compose -f %DOCKER_COMPOSE_DEV% down -v --remove-orphans 2>nul

REM Remove images
docker rmi linuxhardeningcompliancescanner-scanner-webapp 2>nul
docker rmi linuxhardeningcompliancescanner-scanner-cli 2>nul
docker rmi linuxhardeningcompliancescanner-test-env 2>nul

REM Clean up unused resources
docker system prune -f 2>nul
docker volume prune -f 2>nul

REM Clean test files
if exist test-results rmdir /s /q test-results 2>nul

echo.
echo SUCCESS: Cleanup completed
goto :end

:info
echo ========================================
echo System Information
echo ========================================
echo.
echo OS: Windows
for /f "tokens=2 delims==" %%i in ('wmic os get Caption /value') do echo %%i

echo Architecture: %PROCESSOR_ARCHITECTURE%

REM Check Python
python --version 2>nul
if %errorlevel% neq 0 (
    echo Python: Not found
) else (
    echo Python: Found
)

REM Check Docker
docker --version 2>nul
if %errorlevel% neq 0 (
    echo Docker: Not found
) else (
    echo Docker: Found
)

REM Check Git
git --version 2>nul
if %errorlevel% neq 0 (
    echo Git: Not found
) else (
    echo Git: Found
)

echo.
echo Project Information:
echo ====================
cd /d "%PROJECT_ROOT%"

REM Scanner version
findstr /C:"Version:" scanner.sh 2>nul
if %errorlevel% neq 0 (
    echo Scanner Version: Unknown
)

REM Module count
dir /b modules\*.sh 2>nul | find /c ".sh" > temp_count.txt
set /p MODULE_COUNT=<temp_count.txt
echo Modules: %MODULE_COUNT%
del temp_count.txt 2>nul

REM Config count
dir /b config\*.json 2>nul | find /c ".json" > temp_count.txt
set /p CONFIG_COUNT=<temp_count.txt
echo Config Files: %CONFIG_COUNT%
del temp_count.txt 2>nul

goto :end

:end
echo.
pause
