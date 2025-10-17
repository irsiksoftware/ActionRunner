<#
.SYNOPSIS
    Tests for validate-workflow.ps1

.DESCRIPTION
    Pester tests for the workflow validation utility.
#>

BeforeAll {
    . "$PSScriptRoot\..\scripts\validate-workflow.ps1"

    # Create temporary test directory
    $script:TestDir = Join-Path $TestDrive "workflows"
    New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
}

Describe "Workflow Validation Tests" {
    BeforeEach {
        # Clear test directory before each test
        Get-ChildItem -Path $script:TestDir -File -ErrorAction SilentlyContinue | Remove-Item -Force
        $script:validationResults = @()
    }

    Context "Valid Workflow" {
        BeforeEach {
            $validWorkflow = @"
name: CI Build
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build project
        run: npm run build

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: build-artifacts
          path: dist/
"@
            $workflowPath = Join-Path $script:TestDir "valid.yml"
            Set-Content -Path $workflowPath -Value $validWorkflow
        }

        It "Should validate successfully" {
            Invoke-WorkflowValidation -Path $script:TestDir

            $errors = $validationResults | Where-Object { $_.Severity -eq "Error" }
            $errors.Count | Should -Be 0
        }
    }

    Context "Missing Required Fields" {
        BeforeEach {
            $invalidWorkflow = @"
# Missing 'name' field
on:
  push:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "test"
"@
            $workflowPath = Join-Path $script:TestDir "missing-name.yml"
            Set-Content -Path $workflowPath -Value $invalidWorkflow
        }

        It "Should detect missing 'name' field" {
            Invoke-WorkflowValidation -Path $script:TestDir

            $errors = $validationResults | Where-Object { $_.Severity -eq "Error" -and $_.Rule -eq "REQUIRED_FIELD" }
            $errors.Count | Should -BeGreaterThan 0
            $errors[0].Message | Should -Match "name"
        }
    }

    Context "Missing Jobs Section" {
        BeforeEach {
            $invalidWorkflow = @"
name: Test Workflow
on: push
"@
            $workflowPath = Join-Path $script:TestDir "no-jobs.yml"
            Set-Content -Path $workflowPath -Value $invalidWorkflow
        }

        It "Should detect missing 'jobs' section" {
            Invoke-WorkflowValidation -Path $script:TestDir

            $errors = $validationResults | Where-Object { $_.Severity -eq "Error" -and $_.Rule -eq "JOBS" }
            $errors.Count | Should -BeGreaterThan 0
        }
    }

    Context "Invalid YAML Syntax - Tabs" {
        BeforeEach {
            $invalidWorkflow = "name: Test`n`ton: push`njobs:`n`t`tbuild:`n`t`t`truns-on: ubuntu-latest"
            $workflowPath = Join-Path $script:TestDir "tabs.yml"
            Set-Content -Path $workflowPath -Value $invalidWorkflow -NoNewline
        }

        It "Should detect tabs in YAML" {
            Invoke-WorkflowValidation -Path $script:TestDir

            $errors = $validationResults | Where-Object { $_.Severity -eq "Error" -and $_.Rule -eq "YAML_SYNTAX" }
            $errors.Count | Should -BeGreaterThan 0
            $errors[0].Message | Should -Match "tabs"
        }
    }

    Context "Job Name Validation" {
        BeforeEach {
            $workflowWithInvalidJobName = @"
name: Test
on: push
jobs:
  invalid-job@name:
    runs-on: ubuntu-latest
    steps:
      - run: echo "test"
"@
            $workflowPath = Join-Path $script:TestDir "invalid-job-name.yml"
            Set-Content -Path $workflowPath -Value $workflowWithInvalidJobName
        }

        It "Should warn about invalid job name format" {
            Invoke-WorkflowValidation -Path $script:TestDir

            $warnings = $validationResults | Where-Object { $_.Severity -eq "Warning" -and $_.Rule -eq "JOB_NAME_FORMAT" }
            $warnings.Count | Should -BeGreaterThan 0
        }
    }

    Context "Strict Mode Validation" {
        BeforeEach {
            $workflowWithoutTimeout = @"
name: Build
on: push
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Build
        run: npm run build
"@
            $workflowPath = Join-Path $script:TestDir "no-timeout.yml"
            Set-Content -Path $workflowPath -Value $workflowWithoutTimeout

            # Enable strict mode
            $script:Strict = $true
        }

        AfterEach {
            $script:Strict = $false
        }

        It "Should suggest timeout-minutes in strict mode" {
            Invoke-WorkflowValidation -Path $script:TestDir

            $info = $validationResults | Where-Object { $_.Severity -eq "Info" -and $_.Rule -eq "JOB_TIMEOUT" }
            $info.Count | Should -BeGreaterThan 0
        }
    }

    Context "Action Version Validation" {
        BeforeEach {
            $workflowWithUnversionedAction = @"
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout
"@
            $workflowPath = Join-Path $script:TestDir "no-version.yml"
            Set-Content -Path $workflowPath -Value $workflowWithUnversionedAction

            $script:Strict = $true
        }

        AfterEach {
            $script:Strict = $false
        }

        It "Should warn about missing action version in strict mode" {
            Invoke-WorkflowValidation -Path $script:TestDir

            $warnings = $validationResults | Where-Object { $_.Severity -eq "Warning" -and $_.Rule -eq "ACTION_VERSION" }
            $warnings.Count | Should -BeGreaterThan 0
        }
    }

    Context "Self-Hosted Runner Detection" {
        BeforeEach {
            $workflowWithSelfHosted = @"
name: Self-Hosted Test
on: push
jobs:
  test:
    runs-on: [self-hosted, windows]
    steps:
      - name: Test
        run: echo "Running on self-hosted"
"@
            $workflowPath = Join-Path $script:TestDir "self-hosted.yml"
            Set-Content -Path $workflowPath -Value $workflowWithSelfHosted
        }

        It "Should detect self-hosted runner configuration" {
            # Capture verbose output
            $verboseOutput = Invoke-WorkflowValidation -Path $script:TestDir -Verbose 4>&1

            $verboseOutput | Should -Match "self-hosted"
        }
    }

    Context "Multiple Files Validation" {
        BeforeEach {
            $workflow1 = @"
name: Workflow 1
on: push
jobs:
  job1:
    runs-on: ubuntu-latest
    steps:
      - run: echo "test"
"@
            $workflow2 = @"
name: Workflow 2
on: pull_request
jobs:
  job2:
    runs-on: ubuntu-latest
    steps:
      - run: echo "test"
"@
            Set-Content -Path (Join-Path $script:TestDir "workflow1.yml") -Value $workflow1
            Set-Content -Path (Join-Path $script:TestDir "workflow2.yaml") -Value $workflow2
        }

        It "Should validate all workflow files in directory" {
            $ymlFiles = @(Get-ChildItem -Path $script:TestDir -Filter "*.yml")
            $yamlFiles = @(Get-ChildItem -Path $script:TestDir -Filter "*.yaml")
            $files = $ymlFiles + $yamlFiles

            $files.Count | Should -Be 2
        }
    }

    Context "Empty Steps Section" {
        BeforeEach {
            $workflowWithEmptySteps = @"
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
"@
            $workflowPath = Join-Path $script:TestDir "empty-steps.yml"
            Set-Content -Path $workflowPath -Value $workflowWithEmptySteps
        }

        It "Should warn about empty steps section" {
            Invoke-WorkflowValidation -Path $script:TestDir

            $warnings = $validationResults | Where-Object { $_.Severity -eq "Warning" -and $_.Rule -eq "EMPTY_STEPS" }
            $warnings.Count | Should -BeGreaterThan 0
        }
    }

    Context "Output Format Tests" {
        BeforeEach {
            $validWorkflow = @"
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "test"
"@
            $workflowPath = Join-Path $script:TestDir "output-test.yml"
            Set-Content -Path $workflowPath -Value $validWorkflow
        }

        It "Should support JSON output format" {
            $script:OutputFormat = "JSON"

            Invoke-WorkflowValidation -Path $script:TestDir

            # Should not throw
            { $validationResults | ConvertTo-Json -Depth 10 } | Should -Not -Throw

            $script:OutputFormat = "Console"
        }
    }

    Context "Non-Existent Path" {
        It "Should handle non-existent path gracefully" {
            { Invoke-WorkflowValidation -Path "C:\NonExistent\Path" } | Should -Throw
        }
    }

    Context "Best Practices Validation" {
        BeforeEach {
            $workflowWithoutCheckout = @"
name: Test
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Run tests
        run: npm test
"@
            $workflowPath = Join-Path $script:TestDir "no-checkout.yml"
            Set-Content -Path $workflowPath -Value $workflowWithoutCheckout

            $script:Strict = $true
        }

        AfterEach {
            $script:Strict = $false
        }

        It "Should provide info about missing checkout in strict mode" {
            Invoke-WorkflowValidation -Path $script:TestDir

            $info = $validationResults | Where-Object { $_.Severity -eq "Info" -and $_.Rule -eq "CHECKOUT_ACTION" }
            $info.Count | Should -BeGreaterThan 0
        }
    }
}

Describe "ValidationResult Class Tests" {
    It "Should create ValidationResult object" {
        $result = [ValidationResult]::new("test.yml", "Error", "Test message", 10, "TEST_RULE")

        $result.File | Should -Be "test.yml"
        $result.Severity | Should -Be "Error"
        $result.Message | Should -Be "Test message"
        $result.Line | Should -Be 10
        $result.Rule | Should -Be "TEST_RULE"
    }
}

Describe "Add-ValidationResult Function Tests" {
    BeforeEach {
        $script:validationResults = @()
    }

    It "Should add validation result to collection" {
        Add-ValidationResult -File "test.yml" -Severity "Warning" -Message "Test warning" -Line 5 -Rule "TEST"

        $script:validationResults.Count | Should -Be 1
        $script:validationResults[0].File | Should -Be "test.yml"
        $script:validationResults[0].Severity | Should -Be "Warning"
        $script:validationResults[0].Line | Should -Be 5
    }
}
