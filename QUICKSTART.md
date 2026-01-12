# 🚀 Quick Start Guide

Get the Linux Hardening & Compliance Scanner running in minutes!

## Prerequisites

- **Docker & Docker Compose** (recommended)
- **Python 3.6+** (alternative method)
- **Git**

## Method 1: Docker (Recommended)

### Step 1: Clone and Build
```bash
git clone https://github.com/add54/Linux-Hardening-Compliance-Scanner.git
cd Linux-Hardening-Compliance-Scanner

# Build Docker images
make docker-build
# or
docker-compose -f docker-compose.dev.yml build
```

### Step 2: Start the Web Application
```bash
# Start web interface
make docker-up
# or
docker-compose -f docker-compose.dev.yml up -d scanner-webapp

# View logs
make docker-logs
# or
docker-compose -f docker-compose.dev.yml logs -f
```

### Step 3: Access the Scanner
- Open your browser: `http://localhost:5000`
- Click "Start New Scan"
- Choose a profile (filesystem, ssh, full)
- Run your first security scan!

### Docker Commands
```bash
# CLI scanner
make docker-cli PROFILE=filesystem

# Run tests
make docker-test

# Stop everything
make docker-down
```

## Method 2: Python (Alternative)

### Step 1: Install Dependencies
```bash
# Install Python dependencies
pip install -r requirements.txt

# Make scripts executable
chmod +x scanner.sh
chmod +x modules/*.sh
```

### Step 2: Run Scanner Directly
```bash
# CLI usage
./scanner.sh filesystem
./scanner.sh --help

# Web interface
python app.py
# Access: http://localhost:5000
```

## Method 3: Make Commands

```bash
# Setup development environment
make setup

# Build and test
make build
make test

# Start webapp
make webapp

# Run CLI scan
make cli PROFILE=ssh

# Clean up
make clean
```

## 🔧 Troubleshooting

### "Registry denied" error
- Use local Docker builds instead of registry images
- The production docker-compose.yml expects pre-built images
- Use `docker-compose.dev.yml` for local development

### Port 5000 already in use
```bash
# Find process using port
lsof -i :5000
# or on Windows
netstat -ano | findstr :5000

# Kill the process or use different port
FLASK_RUN_PORT=5001 python app.py
```

### Permission denied on scripts
```bash
# Make scripts executable
chmod +x scanner.sh
chmod +x modules/*.sh
chmod +x test_scanner.sh
```

### Docker build fails
```bash
# Clean Docker cache
docker system prune -a

# Rebuild without cache
docker-compose -f docker-compose.dev.yml build --no-cache
```

## 📊 First Scan

1. **Open** `http://localhost:5000`
2. **Click** "Start New Scan"
3. **Select** "filesystem" profile
4. **Click** "Start Scan"
5. **Wait** for completion (usually < 30 seconds)
6. **View** results and download reports

## 🎯 Common Profiles

- `filesystem` - File permissions and security
- `ssh` - SSH daemon hardening
- `system` - System file validation
- `full` - Complete security audit

## 📝 Next Steps

- Explore the web interface
- Run different scan profiles
- View historical results
- Customize scan configurations
- Set up automated scanning

## 🆘 Need Help?

- Check the logs: `docker-compose -f docker-compose.dev.yml logs`
- Run diagnostics: `make info`
- View documentation: `README.md`, `WEBAPP_README.md`
- Report issues: [GitHub Issues](https://github.com/add54/Linux-Hardening-Compliance-Scanner/issues)

---

**Happy Scanning! 🔒🛡️**
