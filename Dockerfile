# Linux Hardening & Compliance Scanner - Docker Image
# Multi-stage build for scanner and web interface

# ============================
# Stage 1: Scanner Base Image
# ============================
FROM ubuntu:22.04 AS scanner-base

# Labels
LABEL maintainer="Linux Security Scanner Team"
LABEL description="Linux Hardening & Compliance Scanner"
LABEL version="1.0.0"

# Environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV SCANNER_HOME=/opt/scanner
ENV PYTHONUNBUFFERED=1

# Install system dependencies for scanner
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create scanner directories
RUN mkdir -p $SCANNER_HOME && \
    mkdir -p $SCANNER_HOME/results && \
    mkdir -p $SCANNER_HOME/logs && \
    mkdir -p $SCANNER_HOME/config

# Set working directory
WORKDIR $SCANNER_HOME

# Copy scanner files
COPY scanner.sh $SCANNER_HOME/
COPY modules/ $SCANNER_HOME/modules/
COPY config/ $SCANNER_HOME/config/

# Make scanner executable
RUN chmod +x $SCANNER_HOME/scanner.sh && \
    chmod +x $SCANNER_HOME/modules/*.sh

# Create non-root user for scanning
RUN useradd -m -s /bin/bash scanner && \
    chown -R scanner:scanner $SCANNER_HOME

# ============================
# Stage 2: Web Application
# ============================
FROM scanner-base AS webapp

# Install Python and pip
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy Python requirements and install
COPY requirements.txt $SCANNER_HOME/
RUN pip install --no-cache-dir -r $SCANNER_HOME/requirements.txt

# Copy web application files
COPY app.py $SCANNER_HOME/
COPY run_webapp.py $SCANNER_HOME/
COPY templates/ $SCANNER_HOME/templates/
COPY static/ $SCANNER_HOME/static/

# Create web application directories
RUN mkdir -p $SCANNER_HOME/uploads && \
    chown -R scanner:scanner $SCANNER_HOME

# Switch to non-root user
USER scanner

# Health check for web application
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5000/api/scans/summary || exit 1

# Expose web port
EXPOSE 5000

# Default command - run web application
CMD ["python", "run_webapp.py"]

# ============================
# Stage 3: CLI Scanner Only
# ============================
FROM scanner-base AS scanner-cli

# Switch to non-root user
USER scanner

# Default command - show help
CMD ["./scanner.sh", "--help"]

# ============================
# Stage 4: Test Environment
# ============================
FROM scanner-base AS test-env

    # Install additional testing tools
    RUN apt-get update && apt-get install -y \
        python3 \
        python3-pip \
        && rm -rf /var/lib/apt/lists/*

    # Install Python testing dependencies
    RUN pip3 install --no-cache-dir pytest

    # Copy test files
    COPY docker-tests/ $SCANNER_HOME/tests/

    # Copy web app for testing
    COPY app.py run_webapp.py requirements.txt $SCANNER_HOME/
    COPY templates/ $SCANNER_HOME/templates/
    COPY static/ $SCANNER_HOME/static/

    # Make test scripts executable
    RUN chmod +x $SCANNER_HOME/tests/test_scanner.sh $SCANNER_HOME/tests/docker-integration-test.sh

# Switch to non-root user
USER scanner

# Default command - run tests
CMD ["./tests/test_scanner.sh"]

# ============================
# Default target: Web Application
# ============================
FROM webapp

# Add metadata
LABEL org.opencontainers.image.title="Linux Hardening & Compliance Scanner"
LABEL org.opencontainers.image.description="A comprehensive security scanner for Linux systems with web interface"
LABEL org.opencontainers.image.vendor="Linux Security Scanner Team"
LABEL org.opencontainers.image.version="1.0.0"
