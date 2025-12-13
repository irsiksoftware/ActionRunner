BeforeAll {
    $scriptPath = "$PSScriptRoot\..\scripts\build-python-image.ps1"
}

Describe "build-python-image.ps1" {
    Context "Script Structure" {
        It "Should exist" {
            Test-Path $scriptPath | Should -Be $true
        }

        It "Should be a valid PowerShell script" {
            { . $scriptPath -NoBuild -ErrorAction Stop } | Should -Not -Throw
        }

        It "Should have proper help documentation" {
            $help = Get-Help $scriptPath
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $help.Description | Should -Not -BeNullOrEmpty
        }
    }

    Context "Parameters" {
        It "Should accept Registry parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params.ContainsKey('Registry') | Should -Be $true
            $params['Registry'].ParameterType.Name | Should -Be 'String'
        }

        It "Should accept Tag parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params.ContainsKey('Tag') | Should -Be $true
            $params['Tag'].ParameterType.Name | Should -Be 'String'
        }

        It "Should accept NoBuild parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params.ContainsKey('NoBuild') | Should -Be $true
            $params['NoBuild'].ParameterType.Name | Should -Be 'SwitchParameter'
        }

        It "Should have Registry parameter as not mandatory" {
            $params = (Get-Command $scriptPath).Parameters
            $params['Registry'].Attributes.Mandatory | Should -Be $false
        }

        It "Should have Tag parameter as not mandatory" {
            $params = (Get-Command $scriptPath).Parameters
            $params['Tag'].Attributes.Mandatory | Should -Be $false
        }

        It "Should have NoBuild parameter as not mandatory" {
            $params = (Get-Command $scriptPath).Parameters
            $params['NoBuild'].Attributes.Mandatory | Should -Be $false
        }
    }

    Context "Configuration" {
        BeforeAll {
            $scriptContent = Get-Content $scriptPath -Raw
        }

        It "Should define ImageName variable" {
            $scriptContent | Should -Match '\$ImageName\s*=\s*[''"]runner-python-multi[''"]'
        }

        It "Should define DockerfilePath variable" {
            $scriptContent | Should -Match '\$DockerfilePath'
        }

        It "Should define BuildContext variable" {
            $scriptContent | Should -Match '\$BuildContext'
        }

        It "Should reference Dockerfile.python-multi" {
            $scriptContent | Should -Match 'Dockerfile\.python-multi'
        }
    }

    Context "Docker Operations" {
        BeforeAll {
            $scriptContent = Get-Content $scriptPath -Raw
        }

        It "Should check if Docker is running" {
            $scriptContent | Should -Match 'docker version'
        }

        It "Should build Docker image" {
            $scriptContent | Should -Match 'docker.*build'
        }

        It "Should tag Docker image" {
            $scriptContent | Should -Match 'docker tag'
        }

        It "Should push Docker image" {
            $scriptContent | Should -Match 'docker push'
        }

        It "Should display Docker images" {
            $scriptContent | Should -Match 'docker images'
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

        It "Should check LASTEXITCODE after Docker commands" {
            $scriptContent | Should -Match '\$LASTEXITCODE'
        }

        It "Should handle Docker build failures" {
            $scriptContent | Should -Match 'Docker build failed|Failed to build'
        }

        It "Should handle Docker push failures" {
            $scriptContent | Should -Match 'Docker push failed|Failed to push'
        }
    }

    Context "Output and Logging" {
        BeforeAll {
            $scriptContent = Get-Content $scriptPath -Raw
        }

        It "Should display header message" {
            $scriptContent | Should -Match 'Python Multi-Version Docker Image Builder'
        }

        It "Should use color-coded output" {
            $scriptContent | Should -Match '-ForegroundColor'
        }

        It "Should display completion message" {
            $scriptContent | Should -Match '\[OK\].*complete'
        }

        It "Should display build progress" {
            $scriptContent | Should -Match 'Building image'
        }

        It "Should display test instructions" {
            $scriptContent | Should -Match 'Test the Image'
        }
    }

    Context "Image Naming" {
        BeforeAll {
            $scriptContent = Get-Content $scriptPath -Raw
        }

        It "Should construct FullImageName with registry when provided" {
            $scriptContent | Should -Match '\$FullImageName\s*=\s*"\$\{Registry\}/\$\{ImageName\}:\$\{Tag\}"'
        }

        It "Should construct LocalImageName" {
            $scriptContent | Should -Match '\$LocalImageName'
        }

        It "Should handle image naming without registry" {
            $scriptContent | Should -Match 'if \(\$Registry\)'
        }
    }

    Context "Conditional Logic" {
        BeforeAll {
            $scriptContent = Get-Content $scriptPath -Raw
        }

        It "Should skip build when NoBuild is set" {
            $scriptContent | Should -Match 'if \(-not \$NoBuild\)'
        }

        It "Should only push when Registry is provided" {
            $scriptContent | Should -Match 'if \(\$Registry\)'
        }

        It "Should tag for registry when needed" {
            $scriptContent | Should -Match 'if \(\$Registry -and \(\$LocalImageName -ne \$FullImageName\)\)'
        }
    }

    Context "Usage Examples" {
        BeforeAll {
            $help = Get-Help $scriptPath
        }

        It "Should have at least 3 examples" {
            $help.Examples.Example.Count | Should -BeGreaterOrEqual 3
        }

        It "Should include local build example" {
            $help.Examples.Example[0].Code | Should -Match 'build-python-image\.ps1'
        }

        It "Should include registry push example" {
            $examplesText = ($help.Examples.Example | ForEach-Object { $_.Code }) -join ' '
            $examplesText | Should -Match '-Registry'
        }

        It "Should include tag example" {
            $examplesText = ($help.Examples.Example | ForEach-Object { $_.Code }) -join ' '
            $examplesText | Should -Match '-Tag'
        }
    }
}

Describe "build-python-image.ps1 Integration" -Tag "Integration" {
    Context "Dockerfile Check" {
        It "Should find docker directory" {
            $dockerPath = "$PSScriptRoot\..\docker"
            Test-Path $dockerPath | Should -Be $true
        }

        It "Should find Dockerfile.python-multi" {
            $dockerfilePath = "$PSScriptRoot\..\docker\Dockerfile.python-multi"
            Test-Path $dockerfilePath | Should -Be $true
        }
    }

    Context "Python Versions Referenced" {
        BeforeAll {
            $scriptContent = Get-Content $scriptPath -Raw
        }

        It "Should reference Python 3.10 in test instructions" {
            $scriptContent | Should -Match 'Python310|Python 3\.10'
        }

        It "Should reference multiple Python versions in description" {
            $help = Get-Help $scriptPath
            $description = $help.Description.Text -join ' '
            $description | Should -Match '3\.(9|10|11|12)'
        }
    }
}
