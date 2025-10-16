#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies Python Flask web framework installation and functionality.

.DESCRIPTION
    This script verifies that Flask is properly installed and functional by checking:
    - Flask module availability
    - Flask version meets minimum requirements
    - Flask application creation
    - Flask route handling
    - Flask request/response processing
    - Flask template rendering
    - Flask configuration management
    - Flask extensions availability

.PARAMETER MinimumVersion
    Minimum Flask version required. Default is "2.0".

.PARAMETER ExitOnFailure
    Exit with code 1 if any check fails. Otherwise continues and reports all results.

.PARAMETER JsonOutput
    Output results in JSON format for integration with monitoring systems.

.EXAMPLE
    .\verify-flask.ps1
    Runs all Flask verification checks with default minimum version 2.0

.EXAMPLE
    .\verify-flask.ps1 -MinimumVersion "2.3" -ExitOnFailure
    Runs checks requiring Flask 2.3 or higher and exits on first failure

.EXAMPLE
    .\verify-flask.ps1 -JsonOutput
    Outputs results in JSON format
#>

[CmdletBinding()]
param(
    [string]$MinimumVersion = "2.0",
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
    Write-Host "`n=== Python Flask Verification ===" -ForegroundColor Cyan
    Write-Host "Checking Flask installation and functionality...`n" -ForegroundColor Cyan
}

# Check 1: Python availability
Test-Requirement -Name "Python Command Available" -Expected "Python available in PATH" -FailureMessage "Python is not installed or not in PATH" -Check {
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCmd) {
        $version = python --version 2>&1 | Out-String
        return @{ Success = $true; Value = $version.Trim() }
    }
    return @{ Success = $false; Value = "Not found" }
}

# Check 2: Flask module import
Test-Requirement -Name "Flask Module Available" -Expected "Flask module can be imported" -FailureMessage "Flask is not installed. Install with: pip install flask" -Check {
    $importTest = python -c "import flask; print('ok')" 2>&1
    if ($importTest -eq 'ok') {
        return @{ Success = $true; Value = "Flask module imported successfully" }
    }
    return @{ Success = $false; Value = "Cannot import Flask: $importTest" }
}

# Check 3: Flask version
Test-Requirement -Name "Flask Version" -Expected "Flask >= $MinimumVersion" -FailureMessage "Flask version is below minimum required version $MinimumVersion" -Check {
    $versionOutput = python -c "import flask; print(flask.__version__)" 2>&1
    if ($versionOutput -match '^([\d.]+)') {
        $version = $matches[1]
        $current = [version]($version -replace '^(\d+\.\d+).*', '$1')
        $minimum = [version]$MinimumVersion

        if ($current -ge $minimum) {
            return @{ Success = $true; Value = "Flask $version" }
        }
        return @{ Success = $false; Value = "Flask $version (minimum: $MinimumVersion)" }
    }
    return @{ Success = $false; Value = "Unable to determine Flask version: $versionOutput" }
}

# Check 4: Flask application creation
Test-Requirement -Name "Flask Application Creation" -Expected "Can create Flask application instance" -FailureMessage "Cannot create Flask app" -Check {
    $testDir = Join-Path $env:TEMP "flask_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        $appFile = Join-Path $testDir "test_app.py"
        @"
from flask import Flask
app = Flask(__name__)
print('app_created')
"@ | Out-File -FilePath $appFile -Encoding utf8

        $createTest = python $appFile 2>&1
        if ($createTest -match 'app_created') {
            return @{ Success = $true; Value = "Flask app created successfully" }
        }
        return @{ Success = $false; Value = "App creation failed: $createTest" }
    }
    finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 5: Flask route handling
Test-Requirement -Name "Flask Route Decorator" -Expected "Route decorator works correctly" -FailureMessage "Route decorator not functioning" -Check {
    $testDir = Join-Path $env:TEMP "flask_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        $routeFile = Join-Path $testDir "test_routes.py"
        @"
from flask import Flask
app = Flask(__name__)

@app.route('/')
def index():
    return 'Hello'

@app.route('/test')
def test():
    return 'Test'

print('routes_ok')
"@ | Out-File -FilePath $routeFile -Encoding utf8

        $routeTest = python $routeFile 2>&1
        if ($routeTest -match 'routes_ok') {
            return @{ Success = $true; Value = "Route decorator functioning" }
        }
        return @{ Success = $false; Value = "Route test failed: $routeTest" }
    }
    finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 6: Flask request handling
Test-Requirement -Name "Flask Request Import" -Expected "Can import request object" -FailureMessage "Cannot import Flask request" -Check {
    $importTest = python -c "from flask import request; print('ok')" 2>&1
    if ($importTest -eq 'ok') {
        return @{ Success = $true; Value = "Request object available" }
    }
    return @{ Success = $false; Value = "Request import failed: $importTest" }
}

