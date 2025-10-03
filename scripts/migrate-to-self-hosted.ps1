<#
.SYNOPSIS
    Migrates GitHub Actions workflows from GitHub-hosted to self-hosted runners.

.DESCRIPTION
    This script helps migrate CI/CD workflows to self-hosted runners to avoid
    GitHub Actions minutes limits. It verifies runner setup, updates workflow files,
    and validates the migration.

.PARAMETER RepoPath
    Path to the local repository (default: current directory)

.PARAMETER VerifyOnly
    Only verify existing self-hosted runner setup without making changes

.PARAMETER AutoUpdate
    Automatically update workflow files to use self-hosted runners

.PARAMETER BackupWorkflows
    Create backup of workflow files before updating (default: true)

.EXAMPLE
    .\migrate-to-self-hosted.ps1 -VerifyOnly

.EXAMPLE
    .\migrate-to-self-hosted.ps1 -AutoUpdate -RepoPath "C:\Code\ActionRunner"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoPath = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [switch]$VerifyOnly,

    [Parameter(Mandatory = $false)]
    [switch]$AutoUpdate,

    [Parameter(Mandatory = $false)]
    [bool]$BackupWorkflows = $true
)

$ErrorActionPreference = "Stop"

# Setup logging
$LogDir = Join-Path $RepoPath "logs"
if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

$LogFile = Join-Path $LogDir "migration-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARN"  { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default { Write-Host $logMessage }
    }

    Add-Content -Path $LogFile -Value $logMessage
}

function Test-RunnerAvailability {
    Write-Log "Checking self-hosted runner availability..."

    # Check if runner service is installed
    $runnerService = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue

    if (-not $runnerService) {
        Write-Log "No self-hosted runner service found" "ERROR"
        Write-Log "Run setup-runner.ps1 to install a runner first" "ERROR"
        return $false
    }

    if ($runnerService.Status -ne 'Running') {
        Write-Log "Runner service exists but is not running: $($runnerService.Status)" "WARN"
        Write-Log "Starting runner service..." "INFO"
        try {
            Start-Service $runnerService.Name
            Start-Sleep -Seconds 3
            Write-Log "Runner service started successfully" "SUCCESS"
        } catch {
            Write-Log "Failed to start runner service: $_" "ERROR"
            return $false
        }
    } else {
        Write-Log "Runner service is running: $($runnerService.Name)" "SUCCESS"
    }

    # Check runner work directory
    $runnerDir = "C:\actions-runner"
    if (Test-Path $runnerDir) {
        Write-Log "Runner directory exists: $runnerDir" "SUCCESS"

        # Check for runner configuration
        $configFile = Join-Path $runnerDir ".runner"
        if (Test-Path $configFile) {
            Write-Log "Runner is configured" "SUCCESS"
        } else {
            Write-Log "Runner directory exists but no configuration found" "WARN"
        }
    } else {
        Write-Log "Runner directory not found: $runnerDir" "ERROR"
        return $false
    }

    return $true
}

function Get-WorkflowFiles {
    $workflowDir = Join-Path $RepoPath ".github\workflows"

    if (-not (Test-Path $workflowDir)) {
        Write-Log "No workflows directory found at $workflowDir" "WARN"
        return @()
    }

    $workflows = Get-ChildItem -Path $workflowDir -Filter "*.yml" -ErrorAction SilentlyContinue
    $workflows += Get-ChildItem -Path $workflowDir -Filter "*.yaml" -ErrorAction SilentlyContinue

    return $workflows
}

function Test-WorkflowMigration {
    param([string]$WorkflowPath)

    $content = Get-Content -Path $WorkflowPath -Raw

    # Check if already using self-hosted
    if ($content -match 'runs-on:\s*\[?\s*self-hosted') {
        return @{
            NeedsMigration = $false
            CurrentRunner = "self-hosted"
            Status = "Already migrated"
        }
    }

    # Check for GitHub-hosted runners
    $githubHostedPatterns = @(
        'runs-on:\s*ubuntu-latest',
        'runs-on:\s*windows-latest',
        'runs-on:\s*macos-latest',
        'runs-on:\s*ubuntu-\d+\.\d+',
        'runs-on:\s*windows-\d+\.\d+'
    )

    foreach ($pattern in $githubHostedPatterns) {
        if ($content -match $pattern) {
            return @{
                NeedsMigration = $true
                CurrentRunner = $matches[0]
                Status = "Needs migration"
            }
        }
    }

    return @{
        NeedsMigration = $false
        CurrentRunner = "Unknown"
        Status = "Unable to determine"
    }
}

