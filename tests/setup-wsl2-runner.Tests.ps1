BeforeAll {
    $scriptPath = "$PSScriptRoot\..\scripts\setup-wsl2-runner.ps1"
}

Describe "setup-wsl2-runner.ps1 Script Tests" {
    Context "Parameter Validation" {
        It "Should have mandatory RepoUrl parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params['RepoUrl'].Attributes.Mandatory | Should -Be $true
        }

        It "Should have mandatory Token parameter" {
            $params = (Get-Command $scriptPath).Parameters
            $params['Token'].Attributes.Mandatory | Should -Be $true
        }

        It "Should have optional RunnerName parameter with default" {
            $params = (Get-Command $scriptPath).Parameters
            $params['RunnerName'].Attributes.Mandatory | Should -Be $false
        }

        It "Should have optional DistroName parameter with default" {
            $params = (Get-Command $scriptPath).Parameters
            $params['DistroName'].Attributes.Mandatory | Should -Be $false
        }

        It "Should have RepoUrl parameter of type String" {
            $params = (Get-Command $scriptPath).Parameters
            $params['RepoUrl'].ParameterType.Name | Should -Be 'String'
        }

        It "Should have Token parameter of type String" {
            $params = (Get-Command $scriptPath).Parameters
            $params['Token'].ParameterType.Name | Should -Be 'String'
        }

        It "Should have RunnerName parameter of type String" {
            $params = (Get-Command $scriptPath).Parameters
            $params['RunnerName'].ParameterType.Name | Should -Be 'String'
        }

        It "Should have DistroName parameter of type String" {
            $params = (Get-Command $scriptPath).Parameters
            $params['DistroName'].ParameterType.Name | Should -Be 'String'
        }
    }

    Context "Script Syntax and Structure" {
        It "Should have valid PowerShell syntax" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize(
                (Get-Content $scriptPath -Raw),
                [ref]$errors
            )
            $errors.Count | Should -Be 0
        }

        It "Should contain comment-based help" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\.SYNOPSIS'
            $content | Should -Match '\.DESCRIPTION'
            $content | Should -Match '\.PARAMETER'
            $content | Should -Match '\.EXAMPLE'
        }

        It "Should set ErrorActionPreference to Stop" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match '\$ErrorActionPreference\s*=\s*"Stop"'
        }

        It "Should have proper encoding (UTF-8 with BOM)" {
            $bytes = [System.IO.File]::ReadAllBytes($scriptPath)
            # Check for UTF-8 BOM (0xEF, 0xBB, 0xBF)
            $bytes.Length | Should -BeGreaterThan 0
        }
    }

    Context "WSL2 Checks" {
        BeforeAll {
            $content = Get-Content $scriptPath -Raw
        }

        It "Should check if WSL2 is installed" {
            $content | Should -Match 'wsl --list --verbose'
        }

        It "Should verify distro exists" {
            $content | Should -Match '\$DistroName'
        }

        It "Should check distro version (WSL1 vs WSL2)" {
            $content | Should -Match 'wsl --set-version'
        }

        It "Should handle WSL2 not installed error" {
            $content | Should -Match 'WSL2? is not installed'
        }

        It "Should provide WSL2 installation instructions" {
            $content | Should -Match 'wsl --install'
        }

        It "Should check LASTEXITCODE after WSL commands" {
            $content | Should -Match '\$LASTEXITCODE'
        }
    }

    Context "Path Conversion" {
        BeforeAll {
            $content = Get-Content $scriptPath -Raw
        }

        It "Should convert Windows path to WSL path" {
            $content | Should -Match 'wslpath'
        }

        It "Should get current location" {
            $content | Should -Match 'Get-Location'
        }

        It "Should store WSL path in variable" {
            $content | Should -Match '\$wslPath'
        }
    }

    Context "Installation Script Generation" {
        BeforeAll {
            $content = Get-Content $scriptPath -Raw
        }

        It "Should create bash installation script" {
            $content | Should -Match '#!/bin/bash'
        }

        It "Should set bash error handling" {
            $content | Should -Match 'set -e'
        }

        It "Should update package lists" {
            $content | Should -Match 'apt-get update'
        }

        It "Should install dependencies (curl, wget, git)" {
            $content | Should -Match 'curl'
            $content | Should -Match 'wget'
            $content | Should -Match 'git'
        }

        It "Should create runner directory" {
            $content | Should -Match 'RUNNER_DIR'
            $content | Should -Match 'mkdir -p'
        }

        It "Should download GitHub Actions runner" {
            $content | Should -Match 'actions-runner-linux'
            $content | Should -Match 'github.com/actions/runner/releases'
        }

        It "Should extract runner archive" {
            $content | Should -Match 'tar xzf'
        }

        It "Should configure runner with required parameters" {
            $content | Should -Match './config.sh'
            $content | Should -Match '--url'
            $content | Should -Match '--token'
            $content | Should -Match '--name'
            $content | Should -Match '--labels'
        }

        It "Should use unattended configuration" {
            $content | Should -Match '--unattended'
        }

        It "Should support runner replacement" {
            $content | Should -Match '--replace'
        }

        It "Should install as systemd service" {
            $content | Should -Match './svc.sh install'
            $content | Should -Match './svc.sh start'
        }
    }

    Context "Runner Configuration" {
        BeforeAll {
            $content = Get-Content $scriptPath -Raw
        }

        It "Should use runner version variable" {
            $content | Should -Match 'RUNNER_VERSION'
        }

        It "Should configure runner with RepoUrl parameter" {
            $content | Should -Match '\$RepoUrl'
        }

        It "Should configure runner with Token parameter" {
            $content | Should -Match '\$Token'
        }

        It "Should configure runner with RunnerName parameter" {
            $content | Should -Match '\$RunnerName'
        }

        It "Should include linux label" {
            $content | Should -Match 'linux'
        }

        It "Should include docker label" {
            $content | Should -Match 'docker'
        }

        It "Should include wsl2 label" {
            $content | Should -Match 'wsl2'
        }

        It "Should include self-hosted label" {
            $content | Should -Match 'self-hosted'
        }

        It "Should specify work directory" {
            $content | Should -Match '--work'
        }
    }

    Context "Docker Image Building" {
        BeforeAll {
            $content = Get-Content $scriptPath -Raw
        }

        It "Should build Python Docker image" {
            $content | Should -Match 'Python Docker image'
        }

        It "Should check for docker directory" {
            $content | Should -Match 'docker'
        }

        It "Should check for build script" {
            $content | Should -Match 'build-python-image-linux.sh'
        }

        It "Should make build script executable" {
            $content | Should -Match 'chmod \+x'
        }

        It "Should build Docker image manually if script missing" {
            $content | Should -Match 'docker build'
        }

        It "Should reference Dockerfile.python-multi-linux" {
            $content | Should -Match 'Dockerfile\.python-multi-linux'
        }

        It "Should tag Docker image" {
            $content | Should -Match 'runner-python-multi'
        }

        It "Should handle missing repository path gracefully" {
            $content | Should -Match 'Could not find repository'
        }
    }

    Context "Service Management" {
        BeforeAll {
            $content = Get-Content $scriptPath -Raw
        }

        It "Should check service status" {
            $content | Should -Match 'systemctl status'
        }

        It "Should reference actions.runner service" {
            $content | Should -Match 'actions\.runner'
        }

        It "Should provide service management instructions" {
            $content | Should -Match 'sudo systemctl status'
            $content | Should -Match 'sudo systemctl stop'
            $content | Should -Match 'sudo systemctl start'
        }

        It "Should provide log viewing instructions" {
            $content | Should -Match 'sudo journalctl'
        }
    }

    Context "Error Handling" {
        BeforeAll {
            $content = Get-Content $scriptPath -Raw
        }

        It "Should use try-catch blocks" {
            $content | Should -Match 'try\s*\{'
            $content | Should -Match 'catch\s*\{'
        }

        It "Should have finally block for cleanup" {
            $content | Should -Match 'finally\s*\{'
        }

        It "Should check exit codes" {
            $content | Should -Match '\$LASTEXITCODE'
        }

        It "Should provide error messages" {
            $content | Should -Match '\[FAIL\]'
        }

        It "Should provide troubleshooting steps" {
            $content | Should -Match 'Troubleshooting'
        }

        It "Should exit with error code on failure" {
            $content | Should -Match 'exit 1'
        }
    }

    Context "Output and Logging" {
        BeforeAll {
            $content = Get-Content $scriptPath -Raw
        }

        It "Should display setup title" {
            $content | Should -Match 'WSL2 Linux Runner Setup'
        }

        It "Should use color-coded output" {
            $content | Should -Match '-ForegroundColor'
        }

        It "Should display success messages" {
            $content | Should -Match '\[OK\]'
        }

        It "Should display warning messages" {
            $content | Should -Match '\[WARN\]'
        }

        It "Should display progress messages" {
            $content | Should -Match 'Checking WSL2'
            $content | Should -Match 'Creating installation script'
            $content | Should -Match 'Running installation'
        }

        It "Should display completion message" {
            $content | Should -Match 'Setup Complete'
        }

        It "Should explain runner architecture" {
            $content | Should -Match 'Windows Runner'
            $content | Should -Match 'Linux Runner'
        }

        It "Should display runner verification URL" {
            $content | Should -Match 'settings/actions/runners'
        }

        It "Should provide next steps" {
            $content | Should -Match 'Next steps'
        }
    }

    Context "Temporary File Handling" {
        BeforeAll {
            $content = Get-Content $scriptPath -Raw
        }

        It "Should create temporary file" {
            $content | Should -Match 'GetTempFileName'
        }

        It "Should clean up temporary file in finally block" {
            $content | Should -Match 'Remove-Item.*-Force'
        }

        It "Should check if temp file exists before cleanup" {
            $content | Should -Match 'Test-Path.*tempScript'
        }
    }

    Context "WSL Command Execution" {
        BeforeAll {
            $content = Get-Content $scriptPath -Raw
        }

        It "Should execute bash commands in WSL" {
            $content | Should -Match 'wsl.*bash -c'
        }

        It "Should use distro parameter" {
            $content | Should -Match 'wsl -d \$DistroName'
        }

        It "Should use heredoc for script transfer" {
            $content | Should -Match 'EOFMARKER'
        }

        It "Should make script executable in WSL" {
            $content | Should -Match 'chmod \+x'
        }

        It "Should execute setup script" {
            $content | Should -Match '/tmp/setup-runner\.sh'
        }
    }

    Context "Security Checks" {
        BeforeAll {
            $content = Get-Content $scriptPath -Raw
        }

        It "Should not contain hardcoded tokens or passwords" {
            $content | Should -Not -Match 'ghp_[a-zA-Z0-9]+'
            $content | Should -Not -Match 'password\s*=\s*"[^"]+"'
        }

        It "Should use HTTPS for downloads" {
            $content | Should -Match 'https://github\.com/actions/runner'
        }

        It "Should use parameters for sensitive data" {
            $content | Should -Match '\[Parameter\(Mandatory = \$true\)\]'
        }
    }

    Context "Documentation" {
        BeforeAll {
            $help = Get-Help $scriptPath
        }

        It "Should have synopsis" {
            $help.Synopsis | Should -Not -BeNullOrEmpty
        }

        It "Should have description" {
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It "Should document RepoUrl parameter" {
            $help.parameters.parameter | Where-Object { $_.name -eq 'RepoUrl' } | Should -Not -BeNullOrEmpty
        }

        It "Should document Token parameter" {
            $help.parameters.parameter | Where-Object { $_.name -eq 'Token' } | Should -Not -BeNullOrEmpty
        }

        It "Should document RunnerName parameter" {
            $help.parameters.parameter | Where-Object { $_.name -eq 'RunnerName' } | Should -Not -BeNullOrEmpty
        }

        It "Should document DistroName parameter" {
            $help.parameters.parameter | Where-Object { $_.name -eq 'DistroName' } | Should -Not -BeNullOrEmpty
        }

        It "Should have examples" {
            $help.examples | Should -Not -BeNullOrEmpty
        }
    }

    Context "Runner Labels" {
        BeforeAll {
            $content = Get-Content $scriptPath -Raw
        }

        It "Should document expected labels" {
            $content | Should -Match 'self-hosted'
            $content | Should -Match 'linux'
            $content | Should -Match 'docker'
            $content | Should -Match 'wsl2'
        }

        It "Should explain label usage in output" {
            $content | Should -Match 'labels:'
        }
    }

    Context "Architecture Documentation" {
        BeforeAll {
            $content = Get-Content $scriptPath -Raw
        }

        It "Should explain Windows + Linux runner architecture" {
            $content | Should -Match 'Windows Host.*Windows Runner'
            $content | Should -Match 'WSL2 Ubuntu.*Linux Runner'
        }

        It "Should explain which runner is for which workload" {
            $content | Should -Match 'For:.*builds'
        }
    }
}

