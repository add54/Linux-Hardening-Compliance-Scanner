#!/usr/bin/env python3
"""
Linux Hardening & Compliance Scanner - Web Interface
A modern Flask web application for the Linux Hardening & Compliance Scanner
"""

import os
import json
import subprocess
import threading
import time
from datetime import datetime
from pathlib import Path
from flask import Flask, render_template, request, jsonify, flash, redirect, url_for, send_file
from werkzeug.utils import secure_filename
import sqlite3
from contextlib import contextmanager

# Flask app configuration
app = Flask(__name__)
app.config['SECRET_KEY'] = 'linux-hardening-scanner-secret-key-2024'
app.config['UPLOAD_FOLDER'] = 'uploads'
app.config['RESULTS_FOLDER'] = 'results'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16MB max file size

# Ensure directories exist
os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
os.makedirs(app.config['RESULTS_FOLDER'], exist_ok=True)

# Database setup
DATABASE = 'scanner.db'

@contextmanager
def get_db():
    """Database connection context manager"""
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()

def init_db():
    """Initialize database tables"""
    with get_db() as conn:
        conn.execute('''
            CREATE TABLE IF NOT EXISTS scans (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                scan_id TEXT UNIQUE NOT NULL,
                profile TEXT NOT NULL,
                status TEXT DEFAULT 'running',
                start_time DATETIME DEFAULT CURRENT_TIMESTAMP,
                end_time DATETIME,
                duration INTEGER,
                compliance_score INTEGER,
                risk_level TEXT,
                total_checks INTEGER DEFAULT 0,
                passed_checks INTEGER DEFAULT 0,
                failed_checks INTEGER DEFAULT 0,
                warning_checks INTEGER DEFAULT 0,
                skipped_checks INTEGER DEFAULT 0,
                output_file TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        conn.commit()

# Initialize database on startup
init_db()

# Global variables for scan tracking
active_scans = {}

def run_scan_background(scan_id, profile, output_format='text', fix_mode=False, excluded_checks=''):
    """Run scan in background thread"""
    try:
        # Update scan status to running
        with get_db() as conn:
            conn.execute('UPDATE scans SET status = ? WHERE scan_id = ?',
                        ('running', scan_id))
            conn.commit()

        # Prepare command
        cmd = ['./scanner.sh', profile, '-q']

        if output_format != 'text':
            cmd.extend(['-f', output_format])

        if fix_mode:
            cmd.append('--fix')

        if excluded_checks:
            cmd.extend(['--exclude', excluded_checks])

        # Create output file path
        output_file = f"{scan_id}.{output_format}"
        output_path = os.path.join(app.config['RESULTS_FOLDER'], output_file)
        cmd.extend(['-o', output_path])

        print(f"Running command: {' '.join(cmd)}")

        # Run the scan
        start_time = time.time()
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=3600)
        end_time = time.time()

        duration = int(end_time - start_time)

        # Parse results if JSON output
        compliance_score = 0
        risk_level = 'Unknown'
        total_checks = passed_checks = failed_checks = warning_checks = skipped_checks = 0

        if output_format == 'json' and os.path.exists(output_path):
            try:
                with open(output_path, 'r') as f:
                    data = json.load(f)
                    compliance_score = data.get('compliance_score', 0)
                    risk_level = data.get('risk_level', 'Unknown')
                    summary = data.get('summary', {})
                    total_checks = summary.get('total_checks', 0)
                    passed_checks = summary.get('passed', 0)
                    failed_checks = summary.get('failed', 0)
                    warning_checks = summary.get('warnings', 0)
                    skipped_checks = summary.get('skipped', 0)
            except (json.JSONDecodeError, KeyError) as e:
                print(f"Error parsing JSON results: {e}")

        # Update database with results
        with get_db() as conn:
            conn.execute('''
                UPDATE scans SET
                    status = ?,
                    end_time = CURRENT_TIMESTAMP,
                    duration = ?,
                    compliance_score = ?,
                    risk_level = ?,
                    total_checks = ?,
                    passed_checks = ?,
                    failed_checks = ?,
                    warning_checks = ?,
                    skipped_checks = ?,
                    output_file = ?
                WHERE scan_id = ?
            ''', (
                'completed' if result.returncode == 0 else 'failed',
                duration,
                compliance_score,
                risk_level,
                total_checks,
                passed_checks,
                failed_checks,
                warning_checks,
                skipped_checks,
                output_file,
                scan_id
            ))
            conn.commit()

    except subprocess.TimeoutExpired:
        # Update scan status to timeout
        with get_db() as conn:
            conn.execute('UPDATE scans SET status = ? WHERE scan_id = ?',
                        ('timeout', scan_id))
            conn.commit()
    except Exception as e:
        print(f"Scan error: {e}")
        # Update scan status to error
        with get_db() as conn:
            conn.execute('UPDATE scans SET status = ? WHERE scan_id = ?',
                        ('error', scan_id))
            conn.commit()

@app.route('/')
def dashboard():
    """Main dashboard page"""
    # Get scan statistics
    with get_db() as conn:
        stats = conn.execute('''
            SELECT
                COUNT(*) as total_scans,
                AVG(compliance_score) as avg_score,
                MAX(compliance_score) as best_score,
                MIN(compliance_score) as worst_score,
                SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_scans,
                SUM(CASE WHEN risk_level = 'CRITICAL' THEN 1 ELSE 0 END) as critical_scans,
                SUM(CASE WHEN risk_level = 'HIGH' THEN 1 ELSE 0 END) as high_scans
            FROM scans
        ''').fetchone()

        # Recent scans
        recent_scans = conn.execute('''
            SELECT * FROM scans
            ORDER BY created_at DESC
            LIMIT 10
        ''').fetchall()

    return render_template('dashboard.html',
                         stats=stats,
                         recent_scans=recent_scans,
                         active_scans=active_scans)

@app.route('/scan', methods=['GET', 'POST'])
def scan():
    """Scan configuration and execution page"""
    if request.method == 'POST':
        profile = request.form.get('profile', 'filesystem')
        output_format = request.form.get('output_format', 'text')
        fix_mode = 'fix_mode' in request.form
        excluded_checks = request.form.get('excluded_checks', '')

        # Generate unique scan ID
        scan_id = f"scan_{int(time.time())}_{profile}"

        # Insert scan record
        with get_db() as conn:
            conn.execute('''
                INSERT INTO scans (scan_id, profile, status)
                VALUES (?, ?, ?)
            ''', (scan_id, profile, 'queued'))
            conn.commit()

        # Start scan in background
        thread = threading.Thread(
            target=run_scan_background,
            args=(scan_id, profile, output_format, fix_mode, excluded_checks)
        )
        thread.daemon = True
        thread.start()

        active_scans[scan_id] = {'thread': thread, 'start_time': time.time()}

        flash(f'Scan {scan_id} started successfully!', 'success')
        return redirect(url_for('scan_status', scan_id=scan_id))

    return render_template('scan.html')

@app.route('/scan/<scan_id>')
def scan_status(scan_id):
    """Scan status and results page"""
    with get_db() as conn:
        scan_data = conn.execute('SELECT * FROM scans WHERE scan_id = ?',
                                (scan_id,)).fetchone()

    if not scan_data:
        flash('Scan not found', 'error')
        return redirect(url_for('dashboard'))

    # Check if scan is still active
    is_active = scan_id in active_scans

    return render_template('scan_status.html',
                         scan=scan_data,
                         is_active=is_active)

@app.route('/api/scan/<scan_id>/status')
def api_scan_status(scan_id):
    """API endpoint for scan status"""
    with get_db() as conn:
        scan_data = conn.execute('SELECT * FROM scans WHERE scan_id = ?',
                                (scan_id,)).fetchone()

    if not scan_data:
        return jsonify({'error': 'Scan not found'}), 404

    return jsonify({
        'scan_id': scan_data['scan_id'],
        'status': scan_data['status'],
        'profile': scan_data['profile'],
        'compliance_score': scan_data['compliance_score'],
        'risk_level': scan_data['risk_level'],
        'duration': scan_data['duration'],
        'total_checks': scan_data['total_checks'],
        'passed_checks': scan_data['passed_checks'],
        'failed_checks': scan_data['failed_checks'],
        'warning_checks': scan_data['warning_checks'],
        'skipped_checks': scan_data['skipped_checks']
    })

@app.route('/results')
def results():
    """Results and history page"""
    page = request.args.get('page', 1, type=int)
    per_page = 20
    offset = (page - 1) * per_page

    with get_db() as conn:
        # Get total count
        total = conn.execute('SELECT COUNT(*) FROM scans').fetchone()[0]

        # Get paginated results
        scans = conn.execute('''
            SELECT * FROM scans
            ORDER BY created_at DESC
            LIMIT ? OFFSET ?
        ''', (per_page, offset)).fetchall()

    return render_template('results.html',
                         scans=scans,
                         page=page,
                         per_page=per_page,
                         total=total)

@app.route('/download/<filename>')
def download_result(filename):
    """Download scan result file"""
    file_path = os.path.join(app.config['RESULTS_FOLDER'], filename)
    if os.path.exists(file_path):
        return send_file(file_path, as_attachment=True)
    else:
        flash('File not found', 'error')
        return redirect(url_for('results'))

@app.route('/settings')
def settings():
    """Settings page"""
    return render_template('settings.html')

@app.route('/api/scans/summary')
def api_scans_summary():
    """API endpoint for scans summary"""
    with get_db() as conn:
        summary = conn.execute('''
            SELECT
                COUNT(*) as total_scans,
                AVG(compliance_score) as avg_score,
                SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_scans,
                SUM(CASE WHEN risk_level = 'CRITICAL' THEN 1 ELSE 0 END) as critical_risk,
                SUM(CASE WHEN risk_level = 'HIGH' THEN 1 ELSE 0 END) as high_risk,
                SUM(CASE WHEN risk_level = 'MEDIUM' THEN 1 ELSE 0 END) as medium_risk,
                SUM(CASE WHEN risk_level = 'LOW' THEN 1 ELSE 0 END) as low_risk
            FROM scans
            WHERE status = 'completed'
        ''').fetchone()

    return jsonify({
        'total_scans': summary['total_scans'] or 0,
        'avg_score': round(summary['avg_score'] or 0, 1),
        'completed_scans': summary['completed_scans'] or 0,
        'risk_distribution': {
            'critical': summary['critical_risk'] or 0,
            'high': summary['high_risk'] or 0,
            'medium': summary['medium_risk'] or 0,
            'low': summary['low_risk'] or 0
        }
    })

@app.route('/about')
def about():
    """About page"""
    return render_template('about.html')

@app.errorhandler(404)
def page_not_found(e):
    return render_template('404.html'), 404

@app.errorhandler(500)
def internal_error(e):
    return render_template('500.html'), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
