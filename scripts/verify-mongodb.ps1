#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies MongoDB database client is properly installed and configured.

.DESCRIPTION
    This script checks that the MongoDB Python client (pymongo) and its dependencies are installed
    and properly configured on the self-hosted runner. It validates the ability to
    import and use basic MongoDB functionality.

    Checks include:
    - Python installation and version
    - pymongo package installation
    - pymongo client import and basic functionality
    - Connection test (if URL provided)
    - Docker container availability (if local setup)

.PARAMETER ExitOnFailure
    Exit with code 1 if any checks fail (useful for CI/CD)

.PARAMETER JsonOutput
    Output results in JSON format

.PARAMETER MinimumPythonVersion
    Minimum required Python version (default: 3.8)

.PARAMETER MinimumMongoDBVersion
    Minimum required pymongo client version (default: 4.0.0)

.PARAMETER MongoDBUrl
    Optional MongoDB connection URL for connection testing (default: mongodb://localhost:27017)

.PARAMETER Username
    Optional MongoDB username for connection testing

.PARAMETER Password
    Optional MongoDB password for connection testing

.PARAMETER SkipConnectionTest
    Skip the connection test to MongoDB instance

.EXAMPLE
    .\verify-mongodb.ps1

.EXAMPLE
    .\verify-mongodb.ps1 -ExitOnFailure

.EXAMPLE
    .\verify-mongodb.ps1 -JsonOutput

.EXAMPLE
    .\verify-mongodb.ps1 -MongoDBUrl "mongodb://localhost:27017"

.EXAMPLE
    .\verify-mongodb.ps1 -MongoDBUrl "mongodb://localhost:27017" -Username "admin" -Password "password"

.NOTES
    Author: ActionRunner Team
    Version: 1.0.0
    Created for Issue #93: MongoDB verification tests
#>

[CmdletBinding()]
param(
    [switch]$ExitOnFailure,
    [switch]$JsonOutput,
    [string]$MinimumPythonVersion = "3.8",
    [string]$MinimumMongoDBVersion = "4.0.0",
    [string]$MongoDBUrl = "mongodb://localhost:27017",
    [string]$Username,
    [string]$Password,
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
    Write-Host "`n=== MongoDB Database Verification ===" -ForegroundColor Cyan
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

# Check 3: pymongo package installed
Test-Requirement `
    -Name "pymongo Package" `
    -Expected "Version $MinimumMongoDBVersion or higher" `
    -FailureMessage "pymongo not installed or version below $MinimumMongoDBVersion" `
    -Check {
        $mongoVersion = python -c "import pymongo; print(pymongo.__version__)" 2>&1
        if ($LASTEXITCODE -eq 0 -and $mongoVersion) {
            $version = $mongoVersion.ToString().Trim()
            try {
                $installedVersion = [version]($version -split '-')[0]
                $minVersion = [version]$MinimumMongoDBVersion
                @{ Passed = ($installedVersion -ge $minVersion); Value = "pymongo $version" }
            }
            catch {
                @{ Passed = $true; Value = "pymongo $version" }
            }
        }
        else {
            @{ Passed = $false; Value = "Not installed" }
        }
    }

# Check 4: pymongo client import
Test-Requirement `
    -Name "pymongo Client Import" `
    -Expected "pymongo module imports successfully" `
    -FailureMessage "Failed to import pymongo module" `
    -Check {
        $result = python -c "import pymongo; print('OK')" 2>&1
        if ($LASTEXITCODE -eq 0 -and $result -match 'OK') {
            @{ Passed = $true; Value = "pymongo imported" }
        }
        else {
            @{ Passed = $false; Value = "Import failed: $result" }
        }
    }

# Check 5: MongoClient import
Test-Requirement `
    -Name "MongoClient Import" `
    -Expected "MongoClient class available" `
    -FailureMessage "MongoClient class not available" `
    -Check {
        $result = python -c "from pymongo import MongoClient; print('OK')" 2>&1
        if ($LASTEXITCODE -eq 0 -and $result -match 'OK') {
            @{ Passed = $true; Value = "MongoClient available" }
        }
        else {
            @{ Passed = $false; Value = "Import failed: $result" }
        }
    }

# Check 6: Basic functionality test
$testDir = Join-Path $env:TEMP "mongodb_test_$(Get-Random)"
try {
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    $testScript = @'
import pymongo
from pymongo import MongoClient
import sys

try:
    # Test basic client initialization (without connecting)
    # This validates the client can be instantiated
    client = MongoClient(serverSelectionTimeoutMS=1000, connectTimeoutMS=1000)

    print("Client initialization successful")
    sys.exit(0)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
'@

    $testFile = Join-Path $testDir "test_mongodb.py"
    Set-Content -Path $testFile -Value $testScript -Encoding UTF8

    Test-Requirement `
        -Name "MongoDB Basic Functionality Test" `
        -Expected "Create and use basic MongoClient" `
        -FailureMessage "Failed to create or use MongoClient" `
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
    -FailureMessage "Docker not available (optional for local MongoDB instance)" `
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

# Check 8: MongoDB Docker container (Warning only)
Test-Requirement `
    -Name "MongoDB Docker Container" `
    -Expected "MongoDB container running locally" `
    -FailureMessage "MongoDB container not running (optional)" `
    -Severity "Warning" `
    -Check {
        $containers = docker ps --filter "ancestor=mongo" --format "{{.Names}}" 2>&1
        if ($LASTEXITCODE -eq 0 -and $containers) {
            @{ Passed = $true; Value = "Container running: $containers" }
        }
        else {
            @{ Passed = $false; Value = "Not running" }
        }
    }

# Check 9: Connection test (if not skipped)
if (-not $SkipConnectionTest) {
    $testDir = Join-Path $env:TEMP "mongodb_connection_test_$(Get-Random)"
    try {
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null

        $authParams = ""
        if ($Username -and $Password) {
            $authParams = ", username='$Username', password='$Password'"
        }

        $connectionTest = @"
import pymongo
from pymongo import MongoClient
import sys

try:
    client = MongoClient('$MongoDBUrl'$authParams, serverSelectionTimeoutMS=5000)

    # Test connection by getting server info
    server_info = client.server_info()
    version = server_info.get('version', 'unknown')
    print(f"Connection successful - MongoDB version {version}")
    client.close()
    sys.exit(0)
except Exception as e:
    print(f"Connection failed: {e}", file=sys.stderr)
    sys.exit(1)
"@

        $testFile = Join-Path $testDir "test_connection.py"
        Set-Content -Path $testFile -Value $connectionTest -Encoding UTF8

        Test-Requirement `
            -Name "MongoDB Connection Test" `
            -Expected "Successfully connect to MongoDB instance" `
            -FailureMessage "Failed to connect to MongoDB instance at $MongoDBUrl" `
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

# Check 10: BSON support
Test-Requirement `
    -Name "BSON Support" `
    -Expected "bson module available" `
    -FailureMessage "bson module not available" `
    -Severity "Warning" `
    -Check {
        $result = python -c "import bson; print(bson.__version__)" 2>&1
        if ($LASTEXITCODE -eq 0) {
            @{ Passed = $true; Value = "bson $result" }
        }
        else {
            @{ Passed = $false; Value = "Not available" }
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
