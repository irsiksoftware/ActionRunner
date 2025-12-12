#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\detect-capabilities.ps1'
}

Describe "detect-capabilities.ps1 - Script Validation" {
    It "Script file exists" {
        Test-Path $script:ScriptPath | Should -Be $true
    }

    It "Script has valid PowerShell syntax" {
        $parseErrors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize(
            (Get-Content $script:ScriptPath -Raw),
            [ref]$parseErrors
        )
        $parseErrors.Count | Should -Be 0
    }

    It "Script requires PowerShell 5.1 or higher" {
        $content = Get-Content $script:ScriptPath -Raw
        $content | Should -Match '#Requires -Version 5.1'
    }

    It "Script has proper comment-based help" {
        $content = Get-Content $script:ScriptPath -Raw
        $content | Should -Match '\.SYNOPSIS'
        $content | Should -Match '\.DESCRIPTION'
        $content | Should -Match '\.EXAMPLE'
    }

    It "Script references Issue #168" {
        $content = Get-Content $script:ScriptPath -Raw
        $content | Should -Match 'Issue #168'
    }
}

Describe "detect-capabilities.ps1 - Parameter Validation" {
    BeforeAll {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:ScriptPath,
            [ref]$null,
            [ref]$null
        )
        $script:Params = $ast.ParamBlock.Parameters
    }

    It "Has IncludeBase parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'IncludeBase' }
        $param | Should -Not -BeNullOrEmpty
    }

    It "Has JsonOutput switch parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'JsonOutput' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'SwitchParameter'
    }

    It "Has Timeout parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'Timeout' }
        $param | Should -Not -BeNullOrEmpty
    }
}

Describe "detect-capabilities.ps1 - Function Definitions" {
    BeforeAll {
        $script:ScriptContent = Get-Content $script:ScriptPath -Raw
    }

    It "Defines Write-StatusMessage function" {
        $script:ScriptContent | Should -Match 'function Write-StatusMessage'
    }

    It "Defines Test-CapabilityScript function" {
        $script:ScriptContent | Should -Match 'function Test-CapabilityScript'
    }

    It "Defines Test-GpuCapability function" {
        $script:ScriptContent | Should -Match 'function Test-GpuCapability'
    }

    It "Defines Test-PythonCapability function" {
        $script:ScriptContent | Should -Match 'function Test-PythonCapability'
    }
}

Describe "detect-capabilities.ps1 - Capability Detection Coverage" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
        # Import the module to verify capabilities come from centralized source
        $modulePath = Join-Path $PSScriptRoot "..\modules\RunnerLabels.psm1"
        Import-Module $modulePath -Force
    }

    It "Uses centralized RunnerLabels module" {
        $script:Content | Should -Match 'Import-Module.*RunnerLabels\.psm1'
    }

    It "Gets capability mappings from module" {
        $script:Content | Should -Match 'Get-CapabilityMappings'
    }

    It "Checks .NET SDK capability via mapping" {
        $script:Content | Should -Match '\$dotnetMapping\s*='
        $script:Content | Should -Match "CapabilityMappings\['dotnet'\]"
    }

    It "Checks Python capability" {
        $script:Content | Should -Match 'Test-PythonCapability'
    }

    It "Checks Unity capability via mapping" {
        $script:Content | Should -Match '\$unityMapping\s*='
        $script:Content | Should -Match "CapabilityMappings\['unity'\]"
    }

    It "Checks Docker capability via mapping" {
        $script:Content | Should -Match '\$dockerMapping\s*='
        $script:Content | Should -Match "CapabilityMappings\['docker'\]"
    }

    It "Checks Desktop capability via mapping" {
        $script:Content | Should -Match '\$desktopMapping\s*='
        $script:Content | Should -Match "CapabilityMappings\['desktop'\]"
    }

    It "Checks Mobile capability via mapping" {
        $script:Content | Should -Match '\$mobileMapping\s*='
        $script:Content | Should -Match "CapabilityMappings\['mobile'\]"
    }

    It "Checks GPU/CUDA capability" {
        $script:Content | Should -Match 'Test-GpuCapability'
    }

    It "Checks Node.js capability via mapping" {
        $script:Content | Should -Match '\$nodejsMapping\s*='
        $script:Content | Should -Match "CapabilityMappings\['nodejs'\]"
    }

    It "Centralized module contains verify script paths" {
        $mappings = Get-CapabilityMappings
        $mappings['dotnet'].Script | Should -Be 'verify-dotnet.ps1'
        $mappings['unity'].Script | Should -Be 'verify-unity.ps1'
        $mappings['docker'].Script | Should -Be 'verify-docker.ps1'
        $mappings['desktop'].Script | Should -Be 'verify-desktop.ps1'
        $mappings['mobile'].Script | Should -Be 'verify-mobile.ps1'
        $mappings['nodejs'].Script | Should -Be 'verify-nodejs.ps1'
    }
}