function Update-WorkflowToSelfHosted {
    param(
        [string]$WorkflowPath,
        [bool]$CreateBackup = $true
    )

    Write-Log "Updating workflow: $WorkflowPath"

    # Create backup
    if ($CreateBackup) {
        $backupPath = "$WorkflowPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -Path $WorkflowPath -Destination $backupPath
        Write-Log "Created backup: $backupPath" "INFO"
    }

    # Read workflow content
    $content = Get-Content -Path $WorkflowPath -Raw

    # Replace GitHub-hosted runners with self-hosted
    $replacements = @{
        'runs-on: ubuntu-latest' = 'runs-on: [self-hosted, linux]'
        'runs-on: windows-latest' = 'runs-on: [self-hosted, windows]'
        'runs-on: macos-latest' = 'runs-on: [self-hosted, macos]'
        'runs-on: ubuntu-\d+\.\d+' = 'runs-on: [self-hosted, linux]'
        'runs-on: windows-\d+\.\d+' = 'runs-on: [self-hosted, windows]'
    }

    $updated = $false
    foreach ($pattern in $replacements.Keys) {
        if ($content -match $pattern) {
            $content = $content -replace $pattern, $replacements[$pattern]
            $updated = $true
            Write-Log "  Replaced: $pattern -> $($replacements[$pattern])" "INFO"
        }
    }

    if ($updated) {
        Set-Content -Path $WorkflowPath -Value $content -NoNewline
        Write-Log "  Workflow updated successfully" "SUCCESS"
        return $true
    } else {
        Write-Log "  No changes needed" "INFO"
        return $false
    }
}

# Main execution
Write-Log "=== GitHub Actions Self-Hosted Runner Migration ==="
Write-Log "Repository Path: $RepoPath"
Write-Log "Verify Only: $VerifyOnly"
Write-Log "Auto Update: $AutoUpdate"
Write-Log ""

# Step 1: Verify runner availability
$runnerAvailable = Test-RunnerAvailability
Write-Log ""

if (-not $runnerAvailable) {
    Write-Log "Self-hosted runner is not available or not configured properly" "ERROR"
    Write-Log "Please run setup-runner.ps1 first to set up a self-hosted runner" "ERROR"
    Write-Log "Migration cannot proceed without a working self-hosted runner" "ERROR"
    exit 1
}

# Step 2: Analyze workflows
Write-Log "Analyzing workflow files..."
$workflows = Get-WorkflowFiles

if ($workflows.Count -eq 0) {
    Write-Log "No workflow files found" "WARN"
    exit 0
}

Write-Log "Found $($workflows.Count) workflow file(s)" "INFO"
Write-Log ""

$migrationNeeded = @()
$alreadyMigrated = @()
$unknown = @()

foreach ($workflow in $workflows) {
    Write-Log "Checking: $($workflow.Name)"
    $status = Test-WorkflowMigration -WorkflowPath $workflow.FullName

    Write-Log "  Status: $($status.Status)" $(if ($status.NeedsMigration) { "WARN" } else { "SUCCESS" })
    Write-Log "  Current: $($status.CurrentRunner)" "INFO"

    if ($status.NeedsMigration) {
        $migrationNeeded += $workflow
    } elseif ($status.Status -eq "Already migrated") {
        $alreadyMigrated += $workflow
    } else {
        $unknown += $workflow
    }
}

Write-Log ""
Write-Log "=== Migration Summary ==="
Write-Log "Total workflows: $($workflows.Count)"
Write-Log "Already using self-hosted: $($alreadyMigrated.Count)" "SUCCESS"
Write-Log "Need migration: $($migrationNeeded.Count)" $(if ($migrationNeeded.Count -gt 0) { "WARN" } else { "INFO" })
Write-Log "Unknown status: $($unknown.Count)" $(if ($unknown.Count -gt 0) { "WARN" } else { "INFO" })
Write-Log ""

# Step 3: Perform migration if requested
if ($VerifyOnly) {
    Write-Log "Verification complete (VerifyOnly mode - no changes made)" "INFO"
} elseif ($migrationNeeded.Count -eq 0) {
    Write-Log "All workflows are already configured for self-hosted runners!" "SUCCESS"
} else {
    if ($AutoUpdate) {
        Write-Log "Auto-updating workflows to use self-hosted runners..." "INFO"
        Write-Log ""

        $updateCount = 0
        foreach ($workflow in $migrationNeeded) {
            $updated = Update-WorkflowToSelfHosted -WorkflowPath $workflow.FullName -CreateBackup $BackupWorkflows
            if ($updated) {
                $updateCount++
            }
        }

        Write-Log ""
        Write-Log "=== Migration Complete ===" "SUCCESS"
        Write-Log "Updated $updateCount workflow file(s)" "SUCCESS"
        Write-Log "Backup files created: $BackupWorkflows" "INFO"
        Write-Log ""
        Write-Log "Next steps:" "INFO"
        Write-Log "1. Review the changes in updated workflow files" "INFO"
        Write-Log "2. Test workflows with 'workflow_dispatch' trigger" "INFO"
        Write-Log "3. Commit and push changes to activate self-hosted runner usage" "INFO"
    } else {
        Write-Log "Workflows need migration but AutoUpdate not specified" "WARN"
        Write-Log ""
        Write-Log "To update workflows automatically, run:" "INFO"
        Write-Log "  .\migrate-to-self-hosted.ps1 -AutoUpdate" "INFO"
        Write-Log ""
        Write-Log "Or manually update these files to use 'runs-on: [self-hosted, windows]':" "INFO"
        foreach ($workflow in $migrationNeeded) {
            Write-Log "  - $($workflow.Name)" "INFO"
        }
    }
}

Write-Log ""
Write-Log "Migration log saved to: $LogFile" "INFO"
Write-Log "=== End of Migration ===" "INFO"
