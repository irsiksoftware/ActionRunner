$testFile = "tests\install-runner.Tests.ps1"
$content = Get-Content $testFile -Raw

# Unicode quote characters (using char codes to avoid issues)
$leftDoubleQuote = [char]0x201C  # "
$rightDoubleQuote = [char]0x201D # "
$leftSingleQuote = [char]0x2018  # '
$rightSingleQuote = [char]0x2019 # '

# Count Unicode quotes
$leftDoubleCount = ([regex]::Matches($content, [regex]::Escape($leftDoubleQuote))).Count
$rightDoubleCount = ([regex]::Matches($content, [regex]::Escape($rightDoubleQuote))).Count
$leftSingleCount = ([regex]::Matches($content, [regex]::Escape($leftSingleQuote))).Count
$rightSingleCount = ([regex]::Matches($content, [regex]::Escape($rightSingleQuote))).Count

Write-Host "Found Unicode quotes:"
Write-Host "  Left double:  $leftDoubleCount"
Write-Host "  Right double: $rightDoubleCount"
Write-Host "  Left single:  $leftSingleCount"
Write-Host "  Right single: $rightSingleCount"

# Replace Unicode quotes with ASCII quotes
$fixed = $content.Replace($leftDoubleQuote, '"').Replace($rightDoubleQuote, '"').Replace($leftSingleQuote, "'").Replace($rightSingleQuote, "'")

# Write back
Set-Content $testFile -Value $fixed -NoNewline

Write-Host "`nFixed! Replaced all Unicode quotes with ASCII quotes." -ForegroundColor Green
