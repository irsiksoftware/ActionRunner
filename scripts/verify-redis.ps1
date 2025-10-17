#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies Redis database client is properly installed and configured.

.DESCRIPTION
    This script checks that the Redis Python client (redis-py) and its dependencies are installed
    and properly configured on the self-hosted runner. It validates the ability to
    import and use basic Redis functionality.

    Checks include:
    - Python installation and version
    - redis-py package installation
    - Redis client import and basic functionality
    - Connection test (if URL provided)
    - Docker container availability (if local setup)

.PARAMETER ExitOnFailure
    Exit with code 1 if any checks fail (useful for CI/CD)

.PARAMETER JsonOutput
    Output results in JSON format

.PARAMETER MinimumPythonVersion
    Minimum required Python version (default: 3.8)

.PARAMETER MinimumRedisVersion
    Minimum required redis-py client version (default: 4.0.0)

.PARAMETER RedisHost
    Redis server host for connection testing (default: localhost)

.PARAMETER RedisPort
    Redis server port for connection testing (default: 6379)

.PARAMETER Password
    Optional Redis password for connection testing

.PARAMETER Database
    Redis database number (default: 0)

.PARAMETER SkipConnectionTest
    Skip the connection test to Redis instance

.EXAMPLE
    .\verify-redis.ps1

.EXAMPLE
    .\verify-redis.ps1 -ExitOnFailure

.EXAMPLE
    .\verify-redis.ps1 -JsonOutput

.EXAMPLE
    .\verify-redis.ps1 -RedisHost "localhost" -RedisPort 6379

.EXAMPLE
    .\verify-redis.ps1 -RedisHost "localhost" -Password "mypassword" -Database 1

.NOTES
    Author: ActionRunner Team
    Version: 1.0.0
    Created for Issue #94: Redis verification tests
#>

