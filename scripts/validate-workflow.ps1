<#
.SYNOPSIS
    Validates GitHub Actions workflow YAML files against expectations.

.DESCRIPTION
    This utility validates workflow YAML files for:
    - Valid YAML syntax
    - Required fields (name, on, jobs)
    - Job structure and naming conventions
    - Step structure with required fields
    - Self-hosted runner labels
    - Common best practices

.PARAMETER WorkflowPath
    Path to a specific workflow file or directory containing workflows.
    Defaults to .github/workflows directory.

.PARAMETER Strict
    Enable strict validation mode with additional checks.

.PARAMETER OutputFormat
    Output format: Console, JSON, or XML. Default: Console

.EXAMPLE
    .\validate-workflow.ps1
    Validates all workflows in .github/workflows

.EXAMPLE
    .\validate-workflow.ps1 -WorkflowPath .github/workflows/ci.yml -Strict
    Validates a specific workflow file with strict mode
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$WorkflowPath = ".github/workflows",

    [Parameter(Mandatory = $false)]
    [switch]$Strict,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Console", "JSON", "XML")]
    [string]$OutputFormat = "Console"
)

$ErrorActionPreference = "Stop"

# Validation result class
class ValidationResult {
    [string]$File
    [string]$Severity
    [string]$Message
    [int]$Line
    [string]$Rule

    ValidationResult([string]$file, [string]$severity, [string]$message, [int]$line, [string]$rule) {
        $this.File = $file
        $this.Severity = $severity
        $this.Message = $message
        $this.Line = $line
        $this.Rule = $rule
    }
}

# Validation rules
$script:validationResults = @()

function Add-ValidationResult {
    param(
        [string]$File,
        [string]$Severity,
        [string]$Message,
        [int]$Line = 0,
        [string]$Rule
    )

    $script:validationResults += [ValidationResult]::new($File, $Severity, $Message, $Line, $Rule)
}

function Test-WorkflowStructure {
    param(
        [string]$FilePath,
        [string]$Content
    )

    Write-Verbose "Validating workflow structure: $FilePath"

    # Check for required top-level fields
    $requiredFields = @('name', 'on', 'jobs')

    foreach ($field in $requiredFields) {
        $pattern = "(?m)^$field\s*:"
        if ($Content -notmatch $pattern) {
            Add-ValidationResult -File $FilePath -Severity "Error" -Message "Missing required field: $field" -Rule "REQUIRED_FIELD"
        }
    }

    # Check for workflow name
    if ($Content -match '(?m)^name\s*:\s*(.+)$') {
        $workflowName = $Matches[1].Trim()
        if ([string]::IsNullOrWhiteSpace($workflowName)) {
            Add-ValidationResult -File $FilePath -Severity "Error" -Message "Workflow name cannot be empty" -Rule "WORKFLOW_NAME"
        }
    }

    # Validate trigger configuration
    if ($Content -notmatch '(?m)^on\s*:') {
        Add-ValidationResult -File $FilePath -Severity "Error" -Message "Missing workflow trigger (on)" -Rule "TRIGGER"
    }

    # Validate jobs section
    if ($Content -notmatch '(?m)^jobs\s*:') {
        Add-ValidationResult -File $FilePath -Severity "Error" -Message "Missing jobs section" -Rule "JOBS"
    }
}

function Test-JobConfiguration {
    param(
        [string]$FilePath,
        [string]$Content
    )

    Write-Verbose "Validating job configuration: $FilePath"

    # Extract jobs section
    $lines = $Content -split "`n"
    $inJobs = $false
    $currentJob = $null
    $lineNumber = 0

    foreach ($line in $lines) {
        $lineNumber++

        if ($line -match '^\s*jobs\s*:') {
            $inJobs = $true
            continue
        }

        if ($inJobs) {
            # Check for job definition
            if ($line -match '^\s{2}([a-zA-Z0-9_-]+)\s*:') {
                $currentJob = $Matches[1]

                # Validate job name format
                if ($currentJob -notmatch '^[a-zA-Z0-9_-]+$') {
                    Add-ValidationResult -File $FilePath -Severity "Warning" -Message "Job name '$currentJob' should use alphanumeric, hyphen, or underscore only" -Line $lineNumber -Rule "JOB_NAME_FORMAT"
                }
            }

            # Check for runs-on
            if ($line -match '^\s{4}runs-on\s*:') {
                # Self-hosted runner check
                if ($line -match '\[.*self-hosted.*\]' -or $line -match 'self-hosted') {
                    Write-Verbose "Job '$currentJob' uses self-hosted runner"
                }
            }

            # Check for steps
            if ($line -match '^\s{4}steps\s*:') {
                Write-Verbose "Job '$currentJob' has steps defined"
            }

            # Exit jobs section when we reach root-level key
            if ($line -match '^[a-zA-Z]' -and $line -notmatch '^\s*jobs\s*:') {
                $inJobs = $false
            }
        }
    }
}

