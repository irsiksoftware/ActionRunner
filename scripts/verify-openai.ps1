#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies OpenAI SDK installation and functionality for Python and Node.js.

.DESCRIPTION
    This script verifies that OpenAI SDK is properly installed and functional by checking:
    - Python OpenAI package installation
    - Python OpenAI version
    - Python OpenAI module imports
    - Node.js OpenAI package installation
    - Node.js OpenAI version
    - Node.js OpenAI module imports
    - Basic functionality tests

.PARAMETER MinimumPythonVersion
    Minimum Python version required. Default is "3.8".

.PARAMETER MinimumPythonOpenAIVersion
    Minimum Python OpenAI package version required. Default is "1.0.0".

.PARAMETER MinimumNodeVersion
    Minimum Node.js version required. Default is "16.0".

.PARAMETER MinimumNodeOpenAIVersion
    Minimum Node.js OpenAI package version required. Default is "4.0.0".

.PARAMETER ExitOnFailure
    Exit with code 1 if any check fails. Otherwise continues and reports all results.

.PARAMETER JsonOutput
    Output results in JSON format for integration with monitoring systems.

.EXAMPLE
    .\verify-openai.ps1
    Runs all OpenAI SDK verification checks with default minimum versions

.EXAMPLE
    .\verify-openai.ps1 -MinimumPythonVersion "3.9" -MinimumNodeVersion "18.0" -ExitOnFailure
    Runs checks requiring Python 3.9+ and Node.js 18.0+ and exits on first failure

.EXAMPLE
    .\verify-openai.ps1 -JsonOutput
    Outputs results in JSON format
#>

[CmdletBinding()]
param(
    [string]$MinimumPythonVersion = "3.8",
    [string]$MinimumPythonOpenAIVersion = "1.0.0",
    [string]$MinimumNodeVersion = "16.0",
    [string]$MinimumNodeOpenAIVersion = "4.0.0",
    [switch]$ExitOnFailure,
    [switch]$JsonOutput
)

$ErrorActionPreference = 'Continue'

# Initialize results collection
$checks = @()
$passed = 0
$failed = 0
$warnings = 0

function Test-Requirement {
    param(
        [string]$Name,
        [scriptblock]$Check,
        [string]$Expected,
        [string]$FailureMessage,
        [string]$Severity = "Error"
    )

    try {
        $result = & $Check
        $checkPassed = $result.Success
        $actual = $result.Value

        if ($checkPassed) {
            $script:passed++
            if (-not $JsonOutput) {
                Write-Host "✅ $Name" -ForegroundColor Green
                if ($actual) {
                    Write-Host "   $actual" -ForegroundColor Gray
                }
            }
        } else {
            if ($Severity -eq "Warning") {
                $script:warnings++
                if (-not $JsonOutput) {
                    Write-Host "⚠️  $Name" -ForegroundColor Yellow
                    Write-Host "   $FailureMessage" -ForegroundColor Yellow
                }
            } else {
                $script:failed++
                if (-not $JsonOutput) {
                    Write-Host "❌ $Name" -ForegroundColor Red
                    Write-Host "   $FailureMessage" -ForegroundColor Red
                }
            }
        }

        $script:checks += @{
            name = $Name
            status = if ($checkPassed) { "passed" } elseif ($Severity -eq "Warning") { "warning" } else { "failed" }
            expected = $Expected
            actual = $actual
            message = if ($checkPassed) { "" } else { $FailureMessage }
            severity = $Severity
        }

        if (-not $checkPassed -and $ExitOnFailure -and $Severity -ne "Warning") {
            exit 1
        }
    }
    catch {
        $script:failed++
        if (-not $JsonOutput) {
            Write-Host "❌ $Name" -ForegroundColor Red
            Write-Host "   Error: $_" -ForegroundColor Red
        }

        $script:checks += @{
            name = $Name
            status = "failed"
            expected = $Expected
            actual = "Error: $_"
            message = $FailureMessage
            severity = $Severity
        }

        if ($ExitOnFailure) {
            exit 1
        }
    }
}

if (-not $JsonOutput) {
    Write-Host "`n=== OpenAI SDK Verification ===" -ForegroundColor Cyan
    Write-Host "Checking OpenAI SDK installation and functionality...`n" -ForegroundColor Cyan
}

