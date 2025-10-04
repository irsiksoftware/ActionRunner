$testFile = "tests\install-runner.Tests.ps1"
$lines = Get-Content $testFile

$inDoubleQuote = $false
$doubleQuoteOpenLine = 0

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $lineNum = $i + 1

    for ($j = 0; $j -lt $line.Length; $j++) {
        $char = $line[$j]

        if ($char -eq '"') {
            if ($j -gt 0 -and $line[$j-1] -eq '`') {
                # Escaped quote, skip
            } elseif ($j -gt 0 -and $line[$j-1] -eq '\') {
                # Regex escaped quote, skip
            } else {
                if (-not $inDoubleQuote) {
                    $doubleQuoteOpenLine = $lineNum
                }
                $inDoubleQuote = -not $inDoubleQuote
            }
        }
    }

    if ($lineNum -ge 380 -and $lineNum -le 395) {
        $statusDouble = if ($inDoubleQuote) { "[OPEN at line $doubleQuoteOpenLine]" } else { "[CLOSED]" }
        Write-Host "Line $lineNum $statusDouble : $line"
    }

    if ($lineNum -eq 393) {
        break
    }
}
