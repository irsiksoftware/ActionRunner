BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    $WorkflowsPath = Join-Path $ProjectRoot ".github\workflows"
}

Describe "GitHub Workflows Configuration" {
    Context "Workflow Files Exist" {
        It "Should have CI workflow" {
            $ciWorkflow = Join-Path $WorkflowsPath "ci.yml"
            $ciWorkflow | Should -Exist
        }

        It "Should have Docker test workflow" -Skip:$true {
            # docker-test.yml does not exist in this repository
            # Docker testing is done via the Build Capability Tests workflow
            $dockerWorkflow = Join-Path $WorkflowsPath "docker-test.yml"
            $dockerWorkflow | Should -Exist
        }

        It "Should have runner health check workflow" {
            $healthWorkflow = Join-Path $WorkflowsPath "runner-health.yml"
            $healthWorkflow | Should -Exist
        }
    }

    Context "CI Workflow Configuration" {
        BeforeAll {
            $ciWorkflow = Join-Path $WorkflowsPath "ci.yml"
            $content = Get-Content $ciWorkflow -Raw
        }

        It "Should use self-hosted runner" {
            $content | Should -Match "runs-on:\s*\[self-hosted,\s*windows\]"
        }

        It "Should have test job" {
            $content | Should -Match "test-powershell-scripts:"
        }

        It "Should have validation job" {
            $content | Should -Match "validate-configuration:"
        }

        It "Should have security scan job" {
            $content | Should -Match "security-scan:"
        }

        It "Should checkout code" {
            $content | Should -Match "actions/checkout@v4"
        }

        It "Should run Pester tests" {
            $content | Should -Match "Invoke-Pester"
        }

        It "Should upload test results" {
            $content | Should -Match "actions/upload-artifact@v4"
        }
    }

    Context "Docker Test Workflow Configuration" -Skip {
        # docker-test.yml does not exist in this repository
        # Docker testing is done via the Build Capability Tests workflow
        BeforeAll {
            $dockerWorkflow = Join-Path $WorkflowsPath "docker-test.yml"
            $content = Get-Content $dockerWorkflow -Raw
        }

        It "Should use self-hosted runner with docker label" {
            $content | Should -Match "runs-on:\s*\[self-hosted,\s*windows,\s*docker\]"
        }

        It "Should verify Docker availability" {
            $content | Should -Match "docker --version"
        }

        It "Should test container execution" {
            $content | Should -Match "docker run"
        }

        It "Should have cleanup step" {
            $content | Should -Match "docker system prune"
        }

        It "Should run on workflow_dispatch" {
            $content | Should -Match "workflow_dispatch:"
        }
    }

    Context "Runner Health Check Workflow Configuration" {
        BeforeAll {
            $healthWorkflow = Join-Path $WorkflowsPath "runner-health.yml"
            $content = Get-Content $healthWorkflow -Raw
        }

        It "Should use self-hosted runner" {
            $content | Should -Match "runs-on:\s*\[self-hosted,\s*windows\]"
        }

        It "Should have scheduled trigger" {
            $content | Should -Match "schedule:"
            $content | Should -Match "cron:"
        }

        It "Should run comprehensive health check script" {
            # The workflow runs health-check.ps1 which performs disk, memory, CPU checks
            $content | Should -Match "health-check\.ps1"
        }

        It "Should check Docker health" {
            $content | Should -Match "Docker Health Check|Docker health|docker info"
        }
    }

    Context "Workflow Security" {
        BeforeAll {
            $workflows = Get-ChildItem $WorkflowsPath -Filter "*.yml"
        }

        It "Should not contain hardcoded secrets" {
            foreach ($workflow in $workflows) {
                $content = Get-Content $workflow.FullName -Raw

                # Check for actual secret values (not regex patterns used for detection)
                # These patterns match actual secrets, not the regex patterns used in security scanning scripts
                $content | Should -Not -Match "ghp_[a-zA-Z0-9]{36}"
                $content | Should -Not -Match "ghs_[a-zA-Z0-9]{36}"
                $content | Should -Not -Match "github_pat_[a-zA-Z0-9_]{82}"
            }
        }

        It "All workflows should use self-hosted runners only" {
            foreach ($workflow in $workflows) {
                $content = Get-Content $workflow.FullName -Raw

                # Should not use GitHub-hosted runners
                $content | Should -Not -Match "runs-on:\s*ubuntu-latest"
                $content | Should -Not -Match "runs-on:\s*windows-latest"
                $content | Should -Not -Match "runs-on:\s*macos-latest"

                # Should use self-hosted
                $content | Should -Match "self-hosted"
            }
        }
    }

    Context "Workflow Syntax" {
        BeforeAll {
            $workflows = Get-ChildItem $WorkflowsPath -Filter "*.yml"
        }

        It "Should have valid YAML syntax for <_>" -ForEach $workflows {
            $content = Get-Content $_.FullName -Raw

            # Basic YAML validation - should not have tab characters
            $content | Should -Not -Match "`t"

            # Should have proper structure
            $content | Should -Match "^name:"
            $content | Should -Match "on:"
            $content | Should -Match "jobs:"
        }

        It "Should use PowerShell shell for Windows runners" {
            $ciWorkflow = Join-Path $WorkflowsPath "ci.yml"
            $content = Get-Content $ciWorkflow -Raw

            # Should specify PowerShell shell
            $content | Should -Match "shell:\s*(pwsh|powershell)"
        }
    }

    Context "Workflow Best Practices" {
        BeforeAll {
            $workflows = Get-ChildItem $WorkflowsPath -Filter "*.yml"
        }

        It "Should use checkout action v4 or higher" {
            foreach ($workflow in $workflows) {
                $content = Get-Content $workflow.FullName -Raw

                if ($content -match "actions/checkout") {
                    $content | Should -Match "actions/checkout@v[4-9]"
                }
            }
        }

        It "Should have descriptive job names" {
            foreach ($workflow in $workflows) {
                $content = Get-Content $workflow.FullName -Raw

                # Each job should have a 'name:' field
                if ($content -match "jobs:") {
                    $content | Should -Match "name:\s*.+"
                }
            }
        }

        It "Should use continue-on-error appropriately" {
            $healthWorkflow = Join-Path $WorkflowsPath "runner-health.yml"
            $content = Get-Content $healthWorkflow -Raw

            # Docker health check should continue on error
            $content | Should -Match "continue-on-error:\s*true"
        }
    }
}