# Check 7: Flask JSON response (jsonify)
Test-Requirement -Name "Flask JSON Response (jsonify)" -Expected "jsonify function available" -FailureMessage "Cannot use jsonify for JSON responses" -Check {
    $testDir = Join-Path $env:TEMP "flask_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        $jsonFile = Join-Path $testDir "test_json.py"
        @"
from flask import Flask, jsonify
app = Flask(__name__)

@app.route('/api/test')
def api_test():
    return jsonify({'status': 'ok', 'data': 'test'})

print('jsonify_ok')
"@ | Out-File -FilePath $jsonFile -Encoding utf8

        $jsonTest = python $jsonFile 2>&1
        if ($jsonTest -match 'jsonify_ok') {
            return @{ Success = $true; Value = "jsonify available" }
        }
        return @{ Success = $false; Value = "jsonify test failed: $jsonTest" }
    }
    finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 8: Flask template rendering
Test-Requirement -Name "Flask Template Rendering" -Expected "render_template_string works" -FailureMessage "Template rendering not available" -Check {
    $testDir = Join-Path $env:TEMP "flask_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        $templateFile = Join-Path $testDir "test_template.py"
        @"
from flask import Flask, render_template_string
app = Flask(__name__)

@app.route('/')
def index():
    return render_template_string('<h1>{{ title }}</h1>', title='Test')

print('template_ok')
"@ | Out-File -FilePath $templateFile -Encoding utf8

        $templateTest = python $templateFile 2>&1
        if ($templateTest -match 'template_ok') {
            return @{ Success = $true; Value = "Template rendering available" }
        }
        return @{ Success = $false; Value = "Template test failed: $templateTest" }
    }
    finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 9: Flask configuration
Test-Requirement -Name "Flask Configuration" -Expected "app.config works" -FailureMessage "Configuration management not working" -Check {
    $testDir = Join-Path $env:TEMP "flask_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        $configFile = Join-Path $testDir "test_config.py"
        @"
from flask import Flask
app = Flask(__name__)
app.config['TESTING'] = True
app.config['DEBUG'] = False
if app.config.get('TESTING') == True:
    print('config_ok')
"@ | Out-File -FilePath $configFile -Encoding utf8

        $configTest = python $configFile 2>&1
        if ($configTest -match 'config_ok') {
            return @{ Success = $true; Value = "Configuration working" }
        }
        return @{ Success = $false; Value = "Config test failed: $configTest" }
    }
    finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 10: Flask test client
Test-Requirement -Name "Flask Test Client" -Expected "test_client() available" -FailureMessage "Test client not available" -Check {
    $testDir = Join-Path $env:TEMP "flask_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        $clientFile = Join-Path $testDir "test_client.py"
        @"
from flask import Flask
app = Flask(__name__)

@app.route('/')
def index():
    return 'Hello World'

with app.test_client() as client:
    response = client.get('/')
    if response.status_code == 200:
        print('test_client_ok')
"@ | Out-File -FilePath $clientFile -Encoding utf8

        $clientTest = python $clientFile 2>&1
        if ($clientTest -match 'test_client_ok') {
            return @{ Success = $true; Value = "Test client functional" }
        }
        return @{ Success = $false; Value = "Test client failed: $clientTest" }
    }
    finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 11: Flask Blueprint support
Test-Requirement -Name "Flask Blueprint Support" -Expected "Blueprint class available" -FailureMessage "Blueprint not available" -Severity "Warning" -Check {
    $importTest = python -c "from flask import Blueprint; print('ok')" 2>&1
    if ($importTest -eq 'ok') {
        return @{ Success = $true; Value = "Blueprint available" }
    }
    return @{ Success = $false; Value = "Blueprint import failed: $importTest" }
}

# Check 12: Flask request context
Test-Requirement -Name "Flask Request Context" -Expected "test_request_context works" -FailureMessage "Request context not working" -Check {
    $testDir = Join-Path $env:TEMP "flask_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        $contextFile = Join-Path $testDir "test_context.py"
        @"
from flask import Flask, request
app = Flask(__name__)

with app.test_request_context('/?name=test'):
    if request.args.get('name') == 'test':
        print('context_ok')
"@ | Out-File -FilePath $contextFile -Encoding utf8

        $contextTest = python $contextFile 2>&1
        if ($contextTest -match 'context_ok') {
            return @{ Success = $true; Value = "Request context working" }
        }
        return @{ Success = $false; Value = "Context test failed: $contextTest" }
    }
    finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Output results
if ($JsonOutput) {
    $output = @{
        timestamp = Get-Date -Format "o"
        tool = "flask"
        minimumVersion = $MinimumVersion
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
        Write-Host "✅ All critical Flask checks passed!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "❌ Some critical checks failed. Please review the issues above." -ForegroundColor Red
        exit 1
    }
}
