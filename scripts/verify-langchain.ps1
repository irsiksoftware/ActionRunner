#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies LangChain Python package is properly installed and configured.

.DESCRIPTION
    This script checks that the LangChain package and its dependencies are installed
    and properly configured on the self-hosted runner. It validates the ability to
    import and use basic LangChain functionality.

    Checks include:
    - Python installation and version
    - LangChain package installation
    - LangChain core components availability
    - Basic LangChain import and usage
    - Common LangChain dependencies

.PARAMETER ExitOnFailure
    Exit with code 1 if any checks fail (useful for CI/CD)

.PARAMETER JsonOutput
    Output results in JSON format

.PARAMETER MinimumPythonVersion
    Minimum required Python version (default: 3.8)

.PARAMETER MinimumLangChainVersion
    Minimum required LangChain version (default: 0.1.0)

.EXAMPLE
    .\verify-langchain.ps1

.EXAMPLE
    .\verify-langchain.ps1 -ExitOnFailure

.EXAMPLE
    .\verify-langchain.ps1 -JsonOutput

.EXAMPLE
    .\verify-langchain.ps1 -MinimumPythonVersion "3.9" -MinimumLangChainVersion "0.2.0"

.NOTES
    Author: ActionRunner Team
    Version: 1.0.0
    Created for Issue #76: LangChain dependency verification
#>

[CmdletBinding()]
param(
    [switch]$ExitOnFailure,
    [switch]$JsonOutput,
    [string]$MinimumPythonVersion = "3.8",
    [string]$MinimumLangChainVersion = "0.1.0"
)

$ErrorActionPreference = 'Continue'

# Results collection
$results = @{
    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    checks = @()
    passed = 0
    failed = 0
    warnings = 0
}

