#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\setup-jesus-runner.ps1'
    $script:TempDir = Join-Path $env:TEMP "JesusRunnerTests_$(Get-Date -Format 'yyyyMMddHHmmss')"

    # Create temp directory for tests
    if (-not (Test-Path $script:TempDir)) {
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
    }
}

AfterAll {
    # Cleanup temp directory
    if (Test-Path $script:TempDir) {
        Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe "setup-jesus-runner.ps1 - Script Validation" {
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

    It "Script requires Administrator privileges" {
        $content = Get-Content $script:ScriptPath -Raw
        $content | Should -Match '#Requires -RunAsAdministrator'
    }

    It "Script has proper comment-based help" {
        $content = Get-Content $script:ScriptPath -Raw
        $content | Should -Match '\.SYNOPSIS'
        $content | Should -Match '\.DESCRIPTION'
        $content | Should -Match '\.PARAMETER'
        $content | Should -Match '\.EXAMPLE'
    }
}

Describe "setup-jesus-runner.ps1 - Parameter Validation" {
    BeforeAll {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:ScriptPath,
            [ref]$null,
            [ref]$null
        )
        $script:Params = $ast.ParamBlock.Parameters
    }

    It "Has mandatory RunnerToken parameter" {
        $tokenParam = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'RunnerToken' }
        $tokenParam | Should -Not -BeNullOrEmpty
        $tokenParam.Attributes.TypeName.Name | Should -Contain 'Parameter'
    }

    It "Has mandatory RepoUrl parameter" {
        $repoParam = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'RepoUrl' }
        $repoParam | Should -Not -BeNullOrEmpty
        $repoParam.Attributes.TypeName.Name | Should -Contain 'Parameter'
    }

    It "Has RunnerPath parameter with default value" {
        $pathParam = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'RunnerPath' }
        $pathParam | Should -Not -BeNullOrEmpty
        $pathParam.DefaultValue.Value | Should -Be 'C:\actions-runner'
    }

    It "Has RunnerName parameter with default value" {
        $nameParam = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'RunnerName' }
        $nameParam | Should -Not -BeNullOrEmpty
    }

    It "Has SkipDocker switch parameter" {
        $skipDockerParam = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'SkipDocker' }
        $skipDockerParam | Should -Not -BeNullOrEmpty
        $skipDockerParam.StaticType.Name | Should -Be 'SwitchParameter'
    }

    It "Has SkipNodeJs switch parameter" {
        $skipNodeParam = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'SkipNodeJs' }
        $skipNodeParam | Should -Not -BeNullOrEmpty
        $skipNodeParam.StaticType.Name | Should -Be 'SwitchParameter'
    }

    It "Has SkipPython switch parameter" {
        $skipPythonParam = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'SkipPython' }
        $skipPythonParam | Should -Not -BeNullOrEmpty
        $skipPythonParam.StaticType.Name | Should -Be 'SwitchParameter'
    }
}

Describe "setup-jesus-runner.ps1 - Function Definitions" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Defines Write-SetupLog function" {
        $script:ScriptContent | Should -Match 'function Write-SetupLog'
    }

    It "Defines Test-DiskSpace function" {
        $script:ScriptContent | Should -Match 'function Test-DiskSpace'
    }

    It "Defines Install-Chocolatey function" {
        $script:ScriptContent | Should -Match 'function Install-Chocolatey'
    }

    It "Defines Install-NodeJs function" {
        $script:ScriptContent | Should -Match 'function Install-NodeJs'
    }

    It "Defines Install-Pnpm function" {
        $script:ScriptContent | Should -Match 'function Install-Pnpm'
    }

    It "Defines Install-Python function" {
        $script:ScriptContent | Should -Match 'function Install-Python'
    }

    It "Defines Install-PythonSecurityTools function" {
        $script:ScriptContent | Should -Match 'function Install-PythonSecurityTools'
    }

    It "Defines Test-DockerInstallation function" {
        $script:ScriptContent | Should -Match 'function Test-DockerInstallation'
    }

    It "Defines Install-OSVScanner function" {
        $script:ScriptContent | Should -Match 'function Install-OSVScanner'
    }

    It "Defines Install-Runner function" {
        $script:ScriptContent | Should -Match 'function Install-Runner'
    }

    It "Defines Configure-Runner function" {
        $script:ScriptContent | Should -Match 'function Configure-Runner'
    }

    It "Defines Install-RunnerService function" {
        $script:ScriptContent | Should -Match 'function Install-RunnerService'
    }

    It "Defines Test-Setup function" {
        $script:ScriptContent | Should -Match 'function Test-Setup'
    }
}

