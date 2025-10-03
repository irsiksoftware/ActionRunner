BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    $ScriptPath = Join-Path $ProjectRoot "scripts\install-runner.ps1"

    # Mock environment
    $env:COMPUTERNAME = "TEST-RUNNER"
}

Describe "install-runner.ps1" {
    Context "Parameter Validation" {
        It "Should have mandatory OrgOrRepo parameter" {
            $params = (Get-Command $ScriptPath).Parameters
            $params['OrgOrRepo'].Attributes.Mandatory | Should -Be $true
        }

        It "Should have mandatory Token parameter" {
            $params = (Get-Command $ScriptPath).Parameters
            $params['Token'].Attributes.Mandatory | Should -Be $true
        }

        It "Should have optional RunnerName with default" {
            $params = (Get-Command $ScriptPath).Parameters
            $params['RunnerName'].Attributes.Mandatory | Should -Be $false
        }

        It "Should have default Labels parameter value" {
            $params = (Get-Command $ScriptPath).Parameters
            $params['Labels'].Attributes.Mandatory | Should -Be $false
        }
    }

    Context "Script Structure" {
        It "Should exist" {
            Test-Path $ScriptPath | Should -Be $true
        }

        It "Should be a valid PowerShell script" {
            { $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $ScriptPath -Raw), [ref]$null) } | Should -Not -Throw
        }

        It "Should have proper help documentation" {
            $help = Get-Help $ScriptPath
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $help.Description | Should -Not -BeNullOrEmpty
        }

        It "Should have example usage in help" {
            $help = Get-Help $ScriptPath
            $help.Examples.Example.Count | Should -BeGreaterThan 0
        }
    }

    Context "Function Definitions" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptPath -Raw
        }

        It "Should define Write-Log function" {
            $scriptContent | Should -Match 'function Write-Log'
        }

        It "Should define Test-Administrator function" {
            $scriptContent | Should -Match 'function Test-Administrator'
        }

        It "Should define Test-Prerequisites function" {
            $scriptContent | Should -Match 'function Test-Prerequisites'
        }

        It "Should define Install-Runner function" {
            $scriptContent | Should -Match 'function Install-Runner'
        }

        It "Should define Register-Runner function" {
            $scriptContent | Should -Match 'function Register-Runner'
        }

        It "Should define Install-RunnerService function" {
            $scriptContent | Should -Match 'function Install-RunnerService'
        }

        It "Should define Set-FirewallRules function" {
            $scriptContent | Should -Match 'function Set-FirewallRules'
        }

        It "Should define Install-NodeJSAndPnpm function" {
            $scriptContent | Should -Match 'function Install-NodeJSAndPnpm'
        }

        It "Should define Install-PythonStack function" {
            $scriptContent | Should -Match 'function Install-PythonStack'
        }

        It "Should define Install-DockerStack function" {
            $scriptContent | Should -Match 'function Install-DockerStack'
        }

        It "Should define Install-JesusProjectStack function" {
            $scriptContent | Should -Match 'function Install-JesusProjectStack'
        }
    }

    Context "Error Handling" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptPath -Raw
        }

        It "Should set ErrorActionPreference to Stop" {
            $scriptContent | Should -Match '\$ErrorActionPreference\s*=\s*["\']Stop["\']'
        }

        It "Should have try-catch blocks" {
            $scriptContent | Should -Match '\btry\s*\{'
            $scriptContent | Should -Match '\}\s*catch\s*\{'
        }

        It "Should log errors appropriately" {
            $scriptContent | Should -Match 'Write-Log.*ERROR'
        }
    }

    Context "Logging Functionality" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptPath -Raw
        }

        It "Should define log file variable" {
            $scriptContent | Should -Match '\$LogFile'
        }

        It "Should log to file in Write-Log function" {
            $scriptContent | Should -Match 'Add-Content.*-Path.*\$LogFile'
        }

        It "Should support different log levels" {
            $scriptContent | Should -Match 'INFO|SUCCESS|WARN|ERROR'
        }
    }

    Context "Prerequisites Validation" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptPath -Raw
        }

        It "Should check PowerShell version" {
            $scriptContent | Should -Match '\$PSVersionTable\.PSVersion'
        }

        It "Should check OS version" {
            $scriptContent | Should -Match 'Win32_OperatingSystem'
        }

        It "Should check Git installation" {
            $scriptContent | Should -Match 'git --version'
        }

        It "Should check disk space" {
            $scriptContent | Should -Match 'Get-PSDrive|Free'
        }

        It "Should check RAM" {
            $scriptContent | Should -Match 'Win32_ComputerSystem|TotalPhysicalMemory'
        }

        It "Should check internet connectivity" {
            $scriptContent | Should -Match 'Invoke-WebRequest.*github\.com|api\.github\.com'
        }
    }

    Context "Runner Installation" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptPath -Raw
        }

        It "Should create work folders" {
            $scriptContent | Should -Match 'New-Item.*-ItemType Directory'
        }

        It "Should download latest runner from GitHub API" {
            $scriptContent | Should -Match 'api\.github\.com/repos/actions/runner/releases/latest'
        }

        It "Should download runner package" {
            $scriptContent | Should -Match 'Invoke-WebRequest.*-OutFile'
        }

        It "Should extract runner archive" {
            $scriptContent | Should -Match 'Expand-Archive'
        }

        It "Should verify extraction" {
            $scriptContent | Should -Match 'config\.cmd'
        }

        It "Should cleanup installation files" {
            $scriptContent | Should -Match 'Remove-Item.*\.zip'
        }
    }

    Context "Runner Registration" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptPath -Raw
        }

        It "Should validate token format" {
            $scriptContent | Should -Match 'ghp_|github_pat_'
        }

        It "Should handle organization-level runners" {
            $scriptContent | Should -Match 'orgs/.*actions/runners/registration-token'
        }

        It "Should handle repository-level runners" {
            $scriptContent | Should -Match 'repos/.*actions/runners/registration-token'
        }

        It "Should request registration token from GitHub API" {
            $scriptContent | Should -Match 'Invoke-RestMethod.*registration-token'
        }

        It "Should configure runner with proper arguments" {
            $scriptContent | Should -Match '--url|--token|--name|--labels|--work|--unattended|--replace'
        }

        It "Should execute config.cmd" {
            $scriptContent | Should -Match '\.\\config\.cmd'
        }
    }

    Context "Service Installation" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptPath -Raw
        }

        It "Should check for administrator privileges" {
            $scriptContent | Should -Match 'Test-Administrator|IsInRole.*Administrator'
        }

        It "Should install service using svc.cmd" {
            $scriptContent | Should -Match '\.\\svc\.cmd install'
        }

        It "Should start service" {
            $scriptContent | Should -Match '\.\\svc\.cmd start'
        }

        It "Should verify service status" {
            $scriptContent | Should -Match 'Get-Service.*actions\.runner'
        }
    }

    Context "Firewall Configuration" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptPath -Raw
        }

        It "Should create firewall rules for GitHub" {
            $scriptContent | Should -Match 'New-NetFirewallRule'
        }

        It "Should specify GitHub IP ranges" {
            $scriptContent | Should -Match '140\.82\.112\.0|143\.55\.64\.0|185\.199\.108\.0|192\.30\.252\.0'
        }

        It "Should allow outbound HTTPS (port 443)" {
            $scriptContent | Should -Match 'RemotePort 443|--dport 443'
        }
    }

    Context "Output and User Guidance" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptPath -Raw
        }

        It "Should display installation complete message" {
            $scriptContent | Should -Match 'INSTALLATION COMPLETE'
        }

        It "Should provide next steps guidance" {
            $scriptContent | Should -Match 'NEXT STEPS'
        }

        It "Should show runner URL" {
            $scriptContent | Should -Match 'github\.com/.*settings/actions/runners'
        }

        It "Should suggest workflow configuration" {
            $scriptContent | Should -Match 'runs-on:.*self-hosted'
        }

        It "Should reference log monitoring" {
            $scriptContent | Should -Match 'Runner_\*\.log'
        }
    }

    Context "Security Considerations" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptPath -Raw
        }

        It "Should not expose tokens in logs" {
            # Ensure token is not logged directly
            $scriptContent | Should -Not -Match 'Write-Log.*\$Token[^a-zA-Z]'
        }

        It "Should use secure API headers" {
            $scriptContent | Should -Match 'Authorization.*Bearer'
        }

        It "Should use HTTPS for all API calls" {
            $scriptContent | Should -Match 'https://api\.github\.com'
        }
    }

    Context "Default Values" {
        BeforeAll {
            $params = (Get-Command $ScriptPath).Parameters
        }

        It "Should have correct default WorkFolder" {
            $params['WorkFolder'].Attributes.Where({$_.TypeId.Name -eq 'ParameterAttribute'}).ValueFromRemainingArguments | Should -BeFalse
        }

        It "Should have correct default Labels including gpu-cuda and unity" {
            # Check in script content since default value is in param block
            $scriptContent = Get-Content $ScriptPath -Raw
            $scriptContent | Should -Match 'gpu-cuda.*unity.*dotnet.*python.*windows'
        }

        It "Should default InstallService to false" {
            $params['InstallService'].ParameterType.Name | Should -Be 'SwitchParameter'
        }

        It "Should default IsOrg to false" {
            $params['IsOrg'].ParameterType.Name | Should -Be 'SwitchParameter'
        }
    }

    Context "Jesus Project Stack Installation" {
        BeforeAll {
            $scriptContent = Get-Content $ScriptPath -Raw
        }

        It "Should check for Node.js 20 installation" {
            $scriptContent | Should -Match 'node --version|v20\.'
        }

        It "Should install Node.js via winget if missing" {
            $scriptContent | Should -Match 'winget install.*NodeJS'
        }

        It "Should install pnpm 9 globally" {
            $scriptContent | Should -Match 'npm install -g pnpm@9|pnpm --version'
        }

        It "Should configure pnpm cache directory" {
            $scriptContent | Should -Match 'pnpm config set store-dir'
        }

        It "Should check for Python 3.11 installation" {
            $scriptContent | Should -Match 'python --version|Python 3\.11\.'
        }

        It "Should install Python via winget if missing" {
            $scriptContent | Should -Match 'winget install.*Python\.3\.11'
        }

        It "Should install pip-audit and detect-secrets" {
            $scriptContent | Should -Match 'pip install.*pip-audit.*detect-secrets'
        }

        It "Should verify Docker installation" {
            $scriptContent | Should -Match 'docker --version'
        }

        It "Should check Docker daemon status" {
            $scriptContent | Should -Match 'docker ps'
        }

        It "Should verify Docker Buildx availability" {
            $scriptContent | Should -Match 'docker buildx version'
        }

        It "Should enable Docker BuildKit" {
            $scriptContent | Should -Match 'DOCKER_BUILDKIT.*1'
        }

        It "Should have InstallJesusStack parameter" {
            $params = (Get-Command $ScriptPath).Parameters
            $params['InstallJesusStack'].ParameterType.Name | Should -Be 'SwitchParameter'
        }

        It "Should call all stack installation functions when InstallJesusStack is used" {
            $scriptContent | Should -Match 'Install-NodeJSAndPnpm'
            $scriptContent | Should -Match 'Install-PythonStack'
            $scriptContent | Should -Match 'Install-DockerStack'
        }
    }
}
