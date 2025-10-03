Describe "Self-Hosted Runner Configuration Tests" {
    BeforeAll {
        $workflowPath = Join-Path $PSScriptRoot "..\\.github\workflows"
        $workflows = Get-ChildItem -Path $workflowPath -Filter "*.yml" -ErrorAction SilentlyContinue
    }

    Context "Workflow Runner Configuration" {
        It "Should find workflow files" {
            $workflows | Should Not BeNullOrEmpty
            $workflows.Count | Should BeGreaterThan 0
        }

        It "All workflows should use self-hosted runners" {
            foreach ($workflow in $workflows) {
                $content = Get-Content $workflow.FullName -Raw

                # Check if the workflow contains runs-on configuration
                if ($content -match 'runs-on:\s*(.+)') {
                    $runsOn = $matches[1].Trim()

                    # Should contain 'self-hosted' either as string or in array
                    $runsOn | Should Match 'self-hosted'

                    # Should NOT use github-hosted runners
                    $runsOn -match 'ubuntu-latest|windows-latest|macos-latest' | Should Be $false
                }
            }
        }

        It "Workflows should specify OS labels for self-hosted runners" {
            foreach ($workflow in $workflows) {
                $content = Get-Content $workflow.FullName -Raw

                if ($content -match 'runs-on:\s*\[([^\]]+)\]') {
                    $labels = $matches[1].Split(',').Trim()

                    # Should have at least 2 labels (self-hosted + OS or capability)
                    $labels.Count -ge 2 | Should Be $true

                    # First label should be self-hosted
                    $labels[0].Trim('"').Trim("'") | Should Be 'self-hosted'
                }
            }
        }

        It "docker-test.yml should use docker label" {
            $dockerWorkflow = $workflows | Where-Object { $_.Name -eq 'docker-test.yml' }
            if ($dockerWorkflow) {
                $content = Get-Content $dockerWorkflow.FullName -Raw
                $content | Should Match '\[self-hosted,\s*windows,\s*docker\]'
            }
        }

        It "runner-health.yml should use windows label" {
            $healthWorkflow = $workflows | Where-Object { $_.Name -eq 'runner-health.yml' }
            if ($healthWorkflow) {
                $content = Get-Content $healthWorkflow.FullName -Raw
                $content | Should Match '\[self-hosted,\s*windows\]'
            }
        }

        It "workspace-cleanup.yml should use windows label" {
            $cleanupWorkflow = $workflows | Where-Object { $_.Name -eq 'workspace-cleanup.yml' }
            if ($cleanupWorkflow) {
                $content = Get-Content $cleanupWorkflow.FullName -Raw
                $content | Should Match '\[self-hosted,\s*windows\]'
            }
        }
    }

    Context "Workflow Actions Version" {
        It "Workflows should use actions/checkout@v4" {
            foreach ($workflow in $workflows) {
                $content = Get-Content $workflow.FullName -Raw
                if ($content -match 'actions/checkout@') {
                    $content | Should Match 'actions/checkout@v4'
                }
            }
        }
    }

    Context "Security Best Practices" {
        It "Workflows should not contain hardcoded secrets" {
            foreach ($workflow in $workflows) {
                $content = Get-Content $workflow.FullName -Raw

                # Check for common secret patterns (this is basic, not comprehensive)
                $content -match 'password:\s*[''"](?!.*\$\{\{)' | Should Be $false
                $content -match 'token:\s*[''"](?!.*\$\{\{)' | Should Be $false
                $content -match 'api[_-]?key:\s*[''"](?!.*\$\{\{)' | Should Be $false
            }
        }

        It "Workflows should use secrets context for sensitive data" {
            foreach ($workflow in $workflows) {
                $content = Get-Content $workflow.FullName -Raw

                # If workflow uses env vars that look like secrets, they should use secrets context
                if ($content -match '(?:PASSWORD|TOKEN|KEY|SECRET)') {
                    # This is informational - workflows using sensitive data should use ${{ secrets.* }}
                    Write-Host "Info: $($workflow.Name) may contain sensitive references - verify they use secrets context"
                }
            }
        }
    }
}
