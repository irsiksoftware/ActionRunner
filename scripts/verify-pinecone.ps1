#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies Pinecone vector database client is properly installed and configured.

.DESCRIPTION
    This script checks that the Pinecone Python client and its dependencies are installed
    and properly configured on the self-hosted runner. It validates the ability to
    import and use basic Pinecone functionality.

    Checks include:
    - Python installation and version
    - Pinecone client package installation
    - Pinecone client import and basic functionality
    - Environment variable configuration (optional)
    - Connection test (if API key provided)

.PARAMETER ExitOnFailure
    Exit with code 1 if any checks fail (useful for CI/CD)

.PARAMETER JsonOutput
    Output results in JSON format

.PARAMETER MinimumPythonVersion
    Minimum required Python version (default: 3.8)

.PARAMETER MinimumPineconeVersion
    Minimum required Pinecone version (default: 2.0.0)

.PARAMETER ApiKey
    Optional Pinecone API key for connection testing

.PARAMETER Environment
    Optional Pinecone environment for connection testing

.EXAMPLE
    .\verify-pinecone.ps1

.EXAMPLE
    .\verify-pinecone.ps1 -ExitOnFailure

.EXAMPLE
    .\verify-pinecone.ps1 -JsonOutput

.EXAMPLE
    .\verify-pinecone.ps1 -ApiKey "your-api-key" -Environment "us-west1-gcp"

.NOTES
    Author: ActionRunner Team
    Version: 1.0.0
    Created for Issue #78: Vector database verification
#>

[CmdletBinding()]
param(
    [switch]$ExitOnFailure,
    [switch]$JsonOutput,
    [string]$MinimumPythonVersion = "3.8",
    [string]$MinimumPineconeVersion = "2.0.0",
    [string]$ApiKey,
    [string]$Environment
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
    Write-Host "`n=== Pinecone Vector Database Verification ===" -ForegroundColor Cyan
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

# Check 3: Pinecone client package installed
Test-Requirement `
    -Name "Pinecone Client Package" `
    -Expected "Version $MinimumPineconeVersion or higher" `
    -FailureMessage "Pinecone client not installed or version below $MinimumPineconeVersion" `
    -Check {
        $pineconeVersion = python -c "import pinecone; print(pinecone.__version__)" 2>&1
        if ($LASTEXITCODE -eq 0 -and $pineconeVersion) {
            $version = $pineconeVersion.ToString().Trim()
            try {
                $installedVersion = [version]($version -split '-')[0]
                $minVersion = [version]$MinimumPineconeVersion
                @{ Passed = ($installedVersion -ge $minVersion); Value = "pinecone $version" }
            }
            catch {
                @{ Passed = $true; Value = "pinecone $version" }
            }
        }
        else {
            @{ Passed = $false; Value = "Not installed" }
        }
    }

# Check 4: Pinecone client import
Test-Requirement `
    -Name "Pinecone Client Import" `
    -Expected "pinecone module imports successfully" `
    -FailureMessage "Failed to import pinecone module" `
    -Check {
        $result = python -c "from pinecone import Pinecone; print('OK')" 2>&1
        if ($LASTEXITCODE -eq 0 -and $result -match 'OK') {
            @{ Passed = $true; Value = "Pinecone client imported" }
        }
        else {
            @{ Passed = $false; Value = "Import failed: $result" }
        }
    }

# Check 5: Pinecone gRPC support (Warning only)
Test-Requirement `
    -Name "Pinecone gRPC Support" `
    -Expected "grpc dependencies available" `
    -FailureMessage "gRPC dependencies not available (optional for performance)" `
    -Severity "Warning" `
    -Check {
        $result = python -c "import grpc; print('OK')" 2>&1
        if ($LASTEXITCODE -eq 0 -and $result -match 'OK') {
            @{ Passed = $true; Value = "gRPC support available" }
        }
        else {
            @{ Passed = $false; Value = "Not available" }
        }
    }

# Check 6: Environment variables (Warning only)
Test-Requirement `
    -Name "Pinecone API Key Environment Variable" `
    -Expected "PINECONE_API_KEY environment variable set" `
    -FailureMessage "PINECONE_API_KEY not set (optional)" `
    -Severity "Warning" `
    -Check {
        if ($env:PINECONE_API_KEY -or $ApiKey) {
            @{ Passed = $true; Value = "API key configured" }
        }
        else {
            @{ Passed = $false; Value = "Not set" }
        }
    }

# Check 7: Basic functionality test
$testDir = Join-Path $env:TEMP "pinecone_test_$(Get-Random)"
try {
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    $testScript = @'
from pinecone import Pinecone, ServerlessSpec
import sys

try:
    # Test basic client initialization (without connecting)
    # This validates the client can be instantiated
    pc = Pinecone(api_key="test-key-for-validation")

    # Test ServerlessSpec creation
    spec = ServerlessSpec(cloud="aws", region="us-east-1")

    print("Client initialization successful")
    sys.exit(0)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
'@

    $testFile = Join-Path $testDir "test_pinecone.py"
    Set-Content -Path $testFile -Value $testScript -Encoding UTF8

    Test-Requirement `
        -Name "Pinecone Basic Functionality Test" `
        -Expected "Create and use basic Pinecone client" `
        -FailureMessage "Failed to create or use Pinecone client" `
        -Check {
            $output = python $testFile 2>&1
            if ($LASTEXITCODE -eq 0 -and $output -match 'successful') {
                @{ Passed = $true; Value = "Basic functionality working" }
            }
            else {
                @{ Passed = $false; Value = "Test failed: $output" }
            }
        }
}
finally {
    if (Test-Path $testDir) {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 8: Connection test (if API key provided)
if ($ApiKey) {
    $testDir = Join-Path $env:TEMP "pinecone_connection_test_$(Get-Random)"
    try {
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null

        $connectionTest = @"
from pinecone import Pinecone
import sys

try:
    pc = Pinecone(api_key="$ApiKey")

    # List indexes to verify connection
    indexes = pc.list_indexes()

    print(f"Connection successful - {len(indexes)} indexes found")
    sys.exit(0)
except Exception as e:
    print(f"Connection failed: {e}", file=sys.stderr)
    sys.exit(1)
"@

        $testFile = Join-Path $testDir "test_connection.py"
        Set-Content -Path $testFile -Value $connectionTest -Encoding UTF8

        Test-Requirement `
            -Name "Pinecone Connection Test" `
            -Expected "Successfully connect to Pinecone service" `
            -FailureMessage "Failed to connect to Pinecone service" `
            -Check {
                $output = python $testFile 2>&1
                if ($LASTEXITCODE -eq 0 -and $output -match 'successful') {
                    @{ Passed = $true; Value = $output.ToString().Trim() }
                }
                else {
                    @{ Passed = $false; Value = "Connection failed: $output" }
                }
            }
    }
    finally {
        if (Test-Path $testDir) {
            Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Check 9: NumPy dependency (Warning only)
Test-Requirement `
    -Name "NumPy Package" `
    -Expected "numpy package installed" `
    -FailureMessage "numpy package not installed (recommended for vector operations)" `
    -Severity "Warning" `
    -Check {
        $result = python -c "import numpy; print(numpy.__version__)" 2>&1
        if ($LASTEXITCODE -eq 0) {
            @{ Passed = $true; Value = "numpy $result" }
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
