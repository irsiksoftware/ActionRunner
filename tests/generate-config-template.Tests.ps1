#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

BeforeAll {
    $ErrorActionPreference = 'Stop'
    $script:ScriptPath = Join-Path $PSScriptRoot "..\scripts\generate-config-template.ps1"
    $script:TestOutputPath = Join-Path $TestDrive "config-templates"

    # Create test output directory
    New-Item -ItemType Directory -Path $script:TestOutputPath -Force | Out-Null

    # Mock powershell-yaml module if not available
    $script:YamlModuleAvailable = Get-Module -ListAvailable -Name powershell-yaml
}

AfterAll {
    # Cleanup test output directories
    if (Test-Path $script:TestOutputPath) {
        Remove-Item -Path $script:TestOutputPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "generate-config-template.ps1 Script Existence" {
    It "Script file should exist" {
        Test-Path $script:ScriptPath | Should -Be $true
    }

    It "Script should have valid PowerShell syntax" {
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:ScriptPath -Raw), [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It "Script should require PowerShell 5.1 or higher" {
        $content = Get-Content $script:ScriptPath -Raw
        $content | Should -Match '#Requires -Version 5\.1'
    }
}

Describe "generate-config-template.ps1 Parameters" {
    BeforeAll {
        $script:ScriptContent = Get-Content $script:ScriptPath -Raw
    }

    It "Should have TemplateType parameter with ValidateSet" {
        $script:ScriptContent | Should -Match '\[ValidateSet\(''general'',\s*''prod'',\s*''gpu'',\s*''unity'',\s*''dev''\)\]'
    }

    It "Should have OutputPath parameter" {
        $script:ScriptContent | Should -Match '\[string\]\$OutputPath'
    }

    It "Should have Format parameter with ValidateSet" {
        $script:ScriptContent | Should -Match '\[ValidateSet\(''yaml'',\s*''json''\)\]'
    }

    It "Should have Validate switch parameter" {
        $script:ScriptContent | Should -Match '\[switch\]\$Validate'
    }

    It "Should have Interactive switch parameter" {
        $script:ScriptContent | Should -Match '\[switch\]\$Interactive'
    }

    It "Should have Force switch parameter" {
        $script:ScriptContent | Should -Match '\[switch\]\$Force'
    }

    It "Should have default value 'general' for TemplateType" {
        $script:ScriptContent | Should -Match '\$TemplateType\s*=\s*''general'''
    }

    It "Should have default value 'yaml' for Format" {
        $script:ScriptContent | Should -Match '\$Format\s*=\s*''yaml'''
    }
}

Describe "generate-config-template.ps1 Help and Documentation" {
    It "Should have synopsis in help" {
        $help = Get-Help $script:ScriptPath
        $help.Synopsis | Should -Not -BeNullOrEmpty
    }

    It "Should have description in help" {
        $help = Get-Help $script:ScriptPath
        $help.Description | Should -Not -BeNullOrEmpty
    }

    It "Should have examples in help" {
        $help = Get-Help $script:ScriptPath
        $help.Examples | Should -Not -BeNullOrEmpty
        $help.Examples.Example.Count | Should -BeGreaterOrEqual 4
    }

    It "Should document TemplateType parameter" {
        $help = Get-Help $script:ScriptPath
        $help.Parameters.Parameter.Name | Should -Contain "TemplateType"
    }

    It "Should document OutputPath parameter" {
        $help = Get-Help $script:ScriptPath
        $help.Parameters.Parameter.Name | Should -Contain "OutputPath"
    }

    It "Should document Format parameter" {
        $help = Get-Help $script:ScriptPath
        $help.Parameters.Parameter.Name | Should -Contain "Format"
    }

    It "Should document Validate parameter" {
        $help = Get-Help $script:ScriptPath
        $help.Parameters.Parameter.Name | Should -Contain "Validate"
    }

    It "Should document Interactive parameter" {
        $help = Get-Help $script:ScriptPath
        $help.Parameters.Parameter.Name | Should -Contain "Interactive"
    }

    It "Should document Force parameter" {
        $help = Get-Help $script:ScriptPath
        $help.Parameters.Parameter.Name | Should -Contain "Force"
    }
}

Describe "generate-config-template.ps1 Template Generation Functions" {
    BeforeAll {
        $script:ScriptContent = Get-Content $script:ScriptPath -Raw
    }

    It "Should have New-GeneralTemplate function" {
        $script:ScriptContent | Should -Match 'function New-GeneralTemplate'
    }

    It "Should have New-ProductionTemplate function" {
        $script:ScriptContent | Should -Match 'function New-ProductionTemplate'
    }

    It "Should have New-GPUTemplate function" {
        $script:ScriptContent | Should -Match 'function New-GPUTemplate'
    }

    It "Should have New-UnityTemplate function" {
        $script:ScriptContent | Should -Match 'function New-UnityTemplate'
    }

    It "Should have New-DevelopmentTemplate function" {
        $script:ScriptContent | Should -Match 'function New-DevelopmentTemplate'
    }

    It "Should have Test-Template validation function" {
        $script:ScriptContent | Should -Match 'function Test-Template'
    }

    It "Should have Write-TemplateLog logging function" {
        $script:ScriptContent | Should -Match 'function Write-TemplateLog'
    }

    It "Should have Get-ConfigValue interactive input function" {
        $script:ScriptContent | Should -Match 'function Get-ConfigValue'
    }
}

Describe "generate-config-template.ps1 General Template Generation - JSON" {
    BeforeAll {
        $outputFile = Join-Path $script:TestOutputPath "general-test.json"
        $script:GeneralResult = & $script:ScriptPath -TemplateType general -OutputPath $outputFile -Format json -Force *>&1
    }

    It "Should generate JSON file" {
        $outputFile = Join-Path $script:TestOutputPath "general-test.json"
        Test-Path $outputFile | Should -Be $true
    }

    It "Should contain valid JSON" {
        $outputFile = Join-Path $script:TestOutputPath "general-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json | Should -Not -BeNullOrEmpty
    }

    It "Should have runner section" {
        $outputFile = Join-Path $script:TestOutputPath "general-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.runner | Should -Not -BeNullOrEmpty
    }

    It "Should have runner.name" {
        $outputFile = Join-Path $script:TestOutputPath "general-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.runner.name | Should -Be "action-runner-general"
    }

    It "Should have runner.labels" {
        $outputFile = Join-Path $script:TestOutputPath "general-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.runner.labels | Should -Contain "self-hosted"
        $json.runner.labels | Should -Contain "Windows"
        $json.runner.labels | Should -Contain "X64"
        $json.runner.labels | Should -Contain "general"
    }

    It "Should have paths section" {
        $outputFile = Join-Path $script:TestOutputPath "general-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.paths | Should -Not -BeNullOrEmpty
        $json.paths.runner_home | Should -Not -BeNullOrEmpty
        $json.paths.work_directory | Should -Not -BeNullOrEmpty
    }

    It "Should have resources section" {
        $outputFile = Join-Path $script:TestOutputPath "general-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.resources | Should -Not -BeNullOrEmpty
        $json.resources.max_concurrent_jobs | Should -Be 3
    }

    It "Should have timeouts section" {
        $outputFile = Join-Path $script:TestOutputPath "general-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.timeouts | Should -Not -BeNullOrEmpty
        $json.timeouts.job_timeout_minutes | Should -Be 360
    }

    It "Should have environment section" {
        $outputFile = Join-Path $script:TestOutputPath "general-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.environment | Should -Not -BeNullOrEmpty
        $json.environment.system | Should -Not -BeNullOrEmpty
        $json.environment.runner | Should -Not -BeNullOrEmpty
    }

    It "Should have docker section with enabled set to true" {
        $outputFile = Join-Path $script:TestOutputPath "general-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.docker | Should -Not -BeNullOrEmpty
        $json.docker.enabled | Should -Be $true
    }

    It "Should have monitoring section" {
        $outputFile = Join-Path $script:TestOutputPath "general-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.monitoring | Should -Not -BeNullOrEmpty
        $json.monitoring.enabled | Should -Be $true
    }

    It "Should have security section" {
        $outputFile = Join-Path $script:TestOutputPath "general-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.security | Should -Not -BeNullOrEmpty
    }

    It "Should have logging section" {
        $outputFile = Join-Path $script:TestOutputPath "general-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.logging | Should -Not -BeNullOrEmpty
        $json.logging.level | Should -Be "info"
    }

    It "Should have maintenance section" {
        $outputFile = Join-Path $script:TestOutputPath "general-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.maintenance | Should -Not -BeNullOrEmpty
    }

    It "Should have features section" {
        $outputFile = Join-Path $script:TestOutputPath "general-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.features | Should -Not -BeNullOrEmpty
    }
}

Describe "generate-config-template.ps1 Production Template Generation - JSON" {
    BeforeAll {
        $outputFile = Join-Path $script:TestOutputPath "prod-test.json"
        $script:ProdResult = & $script:ScriptPath -TemplateType prod -OutputPath $outputFile -Format json -Force *>&1
    }

    It "Should generate production template" {
        $outputFile = Join-Path $script:TestOutputPath "prod-test.json"
        Test-Path $outputFile | Should -Be $true
    }

    It "Should have production runner name" {
        $outputFile = Join-Path $script:TestOutputPath "prod-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.runner.name | Should -Be "action-runner-prod"
    }

    It "Should have production label" {
        $outputFile = Join-Path $script:TestOutputPath "prod-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.runner.labels | Should -Contain "production"
    }

    It "Should have higher max concurrent jobs than general" {
        $outputFile = Join-Path $script:TestOutputPath "prod-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.resources.max_concurrent_jobs | Should -Be 5
    }

    It "Should have stricter security settings" {
        $outputFile = Join-Path $script:TestOutputPath "prod-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.security.audit_logging | Should -Be $true
        $json.security.enforce_code_signing | Should -Be $true
    }

    It "Should have longer log retention" {
        $outputFile = Join-Path $script:TestOutputPath "prod-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.logging.retention_days | Should -Be 90
    }
}

Describe "generate-config-template.ps1 GPU Template Generation - JSON" {
    BeforeAll {
        $outputFile = Join-Path $script:TestOutputPath "gpu-test.json"
        $script:GpuResult = & $script:ScriptPath -TemplateType gpu -OutputPath $outputFile -Format json -Force *>&1
    }

    It "Should generate GPU template" {
        $outputFile = Join-Path $script:TestOutputPath "gpu-test.json"
        Test-Path $outputFile | Should -Be $true
    }

    It "Should have GPU runner name" {
        $outputFile = Join-Path $script:TestOutputPath "gpu-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.runner.name | Should -Be "action-runner-gpu"
    }

    It "Should have GPU-related labels" {
        $outputFile = Join-Path $script:TestOutputPath "gpu-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.runner.labels | Should -Contain "gpu"
        $json.runner.labels | Should -Contain "cuda"
        $json.runner.labels | Should -Contain "nvidia"
    }

    It "Should have GPU enabled" {
        $outputFile = Join-Path $script:TestOutputPath "gpu-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.gpu.enabled | Should -Be $true
    }

    It "Should have CUDA version configured" {
        $outputFile = Join-Path $script:TestOutputPath "gpu-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.gpu.cuda_version | Should -Not -BeNullOrEmpty
    }

    It "Should have CUDA environment variables" {
        $outputFile = Join-Path $script:TestOutputPath "gpu-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.environment.system.CUDA_PATH | Should -Not -BeNullOrEmpty
    }

    It "Should have max_concurrent_jobs set to 1 for GPU" {
        $outputFile = Join-Path $script:TestOutputPath "gpu-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.resources.max_concurrent_jobs | Should -Be 1
    }
}

Describe "generate-config-template.ps1 Unity Template Generation - JSON" {
    BeforeAll {
        $outputFile = Join-Path $script:TestOutputPath "unity-test.json"
        $script:UnityResult = & $script:ScriptPath -TemplateType unity -OutputPath $outputFile -Format json -Force *>&1
    }

    It "Should generate Unity template" {
        $outputFile = Join-Path $script:TestOutputPath "unity-test.json"
        Test-Path $outputFile | Should -Be $true
    }

    It "Should have Unity runner name" {
        $outputFile = Join-Path $script:TestOutputPath "unity-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.runner.name | Should -Be "action-runner-unity"
    }

    It "Should have Unity-related labels" {
        $outputFile = Join-Path $script:TestOutputPath "unity-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.runner.labels | Should -Contain "unity"
        $json.runner.labels | Should -Contain "game-dev"
    }

    It "Should have Unity enabled" {
        $outputFile = Join-Path $script:TestOutputPath "unity-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.unity.enabled | Should -Be $true
    }

    It "Should have Unity version configured" {
        $outputFile = Join-Path $script:TestOutputPath "unity-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.unity.version | Should -Not -BeNullOrEmpty
    }

    It "Should have Unity build targets" {
        $outputFile = Join-Path $script:TestOutputPath "unity-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.unity.build_targets | Should -Not -BeNullOrEmpty
        $json.unity.build_targets.Count | Should -BeGreaterThan 0
    }

    It "Should have Unity environment variables" {
        $outputFile = Join-Path $script:TestOutputPath "unity-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.environment.system.UNITY_PATH | Should -Not -BeNullOrEmpty
    }
}

Describe "generate-config-template.ps1 Development Template Generation - JSON" {
    BeforeAll {
        $outputFile = Join-Path $script:TestOutputPath "dev-test.json"
        $script:DevResult = & $script:ScriptPath -TemplateType dev -OutputPath $outputFile -Format json -Force *>&1
    }

    It "Should generate development template" {
        $outputFile = Join-Path $script:TestOutputPath "dev-test.json"
        Test-Path $outputFile | Should -Be $true
    }

    It "Should have development runner name" {
        $outputFile = Join-Path $script:TestOutputPath "dev-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.runner.name | Should -Be "action-runner-dev"
    }

    It "Should have development labels" {
        $outputFile = Join-Path $script:TestOutputPath "dev-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.runner.labels | Should -Contain "development"
        $json.runner.labels | Should -Contain "test"
    }

    It "Should have relaxed security settings" {
        $outputFile = Join-Path $script:TestOutputPath "dev-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.security.firewall_enabled | Should -Be $false
        $json.security.audit_logging | Should -Be $false
    }

    It "Should have debug logging level" {
        $outputFile = Join-Path $script:TestOutputPath "dev-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.logging.level | Should -Be "debug"
    }

    It "Should have shorter log retention" {
        $outputFile = Join-Path $script:TestOutputPath "dev-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.logging.retention_days | Should -Be 7
    }

    It "Should have auto_update disabled" {
        $outputFile = Join-Path $script:TestOutputPath "dev-test.json"
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json
        $json.maintenance.auto_update | Should -Be $false
    }
}

Describe "generate-config-template.ps1 YAML Format Output" -Skip:(-not $script:YamlModuleAvailable) {
    BeforeAll {
        $outputFile = Join-Path $script:TestOutputPath "general-test.yaml"
        $script:YamlResult = & $script:ScriptPath -TemplateType general -OutputPath $outputFile -Format yaml -Force *>&1
    }

    It "Should generate YAML file" {
        $outputFile = Join-Path $script:TestOutputPath "general-test.yaml"
        Test-Path $outputFile | Should -Be $true
    }

    It "Should contain YAML header comment" {
        $outputFile = Join-Path $script:TestOutputPath "general-test.yaml"
        $content = Get-Content $outputFile -Raw
        $content | Should -Match "# GitHub Actions Self-Hosted Runner Configuration"
    }

    It "Should contain generated timestamp" {
        $outputFile = Join-Path $script:TestOutputPath "general-test.yaml"
        $content = Get-Content $outputFile -Raw
        $content | Should -Match "# Generated:"
    }

    It "Should contain template type in header" {
        $outputFile = Join-Path $script:TestOutputPath "general-test.yaml"
        $content = Get-Content $outputFile -Raw
        $content | Should -Match "# Template Type: general"
    }

    It "Should contain valid YAML structure" {
        $outputFile = Join-Path $script:TestOutputPath "general-test.yaml"
        $content = Get-Content $outputFile -Raw
        $content | Should -Match "runner:"
        $content | Should -Match "paths:"
        $content | Should -Match "resources:"
    }
}

Describe "generate-config-template.ps1 Template Validation" {
    It "Should validate general template successfully" {
        $outputFile = Join-Path $script:TestOutputPath "validate-general.json"
        { & $script:ScriptPath -TemplateType general -OutputPath $outputFile -Format json -Validate -Force } | Should -Not -Throw
    }

    It "Should validate production template successfully" {
        $outputFile = Join-Path $script:TestOutputPath "validate-prod.json"
        { & $script:ScriptPath -TemplateType prod -OutputPath $outputFile -Format json -Validate -Force } | Should -Not -Throw
    }

    It "Should validate GPU template successfully" {
        $outputFile = Join-Path $script:TestOutputPath "validate-gpu.json"
        { & $script:ScriptPath -TemplateType gpu -OutputPath $outputFile -Format json -Validate -Force } | Should -Not -Throw
    }

    It "Should validate Unity template successfully" {
        $outputFile = Join-Path $script:TestOutputPath "validate-unity.json"
        { & $script:ScriptPath -TemplateType unity -OutputPath $outputFile -Format json -Validate -Force } | Should -Not -Throw
    }

    It "Should validate development template successfully" {
        $outputFile = Join-Path $script:TestOutputPath "validate-dev.json"
        { & $script:ScriptPath -TemplateType dev -OutputPath $outputFile -Format json -Validate -Force } | Should -Not -Throw
    }
}

Describe "generate-config-template.ps1 File Overwrite Protection" {
    BeforeAll {
        $script:OverwriteTestFile = Join-Path $script:TestOutputPath "overwrite-test.json"
        # Create initial file
        & $script:ScriptPath -TemplateType general -OutputPath $script:OverwriteTestFile -Format json -Force *>&1
        $script:InitialContent = Get-Content $script:OverwriteTestFile -Raw
    }

    It "Should create file if it doesn't exist" {
        Test-Path $script:OverwriteTestFile | Should -Be $true
    }

    It "Should overwrite file when Force is specified" {
        & $script:ScriptPath -TemplateType dev -OutputPath $script:OverwriteTestFile -Format json -Force *>&1
        $newContent = Get-Content $script:OverwriteTestFile -Raw | ConvertFrom-Json
        $newContent.runner.name | Should -Be "action-runner-dev"
    }
}

Describe "generate-config-template.ps1 Output Directory Creation" {
    It "Should create output directory if it doesn't exist" {
        $newDir = Join-Path $script:TestOutputPath "new-subdir\nested"
        $outputFile = Join-Path $newDir "test-config.json"

        & $script:ScriptPath -TemplateType general -OutputPath $outputFile -Format json -Force *>&1

        Test-Path $newDir | Should -Be $true
        Test-Path $outputFile | Should -Be $true
    }
}

Describe "generate-config-template.ps1 Default Output Path" {
    It "Should use default output path when not specified" {
        Push-Location $script:TestOutputPath
        try {
            # Create config subdirectory for default path
            New-Item -ItemType Directory -Path "config" -Force | Out-Null

            & $script:ScriptPath -TemplateType general -Format json -Force *>&1

            $defaultFile = "config\runner-config.general.json"
            Test-Path $defaultFile | Should -Be $true
        } finally {
            Pop-Location
        }
    }
}

Describe "generate-config-template.ps1 Error Handling" {
    It "Should handle invalid template type parameter" {
        { & $script:ScriptPath -TemplateType "invalid" -ErrorAction Stop } | Should -Throw
    }

    It "Should handle invalid format parameter" {
        { & $script:ScriptPath -Format "xml" -ErrorAction Stop } | Should -Throw
    }
}

Describe "generate-config-template.ps1 Template Completeness" {
    Context "All templates should have required sections" {
        BeforeAll {
            $script:TemplateTypes = @('general', 'prod', 'gpu', 'unity', 'dev')
            $script:RequiredSections = @('runner', 'paths', 'resources', 'timeouts', 'environment',
                                          'monitoring', 'security', 'logging', 'maintenance')
        }

        It "Template '<_>' should have all required sections" -ForEach $script:TemplateTypes {
            $templateType = $_
            $outputFile = Join-Path $script:TestOutputPath "complete-$templateType.json"
            & $script:ScriptPath -TemplateType $templateType -OutputPath $outputFile -Format json -Force *>&1

            $json = Get-Content $outputFile -Raw | ConvertFrom-Json

            foreach ($section in $script:RequiredSections) {
                $json.PSObject.Properties.Name | Should -Contain $section
            }
        }
    }

    Context "Runner section completeness" {
        BeforeAll {
            $script:TemplateTypes = @('general', 'prod', 'gpu', 'unity', 'dev')
        }

        It "Template '<_>' should have complete runner section" -ForEach $script:TemplateTypes {
            $templateType = $_
            $outputFile = Join-Path $script:TestOutputPath "runner-$templateType.json"
            & $script:ScriptPath -TemplateType $templateType -OutputPath $outputFile -Format json -Force *>&1

            $json = Get-Content $outputFile -Raw | ConvertFrom-Json

            $json.runner.name | Should -Not -BeNullOrEmpty
            $json.runner.labels | Should -Not -BeNullOrEmpty
            $json.runner.labels.Count | Should -BeGreaterThan 0
        }
    }

    Context "Paths section completeness" {
        BeforeAll {
            $script:TemplateTypes = @('general', 'prod', 'gpu', 'unity', 'dev')
        }

        It "Template '<_>' should have complete paths section" -ForEach $script:TemplateTypes {
            $templateType = $_
            $outputFile = Join-Path $script:TestOutputPath "paths-$templateType.json"
            & $script:ScriptPath -TemplateType $templateType -OutputPath $outputFile -Format json -Force *>&1

            $json = Get-Content $outputFile -Raw | ConvertFrom-Json

            $json.paths.runner_home | Should -Not -BeNullOrEmpty
            $json.paths.work_directory | Should -Not -BeNullOrEmpty
            $json.paths.temp_directory | Should -Not -BeNullOrEmpty
            $json.paths.log_directory | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "generate-config-template.ps1 Template Type-Specific Features" {
    It "General template should have balanced settings" {
        $outputFile = Join-Path $script:TestOutputPath "feature-general.json"
        & $script:ScriptPath -TemplateType general -OutputPath $outputFile -Format json -Force *>&1
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json

        $json.resources.max_concurrent_jobs | Should -Be 3
        $json.gpu.enabled | Should -Be $false
        $json.unity.enabled | Should -Be $false
        $json.docker.enabled | Should -Be $true
    }

    It "Production template should have enterprise features" {
        $outputFile = Join-Path $script:TestOutputPath "feature-prod.json"
        & $script:ScriptPath -TemplateType prod -OutputPath $outputFile -Format json -Force *>&1
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json

        $json.monitoring.enabled | Should -Be $true
        $json.security.audit_logging | Should -Be $true
        $json.logging.retention_days | Should -BeGreaterThan 30
    }

    It "GPU template should have GPU-specific configurations" {
        $outputFile = Join-Path $script:TestOutputPath "feature-gpu.json"
        & $script:ScriptPath -TemplateType gpu -OutputPath $outputFile -Format json -Force *>&1
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json

        $json.gpu.enabled | Should -Be $true
        $json.gpu.cuda_version | Should -Not -BeNullOrEmpty
        $json.gpu.vram | Should -Not -BeNullOrEmpty
    }

    It "Unity template should have Unity-specific configurations" {
        $outputFile = Join-Path $script:TestOutputPath "feature-unity.json"
        & $script:ScriptPath -TemplateType unity -OutputPath $outputFile -Format json -Force *>&1
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json

        $json.unity.enabled | Should -Be $true
        $json.unity.version | Should -Not -BeNullOrEmpty
        $json.unity.build_targets | Should -Not -BeNullOrEmpty
    }

    It "Development template should have relaxed settings" {
        $outputFile = Join-Path $script:TestOutputPath "feature-dev.json"
        & $script:ScriptPath -TemplateType dev -OutputPath $outputFile -Format json -Force *>&1
        $json = Get-Content $outputFile -Raw | ConvertFrom-Json

        $json.logging.level | Should -Be "debug"
        $json.security.firewall_enabled | Should -Be $false
        $json.maintenance.auto_update | Should -Be $false
    }
}

Describe "generate-config-template.ps1 Integration Tests" {
    It "Should be callable from any directory" {
        $originalLocation = Get-Location
        Push-Location $env:TEMP
        try {
            $outputFile = Join-Path $script:TestOutputPath "integration-test.json"
            $result = & $script:ScriptPath -TemplateType general -OutputPath $outputFile -Format json -Force *>&1
            Test-Path $outputFile | Should -Be $true
        } finally {
            Pop-Location
        }
    }

    It "Should work with relative paths" {
        Push-Location $script:TestOutputPath
        try {
            $result = & $script:ScriptPath -TemplateType general -OutputPath ".\relative-path-test.json" -Format json -Force *>&1
            Test-Path ".\relative-path-test.json" | Should -Be $true
        } finally {
            Pop-Location
        }
    }
}