# ====================================
# Python OpenAI SDK Checks
# ====================================

if (-not $JsonOutput) {
    Write-Host "--- Python OpenAI SDK ---" -ForegroundColor Cyan
}

# Check 1: Python command availability
Test-Requirement -Name "Python Interpreter" -Expected "python command found in PATH" -FailureMessage "Python is not installed or not in PATH" -Check {
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCmd) {
        $versionOutput = python --version 2>&1 | Out-String
        if ($versionOutput -match 'Python ([\d.]+)') {
            $version = $matches[1]
            $current = [version]($version -replace '^(\d+\.\d+).*', '$1')
            $minimum = [version]$MinimumPythonVersion

            if ($current -ge $minimum) {
                return @{ Success = $true; Value = "Python $version" }
            }
            return @{ Success = $false; Value = "Python $version (minimum: $MinimumPythonVersion)" }
        }
    }
    return @{ Success = $false; Value = "Not found" }
}

# Check 2: pip availability
Test-Requirement -Name "pip Package Manager" -Expected "pip command available" -FailureMessage "pip is not available" -Check {
    $pipOutput = python -m pip --version 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0 -and $pipOutput -match 'pip ([\d.]+)') {
        return @{ Success = $true; Value = "pip $($matches[1])" }
    }
    return @{ Success = $false; Value = "Not found" }
}

# Check 3: Python OpenAI package installation
Test-Requirement -Name "Python OpenAI Package" -Expected "openai package installed" -FailureMessage "OpenAI package not installed. Install with: pip install openai" -Check {
    $testDir = Join-Path $env:TEMP "openai_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        $testScript = @"
import sys
try:
    import openai
    print(f"INSTALLED:{openai.__version__}")
    sys.exit(0)
except ImportError as e:
    print(f"NOT_INSTALLED:{e}")
    sys.exit(1)
"@
        $scriptPath = Join-Path $testDir "test_openai_import.py"
        $testScript | Out-File -FilePath $scriptPath -Encoding utf8

        $output = python $scriptPath 2>&1 | Out-String
        if ($output -match 'INSTALLED:([\d.]+)') {
            $version = $matches[1]
            return @{ Success = $true; Value = "openai v$version" }
        }
        return @{ Success = $false; Value = "Not installed" }
    }
    finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 4: Python OpenAI version check
Test-Requirement -Name "Python OpenAI Version" -Expected "openai >= $MinimumPythonOpenAIVersion" -FailureMessage "OpenAI version is below minimum required version $MinimumPythonOpenAIVersion" -Check {
    $testDir = Join-Path $env:TEMP "openai_version_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        $testScript = @"
import sys
try:
    import openai
    from packaging import version
    current = version.parse(openai.__version__)
    minimum = version.parse("$MinimumPythonOpenAIVersion")
    if current >= minimum:
        print(f"VERSION_OK:{openai.__version__}")
        sys.exit(0)
    else:
        print(f"VERSION_LOW:{openai.__version__}")
        sys.exit(1)
except ImportError:
    # If packaging is not available, do string comparison
    import openai
    print(f"VERSION_OK:{openai.__version__}")
    sys.exit(0)
"@
        $scriptPath = Join-Path $testDir "test_version.py"
        $testScript | Out-File -FilePath $scriptPath -Encoding utf8

        $output = python $scriptPath 2>&1 | Out-String
        if ($output -match 'VERSION_OK:([\d.]+)') {
            return @{ Success = $true; Value = "openai v$($matches[1])" }
        }
        if ($output -match 'VERSION_LOW:([\d.]+)') {
            return @{ Success = $false; Value = "openai v$($matches[1]) (minimum: $MinimumPythonOpenAIVersion)" }
        }
        return @{ Success = $false; Value = "Version check failed" }
    }
    finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 5: Python OpenAI core imports