function Test-StepConfiguration {
    param(
        [string]$FilePath,
        [string]$Content
    )

    Write-Verbose "Validating step configuration: $FilePath"

    $lines = $Content -split "`n"
    $inSteps = $false
    $lineNumber = 0
    $stepCount = 0

    foreach ($line in $lines) {
        $lineNumber++

        if ($line -match '^\s{4}steps\s*:') {
            $inSteps = $true
            continue
        }

        if ($inSteps) {
            # Check for step definition
            if ($line -match '^\s{6}-\s*name\s*:') {
                $stepCount++
            }

            # Check for action usage
            if ($line -match '^\s{8}uses\s*:\s*(.+)$') {
                $action = $Matches[1].Trim()

                # Validate action format
                if ($action -notmatch '^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+@.+$') {
                    if ($Strict) {
                        Add-ValidationResult -File $FilePath -Severity "Warning" -Message "Action '$action' should specify version (e.g., @v4)" -Line $lineNumber -Rule "ACTION_VERSION"
                    }
                }
            }

            # Exit steps when we hit a new job or root key
            if ($line -match '^\s{2}[a-zA-Z]' -or $line -match '^[a-zA-Z]') {
                $inSteps = $false

                if ($stepCount -eq 0) {
                    Add-ValidationResult -File $FilePath -Severity "Warning" -Message "Job has steps section but no steps defined" -Rule "EMPTY_STEPS"
                }
            }
        }
    }
}

function Test-BestPractices {
    param(
        [string]$FilePath,
        [string]$Content
    )

    Write-Verbose "Validating best practices: $FilePath"

    # Check for checkout action
    if ($Content -notmatch 'uses\s*:\s*actions/checkout') {
        if ($Strict) {
            Add-ValidationResult -File $FilePath -Severity "Info" -Message "Workflow doesn't use actions/checkout - may be intentional" -Rule "CHECKOUT_ACTION"
        }
    }

    # Check for artifact uploads with if: always()
    if ($Content -match 'uses\s*:\s*actions/upload-artifact') {
        if ($Content -notmatch 'if\s*:\s*always\(\)') {
            if ($Strict) {
                Add-ValidationResult -File $FilePath -Severity "Info" -Message "Consider using 'if: always()' with upload-artifact to ensure artifacts are uploaded even on failure" -Rule "ARTIFACT_UPLOAD"
            }
        }
    }

    # Check for timeout settings
    if ($Content -notmatch 'timeout-minutes\s*:') {
        if ($Strict) {
            Add-ValidationResult -File $FilePath -Severity "Info" -Message "Consider adding timeout-minutes to prevent jobs from running indefinitely" -Rule "JOB_TIMEOUT"
        }
    }
}

function Test-YamlSyntax {
    param(
        [string]$FilePath,
        [string]$Content
    )

    Write-Verbose "Validating YAML syntax: $FilePath"

    try {
        # Basic syntax checks
        $lines = $Content -split "`n"
        $lineNumber = 0

        foreach ($line in $lines) {
            $lineNumber++

            # Check for tabs (YAML should use spaces)
            if ($line -match '\t') {
                Add-ValidationResult -File $FilePath -Severity "Error" -Message "YAML files should use spaces, not tabs" -Line $lineNumber -Rule "YAML_SYNTAX"
            }

            # Check for trailing whitespace
            if ($line -match '\s+$') {
                if ($Strict) {
                    Add-ValidationResult -File $FilePath -Severity "Warning" -Message "Line has trailing whitespace" -Line $lineNumber -Rule "TRAILING_WHITESPACE"
                }
            }
        }
    }
    catch {
        $errMsg = $_.Exception.Message
        Add-ValidationResult -File $FilePath -Severity "Error" -Message "YAML syntax error: $errMsg" -Rule "YAML_SYNTAX"
    }
}

