<#
.SYNOPSIS
    Simple HTTP server for the runner dashboard.

.DESCRIPTION
    Serves the dashboard HTML/JS files and provides API endpoints for dashboard data.
    Data is sourced from real runner logs and system metrics via the DashboardDataProvider module.

.PARAMETER Port
    Port to run the server on (default: 8080)

.PARAMETER LogPath
    Path to runner logs directory. Defaults to auto-detection of common runner locations.

.EXAMPLE
    .\server.ps1 -Port 8080

.EXAMPLE
    .\server.ps1 -Port 8080 -LogPath "C:\actions-runner\_diag"
#>

param(
    [Parameter(Mandatory=$false)]
    [int]$Port = 8080,

    [Parameter(Mandatory=$false)]
    [string]$LogPath
)

$ErrorActionPreference = "Stop"

# Get the dashboard directory and import the data provider module
$dashboardDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path (Split-Path -Parent $dashboardDir) "modules" "DashboardDataProvider.psm1"

if (Test-Path $modulePath) {
    Import-Module $modulePath -Force -WarningAction SilentlyContinue
    Write-Host "Loaded DashboardDataProvider module" -ForegroundColor Green
} else {
    Write-Host "Warning: DashboardDataProvider module not found at $modulePath" -ForegroundColor Yellow
    Write-Host "Dashboard will use fallback data" -ForegroundColor Yellow
}

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
            # Get dashboard data from real sources via DashboardDataProvider module
            $data = $null

            if (Get-Command -Name 'Get-DashboardData' -ErrorAction SilentlyContinue) {
                # Use the DashboardDataProvider module for real data
                try {
                    $data = Get-DashboardData -LogPath $LogPath
                } catch {
                    Write-Host "Error getting dashboard data: $_" -ForegroundColor Red
                }
            }

            # Fallback to basic data if module is unavailable or failed
            if ($null -eq $data) {
                $disk = Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -eq "C" }

                $data = @{
                    status = "offline"
                    timestamp = (Get-Date).ToString("o")
                    metrics = @{
                        totalJobsToday = 0
                        successfulJobs = 0
                        failedJobs = 0
                        successRate = 0
                        diskFreeGB = if ($disk) { [math]::Round($disk.Free / 1GB, 1) } else { 0 }
                        diskTotalGB = if ($disk) { [math]::Round(($disk.Used + $disk.Free) / 1GB, 1) } else { 0 }
                        avgJobDuration = 0
                        queueLength = 0
                        uptimeHours = [math]::Round((Get-Uptime).TotalHours, 1)
                    }
                    charts = @{
                        jobsPerDay = @()
                        diskPerDay = @()
                    }
                    recentJobs = @()
                }

                # Generate empty chart data
                for ($i = 6; $i -ge 0; $i--) {
                    $date = (Get-Date).AddDays(-$i)
                    $data.charts.jobsPerDay += @{
                        date = $date.ToString("MMM dd")
                        count = 0
                    }
                    $data.charts.diskPerDay += @{
                        date = $date.ToString("MMM dd")
                        freeGB = $data.metrics.diskFreeGB
                    }
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
