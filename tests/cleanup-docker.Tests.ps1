BeforeAll {
    $scriptPath = "$PSScriptRoot\..\scripts\cleanup-docker.ps1"
}

Describe "cleanup-docker.ps1" {
    Context "Script Structure" {
        It "Should exist" {
            Test-Path $scriptPath | Should -Be $true
        }

        It "Should be a valid PowerShell script" {
            { . $scriptPath -DryRun -ErrorAction Stop } | Should -Not -Throw
        }

        It "Should have proper help documentation" {
            $help = Get-Help $scriptPath
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $help.Description | Should -Not -BeNullOrEmpty
        }
    }

    Context "Parameters" {
        It "Should accept Force parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params.ContainsKey('Force') | Should -Be $true
            $params['Force'].ParameterType.Name | Should -Be 'SwitchParameter'
        }

        It "Should accept RemoveAllContainers parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params.ContainsKey('RemoveAllContainers') | Should -Be $true
            $params['RemoveAllContainers'].ParameterType.Name | Should -Be 'SwitchParameter'
        }

        It "Should accept RemoveAllImages parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params.ContainsKey('RemoveAllImages') | Should -Be $true
            $params['RemoveAllImages'].ParameterType.Name | Should -Be 'SwitchParameter'
        }

        It "Should accept DryRun parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params.ContainsKey('DryRun') | Should -Be $true
            $params['DryRun'].ParameterType.Name | Should -Be 'SwitchParameter'
        }
    }

    Context "Function Definitions" {
        BeforeAll {
            $scriptContent = Get-Content $scriptPath -Raw
        }

        It "Should define Test-DockerRunning function" {
            $scriptContent | Should -Match 'function Test-DockerRunning'
        }

        It "Should define Remove-StoppedContainers function" {
            $scriptContent | Should -Match 'function Remove-StoppedContainers'
        }

        It "Should define Remove-AllContainers function" {
            $scriptContent | Should -Match 'function Remove-AllContainers'
        }

        It "Should define Remove-DanglingImages function" {
            $scriptContent | Should -Match 'function Remove-DanglingImages'
        }

        It "Should define Remove-UnusedImages function" {
            $scriptContent | Should -Match 'function Remove-UnusedImages'
        }

        It "Should define Remove-UnusedVolumes function" {
            $scriptContent | Should -Match 'function Remove-UnusedVolumes'
        }

        It "Should define Remove-BuildCache function" {
            $scriptContent | Should -Match 'function Remove-BuildCache'
        }

        It "Should define Show-DiskUsage function" {
            $scriptContent | Should -Match 'function Show-DiskUsage'
        }
    }

    Context "Docker Commands" {
        BeforeAll {
            $scriptContent = Get-Content $scriptPath -Raw
        }

        It "Should use docker ps for container listing" {
            $scriptContent | Should -Match 'docker ps'
        }

        It "Should use docker rm for container removal" {
            $scriptContent | Should -Match 'docker rm'
        }

        It "Should use docker rmi for image removal" {
            $scriptContent | Should -Match 'docker rmi'
        }

        It "Should use docker volume for volume management" {
            $scriptContent | Should -Match 'docker volume'
        }

        It "Should use docker builder prune for cache cleanup" {
            $scriptContent | Should -Match 'docker builder prune'
        }

        It "Should use docker system df for disk usage" {
            $scriptContent | Should -Match 'docker system df'
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

        It "Should check if Docker is running" {
            $scriptContent | Should -Match 'Test-DockerRunning'
        }
    }

    Context "Safety Features" {
        BeforeAll {
            $scriptContent = Get-Content $scriptPath -Raw
        }

        It "Should preserve runner-* images when removing images" {
            $scriptContent | Should -Match 'runner-'
        }

        It "Should support dry run mode" {
            $scriptContent | Should -Match '\$DryRun'
        }

        It "Should require Force flag for dangerous operations" {
            $scriptContent | Should -Match '\$Force'
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

        It "Should show disk usage summary" {
            $scriptContent | Should -Match 'Show-DiskUsage'
        }
    }
}