Describe "Migration Guide Documentation" {
    Context "Migration Guide Exists" {
        It "Should have MIGRATION_GUIDE.md" {
            $migrationGuide = Join-Path $ProjectRoot "MIGRATION_GUIDE.md"
            $migrationGuide | Should -Exist
        }

        It "Should have substantial content" {
            $migrationGuide = Join-Path $ProjectRoot "MIGRATION_GUIDE.md"
            $content = Get-Content $migrationGuide -Raw
            $content.Length | Should -BeGreaterThan 1000
        }

        It "Should include step-by-step instructions" {
            $migrationGuide = Join-Path $ProjectRoot "MIGRATION_GUIDE.md"
            $content = Get-Content $migrationGuide -Raw

            $content | Should -Match "Step 1:"
            $content | Should -Match "Step 2:"
            $content | Should -Match "Step 3:"
        }

        It "Should include workflow examples" {
            $migrationGuide = Join-Path $ProjectRoot "MIGRATION_GUIDE.md"
            $content = Get-Content $migrationGuide -Raw

            $content | Should -Match "runs-on: windows-latest"
            $content | Should -Match "runs-on: \[self-hosted, windows\]"
        }

        It "Should include security warnings" {
            $migrationGuide = Join-Path $ProjectRoot "MIGRATION_GUIDE.md"
            $content = Get-Content $migrationGuide -Raw

            $content | Should -Match "(?i)security"
            $content | Should -Match "(?i)private"
        }

        It "Should include troubleshooting section" {
            $migrationGuide = Join-Path $ProjectRoot "MIGRATION_GUIDE.md"
            $content = Get-Content $migrationGuide -Raw

            $content | Should -Match "(?i)(troubleshoot|common.*issue)"
        }
    }
}
