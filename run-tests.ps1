Import-Module Pester -MinimumVersion 5.0.0
$config = New-PesterConfiguration
$config.Run.Path = './tests/detect-capabilities.Tests.ps1'
$config.Output.Verbosity = 'None'
$config.Run.PassThru = $true
$result = Invoke-Pester -Configuration $config
Write-Host "Passed: $($result.PassedCount) Failed: $($result.FailedCount) Skipped: $($result.SkippedCount)"
if ($result.FailedCount -gt 0) {
    $result.Failed | ForEach-Object {
        Write-Host "FAILED: $($_.Name)" -ForegroundColor Red
        Write-Host "  $($_.ErrorRecord)" -ForegroundColor Yellow
    }
}