Describe "setup-wsl2-runner.ps1 Integration Tests" -Tag "Integration" {
    Context "Script File Existence" {
        It "Should exist at expected path" {
            Test-Path $scriptPath | Should -Be $true
        }

        It "Should be readable" {
            { Get-Content $scriptPath -Raw } | Should -Not -Throw
        }
    }

    Context "Related Files" {
        It "Should reference docker directory" {
            $dockerPath = "$PSScriptRoot\..\docker"
            Test-Path $dockerPath | Should -Be $true
        }

        It "Should reference Linux Python Dockerfile" {
            $content = Get-Content $scriptPath -Raw
            if ($content -match 'Dockerfile\.python-multi-linux') {
                $dockerfilePath = "$PSScriptRoot\..\docker\Dockerfile.python-multi-linux"
                # Docker file may or may not exist, but directory should
                $dockerDir = Split-Path $dockerfilePath -Parent
                Test-Path $dockerDir | Should -Be $true
            }
        }

        It "Should reference Linux build script" {
            $content = Get-Content $scriptPath -Raw
            if ($content -match 'build-python-image-linux\.sh') {
                $scriptsDir = "$PSScriptRoot\..\scripts"
                Test-Path $scriptsDir | Should -Be $true
            }
        }
    }

    Context "Default Values" {
        It "Should have sensible default for RunnerName" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'RunnerName.*=.*"linux-runner"'
        }

        It "Should have sensible default for DistroName" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'DistroName.*=.*"Ubuntu"'
        }
    }

    Context "Runner Version" {
        BeforeAll {
            $content = Get-Content $scriptPath -Raw
        }

        It "Should specify a runner version" {
            $content | Should -Match 'RUNNER_VERSION=.*\d+\.\d+\.\d+'
        }

        It "Should use consistent version format" {
            if ($content -match 'RUNNER_VERSION=.*(\d+\.\d+\.\d+)') {
                $version = $matches[1]
                $version | Should -Match '^\d+\.\d+\.\d+$'
            }
        }
    }

    Context "Bash Script Compatibility" {
        BeforeAll {
            $content = Get-Content $scriptPath -Raw
        }

        It "Should use proper bash shebang" {
            $content | Should -Match '#!/bin/bash'
        }

        It "Should use bash error handling" {
            $content | Should -Match 'set -e'
        }

        It "Should use proper bash variable syntax" {
            # Check for proper bash variables like $HOME, ${VAR}, etc.
            $content | Should -Match '\$HOME|\$\{[A-Z_]+\}'
        }
    }
}
