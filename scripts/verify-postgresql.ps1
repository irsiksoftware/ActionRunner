#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies PostgreSQL database is properly installed and configured.

.DESCRIPTION
    This script checks that PostgreSQL and its client tools are installed
    and properly configured on the self-hosted runner. It validates the ability to
    connect to and use basic PostgreSQL functionality.

    Checks include:
    - PostgreSQL client (psql) installation and version
    - PostgreSQL server availability (if running locally)
    - Connection test (if credentials provided)
    - Basic SQL operations
    - Environment variable configuration (optional)

.PARAMETER ExitOnFailure
    Exit with code 1 if any checks fail (useful for CI/CD)

.PARAMETER JsonOutput
    Output results in JSON format

.PARAMETER MinimumVersion
    Minimum required PostgreSQL version (default: 12.0)

.PARAMETER Host
    PostgreSQL server host (default: localhost)

.PARAMETER Port
    PostgreSQL server port (default: 5432)

.PARAMETER Database
    Database name for connection testing (default: postgres)

.PARAMETER Username
    Username for connection testing

.PARAMETER Password
    Password for connection testing

.PARAMETER SkipConnectionTest
    Skip the connection test even if credentials are provided

.EXAMPLE
    .\verify-postgresql.ps1

.EXAMPLE
    .\verify-postgresql.ps1 -ExitOnFailure

.EXAMPLE
    .\verify-postgresql.ps1 -JsonOutput

.EXAMPLE
    .\verify-postgresql.ps1 -Username "postgres" -Password "secret" -Database "testdb"

.NOTES
    Author: ActionRunner Team
    Version: 1.0.0
    Created for Issue #92: PostgreSQL verification tests
#>

[CmdletBinding()]
param(
    [switch]$ExitOnFailure,
    [switch]$JsonOutput,
    [string]$MinimumVersion = "12.0",
    [string]$Host = "localhost",
    [int]$Port = 5432,
    [string]$Database = "postgres",
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
    Write-Host "`n=== PostgreSQL Database Verification ===" -ForegroundColor Cyan
    Write-Host "Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" -ForegroundColor Gray
}

# Check 1: psql client installed
Test-Requirement `
    -Name "PostgreSQL Client (psql)" `
    -Expected "Version $MinimumVersion or higher" `
    -FailureMessage "psql not found or version below $MinimumVersion" `
    -Check {
        $psqlVersion = psql --version 2>&1
        if ($LASTEXITCODE -eq 0 -and $psqlVersion) {
            if ($psqlVersion -match 'psql \(PostgreSQL\) ([\d.]+)') {
                $version = $matches[1]
                $installedVersion = [version]($version -split '-')[0]
                $minVersion = [version]$MinimumVersion
                @{ Passed = ($installedVersion -ge $minVersion); Value = "psql (PostgreSQL) $version" }
            }
            else {
                @{ Passed = $true; Value = $psqlVersion.ToString().Trim() }
            }
        }
        else {
            @{ Passed = $false; Value = "Not installed" }
        }
    }

# Check 2: pg_isready utility
Test-Requirement `
    -Name "pg_isready Utility" `
    -Expected "pg_isready command available" `
    -FailureMessage "pg_isready utility not found" `
    -Check {
        $pgIsReady = Get-Command pg_isready -ErrorAction SilentlyContinue
        if ($pgIsReady) {
            @{ Passed = $true; Value = "pg_isready available" }
        }
        else {
            @{ Passed = $false; Value = "Not available" }
        }
    }

# Check 3: PostgreSQL server availability (Warning only)
Test-Requirement `
    -Name "PostgreSQL Server Status" `
    -Expected "PostgreSQL server accepting connections on $Host`:$Port" `
    -FailureMessage "PostgreSQL server not accepting connections (may not be running locally)" `
    -Severity "Warning" `
    -Check {
        $serverCheck = pg_isready -h $Host -p $Port 2>&1
        if ($LASTEXITCODE -eq 0) {
            @{ Passed = $true; Value = "Server accepting connections at $Host`:$Port" }
        }
        else {
            @{ Passed = $false; Value = "Server not responding" }
        }
    }

# Check 4: Environment variables (Warning only)
Test-Requirement `
    -Name "PostgreSQL Environment Variables" `
    -Expected "PGHOST, PGPORT, PGUSER, or PGDATABASE environment variables set" `
    -FailureMessage "PostgreSQL environment variables not configured (optional)" `
    -Severity "Warning" `
    -Check {
        if ($env:PGHOST -or $env:PGPORT -or $env:PGUSER -or $env:PGDATABASE) {
            $vars = @()
            if ($env:PGHOST) { $vars += "PGHOST" }
            if ($env:PGPORT) { $vars += "PGPORT" }
            if ($env:PGUSER) { $vars += "PGUSER" }
            if ($env:PGDATABASE) { $vars += "PGDATABASE" }
            @{ Passed = $true; Value = "Configured: $($vars -join ', ')" }
        }
        else {
            @{ Passed = $false; Value = "Not configured" }
        }
    }

# Check 5: Docker PostgreSQL availability (Warning only)
Test-Requirement `
    -Name "Docker PostgreSQL Container" `
    -Expected "PostgreSQL container running in Docker" `
    -FailureMessage "No PostgreSQL Docker container found (optional)" `
    -Severity "Warning" `
    -Check {
        $dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
        if ($dockerCmd) {
            $pgContainers = docker ps --filter "ancestor=postgres" --format "{{.Names}}" 2>&1
            if ($LASTEXITCODE -eq 0 -and $pgContainers) {
                $containerNames = ($pgContainers | Out-String).Trim()
                if ($containerNames) {
                    @{ Passed = $true; Value = "Found containers: $containerNames" }
                }
                else {
                    @{ Passed = $false; Value = "No PostgreSQL containers running" }
                }
            }
            else {
                @{ Passed = $false; Value = "No PostgreSQL containers running" }
            }
        }
        else {
            @{ Passed = $false; Value = "Docker not available" }
        }
    }

