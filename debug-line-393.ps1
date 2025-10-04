$testFile = "tests\install-runner.Tests.ps1"
$lines = Get-Content $testFile
$line393 = $lines[392]  # 0-indexed

Write-Host "Line 393 content:"
Write-Host $line393
Write-Host "`nLength: $($line393.Length)"

Write-Host "`nCharacters from position 85 to 92:"
for ($i = 85; $i -le [Math]::Min(92, $line393.Length - 1); $i++) {
    $char = $line393[$i]
    $code = [int][char]$char
    Write-Host "Pos $i : '$char' (0x$($code.ToString('X2')))"
}
