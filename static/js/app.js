// Linux Security Scanner - Frontend JavaScript
// Handles dynamic UI interactions and API communications

document.addEventListener('DOMContentLoaded', function() {
    // Initialize tooltips
    initializeTooltips();

    // Initialize form validations
    initializeFormValidations();

    // Initialize real-time updates
    initializeRealTimeUpdates();

    // Initialize keyboard shortcuts
    initializeKeyboardShortcuts();

    console.log('Linux Security Scanner UI initialized');
});

// Initialize Bootstrap tooltips
function initializeTooltips() {
    const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
    tooltipTriggerList.map(function (tooltipTriggerEl) {
        return new bootstrap.Tooltip(tooltipTriggerEl);
    });
}

// Form validation
function initializeFormValidations() {
    // Scan form validation
    const scanForm = document.getElementById('scanForm');
    if (scanForm) {
        scanForm.addEventListener('submit', function(e) {
            const profile = document.getElementById('profile').value;
            if (!profile) {
                e.preventDefault();
                showAlert('Please select a scan profile', 'danger');
                return false;
            }

            // Show loading state
            const submitBtn = scanForm.querySelector('button[type="submit"]');
            submitBtn.disabled = true;
            submitBtn.innerHTML = '<i class="bi bi-play-circle-fill me-2"></i>Starting Scan...';
        });
    }
}

// Real-time updates for active scans
function initializeRealTimeUpdates() {
    // Update active scan counters every 30 seconds
    setInterval(updateActiveScans, 30000);

    // Update dashboard stats every 60 seconds
    if (document.getElementById('complianceChart')) {
        setInterval(updateDashboardStats, 60000);
    }
}

// Update active scans counter
async function updateActiveScans() {
    try {
        // This would be replaced with actual API call
        const activeScansIndicator = document.querySelector('.navbar-nav .nav-link.text-warning');
        if (activeScansIndicator) {
            // In a real implementation, fetch from API
            console.log('Checking for active scans...');
        }
    } catch (error) {
        console.error('Error updating active scans:', error);
    }
}

// Update dashboard statistics
async function updateDashboardStats() {
    try {
        const response = await fetch('/api/scans/summary');
        const data = await response.json();

        // Update summary cards
        updateSummaryCards(data);

        // Update charts if they exist
        if (typeof updateComplianceChart === 'function') {
            updateComplianceChart(data);
        }
        if (typeof updateRiskChart === 'function') {
            updateRiskChart(data);
        }
    } catch (error) {
        console.error('Error updating dashboard stats:', error);
    }
}

// Update summary cards with new data
function updateSummaryCards(data) {
    // This would update the dashboard cards with real-time data
    console.log('Updating summary cards with data:', data);
}

// Keyboard shortcuts
function initializeKeyboardShortcuts() {
    document.addEventListener('keydown', function(e) {
        // Ctrl/Cmd + Enter to submit forms
        if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
            const activeForm = document.activeElement.closest('form');
            if (activeForm) {
                e.preventDefault();
                activeForm.dispatchEvent(new Event('submit'));
            }
        }

        // Escape to close modals
        if (e.key === 'Escape') {
            const openModal = document.querySelector('.modal.show');
            if (openModal) {
                bootstrap.Modal.getInstance(openModal).hide();
            }
        }
    });
}

// Utility functions

// Show alert messages
function showAlert(message, type = 'info', duration = 5000) {
    const alertContainer = document.querySelector('.container.mt-3') || document.body;

    const alertHTML = `
        <div class="alert alert-${type} alert-dismissible fade show" role="alert">
            ${message}
            <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
    `;

    alertContainer.insertAdjacentHTML('afterbegin', alertHTML);

    // Auto-dismiss after duration
    setTimeout(() => {
        const alert = alertContainer.querySelector('.alert');
        if (alert) {
            alert.remove();
        }
    }, duration);
}

// Format file size
function formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';

    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));

    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

// Format duration
function formatDuration(seconds) {
    if (seconds < 60) return `${seconds}s`;

    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;

    if (minutes < 60) return `${minutes}m ${remainingSeconds}s`;

    const hours = Math.floor(minutes / 60);
    const remainingMinutes = minutes % 60;

    return `${hours}h ${remainingMinutes}m ${remainingSeconds}s`;
}

// Copy to clipboard
async function copyToClipboard(text) {
    try {
        await navigator.clipboard.writeText(text);
        showAlert('Copied to clipboard!', 'success', 2000);
    } catch (error) {
        // Fallback for older browsers
        const textArea = document.createElement('textarea');
        textArea.value = text;
        document.body.appendChild(textArea);
        textArea.select();
        document.execCommand('copy');
        document.body.removeChild(textArea);
        showAlert('Copied to clipboard!', 'success', 2000);
    }
}

// Debounce function for search inputs
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Export functions for global use
window.showAlert = showAlert;
window.formatFileSize = formatFileSize;
window.formatDuration = formatDuration;
window.copyToClipboard = copyToClipboard;