# Check 6: Connection test (if credentials provided and not skipped)
if ($Username -and $Password -and -not $SkipConnectionTest) {
    # Set password environment variable for psql
    $env:PGPASSWORD = $Password

    try {
        Test-Requirement `
            -Name "PostgreSQL Connection Test" `
            -Expected "Successfully connect to database" `
            -FailureMessage "Failed to connect to PostgreSQL database" `
            -Check {
                $query = "SELECT version();"
                $result = psql -h $Host -p $Port -U $Username -d $Database -t -c $query 2>&1
                if ($LASTEXITCODE -eq 0 -and $result) {
                    $versionInfo = ($result | Out-String).Trim()
                    if ($versionInfo -match 'PostgreSQL ([\d.]+)') {
                        @{ Passed = $true; Value = "Connected - PostgreSQL $($matches[1])" }
                    }
                    else {
                        @{ Passed = $true; Value = "Connected successfully" }
                    }
                }
                else {
                    @{ Passed = $false; Value = "Connection failed: $result" }
                }
            }
    }
    finally {
        # Clear password from environment
        Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    }
}
elseif ($Username -and -not $Password -and -not $SkipConnectionTest) {
    Test-Requirement `
        -Name "PostgreSQL Connection Test" `
        -Expected "Successfully connect to database" `
        -FailureMessage "Password not provided for connection test" `
        -Severity "Warning" `
        -Check {
            @{ Passed = $false; Value = "Skipped - no password provided" }
        }
}

# Check 7: Basic SQL operations (if credentials provided)
if ($Username -and $Password -and -not $SkipConnectionTest) {
    $env:PGPASSWORD = $Password

    try {
        Test-Requirement `
            -Name "PostgreSQL Basic SQL Operations" `
            -Expected "Execute basic SELECT, CREATE, INSERT, DROP" `
            -FailureMessage "Failed to execute basic SQL operations" `
            -Check {
                $testTable = "test_table_$(Get-Random)"

                # Create table
                $createQuery = "CREATE TEMP TABLE $testTable (id SERIAL PRIMARY KEY, name VARCHAR(100));"
                $createResult = psql -h $Host -p $Port -U $Username -d $Database -t -c $createQuery 2>&1

                if ($LASTEXITCODE -ne 0) {
                    @{ Passed = $false; Value = "CREATE TABLE failed: $createResult" }
                }
                else {
                    # Insert data
                    $insertQuery = "INSERT INTO $testTable (name) VALUES ('test') RETURNING id;"
                    $insertResult = psql -h $Host -p $Port -U $Username -d $Database -t -c $insertQuery 2>&1

                    if ($LASTEXITCODE -ne 0) {
                        @{ Passed = $false; Value = "INSERT failed: $insertResult" }
                    }
                    else {
                        # Select data
                        $selectQuery = "SELECT COUNT(*) FROM $testTable;"
                        $selectResult = psql -h $Host -p $Port -U $Username -d $Database -t -c $selectQuery 2>&1

                        if ($LASTEXITCODE -eq 0 -and $selectResult -match '1') {
                            @{ Passed = $true; Value = "CREATE, INSERT, SELECT operations successful" }
                        }
                        else {
                            @{ Passed = $false; Value = "SELECT failed: $selectResult" }
                        }
                    }
                }
            }
    }
    finally {
        Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    }
}

# Check 8: PostgreSQL extensions support (if credentials provided)
if ($Username -and $Password -and -not $SkipConnectionTest) {
    $env:PGPASSWORD = $Password

    try {
        Test-Requirement `
            -Name "PostgreSQL Extensions Support" `
            -Expected "Ability to query available extensions" `
            -FailureMessage "Failed to query PostgreSQL extensions" `
            -Severity "Warning" `
            -Check {
                $query = "SELECT COUNT(*) FROM pg_available_extensions;"
                $result = psql -h $Host -p $Port -U $Username -d $Database -t -c $query 2>&1
                if ($LASTEXITCODE -eq 0 -and $result -match '\d+') {
                    $count = ($result | Out-String).Trim()
                    @{ Passed = $true; Value = "$count extensions available" }
                }
                else {
                    @{ Passed = $false; Value = "Query failed: $result" }
                }
            }
    }
    finally {
        Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
    }
}

# Check 9: Common PostgreSQL tools
Test-Requirement `
    -Name "PostgreSQL Dump Utility (pg_dump)" `
    -Expected "pg_dump command available" `
    -FailureMessage "pg_dump utility not found" `
    -Severity "Warning" `
    -Check {
        $pgDump = Get-Command pg_dump -ErrorAction SilentlyContinue
        if ($pgDump) {
            $version = pg_dump --version 2>&1
            if ($version -match 'pg_dump \(PostgreSQL\) ([\d.]+)') {
                @{ Passed = $true; Value = "pg_dump $($matches[1])" }
            }
            else {
                @{ Passed = $true; Value = "pg_dump available" }
            }
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
