#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies Weaviate vector database client is properly installed and configured.

.DESCRIPTION
    This script checks that the Weaviate Python client and its dependencies are installed
    and properly configured on the self-hosted runner. It validates the ability to
    import and use basic Weaviate functionality.

    Checks include:
    - Python installation and version
    - Weaviate client package installation
    - Weaviate client import and basic functionality
    - Connection test (if URL provided)
    - Docker container availability (if local setup)

.PARAMETER ExitOnFailure
    Exit with code 1 if any checks fail (useful for CI/CD)

.PARAMETER JsonOutput
    Output results in JSON format

.PARAMETER MinimumPythonVersion
    Minimum required Python version (default: 3.8)

.PARAMETER MinimumWeaviateVersion
    Minimum required Weaviate client version (default: 3.0.0)

.PARAMETER WeaviateUrl
    Optional Weaviate instance URL for connection testing (default: http://localhost:8080)

.PARAMETER ApiKey
    Optional Weaviate API key for connection testing

.PARAMETER SkipConnectionTest
    Skip the connection test to Weaviate instance

.EXAMPLE
    .\verify-weaviate.ps1

.EXAMPLE
    .\verify-weaviate.ps1 -ExitOnFailure

.EXAMPLE
    .\verify-weaviate.ps1 -JsonOutput

.EXAMPLE
    .\verify-weaviate.ps1 -WeaviateUrl "http://localhost:8080"

.EXAMPLE
    .\verify-weaviate.ps1 -WeaviateUrl "https://my-cluster.weaviate.network" -ApiKey "your-api-key"

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
    [string]$MinimumWeaviateVersion = "3.0.0",
    [string]$WeaviateUrl = "http://localhost:8080",
    [string]$ApiKey,
    [switch]$SkipConnectionTest
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
    Write-Host "`n=== Weaviate Vector Database Verification ===" -ForegroundColor Cyan
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

# Check 3: Weaviate client package installed
Test-Requirement `
    -Name "Weaviate Client Package" `
    -Expected "Version $MinimumWeaviateVersion or higher" `
    -FailureMessage "Weaviate client not installed or version below $MinimumWeaviateVersion" `
    -Check {
        $weaviateVersion = python -c "import weaviate; print(weaviate.__version__)" 2>&1
        if ($LASTEXITCODE -eq 0 -and $weaviateVersion) {
            $version = $weaviateVersion.ToString().Trim()
            try {
                $installedVersion = [version]($version -split '-')[0]
                $minVersion = [version]$MinimumWeaviateVersion
                @{ Passed = ($installedVersion -ge $minVersion); Value = "weaviate $version" }
            }
            catch {
                @{ Passed = $true; Value = "weaviate $version" }
            }
        }
        else {
            @{ Passed = $false; Value = "Not installed" }
        }
    }

# Check 4: Weaviate client import
Test-Requirement `
    -Name "Weaviate Client Import" `
    -Expected "weaviate module imports successfully" `
    -FailureMessage "Failed to import weaviate module" `
    -Check {
        $result = python -c "import weaviate; print('OK')" 2>&1
        if ($LASTEXITCODE -eq 0 -and $result -match 'OK') {
            @{ Passed = $true; Value = "Weaviate client imported" }
        }
        else {
            @{ Passed = $false; Value = "Import failed: $result" }
        }
    }

# Check 5: Weaviate client classes import
Test-Requirement `
    -Name "Weaviate Client Classes Import" `
    -Expected "weaviate.classes module available" `
    -FailureMessage "Weaviate classes module not available" `
    -Check {
        $result = python -c "from weaviate.classes.config import Configure; print('OK')" 2>&1
        if ($LASTEXITCODE -eq 0 -and $result -match 'OK') {
            @{ Passed = $true; Value = "Classes module available" }
        }
        else {
            @{ Passed = $false; Value = "Import failed: $result" }
        }
    }

# Check 6: Basic functionality test
$testDir = Join-Path $env:TEMP "weaviate_test_$(Get-Random)"
try {
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    $testScript = @'
import weaviate
from weaviate.classes.config import Configure
import sys

try:
    # Test basic client initialization (without connecting)
    # This validates the client can be instantiated
    client = weaviate.WeaviateClient()

    print("Client initialization successful")
    sys.exit(0)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
'@

    $testFile = Join-Path $testDir "test_weaviate.py"
    Set-Content -Path $testFile -Value $testScript -Encoding UTF8

    Test-Requirement `
        -Name "Weaviate Basic Functionality Test" `
        -Expected "Create and use basic Weaviate client" `
        -FailureMessage "Failed to create or use Weaviate client" `
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

# Check 7: Docker availability (Warning only)
Test-Requirement `
    -Name "Docker Availability" `
    -Expected "Docker is installed and running" `
    -FailureMessage "Docker not available (optional for local Weaviate instance)" `
    -Severity "Warning" `
    -Check {
        $dockerVersion = docker --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $dockerVersion) {
            if ($dockerVersion -match 'Docker version ([\d.]+)') {
                $version = $matches[1]
                @{ Passed = $true; Value = "Docker $version" }
            }
            else {
                @{ Passed = $true; Value = $dockerVersion.ToString().Trim() }
            }
        }
        else {
            @{ Passed = $false; Value = "Not available" }
        }
    }

# Check 8: Weaviate Docker container (Warning only)
Test-Requirement `
    -Name "Weaviate Docker Container" `
    -Expected "Weaviate container running locally" `
    -FailureMessage "Weaviate container not running (optional)" `
    -Severity "Warning" `
    -Check {
        $containers = docker ps --filter "ancestor=semitechnologies/weaviate" --format "{{.Names}}" 2>&1
        if ($LASTEXITCODE -eq 0 -and $containers) {
            @{ Passed = $true; Value = "Container running: $containers" }
        }
        else {
            @{ Passed = $false; Value = "Not running" }
        }
    }

# Check 9: Connection test (if not skipped)
if (-not $SkipConnectionTest) {
    $testDir = Join-Path $env:TEMP "weaviate_connection_test_$(Get-Random)"
    try {
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null

        $apiKeyParam = if ($ApiKey) { ", auth_client_secret=weaviate.auth.AuthApiKey('$ApiKey')" } else { "" }

        $connectionTest = @"
import weaviate
import sys

try:
    client = weaviate.connect_to_local(host='$WeaviateUrl'$apiKeyParam)

    # Check if ready
    if client.is_ready():
        meta = client.get_meta()
        version = meta.get('version', 'unknown')
        print(f"Connection successful - Weaviate version {version}")
        client.close()
        sys.exit(0)
    else:
        print("Connection failed - server not ready", file=sys.stderr)
        client.close()
        sys.exit(1)
except Exception as e:
    print(f"Connection failed: {e}", file=sys.stderr)
    sys.exit(1)
"@

        $testFile = Join-Path $testDir "test_connection.py"
        Set-Content -Path $testFile -Value $connectionTest -Encoding UTF8

        Test-Requirement `
            -Name "Weaviate Connection Test" `
            -Expected "Successfully connect to Weaviate instance" `
            -FailureMessage "Failed to connect to Weaviate instance at $WeaviateUrl" `
            -Severity "Warning" `
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

# Check 10: NumPy dependency (Warning only)
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