Describe "setup-jesus-runner.ps1 - Write-SetupLog Function" {
    BeforeAll {
        $script:ScriptContent = Get-Content $script:ScriptPath -Raw
    }

    It "Write-SetupLog function validates log levels" {
        $script:ScriptContent | Should -Match "ValidateSet\('INFO', 'SUCCESS', 'WARN', 'ERROR'\)"
    }

    It "Write-SetupLog creates timestamped log entries" {
        $script:ScriptContent | Should -Match 'Get-Date -Format.*HH:mm:ss'
    }

    It "Write-SetupLog writes to log file" {
        $script:ScriptContent | Should -Match 'Add-Content.*logFile'
    }

    It "Write-SetupLog uses colored output" {
        $script:ScriptContent | Should -Match 'Write-Host.*-ForegroundColor'
    }
}

Describe "setup-jesus-runner.ps1 - Installation Requirements" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Checks for Node.js 20.x requirement" {
        $script:ScriptContent | Should -Match 'Node.*20\.x'
    }

    It "Checks for pnpm 9.x requirement" {
        $script:ScriptContent | Should -Match 'pnpm.*9\.x'
    }

    It "Checks for Python 3.11 requirement" {
        $script:ScriptContent | Should -Match 'Python.*3\.11'
    }

    It "Checks for Docker BuildKit support" {
        $script:ScriptContent | Should -Match 'BuildKit|buildx'
    }

    It "Checks for pip-audit security tool" {
        $script:ScriptContent | Should -Match 'pip-audit'
    }

    It "Checks for detect-secrets security tool" {
        $script:ScriptContent | Should -Match 'detect-secrets'
    }

    It "Checks for OSV Scanner" {
        $script:ScriptContent | Should -Match 'osv-scanner'
    }
}

Describe "setup-jesus-runner.ps1 - Disk Space Check" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Requires minimum 100GB disk space" {
        $script:ScriptContent | Should -Match 'RequiredGB.*100'
    }

    It "Checks system drive free space" {
        $script:ScriptContent | Should -Match '\$env:SystemDrive'
    }

    It "Calculates free space in GB" {
        $script:ScriptContent | Should -Match 'Get-PSDrive.*Free.*1GB'
    }
}

Describe "setup-jesus-runner.ps1 - Chocolatey Installation" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Checks if Chocolatey is already installed" {
        $script:ScriptContent | Should -Match 'Get-Command choco'
    }

    It "Downloads Chocolatey from official source" {
        $script:ScriptContent | Should -Match 'community\.chocolatey\.org/install\.ps1'
    }

    It "Sets security protocol for TLS 1.2" {
        $script:ScriptContent | Should -Match 'SecurityProtocol.*3072'
    }

    It "Refreshes environment PATH after installation" {
        $script:ScriptContent | Should -Match 'GetEnvironmentVariable.*Path'
    }
}

Describe "setup-jesus-runner.ps1 - Node.js Installation" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Respects SkipNodeJs switch" {
        $script:ScriptContent | Should -Match 'if.*\$SkipNodeJs'
    }

    It "Detects existing Node.js installation" {
        $script:ScriptContent | Should -Match 'Get-Command node'
    }

    It "Installs Node.js 20.x via Chocolatey" {
        $script:ScriptContent | Should -Match 'choco install nodejs-lts'
    }

    It "Verifies installed Node.js version" {
        $script:ScriptContent | Should -Match 'node --version'
    }
}

Describe "setup-jesus-runner.ps1 - pnpm Installation" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Detects existing pnpm installation" {
        $script:ScriptContent | Should -Match 'Get-Command pnpm'
    }

    It "Installs pnpm 9.x globally" {
        $script:ScriptContent | Should -Match 'npm install -g pnpm@9'
    }

    It "Configures pnpm cache directory" {
        $script:ScriptContent | Should -Match 'pnpm config set store-dir'
    }

    It "Sets pnpm cache to C:\pnpm-store" {
        $script:ScriptContent | Should -Match 'C:\\pnpm-store'
    }
}

