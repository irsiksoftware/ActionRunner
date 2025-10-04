#Requires -Version 5.1

<#
.SYNOPSIS
    Tests for generate-config-template.ps1 script

.DESCRIPTION
    Pester tests for configuration template generation functionality
#>

BeforeAll {
    $script:scriptPath = "$PSScriptRoot\..\..\scripts\generate-config-template.ps1"
    $script:tempTestDir = "$PSScriptRoot\temp-test-configs"

    # Create temp directory for tests
    if (Test-Path $script:tempTestDir) {
        Remove-Item -Path $script:tempTestDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $script:tempTestDir -Force | Out-Null

    # Mock Install-Module for tests
    Mock Install-Module {}
}

AfterAll {
    # Cleanup temp directory
    if (Test-Path $script:tempTestDir) {
        Remove-Item -Path $script:tempTestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "generate-config-template.ps1" {

    Context "Script Existence and Syntax" {

        It "Should exist" {
            Test-Path $script:scriptPath | Should -Be $true
        }

        It "Should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize(
                (Get-Content -Path $script:scriptPath -Raw),
                [ref]$errors
            )
            $errors.Count | Should -Be 0
        }

        It "Should have CmdletBinding attribute" {
            $content = Get-Content -Path $script:scriptPath -Raw
            $content | Should -Match '\[CmdletBinding\(\)\]'
        }
    }

    Context "Template Generation - General" {

        It "Should generate general template in YAML format" {
            $outputPath = Join-Path $script:tempTestDir "test-general.yaml"

            $result = & $script:scriptPath -TemplateType general -OutputPath $outputPath -Force

            Test-Path $outputPath | Should -Be $true
            $content = Get-Content -Path $outputPath -Raw
            $content | Should -Match "runner:"
            $content | Should -Match "name:"
            $content | Should -Match "paths:"
        }

        It "Should generate general template in JSON format" {
            $outputPath = Join-Path $script:tempTestDir "test-general.json"

            $result = & $script:scriptPath -TemplateType general -OutputPath $outputPath -Format json -Force

            Test-Path $outputPath | Should -Be $true
            $content = Get-Content -Path $outputPath -Raw
            $json = $content | ConvertFrom-Json
            $json.runner | Should -Not -BeNullOrEmpty
            $json.paths | Should -Not -BeNullOrEmpty
            $json.resources | Should -Not -BeNullOrEmpty
        }
    }

    Context "Template Generation - Production" {

        It "Should generate production template" {
            $outputPath = Join-Path $script:tempTestDir "test-prod.yaml"

            $result = & $script:scriptPath -TemplateType prod -OutputPath $outputPath -Force

            Test-Path $outputPath | Should -Be $true
            $content = Get-Content -Path $outputPath -Raw
            $content | Should -Match "production"
        }

        It "Should have production-specific settings" {
            $outputPath = Join-Path $script:tempTestDir "test-prod.json"

            $result = & $script:scriptPath -TemplateType prod -OutputPath $outputPath -Format json -Force

            $content = Get-Content -Path $outputPath -Raw
            $json = $content | ConvertFrom-Json
            $json.security | Should -Not -BeNullOrEmpty
            $json.monitoring.enabled | Should -Be $true
        }
    }

    Context "Template Generation - GPU" {

        It "Should generate GPU template" {
            $outputPath = Join-Path $script:tempTestDir "test-gpu.yaml"

            $result = & $script:scriptPath -TemplateType gpu -OutputPath $outputPath -Force

            Test-Path $outputPath | Should -Be $true
            $content = Get-Content -Path $outputPath -Raw
            $content | Should -Match "gpu"
            $content | Should -Match "cuda"
        }

        It "Should have GPU-specific settings" {
            $outputPath = Join-Path $script:tempTestDir "test-gpu.json"

            $result = & $script:scriptPath -TemplateType gpu -OutputPath $outputPath -Format json -Force

            $content = Get-Content -Path $outputPath -Raw
            $json = $content | ConvertFrom-Json
            $json.gpu.enabled | Should -Be $true
            $json.gpu.cuda_version | Should -Not -BeNullOrEmpty
        }
    }

    Context "Template Generation - Unity" {

        It "Should generate Unity template" {
            $outputPath = Join-Path $script:tempTestDir "test-unity.yaml"

            $result = & $script:scriptPath -TemplateType unity -OutputPath $outputPath -Force

            Test-Path $outputPath | Should -Be $true
            $content = Get-Content -Path $outputPath -Raw
            $content | Should -Match "unity"
        }

        It "Should have Unity-specific settings" {
            $outputPath = Join-Path $script:tempTestDir "test-unity.json"

            $result = & $script:scriptPath -TemplateType unity -OutputPath $outputPath -Format json -Force

            $content = Get-Content -Path $outputPath -Raw
            $json = $content | ConvertFrom-Json
            $json.unity.enabled | Should -Be $true
            $json.unity.version | Should -Not -BeNullOrEmpty
        }
    }

    Context "Template Generation - Development" {

        It "Should generate development template" {
            $outputPath = Join-Path $script:tempTestDir "test-dev.yaml"

            $result = & $script:scriptPath -TemplateType dev -OutputPath $outputPath -Force

            Test-Path $outputPath | Should -Be $true
            $content = Get-Content -Path $outputPath -Raw
            $content | Should -Match "development"
        }

        It "Should have development-specific settings" {
            $outputPath = Join-Path $script:tempTestDir "test-dev.json"

            $result = & $script:scriptPath -TemplateType dev -OutputPath $outputPath -Format json -Force

            $content = Get-Content -Path $outputPath -Raw
            $json = $content | ConvertFrom-Json
            $json.logging.level | Should -Be "debug"
            $json.maintenance.auto_update | Should -Be $false
        }
    }

    Context "Template Validation" {

        It "Should validate generated templates" {
            $outputPath = Join-Path $script:tempTestDir "test-validate.yaml"

            $result = & $script:scriptPath -TemplateType general -OutputPath $outputPath -Validate -Force

            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "File Handling" {

        It "Should create output directory if it doesn't exist" {
            $newDir = Join-Path $script:tempTestDir "new-subdir"
            $outputPath = Join-Path $newDir "test-config.yaml"

            $result = & $script:scriptPath -TemplateType general -OutputPath $outputPath -Force

            Test-Path $newDir | Should -Be $true
            Test-Path $outputPath | Should -Be $true
        }

        It "Should use default output path when not specified" {
            # This test would need to be run in the project root or mocked
            # Skipping for now as it modifies the actual config directory
        }
    }

    Context "Required Template Sections" {

        It "Should include all required sections in generated template" {
            $outputPath = Join-Path $script:tempTestDir "test-sections.json"

            $result = & $script:scriptPath -TemplateType general -OutputPath $outputPath -Format json -Force

            $content = Get-Content -Path $outputPath -Raw
            $json = $content | ConvertFrom-Json

            # Check for all required sections
            $json.runner | Should -Not -BeNullOrEmpty
            $json.paths | Should -Not -BeNullOrEmpty
            $json.resources | Should -Not -BeNullOrEmpty
            $json.timeouts | Should -Not -BeNullOrEmpty
            $json.environment | Should -Not -BeNullOrEmpty
            $json.monitoring | Should -Not -BeNullOrEmpty
            $json.security | Should -Not -BeNullOrEmpty
            $json.logging | Should -Not -BeNullOrEmpty
            $json.maintenance | Should -Not -BeNullOrEmpty
        }

        It "Should include runner name and labels" {
            $outputPath = Join-Path $script:tempTestDir "test-runner.json"

            $result = & $script:scriptPath -TemplateType general -OutputPath $outputPath -Format json -Force

            $content = Get-Content -Path $outputPath -Raw
            $json = $content | ConvertFrom-Json

            $json.runner.name | Should -Not -BeNullOrEmpty
            $json.runner.labels | Should -Not -BeNullOrEmpty
            $json.runner.labels.Count | Should -BeGreaterThan 0
        }
    }

    Context "Format Validation" {

        It "Should generate valid YAML format" {
            $outputPath = Join-Path $script:tempTestDir "test-yaml-valid.yaml"

            $result = & $script:scriptPath -TemplateType general -OutputPath $outputPath -Force

            # Check that file can be read as YAML (basic syntax check)
            $content = Get-Content -Path $outputPath -Raw
            $content | Should -Match "^\s*#"  # Should start with comment
            $content | Should -Match "runner:\s*$"
        }

        It "Should generate valid JSON format" {
            $outputPath = Join-Path $script:tempTestDir "test-json-valid.json"

            $result = & $script:scriptPath -TemplateType general -OutputPath $outputPath -Format json -Force

            # Check that file can be parsed as JSON
            $content = Get-Content -Path $outputPath -Raw
            { $content | ConvertFrom-Json } | Should -Not -Throw
        }
    }

    Context "Error Handling" {

        It "Should handle invalid output path gracefully" {
            $invalidPath = "Z:\NonExistent\Path\config.yaml"

            # This should fail but not crash
            { & $script:scriptPath -TemplateType general -OutputPath $invalidPath -Force -ErrorAction Stop } | Should -Throw
        }
    }
}
