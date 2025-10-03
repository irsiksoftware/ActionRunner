// Dashboard data management and UI updates

let dashboardData = null;
let refreshInterval = null;

// Initialize dashboard on page load
document.addEventListener('DOMContentLoaded', function() {
    loadDashboard();
    // Auto-refresh every 30 seconds
    refreshInterval = setInterval(loadDashboard, 30000);
});

// Load dashboard data
async function loadDashboard() {
    try {
        // Try to load data from API endpoint
        const response = await fetch('/api/dashboard-data');
        if (response.ok) {
            dashboardData = await response.json();
        } else {
            // Fallback to mock data if API is not available
            dashboardData = generateMockData();
        }
    } catch (error) {
        console.log('API not available, using mock data');
        dashboardData = generateMockData();
    }

    updateDashboard(dashboardData);
}

// Generate mock data for development/demo
function generateMockData() {
    const now = new Date();
    const jobsPerDay = [];
    const diskPerDay = [];

    // Generate data for last 7 days
    for (let i = 6; i >= 0; i--) {
        const date = new Date(now);
        date.setDate(date.getDate() - i);
        const dateStr = date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });

        jobsPerDay.push({
            date: dateStr,
            count: Math.floor(Math.random() * 20) + 5
        });

        diskPerDay.push({
            date: dateStr,
            freeGB: Math.floor(Math.random() * 50) + 150
        });
    }

    const totalJobs = jobsPerDay[6].count;
    const successfulJobs = Math.floor(totalJobs * 0.92);

    return {
        status: 'online',
        timestamp: now.toISOString(),
        metrics: {
            totalJobsToday: totalJobs,
            successfulJobs: successfulJobs,
            failedJobs: totalJobs - successfulJobs,
            successRate: Math.round((successfulJobs / totalJobs) * 100),
            diskFreeGB: diskPerDay[6].freeGB,
            diskTotalGB: 250,
            avgJobDuration: Math.floor(Math.random() * 300) + 120,
            queueLength: Math.floor(Math.random() * 5),
            uptimeHours: Math.floor(Math.random() * 72) + 1
        },
        charts: {
            jobsPerDay: jobsPerDay,
            diskPerDay: diskPerDay
        },
        recentJobs: generateMockJobs(10)
    };
}

// Generate mock job history
function generateMockJobs(count) {
    const jobs = [];
    const jobNames = [
        'Build and Test',
        'Deploy to Production',
        'Run Integration Tests',
        'Code Quality Check',
        'Security Scan',
        'Build Docker Image',
        'Run Unit Tests',
        'Deploy to Staging',
        'Database Migration',
        'Generate Reports'
    ];

    const statuses = ['success', 'success', 'success', 'success', 'failure', 'running'];

    for (let i = 0; i < count; i++) {
        const minutesAgo = i * 15 + Math.floor(Math.random() * 10);
        const status = i === 0 ? 'running' : statuses[Math.floor(Math.random() * statuses.length)];

        jobs.push({
            name: jobNames[Math.floor(Math.random() * jobNames.length)],
            status: status,
            timestamp: new Date(Date.now() - minutesAgo * 60000).toISOString(),
            duration: status === 'running' ? null : Math.floor(Math.random() * 300) + 60
        });
    }

    return jobs;
}

// Update dashboard UI with data
function updateDashboard(data) {
    if (!data) return;

    // Update status indicator
    const statusDot = document.getElementById('statusDot');
    const statusText = document.getElementById('statusText');

    if (data.status === 'online') {
        statusDot.classList.remove('offline');
        statusText.textContent = 'Runner Online';
    } else {
        statusDot.classList.add('offline');
        statusText.textContent = 'Runner Offline';
    }

    // Update metrics
    const metrics = data.metrics;
    document.getElementById('totalJobs').textContent = metrics.totalJobsToday || 0;
    document.getElementById('successRate').innerHTML = `${metrics.successRate || 0}<span class="metric-unit">%</span>`;
    document.getElementById('diskSpace').innerHTML = `${metrics.diskFreeGB || 0}<span class="metric-unit">GB</span>`;
    document.getElementById('avgDuration').innerHTML = `${metrics.avgJobDuration || 0}<span class="metric-unit">s</span>`;
    document.getElementById('queueLength').textContent = metrics.queueLength || 0;
    document.getElementById('uptime').innerHTML = `${metrics.uptimeHours || 0}<span class="metric-unit">h</span>`;

    // Update metric changes
    const jobsChange = document.getElementById('jobsChange');
    const yesterdayJobs = data.charts.jobsPerDay.length > 1 ? data.charts.jobsPerDay[5].count : 0;
    const jobsDiff = metrics.totalJobsToday - yesterdayJobs;
    jobsChange.textContent = `${jobsDiff >= 0 ? '+' : ''}${jobsDiff} from yesterday`;
    jobsChange.className = jobsDiff >= 0 ? 'metric-change' : 'metric-change negative';

    const successChange = document.getElementById('successChange');
    const successDiff = metrics.successRate - 85; // Compare to target 85%
    successChange.textContent = `${successDiff >= 0 ? '+' : ''}${successDiff}% from target`;
    successChange.className = successDiff >= 0 ? 'metric-change' : 'metric-change negative';

    const diskChange = document.getElementById('diskChange');
    const diskPercent = Math.round((metrics.diskFreeGB / metrics.diskTotalGB) * 100);
    diskChange.textContent = `${diskPercent}% available`;
    diskChange.className = diskPercent > 20 ? 'metric-change' : 'metric-change negative';

    // Update charts
    updateJobsChart(data.charts.jobsPerDay);
    updateDiskChart(data.charts.diskPerDay);

    // Update job list
    updateJobsList(data.recentJobs);

    // Update timestamp
    const now = new Date();
    document.getElementById('lastUpdate').textContent = now.toLocaleTimeString();
}

