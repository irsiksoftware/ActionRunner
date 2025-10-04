# Add Docker Desktop to Windows Startup
$dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
$runKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

Write-Host "Adding Docker Desktop to Windows startup..." -ForegroundColor Cyan

if (Test-Path $dockerPath) {
    Set-ItemProperty -Path $runKey -Name "Docker Desktop" -Value "`"$dockerPath`""
    Write-Host "✓ Docker Desktop added to startup" -ForegroundColor Green
    Write-Host "  It will start automatically on system boot" -ForegroundColor Gray

    # Verify
    $value = Get-ItemProperty -Path $runKey -Name "Docker Desktop" -ErrorAction SilentlyContinue
    if ($value) {
        Write-Host ""
        Write-Host "Registry entry created:" -ForegroundColor Yellow
        Write-Host "  $($value.'Docker Desktop')" -ForegroundColor Gray
    }
} else {
    Write-Host "✗ Docker Desktop not found at: $dockerPath" -ForegroundColor Red
}
