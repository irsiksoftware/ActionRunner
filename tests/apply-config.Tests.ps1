<#
.SYNOPSIS
    Pester tests for apply-config.ps1 script.

.DESCRIPTION
    Comprehensive validation tests for the configuration management script including:
    - Script existence and structure
    - Parameter validation
    - Configuration parsing
    - Validation logic
    - Backup functionality
    - Configuration application
#>

$script:ApplyConfigScript = Join-Path $PSScriptRoot "..\scripts\apply-config.ps1"
$script:ConfigFile = Join-Path $PSScriptRoot "..\config\runner-config.yaml"

Describe "Apply Config Script Tests" -Tags @("Configuration", "Scripts") {

    Context "Script File Structure" {
        It "Should exist" {
            Test-Path $ApplyConfigScript | Should -Be $true
        }

        It "Should be a PowerShell script" {
            $ApplyConfigScript | Should -Match "\.ps1$"
        }

        It "Should require PowerShell 5.1 or higher" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "#Requires -Version 5\.1"
        }

        It "Should have synopsis in help" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "\.SYNOPSIS"
        }

        It "Should have description in help" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "\.DESCRIPTION"
        }

        It "Should have examples in help" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "\.EXAMPLE"
        }
    }

    Context "Script Parameters" {
        It "Should accept ConfigPath parameter" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "\[Parameter.*\].*\[string\]\`$ConfigPath"
        }

        It "Should accept Validate switch" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "\[switch\]\`$Validate"
        }

        It "Should accept Backup switch" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "\[switch\]\`$Backup"
        }

        It "Should accept Force switch" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "\[switch\]\`$Force"
        }

        It "Should accept DryRun switch" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "\[switch\]\`$DryRun"
        }

        It "Should have default value for ConfigPath" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "\`$ConfigPath\s*=\s*`"config"
        }
    }

    Context "Functions" {
        It "Should define ConvertFrom-Yaml function" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "function ConvertFrom-Yaml"
        }

        It "Should define Write-Log function" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "function Write-Log"
        }

        It "Should define Test-ConfigurationFile function" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "function Test-ConfigurationFile"
        }

        It "Should define Test-ConfigurationStructure function" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "function Test-ConfigurationStructure"
        }

        It "Should define Backup-Configuration function" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "function Backup-Configuration"
        }

        It "Should define Set-EnvironmentVariables function" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "function Set-EnvironmentVariables"
        }

        It "Should define Set-RunnerLabels function" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "function Set-RunnerLabels"
        }

        It "Should define Set-ResourceLimits function" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "function Set-ResourceLimits"
        }

        It "Should define Set-GPUConfiguration function" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "function Set-GPUConfiguration"
        }

        It "Should define Set-DockerConfiguration function" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "function Set-DockerConfiguration"
        }
    }

    Context "Configuration File Validation" {
        It "Should check if configuration file exists" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Test-Path.*ConfigPath"
        }

        It "Should exit with error if file not found" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Configuration file not found"
            $content | Should -Match "exit 1"
        }
    }

    Context "YAML Parsing" {
        It "Should parse YAML content" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "ConvertFrom-Yaml"
        }

        It "Should handle comments" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Skip comments"
        }

        It "Should parse key-value pairs" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "key.*value"
        }

        It "Should handle boolean values" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "true.*false"
        }

        It "Should handle numeric values" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "\[int\]"
        }
    }

    Context "Configuration Structure Validation" {
        It "Should check for required sections" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "requiredSections"
            $content | Should -Match "runner"
            $content | Should -Match "paths"
            $content | Should -Match "resources"
        }

        It "Should validate paths exist" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Test-Path.*runner_home"
        }

        It "Should validate resource limits" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "max_memory_gb"
            $content | Should -Match "TotalVisibleMemorySize"
        }

        It "Should collect errors and warnings" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "\`$errors.*@\(\)"
            $content | Should -Match "\`$warnings.*@\(\)"
        }

        It "Should return false on validation errors" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "if.*errors\.Count.*return.*false"
        }
    }

    Context "Logging" {
        It "Should write logs with timestamp" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Get-Date.*Format"
        }

        It "Should support log levels" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "ValidateSet.*INFO.*WARNING.*ERROR.*SUCCESS"
        }

        It "Should write to console with colors" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Write-Host.*ForegroundColor"
        }

        It "Should write to log file" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Add-Content.*apply-config\.log"
        }

        It "Should create log directory if missing" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "New-Item.*Directory.*logs"
        }
    }

    Context "Backup Functionality" {
        It "Should create backup directory" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "backupDir.*backups"
        }

        It "Should include timestamp in backup filename" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Get-Date.*Format.*yyyy-MM-dd"
        }

        It "Should copy configuration file to backup" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Copy-Item.*ConfigPath.*backupPath"
        }

        It "Should respect Backup parameter" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "if.*Backup.*DryRun"
        }
    }

    Context "Environment Variables" {
        It "Should set environment variables" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "SetEnvironmentVariable"
        }

        It "Should support system variables" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "system.*environment"
        }

        It "Should support runner variables" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "runner.*environment"
        }

        It "Should support custom variables" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "custom.*environment"
        }

        It "Should set at machine level" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Machine"
        }

        It "Should skip if DryRun" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "if.*DryRun.*Would apply environment"
        }
    }

    Context "Runner Labels" {
        It "Should handle runner labels" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Set-RunnerLabels"
        }

        It "Should log labels to be applied" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Labels.*join"
        }

        It "Should note labels are set during registration" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "during runner registration"
        }
    }

    Context "Resource Limits" {
        It "Should apply CPU affinity settings" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "CPU affinity"
        }

        It "Should apply memory limits" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Memory limits"
        }

        It "Should log resource configuration" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Resource limits"
        }
    }

    Context "GPU Configuration" {
        It "Should check if GPU is enabled" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "gpu.*enabled"
        }

        It "Should check for nvidia-smi" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "nvidia-smi"
        }

        It "Should configure CUDA version" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "cuda_version"
        }

        It "Should configure compute mode" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "compute_mode"
        }

        It "Should configure VRAM limits" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "vram.*reserved_vram_gb"
        }

        It "Should skip if DryRun" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "if.*DryRun.*Would configure GPU"
        }
    }

    Context "Docker Configuration" {
        It "Should check if Docker is enabled" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "docker.*enabled"
        }

        It "Should check Docker availability" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "docker info"
        }

        It "Should configure isolation mode" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "isolation_mode"
        }

        It "Should configure container limits" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "container_limits"
        }

        It "Should handle Docker errors gracefully" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Docker.*not running"
        }
    }

    Context "User Confirmation" {
        It "Should prompt for confirmation by default" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Read-Host.*Apply this configuration"
        }

        It "Should skip confirmation with Force parameter" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "if.*not.*Force.*not.*DryRun"
        }

        It "Should allow user to cancel" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Configuration not applied"
        }
    }

    Context "Dry Run Mode" {
        It "Should support dry run mode" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "\[DRY RUN\]"
        }

        It "Should not make changes in dry run" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "if.*DryRun.*Would"
        }

        It "Should show summary after dry run" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Dry Run Complete"
        }
    }

    Context "Validation Mode" {
        It "Should support validation-only mode" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "if.*Validate"
        }

        It "Should exit after validation" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "validation completed.*exit 0"
        }
    }

    Context "Configuration Summary" {
        It "Should display configuration summary" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Configuration Summary"
        }

        It "Should show runner name" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Runner Name"
        }

        It "Should show runner labels" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Runner Labels"
        }

        It "Should show paths" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "Runner Home.*Work Directory"
        }
    }

    Context "Exit Codes" {
        It "Should exit 0 on success" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "exit 0"
        }

        It "Should exit 1 on error" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "exit 1"
        }
    }

    Context "Best Practices" {
        It "Should not contain hardcoded credentials" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Not -Match "password\s*=\s*`"[^`"]+`""
            $content | Should -Not -Match "api[_-]?key\s*=\s*`"[^`"]+`""
        }

        It "Should have error handling" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "try.*catch"
        }

        It "Should use descriptive variable names" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "\`$config"
            $content | Should -Match "\`$backupPath"
        }

        It "Should provide usage examples" {
            $content = Get-Content $ApplyConfigScript -Raw
            $content | Should -Match "\.EXAMPLE"
            $content | Should -Match "apply-config\.ps1"
        }
    }
}