// Update jobs per day chart
function updateJobsChart(jobsData) {
    const chartContainer = document.getElementById('jobsChart');
    chartContainer.innerHTML = '';

    const maxJobs = Math.max(...jobsData.map(d => d.count), 1);

    jobsData.forEach(day => {
        const bar = document.createElement('div');
        bar.className = 'bar';
        const height = (day.count / maxJobs) * 100;
        bar.style.height = `${height}%`;

        const label = document.createElement('div');
        label.className = 'bar-label';
        label.textContent = day.date;

        const value = document.createElement('div');
        value.className = 'bar-value';
        value.textContent = day.count;

        bar.appendChild(label);
        bar.appendChild(value);
        chartContainer.appendChild(bar);
    });
}

// Update disk space chart
function updateDiskChart(diskData) {
    const chartContainer = document.getElementById('diskChart');
    chartContainer.innerHTML = '';

    const maxDisk = Math.max(...diskData.map(d => d.freeGB), 1);

    diskData.forEach(day => {
        const bar = document.createElement('div');
        bar.className = 'bar';
        const height = (day.freeGB / maxDisk) * 100;
        bar.style.height = `${height}%`;
        bar.style.background = 'linear-gradient(to top, #28a745, #20c997)';

        const label = document.createElement('div');
        label.className = 'bar-label';
        label.textContent = day.date;

        const value = document.createElement('div');
        value.className = 'bar-value';
        value.textContent = `${day.freeGB}GB`;

        bar.appendChild(label);
        bar.appendChild(value);
        chartContainer.appendChild(bar);
    });
}

// Update recent jobs list
function updateJobsList(jobs) {
    const jobsList = document.getElementById('jobsList');
    jobsList.innerHTML = '';

    if (!jobs || jobs.length === 0) {
        jobsList.innerHTML = '<div class="loading">No recent jobs</div>';
        return;
    }

    jobs.forEach(job => {
        const jobItem = document.createElement('div');
        jobItem.className = 'job-item';

        const jobInfo = document.createElement('div');
        jobInfo.className = 'job-info';

        const jobName = document.createElement('div');
        jobName.className = 'job-name';
        jobName.textContent = job.name;

        const jobTime = document.createElement('div');
        jobTime.className = 'job-time';
        jobTime.textContent = formatJobTime(job.timestamp, job.duration);

        jobInfo.appendChild(jobName);
        jobInfo.appendChild(jobTime);

        const jobStatus = document.createElement('div');
        jobStatus.className = `job-status ${job.status}`;
        jobStatus.textContent = job.status.charAt(0).toUpperCase() + job.status.slice(1);

        jobItem.appendChild(jobInfo);
        jobItem.appendChild(jobStatus);
        jobsList.appendChild(jobItem);
    });
}

// Format job timestamp and duration
function formatJobTime(timestamp, duration) {
    const date = new Date(timestamp);
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);

    let timeStr = '';
    if (diffMins < 1) {
        timeStr = 'Just now';
    } else if (diffMins < 60) {
        timeStr = `${diffMins} minute${diffMins > 1 ? 's' : ''} ago`;
    } else {
        const diffHours = Math.floor(diffMins / 60);
        timeStr = `${diffHours} hour${diffHours > 1 ? 's' : ''} ago`;
    }

    if (duration) {
        const durationMins = Math.floor(duration / 60);
        const durationSecs = duration % 60;
        if (durationMins > 0) {
            timeStr += ` • ${durationMins}m ${durationSecs}s`;
        } else {
            timeStr += ` • ${durationSecs}s`;
        }
    }

    return timeStr;
}

// Export functions for external use
window.loadDashboard = loadDashboard;