Describe "detect-capabilities.ps1 - Label Mapping" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
        # Import the module to verify label mappings
        $modulePath = Join-Path $PSScriptRoot "..\modules\RunnerLabels.psm1"
        Import-Module $modulePath -Force
    }

    It "Uses CapabilityLabels from centralized module" {
        $script:Content | Should -Match 'Get-CapabilityLabels'
    }

    It "Adds dotnet label from CapabilityLabels" {
        $script:Content | Should -Match '\$CapabilityLabels\.DotNet'
    }

    It "Adds python label from CapabilityLabels" {
        $script:Content | Should -Match '\$CapabilityLabels\.Python'
    }

    It "Adds unity label from CapabilityLabels" {
        $script:Content | Should -Match '\$CapabilityLabels\.Unity'
    }

    It "Adds docker label from CapabilityLabels" {
        $script:Content | Should -Match '\$CapabilityLabels\.Docker'
    }

    It "Adds desktop label from CapabilityLabels" {
        $script:Content | Should -Match '\$CapabilityLabels\.Desktop'
    }

    It "Adds mobile label from CapabilityLabels" {
        $script:Content | Should -Match '\$CapabilityLabels\.Mobile'
    }

    It "Adds gpu-cuda label from CapabilityLabels" {
        $script:Content | Should -Match '\$CapabilityLabels\.GpuCuda'
    }

    It "Adds nodejs label from CapabilityLabels" {
        $script:Content | Should -Match '\$CapabilityLabels\.NodeJs'
    }

    It "Centralized module has correct label values" {
        $labels = Get-CapabilityLabels
        $labels.DotNet | Should -Be "dotnet"
        $labels.Python | Should -Be "python"
        $labels.Unity | Should -Be "unity-pool"
        $labels.Docker | Should -Be "docker"
        $labels.Desktop | Should -Be "desktop"
        $labels.Mobile | Should -Be "mobile"
        $labels.GpuCuda | Should -Be "gpu-cuda"
        $labels.NodeJs | Should -Be "nodejs"
    }
}

Describe "detect-capabilities.ps1 - Base Labels" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
        # Import the module to verify base label values
        $modulePath = Join-Path $PSScriptRoot "..\modules\RunnerLabels.psm1"
        Import-Module $modulePath -Force
    }

    It "Uses BaseLabels from centralized module" {
        $script:Content | Should -Match 'Get-BaseLabels'
    }

    It "Uses Get-OSLabel for OS detection" {
        $script:Content | Should -Match 'Get-OSLabel'
    }

    It "Adds self-hosted from BaseLabels" {
        $script:Content | Should -Match '\$BaseLabels\.SelfHosted'
    }

    It "Centralized module has correct base label values" {
        $labels = Get-BaseLabels
        $labels.SelfHosted | Should -Be "self-hosted"
        $labels.Windows | Should -Be "windows"
        $labels.Linux | Should -Be "linux"
        $labels.MacOS | Should -Be "macos"
    }
}

Describe "detect-capabilities.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Uses proper error handling" {
        $script:Content | Should -Match '\$ErrorActionPreference'
    }

    It "Has JSON output support" {
        $script:Content | Should -Match 'ConvertTo-Json'
    }

    It "Returns labels as comma-separated string" {
        $script:Content | Should -Match '-join ","'
    }

    It "Includes timestamp in results" {
        $script:Content | Should -Match 'timestamp'
    }

    It "Tracks capabilities dictionary" {
        $script:Content | Should -Match 'capabilities\s*='
    }

    It "Tracks labels array" {
        $script:Content | Should -Match 'labels\s*=\s*@\(\)'
    }
}