Describe "Configuration File Tests" -Tags @("Configuration", "Files") {

    Context "Main Configuration File" {
        It "Should exist" {
            Test-Path $ConfigFile | Should -Be $true
        }

        It "Should be YAML format" {
            $ConfigFile | Should -Match "\.yaml$"
        }

        It "Should contain runner section" {
            $content = Get-Content $ConfigFile -Raw
            $content | Should -Match "runner:"
        }

        It "Should contain paths section" {
            $content = Get-Content $ConfigFile -Raw
            $content | Should -Match "paths:"
        }

        It "Should contain resources section" {
            $content = Get-Content $ConfigFile -Raw
            $content | Should -Match "resources:"
        }

        It "Should contain environment section" {
            $content = Get-Content $ConfigFile -Raw
            $content | Should -Match "environment:"
        }

        It "Should contain GPU section" {
            $content = Get-Content $ConfigFile -Raw
            $content | Should -Match "gpu:"
        }

        It "Should contain Unity section" {
            $content = Get-Content $ConfigFile -Raw
            $content | Should -Match "unity:"
        }

        It "Should contain Docker section" {
            $content = Get-Content $ConfigFile -Raw
            $content | Should -Match "docker:"
        }

        It "Should contain monitoring section" {
            $content = Get-Content $ConfigFile -Raw
            $content | Should -Match "monitoring:"
        }

        It "Should contain security section" {
            $content = Get-Content $ConfigFile -Raw
            $content | Should -Match "security:"
        }

        It "Should contain logging section" {
            $content = Get-Content $ConfigFile -Raw
            $content | Should -Match "logging:"
        }
    }

    Context "Configuration Templates" {
        It "Should have GPU-focused template" {
            $template = "config\templates\gpu-focused.yaml"
            Test-Path $template | Should -Be $true
        }

        It "Should have Unity-focused template" {
            $template = "config\templates\unity-focused.yaml"
            Test-Path $template | Should -Be $true
        }

        It "Should have general-purpose template" {
            $template = "config\templates\general-purpose.yaml"
            Test-Path $template | Should -Be $true
        }

        It "GPU template should have GPU enabled" {
            $content = Get-Content "config\templates\gpu-focused.yaml" -Raw
            $content | Should -Match "gpu:[\s\S]*enabled:\s*true"
        }

        It "Unity template should have Unity enabled" {
            $content = Get-Content "config\templates\unity-focused.yaml" -Raw
            $content | Should -Match "unity:[\s\S]*enabled:\s*true"
        }
    }
}
