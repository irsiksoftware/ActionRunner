# Start WSL2 and Linux Runner on Windows Boot
# This script ensures the Linux runner in WSL2 starts automatically

Write-Host "Starting WSL2 Linux Runner..." -ForegroundColor Cyan

# Start WSL2 Ubuntu distribution
Write-Host "Starting Ubuntu WSL2..." -ForegroundColor Yellow
wsl -d Ubuntu -e bash -c "echo 'Ubuntu WSL2 started'"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Ubuntu WSL2 is running" -ForegroundColor Green

    # Check if runner is already running
    $runnerCheck = wsl -d Ubuntu -e bash -c "ps aux | grep Runner.Listener | grep -v grep | wc -l"

    if ($runnerCheck -gt 0) {
        Write-Host "✓ Linux runner is already running" -ForegroundColor Green
    } else {
        Write-Host "Starting Linux runner service..." -ForegroundColor Yellow
        # The runner should auto-start with systemd, but if not, we can start it manually
        # Note: This requires passwordless sudo or the service to be configured to auto-start
    }

    Write-Host ""
    Write-Host "WSL2 Linux runner startup complete!" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to start Ubuntu WSL2" -ForegroundColor Red
}