Describe "detect-capabilities.ps1 - Execution Tests" {
    Context "Script execution" {
        It "Should execute without throwing errors" {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include labels array in JSON output" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.labels | Should -Not -BeNullOrEmpty
        }

        It "Should include labelsString in JSON output" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.labelsString | Should -Not -BeNullOrEmpty
        }

        It "Should include capabilities in JSON output" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.PSObject.Properties.Name | Should -Contain 'capabilities'
        }

        It "Should include checks array in JSON output" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.PSObject.Properties.Name | Should -Contain 'checks'
        }

        It "Should include summary in JSON output" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.PSObject.Properties.Name | Should -Contain 'summary'
        }
    }

    Context "Base labels" {
        It "Should include 'self-hosted' label when IncludeBase is true" {
            $output = & $script:ScriptPath -JsonOutput -IncludeBase $true 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.labels | Should -Contain 'self-hosted'
        }

        It "Should include OS label when IncludeBase is true" {
            $output = & $script:ScriptPath -JsonOutput -IncludeBase $true 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            # Should contain one of the OS labels
            ($json.labels -contains 'windows' -or $json.labels -contains 'linux' -or $json.labels -contains 'macos') | Should -Be $true
        }

        It "Should not include 'self-hosted' label when IncludeBase is false" {
            $output = & $script:ScriptPath -JsonOutput -IncludeBase $false 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.labels | Should -Not -Contain 'self-hosted'
        }
    }

    Context "Capability-based labels" {
        BeforeAll {
            # Check what capabilities are available on this system
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $script:DetectionResult = $output | ConvertFrom-Json
        }

        It "Should detect at least one capability on a development machine" {
            $script:DetectionResult.summary.totalLabels | Should -BeGreaterThan 0
        }

        It "Should have consistent labels array and labelsString" {
            $expectedString = $script:DetectionResult.labels -join ','
            $script:DetectionResult.labelsString | Should -Be $expectedString
        }

        It "Labels should only contain valid characters" {
            foreach ($label in $script:DetectionResult.labels) {
                $label | Should -Match '^[a-zA-Z0-9_-]+$'
            }
        }
    }

    Context "Returns labels string (non-JSON mode)" {
        It "Should return a comma-separated string by default" {
            $result = & $script:ScriptPath -IncludeBase $true 2>&1 | Select-Object -Last 1
            $result | Should -Match '^[a-zA-Z0-9_,-]+$'
        }

        It "Returned string should include 'self-hosted'" {
            $result = & $script:ScriptPath -IncludeBase $true 2>&1 | Select-Object -Last 1
            $result | Should -Match 'self-hosted'
        }
    }
}

Describe "detect-capabilities.ps1 - Output Formatting" {
    Context "Console output" {
        It "Should display capability detection header" {
            $output = & $script:ScriptPath *>&1 | Out-String
            $output | Should -Match 'Runner Capability Detection'
        }

        It "Should display detection summary" {
            $output = & $script:ScriptPath *>&1 | Out-String
            $output | Should -Match 'Detection Summary'
        }

        It "Should display detected labels section" {
            $output = & $script:ScriptPath *>&1 | Out-String
            $output | Should -Match 'Detected Labels'
        }
    }
}

Describe "detect-capabilities.ps1 - Integration with verify scripts" {
    BeforeAll {
        $script:ScriptsDir = Join-Path $PSScriptRoot '..\scripts'
    }

    Context "Verify script existence" {
        It "verify-dotnet.ps1 should exist" {
            Test-Path (Join-Path $script:ScriptsDir 'verify-dotnet.ps1') | Should -Be $true
        }

        It "verify-docker.ps1 should exist" {
            Test-Path (Join-Path $script:ScriptsDir 'verify-docker.ps1') | Should -Be $true
        }

        It "verify-unity.ps1 should exist" {
            Test-Path (Join-Path $script:ScriptsDir 'verify-unity.ps1') | Should -Be $true
        }

        It "verify-desktop.ps1 should exist" {
            Test-Path (Join-Path $script:ScriptsDir 'verify-desktop.ps1') | Should -Be $true
        }

        It "verify-mobile.ps1 should exist" {
            Test-Path (Join-Path $script:ScriptsDir 'verify-mobile.ps1') | Should -Be $true
        }

        It "verify-nodejs.ps1 should exist" {
            Test-Path (Join-Path $script:ScriptsDir 'verify-nodejs.ps1') | Should -Be $true
        }
    }
}

Describe "detect-capabilities.ps1 - Security and Best Practices" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Uses ErrorActionPreference" {
        $script:Content | Should -Match '\$ErrorActionPreference\s*='
    }

    It "Uses CmdletBinding attribute" {
        $script:Content | Should -Match '\[CmdletBinding\(\)\]'
    }

    It "Uses SilentlyContinue for optional command checks" {
        $script:Content | Should -Match 'ErrorAction\s+SilentlyContinue'
    }

    It "Has try-catch blocks for error handling" {
        $script:Content | Should -Match 'try\s*\{'
        $script:Content | Should -Match 'catch\s*\{'
    }

    It "Tracks errors in results" {
        $script:Content | Should -Match 'errors\s*=\s*@\(\)'
    }
}

Describe "detect-capabilities.ps1 - GPU Detection" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Checks for nvidia-smi" {
        $script:Content | Should -Match 'nvidia-smi'
    }

    It "Has fallback to PyTorch CUDA check" {
        $script:Content | Should -Match 'torch\.cuda\.is_available'
    }

    It "Queries GPU information" {
        $script:Content | Should -Match 'query-gpu'
    }
}

Describe "detect-capabilities.ps1 - Python Detection" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Checks for python command" {
        $script:Content | Should -Match 'Get-Command python'
    }

    It "Verifies python version" {
        $script:Content | Should -Match 'python --version'
    }
}