# Main validation function
function Invoke-WorkflowValidation {
    param([string]$Path)

    $files = @()

    if (Test-Path $Path -PathType Container) {
        # Validate all workflow files in directory
        $files = Get-ChildItem -Path $Path -Filter "*.yml" -File
        $files += Get-ChildItem -Path $Path -Filter "*.yaml" -File
    }
    elseif (Test-Path $Path -PathType Leaf) {
        # Validate single file
        $files = @(Get-Item $Path)
    }
    else {
        Write-Error "Path not found: $Path"
        return
    }

    if ($files.Count -eq 0) {
        Write-Warning "No workflow files found in: $Path"
        return
    }

    Write-Host "Validating $($files.Count) workflow file(s)..." -ForegroundColor Cyan

    foreach ($file in $files) {
        Write-Verbose "Processing: $($file.Name)"

        $content = Get-Content -Path $file.FullName -Raw

        # Run validation checks
        Test-YamlSyntax -FilePath $file.Name -Content $content
        Test-WorkflowStructure -FilePath $file.Name -Content $content
        Test-JobConfiguration -FilePath $file.Name -Content $content
        Test-StepConfiguration -FilePath $file.Name -Content $content
        Test-BestPractices -FilePath $file.Name -Content $content
    }
}

# Main execution
try {
    Write-Host ""
    Write-Host "=== GitHub Actions Workflow Validator ===" -ForegroundColor Cyan
    Write-Host "Path: $WorkflowPath" -ForegroundColor Gray
    Write-Host "Strict Mode: $Strict" -ForegroundColor Gray
    Write-Host ""

    Invoke-WorkflowValidation -Path $WorkflowPath

    # Output results
    if ($validationResults.Count -eq 0) {
        Write-Host "All workflows validated successfully! No issues found." -ForegroundColor Green
        exit 0
    }

    # Group results by severity
    $errors = $validationResults | Where-Object { $_.Severity -eq "Error" }
    $warnings = $validationResults | Where-Object { $_.Severity -eq "Warning" }
    $info = $validationResults | Where-Object { $_.Severity -eq "Info" }

    if ($OutputFormat -eq "JSON") {
        $output = @{
            TotalIssues = $validationResults.Count
            Errors      = $errors.Count
            Warnings    = $warnings.Count
            Info        = $info.Count
            Results     = $validationResults
        }
        $output | ConvertTo-Json -Depth 10
    }
    elseif ($OutputFormat -eq "XML") {
        $validationResults | Export-Clixml -Path "workflow-validation-results.xml"
        Write-Host "Results exported to: workflow-validation-results.xml" -ForegroundColor Cyan
    }
    else {
        # Console output
        Write-Host ""
        Write-Host "=== Validation Results ===" -ForegroundColor Cyan

        if ($errors.Count -gt 0) {
            Write-Host ""
            Write-Host "Errors:" -ForegroundColor Red
            foreach ($result in $errors) {
                if ($result.Line -gt 0) {
                    Write-Host "  [ERROR] $($result.File) (Line $($result.Line)) - $($result.Message)" -ForegroundColor Red
                }
                else {
                    Write-Host "  [ERROR] $($result.File) - $($result.Message)" -ForegroundColor Red
                }
            }
        }

        if ($warnings.Count -gt 0) {
            Write-Host ""
            Write-Host "Warnings:" -ForegroundColor Yellow
            foreach ($result in $warnings) {
                if ($result.Line -gt 0) {
                    Write-Host "  [WARN] $($result.File) (Line $($result.Line)) - $($result.Message)" -ForegroundColor Yellow
                }
                else {
                    Write-Host "  [WARN] $($result.File) - $($result.Message)" -ForegroundColor Yellow
                }
            }
        }

        if ($info.Count -gt 0) {
            Write-Host ""
            Write-Host "Info:" -ForegroundColor Cyan
            foreach ($result in $info) {
                if ($result.Line -gt 0) {
                    Write-Host "  [INFO] $($result.File) (Line $($result.Line)) - $($result.Message)" -ForegroundColor Cyan
                }
                else {
                    Write-Host "  [INFO] $($result.File) - $($result.Message)" -ForegroundColor Cyan
                }
            }
        }

        Write-Host ""
        Write-Host "--- Summary ---" -ForegroundColor Cyan
        $errCount = $errors.Count
        $warnCount = $warnings.Count
        $infoCount = $info.Count
        Write-Host "Total Issues: $($validationResults.Count)" -ForegroundColor White
        Write-Host "  Errors: $errCount" -ForegroundColor Red
        Write-Host "  Warnings: $warnCount" -ForegroundColor Yellow
        Write-Host "  Info: $infoCount" -ForegroundColor Cyan
    }

    # Exit with error if there are errors
    if ($errors.Count -gt 0) {
        Write-Host ""
        Write-Host "Validation failed with errors" -ForegroundColor Red
        exit 1
    }

    if ($warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "Validation completed with warnings" -ForegroundColor Yellow
        exit 0
    }

    Write-Host ""
    Write-Host "Validation completed successfully!" -ForegroundColor Green
    exit 0
}
catch {
    $errorMsg = $_.Exception.Message
    Write-Host ""
    Write-Host "Validation failed: $errorMsg" -ForegroundColor Red
    exit 1
}