[CmdletBinding()]
param(
    [switch]$ExitOnFailure,
    [switch]$JsonOutput,
    [string]$MinimumPythonVersion = "3.8",
    [string]$MinimumRedisVersion = "4.0.0",
    [string]$RedisHost = "localhost",
    [int]$RedisPort = 6379,
    [string]$Password,
    [int]$Database = 0,
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
    Write-Host "`n=== Redis Database Verification ===" -ForegroundColor Cyan
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

# Check 3: redis package installed
Test-Requirement `
    -Name "redis Package" `
    -Expected "Version $MinimumRedisVersion or higher" `
    -FailureMessage "redis-py not installed or version below $MinimumRedisVersion" `
    -Check {
        $redisVersion = python -c "import redis; print(redis.__version__)" 2>&1
        if ($LASTEXITCODE -eq 0 -and $redisVersion) {
            $version = $redisVersion.ToString().Trim()
            try {
                $installedVersion = [version]($version -split '-')[0]
                $minVersion = [version]$MinimumRedisVersion
                @{ Passed = ($installedVersion -ge $minVersion); Value = "redis $version" }
            }
            catch {
                @{ Passed = $true; Value = "redis $version" }
            }
        }
        else {
            @{ Passed = $false; Value = "Not installed" }
        }
    }

# Check 4: redis client import
Test-Requirement `
    -Name "redis Client Import" `
    -Expected "redis module imports successfully" `
    -FailureMessage "Failed to import redis module" `
    -Check {
        $result = python -c "import redis; print('OK')" 2>&1
        if ($LASTEXITCODE -eq 0 -and $result -match 'OK') {
            @{ Passed = $true; Value = "redis imported" }
        }
        else {
            @{ Passed = $false; Value = "Import failed: $result" }
        }
    }

# Check 5: Redis client import
Test-Requirement `
    -Name "Redis Client Import" `
    -Expected "Redis class available" `
    -FailureMessage "Redis class not available" `
    -Check {
        $result = python -c "from redis import Redis; print('OK')" 2>&1
        if ($LASTEXITCODE -eq 0 -and $result -match 'OK') {
            @{ Passed = $true; Value = "Redis client available" }
        }
        else {
            @{ Passed = $false; Value = "Import failed: $result" }
        }
    }

# Check 6: Basic functionality test
$testDir = Join-Path $env:TEMP "redis_test_$(Get-Random)"
try {
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    $testScript = @'
import redis
from redis import Redis
import sys

try:
    # Test basic client initialization (without connecting)
    # This validates the client can be instantiated
    client = Redis(host='localhost', port=6379, socket_connect_timeout=1, socket_timeout=1, decode_responses=True)

    print("Client initialization successful")
    sys.exit(0)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
'@

    $testFile = Join-Path $testDir "test_redis.py"
    Set-Content -Path $testFile -Value $testScript -Encoding UTF8

    Test-Requirement `
        -Name "Redis Basic Functionality Test" `
        -Expected "Create and use basic Redis client" `
        -FailureMessage "Failed to create or use Redis client" `
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
    -FailureMessage "Docker not available (optional for local Redis instance)" `
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

# Check 8: Redis Docker container (Warning only)
Test-Requirement `
    -Name "Redis Docker Container" `
    -Expected "Redis container running locally" `
    -FailureMessage "Redis container not running (optional)" `
    -Severity "Warning" `
    -Check {
        $containers = docker ps --filter "ancestor=redis" --format "{{.Names}}" 2>&1
        if ($LASTEXITCODE -eq 0 -and $containers) {
            @{ Passed = $true; Value = "Container running: $containers" }
        }
        else {
            @{ Passed = $false; Value = "Not running" }
        }
    }

# Check 9: Connection test (if not skipped)
if (-not $SkipConnectionTest) {
    $testDir = Join-Path $env:TEMP "redis_connection_test_$(Get-Random)"
    try {
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null

        $passwordParam = ""
        if ($Password) {
            $passwordParam = ", password='$Password'"
        }

        $connectionTest = @"
import redis
from redis import Redis
import sys

try:
    client = Redis(host='$RedisHost', port=$RedisPort, db=$Database$passwordParam, socket_connect_timeout=5, socket_timeout=5, decode_responses=True)

    # Test connection by pinging server
    response = client.ping()
    if response:
        # Get server info
        info = client.info('server')
        version = info.get('redis_version', 'unknown')
        print(f"Connection successful - Redis version {version}")
        client.close()
        sys.exit(0)
    else:
        print("Connection failed: ping returned False", file=sys.stderr)
        sys.exit(1)
except Exception as e:
    print(f"Connection failed: {e}", file=sys.stderr)
    sys.exit(1)
"@

        $testFile = Join-Path $testDir "test_connection.py"
        Set-Content -Path $testFile -Value $connectionTest -Encoding UTF8

        Test-Requirement `
            -Name "Redis Connection Test" `
            -Expected "Successfully connect to Redis instance" `
            -FailureMessage "Failed to connect to Redis instance at ${RedisHost}:${RedisPort}" `
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

# Check 10: redis-py advanced features
Test-Requirement `
    -Name "Redis Pipeline Support" `
    -Expected "Pipeline class available" `
    -FailureMessage "Pipeline class not available" `
    -Severity "Warning" `
    -Check {
        $result = python -c "from redis import Redis; r = Redis(); p = r.pipeline(); print('OK')" 2>&1
        if ($LASTEXITCODE -eq 0 -and $result -match 'OK') {
            @{ Passed = $true; Value = "Pipeline available" }
        }
        else {
            @{ Passed = $false; Value = "Not available" }
        }
    }

# Check 11: Connection pool support
Test-Requirement `
    -Name "Connection Pool Support" `
    -Expected "ConnectionPool class available" `
    -FailureMessage "ConnectionPool class not available" `
    -Severity "Warning" `
    -Check {
        $result = python -c "from redis import ConnectionPool; print('OK')" 2>&1
        if ($LASTEXITCODE -eq 0 -and $result -match 'OK') {
            @{ Passed = $true; Value = "ConnectionPool available" }
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
