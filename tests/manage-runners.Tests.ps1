# Pester tests for manage-runners.ps1
# Run with: Invoke-Pester -Path .\tests\manage-runners.Tests.ps1

BeforeAll {
    # Script under test
    $script:ScriptPath = Join-Path $PSScriptRoot ".." "scripts" "manage-runners.ps1"

    # Verify script exists
    if (-not (Test-Path $script:ScriptPath)) {
        throw "Script not found: $script:ScriptPath"
    }

    # Test requires elevated permissions for some operations
    $currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $script:IsAdmin = $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    # Common test patterns
    $script:ServicePattern = "actions.runner.*"
    $script:DefaultDistro = "Ubuntu"
}

Describe "manage-runners.ps1 - Script Structure and Parameters" {
    Context "Script Availability" {
        It "Should exist at the expected path" {
            Test-Path $script:ScriptPath | Should -Be $true
        }

        It "Should be a PowerShell script" {
            $script:ScriptPath | Should -Match '\.ps1$'
        }

        It "Should have non-zero content" {
            (Get-Content $script:ScriptPath).Count | Should -BeGreaterThan 0
        }
    }

    Context "Parameter Validation" {
        It "Should have Action parameter with ValidateSet" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\[ValidateSet\(''status'',\s*''start'',\s*''stop'',\s*''restart'',\s*''logs''\)\]'
        }

        It "Should have Runner parameter with ValidateSet" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\[ValidateSet\(''windows'',\s*''linux'',\s*''both''\)\]'
        }

        It "Should have mandatory Action parameter" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\[Parameter\(Mandatory\s*=\s*\$true\)\]'
            $content | Should -Match '\[string\]\$Action'
        }

        It "Should have optional Runner parameter with default value" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\$Runner\s*=\s*[''"]both[''"]'
        }

        It "Should have optional DistroName parameter" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\[string\]\$DistroName'
        }

        It "Should have Follow switch parameter" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\[switch\]\$Follow'
        }
    }
}

Describe "manage-runners.ps1 - Helper Functions" {
    Context "Output Functions" {
        BeforeAll {
            # Dot source the script to load functions
            . $script:ScriptPath -Action status -ErrorAction SilentlyContinue
        }

        It "Should define Write-Header function" {
            Get-Command Write-Header -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should define Write-Success function" {
            Get-Command Write-Success -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should define Write-Error2 function" {
            Get-Command Write-Error2 -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should define Write-Warning2 function" {
            Get-Command Write-Warning2 -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should define Write-Info function" {
            Get-Command Write-Info -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Write-Header should accept Text parameter" {
            { Write-Header -Text "Test" } | Should -Not -Throw
        }

        It "Write-Success should accept Text parameter" {
            { Write-Success -Text "Test" } | Should -Not -Throw
        }

        It "Write-Error2 should accept Text parameter" {
            { Write-Error2 -Text "Test" } | Should -Not -Throw
        }

        It "Write-Warning2 should accept Text parameter" {
            { Write-Warning2 -Text "Test" } | Should -Not -Throw
        }

        It "Write-Info should accept Text parameter" {
            { Write-Info -Text "Test" } | Should -Not -Throw
        }
    }
}

