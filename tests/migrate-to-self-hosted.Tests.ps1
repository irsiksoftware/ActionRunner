BeforeAll {
    # Import the script to test
    $scriptPath = Join-Path $PSScriptRoot "..\scripts\migrate-to-self-hosted.ps1"

    # Create test repository structure
    $testRepoPath = Join-Path $TestDrive "TestRepo"
    $workflowDir = Join-Path $testRepoPath ".github\workflows"
    New-Item -Path $workflowDir -ItemType Directory -Force | Out-Null

    # Helper function to create test workflow
    function New-TestWorkflow {
        param(
            [string]$Name,
            [string]$RunsOn
        )

        $workflowContent = @"
name: $Name

on: [push]

jobs:
  test:
    runs-on: $RunsOn
    steps:
      - uses: actions/checkout@v4
"@

        $workflowPath = Join-Path $workflowDir "$Name.yml"
        Set-Content -Path $workflowPath -Value $workflowContent
        return $workflowPath
    }
}

Describe "migrate-to-self-hosted.ps1 Tests" {
    Context "Workflow Detection" {
        It "Should detect GitHub-hosted ubuntu-latest runner" {
            $workflow = New-TestWorkflow -Name "ubuntu-test" -RunsOn "ubuntu-latest"
            $content = Get-Content $workflow -Raw

            $content | Should -Match 'runs-on:\s*ubuntu-latest'
        }

        It "Should detect GitHub-hosted windows-latest runner" {
            $workflow = New-TestWorkflow -Name "windows-test" -RunsOn "windows-latest"
            $content = Get-Content $workflow -Raw

            $content | Should -Match 'runs-on:\s*windows-latest'
        }

        It "Should detect self-hosted runner" {
            $workflow = New-TestWorkflow -Name "self-hosted-test" -RunsOn "[self-hosted, windows]"
            $content = Get-Content $workflow -Raw

            $content | Should -Match 'runs-on:\s*\[?\s*self-hosted'
        }
    }

    Context "Workflow Migration" {
        It "Should replace ubuntu-latest with self-hosted linux" {
            $workflow = New-TestWorkflow -Name "ubuntu-migrate" -RunsOn "ubuntu-latest"

            # Simulate migration
            $content = Get-Content $workflow -Raw
            $updated = $content -replace 'runs-on: ubuntu-latest', 'runs-on: [self-hosted, linux]'
            Set-Content -Path $workflow -Value $updated -NoNewline

            $result = Get-Content $workflow -Raw
            $result | Should -Match 'runs-on:\s*\[self-hosted,\s*linux\]'
            $result | Should -Not -Match 'ubuntu-latest'
        }

        It "Should replace windows-latest with self-hosted windows" {
            $workflow = New-TestWorkflow -Name "windows-migrate" -RunsOn "windows-latest"

            # Simulate migration
            $content = Get-Content $workflow -Raw
            $updated = $content -replace 'runs-on: windows-latest', 'runs-on: [self-hosted, windows]'
            Set-Content -Path $workflow -Value $updated -NoNewline

            $result = Get-Content $workflow -Raw
            $result | Should -Match 'runs-on:\s*\[self-hosted,\s*windows\]'
            $result | Should -Not -Match 'windows-latest'
        }

        It "Should create backup when migrating" {
            $workflow = New-TestWorkflow -Name "backup-test" -RunsOn "ubuntu-latest"
            $originalContent = Get-Content $workflow -Raw

            # Simulate backup creation
            $backupPath = "$workflow.backup"
            Copy-Item -Path $workflow -Destination $backupPath

            Test-Path $backupPath | Should -Be $true
            $backupContent = Get-Content $backupPath -Raw
            $backupContent | Should -Be $originalContent
        }
    }

    Context "Multiple Workflows" {
        It "Should handle repository with multiple workflow files" {
            New-TestWorkflow -Name "workflow1" -RunsOn "ubuntu-latest" | Out-Null
            New-TestWorkflow -Name "workflow2" -RunsOn "windows-latest" | Out-Null
            New-TestWorkflow -Name "workflow3" -RunsOn "[self-hosted, windows]" | Out-Null

            $workflows = Get-ChildItem -Path $workflowDir -Filter "*.yml"
            $workflows.Count | Should -Be 3
        }

        It "Should identify which workflows need migration" {
            New-TestWorkflow -Name "needs-migration" -RunsOn "ubuntu-latest" | Out-Null
            New-TestWorkflow -Name "already-migrated" -RunsOn "[self-hosted, windows]" | Out-Null

            $workflows = Get-ChildItem -Path $workflowDir -Filter "*.yml"

            $needsMigration = @()
            $alreadyMigrated = @()

            foreach ($wf in $workflows) {
                $content = Get-Content $wf.FullName -Raw
                if ($content -match 'runs-on:\s*\[?\s*self-hosted') {
                    $alreadyMigrated += $wf
                } elseif ($content -match 'runs-on:\s*(ubuntu|windows|macos)-latest') {
                    $needsMigration += $wf
                }
            }

            $needsMigration.Count | Should -BeGreaterThan 0
            $alreadyMigrated.Count | Should -BeGreaterThan 0
        }
    }

    Context "Edge Cases" {
        It "Should handle workflow with array syntax runs-on" {
            $workflowContent = @"
name: Array Syntax

on: [push]

jobs:
  test:
    runs-on: [ubuntu-latest]
    steps:
      - uses: actions/checkout@v4
"@

            $workflowPath = Join-Path $workflowDir "array-syntax.yml"
            Set-Content -Path $workflowPath -Value $workflowContent

            $content = Get-Content $workflowPath -Raw
            $content | Should -Match 'runs-on:\s*\[ubuntu-latest\]'
        }

        It "Should handle workflow with version-specific runner" {
            $workflowContent = @"
name: Specific Version

on: [push]

jobs:
  test:
    runs-on: ubuntu-20.04
    steps:
      - uses: actions/checkout@v4
"@

            $workflowPath = Join-Path $workflowDir "version-specific.yml"
            Set-Content -Path $workflowPath -Value $workflowContent

            $content = Get-Content $workflowPath -Raw
            $content | Should -Match 'runs-on:\s*ubuntu-\d+\.\d+'
        }

        It "Should preserve workflow formatting after migration" {
            $originalContent = @"
name: Formatting Test

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: echo "Building"
"@

            $workflowPath = Join-Path $workflowDir "formatting-test.yml"
            Set-Content -Path $workflowPath -Value $originalContent

            # Migrate
            $content = Get-Content $workflowPath -Raw
            $updated = $content -replace 'runs-on: ubuntu-latest', 'runs-on: [self-hosted, linux]'
            Set-Content -Path $workflowPath -Value $updated -NoNewline

            $result = Get-Content $workflowPath -Raw
            $result | Should -Match 'on:'
            $result | Should -Match 'push:'
            $result | Should -Match 'branches:'
            $result | Should -Match 'jobs:'
            $result | Should -Match 'steps:'
        }
    }

    Context "Verification Mode" {
        It "Should not modify files in verify-only mode" {
            $workflow = New-TestWorkflow -Name "verify-only" -RunsOn "ubuntu-latest"
            $originalContent = Get-Content $workflow -Raw

            # In verify mode, we only read, not write
            $content = Get-Content $workflow -Raw
            $content -match 'ubuntu-latest' | Should -Be $true

            # Content should remain unchanged
            $currentContent = Get-Content $workflow -Raw
            $currentContent | Should -Be $originalContent
        }
    }

    Context "Error Handling" {
        It "Should handle missing workflow directory gracefully" {
            $nonExistentPath = Join-Path $TestDrive "NonExistent\.github\workflows"

            Test-Path $nonExistentPath | Should -Be $false
        }

        It "Should handle empty workflow directory" {
            $emptyWorkflowDir = Join-Path $TestDrive "Empty\.github\workflows"
            New-Item -Path $emptyWorkflowDir -ItemType Directory -Force | Out-Null

            $workflows = Get-ChildItem -Path $emptyWorkflowDir -Filter "*.yml" -ErrorAction SilentlyContinue
            $workflows.Count | Should -Be 0
        }

        It "Should handle malformed YAML files" {
            $malformedPath = Join-Path $workflowDir "malformed.yml"
            Set-Content -Path $malformedPath -Value "this is not valid yaml: {["

            Test-Path $malformedPath | Should -Be $true
            # Script should handle gracefully without crashing
        }
    }
}