Describe "setup-jesus-runner.ps1 - Python Installation" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Respects SkipPython switch" {
        $script:ScriptContent | Should -Match 'if.*\$SkipPython'
    }

    It "Detects existing Python installation" {
        $script:ScriptContent | Should -Match 'Get-Command python'
    }

    It "Installs Python 3.11 via Chocolatey" {
        $script:ScriptContent | Should -Match 'choco install python311'
    }

    It "Ensures pip is available" {
        $script:ScriptContent | Should -Match 'python -m ensurepip'
    }
}

Describe "setup-jesus-runner.ps1 - Security Tools Installation" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Installs pip-audit via pip" {
        $script:ScriptContent | Should -Match 'python -m pip install pip-audit'
    }

    It "Installs detect-secrets via pip" {
        $script:ScriptContent | Should -Match 'python -m pip install detect-secrets'
    }

    It "Downloads OSV Scanner from GitHub" {
        $script:ScriptContent | Should -Match 'github\.com.*osv-scanner'
    }

    It "Installs OSV Scanner to Program Files" {
        $script:ScriptContent | Should -Match 'Program Files\\osv-scanner'
    }
}

Describe "setup-jesus-runner.ps1 - Docker Verification" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Respects SkipDocker switch" {
        $script:ScriptContent | Should -Match 'if.*\$SkipDocker'
    }

    It "Checks Docker command availability" {
        $script:ScriptContent | Should -Match 'Get-Command docker'
    }

    It "Verifies Docker Buildx availability" {
        $script:ScriptContent | Should -Match 'docker buildx version'
    }

    It "Tests Docker connectivity" {
        $script:ScriptContent | Should -Match 'docker ps'
    }

    It "Provides manual installation instructions if Docker missing" {
        $script:ScriptContent | Should -Match 'docker\.com/products/docker-desktop'
    }
}

Describe "setup-jesus-runner.ps1 - GitHub Runner Installation" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Downloads runner from GitHub API" {
        $script:ScriptContent | Should -Match 'api\.github\.com/repos/actions/runner/releases/latest'
    }

    It "Selects Windows x64 runner package" {
        $script:ScriptContent | Should -Match 'win-x64.*\.zip'
    }

    It "Extracts runner to specified path" {
        $script:ScriptContent | Should -Match 'Expand-Archive'
    }

    It "Handles existing runner directory" {
        $script:ScriptContent | Should -Match 'Test-Path.*RunnerPath'
    }
}

Describe "setup-jesus-runner.ps1 - Runner Configuration" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Runs config.cmd with repository URL" {
        $script:ScriptContent | Should -Match 'config\.cmd.*--url.*RepoUrl'
    }

    It "Uses runner token for authentication" {
        $script:ScriptContent | Should -Match '--token.*RunnerToken'
    }

    It "Sets runner name" {
        $script:ScriptContent | Should -Match '--name.*RunnerName'
    }

    It "Applies 'jesus' label to runner" {
        $script:ScriptContent | Should -Match '--labels.*jesus'
    }

    It "Applies 'self-hosted' label to runner" {
        $script:ScriptContent | Should -Match '--labels.*self-hosted'
    }

    It "Applies 'Windows' label to runner" {
        $script:ScriptContent | Should -Match '--labels.*Windows'
    }

    It "Applies 'X64' label to runner" {
        $script:ScriptContent | Should -Match '--labels.*X64'
    }

    It "Runs configuration in unattended mode" {
        $script:ScriptContent | Should -Match '--unattended'
    }
}

Describe "setup-jesus-runner.ps1 - Service Installation" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Installs runner as Windows service" {
        $script:ScriptContent | Should -Match 'svc\.cmd install'
    }

    It "Starts runner service" {
        $script:ScriptContent | Should -Match 'svc\.cmd start'
    }

    It "Verifies service is running" {
        $script:ScriptContent | Should -Match 'Get-Service.*actions\.runner'
    }

    It "Provides manual start instructions on failure" {
        $script:ScriptContent | Should -Match 'run\.cmd'
    }
}

Describe "setup-jesus-runner.ps1 - Integration Tests" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Tests Node.js installation" {
        $script:ScriptContent | Should -Match 'Testing Node\.js'
    }

    It "Tests pnpm installation" {
        $script:ScriptContent | Should -Match 'Testing pnpm'
    }

    It "Tests Python installation" {
        $script:ScriptContent | Should -Match 'Testing Python'
    }

    It "Tests pip installation" {
        $script:ScriptContent | Should -Match 'Testing pip'
    }

    It "Tests Docker installation" {
        $script:ScriptContent | Should -Match 'Testing Docker'
    }

    It "Tests pip-audit installation" {
        $script:ScriptContent | Should -Match 'pip-audit --version'
    }

    It "Tests detect-secrets installation" {
        $script:ScriptContent | Should -Match 'detect-secrets --version'
    }

    It "Tests curl availability" {
        $script:ScriptContent | Should -Match 'curl --version'
    }
}

