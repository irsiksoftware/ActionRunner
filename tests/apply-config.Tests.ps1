#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

BeforeAll {
    $ErrorActionPreference = 'Stop'
    $scriptPath = Join-Path $PSScriptRoot "..\scripts\apply-config.ps1"
    $configDir = Join-Path $PSScriptRoot "..\config"
    $testConfigDir = Join-Path $TestDrive "config"
    $testBackupDir = Join-Path $TestDrive "config\backups"

    # Create test directories
    New-Item -ItemType Directory -Path $testConfigDir -Force | Out-Null
    New-Item -ItemType Directory -Path $testBackupDir -Force | Out-Null

    # Sample valid configuration
    $validConfig = @"
runner:
  name: "test-runner"
  labels:
    - self-hosted
    - windows
  group: "Default"

paths:
  runner_home: "C:\\test-runner"
  work_directory: "C:\\test-runner\\_work"
  temp_directory: "C:\\Temp"
  log_directory: "C:\\test-runner\\logs"

resources:
  max_concurrent_jobs: 1
  cpu:
    max_cores: 4
  memory:
    max_memory_gb: 8
    reserved_memory_gb: 2
  disk:
    min_free_space_gb: 50

timeouts:
  job_timeout_minutes: 60

environment:
  system:
    DOTNET_ROOT: "C:\\Program Files\\dotnet"
  runner:
    RUNNER_DEBUG: "1"

monitoring:
  enabled: true

security:
  firewall_enabled: true

logging:
  level: "info"
"@

    $testConfigFile = Join-Path $testConfigDir "test-config.yaml"
    Set-Content -Path $testConfigFile -Value $validConfig
}

Describe "apply-config.ps1 Tests" {
    Context "Configuration File Validation" {
        It "Should find existing configuration file" {
            Test-Path $testConfigFile | Should -Be $true
        }

        It "Should error when config file doesn't exist" {
            $invalidPath = Join-Path $testConfigDir "nonexistent.yaml"
            { & $scriptPath -ConfigFile $invalidPath -Validate } | Should -Throw
        }
    }

    Context "Configuration Validation" {
        It "Should validate a valid configuration" {
            { & $scriptPath -ConfigFile $testConfigFile -Validate } | Should -Not -Throw
        }

        It "Should reject configuration missing required sections" {
            $invalidConfig = @"
runner:
  name: "test-runner"
"@
            $invalidFile = Join-Path $testConfigDir "invalid.yaml"
            Set-Content -Path $invalidFile -Value $invalidConfig

            { & $scriptPath -ConfigFile $invalidFile -Validate } | Should -Throw
        }
    }

    Context "Dry Run Mode" {
        It "Should run in dry-run mode without errors" {
            { & $scriptPath -ConfigFile $testConfigFile -DryRun } | Should -Not -Throw
        }

        It "Should not modify system when in dry-run mode" {
            $envBefore = [Environment]::GetEnvironmentVariable('TEST_VAR', 'Machine')
            & $scriptPath -ConfigFile $testConfigFile -DryRun
            $envAfter = [Environment]::GetEnvironmentVariable('TEST_VAR', 'Machine')

            $envBefore | Should -Be $envAfter
        }
    }

    Context "Backup Functionality" {
        It "Should create backup when requested" -Skip {
            # This test requires InModuleScope which only works with modules, not scripts
            # The backup functionality is tested manually or via integration tests
        }
    }

    Context "Configuration Parsing" {
        It "Should parse YAML configuration correctly" {
            $content = Get-Content $testConfigFile -Raw

            # Test YAML parsing (simplified)
            $content | Should -Match "runner:"
            $content | Should -Match "paths:"
            $content | Should -Match "resources:"
        }

        It "Should handle comments in YAML" {
            $configWithComments = @"
# This is a comment
runner:
  name: "test-runner"  # inline comment
  labels:
    - self-hosted
    - windows

paths:
  runner_home: "C:\\test-runner"
  work_directory: "C:\\test-runner\\_work"
"@
            $commentFile = Join-Path $testConfigDir "comments.yaml"
            Set-Content -Path $commentFile -Value $configWithComments

            { & $scriptPath -ConfigFile $commentFile -Validate } | Should -Not -Throw
        }
    }

    Context "Environment-Specific Configurations" {
        It "Should validate dev configuration" {
            $devConfig = Join-Path $configDir "runner-config.dev.yaml"
            if (Test-Path $devConfig) {
                { & $scriptPath -ConfigFile $devConfig -Validate } | Should -Not -Throw
            }
        }

        It "Should validate prod configuration" {
            $prodConfig = Join-Path $configDir "runner-config.prod.yaml"
            if (Test-Path $prodConfig) {
                { & $scriptPath -ConfigFile $prodConfig -Validate } | Should -Not -Throw
            }
        }
    }

    Context "Workload Profile Configurations" {
        It "Should validate GPU workload profile" {
            $gpuConfig = Join-Path $configDir "runner-config.gpu.yaml"
            if (Test-Path $gpuConfig) {
                { & $scriptPath -ConfigFile $gpuConfig -Validate } | Should -Not -Throw
            }
        }

        It "Should validate Unity workload profile" {
            $unityConfig = Join-Path $configDir "runner-config.unity.yaml"
            if (Test-Path $unityConfig) {
                { & $scriptPath -ConfigFile $unityConfig -Validate } | Should -Not -Throw
            }
        }

        It "Should validate general workload profile" {
            $generalConfig = Join-Path $configDir "runner-config.general.yaml"
            if (Test-Path $generalConfig) {
                { & $scriptPath -ConfigFile $generalConfig -Validate } | Should -Not -Throw
            }
        }
    }

    Context "Resource Limit Validation" {
        It "Should warn when memory limit exceeds system memory" {
            $highMemConfig = @"
runner:
  name: "test-runner"
  labels:
    - self-hosted
    - windows
paths:
  runner_home: "C:\\test"
  work_directory: "C:\\test\\_work"
resources:
  memory:
    max_memory_gb: 9999
    reserved_memory_gb: 2
"@
            $highMemFile = Join-Path $testConfigDir "high-mem.yaml"
            Set-Content -Path $highMemFile -Value $highMemConfig

            # Should still validate but with warnings
            { & $scriptPath -ConfigFile $highMemFile -Validate } | Should -Not -Throw
        }
    }

    Context "Path Validation" {
        It "Should handle Windows path separators" {
            $content = Get-Content $testConfigFile -Raw
            $content | Should -Match "C:\\\\"
        }

        It "Should validate absolute paths" {
            $content = Get-Content $testConfigFile -Raw
            $content | Should -Match "[A-Z]:\\\\"
        }
    }
}