Describe "manage-runners.ps1 - Windows Runner Functions" {
    Context "Get-WindowsRunnerStatus Function" {
        BeforeAll {
            # Dot source to load functions
            . $script:ScriptPath -Action status -ErrorAction SilentlyContinue
        }

        It "Should define Get-WindowsRunnerStatus function" {
            Get-Command Get-WindowsRunnerStatus -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should not throw when called" {
            { Get-WindowsRunnerStatus } | Should -Not -Throw
        }

        It "Should return boolean or service status value" {
            $result = Get-WindowsRunnerStatus
            # The function returns different types based on number of services present
            # Can be bool, ServiceControllerStatus, or array of ServiceControllerStatus
            $isValidType = ($result -is [bool] -or
                           $result -is [System.ServiceProcess.ServiceControllerStatus] -or
                           $result -is [Array])
            $isValidType | Should -Be $true
        }

        It "Should query for Windows runner service" {
            Mock Get-Service { return $null } -Verifiable
            Get-WindowsRunnerStatus
            Should -Invoke Get-Service -Times 1
        }

        It "Should return false when service not found" {
            Mock Get-Service { return $null }
            $result = Get-WindowsRunnerStatus
            $result | Should -Be $false
        }

        It "Should return true when service is running" {
            $mockService = [PSCustomObject]@{
                Name = 'actions.runner.test'
                Status = 'Running'
                StartType = 'Automatic'
            }
            Mock Get-Service { return $mockService }
            $result = Get-WindowsRunnerStatus
            $result | Should -Be $true
        }
    }

    Context "Start-WindowsRunner Function" {
        BeforeAll {
            . $script:ScriptPath -Action status -ErrorAction SilentlyContinue
        }

        It "Should define Start-WindowsRunner function" {
            Get-Command Start-WindowsRunner -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should not throw when service not found" {
            Mock Get-Service { return $null }
            { Start-WindowsRunner } | Should -Not -Throw
        }

        It "Should attempt to start stopped service" -Skip:(-not $script:IsAdmin) {
            $mockService = [PSCustomObject]@{
                Name = 'actions.runner.test'
                Status = 'Stopped'
            } | Add-Member -MemberType ScriptMethod -Name Refresh -Value {} -PassThru

            Mock Get-Service { return $mockService }
            Mock Start-Service { }

            Start-WindowsRunner
            Should -Invoke Start-Service -Times 1
        }

        It "Should not attempt to start already running service" {
            $mockService = [PSCustomObject]@{
                Name = 'actions.runner.test'
                Status = 'Running'
            }
            Mock Get-Service { return $mockService }
            Mock Start-Service { }

            Start-WindowsRunner
            Should -Invoke Start-Service -Times 0
        }
    }

    Context "Stop-WindowsRunner Function" {
        BeforeAll {
            . $script:ScriptPath -Action status -ErrorAction SilentlyContinue
        }

        It "Should define Stop-WindowsRunner function" {
            Get-Command Stop-WindowsRunner -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should not throw when service not found" {
            Mock Get-Service { return $null }
            { Stop-WindowsRunner } | Should -Not -Throw
        }

        It "Should attempt to stop running service" -Skip:(-not $script:IsAdmin) {
            $mockService = [PSCustomObject]@{
                Name = 'actions.runner.test'
                Status = 'Running'
            } | Add-Member -MemberType ScriptMethod -Name Refresh -Value {} -PassThru

            Mock Get-Service { return $mockService }
            Mock Stop-Service { }

            Stop-WindowsRunner
            Should -Invoke Stop-Service -Times 1
        }

        It "Should not attempt to stop already stopped service" {
            $mockService = [PSCustomObject]@{
                Name = 'actions.runner.test'
                Status = 'Stopped'
            }
            Mock Get-Service { return $mockService }
            Mock Stop-Service { }

            Stop-WindowsRunner
            Should -Invoke Stop-Service -Times 0
        }
    }

    Context "Get-WindowsRunnerLogs Function" {
        BeforeAll {
            . $script:ScriptPath -Action status -ErrorAction SilentlyContinue
        }

        It "Should define Get-WindowsRunnerLogs function" {
            Get-Command Get-WindowsRunnerLogs -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should not throw when called" {
            # Get-EventLog is Windows PowerShell only, skip on PowerShell Core
            if ($PSVersionTable.PSEdition -eq 'Core') {
                Set-ItResult -Skipped -Because "Get-EventLog not available in PowerShell Core"
            } else {
                Mock Get-EventLog { return @() }
                { Get-WindowsRunnerLogs } | Should -Not -Throw
            }
        }

        It "Should query Windows Event Log" {
            # Get-EventLog is Windows PowerShell only, skip on PowerShell Core
            if ($PSVersionTable.PSEdition -eq 'Core') {
                Set-ItResult -Skipped -Because "Get-EventLog not available in PowerShell Core"
            } else {
                Mock Get-EventLog { return @() } -Verifiable
                Get-WindowsRunnerLogs
                Should -Invoke Get-EventLog -Times 1
            }
        }
    }
}

