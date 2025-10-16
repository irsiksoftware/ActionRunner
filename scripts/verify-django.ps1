#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies Python Django web framework installation and functionality.

.DESCRIPTION
    This script verifies that Django is properly installed and functional by checking:
    - Django module availability
    - Django version meets minimum requirements
    - Django project creation capability
    - Django admin command functionality
    - Django ORM and models
    - Django migrations system
    - Django URL routing
    - Django views and templates
    - Django settings configuration

.PARAMETER MinimumVersion
    Minimum Django version required. Default is "3.2".

.PARAMETER ExitOnFailure
    Exit with code 1 if any check fails. Otherwise continues and reports all results.

.PARAMETER JsonOutput
    Output results in JSON format for integration with monitoring systems.

.EXAMPLE
    .\verify-django.ps1
    Runs all Django verification checks with default minimum version 3.2

.EXAMPLE
    .\verify-django.ps1 -MinimumVersion "4.0" -ExitOnFailure
    Runs checks requiring Django 4.0 or higher and exits on first failure

.EXAMPLE
    .\verify-django.ps1 -JsonOutput
    Outputs results in JSON format
#>

[CmdletBinding()]
param(
    [string]$MinimumVersion = "3.2",
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
    Write-Host "`n=== Python Django Verification ===" -ForegroundColor Cyan
    Write-Host "Checking Django installation and functionality...`n" -ForegroundColor Cyan
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

# Check 2: Django module import
Test-Requirement -Name "Django Module Available" -Expected "Django module can be imported" -FailureMessage "Django is not installed. Install with: pip install django" -Check {
    $importTest = python -c "import django; print('ok')" 2>&1
    if ($importTest -eq 'ok') {
        return @{ Success = $true; Value = "Django module imported successfully" }
    }
    return @{ Success = $false; Value = "Cannot import Django: $importTest" }
}

# Check 3: Django version
Test-Requirement -Name "Django Version" -Expected "Django >= $MinimumVersion" -FailureMessage "Django version is below minimum required version $MinimumVersion" -Check {
    $versionOutput = python -c "import django; print(django.get_version())" 2>&1
    if ($versionOutput -match '^([\d.]+)') {
        $version = $matches[1]
        $current = [version]($version -replace '^(\d+\.\d+).*', '$1')
        $minimum = [version]$MinimumVersion

        if ($current -ge $minimum) {
            return @{ Success = $true; Value = "Django $version" }
        }
        return @{ Success = $false; Value = "Django $version (minimum: $MinimumVersion)" }
    }
    return @{ Success = $false; Value = "Unable to determine Django version: $versionOutput" }
}

# Check 4: django-admin command
Test-Requirement -Name "django-admin Command Available" -Expected "django-admin executable found" -FailureMessage "django-admin command not found in PATH" -Check {
    $djangoAdminCmd = Get-Command django-admin -ErrorAction SilentlyContinue
    if (-not $djangoAdminCmd) {
        # Try python -m django
        $moduleTest = python -m django --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            return @{ Success = $true; Value = "django-admin via python -m django" }
        }
        return @{ Success = $false; Value = "django-admin not found" }
    }
    $version = django-admin --version 2>&1
    return @{ Success = $true; Value = "django-admin $version" }
}

# Check 5: Django project creation
Test-Requirement -Name "Django Project Creation" -Expected "Can create Django project" -FailureMessage "Cannot create Django project" -Check {
    $testDir = Join-Path $env:TEMP "django_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        $projectName = "testproject"
        $createOutput = python -m django startproject $projectName $testDir 2>&1

        $manageFile = Join-Path $testDir "manage.py"
        if (Test-Path $manageFile) {
            return @{ Success = $true; Value = "Project created successfully" }
        }
        return @{ Success = $false; Value = "Project creation failed: $createOutput" }
    }
    finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 6: Django settings module
Test-Requirement -Name "Django Settings Configuration" -Expected "Settings module works" -FailureMessage "Settings configuration failed" -Check {
    $testDir = Join-Path $env:TEMP "django_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        $projectName = "testproject"
        python -m django startproject $projectName $testDir 2>&1 | Out-Null

        $settingsFile = Join-Path $testDir $projectName "settings.py"
        if (Test-Path $settingsFile) {
            $settingsContent = Get-Content $settingsFile -Raw
            if ($settingsContent -match 'INSTALLED_APPS' -and $settingsContent -match 'DATABASES') {
                return @{ Success = $true; Value = "Settings module created correctly" }
            }
        }
        return @{ Success = $false; Value = "Settings file incomplete" }
    }
    finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 7: Django models import