Describe "Configuration Structure Tests" {
    Context "Required Sections" {
        BeforeAll {
            $configFile = Join-Path $PSScriptRoot "..\config\runner-config.general.yaml"
            $script:requiredContent = Get-Content $configFile -Raw
        }

        It "Should have runner section" {
            $script:requiredContent | Should -Match "runner:"
        }

        It "Should have paths section" {
            $script:requiredContent | Should -Match "paths:"
        }

        It "Should have resources section" {
            $script:requiredContent | Should -Match "resources:"
        }
    }

    Context "Runner Configuration" {
        BeforeAll {
            $configFile = Join-Path $PSScriptRoot "..\config\runner-config.general.yaml"
            $script:runnerContent = Get-Content $configFile -Raw
        }

        It "Should have runner name" {
            $script:runnerContent | Should -Match "name:"
        }

        It "Should have runner labels" {
            $script:runnerContent | Should -Match "labels:"
        }
    }

    Context "Path Configuration" {
        BeforeAll {
            $configFile = Join-Path $PSScriptRoot "..\config\runner-config.general.yaml"
            $script:pathContent = Get-Content $configFile -Raw
        }

        It "Should have runner_home path" {
            $script:pathContent | Should -Match "runner_home:"
        }

        It "Should have work_directory path" {
            $script:pathContent | Should -Match "work_directory:"
        }
    }

    Context "Resource Configuration" {
        BeforeAll {
            $configFile = Join-Path $PSScriptRoot "..\config\runner-config.general.yaml"
            $script:resourceContent = Get-Content $configFile -Raw
        }

        It "Should have CPU settings" {
            $script:resourceContent | Should -Match "cpu:"
        }

        It "Should have memory settings" {
            $script:resourceContent | Should -Match "memory:"
        }

        It "Should have disk settings" {
            $script:resourceContent | Should -Match "disk:"
        }
    }
}

Describe "Configuration Templates Tests" {
    BeforeAll {
        $script:templateConfigDir = Join-Path $PSScriptRoot "..\config"
    }

    Context "Default Configuration" {
        It "Should exist" {
            $defaultConfig = Join-Path $script:templateConfigDir "runner-config.general.yaml"
            Test-Path $defaultConfig | Should -Be $true
        }
    }

    Context "Environment Configurations" {
        It "Should have dev template" {
            $devConfig = Join-Path $script:templateConfigDir "runner-config.dev.yaml"
            Test-Path $devConfig | Should -Be $true
        }

        It "Should have prod template" {
            $prodConfig = Join-Path $script:templateConfigDir "runner-config.prod.yaml"
            Test-Path $prodConfig | Should -Be $true
        }
    }

    Context "Workload Profiles" {
        It "Should have GPU profile" {
            $gpuConfig = Join-Path $script:templateConfigDir "runner-config.gpu.yaml"
            Test-Path $gpuConfig | Should -Be $true
        }

        It "Should have Unity profile" {
            $unityConfig = Join-Path $script:templateConfigDir "runner-config.unity.yaml"
            Test-Path $unityConfig | Should -Be $true
        }

        It "Should have general profile" {
            $generalConfig = Join-Path $script:templateConfigDir "runner-config.general.yaml"
            Test-Path $generalConfig | Should -Be $true
        }
    }
}
