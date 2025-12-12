#Requires -Version 5.1
#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.0.0" }

<#
.SYNOPSIS
    Pester tests for RunnerLabels module

.DESCRIPTION
    Tests centralized runner label definitions and utility functions
    Created for Issue #185: Runner labels are hardcoded magic strings
#>

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot "..\modules\RunnerLabels.psm1"
    Import-Module $modulePath -Force
}

Describe "RunnerLabels Module" {

    Context "Module Import" {
        It "Should import successfully" {
            Get-Module RunnerLabels | Should -Not -BeNullOrEmpty
        }

        It "Should export required functions" {
            $module = Get-Module RunnerLabels
            $module.ExportedFunctions.Keys | Should -Contain 'Get-BaseLabels'
            $module.ExportedFunctions.Keys | Should -Contain 'Get-CapabilityLabels'
            $module.ExportedFunctions.Keys | Should -Contain 'Get-CapabilityMappings'
            $module.ExportedFunctions.Keys | Should -Contain 'Get-AICapabilityMappings'
            $module.ExportedFunctions.Keys | Should -Contain 'Get-OSLabel'
            $module.ExportedFunctions.Keys | Should -Contain 'Get-AllLabels'
            $module.ExportedFunctions.Keys | Should -Contain 'Test-ValidLabel'
        }
    }

    Context "Get-BaseLabels" {
        It "Should return a hashtable" {
            $labels = Get-BaseLabels
            $labels | Should -BeOfType [hashtable]
        }

        It "Should contain SelfHosted label" {
            $labels = Get-BaseLabels
            $labels.SelfHosted | Should -Be "self-hosted"
        }

        It "Should contain Windows label" {
            $labels = Get-BaseLabels
            $labels.Windows | Should -Be "windows"
        }

        It "Should contain Linux label" {
            $labels = Get-BaseLabels
            $labels.Linux | Should -Be "linux"
        }

        It "Should contain MacOS label" {
            $labels = Get-BaseLabels
            $labels.MacOS | Should -Be "macos"
        }

        It "Should return a clone (not modify original)" {
            $labels = Get-BaseLabels
            $labels.SelfHosted = "modified"
            $labels2 = Get-BaseLabels
            $labels2.SelfHosted | Should -Be "self-hosted"
        }
    }

    Context "Get-CapabilityLabels" {
        It "Should return a hashtable" {
            $labels = Get-CapabilityLabels
            $labels | Should -BeOfType [hashtable]
        }

        It "Should contain DotNet label" {
            $labels = Get-CapabilityLabels
            $labels.DotNet | Should -Be "dotnet"
        }

        It "Should contain Python label" {
            $labels = Get-CapabilityLabels
            $labels.Python | Should -Be "python"
        }

        It "Should contain Unity label" {
            $labels = Get-CapabilityLabels
            $labels.Unity | Should -Be "unity-pool"
        }

        It "Should contain Docker label" {
            $labels = Get-CapabilityLabels
            $labels.Docker | Should -Be "docker"
        }

        It "Should contain Desktop label" {
            $labels = Get-CapabilityLabels
            $labels.Desktop | Should -Be "desktop"
        }

        It "Should contain Mobile label" {
            $labels = Get-CapabilityLabels
            $labels.Mobile | Should -Be "mobile"
        }

        It "Should contain GpuCuda label" {
            $labels = Get-CapabilityLabels
            $labels.GpuCuda | Should -Be "gpu-cuda"
        }

        It "Should contain NodeJs label" {
            $labels = Get-CapabilityLabels
            $labels.NodeJs | Should -Be "nodejs"
        }

        It "Should contain AI label" {
            $labels = Get-CapabilityLabels
            $labels.AI | Should -Be "ai"
        }

        It "Should return a clone (not modify original)" {
            $labels = Get-CapabilityLabels
            $labels.Docker = "modified"
            $labels2 = Get-CapabilityLabels
            $labels2.Docker | Should -Be "docker"
        }
    }

    Context "Get-CapabilityMappings" {
        It "Should return a hashtable" {
            $mappings = Get-CapabilityMappings
            $mappings | Should -BeOfType [hashtable]
        }

        It "Should contain dotnet mapping" {
            $mappings = Get-CapabilityMappings
            $mappings['dotnet'] | Should -Not -BeNullOrEmpty
            $mappings['dotnet'].Name | Should -Be ".NET SDK"
            $mappings['dotnet'].Script | Should -Be "verify-dotnet.ps1"
            $mappings['dotnet'].Label | Should -Be "dotnet"
        }

        It "Should contain unity mapping" {
            $mappings = Get-CapabilityMappings
            $mappings['unity'] | Should -Not -BeNullOrEmpty
            $mappings['unity'].Name | Should -Be "Unity"
            $mappings['unity'].Script | Should -Be "verify-unity.ps1"
            $mappings['unity'].Label | Should -Be "unity-pool"
        }

        It "Should contain docker mapping" {
            $mappings = Get-CapabilityMappings
            $mappings['docker'] | Should -Not -BeNullOrEmpty
            $mappings['docker'].Name | Should -Be "Docker"
            $mappings['docker'].Script | Should -Be "verify-docker.ps1"
            $mappings['docker'].Label | Should -Be "docker"
        }

        It "Should contain nodejs mapping" {
            $mappings = Get-CapabilityMappings
            $mappings['nodejs'] | Should -Not -BeNullOrEmpty
            $mappings['nodejs'].Name | Should -Be "Node.js"
            $mappings['nodejs'].Script | Should -Be "verify-nodejs.ps1"
            $mappings['nodejs'].Label | Should -Be "nodejs"
        }

        It "Should contain gpu mapping" {
            $mappings = Get-CapabilityMappings
            $mappings['gpu'] | Should -Not -BeNullOrEmpty
            $mappings['gpu'].Name | Should -Be "GPU/CUDA"
            $mappings['gpu'].Label | Should -Be "gpu-cuda"
        }

        It "Should return a deep clone (not modify original)" {
            $mappings = Get-CapabilityMappings
            $mappings['dotnet'].Label = "modified"
            $mappings2 = Get-CapabilityMappings
            $mappings2['dotnet'].Label | Should -Be "dotnet"
        }
    }

    Context "Get-AICapabilityMappings" {
        It "Should return a hashtable" {
            $mappings = Get-AICapabilityMappings
            $mappings | Should -BeOfType [hashtable]
        }

        It "Should contain openai mapping" {
            $mappings = Get-AICapabilityMappings
            $mappings['openai'] | Should -Not -BeNullOrEmpty
            $mappings['openai'].Name | Should -Be "OpenAI SDK"
            $mappings['openai'].Script | Should -Be "verify-openai.ps1"
            $mappings['openai'].Label | Should -Be "ai"
        }

        It "Should contain langchain mapping" {
            $mappings = Get-AICapabilityMappings
            $mappings['langchain'] | Should -Not -BeNullOrEmpty
            $mappings['langchain'].Name | Should -Be "LangChain"
            $mappings['langchain'].Script | Should -Be "verify-langchain.ps1"
            $mappings['langchain'].Label | Should -Be "ai"
        }

        It "Should contain embeddings mapping" {
            $mappings = Get-AICapabilityMappings
            $mappings['embeddings'] | Should -Not -BeNullOrEmpty
            $mappings['embeddings'].Script | Should -Be "verify-embedding-models.ps1"
        }

        It "Should contain pinecone mapping" {
            $mappings = Get-AICapabilityMappings
            $mappings['pinecone'] | Should -Not -BeNullOrEmpty
            $mappings['pinecone'].Script | Should -Be "verify-pinecone.ps1"
        }

        It "Should contain weaviate mapping" {
            $mappings = Get-AICapabilityMappings
            $mappings['weaviate'] | Should -Not -BeNullOrEmpty
            $mappings['weaviate'].Script | Should -Be "verify-weaviate.ps1"
        }

        It "Should contain vllm_tgi mapping" {
            $mappings = Get-AICapabilityMappings
            $mappings['vllm_tgi'] | Should -Not -BeNullOrEmpty
            $mappings['vllm_tgi'].Script | Should -Be "verify-vllm-tgi.ps1"
        }

        It "All AI mappings should have the ai label" {
            $mappings = Get-AICapabilityMappings
            foreach ($key in $mappings.Keys) {
                $mappings[$key].Label | Should -Be "ai"
            }
        }
    }

    Context "Get-OSLabel" {
        It "Should return a string" {
            $osLabel = Get-OSLabel
            $osLabel | Should -BeOfType [string]
        }

        It "Should return one of the valid OS labels" {
            $osLabel = Get-OSLabel
            $validLabels = @("windows", "linux", "macos")
            $validLabels | Should -Contain $osLabel
        }

        It "Should return windows on Windows" {
            # This test will only pass on Windows
            if ($IsWindows -or $env:OS -match 'Windows' -or [System.Environment]::OSVersion.Platform -eq 'Win32NT') {
                $osLabel = Get-OSLabel
                $osLabel | Should -Be "windows"
            }
        }
    }

    Context "Get-AllLabels" {
        It "Should return an array" {
            $labels = Get-AllLabels
            $labels | Should -BeOfType [string]
        }

        It "Should contain all base labels" {
            $labels = Get-AllLabels
            $labels | Should -Contain "self-hosted"
            $labels | Should -Contain "windows"
            $labels | Should -Contain "linux"
            $labels | Should -Contain "macos"
        }

        It "Should contain all capability labels" {
            $labels = Get-AllLabels
            $labels | Should -Contain "dotnet"
            $labels | Should -Contain "python"
            $labels | Should -Contain "unity-pool"
            $labels | Should -Contain "docker"
            $labels | Should -Contain "desktop"
            $labels | Should -Contain "mobile"
            $labels | Should -Contain "gpu-cuda"
            $labels | Should -Contain "nodejs"
            $labels | Should -Contain "ai"
        }

        It "Should not contain duplicates" {
            $labels = Get-AllLabels
            $uniqueLabels = $labels | Select-Object -Unique
            $labels.Count | Should -Be $uniqueLabels.Count
        }
    }

    Context "Test-ValidLabel" {
        It "Should return true for valid base labels" {
            Test-ValidLabel -Label "self-hosted" | Should -Be $true
            Test-ValidLabel -Label "windows" | Should -Be $true
            Test-ValidLabel -Label "linux" | Should -Be $true
            Test-ValidLabel -Label "macos" | Should -Be $true
        }

        It "Should return true for valid capability labels" {
            Test-ValidLabel -Label "dotnet" | Should -Be $true
            Test-ValidLabel -Label "python" | Should -Be $true
            Test-ValidLabel -Label "unity-pool" | Should -Be $true
            Test-ValidLabel -Label "docker" | Should -Be $true
            Test-ValidLabel -Label "desktop" | Should -Be $true
            Test-ValidLabel -Label "mobile" | Should -Be $true
            Test-ValidLabel -Label "gpu-cuda" | Should -Be $true
            Test-ValidLabel -Label "nodejs" | Should -Be $true
            Test-ValidLabel -Label "ai" | Should -Be $true
        }

        It "Should return false for invalid labels" {
            Test-ValidLabel -Label "invalid-label" | Should -Be $false
            Test-ValidLabel -Label "not-a-label" | Should -Be $false
            Test-ValidLabel -Label "xyz123" | Should -Be $false
        }
    }

    Context "Label Consistency" {
        It "Capability mappings should use labels from CapabilityLabels" {
            $capLabels = Get-CapabilityLabels
            $mappings = Get-CapabilityMappings

            $mappings['dotnet'].Label | Should -Be $capLabels.DotNet
            $mappings['python'].Label | Should -Be $capLabels.Python
            $mappings['unity'].Label | Should -Be $capLabels.Unity
            $mappings['docker'].Label | Should -Be $capLabels.Docker
            $mappings['desktop'].Label | Should -Be $capLabels.Desktop
            $mappings['mobile'].Label | Should -Be $capLabels.Mobile
            $mappings['gpu'].Label | Should -Be $capLabels.GpuCuda
            $mappings['nodejs'].Label | Should -Be $capLabels.NodeJs
        }

        It "AI capability mappings should all use the AI label" {
            $capLabels = Get-CapabilityLabels
            $aiMappings = Get-AICapabilityMappings

            foreach ($key in $aiMappings.Keys) {
                $aiMappings[$key].Label | Should -Be $capLabels.AI
            }
        }
    }
}

AfterAll {
    Remove-Module RunnerLabels -Force -ErrorAction SilentlyContinue
}
