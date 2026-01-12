#!/usr/bin/env python3
"""
Linux Hardening & Compliance Scanner - Web App Launcher
A simple script to run the Flask web application
"""

import os
import sys
import subprocess
from pathlib import Path

def check_python_version():
    """Check if Python version is compatible"""
    if sys.version_info < (3, 6):
        print("❌ Python 3.6 or higher is required")
        print(f"   Current version: {sys.version}")
        return False
    print(f"✅ Python {sys.version.split()[0]} detected")
    return True

def check_dependencies():
    """Check if required Python packages are installed"""
    required_packages = ['flask', 'werkzeug', 'jinja2']

    missing_packages = []
    for package in required_packages:
        try:
            __import__(package)
            print(f"✅ {package} is installed")
        except ImportError:
            missing_packages.append(package)
            print(f"❌ {package} is missing")

    if missing_packages:
        print(f"\n📦 Installing missing packages: {', '.join(missing_packages)}")
        try:
            subprocess.check_call([sys.executable, '-m', 'pip', 'install'] + missing_packages)
            print("✅ Dependencies installed successfully")
            return True
        except subprocess.CalledProcessError:
            print("❌ Failed to install dependencies")
            print("   Try running: pip install -r requirements.txt")
            return False

    return True

def check_project_structure():
    """Check if project structure is correct"""
    required_files = [
        'app.py',
        'scanner.sh',
        'templates/base.html',
        'static/css/style.css',
        'static/js/app.js'
    ]

    missing_files = []
    for file_path in required_files:
        if not Path(file_path).exists():
            missing_files.append(file_path)

    if missing_files:
        print("❌ Missing required files:")
        for file_path in missing_files:
            print(f"   - {file_path}")
        return False

    print("✅ Project structure is complete")
    return True

def check_scanner_executable():
    """Check if scanner.sh is executable"""
    scanner_path = Path('scanner.sh')
    if scanner_path.exists():
        if os.access(scanner_path, os.X_OK):
            print("✅ scanner.sh is executable")
            return True
        else:
            print("⚠️  scanner.sh is not executable, attempting to fix...")
            try:
                scanner_path.chmod(0o755)
                print("✅ scanner.sh permissions fixed")
                return True
            except Exception as e:
                print(f"❌ Failed to make scanner.sh executable: {e}")
                return False
    else:
        print("❌ scanner.sh not found")
        return False

def main():
    """Main launcher function"""
    print("🚀 Linux Hardening & Compliance Scanner - Web App Launcher")
    print("=" * 60)

    # Run checks
    checks = [
        ("Python version", check_python_version),
        ("Project structure", check_project_structure),
        ("Scanner executable", check_scanner_executable),
        ("Python dependencies", check_dependencies)
    ]

    all_passed = True
    for check_name, check_func in checks:
        print(f"\n🔍 Checking {check_name}...")
        if not check_func():
            all_passed = False

    if not all_passed:
        print("\n❌ Some checks failed. Please fix the issues above and try again.")
        sys.exit(1)

    print("\n✅ All checks passed! Starting web application...")

    # Start the Flask application
    print("\n🌐 Starting Flask web application...")
    print("   URL: http://localhost:5000")
    print("   Press Ctrl+C to stop the server")
    print("-" * 60)

    try:
        # Import and run the Flask app
        from app import app
        app.run(
            host='0.0.0.0',
            port=5000,
            debug=True,
            use_reloader=False  # Disable reloader in launcher
        )
    except KeyboardInterrupt:
        print("\n\n🛑 Server stopped by user")
    except Exception as e:
        print(f"\n❌ Failed to start web application: {e}")
        print("   Make sure no other service is using port 5000")
        sys.exit(1)

if __name__ == '__main__':
    main()
