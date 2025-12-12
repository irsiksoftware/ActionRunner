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

    It "Has GetDefaultLabels switch parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'GetDefaultLabels' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'SwitchParameter'
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
    }

    It "Checks .NET SDK capability" {
        $script:Content | Should -Match 'verify-dotnet\.ps1'
    }

    It "Checks Python capability" {
        $script:Content | Should -Match 'Test-PythonCapability'
    }

    It "Checks Unity capability" {
        $script:Content | Should -Match 'verify-unity\.ps1'
    }

    It "Checks Docker capability" {
        $script:Content | Should -Match 'verify-docker\.ps1'
    }

    It "Checks Desktop capability" {
        $script:Content | Should -Match 'verify-desktop\.ps1'
    }

    It "Checks Mobile capability" {
        $script:Content | Should -Match 'verify-mobile\.ps1'
    }

    It "Checks GPU/CUDA capability" {
        $script:Content | Should -Match 'Test-GpuCapability'
    }

    It "Checks Node.js capability" {
        $script:Content | Should -Match 'verify-nodejs\.ps1'
    }
}

Describe "detect-capabilities.ps1 - Label Mapping" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Maps dotnet capability to dotnet label" {
        $script:Content | Should -Match '-Label "dotnet"'
    }

    It "Maps python capability to python label" {
        $script:Content | Should -Match '"python"'
    }

    It "Maps unity capability to unity-pool label" {
        $script:Content | Should -Match '-Label "unity-pool"'
    }

    It "Maps docker capability to docker label" {
        $script:Content | Should -Match '-Label "docker"'
    }

    It "Maps desktop capability to desktop label" {
        $script:Content | Should -Match '-Label "desktop"'
    }

    It "Maps mobile capability to mobile label" {
        $script:Content | Should -Match '-Label "mobile"'
    }

    It "Maps gpu capability to gpu-cuda label" {
        $script:Content | Should -Match '"gpu-cuda"'
    }

    It "Maps nodejs capability to nodejs label" {
        $script:Content | Should -Match '-Label "nodejs"'
    }
}

Describe "detect-capabilities.ps1 - Base Labels" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Includes self-hosted as base label" {
        $script:Content | Should -Match '"self-hosted"'
    }

    It "Detects Windows OS" {
        $script:Content | Should -Match '"windows"'
    }

    It "Detects Linux OS" {
        $script:Content | Should -Match '"linux"'
    }

    It "Detects macOS" {
        $script:Content | Should -Match '"macos"'
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

Describe "detect-capabilities.ps1 - GetDefaultLabels Parameter" {
    Context "Default labels (single source of truth)" {
        It "Should return default labels without running detection" {
            $result = & $script:ScriptPath -GetDefaultLabels -IncludeBase $true 2>&1 | Select-Object -Last 1
            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match '^[a-zA-Z0-9_,-]+$'
        }

        It "Should include self-hosted in default labels" {
            $result = & $script:ScriptPath -GetDefaultLabels -IncludeBase $true 2>&1 | Select-Object -Last 1
            $result -split ',' | Should -Contain 'self-hosted'
        }

        It "Should include OS label in default labels" {
            $result = & $script:ScriptPath -GetDefaultLabels -IncludeBase $true 2>&1 | Select-Object -Last 1
            $labels = $result -split ','
            ($labels -contains 'windows' -or $labels -contains 'linux' -or $labels -contains 'macos') | Should -Be $true
        }

        It "Should include all capability labels in defaults" {
            $result = & $script:ScriptPath -GetDefaultLabels -IncludeBase $true 2>&1 | Select-Object -Last 1
            $labels = $result -split ','
            $labels | Should -Contain 'dotnet'
            $labels | Should -Contain 'python'
            $labels | Should -Contain 'unity-pool'
            $labels | Should -Contain 'docker'
            $labels | Should -Contain 'desktop'
            $labels | Should -Contain 'mobile'
            $labels | Should -Contain 'gpu-cuda'
            $labels | Should -Contain 'nodejs'
            $labels | Should -Contain 'ai'
        }

        It "Should not include base labels when IncludeBase is false" {
            $result = & $script:ScriptPath -GetDefaultLabels -IncludeBase $false 2>&1 | Select-Object -Last 1
            $labels = $result -split ','
            $labels | Should -Not -Contain 'self-hosted'
            $labels | Should -Not -Contain 'windows'
            $labels | Should -Not -Contain 'linux'
            $labels | Should -Not -Contain 'macos'
        }

        It "Should return JSON when -JsonOutput is specified" {
            $output = & $script:ScriptPath -GetDefaultLabels -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
            $json = $output | ConvertFrom-Json
            $json.PSObject.Properties.Name | Should -Contain 'labels'
            $json.PSObject.Properties.Name | Should -Contain 'labelsString'
        }
    }

    Context "Single source of truth for AllCapabilityLabels" {
        BeforeAll {
            $script:Content = Get-Content $script:ScriptPath -Raw
        }

        It "Should define AllCapabilityLabels array" {
            $script:Content | Should -Match '\$script:AllCapabilityLabels\s*=\s*@\('
        }

        It "AllCapabilityLabels should contain expected capability labels" {
            $script:Content | Should -Match '"dotnet"'
            $script:Content | Should -Match '"python"'
            $script:Content | Should -Match '"unity-pool"'
            $script:Content | Should -Match '"docker"'
            $script:Content | Should -Match '"desktop"'
            $script:Content | Should -Match '"mobile"'
            $script:Content | Should -Match '"gpu-cuda"'
            $script:Content | Should -Match '"nodejs"'
            $script:Content | Should -Match '"ai"'
        }
    }
}
