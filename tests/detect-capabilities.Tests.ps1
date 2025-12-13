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
        $script:Content | Should -Match 'verify-android\.ps1'
    }

    It "Checks Flutter capability" {
        $script:Content | Should -Match 'verify-flutter\.ps1'
    }

    It "Checks React Native capability" {
        $script:Content | Should -Match 'verify-reactnative\.ps1'
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

    It "Maps flutter capability to flutter label" {
        $script:Content | Should -Match '-Label "flutter"'
    }

    It "Maps reactnative capability to reactnative label" {
        $script:Content | Should -Match '-Label "reactnative"'
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

        It "verify-android.ps1 should exist" {
            Test-Path (Join-Path $script:ScriptsDir 'verify-android.ps1') | Should -Be $true
        }

        It "verify-nodejs.ps1 should exist" {
            Test-Path (Join-Path $script:ScriptsDir 'verify-nodejs.ps1') | Should -Be $true
        }

        It "verify-flutter.ps1 should exist" {
            Test-Path (Join-Path $script:ScriptsDir 'verify-flutter.ps1') | Should -Be $true
        }

        It "verify-reactnative.ps1 should exist" {
            Test-Path (Join-Path $script:ScriptsDir 'verify-reactnative.ps1') | Should -Be $true
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

Describe "detect-capabilities.ps1 - AI Capability Detection" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    Context "AI capability detection logic" {
        It "Has AI capability detection section" {
            $script:Content | Should -Match 'AI CAPABILITY DETECTION'
        }

        It "Initializes aiDetected flag" {
            $script:Content | Should -Match '\$aiDetected\s*=\s*\$false'
        }

        It "Initializes aiComponents array" {
            $script:Content | Should -Match '\$aiComponents\s*=\s*@\(\)'
        }

        It "Displays AI capability checking message" {
            $script:Content | Should -Match 'Checking AI/LLM capabilities'
        }

        It "Defines AI capabilities array with component metadata" {
            $script:Content | Should -Match '\$aiCapabilities\s*=\s*@\('
        }

        It "Iterates through AI capabilities for detection" {
            $script:Content | Should -Match 'foreach\s*\(\s*\$aiCap\s+in\s+\$aiCapabilities\s*\)'
        }

        It "Sets aiDetected to true when any AI component is found" {
            $script:Content | Should -Match '\$aiDetected\s*=\s*\$true'
        }

        It "Tracks detected AI components" {
            $script:Content | Should -Match '\$aiComponents\s*\+=\s*\$aiCap\.Component'
        }

        It "Adds 'ai' label when AI capability detected" {
            $script:Content | Should -Match 'if\s*\(\s*\$aiDetected\s*\)'
            $script:Content | Should -Match '\$script:Results\.labels\s*\+=\s*"ai"'
        }

        It "Sets capabilities['ai'] to true when detected" {
            $script:Content | Should -Match '\$script:Results\.capabilities\["ai"\]\s*=\s*\$true'
        }

        It "Stores ai_components list in capabilities" {
            $script:Content | Should -Match '\$script:Results\.capabilities\["ai_components"\]\s*=\s*\$aiComponents'
        }

        It "Displays AI detection success message with components" {
            $script:Content | Should -Match 'AI capability detected.*components:'
        }

        It "Displays message when no AI capabilities detected" {
            $script:Content | Should -Match 'No AI capabilities detected'
        }
    }

    Context "AI component verification scripts" {
        It "Checks for OpenAI SDK (verify-openai.ps1)" {
            $script:Content | Should -Match 'verify-openai\.ps1'
        }

        It "Maps OpenAI to 'openai' component" {
            $script:Content | Should -Match 'Component\s*=\s*"openai"'
        }

        It "Checks for LangChain (verify-langchain.ps1)" {
            $script:Content | Should -Match 'verify-langchain\.ps1'
        }

        It "Maps LangChain to 'langchain' component" {
            $script:Content | Should -Match 'Component\s*=\s*"langchain"'
        }

        It "Checks for Embedding Models (verify-embedding-models.ps1)" {
            $script:Content | Should -Match 'verify-embedding-models\.ps1'
        }

        It "Maps Embedding Models to 'embeddings' component" {
            $script:Content | Should -Match 'Component\s*=\s*"embeddings"'
        }

        It "Checks for Pinecone (verify-pinecone.ps1)" {
            $script:Content | Should -Match 'verify-pinecone\.ps1'
        }

        It "Maps Pinecone to 'pinecone' component" {
            $script:Content | Should -Match 'Component\s*=\s*"pinecone"'
        }

        It "Checks for Weaviate (verify-weaviate.ps1)" {
            $script:Content | Should -Match 'verify-weaviate\.ps1'
        }

        It "Maps Weaviate to 'weaviate' component" {
            $script:Content | Should -Match 'Component\s*=\s*"weaviate"'
        }

        It "Checks for vLLM/TGI (verify-vllm-tgi.ps1)" {
            $script:Content | Should -Match 'verify-vllm-tgi\.ps1'
        }

        It "Maps vLLM/TGI to 'vllm-tgi' component" {
            $script:Content | Should -Match 'Component\s*=\s*"vllm-tgi"'
        }
    }

    Context "AI component names" {
        It "Defines 'OpenAI SDK' component name" {
            $script:Content | Should -Match 'Name\s*=\s*"OpenAI SDK"'
        }

        It "Defines 'LangChain' component name" {
            $script:Content | Should -Match 'Name\s*=\s*"LangChain"'
        }

        It "Defines 'Embedding Models' component name" {
            $script:Content | Should -Match 'Name\s*=\s*"Embedding Models"'
        }

        It "Defines 'Pinecone' component name" {
            $script:Content | Should -Match 'Name\s*=\s*"Pinecone"'
        }

        It "Defines 'Weaviate' component name" {
            $script:Content | Should -Match 'Name\s*=\s*"Weaviate"'
        }

        It "Defines 'vLLM/TGI' component name" {
            $script:Content | Should -Match 'Name\s*=\s*"vLLM/TGI"'
        }
    }

    Context "AI label mapping" {
        It "All AI components map to 'ai' label" {
            # Verify each AI capability check specifies -Label "ai"
            $script:Content | Should -Match 'ScriptName.*verify-openai.*Label\s*=\s*"ai"' -Because "OpenAI should use 'ai' label"
        }

        It "Documents ai capability to ai label mapping in header" {
            $script:Content | Should -Match 'ai \(OpenAI/LangChain/embeddings/vector DBs\) capability -> ai label'
        }
    }

    Context "AI verification script files existence" {
        BeforeAll {
            $script:ScriptsDir = Join-Path $PSScriptRoot '..\scripts'
        }

        It "verify-openai.ps1 should exist" {
            Test-Path (Join-Path $script:ScriptsDir 'verify-openai.ps1') | Should -Be $true
        }

        It "verify-langchain.ps1 should exist" {
            Test-Path (Join-Path $script:ScriptsDir 'verify-langchain.ps1') | Should -Be $true
        }

        It "verify-embedding-models.ps1 should exist" {
            Test-Path (Join-Path $script:ScriptsDir 'verify-embedding-models.ps1') | Should -Be $true
        }

        It "verify-pinecone.ps1 should exist" {
            Test-Path (Join-Path $script:ScriptsDir 'verify-pinecone.ps1') | Should -Be $true
        }

        It "verify-weaviate.ps1 should exist" {
            Test-Path (Join-Path $script:ScriptsDir 'verify-weaviate.ps1') | Should -Be $true
        }

        It "verify-vllm-tgi.ps1 should exist" {
            Test-Path (Join-Path $script:ScriptsDir 'verify-vllm-tgi.ps1') | Should -Be $true
        }
    }

    Context "AI capability execution tests" {
        It "Should include ai_components in capabilities when AI detected" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json

            # If AI capability was detected
            if ($json.capabilities.ai -eq $true) {
                $json.capabilities.PSObject.Properties.Name | Should -Contain 'ai_components'
                $json.capabilities.ai_components | Should -Not -BeNullOrEmpty
            }
        }

        It "Should include 'ai' label if any AI component is detected" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json

            # If any AI component is available
            if ($json.capabilities.ai -eq $true) {
                $json.labels | Should -Contain 'ai'
            }
        }

        It "Should not include 'ai' label if no AI components detected" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json

            # If AI is not detected
            if ($json.capabilities.ai -ne $true) {
                $json.labels | Should -Not -Contain 'ai'
            }
        }

        It "AI components should be valid component keys" {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json

            if ($json.capabilities.ai -eq $true) {
                $validComponents = @('openai', 'langchain', 'embeddings', 'pinecone', 'weaviate', 'vllm-tgi')
                foreach ($component in $json.capabilities.ai_components) {
                    $validComponents | Should -Contain $component
                }
            }
        }
    }
}

Describe "detect-capabilities.ps1 - iOS Build Capability Detection" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Checks for iOS build capability (verify-ios-build.ps1)" {
        $script:Content | Should -Match 'verify-ios-build\.ps1'
    }

    It "Maps iOS capability to 'ios' label" {
        $script:Content | Should -Match '-Label "ios"'
    }

    It "Documents ios capability in header" {
        $script:Content | Should -Match 'ios \(Xcode/iOS SDK on macOS\) capability -> ios label'
    }

    It "Sets capabilities['ios'] to true when detected" {
        $script:Content | Should -Match '\$script:Results\.capabilities\["ios"\]\s*=\s*\$true'
    }

    It "verify-ios-build.ps1 should exist" {
        $scriptsDir = Join-Path $PSScriptRoot '..\scripts'
        Test-Path (Join-Path $scriptsDir 'verify-ios-build.ps1') | Should -Be $true
    }

    It "References Issue #192 for iOS capability" {
        $script:Content | Should -Match 'Issue #192'
    }
}
