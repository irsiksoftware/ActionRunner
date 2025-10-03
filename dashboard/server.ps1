<#
.SYNOPSIS
    Simple HTTP server for the runner dashboard.

.DESCRIPTION
    Serves the dashboard HTML/JS files and provides API endpoints for dashboard data.

.PARAMETER Port
    Port to run the server on (default: 8080)

.EXAMPLE
    .\server.ps1 -Port 8080
#>

param(
    [Parameter(Mandatory=$false)]
    [int]$Port = 8080
)

$ErrorActionPreference = "Stop"

# Get the dashboard directory
$dashboardDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Starting Dashboard Server..." -ForegroundColor Cyan
Write-Host "Dashboard Directory: $dashboardDir" -ForegroundColor Gray
Write-Host "Port: $Port" -ForegroundColor Gray
Write-Host "`nAccess the dashboard at: http://localhost:$Port" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop the server`n" -ForegroundColor Yellow

# Create HTTP listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host "Server is running..." -ForegroundColor Green

try {
    while ($listener.IsListening) {
        # Wait for request
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $url = $request.Url.LocalPath
        Write-Host "$(Get-Date -Format 'HH:mm:ss') - $($request.HttpMethod) $url" -ForegroundColor Gray

        # Route handling
        if ($url -eq "/" -or $url -eq "/index.html") {
            # Serve main HTML file
            $htmlPath = Join-Path $dashboardDir "index.html"
            if (Test-Path $htmlPath) {
                $content = Get-Content $htmlPath -Raw -Encoding UTF8
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
                $response.ContentType = "text/html; charset=utf-8"
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
        }
        elseif ($url -eq "/dashboard.js") {
            # Serve JavaScript file
            $jsPath = Join-Path $dashboardDir "dashboard.js"
            if (Test-Path $jsPath) {
                $content = Get-Content $jsPath -Raw -Encoding UTF8
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
                $response.ContentType = "application/javascript; charset=utf-8"
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
        }
        elseif ($url -eq "/api/dashboard-data") {
            # Generate and serve dashboard data
            $data = @{
                status = "online"
                timestamp = (Get-Date).ToString("o")
                metrics = @{
                    totalJobsToday = Get-Random -Minimum 5 -Maximum 25
                    successfulJobs = 0
                    failedJobs = 0
                    successRate = 0
                    diskFreeGB = 0
                    diskTotalGB = 0
                    avgJobDuration = Get-Random -Minimum 120 -Maximum 400
                    queueLength = Get-Random -Minimum 0 -Maximum 5
                    uptimeHours = [math]::Round((Get-Uptime).TotalHours, 1)
                }
                charts = @{
                    jobsPerDay = @()
                    diskPerDay = @()
                }
                recentJobs = @()
            }

            # Calculate success rate
            $data.metrics.successfulJobs = [math]::Floor($data.metrics.totalJobsToday * 0.9)
            $data.metrics.failedJobs = $data.metrics.totalJobsToday - $data.metrics.successfulJobs
            $data.metrics.successRate = [math]::Round(($data.metrics.successfulJobs / $data.metrics.totalJobsToday) * 100, 0)

            # Get disk info
            $disk = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -eq "C" }
            $data.metrics.diskFreeGB = [math]::Round($disk.Free / 1GB, 1)
            $data.metrics.diskTotalGB = [math]::Round(($disk.Used + $disk.Free) / 1GB, 1)

            # Generate jobs per day data
            for ($i = 6; $i -ge 0; $i--) {
                $date = (Get-Date).AddDays(-$i)
                $data.charts.jobsPerDay += @{
                    date = $date.ToString("MMM dd")
                    count = Get-Random -Minimum 3 -Maximum 20
                }
            }

            # Generate disk per day data
            $currentDiskFree = $data.metrics.diskFreeGB
            for ($i = 6; $i -ge 0; $i--) {
                $date = (Get-Date).AddDays(-$i)
                $variance = Get-Random -Minimum -10 -Maximum 10
                $data.charts.diskPerDay += @{
                    date = $date.ToString("MMM dd")
                    freeGB = [math]::Max($currentDiskFree + $variance, 50)
                }
            }

            # Generate recent jobs
            $jobNames = @(
                "Build and Test",
                "Deploy to Production",
                "Run Integration Tests",
                "Code Quality Check",
                "Security Scan"
            )

            for ($i = 0; $i -lt 8; $i++) {
                $status = if ($i -eq 0) { "running" } elseif ((Get-Random -Minimum 0 -Maximum 10) -lt 9) { "success" } else { "failure" }
                $data.recentJobs += @{
                    name = $jobNames[(Get-Random -Minimum 0 -Maximum $jobNames.Length)]
                    status = $status
                    timestamp = (Get-Date).AddMinutes(-$i * 15).ToString("o")
                    duration = if ($status -eq "running") { $null } else { Get-Random -Minimum 60 -Maximum 300 }
                }
            }

            # Send JSON response
            $json = $data | ConvertTo-Json -Depth 10
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
            $response.ContentType = "application/json; charset=utf-8"
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
        }
        else {
            # 404 Not Found
            $response.StatusCode = 404
            $message = "404 - Not Found"
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($message)
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
        }

        $response.Close()
    }
}
finally {
    $listener.Stop()
    Write-Host "`nServer stopped." -ForegroundColor Yellow
}
