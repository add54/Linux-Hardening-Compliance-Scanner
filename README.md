# Linux Hardening & Compliance Scanner

[![PowerShell](https://img.shields.io/badge/PowerShell-7+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://docker.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A comprehensive PowerShell-based security scanner for Linux systems that performs hardening checks and compliance validation against industry standards including CIS, NIST 800-53, and PCI-DSS.

## 📋 Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Configuration](#configuration)
- [Compliance Profiles](#compliance-profiles)
- [Output Formats](#output-formats)
- [Docker Usage](#docker-usage)
- [Kubernetes Deployment](#kubernetes-deployment)
- [Testing](#testing)
- [Contributing](#contributing)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## ✨ Features

### 🔍 Comprehensive Scanning
- **File System Security**: File permissions, ownership, and integrity checks
- **Authentication & Access**: Password policies, user accounts, and access controls
- **Network Security**: Firewall rules, service configurations, and network settings
- **Kernel Security**: Sysctl parameters and kernel module configurations
- **Service Management**: Running services, startup configurations, and security settings
- **Logging & Monitoring**: Audit logging, system logging, and monitoring configurations

### 📊 Compliance Standards
- **CIS Benchmarks**: Level 1 and Level 2 compliance scanning
- **NIST 800-53**: Federal security controls and requirements
- **PCI-DSS**: Payment card industry data security standards
- **Custom Profiles**: Create and use your own compliance profiles

### 🛠️ Automation & Remediation
- **Automated Remediation**: Fix identified security issues automatically
- **Custom Scripts**: Execute remediation scripts for complex fixes
- **Rollback Support**: Revert changes when needed
- **Dry-run Mode**: Test changes before applying them

### 📈 Reporting & Analytics
- **Multiple Output Formats**: Text, JSON, HTML, CSV, and XML reports
- **Compliance Scoring**: Calculate overall compliance percentages
- **Risk Assessment**: Categorize findings by severity levels
- **Historical Tracking**: Compare scan results over time

## 🔧 Requirements

### System Requirements
- **PowerShell**: Version 7.0 or higher (Core edition recommended)
- **Operating System**: Linux distributions (Ubuntu, CentOS, RHEL, Debian, SUSE, etc.)
- **Permissions**: Root or sudo access for comprehensive scanning
- **Disk Space**: Minimum 100MB free space for logs and reports

### Software Dependencies
```bash
# Required packages (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y curl wget jq

# Required packages (CentOS/RHEL)
sudo yum install -y curl wget jq
# or
sudo dnf install -y curl wget jq
```

### PowerShell Modules
The scanner includes all required PowerShell modules in the `src/` directory:
- `ScannerCore.psm1` - Core scanning functionality
- `AuthenticationScanner.psm1` - Authentication checks
- `FileSystemScanner.psm1` - File system security
- `KernelScanner.psm1` - Kernel parameters
- `NetworkScanner.psm1` - Network security
- `ServiceScanner.psm1` - Service management
- `LoggingScanner.psm1` - Logging configuration

## 📦 Installation

### Option 1: Direct Download (Recommended)

```bash
# Clone the repository
git clone https://github.com/add54/Linux-Hardening-Compliance-Scanner.git
cd Linux-Hardening-Compliance-Scanner

# Make scripts executable (if needed)
chmod +x *.ps1
chmod +x *.sh
```

### Option 2: PowerShell Gallery (Future Release)

```powershell
# Install from PowerShell Gallery (when available)
Install-Module -Name LinuxHardeningScanner -Scope CurrentUser
```

### Option 3: Docker Container

```bash
# Build the Docker image
docker build -t linux-hardening-scanner .

# Or pull from registry (when available)
docker pull add54/linux-hardening-scanner
```

## 🚀 Quick Start

### Basic System Scan

```bash
# Run a basic compliance scan
./scanner.ps1 -Profile cis_level1
```

### Generate HTML Report

```bash
# Scan and generate HTML report
./scanner.ps1 -Profile pci_dss -OutputFormat HTML -OutputFile report.html
```

### Automated Remediation

```bash
# Scan and automatically fix issues
./scanner.ps1 -Profile custom -Fix
```

## 📖 Usage

### Command Line Options

```bash
./scanner.ps1 [OPTIONS]

OPTIONS:
  -Profile <string>           Compliance profile to use
                             Values: cis_level1, cis_level2, pci_dss, nist_800_53, custom
  -OutputFormat <string>      Output format for results
                             Values: Text, JSON, HTML, CSV, XML (default: Text)
  -OutputFile <string>        Save results to specified file
  -Fix                       Automatically apply remediation for failed checks
  -Quiet                     Suppress progress messages
  -NoColor                   Disable colored output
  -Export                    Export detailed check data
  -Exclude <string[]>        Exclude specific check IDs
  -IncludeOnly <string[]>    Run only specified check IDs
  -SkipModules               Skip module-based checks
  -Timeout <int>             Scan timeout in seconds (default: 3600)
  -ShowVersion               Display version information
  -Help                      Show help information
```

### Examples

#### 1. CIS Level 1 Compliance Scan
```bash
./scanner.ps1 -Profile cis_level1 -OutputFormat HTML -OutputFile cis_report.html
```

#### 2. PCI-DSS Audit with JSON Output
```bash
./scanner.ps1 -Profile pci_dss -OutputFormat JSON -OutputFile pci_audit.json
```

#### 3. Custom Profile Scan with Remediation
```bash
./scanner.ps1 -Profile custom -Fix -OutputFormat Text
```

#### 4. Targeted Scan (Specific Checks Only)
```bash
./scanner.ps1 -Profile nist_800_53 -IncludeOnly "AC-1", "AC-2", "AC-3"
```

#### 5. Exclude Certain Checks
```bash
./scanner.ps1 -Profile cis_level2 -Exclude "1.1.1", "1.1.2" -OutputFormat CSV
```

## ⚙️ Configuration

### Compliance Profiles

The scanner uses JSON-based configuration files located in the `config/` directory:

- `CIS-Level1.json` - CIS Benchmark Level 1 controls
- `CIS-Level2.json` - CIS Benchmark Level 2 controls
- `NIST-800-53.json` - NIST 800-53 security controls
- `PCI-DSS.json` - PCI-DSS requirements
- `Custom-Profile.json` - User-defined custom checks

### Profile Structure

```json
{
  "name": "Custom Security Profile",
  "version": "1.0.0",
  "description": "Custom security checks for specific requirements",
  "required_score": 80,
  "modules": [
    "FileSystemScanner",
    "NetworkScanner",
    "AuthenticationScanner"
  ],
  "checks": {
    "CUSTOM-001": {
      "name": "Custom Check 1",
      "category": "Access Control",
      "severity": "High",
      "description": "Custom security check",
      "command": "custom_check_command",
      "expected_result": "expected_output",
      "remediation": "fix_command"
    }
  }
}
```

### Scanner Configuration

The scanner can be configured through environment variables:

```bash
# Set log level
export SCANNER_LOG_LEVEL=INFO

# Set custom config directory
export SCANNER_CONFIG_DIR=/path/to/config

# Set output directory
export SCANNER_OUTPUT_DIR=/path/to/results

# Enable debug mode
export SCANNER_DEBUG=true
```

## 📋 Compliance Profiles

### CIS Benchmarks
- **Level 1**: Basic security requirements for all systems
- **Level 2**: Advanced security requirements for high-security environments

### NIST 800-53
- **Security Controls**: Comprehensive security control framework
- **Risk Management**: Systematic approach to security risk management

### PCI-DSS
- **Payment Security**: Requirements for handling payment card data
- **Compliance Validation**: Quarterly scanning and annual self-assessment

### Custom Profiles
Create your own compliance profiles by modifying `config/Custom-Profile.json`:

```json
{
  "name": "Corporate Security Standard",
  "version": "2.1",
  "description": "Internal corporate security requirements",
  "required_score": 90,
  "modules": ["FileSystemScanner", "NetworkScanner"],
  "checks": {
    // Add your custom checks here
  }
}
```

## 📊 Output Formats

### Text Format (Default)
Human-readable output with colored results and summary statistics.

### JSON Format
Structured data format for programmatic processing:

```json
{
  "scan_id": "scan_20240112_143022",
  "timestamp": "2024-01-12T14:30:22Z",
  "profile": "cis_level1",
  "compliance_score": 85,
  "risk_level": "Medium",
  "summary": {
    "total_checks": 150,
    "passed": 127,
    "failed": 18,
    "skipped": 5
  },
  "checks": [...]
}
```

### HTML Format
Interactive web-based reports with charts and detailed findings.

### CSV Format
Tabular data format for spreadsheet analysis and reporting.

### XML Format
Structured markup format for enterprise integration.

## 🐳 Docker Usage

### Building the Image

```bash
# Build Docker image
docker build -t linux-hardening-scanner .

# Build with specific PowerShell version
docker build --build-arg PS_VERSION=7.4 -t linux-hardening-scanner:7.4 .
```

### Running in Container

```bash
# Basic scan
docker run --rm -v /:/host linux-hardening-scanner -Profile cis_level1

# Scan with custom config
docker run --rm \
  -v /:/host \
  -v $(pwd)/config:/app/config \
  linux-hardening-scanner \
  -Profile custom \
  -OutputFormat JSON \
  -OutputFile /host/scan_results.json
```

### Docker Compose

```bash
# Start scanner service
docker-compose up scanner

# Run scheduled scans
docker-compose up -d scheduler
```

## 🚢 Kubernetes Deployment

Deploy the scanner on Kubernetes clusters for production environments with high availability, scaling, and automated operations.

### Quick Start with Helm

```bash
# Install with Helm (recommended)
helm install linux-scanner ./helm/linux-scanner \
  --set global.domain=scanner.yourdomain.com \
  --create-namespace

# Access at https://scanner.yourdomain.com
```

### Manual Deployment with kubectl

```bash
# Deploy all components
kubectl apply -f k8s/

# Check status
kubectl get pods -n linux-scanner

# Access the web interface
kubectl get ingress -n linux-scanner
```

### Architecture

- **Web Application**: Flask app with REST API (2 replicas with HPA)
- **Scanner Worker**: Background security scanning (1 replica)
- **Scheduled Jobs**: CronJobs for automated daily/weekly scans
- **Persistent Storage**: PVCs for data, logs, and results
- **Ingress**: External access with SSL termination
- **Auto-scaling**: Horizontal Pod Autoscaler for webapp

### Features

- ✅ **High Availability**: Multi-replica deployments with PDBs
- ✅ **Auto-scaling**: HPA based on CPU/memory usage
- ✅ **Persistent Storage**: Data survives pod restarts
- ✅ **SSL/TLS**: Automatic certificates via cert-manager
- ✅ **Scheduled Scans**: Automated security assessments
- ✅ **Security Policies**: NetworkPolicies and RBAC
- ✅ **Monitoring**: Prometheus metrics and health checks

### Production Configuration

```yaml
# values.yaml overrides for production
webapp:
  replicaCount: 3
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi

ingress:
  enabled: true
  hosts:
    - scanner.yourcompany.com

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10

persistence:
  data:
    size: 50Gi
  logs:
    size: 10Gi
```

For complete Kubernetes deployment guide, see [`KUBERNETES_DEPLOYMENT.md`](KUBERNETES_DEPLOYMENT.md).

## 🧪 Testing

### Running Tests

```bash
# Run all tests
./Test-Scanner.ps1

# Run specific test suites
Invoke-Pester -Path ./tests/Pester/
Invoke-Pester -Path ./tests/Unit/
Invoke-Pester -Path ./tests/Integration/
```

### Performance Testing

```bash
# Run performance benchmarks
./tests/Performance/Test-ScannerPerformance.ps1
```

### Test Coverage

The test suite includes:
- **Unit Tests**: Individual module testing
- **Integration Tests**: End-to-end workflow testing
- **Performance Tests**: Benchmarking and optimization
- **Pester Tests**: PowerShell-specific testing framework

## 🤝 Contributing

### Development Setup

```bash
# Fork and clone the repository
git clone https://github.com/yourusername/Linux-Hardening-Compliance-Scanner.git
cd Linux-Hardening-Compliance-Scanner

# Create development branch
git checkout -b feature/new-feature

# Install development dependencies
./Install-Scanner.ps1 -Development
```

### Code Standards

- Follow PowerShell best practices and conventions
- Use consistent naming and formatting
- Add comprehensive error handling
- Include inline documentation and comments
- Write tests for new functionality

### Pull Request Process

1. **Fork** the repository
2. **Create** a feature branch
3. **Implement** your changes with tests
4. **Run** the full test suite
5. **Submit** a pull request with detailed description

### Adding New Checks

```powershell
# Create new check in appropriate module
function New-CustomCheck {
    [CmdletBinding()]
    param()

    $check = [CheckResult]::new()
    $check.ID = "CUSTOM-001"
    $check.Name = "Custom Security Check"
    $check.Category = "Access Control"
    $check.Severity = "High"

    # Implement check logic
    $result = Test-CustomRequirement

    if ($result) {
        $check.Status = "PASS"
        $check.Message = "Requirement met"
    } else {
        $check.Status = "FAIL"
        $check.Message = "Requirement not met"
        $check.Remediation = "Run remediation command"
    }

    return $check
}
```

## 🔧 Troubleshooting

### Common Issues

#### Permission Denied Errors
```bash
# Run with sudo for full system access
sudo ./scanner.ps1 -Profile cis_level1

# Or run specific checks without root
./scanner.ps1 -Profile custom -SkipModules
```

#### PowerShell Version Issues
```bash
# Check PowerShell version
$PSVersionTable.PSVersion

# Install latest PowerShell (Ubuntu/Debian)
wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y powershell
```

#### Memory Issues
```bash
# Increase memory limit for large scans
export PSModulePath=/usr/local/share/powershell/Modules:$PSModulePath

# Run with reduced scope
./scanner.ps1 -Profile cis_level1 -IncludeOnly "1.*"
```

#### Network Timeout Issues
```bash
# Increase timeout for slow networks
./scanner.ps1 -Profile nist_800_53 -Timeout 7200

# Skip network-dependent checks
./scanner.ps1 -Profile custom -Exclude "NET-*"
```

### Debug Mode

```bash
# Enable detailed logging
$env:SCANNER_DEBUG = $true
./scanner.ps1 -Profile cis_level1

# View debug logs
Get-Content ./logs/scanner_debug.log
```

### Getting Help

- **Documentation**: Check the `docs/` directory for detailed guides
- **Issues**: Report bugs on GitHub Issues
- **Discussions**: Join community discussions for questions
- **Examples**: Review example scripts in `examples/` directory

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- CIS Benchmarks for security best practices
- NIST for security control frameworks
- PowerShell community for scripting excellence
- Open source security tools and libraries

## 📞 Support

- **GitHub Issues**: Bug reports and feature requests
- **Documentation**: Comprehensive guides in `docs/` directory
- **Community**: Join discussions and share knowledge
- **Professional Services**: Enterprise support available

---

**Happy Scanning! 🔒🛡️**
