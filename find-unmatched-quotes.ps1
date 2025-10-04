$testFile = "tests\install-runner.Tests.ps1"
$lines = Get-Content $testFile

$inDoubleQuote = $false
$inSingleQuote = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $lineNum = $i + 1

    for ($j = 0; $j -lt $line.Length; $j++) {
        $char = $line[$j]

        if ($char -eq '"' -and -not $inSingleQuote) {
            if ($j -gt 0 -and $line[$j-1] -eq '`') {
                # Escaped quote, skip
            } else {
                $inDoubleQuote = -not $inDoubleQuote
            }
        } elseif ($char -eq "'" -and -not $inDoubleQuote) {
            if ($j -gt 0 -and $line[$j-1] -eq '`') {
                # Escaped quote, skip
            } else {
                $inSingleQuote = -not $inSingleQuote
            }
        }
    }

    if ($lineNum -eq 393) {
        Write-Host "At line 393:" -ForegroundColor Yellow
        Write-Host "  In double quote: $inDoubleQuote"
        Write-Host "  In single quote: $inSingleQuote"
        break
    }
}

Write-Host "`nScanning backwards from line 393 to find unclosed quote..."
for ($i = 392; $i -ge 0; $i--) {
    $line = $lines[$i]
    $singleCount = ($line.ToCharArray() | Where-Object { $_ -eq "'" }).Count
    $doubleCount = ($line.ToCharArray() | Where-Object { $_ -eq '"' }).Count

    if ($singleCount % 2 -ne 0 -or $doubleCount % 2 -ne 0) {
        Write-Host "Line $($i+1) has unmatched quotes: $line" -ForegroundColor Red
    }
}
