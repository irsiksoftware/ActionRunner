$testFile = "tests\install-runner.Tests.ps1"
$content = Get-Content $testFile -Raw
$errors = $null
$tokens = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors)

if ($errors) {
    Write-Host "Parse errors found:" -ForegroundColor Red
    foreach ($parseError in $errors) {
        $line = $parseError.Token.StartLine
        $col = $parseError.Token.StartColumn
        $text = $parseError.Token.Content
        Write-Host "Line $line, Col $col : $($parseError.Message)" -ForegroundColor Yellow
        Write-Host "  Token: '$text'" -ForegroundColor Cyan
    }
} else {
    Write-Host "No parse errors found!" -ForegroundColor Green
}