// Scan-specific functions

// Quick scan from dashboard
function quickScan(profile) {
    // Create a form and submit it
    const form = document.createElement('form');
    form.method = 'POST';
    form.action = '/scan';

    const profileInput = document.createElement('input');
    profileInput.type = 'hidden';
    profileInput.name = 'profile';
    profileInput.value = profile;

    const outputFormatInput = document.createElement('input');
    outputFormatInput.type = 'hidden';
    outputFormatInput.name = 'output_format';
    outputFormatInput.value = 'text';

    form.appendChild(profileInput);
    form.appendChild(outputFormatInput);
    document.body.appendChild(form);
    form.submit();
}

// View scan details
function viewScan(scanId) {
    window.location.href = `/scan/${scanId}`;
}

// Download scan result
function downloadScan(scanId, filename) {
    const link = document.createElement('a');
    link.href = `/download/${filename}`;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}

// Delete scan
function deleteScan(scanId) {
    if (confirm(`Are you sure you want to delete scan ${scanId}?`)) {
        // In a real implementation, this would make an API call
        showAlert(`Scan ${scanId} deleted successfully`, 'success');
        // Reload the page or update the table
        setTimeout(() => location.reload(), 1000);
    }
}

// Filter and search functions
function filterScans() {
    const searchTerm = document.getElementById('scanSearch').value.toLowerCase();
    const statusFilter = document.getElementById('statusFilter').value;
    const profileFilter = document.getElementById('profileFilter').value;

    const rows = document.querySelectorAll('#scansTable tbody tr');

    rows.forEach(row => {
        const text = row.textContent.toLowerCase();
        const status = row.dataset.status;
        const profile = row.dataset.profile;

        const matchesSearch = !searchTerm || text.includes(searchTerm);
        const matchesStatus = !statusFilter || status === statusFilter;
        const matchesProfile = !profileFilter || profile === profileFilter;

        row.style.display = (matchesSearch && matchesStatus && matchesProfile) ? '' : 'none';
    });
}

// Pagination
function changePage(page) {
    const url = new URL(window.location);
    url.searchParams.set('page', page);
    window.location.href = url.toString();
}

// Auto-refresh functionality
let autoRefreshInterval;

function toggleAutoRefresh() {
    const button = document.getElementById('autoRefreshToggle');
    if (autoRefreshInterval) {
        clearInterval(autoRefreshInterval);
        autoRefreshInterval = null;
        button.innerHTML = '<i class="bi bi-play-circle me-1"></i>Enable Auto-Refresh';
        button.classList.remove('btn-success');
        button.classList.add('btn-outline-secondary');
    } else {
        autoRefreshInterval = setInterval(() => {
            location.reload();
        }, 30000); // Refresh every 30 seconds
        button.innerHTML = '<i class="bi bi-pause-circle me-1"></i>Disable Auto-Refresh';
        button.classList.remove('btn-outline-secondary');
        button.classList.add('btn-success');
    }
}

// Export functionality
function exportScans(format) {
    const selectedScans = Array.from(document.querySelectorAll('.scan-checkbox:checked'))
                              .map(cb => cb.value);

    if (selectedScans.length === 0) {
        showAlert('Please select scans to export', 'warning');
        return;
    }

    // In a real implementation, this would make an API call
    showAlert(`Exporting ${selectedScans.length} scans as ${format.toUpperCase()}`, 'info');

    // Simulate download
    setTimeout(() => {
        showAlert(`Export completed! ${selectedScans.length} scans exported as ${format.toUpperCase()}`, 'success');
    }, 2000);
}

// Theme switching (future enhancement)
function toggleTheme() {
    const html = document.documentElement;
    const currentTheme = html.getAttribute('data-bs-theme');
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';

    html.setAttribute('data-bs-theme', newTheme);
    localStorage.setItem('theme', newTheme);

    const button = document.getElementById('themeToggle');
    if (button) {
        button.innerHTML = newTheme === 'dark'
            ? '<i class="bi bi-sun me-1"></i>Light Mode'
            : '<i class="bi bi-moon me-1"></i>Dark Mode';
    }
}

// Initialize theme on page load
const savedTheme = localStorage.getItem('theme') || 'light';
document.documentElement.setAttribute('data-bs-theme', savedTheme);

// Error handling
window.addEventListener('error', function(e) {
    console.error('JavaScript error:', e.error);
    showAlert('An unexpected error occurred. Please refresh the page.', 'danger');
});

window.addEventListener('unhandledrejection', function(e) {
    console.error('Unhandled promise rejection:', e.reason);
    showAlert('An unexpected error occurred. Please refresh the page.', 'danger');
});

// Performance monitoring
if ('performance' in window && 'timing' in performance) {
    window.addEventListener('load', function() {
        const loadTime = performance.timing.loadEventEnd - performance.timing.navigationStart;
        console.log(`Page load time: ${loadTime}ms`);
    });
}
