# Linux Hardening & Compliance Scanner - Web Interface

[![Flask](https://img.shields.io/badge/Flask-2.3+-blue.svg)](https://flask.palletsprojects.com/)
[![Bootstrap](https://img.shields.io/badge/Bootstrap-5.3+-purple.svg)](https://getbootstrap.com)
[![Python](https://img.shields.io/badge/Python-3.6+-green.svg)](https://python.org)

A modern, responsive web interface for the Linux Hardening & Compliance Scanner built with Flask, Bootstrap 5, and Chart.js.

## 🌟 Features

### 🎨 Modern UI/UX
- **Responsive Design**: Works perfectly on desktop, tablet, and mobile devices
- **Dark Mode Support**: Automatic theme switching based on system preference
- **Interactive Charts**: Real-time visualization of scan results and trends
- **Bootstrap 5**: Latest Bootstrap framework for modern styling

### 📊 Dashboard & Analytics
- **Real-time Statistics**: Live scan metrics and compliance scores
- **Risk Distribution Charts**: Visual representation of security posture
- **Compliance Trends**: Historical analysis of scan results
- **Active Scan Monitoring**: Track running scans in real-time

### 🔧 Scan Management
- **Profile Selection**: Choose from Filesystem, System, SSH, Full, CIS, and Custom scans
- **Output Formats**: Text, JSON, and CSV export options
- **Remediation Support**: Automatic security fix application
- **Advanced Filtering**: Exclude specific checks or include only certain ones

### 📈 Results & Reporting
- **Detailed Results View**: Comprehensive scan result analysis
- **Download Reports**: Export scan results in multiple formats
- **Historical Data**: Browse and search through all past scans
- **Pagination**: Efficient handling of large result sets

### ⚙️ Administration
- **Settings Management**: Configure scan defaults and preferences
- **User Preferences**: Theme selection and notification settings
- **System Diagnostics**: Built-in health checks and troubleshooting

## 🚀 Quick Start

### Prerequisites

- **Python 3.6+** with pip
- **Bash shell** (for the scanner backend)
- **Web browser** (Chrome, Firefox, Safari, Edge)

### Installation

1. **Clone the repository** (if not already done):
   ```bash
   git clone https://github.com/add54/Linux-Hardening-Compliance-Scanner.git
   cd Linux-Hardening-Compliance-Scanner
   ```

2. **Install Python dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

3. **Make scanner executable**:
   ```bash
   chmod +x scanner.sh
   ```

### Running the Application

#### Method 1: Using the Launcher (Recommended)
```bash
python run_webapp.py
```
This script automatically checks for dependencies and fixes common issues.

#### Method 2: Direct Flask Run
```bash
# Set environment variables (optional)
export FLASK_APP=app.py
export FLASK_ENV=development

# Run the application
python -m flask run --host=0.0.0.0 --port=5000
```

#### Method 3: Using Python directly
```bash
python app.py
```

### Access the Web Interface

Once running, open your browser and navigate to:
```
http://localhost:5000
```

## 📱 User Interface Guide

### Dashboard
The main dashboard provides an overview of your security posture:

- **Statistics Cards**: Total scans, average score, and critical issues
- **Charts**: Compliance trends and risk distribution
- **Recent Scans**: Latest scan results with quick actions
- **Active Scans**: Monitor currently running scans

### Starting a Scan

1. **Navigate to Scan Page**: Click "Start New Scan" from dashboard or use the navigation menu
2. **Choose Profile**: Select from available scan profiles
3. **Configure Options**:
   - Output format (Text/JSON/CSV)
   - Enable remediation (auto-fix issues)
   - Exclude specific checks
4. **Start Scan**: Click "Start Scan" to begin

### Viewing Results

1. **Scan Status**: Monitor real-time progress during scan execution
2. **Results Page**: View detailed findings with severity levels
3. **Download Reports**: Export results in your preferred format
4. **Historical View**: Browse all past scans with filtering and search

## 🔧 Configuration

### Application Settings

The web application supports various configuration options:

```python
# In app.py
app.config['SECRET_KEY'] = 'your-secret-key-here'
app.config['UPLOAD_FOLDER'] = 'uploads'
app.config['RESULTS_FOLDER'] = 'results'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB
```

### Environment Variables

```bash
# Flask environment
export FLASK_APP=app.py
export FLASK_ENV=development

# Application settings
export SCANNER_UPLOAD_FOLDER=/path/to/uploads
export SCANNER_RESULTS_FOLDER=/path/to/results
```

### Database

The application uses SQLite for data storage. The database file `scanner.db` is created automatically.

**Database Schema:**
- `scans` table: Stores scan metadata and results
- Automatic creation on first run

## 🌐 API Reference

### REST Endpoints

#### GET `/api/scans/summary`
Returns summary statistics for all scans.

**Response:**
```json
{
  "total_scans": 25,
  "avg_score": 78.5,
  "completed_scans": 23,
  "risk_distribution": {
    "critical": 2,
    "high": 5,
    "medium": 8,
    "low": 10
  }
}
```

#### GET `/api/scan/<scan_id>/status`
Returns status information for a specific scan.

**Response:**
```json
{
  "scan_id": "scan_001",
  "status": "completed",
  "profile": "full",
  "compliance_score": 85,
  "risk_level": "MEDIUM",
  "duration": 120,
  "total_checks": 150,
  "passed_checks": 127,
  "failed_checks": 18,
  "warning_checks": 5
}
```

## 🎨 Customization

### Themes

The application supports light and dark themes:

- **Automatic**: Follows system preference
- **Manual**: Override in settings
- **CSS Variables**: Easy customization

### Custom Styling

Modify `static/css/style.css` to customize appearance:

```css
/* Custom color scheme */
:root {
  --primary-color: #your-color;
  --secondary-color: #your-color;
}

/* Custom component styles */
.custom-card {
  /* Your styles */
}
```

### Templates

Jinja2 templates are located in `templates/`:

- `base.html`: Base template with navigation
- `dashboard.html`: Main dashboard
- `scan.html`: Scan configuration
- `results.html`: Results browser

## 🔒 Security Considerations

### Web Application Security
- **CSRF Protection**: Flask-WTF integration (future enhancement)
- **Input Validation**: Server-side validation for all inputs
- **Secure Headers**: Appropriate security headers (future enhancement)
- **Session Management**: Secure session handling

### Scanner Integration
- **Permission Checks**: Validates scanner.sh permissions
- **Input Sanitization**: Sanitizes all scanner inputs
- **Timeout Protection**: Prevents runaway scan processes
- **Result Validation**: Validates scanner output format

## 🐳 Docker Support

### Building the Docker Image

```dockerfile
# Dockerfile content (create this file)
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
RUN chmod +x scanner.sh

EXPOSE 5000
CMD ["python", "run_webapp.py"]
```

### Running with Docker

```bash
# Build image
docker build -t linux-scanner-web .

# Run container
docker run -p 5000:5000 -v $(pwd)/results:/app/results linux-scanner-web
```

## 🧪 Testing

### Running Tests

```bash
# Install test dependencies
pip install pytest

# Run tests
pytest

# Run with coverage
pytest --cov=app --cov-report=html
```

### Manual Testing

1. **Start the application**
2. **Run different scan profiles**
3. **Test all output formats**
4. **Verify download functionality**
5. **Test responsive design on mobile**

## 🚀 Production Deployment

### Using Gunicorn

```bash
# Install Gunicorn
pip install gunicorn

# Run with Gunicorn
gunicorn -w 4 -b 0.0.0.0:5000 app:app
```

### Using Nginx + Gunicorn

**nginx.conf:**
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Environment Variables for Production

```bash
export FLASK_ENV=production
export SECRET_KEY=your-secure-random-key
export SCANNER_TIMEOUT=1800  # 30 minutes
```

## 🐛 Troubleshooting

### Common Issues

#### "Scanner not executable"
```bash
chmod +x scanner.sh
```

#### "Port already in use"
```bash
# Find process using port 5000
lsof -i :5000
# Kill the process or use different port
python app.py  # Uses port 5000 by default
```

#### "Permission denied" errors
```bash
# Ensure proper permissions for results directory
chmod 755 results/
chmod 755 uploads/
```

#### Database issues
```bash
# Remove and recreate database
rm scanner.db
python -c "from app import init_db; init_db()"
```

### Debug Mode

Enable debug mode for development:
```bash
export FLASK_ENV=development
python app.py
```

### Logging

View application logs:
```bash
# Flask logs appear in console
python app.py

# Scanner logs
tail -f results/scanner_*.log
```

## 📈 Performance Optimization

### Database Optimization
- **Indexes**: Add database indexes for frequently queried columns
- **Pagination**: Implement efficient pagination for large result sets
- **Caching**: Cache frequently accessed data

### Frontend Optimization
- **Minification**: Minify CSS and JavaScript for production
- **CDN**: Use CDN for Bootstrap and Chart.js
- **Lazy Loading**: Load charts and heavy content on demand

### Scanner Integration
- **Async Processing**: Background processing for long-running scans
- **Resource Limits**: CPU and memory limits for scanner processes
- **Timeout Handling**: Proper timeout handling for stuck processes

## 🤝 Contributing

### Development Setup

1. **Fork the repository**
2. **Create feature branch**: `git checkout -b feature/new-feature`
3. **Install dependencies**: `pip install -r requirements.txt`
4. **Run tests**: `pytest`
5. **Make changes**
6. **Submit pull request**

### Code Standards

- **PEP 8**: Follow Python style guidelines
- **Flask Best Practices**: Follow Flask development patterns
- **Security**: Implement secure coding practices
- **Documentation**: Document all new features

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Flask Framework**: For the excellent Python web framework
- **Bootstrap 5**: For the modern, responsive UI components
- **Chart.js**: For the interactive data visualization
- **Bash Scanner**: For the robust command-line security scanner

---

**Ready to secure your Linux systems? 🛡️🔒**

The web interface makes it easy to manage security scans, view results, and maintain compliance across your infrastructure!