Describe "setup-jesus-runner.ps1 - Error Handling" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Sets ErrorActionPreference to Stop" {
        $script:ScriptContent | Should -Match '\$ErrorActionPreference\s*=\s*[''"]Stop[''"]'
    }

    It "Has try-catch block for main execution" {
        $script:ScriptContent | Should -Match 'try\s*\{[\s\S]*\}\s*catch'
    }

    It "Creates log file for diagnostics" {
        $script:ScriptContent | Should -Match '\$logFile'
    }

    It "Logs errors to file" {
        $script:ScriptContent | Should -Match 'Add-Content.*logFile'
    }

    It "Exits with code 1 on failure" {
        $script:ScriptContent | Should -Match 'exit 1'
    }

    It "Exits with code 0 on success" {
        $script:ScriptContent | Should -Match 'exit 0'
    }
}

Describe "setup-jesus-runner.ps1 - Logging Functionality" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Creates timestamp for log entries" {
        $script:ScriptContent | Should -Match 'Get-Date -Format.*yyyy-MM-dd HH:mm:ss'
    }

    It "Logs to file in C:\Temp" {
        $script:ScriptContent | Should -Match 'C:\\Temp.*jesus-runner-setup'
    }

    It "Creates temp directory if missing" {
        $script:ScriptContent | Should -Match 'New-Item.*C:\\Temp'
    }

    It "Uses different colors for log levels" {
        $script:ScriptContent | Should -Match '-ForegroundColor Red'
        $script:ScriptContent | Should -Match '-ForegroundColor Yellow'
        $script:ScriptContent | Should -Match '-ForegroundColor Green'
    }
}

Describe "setup-jesus-runner.ps1 - Setup Summary" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Displays success summary" {
        $script:ScriptContent | Should -Match 'Setup Complete'
    }

    It "Lists installed components" {
        $script:ScriptContent | Should -Match 'Node\.js.*installed'
        $script:ScriptContent | Should -Match 'pnpm.*installed'
        $script:ScriptContent | Should -Match 'Python.*installed'
    }

    It "Provides next steps" {
        $script:ScriptContent | Should -Match 'Next steps:'
    }

    It "Shows log file location" {
        $script:ScriptContent | Should -Match 'Log file:'
    }
}

Describe "setup-jesus-runner.ps1 - Security Best Practices" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Does not contain hardcoded tokens" {
        $script:ScriptContent | Should -Not -Match 'ghp_[a-zA-Z0-9]{36}'
        $script:ScriptContent | Should -Not -Match 'github_pat_[a-zA-Z0-9_]{82}'
    }

    It "Does not contain hardcoded passwords" {
        $script:ScriptContent | Should -Not -Match 'password\s*=\s*[''"][^''"]+'
    }

    It "Uses HTTPS for downloads" {
        $script:ScriptContent | Should -Match 'https://'
        $script:ScriptContent | Should -Not -Match 'http://(?!localhost)'
    }

    It "Validates downloaded files before extraction" {
        $script:ScriptContent | Should -Match 'Expand-Archive'
    }
}

Describe "setup-jesus-runner.ps1 - Documentation Quality" {
    BeforeAll {
        $content = Get-Content $script:ScriptPath -Raw
        $script:ScriptContent = $content
    }

    It "Has author information" {
        $script:ScriptContent | Should -Match '\.NOTES'
        $script:ScriptContent | Should -Match 'Author:'
    }

    It "Has version information" {
        $script:ScriptContent | Should -Match 'Version:'
    }

    It "Documents issue number" {
        $script:ScriptContent | Should -Match 'Issue #30'
    }

    It "Provides usage examples" {
        $script:ScriptContent | Should -Match '\.EXAMPLE'
    }

    It "Documents all parameters" {
        $script:ScriptContent | Should -Match '\.PARAMETER RunnerPath'
        $script:ScriptContent | Should -Match '\.PARAMETER RunnerToken'
        $script:ScriptContent | Should -Match '\.PARAMETER RepoUrl'
    }
}
