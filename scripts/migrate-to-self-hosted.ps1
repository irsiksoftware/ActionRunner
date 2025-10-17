<#
.SYNOPSIS
    Migrates GitHub Actions workflows from GitHub-hosted to self-hosted runners.

.DESCRIPTION
    This script helps migrate CI/CD workflows to self-hosted runners to avoid
    GitHub Actions minutes limits. It verifies runner setup, updates workflow files,
    and validates the migration.

    Features:
    - Scanning workflow files for GitHub-hosted runner configurations
    - Backing up original workflows
    - Updating runs-on to use self-hosted runners
    - Providing a migration report

.PARAMETER RepoPath
    Path to the local repository (default: current directory)

.PARAMETER VerifyOnly
    Only verify existing self-hosted runner setup without making changes

.PARAMETER AutoUpdate
    Automatically update workflow files to use self-hosted runners

.PARAMETER BackupWorkflows
    Create backup of workflow files before updating (default: true)

.PARAMETER WorkflowPath
    Path to the .github/workflows directory (default: .github/workflows)

.PARAMETER RunnerLabels
    Comma-separated list of runner labels (default: self-hosted)

.PARAMETER BackupDir
    Directory to store workflow backups (default: .github/workflows.backup)

.PARAMETER DryRun
    Preview changes without modifying files

.EXAMPLE
    .\migrate-to-self-hosted.ps1 -VerifyOnly

.EXAMPLE
    .\migrate-to-self-hosted.ps1 -AutoUpdate -RepoPath "C:\Code\ActionRunner"

.EXAMPLE
    .\migrate-to-self-hosted.ps1
    Migrates all workflows with default settings

.EXAMPLE
    .\migrate-to-self-hosted.ps1 -RunnerLabels "self-hosted,linux,x64" -DryRun
    Preview migration with specific runner labels
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
    [bool]$BackupWorkflows = $true,

    [Parameter()]
    [string]$WorkflowPath = ".github/workflows",

    [Parameter()]
    [string]$RunnerLabels = "self-hosted",

    [Parameter()]
    [string]$BackupDir = ".github/workflows.backup",

    [Parameter()]
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# GitHub-hosted runner identifiers to detect
$GitHubHostedRunners = @(
    'ubuntu-latest', 'ubuntu-22.04', 'ubuntu-20.04',
    'windows-latest', 'windows-2022', 'windows-2019',
    'macos-latest', 'macos-13', 'macos-12', 'macos-11'
)

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

function Write-Header {
    param([string]$Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Yellow
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
    param([string]$Path)

    $workflowDir = if ([System.IO.Path]::IsPathRooted($Path)) {
        $Path
    } else {
        Join-Path $RepoPath $Path
    }

    if (-not (Test-Path $workflowDir)) {
        Write-Log "No workflows directory found at $workflowDir" "WARN"
        return @()
    }

    $workflows = Get-ChildItem -Path $workflowDir -Filter "*.yml" -File -ErrorAction SilentlyContinue
    $workflows += Get-ChildItem -Path $workflowDir -Filter "*.yaml" -File -ErrorAction SilentlyContinue

    return $workflows
}

function Test-GitHubHostedRunner {
    param([string]$Content)

    foreach ($runner in $GitHubHostedRunners) {
        if ($Content -match "runs-on:\s+$runner") {
            return $true
        }
        if ($Content -match "runs-on:\s+\[$runner\]") {
            return $true
        }
    }
    return $false
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
    if (Test-GitHubHostedRunner -Content $content) {
        return @{
            NeedsMigration = $true
            CurrentRunner = "GitHub-hosted"
            Status = "Needs migration"
        }
    }

    return @{
        NeedsMigration = $false
        CurrentRunner = "Unknown"
        Status = "Unable to determine"
    }
}

function Convert-RunnerConfig {
    param(
        [string]$Content,
        [string]$Labels
    )

    $labelsArray = $Labels -split ',' | ForEach-Object { $_.Trim() }
    $runnerConfig = if ($labelsArray.Count -eq 1) {
        $labelsArray[0]
    } else {
        "[" + ($labelsArray -join ", ") + "]"
    }

    $modified = $Content
    foreach ($runner in $GitHubHostedRunners) {
        # Match both simple and array format
        $modified = $modified -replace "runs-on:\s+$runner", "runs-on: $runnerConfig"
        $modified = $modified -replace "runs-on:\s+\[$runner\]", "runs-on: $runnerConfig"
    }

    return $modified
}

function Backup-Workflow {
    param(
        [string]$FilePath,
        [string]$BackupDirectory
    )

    if (-not (Test-Path $BackupDirectory)) {
        New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
    }

    $fileName = Split-Path $FilePath -Leaf
    $backupPath = Join-Path $BackupDirectory $fileName
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

    # Add timestamp if backup already exists
    if (Test-Path $backupPath) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
        $extension = [System.IO.Path]::GetExtension($fileName)
        $backupPath = Join-Path $BackupDirectory "$baseName.$timestamp$extension"
    }

    Copy-Item -Path $FilePath -Destination $backupPath -Force
    return $backupPath
}