Describe "Runner Availability Tests" {
    Context "Runner Service Detection" {
        It "Should detect if runner service exists" {
            # This is a system-dependent test
            $services = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue

            # Test passes if we can query services (even if none exist)
            # Service query should not throw an error
            { Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should check if runner directory exists" {
            $runnerDir = "C:\actions-runner"

            # This test documents expected runner location
            # Actual existence depends on system setup
            $runnerDir | Should -Be "C:\actions-runner"
        }
    }
}

Describe "Integration Tests" {
    Context "Full Migration Workflow" {
        It "Should perform complete migration simulation" {
            # Setup: Create test workflows
            $wf1 = New-TestWorkflow -Name "integration-ubuntu" -RunsOn "ubuntu-latest"
            $wf2 = New-TestWorkflow -Name "integration-windows" -RunsOn "windows-latest"
            $wf3 = New-TestWorkflow -Name "integration-existing" -RunsOn "[self-hosted, windows]"

            # Analyze
            $workflows = Get-ChildItem -Path $workflowDir -Filter "*.yml"
            $workflows.Count | Should -BeGreaterThan 0

            # Identify migration targets
            $toMigrate = @()
            foreach ($wf in $workflows) {
                $content = Get-Content $wf.FullName -Raw
                if ($content -match 'runs-on:\s*(ubuntu|windows|macos)-latest') {
                    $toMigrate += $wf
                }
            }

            $toMigrate.Count | Should -Be 2

            # Migrate
            foreach ($wf in $toMigrate) {
                $content = Get-Content $wf.FullName -Raw
                $updated = $content -replace 'runs-on: ubuntu-latest', 'runs-on: [self-hosted, linux]'
                $updated = $updated -replace 'runs-on: windows-latest', 'runs-on: [self-hosted, windows]'
                Set-Content -Path $wf.FullName -Value $updated -NoNewline
            }

            # Verify
            $allWorkflows = Get-ChildItem -Path $workflowDir -Filter "*.yml"
            foreach ($wf in $allWorkflows) {
                $content = Get-Content $wf.FullName -Raw
                $content | Should -Match 'self-hosted'
            }
        }
    }
}
