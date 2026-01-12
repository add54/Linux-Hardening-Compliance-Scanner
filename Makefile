# Linux Hardening & Compliance Scanner - Makefile
# Provides easy commands for development, testing, and deployment

.PHONY: help build test docker-test webapp cli clean deploy

# Default target
help:
	@echo "Linux Hardening & Compliance Scanner"
	@echo "===================================="
	@echo ""
	@echo "Available commands:"
	@echo "  build         - Build all Docker images"
	@echo "  test          - Run all tests"
	@echo "  docker-test   - Run Docker integration tests"
	@echo "  webapp        - Start web application"
	@echo "  cli           - Run CLI scanner (usage: make cli PROFILE=filesystem)"
	@echo "  deploy        - Deploy full stack locally"
	@echo "  clean         - Clean up Docker resources"
	@echo "  lint          - Run code linting"
	@echo "  format        - Format code"
	@echo "  docs          - Generate documentation"
	@echo ""
	@echo "Docker Development:"
	@echo "  docker-build  - Build Docker images for development"
	@echo "  docker-up     - Start development environment"
	@echo "  docker-down   - Stop development environment"
	@echo "  docker-logs   - Show development logs"
	@echo "  docker-cli    - Run CLI scanner in Docker"
	@echo "  docker-test   - Run tests in Docker"
	@echo ""
	@echo "Examples:"
	@echo "  make build"
	@echo "  make test"
	@echo "  make webapp"
	@echo "  make cli PROFILE=filesystem"
	@echo "  make deploy"
	@echo "  make clean"
	@echo ""
	@echo "  # Docker development"
	@echo "  make docker-build"
	@echo "  make docker-up"
	@echo "  make docker-cli PROFILE=ssh"
	@echo "  make docker-test"
	@echo "  make docker-down"

# Build all Docker images
build:
	@echo "🔨 Building Docker images..."
	@chmod +x run_docker_tests.sh
	@./run_docker_tests.sh build

