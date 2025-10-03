BeforeAll {
    $scriptPath = "$PSScriptRoot\..\scripts\setup-docker.ps1"
}

Describe "setup-docker.ps1" {
    Context "Script Structure" {
        It "Should exist" {
            Test-Path $scriptPath | Should -Be $true
        }

        It "Should be a valid PowerShell script" {
            { . $scriptPath -SkipDockerInstall -WhatIf -ErrorAction Stop } | Should -Not -Throw
        }

        It "Should have proper help documentation" {
            $help = Get-Help $scriptPath
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $help.Description | Should -Not -BeNullOrEmpty
        }
    }

    Context "Parameters" {
        It "Should accept SkipDockerInstall parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params.ContainsKey('SkipDockerInstall') | Should -Be $true
            $params['SkipDockerInstall'].ParameterType.Name | Should -Be 'SwitchParameter'
        }

        It "Should accept EnableGPU parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params.ContainsKey('EnableGPU') | Should -Be $true
            $params['EnableGPU'].ParameterType.Name | Should -Be 'SwitchParameter'
        }

        It "Should accept MaxCPUs parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params.ContainsKey('MaxCPUs') | Should -Be $true
            $params['MaxCPUs'].ParameterType.Name | Should -Be 'Int32'
        }

        It "Should accept MaxMemoryGB parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params.ContainsKey('MaxMemoryGB') | Should -Be $true
            $params['MaxMemoryGB'].ParameterType.Name | Should -Be 'Int32'
        }
    }

    Context "Function Definitions" {
        BeforeAll {
            # Load script content to check for functions
            $scriptContent = Get-Content $scriptPath -Raw
        }

        It "Should define Test-WSL2 function" {
            $scriptContent | Should -Match 'function Test-WSL2'
        }

        It "Should define Install-WSL2 function" {
            $scriptContent | Should -Match 'function Install-WSL2'
        }

        It "Should define Install-DockerDesktop function" {
            $scriptContent | Should -Match 'function Install-DockerDesktop'
        }

        It "Should define Configure-Docker function" {
            $scriptContent | Should -Match 'function Configure-Docker'
        }

        It "Should define Setup-GPUSupport function" {
            $scriptContent | Should -Match 'function Setup-GPUSupport'
        }

        It "Should define Build-DockerImages function" {
            $scriptContent | Should -Match 'function Build-DockerImages'
        }
    }

    Context "Docker Image References" {
        BeforeAll {
            $scriptContent = Get-Content $scriptPath -Raw
        }

        It "Should reference Unity Docker image" {
            $scriptContent | Should -Match 'runner-unity'
        }

        It "Should reference Python Docker image" {
            $scriptContent | Should -Match 'runner-python'
        }

        It "Should reference .NET Docker image" {
            $scriptContent | Should -Match 'runner-dotnet'
        }

        It "Should reference GPU Docker image" {
            $scriptContent | Should -Match 'runner-gpu'
        }
    }

    Context "Error Handling" {
        BeforeAll {
            $scriptContent = Get-Content $scriptPath -Raw
        }

        It "Should set ErrorActionPreference to Stop" {
            $scriptContent | Should -Match '\$ErrorActionPreference\s*=\s*[''"]Stop[''"]'
        }

        It "Should have try-catch blocks" {
            $scriptContent | Should -Match 'try\s*\{'
            $scriptContent | Should -Match 'catch\s*\{'
        }

        It "Should check for Administrator privileges" {
            $scriptContent | Should -Match 'WindowsPrincipal|Administrator'
        }
    }

    Context "Output and Logging" {
        BeforeAll {
            $scriptContent = Get-Content $scriptPath -Raw
        }

        It "Should display progress messages" {
            $scriptContent | Should -Match 'Write-Host.*\[.*\]'
        }

        It "Should use color-coded output" {
            $scriptContent | Should -Match '-ForegroundColor'
        }

        It "Should display completion message" {
            $scriptContent | Should -Match 'Complete'
        }
    }
}

Describe "setup-docker.ps1 Integration" -Tag "Integration" {
    Context "Docker Directory Check" {
        It "Should find Docker directory" {
            $dockerPath = "$PSScriptRoot\..\docker"
            Test-Path $dockerPath | Should -Be $true
        }

        It "Should find Dockerfile.unity" {
            $dockerfilePath = "$PSScriptRoot\..\docker\Dockerfile.unity"
            Test-Path $dockerfilePath | Should -Be $true
        }

        It "Should find Dockerfile.python" {
            $dockerfilePath = "$PSScriptRoot\..\docker\Dockerfile.python"
            Test-Path $dockerfilePath | Should -Be $true
        }

        It "Should find Dockerfile.dotnet" {
            $dockerfilePath = "$PSScriptRoot\..\docker\Dockerfile.dotnet"
            Test-Path $dockerfilePath | Should -Be $true
        }

        It "Should find Dockerfile.gpu" {
            $dockerfilePath = "$PSScriptRoot\..\docker\Dockerfile.gpu"
            Test-Path $dockerfilePath | Should -Be $true
        }
    }
}