function Test-Requirement {
    param(
        [string]$Name,
        [scriptblock]$Check,
        [string]$Expected,
        [string]$FailureMessage,
        [string]$Severity = 'Error'  # Error or Warning
    )

    try {
        $result = & $Check

        $checkResult = @{
            name = $Name
            expected = $Expected
            actual = $result.Value
            passed = $result.Passed
            message = if ($result.Passed) { "OK" } else { $FailureMessage }
            severity = if ($result.Passed) { "Pass" } else { $Severity }
        }

        if ($result.Passed) {
            $script:results.passed++
            if (-not $JsonOutput) {
                Write-Host "✅ $Name : $($result.Value)" -ForegroundColor Green
            }
        }
        else {
            if ($Severity -eq 'Error') {
                $script:results.failed++
                if (-not $JsonOutput) {
                    Write-Host "❌ $Name : $FailureMessage" -ForegroundColor Red
                }
            }
            else {
                $script:results.warnings++
                if (-not $JsonOutput) {
                    Write-Host "⚠️  $Name : $FailureMessage" -ForegroundColor Yellow
                }
            }
        }

        $script:results.checks += $checkResult
    }
    catch {
        $script:results.failed++
        $checkResult = @{
            name = $Name
            expected = $Expected
            actual = "Error: $($_.Exception.Message)"
            passed = $false
            message = $FailureMessage
            severity = 'Error'
        }
        $script:results.checks += $checkResult

        if (-not $JsonOutput) {
            Write-Host "❌ $Name : Error - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

if (-not $JsonOutput) {
    Write-Host "`n=== LangChain Environment Verification ===" -ForegroundColor Cyan
    Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray
}

# Check 1: Python installed
Test-Requirement `
    -Name "Python Interpreter" `
    -Expected "Version $MinimumPythonVersion or higher" `
    -FailureMessage "Python not found or version below $MinimumPythonVersion" `
    -Check {
        $pythonVersion = python --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $pythonVersion) {
            # Parse "Python 3.11.0" format
            if ($pythonVersion -match 'Python ([\d.]+)') {
                $version = $matches[1]
                $installedVersion = [version]($version -split '-')[0]
                $minVersion = [version]$MinimumPythonVersion
                @{ Passed = ($installedVersion -ge $minVersion); Value = "Python $version" }
            }
            else {
                @{ Passed = $false; Value = "Unable to parse version" }
            }
        }
        else {
            @{ Passed = $false; Value = "Not installed" }
        }
    }

# Check 2: pip installed
Test-Requirement `
    -Name "pip Package Manager" `
    -Expected "pip installed and accessible" `
    -FailureMessage "pip not found or not accessible" `
    -Check {
        $pipVersion = python -m pip --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $pipVersion) {
            if ($pipVersion -match 'pip ([\d.]+)') {
                $version = $matches[1]
                @{ Passed = $true; Value = "pip $version" }
            }
            else {
                @{ Passed = $true; Value = $pipVersion.ToString().Trim() }
            }
        }
        else {
            @{ Passed = $false; Value = "Not installed" }
        }
    }

# Check 3: LangChain package installed
Test-Requirement `
    -Name "LangChain Package" `
    -Expected "Version $MinimumLangChainVersion or higher" `
    -FailureMessage "LangChain not installed or version below $MinimumLangChainVersion" `
    -Check {
        $langchainVersion = python -c "import langchain; print(langchain.__version__)" 2>&1
        if ($LASTEXITCODE -eq 0 -and $langchainVersion) {
            # Remove any leading/trailing whitespace
            $version = $langchainVersion.ToString().Trim()
            try {
                $installedVersion = [version]($version -split '-')[0]
                $minVersion = [version]$MinimumLangChainVersion
                @{ Passed = ($installedVersion -ge $minVersion); Value = "langchain $version" }
            }
            catch {
                # If version parsing fails, just check it's installed
                @{ Passed = $true; Value = "langchain $version" }
            }
        }
        else {
            @{ Passed = $false; Value = "Not installed" }
        }
    }

# Check 4: LangChain core components
Test-Requirement `
    -Name "LangChain Core Import" `
    -Expected "langchain.llms module available" `
    -FailureMessage "LangChain core components not available" `
    -Check {
        $result = python -c "from langchain.llms import OpenAI; print('OK')" 2>&1
        if ($LASTEXITCODE -eq 0 -and $result -match 'OK') {
            @{ Passed = $true; Value = "Core components available" }
        }
        else {
            @{ Passed = $false; Value = "Import failed: $result" }
        }
    }

# Check 5: LangChain chains module
Test-Requirement `
    -Name "LangChain Chains Module" `
    -Expected "langchain.chains module available" `
    -FailureMessage "LangChain chains module not available" `
    -Check {
        $result = python -c "from langchain.chains import LLMChain; print('OK')" 2>&1
        if ($LASTEXITCODE -eq 0 -and $result -match 'OK') {
            @{ Passed = $true; Value = "Chains module available" }
        }
        else {
            @{ Passed = $false; Value = "Import failed: $result" }
        }
    }

# Check 6: LangChain prompts module
Test-Requirement `
    -Name "LangChain Prompts Module" `
    -Expected "langchain.prompts module available" `
    -FailureMessage "LangChain prompts module not available" `
    -Check {
        $result = python -c "from langchain.prompts import PromptTemplate; print('OK')" 2>&1
        if ($LASTEXITCODE -eq 0 -and $result -match 'OK') {
            @{ Passed = $true; Value = "Prompts module available" }
        }
        else {
            @{ Passed = $false; Value = "Import failed: $result" }
        }
    }

# Check 7: LangChain agents module (Warning only)
Test-Requirement `
    -Name "LangChain Agents Module" `
    -Expected "langchain.agents module available" `
    -FailureMessage "LangChain agents module not available (optional)" `
    -Severity "Warning" `
    -Check {
        $result = python -c "from langchain.agents import AgentType; print('OK')" 2>&1
        if ($LASTEXITCODE -eq 0 -and $result -match 'OK') {
            @{ Passed = $true; Value = "Agents module available" }
        }
        else {
            @{ Passed = $false; Value = "Not available" }
        }
    }

# Check 8: Create simple LangChain test
$testDir = Join-Path $env:TEMP "langchain_test_$(Get-Random)"
try {
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    $testScript = @'
from langchain.prompts import PromptTemplate

# Test basic prompt template creation
template = PromptTemplate(
    input_variables=["topic"],
    template="Write a short sentence about {topic}."
)

# Test formatting
result = template.format(topic="testing")
print("Template created and formatted successfully")
'@

    $testFile = Join-Path $testDir "test_langchain.py"
    Set-Content -Path $testFile -Value $testScript -Encoding UTF8

    Test-Requirement `
        -Name "LangChain Basic Functionality Test" `
        -Expected "Create and use basic LangChain components" `
        -FailureMessage "Failed to create or use LangChain components" `
        -Check {
            $output = python $testFile 2>&1
            if ($LASTEXITCODE -eq 0 -and $output -match 'successfully') {
                @{ Passed = $true; Value = "Basic functionality working" }
            }
            else {
                @{ Passed = $false; Value = "Test failed: $output" }
            }
        }
}
finally {
    # Cleanup
    if (Test-Path $testDir) {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 9: Common dependencies (Warning only)
Test-Requirement `
    -Name "OpenAI Python Package" `
    -Expected "openai package installed" `
    -FailureMessage "openai package not installed (recommended for LangChain)" `
    -Severity "Warning" `
    -Check {
        $result = python -c "import openai; print(openai.__version__)" 2>&1
        if ($LASTEXITCODE -eq 0) {
            @{ Passed = $true; Value = "openai $result" }
        }
        else {
            @{ Passed = $false; Value = "Not installed" }
        }
    }

# Summary
if (-not $JsonOutput) {
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Passed: $($results.passed)" -ForegroundColor Green
    Write-Host "Failed: $($results.failed)" -ForegroundColor Red
    Write-Host "Warnings: $($results.warnings)" -ForegroundColor Yellow
    Write-Host "Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
}
else {
    $results | ConvertTo-Json -Depth 10
}

# Exit with appropriate code
if ($ExitOnFailure -and $results.failed -gt 0) {
    exit 1
}

exit 0
