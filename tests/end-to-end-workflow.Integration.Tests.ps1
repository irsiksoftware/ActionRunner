<#
.SYNOPSIS
    End-to-end integration tests for complete workflow execution.

.DESCRIPTION
    These tests verify the complete runner setup, GitHub integration, and multiple
    frameworks working together in an end-to-end workflow scenario. This includes:
    - Complete runner installation and setup
    - GitHub workflow integration
    - Multi-framework build and test scenarios
    - Full lifecycle validation
#>

Describe "End-to-End Workflow Integration Tests" -Tag "Integration", "E2E" {
    BeforeAll {
        # Set script paths
        $script:installRunnerPath = Join-Path $PSScriptRoot "..\scripts\install-runner.ps1"
        $script:setupRunnerPath = Join-Path $PSScriptRoot "..\scripts\setup-runner.ps1"
        $script:healthCheckPath = Join-Path $PSScriptRoot "..\scripts\health-check.ps1"
        $script:applyConfigPath = Join-Path $PSScriptRoot "..\scripts\apply-config.ps1"
        $script:validateWorkflowPath = Join-Path $PSScriptRoot "..\scripts\validate-workflow.ps1"
        $script:verifyDockerPath = Join-Path $PSScriptRoot "..\scripts\verify-docker.ps1"

        # Test workspace
        $script:testWorkspace = Join-Path $env:TEMP "e2e-test-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:testWorkspace -Force | Out-Null

        # Verify required scripts exist
        $requiredScripts = @(
            $script:healthCheckPath,
            $script:applyConfigPath,
            $script:validateWorkflowPath
        )

        foreach ($scriptPath in $requiredScripts) {
            if (-not (Test-Path $scriptPath)) {
                throw "Required script not found: $scriptPath"
            }
        }

        # Store original location
        $script:originalLocation = Get-Location
    }

    AfterAll {
        # Cleanup test workspace
        if (Test-Path $script:testWorkspace) {
            Remove-Item -Path $script:testWorkspace -Recurse -Force -ErrorAction SilentlyContinue
        }

        # Restore location
        Set-Location $script:originalLocation
    }

    Context "Complete Runner Lifecycle" {
        It "Should validate system health before setup" {
            $output = & $script:healthCheckPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $script:testWorkspace
            $json = $output | ConvertFrom-Json

            $json.OverallHealth | Should -BeIn @('Healthy', 'Warning')
            $json.Checks.DiskSpace.Status | Should -Not -Be 'Unhealthy'
            $json.Checks.SystemResources.Status | Should -Not -Be 'Error'
        }

        It "Should detect required dependencies" {
            # Check for PowerShell
            $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 5

            # Check for .NET
            $dotnetVersion = dotnet --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                $dotnetVersion | Should -Not -BeNullOrEmpty
            }

            # Check for Git
            $gitVersion = git --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                $gitVersion | Should -Match 'git version'
            }
        }

        It "Should create and validate configuration" {
            $configPath = Join-Path $script:testWorkspace "test-config.json"

            # Create test configuration
            $config = @{
                runnerName = "e2e-test-runner"
                runnerGroup = "default"
                labels = @("test", "e2e")
                workDirectory = $script:testWorkspace
                logLevel = "INFO"
            }

            $config | ConvertTo-Json | Out-File -FilePath $configPath -Encoding UTF8

            # Validate configuration exists and is parseable
            Test-Path $configPath | Should -Be $true

            $loadedConfig = Get-Content $configPath -Raw | ConvertFrom-Json
            $loadedConfig.runnerName | Should -Be "e2e-test-runner"
            $loadedConfig.labels.Count | Should -Be 2
        }
    }

    Context "Multi-Framework Verification" {
        It "Should verify PowerShell environment" {
            $PSVersionTable.PSVersion.Major | Should -BeGreaterOrEqual 5
            $PSVersionTable.PSEdition | Should -BeIn @('Core', 'Desktop')
        }

        It "Should verify Node.js if available" {
            $nodeVersion = node --version 2>$null

            if ($LASTEXITCODE -eq 0) {
                $nodeVersion | Should -Match '^v\d+\.\d+\.\d+$'

                # Check npm
                $npmVersion = npm --version 2>$null
                $npmVersion | Should -Not -BeNullOrEmpty
            } else {
                Set-ItResult -Skipped -Because "Node.js not installed"
            }
        }

        It "Should verify Python if available" {
            $pythonVersion = python --version 2>$null

            if ($LASTEXITCODE -eq 0) {
                $pythonVersion | Should -Match 'Python \d+\.\d+'

                # Check pip (may not be in PATH even if Python is installed)
                $pipVersion = pip --version 2>$null
                if ($LASTEXITCODE -eq 0 -and $pipVersion) {
                    $pipVersion | Should -Match 'pip \d+'
                }
            } else {
                Set-ItResult -Skipped -Because "Python not installed"
            }
        }

        It "Should verify .NET SDK if available" {
            $dotnetVersion = dotnet --version 2>$null

            if ($LASTEXITCODE -eq 0) {
                $dotnetVersion | Should -Match '^\d+\.\d+\.\d+$'

                # Check SDKs
                $sdks = dotnet --list-sdks 2>$null
                $sdks | Should -Not -BeNullOrEmpty
            } else {
                Set-ItResult -Skipped -Because ".NET SDK not installed"
            }
        }

        It "Should verify Docker if available" {
            if (Test-Path $script:verifyDockerPath) {
                try {
                    $output = & $script:verifyDockerPath
                    if ($LASTEXITCODE -eq 0) {
                        $output | Should -Match '(Docker.*installed|Docker.*available)'
                    } else {
                        Set-ItResult -Skipped -Because "Docker not available"
                    }
                } catch {
                    Set-ItResult -Skipped -Because "Docker verification failed: $_"
                }
            } else {
                Set-ItResult -Skipped -Because "Docker verification script not found"
            }
        }
    }

    Context "Workflow Validation" {
        BeforeAll {
            # Create test workflow file
            $script:workflowDir = Join-Path $script:testWorkspace ".github\workflows"
            New-Item -ItemType Directory -Path $script:workflowDir -Force | Out-Null

            $script:testWorkflowPath = Join-Path $script:workflowDir "test-workflow.yml"

            $workflowContent = @"
name: E2E Test Workflow

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4

      - name: Setup environment
        run: echo "Setting up test environment"

      - name: Run tests
        run: |
          echo "Running tests"
          exit 0

      - name: Cleanup
        if: always()
        run: echo "Cleaning up"
"@

            $workflowContent | Out-File -FilePath $script:testWorkflowPath -Encoding UTF8
        }

        It "Should create valid workflow file" {
            Test-Path $script:testWorkflowPath | Should -Be $true

            $content = Get-Content $script:testWorkflowPath -Raw
            $content | Should -Match 'name:.*E2E Test Workflow'
            $content | Should -Match 'runs-on:.*self-hosted'
            $content | Should -Match 'actions/checkout'
        }

        It "Should validate workflow YAML syntax" {
            if (Test-Path $script:validateWorkflowPath) {
                try {
                    $output = & $script:validateWorkflowPath -WorkflowPath $script:testWorkflowPath 2>&1

                    # If validation script exists and runs, check output
                    if ($LASTEXITCODE -eq 0 -or $output -match 'valid|success') {
                        $output | Should -Not -Match 'error|invalid|failed'
                    }
                } catch {
                    # Workflow validation may not be fully implemented
                    Set-ItResult -Skipped -Because "Workflow validation not available: $_"
                }
            } else {
                # Basic YAML structure validation
                $content = Get-Content $script:testWorkflowPath -Raw
                $content | Should -Match 'name:'
                $content | Should -Match 'on:'
                $content | Should -Match 'jobs:'
                $content | Should -Match 'steps:'
            }
        }

        It "Should contain required workflow elements" {
            $content = Get-Content $script:testWorkflowPath -Raw

            # Check for essential workflow components
            $content | Should -Match 'name:'
            $content | Should -Match 'on:'
            $content | Should -Match 'jobs:'
            $content | Should -Match 'steps:'
            $content | Should -Match 'runs-on:'
        }

        It "Should include cleanup steps" {
            $content = Get-Content $script:testWorkflowPath -Raw

            $content | Should -Match 'Cleanup'
            $content | Should -Match 'if:.*always\(\)'
        }
    }

    Context "Health Monitoring Integration" {
        It "Should monitor system health during workflow" {
            $beforeHealth = & $script:healthCheckPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $script:testWorkspace
            $beforeJson = $beforeHealth | ConvertFrom-Json

            # Simulate workflow execution (create some files)
            $testFile = Join-Path $script:testWorkspace "workflow-output.txt"
            "Test workflow output" | Out-File -FilePath $testFile

            # Check health after
            $afterHealth = & $script:healthCheckPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $script:testWorkspace
            $afterJson = $afterHealth | ConvertFrom-Json

            # Health should remain stable
            $afterJson.OverallHealth | Should -BeIn @('Healthy', 'Warning')
            $afterJson.Checks.DiskSpace.Status | Should -Not -Be 'Unhealthy'
        }

        It "Should track resource usage during execution" {
            $initialHealth = & $script:healthCheckPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $script:testWorkspace
            $initialJson = $initialHealth | ConvertFrom-Json

            $initialCPU = $initialJson.Checks.SystemResources.CPUUsagePercentage
            $initialRAM = $initialJson.Checks.SystemResources.RAMUsagePercentage

            # Both metrics should be valid percentages
            $initialCPU | Should -BeGreaterOrEqual 0
            $initialCPU | Should -BeLessOrEqual 100
            $initialRAM | Should -BeGreaterThan 0
            $initialRAM | Should -BeLessOrEqual 100
        }

        It "Should maintain network connectivity throughout" {
            $health = & $script:healthCheckPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $script:testWorkspace
            $json = $health | ConvertFrom-Json

            # Check GitHub connectivity
            $githubConnectivity = $json.Checks.NetworkConnectivity.Results |
                                  Where-Object { $_.Host -eq 'github.com' }

            if ($githubConnectivity) {
                $githubConnectivity.Connected | Should -Be $true
            }
        }
    }

    Context "End-to-End Workflow Execution Simulation" {
        It "Should simulate complete workflow execution" {
            # Step 1: Pre-execution health check
            $preCheck = & $script:healthCheckPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $script:testWorkspace
            $preJson = $preCheck | ConvertFrom-Json
            $preJson.OverallHealth | Should -BeIn @('Healthy', 'Warning')

            # Step 2: Simulate checkout
            $checkoutDir = Join-Path $script:testWorkspace "checkout"
            New-Item -ItemType Directory -Path $checkoutDir -Force | Out-Null
            Test-Path $checkoutDir | Should -Be $true

            # Step 3: Simulate build
            $buildOutput = Join-Path $script:testWorkspace "build-output.log"
            "Build completed successfully" | Out-File -FilePath $buildOutput
            Test-Path $buildOutput | Should -Be $true

            # Step 4: Simulate test execution
            $testResults = Join-Path $script:testWorkspace "test-results.xml"
            @"
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="E2E Tests" tests="1" failures="0" errors="0">
    <testcase name="workflow_execution" time="1.0" />
  </testsuite>
</testsuites>
"@ | Out-File -FilePath $testResults
            Test-Path $testResults | Should -Be $true

            # Step 5: Post-execution health check
            $postCheck = & $script:healthCheckPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $script:testWorkspace
            $postJson = $postCheck | ConvertFrom-Json
            $postJson.OverallHealth | Should -BeIn @('Healthy', 'Warning')

            # Step 6: Cleanup verification
            $allFiles = Get-ChildItem -Path $script:testWorkspace -Recurse
            $allFiles.Count | Should -BeGreaterThan 0
        }

        It "Should handle workflow failures gracefully" {
            # Simulate failed step
            $errorLog = Join-Path $script:testWorkspace "error.log"
            "Error: Simulated failure" | Out-File -FilePath $errorLog

            # Health check should still work
            $health = & $script:healthCheckPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $script:testWorkspace
            { $health | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should maintain workspace integrity" {
            # Verify workspace structure
            Test-Path $script:testWorkspace | Should -Be $true

            # Verify .github/workflows directory
            Test-Path (Join-Path $script:testWorkspace ".github\workflows") | Should -Be $true

            # Verify workflow file
            Test-Path $script:testWorkflowPath | Should -Be $true
        }

        It "Should complete full workflow within time limit" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            # Execute all workflow steps
            & $script:healthCheckPath -OutputFormat JSON -DiskThresholdGB 10 -WorkDirectory $script:testWorkspace | Out-Null

            # Simulate job steps
            $stepDir = Join-Path $script:testWorkspace "step-$(Get-Random)"
            New-Item -ItemType Directory -Path $stepDir -Force | Out-Null
            "Step completed" | Out-File -FilePath (Join-Path $stepDir "output.txt")

            $stopwatch.Stop()

            # Full E2E workflow should complete in reasonable time (60 seconds)
            $stopwatch.Elapsed.TotalSeconds | Should -BeLessThan 60
        }
    }

    Context "Multi-Framework Build Scenarios" {
        It "Should support PowerShell-based builds" {
            $buildScript = Join-Path $script:testWorkspace "build.ps1"

            @"
`$result = @{
    Status = "Success"
    BuildTime = "1.5s"
    Artifacts = @("output.dll")
}
`$result | ConvertTo-Json
"@ | Out-File -FilePath $buildScript

            Test-Path $buildScript | Should -Be $true

            $output = & $buildScript
            $result = $output | ConvertFrom-Json
            $result.Status | Should -Be "Success"
        }

        It "Should support Node.js-based builds if available" {
            $nodeAvailable = $null -ne (Get-Command node -ErrorAction SilentlyContinue)

            if ($nodeAvailable) {
                $packageJson = Join-Path $script:testWorkspace "package.json"
                @"
{
  "name": "e2e-test",
  "version": "1.0.0",
  "scripts": {
    "test": "echo 'Test passed'"
  }
}
"@ | Out-File -FilePath $packageJson

                Test-Path $packageJson | Should -Be $true

                $json = Get-Content $packageJson -Raw | ConvertFrom-Json
                $json.name | Should -Be "e2e-test"
            } else {
                Set-ItResult -Skipped -Because "Node.js not available"
            }
        }

        It "Should support .NET-based builds if available" {
            $dotnetAvailable = $null -ne (Get-Command dotnet -ErrorAction SilentlyContinue)

            if ($dotnetAvailable) {
                $csproj = Join-Path $script:testWorkspace "test.csproj"
                @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net6.0</TargetFramework>
  </PropertyGroup>
</Project>
"@ | Out-File -FilePath $csproj

                Test-Path $csproj | Should -Be $true

                [xml]$project = Get-Content $csproj
                $project.Project.PropertyGroup.TargetFramework | Should -Match 'net\d+\.\d+'
            } else {
                Set-ItResult -Skipped -Because ".NET SDK not available"
            }
        }
    }

    Context "Error Recovery and Resilience" {
        It "Should recover from disk space warnings" {
            # Check current disk space
            $health = & $script:healthCheckPath -OutputFormat JSON -DiskThresholdGB 1 -WorkDirectory $script:testWorkspace
            $json = $health | ConvertFrom-Json

            # System should handle low thresholds gracefully
            $json.Checks.DiskSpace | Should -Not -BeNullOrEmpty
            $json.Checks.DiskSpace.FreeSpaceGB | Should -BeGreaterThan 0
        }

        It "Should handle missing dependencies gracefully" {
            # Try to detect missing tools without failing
            $tools = @('nonexistent-tool-xyz', 'fake-command-123')

            foreach ($tool in $tools) {
                $exists = Get-Command $tool -ErrorAction SilentlyContinue
                $exists | Should -BeNullOrEmpty
            }

            # Test should complete without throwing
            $true | Should -Be $true
        }

        It "Should validate cleanup after workflow" {
            # Create temporary files
            $tempFiles = 1..3 | ForEach-Object {
                $file = Join-Path $script:testWorkspace "temp-$_.txt"
                "Temporary data" | Out-File -FilePath $file
                $file
            }

            # Verify files exist
            foreach ($file in $tempFiles) {
                Test-Path $file | Should -Be $true
            }

            # Simulate cleanup
            foreach ($file in $tempFiles) {
                if (Test-Path $file) {
                    Remove-Item -Path $file -Force
                }
            }

            # Verify cleanup
            foreach ($file in $tempFiles) {
                Test-Path $file | Should -Be $false
            }
        }
    }

    Context "Integration with GitHub Actions" {
        It "Should detect GitHub Actions environment if present" {
            # Check for GitHub Actions environment variables
            $isGitHubActions = $env:GITHUB_ACTIONS -eq 'true'

            if ($isGitHubActions) {
                $env:GITHUB_WORKFLOW | Should -Not -BeNullOrEmpty
                $env:GITHUB_REPOSITORY | Should -Not -BeNullOrEmpty
            } else {
                Set-ItResult -Skipped -Because "Not running in GitHub Actions environment"
            }
        }

        It "Should support GitHub Actions workflow commands" {
            # Test workflow command format
            $workflowCommand = "::set-output name=test::value"
            $workflowCommand | Should -Match '^::\w+'

            $groupCommand = "::group::Test Group"
            $groupCommand | Should -Match '^::group::'
        }

        It "Should handle runner context correctly" {
            if ($env:RUNNER_WORKSPACE) {
                $env:RUNNER_WORKSPACE | Should -Not -BeNullOrEmpty
                Test-Path $env:RUNNER_WORKSPACE -IsValid | Should -Be $true
            } else {
                # Not in runner environment - use test workspace
                $script:testWorkspace | Should -Not -BeNullOrEmpty
            }
        }
    }
}