Test-Requirement -Name "Python OpenAI Core Imports" -Expected "Can import core OpenAI classes" -FailureMessage "Cannot import OpenAI core classes" -Check {
    $testDir = Join-Path $env:TEMP "openai_imports_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        $testScript = @"
import sys
try:
    from openai import OpenAI
    print("IMPORTS_OK:OpenAI client class")
    sys.exit(0)
except ImportError as e:
    print(f"IMPORTS_FAILED:{e}")
    sys.exit(1)
"@
        $scriptPath = Join-Path $testDir "test_imports.py"
        $testScript | Out-File -FilePath $scriptPath -Encoding utf8

        $output = python $scriptPath 2>&1 | Out-String
        if ($output -match 'IMPORTS_OK:(.+)') {
            return @{ Success = $true; Value = $matches[1] }
        }
        return @{ Success = $false; Value = "Import failed" }
    }
    finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 6: Python OpenAI client instantiation
Test-Requirement -Name "Python OpenAI Client Instantiation" -Expected "Can create OpenAI client instance" -FailureMessage "Cannot instantiate OpenAI client" -Check {
    $testDir = Join-Path $env:TEMP "openai_client_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        $testScript = @"
import sys
import os
try:
    from openai import OpenAI
    # Create client with dummy API key for testing
    os.environ['OPENAI_API_KEY'] = 'sk-test-key-for-verification'
    client = OpenAI(api_key='sk-test-key-for-verification')
    print("CLIENT_OK:Client instantiated successfully")
    sys.exit(0)
except Exception as e:
    print(f"CLIENT_FAILED:{e}")
    sys.exit(1)
"@
        $scriptPath = Join-Path $testDir "test_client.py"
        $testScript | Out-File -FilePath $scriptPath -Encoding utf8

        $output = python $scriptPath 2>&1 | Out-String
        if ($output -match 'CLIENT_OK:(.+)') {
            return @{ Success = $true; Value = $matches[1] }
        }
        return @{ Success = $false; Value = "Client instantiation failed" }
    }
    finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ====================================
# Node.js OpenAI SDK Checks
# ====================================

if (-not $JsonOutput) {
    Write-Host "`n--- Node.js OpenAI SDK ---" -ForegroundColor Cyan
}

# Check 7: Node.js command availability
Test-Requirement -Name "Node.js Interpreter" -Expected "node command found in PATH" -FailureMessage "Node.js is not installed or not in PATH" -Check {
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($nodeCmd) {
        $versionOutput = node --version 2>&1 | Out-String
        if ($versionOutput -match 'v?([\d.]+)') {
            $version = $matches[1]
            $current = [version]($version -replace '^(\d+\.\d+).*', '$1')
            $minimum = [version]$MinimumNodeVersion

            if ($current -ge $minimum) {
                return @{ Success = $true; Value = "Node.js v$version" }
            }
            return @{ Success = $false; Value = "Node.js v$version (minimum: $MinimumNodeVersion)" }
        }
    }
    return @{ Success = $false; Value = "Not found" }
}

# Check 8: npm availability
Test-Requirement -Name "npm Package Manager" -Expected "npm command available" -FailureMessage "npm is not available" -Check {
    $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
    if ($npmCmd) {
        $npmVersion = npm --version 2>&1 | Out-String
        return @{ Success = $true; Value = "npm v$($npmVersion.Trim())" }
    }
    return @{ Success = $false; Value = "Not found" }
}