# Run all tests
test:
	@echo "🧪 Running test suite..."
	@chmod +x scanner.sh test_scanner.sh
	@chmod +x modules/*.sh
	@./test_scanner.sh

# Run Docker integration tests
docker-test:
	@echo "🐳 Running Docker integration tests..."
	@chmod +x run_docker_tests.sh tests/docker-integration-test.sh
	@./run_docker_tests.sh test

# Start web application
webapp:
	@echo "🌐 Starting web application..."
	@mkdir -p results logs uploads
	@chmod +x run_docker_tests.sh
	@./run_docker_tests.sh webapp

# Run CLI scanner
cli:
	@echo "💻 Running CLI scanner..."
	@mkdir -p results
	@chmod +x run_docker_tests.sh
	@if [ -z "$(PROFILE)" ]; then \
		echo "Usage: make cli PROFILE=<profile_name>"; \
		echo "Example: make cli PROFILE=filesystem"; \
		exit 1; \
	fi
	@./run_docker_tests.sh cli $(PROFILE)

# Deploy full stack
deploy:
	@echo "🚀 Deploying full stack..."
	@chmod +x run_docker_tests.sh
	@./run_docker_tests.sh deploy

# Run integration tests
integration:
	@echo "🔗 Running integration tests..."
	@chmod +x run_docker_tests.sh
	@./run_docker_tests.sh integration

# Clean up Docker resources
clean:
	@echo "🧹 Cleaning up Docker resources..."
	@chmod +x run_docker_tests.sh
	@./run_docker_tests.sh clean

# Run linting
lint:
	@echo "🔍 Running code linting..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		echo "Checking Bash scripts..."; \
		find . -name "*.sh" -exec shellcheck {} \;; \
	else \
		echo "shellcheck not found, skipping Bash linting"; \
	fi
	@if command -v flake8 >/dev/null 2>&1; then \
		echo "Checking Python files..."; \
		flake8 app.py run_webapp.py --count --select=E9,F63,F7,F82 --show-source --statistics; \
	else \
		echo "flake8 not found, skipping Python linting"; \
	fi

# Format code
format:
	@echo "🎨 Formatting code..."
	@if command -v black >/dev/null 2>&1; then \
		echo "Formatting Python files..."; \
		black app.py run_webapp.py; \
	else \
		echo "black not found, skipping Python formatting"; \
	fi

# Generate documentation
docs:
	@echo "📚 Generating documentation..."
	@echo "Documentation generation not yet implemented"
	@echo "See README.md and WEBAPP_README.md for current docs"

# Development setup
setup:
	@echo "🔧 Setting up development environment..."
	@if command -v python3 >/dev/null 2>&1; then \
		echo "Installing Python dependencies..."; \
		pip install -r requirements.txt; \
		pip install pytest pytest-cov black flake8 mypy shellcheck-py; \
	else \
		echo "Python3 not found. Please install Python 3.6+"; \
		exit 1; \
	fi
	@echo "Making scripts executable..."
	@chmod +x scanner.sh test_scanner.sh run_docker_tests.sh
	@chmod +x modules/*.sh
	@echo "✅ Development environment ready!"

# Docker development commands
docker-build:
	@echo "🔨 Building Docker images for development..."
	@docker-compose -f docker-compose.dev.yml build

docker-up:
	@echo "🚀 Starting development environment..."
	@docker-compose -f docker-compose.dev.yml up -d scanner-webapp

docker-down:
	@echo "🛑 Stopping development environment..."
	@docker-compose -f docker-compose.dev.yml down

docker-logs:
	@echo "📋 Showing development logs..."
	@docker-compose -f docker-compose.dev.yml logs -f

docker-cli:
	@echo "💻 Running CLI scanner..."
	@docker-compose -f docker-compose.dev.yml --profile cli run --rm scanner-cli

docker-test:
	@echo "🧪 Running tests in Docker..."
	@docker-compose -f docker-compose.dev.yml --profile test run --rm scanner-test

# Show system information
info:
	@echo "🔍 System Information"
	@echo "===================="
	@echo "OS: $(shell uname -s)"
	@echo "Architecture: $(shell uname -m)"
	@echo "Python: $(shell python3 --version 2>/dev/null || echo 'Not found')"
	@echo "Docker: $(shell docker --version 2>/dev/null || echo 'Not found')"
	@echo "Git: $(shell git --version 2>/dev/null || echo 'Not found')"
	@echo ""
	@echo "Project Information"
	@echo "==================="
	@echo "Scanner Version: $(shell grep 'Version:' scanner.sh | head -1 | cut -d: -f2 | tr -d ' ')"
	@echo "Webapp Version: $(shell grep 'version=' app.py | head -1 | cut -d= -f2 | tr -d \"' \")"
	@echo "Modules: $(shell ls modules/*.sh | wc -l)"
	@echo "Config Files: $(shell ls config/*.json | wc -l)"
	@echo "Test Files: $(shell find tests/ -name "*.sh" -o -name "*.ps1" | wc -l)"

# Quick scan (development)
quick-scan:
	@echo "⚡ Running quick filesystem scan..."
	@chmod +x scanner.sh
	@./scanner.sh filesystem --quiet

# Health check
health:
	@echo "❤️  Health Check"
	@echo "==============="
	@echo "Scanner executable: $(shell test -x scanner.sh && echo '✅' || echo '❌')"
	@echo "Modules directory: $(shell test -d modules && echo '✅' || echo '❌')"
	@echo "Config directory: $(shell test -d config && echo '✅' || echo '❌')"
	@echo "Results directory: $(shell test -d results && echo '✅' || echo '❌')"
	@echo "Python app: $(shell python3 -c "import flask" 2>/dev/null && echo '✅' || echo '❌')"
	@echo "Docker available: $(shell docker info >/dev/null 2>&1 && echo '✅' || echo '❌')"