Test-Requirement -Name "Django Models Import" -Expected "Can import Django models" -FailureMessage "Cannot import Django models" -Check {
    $importTest = python -c "from django.db import models; print('ok')" 2>&1
    if ($importTest -eq 'ok') {
        return @{ Success = $true; Value = "Models module available" }
    }
    return @{ Success = $false; Value = "Models import failed: $importTest" }
}

# Check 8: Django URL routing
Test-Requirement -Name "Django URL Routing" -Expected "Can import URL routing components" -FailureMessage "URL routing not available" -Check {
    $importTest = python -c "from django.urls import path; print('ok')" 2>&1
    if ($importTest -eq 'ok') {
        return @{ Success = $true; Value = "URL routing available" }
    }
    return @{ Success = $false; Value = "URL routing import failed: $importTest" }
}

# Check 9: Django views
Test-Requirement -Name "Django Views Import" -Expected "Can import Django views" -FailureMessage "Views module not available" -Check {
    $importTest = python -c "from django.http import HttpResponse; from django.views import View; print('ok')" 2>&1
    if ($importTest -eq 'ok') {
        return @{ Success = $true; Value = "Views components available" }
    }
    return @{ Success = $false; Value = "Views import failed: $importTest" }
}

# Check 10: Django template system
Test-Requirement -Name "Django Template System" -Expected "Template engine available" -FailureMessage "Template system not available" -Check {
    $testDir = Join-Path $env:TEMP "django_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        $testFile = Join-Path $testDir "test_template.py"
        @"
from django.template import Template, Context
template = Template('Hello {{ name }}!')
context = Context({'name': 'Django'})
result = template.render(context)
if result == 'Hello Django!':
    print('ok')
"@ | Out-File -FilePath $testFile -Encoding utf8

        $templateTest = python $testFile 2>&1
        if ($templateTest -eq 'ok') {
            return @{ Success = $true; Value = "Template system working" }
        }
        return @{ Success = $false; Value = "Template test failed: $templateTest" }
    }
    finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 11: Django ORM functionality
Test-Requirement -Name "Django ORM Basic Operations" -Expected "ORM model definition works" -FailureMessage "ORM not functioning correctly" -Check {
    $testDir = Join-Path $env:TEMP "django_test_$(Get-Random)"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    try {
        $testFile = Join-Path $testDir "test_orm.py"
        @"
from django.db import models

class TestModel(models.Model):
    name = models.CharField(max_length=100)
    created = models.DateTimeField(auto_now_add=True)

    class Meta:
        app_label = 'test'

print('ok')
"@ | Out-File -FilePath $testFile -Encoding utf8

        $ormTest = python $testFile 2>&1
        if ($ormTest -match 'ok') {
            return @{ Success = $true; Value = "ORM model definition working" }
        }
        return @{ Success = $false; Value = "ORM test failed: $ormTest" }
    }
    finally {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check 12: Django admin import
Test-Requirement -Name "Django Admin Interface" -Expected "Admin module available" -FailureMessage "Admin interface not available" -Severity "Warning" -Check {
    $importTest = python -c "from django.contrib import admin; print('ok')" 2>&1
    if ($importTest -eq 'ok') {
        return @{ Success = $true; Value = "Admin interface available" }
    }
    return @{ Success = $false; Value = "Admin import failed: $importTest" }
}

# Check 13: Django migrations
Test-Requirement -Name "Django Migrations Import" -Expected "Migrations framework available" -FailureMessage "Migrations not available" -Check {
    $importTest = python -c "from django.db import migrations; print('ok')" 2>&1
    if ($importTest -eq 'ok') {
        return @{ Success = $true; Value = "Migrations framework available" }
    }
    return @{ Success = $false; Value = "Migrations import failed: $importTest" }
}

# Check 14: Django forms
Test-Requirement -Name "Django Forms Framework" -Expected "Forms module available" -FailureMessage "Forms not available" -Severity "Warning" -Check {
    $importTest = python -c "from django import forms; print('ok')" 2>&1
    if ($importTest -eq 'ok') {
        return @{ Success = $true; Value = "Forms framework available" }
    }
    return @{ Success = $false; Value = "Forms import failed: $importTest" }
}

# Output results
if ($JsonOutput) {
    $output = @{
        timestamp = Get-Date -Format "o"
        tool = "django"
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
        Write-Host "✅ All critical Django checks passed!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "❌ Some critical checks failed. Please review the issues above." -ForegroundColor Red
        exit 1
    }
}