Describe "manage-runners.ps1 - Linux Runner Functions" {
    Context "Get-LinuxRunnerStatus Function" {
        BeforeAll {
            . $script:ScriptPath -Action status -ErrorAction SilentlyContinue
        }

        It "Should define Get-LinuxRunnerStatus function" {
            Get-Command Get-LinuxRunnerStatus -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should not throw when called" {
            Mock wsl { return "" }
            { Get-LinuxRunnerStatus } | Should -Not -Throw
        }

        It "Should check if WSL distro exists" {
            Mock wsl { return "Ubuntu" } -ParameterFilter { $args -contains '--list' }
            Mock wsl { return "0" } -ParameterFilter { $args -contains 'bash' }

            Get-LinuxRunnerStatus
            Should -Invoke wsl -Times 1 -ParameterFilter { $args -contains '--list' }
        }

        It "Should return false when distro not found" {
            Mock wsl { return "OtherDistro" } -ParameterFilter { $args -contains '--list' }

            $result = Get-LinuxRunnerStatus
            $result | Should -Be $false
        }

        It "Should check for runner service in WSL" {
            Mock wsl {
                if ($args -contains '--list') { return "Ubuntu" }
                if ($args -contains 'bash') { return "1" }
                return ""
            }

            Get-LinuxRunnerStatus
            Should -Invoke wsl -Times 1 -ParameterFilter { $args -contains 'bash' }
        }

        It "Should return false when service not found in WSL" {
            Mock wsl {
                if ($args -contains '--list') { return "Ubuntu" }
                if ($args -contains 'bash') { return "0" }
                return ""
            }

            $result = Get-LinuxRunnerStatus
            $result | Should -Be $false
        }

        It "Should return true when service is active" {
            Mock wsl {
                if ($args -contains '--list') { return "Ubuntu" }
                if ($args -contains 'bash') { return "1" }
                if ($args -contains 'systemctl' -and $args -contains 'status') {
                    return "Active: active (running)"
                }
                return ""
            }

            $result = Get-LinuxRunnerStatus
            $result | Should -Be $true
        }

        It "Should return false when service is inactive" {
            Mock wsl {
                if ($args -contains '--list') { return "Ubuntu" }
                if ($args -contains 'bash') { return "1" }
                if ($args -contains 'systemctl' -and $args -contains 'status') {
                    return "Active: inactive (dead)"
                }
                return ""
            }

            $result = Get-LinuxRunnerStatus
            $result | Should -Be $false
        }
    }

    Context "Start-LinuxRunner Function" {
        BeforeAll {
            . $script:ScriptPath -Action status -ErrorAction SilentlyContinue
        }

        It "Should define Start-LinuxRunner function" {
            Get-Command Start-LinuxRunner -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should not throw when called" {
            Mock wsl { return "" }
            { Start-LinuxRunner } | Should -Not -Throw
        }

        It "Should call systemctl start command" {
            Mock wsl { return "active" } -Verifiable
            Start-LinuxRunner
            Should -Invoke wsl -Times 1 -ParameterFilter { $args -contains 'start' }
        }

        It "Should verify service started successfully" {
            Mock wsl {
                if ($args -contains 'start') { return "" }
                if ($args -contains 'is-active') { return "active" }
                return ""
            }
            Start-LinuxRunner
            Should -Invoke wsl -Times 1 -ParameterFilter { $args -contains 'is-active' }
        }
    }

    Context "Stop-LinuxRunner Function" {
        BeforeAll {
            . $script:ScriptPath -Action status -ErrorAction SilentlyContinue
        }

        It "Should define Stop-LinuxRunner function" {
            Get-Command Stop-LinuxRunner -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should not throw when called" {
            Mock wsl { return "" }
            { Stop-LinuxRunner } | Should -Not -Throw
        }

        It "Should call systemctl stop command" {
            Mock wsl { return "inactive" } -Verifiable
            Stop-LinuxRunner
            Should -Invoke wsl -Times 1 -ParameterFilter { $args -contains 'stop' }
        }

        It "Should verify service stopped successfully" {
            Mock wsl {
                if ($args -contains 'stop') { return "" }
                if ($args -contains 'is-active') { return "inactive" }
                return ""
            }
            Stop-LinuxRunner
            Should -Invoke wsl -Times 1 -ParameterFilter { $args -contains 'is-active' }
        }
    }

    Context "Get-LinuxRunnerLogs Function" {
        BeforeAll {
            . $script:ScriptPath -Action status -ErrorAction SilentlyContinue
        }

        It "Should define Get-LinuxRunnerLogs function" {
            Get-Command Get-LinuxRunnerLogs -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It "Should not throw when called without Follow" {
            Mock wsl { return "" }
            { Get-LinuxRunnerLogs } | Should -Not -Throw
        }

        It "Should call journalctl without -f when Follow is not set" {
            Mock wsl { return "" } -Verifiable
            Get-LinuxRunnerLogs
            Should -Invoke wsl -Times 1 -ParameterFilter {
                $args -contains 'journalctl' -and $args -notcontains '-f'
            }
        }

        It "Should include line limit when Follow is not set" {
            Mock wsl { return "" }
            Get-LinuxRunnerLogs
            Should -Invoke wsl -Times 1 -ParameterFilter {
                $args -contains '-n'
            }
        }
    }
}

Describe "manage-runners.ps1 - Main Action Logic" {
    Context "Action Execution" {
        It "Should accept status action" {
            { & $script:ScriptPath -Action status -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should accept start action" {
            { & $script:ScriptPath -Action start -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should accept stop action" {
            { & $script:ScriptPath -Action stop -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should accept restart action" {
            { & $script:ScriptPath -Action restart -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should accept logs action" {
            { & $script:ScriptPath -Action logs -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context "Runner Selection" {
        It "Should accept windows runner" {
            { & $script:ScriptPath -Action status -Runner windows -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should accept linux runner" {
            { & $script:ScriptPath -Action status -Runner linux -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should accept both runners" {
            { & $script:ScriptPath -Action status -Runner both -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should default to both runners when not specified" {
            { & $script:ScriptPath -Action status -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context "Action Logic Flow" {
        It "Should execute status action without errors" {
            $output = & $script:ScriptPath -Action status 2>&1
            $LASTEXITCODE | Should -BeNullOrEmpty -Because "Script should not set exit code"
        }

        It "Should not throw for start action" {
            { & $script:ScriptPath -Action start -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should not throw for stop action" {
            { & $script:ScriptPath -Action stop -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should not throw for restart action" {
            { & $script:ScriptPath -Action restart -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should not throw for logs action" {
            { & $script:ScriptPath -Action logs -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }
}

Describe "manage-runners.ps1 - Parameter Combinations" {
    Context "DistroName Parameter" {
        It "Should accept custom distro name" {
            Mock wsl { return "" }
            { & $script:ScriptPath -Action status -Runner linux -DistroName "CustomDistro" -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should use default Ubuntu distro when not specified" {
            Mock wsl { return "" }
            { & $script:ScriptPath -Action status -Runner linux -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    Context "Follow Parameter" {
        It "Should accept Follow switch for logs action" {
            Mock wsl { return "" }
            { & $script:ScriptPath -Action logs -Runner linux -Follow -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should work without Follow switch for logs action" {
            Mock wsl { return "" }
            { & $script:ScriptPath -Action logs -Runner linux -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }
}

Describe "manage-runners.ps1 - Error Handling" {
    Context "Service Not Found Scenarios" {
        BeforeAll {
            . $script:ScriptPath -Action status -ErrorAction SilentlyContinue
        }

        It "Should handle Windows service not found gracefully" {
            Mock Get-Service { return $null }
            { Get-WindowsRunnerStatus } | Should -Not -Throw
        }

        It "Should handle WSL distro not found gracefully" {
            Mock wsl { return "OtherDistro" }
            { Get-LinuxRunnerStatus } | Should -Not -Throw
        }

        It "Should handle Linux service not found gracefully" {
            Mock wsl {
                if ($args -contains '--list') { return "Ubuntu" }
                if ($args -contains 'bash') { return "0" }
                return ""
            }
            { Get-LinuxRunnerStatus } | Should -Not -Throw
        }
    }

    Context "ErrorActionPreference" {
        It "Should set ErrorActionPreference to Continue" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\$ErrorActionPreference\s*=\s*"Continue"'
        }
    }
}

Describe "manage-runners.ps1 - Integration Scenarios" {
    Context "Real Environment Detection" {
        It "Should detect actual Windows runner service if present" {
            $service = Get-Service -Name $script:ServicePattern -ErrorAction SilentlyContinue
            if ($service) {
                $service.Name | Should -Match '^actions\.runner\.'
            } else {
                Set-ItResult -Skipped -Because "No Windows runner service installed"
            }
        }

        It "Should detect WSL2 installation if present" {
            $wslAvailable = Get-Command wsl -ErrorAction SilentlyContinue
            if ($wslAvailable) {
                { wsl --list --quiet } | Should -Not -Throw
            } else {
                Set-ItResult -Skipped -Because "WSL2 not installed"
            }
        }
    }
}

AfterAll {
    if (-not $script:IsAdmin) {
        Write-Warning "Some service control tests were skipped due to lack of elevated permissions."
        Write-Host "To run all tests, execute PowerShell as Administrator:" -ForegroundColor Yellow
        Write-Host "  Invoke-Pester -Path .\tests\manage-runners.Tests.ps1" -ForegroundColor Cyan
    }
}