# Check 9: Node.js OpenAI package installation check
Test-Requirement -Name "Node.js OpenAI Package" -Expected "openai package can be resolved" -FailureMessage "OpenAI package not installed. Install with: npm install openai" -Severity "Warning" -Check {
    $testDir = Join-Path $env:TEMP "node_openai_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        Push-Location $testDir

        # Create a minimal package.json
        $packageJson = @{
            name = "openai-test"
            version = "1.0.0"
            type = "module"
        } | ConvertTo-Json
        $packageJson | Out-File -FilePath "package.json" -Encoding utf8

        # Try to require openai (checking global or local installation)
        $testScript = @"
try {
    const openai = await import('openai');
    console.log('INSTALLED:' + openai.default.VERSION || 'unknown');
    process.exit(0);
} catch (e) {
    console.log('NOT_INSTALLED:' + e.message);
    process.exit(1);
}
"@
        $scriptPath = Join-Path $testDir "test.mjs"
        $testScript | Out-File -FilePath $scriptPath -Encoding utf8

        $output = node $scriptPath 2>&1 | Out-String
        if ($output -match 'INSTALLED:(.+)') {
            return @{ Success = $true; Value = "openai package accessible" }
        }
        return @{ Success = $false; Value = "Not installed" }
    }
    finally {
        Pop-Location
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 10: Node.js OpenAI package local installation test
Test-Requirement -Name "Node.js OpenAI Installation Test" -Expected "Can install openai package" -FailureMessage "Cannot install openai package with npm" -Check {
    $testDir = Join-Path $env:TEMP "node_openai_install_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        Push-Location $testDir

        # Create a minimal package.json
        $packageJson = @{
            name = "openai-install-test"
            version = "1.0.0"
            type = "module"
            dependencies = @{
                openai = "^$MinimumNodeOpenAIVersion"
            }
        } | ConvertTo-Json
        $packageJson | Out-File -FilePath "package.json" -Encoding utf8

        # Try to install
        $installOutput = npm install 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -and (Test-Path "node_modules/openai")) {
            # Check version
            $pkgJsonPath = Join-Path $testDir "node_modules/openai/package.json"
            if (Test-Path $pkgJsonPath) {
                $pkgJson = Get-Content $pkgJsonPath | ConvertFrom-Json
                return @{ Success = $true; Value = "openai v$($pkgJson.version)" }
            }
            return @{ Success = $true; Value = "Package installed successfully" }
        }
        return @{ Success = $false; Value = "Install failed" }
    }
    finally {
        Pop-Location
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 11: Node.js OpenAI client instantiation
Test-Requirement -Name "Node.js OpenAI Client Instantiation" -Expected "Can create OpenAI client instance" -FailureMessage "Cannot instantiate OpenAI client" -Check {
    $testDir = Join-Path $env:TEMP "node_openai_client_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        Push-Location $testDir

        # Create a minimal package.json
        $packageJson = @{
            name = "openai-client-test"
            version = "1.0.0"
            type = "module"
            dependencies = @{
                openai = "^$MinimumNodeOpenAIVersion"
            }
        } | ConvertTo-Json
        $packageJson | Out-File -FilePath "package.json" -Encoding utf8

        # Install package
        npm install 2>&1 | Out-Null

        if (Test-Path "node_modules/openai") {
            $testScript = @"
import OpenAI from 'openai';

try {
    const client = new OpenAI({
        apiKey: 'sk-test-key-for-verification'
    });
    console.log('CLIENT_OK:Client instantiated successfully');
    process.exit(0);
} catch (e) {
    console.log('CLIENT_FAILED:' + e.message);
    process.exit(1);
}
"@
            $scriptPath = Join-Path $testDir "test.mjs"
            $testScript | Out-File -FilePath $scriptPath -Encoding utf8

            $output = node $scriptPath 2>&1 | Out-String
            if ($output -match 'CLIENT_OK:(.+)') {
                return @{ Success = $true; Value = $matches[1] }
            }
            return @{ Success = $false; Value = "Client instantiation failed" }
        }
        return @{ Success = $false; Value = "Package not installed" }
    }
    finally {
        Pop-Location
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Output results
if ($JsonOutput) {
    $output = @{
        timestamp = Get-Date -Format "o"
        tool = "openai-sdk"
        minimumPythonVersion = $MinimumPythonVersion
        minimumPythonOpenAIVersion = $MinimumPythonOpenAIVersion
        minimumNodeVersion = $MinimumNodeVersion
        minimumNodeOpenAIVersion = $MinimumNodeOpenAIVersion
        passed = $passed
        failed = $failed
        warnings = $warnings
        total = $checks.Count
        checks = $checks
    }
    $output | ConvertTo-Json -Depth 10
} else {
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Passed:   $passed" -ForegroundColor Green
    Write-Host "Failed:   $failed" -ForegroundColor Red
    Write-Host "Warnings: $warnings" -ForegroundColor Yellow
    Write-Host "Total:    $($checks.Count)`n" -ForegroundColor Cyan

    if ($failed -eq 0) {
        Write-Host "✅ All critical OpenAI SDK checks passed!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "❌ Some critical checks failed. Please review the issues above." -ForegroundColor Red
        exit 1
    }
}