function Update-WorkflowToSelfHosted {
    param(
        [string]$WorkflowPath,
        [bool]$CreateBackup = $true,
        [string]$Labels
    )

    Write-Log "Updating workflow: $WorkflowPath"

    # Create backup
    if ($CreateBackup) {
        $backupDir = Join-Path $RepoPath $BackupDir
        $backupPath = Backup-Workflow -FilePath $WorkflowPath -BackupDirectory $backupDir
        Write-Log "Created backup: $backupPath" "INFO"
    }

    # Read workflow content
    $content = Get-Content -Path $WorkflowPath -Raw

    # Convert runner configuration
    $modifiedContent = Convert-RunnerConfig -Content $content -Labels $Labels

    if ($content -ne $modifiedContent) {
        Set-Content -Path $WorkflowPath -Value $modifiedContent -NoNewline
        Write-Log "  Workflow updated successfully" "SUCCESS"
        return $true
    } else {
        Write-Log "  No changes needed" "INFO"
        return $false
    }
}

function Show-Diff {
    param(
        [string]$Original,
        [string]$Modified,
        [string]$FileName
    )

    Write-Host "`nChanges for: $FileName" -ForegroundColor Magenta
    Write-Host "─" * 60

    $originalLines = $Original -split "`n"
    $modifiedLines = $Modified -split "`n"

    for ($i = 0; $i -lt [Math]::Max($originalLines.Count, $modifiedLines.Count); $i++) {
        $origLine = if ($i -lt $originalLines.Count) { $originalLines[$i] } else { "" }
        $modLine = if ($i -lt $modifiedLines.Count) { $modifiedLines[$i] } else { "" }

        if ($origLine -ne $modLine) {
            if ($origLine) {
                Write-Host "- $origLine" -ForegroundColor Red
            }
            if ($modLine) {
                Write-Host "+ $modLine" -ForegroundColor Green
            }
        }
    }
    Write-Host "─" * 60
}

# Main execution
Write-Log "=== GitHub Actions Self-Hosted Runner Migration ==="
Write-Log "Repository Path: $RepoPath"
Write-Log "Verify Only: $VerifyOnly"
Write-Log "Auto Update: $AutoUpdate"
Write-Log "Dry Run: $DryRun"
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
$workflows = Get-WorkflowFiles -Path $WorkflowPath

if ($workflows.Count -eq 0) {
    Write-Log "No workflow files found" "WARN"
    exit 0
}

Write-Log "Found $($workflows.Count) workflow file(s)" "INFO"
Write-Log ""

# Track migration statistics
$stats = @{
    Total = $workflows.Count
    Migrated = 0
    AlreadyMigrated = 0
    Skipped = 0
}

$migrationNeeded = @()
$alreadyMigrated = @()
$unknown = @()
$migratedFiles = @()

foreach ($workflow in $workflows) {
    Write-Log "Checking: $($workflow.Name)"
    $status = Test-WorkflowMigration -WorkflowPath $workflow.FullName

    Write-Log "  Status: $($status.Status)" $(if ($status.NeedsMigration) { "WARN" } else { "SUCCESS" })
    Write-Log "  Current: $($status.CurrentRunner)" "INFO"

    if ($status.NeedsMigration) {
        $migrationNeeded += $workflow
    } elseif ($status.Status -eq "Already migrated") {
        $alreadyMigrated += $workflow
        $stats.AlreadyMigrated++
    } else {
        $unknown += $workflow
    }
}

Write-Log ""
Write-Log "=== Migration Summary ==="
Write-Log "Total workflows: $($stats.Total)"
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
    if ($AutoUpdate -or $DryRun) {
        Write-Log "$(if ($DryRun) { 'Previewing' } else { 'Auto-updating' }) workflows to use self-hosted runners..." "INFO"
        Write-Log ""

        foreach ($workflow in $migrationNeeded) {
            $content = Get-Content -Path $workflow.FullName -Raw
            $modifiedContent = Convert-RunnerConfig -Content $content -Labels $RunnerLabels

            if ($DryRun) {
                Show-Diff -Original $content -Modified $modifiedContent -FileName $workflow.Name
                $stats.Migrated++
                $migratedFiles += $workflow.Name
            } else {
                $updated = Update-WorkflowToSelfHosted -WorkflowPath $workflow.FullName -CreateBackup $BackupWorkflows -Labels $RunnerLabels
                if ($updated) {
                    $stats.Migrated++
                    $migratedFiles += $workflow.Name
                }
            }
        }

        Write-Log ""
        Write-Log "=== Migration $(if ($DryRun) { 'Preview' } else { 'Complete' }) ===" "SUCCESS"
        Write-Log "$(if ($DryRun) { 'Would update' } else { 'Updated' }) $($stats.Migrated) workflow file(s)" "SUCCESS"
        if (-not $DryRun) {
            Write-Log "Backup files created: $BackupWorkflows" "INFO"
        }
        Write-Log ""
        Write-Log "Next steps:" "INFO"
        Write-Log "1. Review the changes in updated workflow files" "INFO"
        Write-Log "2. Ensure your self-hosted runner is configured with labels: $RunnerLabels" "INFO"
        Write-Log "3. Test workflows with 'workflow_dispatch' trigger" "INFO"
        Write-Log "4. Commit and push changes to activate self-hosted runner usage" "INFO"

        if ($DryRun) {
            Write-Log "`nRe-run without -DryRun to apply changes" "INFO"
        }
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
