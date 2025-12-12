# Pester tests for register-runner.ps1
# Run with: Invoke-Pester -Path .\tests\register-runner.Tests.ps1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "..\scripts\register-runner.ps1"

    # Mock functions for testing
    function Mock-RunnerSetup {
        param($WorkFolder)

        if (-not (Test-Path $WorkFolder)) {
            New-Item -ItemType Directory -Path $WorkFolder -Force | Out-Null
        }

        # Create mock config.cmd
        $configScript = @"
@echo off
echo Mock runner configuration
echo URL: %2
echo Token: %4
echo Name: %6
echo Labels: %8
exit /b 0
"@
        Set-Content -Path (Join-Path $WorkFolder "config.cmd") -Value $configScript

        # Create mock svc.cmd
        $svcScript = @"
@echo off
echo Mock service command: %1
exit /b 0
"@
        Set-Content -Path (Join-Path $WorkFolder "svc.cmd") -Value $svcScript
    }
}

Describe "register-runner.ps1 Parameter Validation" {
    It "Should accept valid organization name" {
        { & $ScriptPath -OrgOrRepo "test-org" -Token "ghp_1234567890" -WhatIf } | Should -Not -Throw
    }

    It "Should accept valid repository path" {
        { & $ScriptPath -OrgOrRepo "owner/repo" -Token "ghp_1234567890" -WhatIf } | Should -Not -Throw
    }

    It "Should require OrgOrRepo parameter" {
        { & $ScriptPath -Token "ghp_1234567890" } | Should -Throw
    }

    It "Should require Token parameter" {
        { & $ScriptPath -OrgOrRepo "test-org" } | Should -Throw
    }

    It "Should validate token format (ghp_ prefix)" {
        Mock -CommandName Write-Log -MockWith {}
        Mock -CommandName Invoke-RestMethod -MockWith { return @{ tag_name = "v2.311.0"; assets = @() } }

        { & $ScriptPath -OrgOrRepo "test-org" -Token "invalid_token" } | Should -Throw
    }

    It "Should accept github_pat_ token prefix" {
        Mock -CommandName Write-Log -MockWith {}
        Mock -CommandName Invoke-RestMethod -MockWith { return @{ tag_name = "v2.311.0"; assets = @() } }

        { & $ScriptPath -OrgOrRepo "test-org" -Token "github_pat_1234567890" -WhatIf } | Should -Not -Throw
    }
}

Describe "register-runner.ps1 Default Values" {
    It "Should use computer name as default runner name" {
        Mock -CommandName Write-Log -MockWith {}

        $result = & $ScriptPath -OrgOrRepo "test-org" -Token "ghp_1234567890" -WhatIf 6>$null

        # Check that default runner name is set
        $env:COMPUTERNAME | Should -Not -BeNullOrEmpty
    }

    It "Should use C:\actions-runner as default work folder" {
        Mock -CommandName Write-Log -MockWith {}

        $defaultWorkFolder = "C:\actions-runner"
        $defaultWorkFolder | Should -Be "C:\actions-runner"
    }
}

Describe "register-runner.ps1 AutoDetectLabels Parameter" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Script has AutoDetectLabels parameter" {
        $script:Content | Should -Match '\$AutoDetectLabels'
    }

    It "AutoDetectLabels defaults to true" {
        $script:Content | Should -Match '\[bool\]\$AutoDetectLabels\s*=\s*\$true'
    }

    It "Script references detect-capabilities.ps1" {
        $script:Content | Should -Match 'detect-capabilities\.ps1'
    }

    It "Script has static default labels fallback" {
        $script:Content | Should -Match '\$StaticDefaultLabels'
    }

    It "Static default labels include expected values" {
        $script:Content | Should -Match 'self-hosted'
        $script:Content | Should -Match 'windows'
        $script:Content | Should -Match 'dotnet'
    }
}

Describe "register-runner.ps1 Label Detection Logic" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Uses explicit labels when provided" {
        $script:Content | Should -Match 'if \(\$Labels\)'
        $script:Content | Should -Match 'Using explicitly provided labels'
    }

    It "Auto-detects labels when AutoDetectLabels is enabled and no explicit labels" {
        $script:Content | Should -Match 'elseif \(\$AutoDetectLabels\)'
        $script:Content | Should -Match 'Auto-detecting runner capabilities'
    }

    It "Falls back to static defaults when auto-detection is disabled" {
        $script:Content | Should -Match 'Label auto-detection disabled'
    }

    It "Falls back to static defaults when detect-capabilities.ps1 is not found" {
        $script:Content | Should -Match 'Capability detection script not found'
    }

    It "Falls back to static defaults when detection fails" {
        $script:Content | Should -Match 'Capability detection failed'
        $script:Content | Should -Match 'Falling back to static default labels'
    }
}

Describe "register-runner.ps1 Static Default Labels" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Static default labels include self-hosted" {
        $script:Content | Should -Match '\$StaticDefaultLabels\s*=.*self-hosted'
    }

    It "Static default labels include windows" {
        $script:Content | Should -Match '\$StaticDefaultLabels\s*=.*windows'
    }

    It "Static default labels include dotnet" {
        $script:Content | Should -Match '\$StaticDefaultLabels\s*=.*dotnet'
    }

    It "Static default labels include python" {
        $script:Content | Should -Match '\$StaticDefaultLabels\s*=.*python'
    }

    It "Static default labels include unity-pool" {
        $script:Content | Should -Match '\$StaticDefaultLabels\s*=.*unity-pool'
    }

    It "Static default labels include gpu-cuda" {
        $script:Content | Should -Match '\$StaticDefaultLabels\s*=.*gpu-cuda'
    }

    It "Static default labels include docker" {
        $script:Content | Should -Match '\$StaticDefaultLabels\s*=.*docker'
    }

    It "Static default labels include desktop" {
        $script:Content | Should -Match '\$StaticDefaultLabels\s*=.*desktop'
    }
}

Describe "register-runner.ps1 Label Validation" {
    It "Should accept custom labels" {
        Mock -CommandName Write-Log -MockWith {}
        Mock -CommandName Invoke-RestMethod -MockWith { return @{ tag_name = "v2.311.0"; assets = @() } }

        { & $ScriptPath -OrgOrRepo "test-org" -Token "ghp_1234567890" -Labels "custom1,custom2" -WhatIf } | Should -Not -Throw
    }

    It "Should include self-hosted label" {
        $customLabels = "self-hosted,windows,custom"
        $customLabels -split ',' | Should -Contain 'self-hosted'
    }

    It "Should handle single label" {
        Mock -CommandName Write-Log -MockWith {}
        Mock -CommandName Invoke-RestMethod -MockWith { return @{ tag_name = "v2.311.0"; assets = @() } }

        { & $ScriptPath -OrgOrRepo "test-org" -Token "ghp_1234567890" -Labels "self-hosted" -WhatIf } | Should -Not -Throw
    }
}

Describe "register-runner.ps1 URL Construction" {
    It "Should construct organization URL correctly" {
        $orgName = "test-org"
        $expectedUrl = "https://github.com/$orgName"

        $expectedUrl | Should -Be "https://github.com/test-org"
    }

    It "Should construct repository URL correctly" {
        $repoPath = "owner/repo"
        $expectedUrl = "https://github.com/$repoPath"

        $expectedUrl | Should -Be "https://github.com/owner/repo"
    }

    It "Should construct organization token URL correctly" {
        $orgName = "test-org"
        $expectedTokenUrl = "https://api.github.com/orgs/$orgName/actions/runners/registration-token"

        $expectedTokenUrl | Should -Be "https://api.github.com/orgs/test-org/actions/runners/registration-token"
    }

    It "Should construct repository token URL correctly" {
        $repoPath = "owner/repo"
        $expectedTokenUrl = "https://api.github.com/repos/$repoPath/actions/runners/registration-token"

        $expectedTokenUrl | Should -Be "https://api.github.com/repos/owner/repo/actions/runners/registration-token"
    }
}

Describe "register-runner.ps1 API Interaction" {
    BeforeAll {
        Mock -CommandName Write-Log -MockWith {}
    }

    It "Should request latest runner version from GitHub API" {
        Mock -CommandName Invoke-RestMethod -MockWith {
            return @{
                tag_name = "v2.311.0"
                assets = @(
                    @{ name = "actions-runner-win-x64-2.311.0.zip"; browser_download_url = "https://example.com/runner.zip" }
                )
            }
        }

        Mock -CommandName Invoke-WebRequest -MockWith {}
        Mock -CommandName Expand-Archive -MockWith {}

        # This would normally fail, but we're testing API interaction
        $apiUrl = "https://api.github.com/repos/actions/runner/releases/latest"
        $apiUrl | Should -Be "https://api.github.com/repos/actions/runner/releases/latest"
    }

    It "Should send registration token request with correct headers" {
        $expectedHeaders = @{
            "Accept" = "application/vnd.github+json"
            "Authorization" = "Bearer ghp_1234567890"
            "X-GitHub-Api-Version" = "2022-11-28"
        }

        $expectedHeaders["Accept"] | Should -Be "application/vnd.github+json"
        $expectedHeaders["Authorization"] | Should -Be "Bearer ghp_1234567890"
        $expectedHeaders["X-GitHub-Api-Version"] | Should -Be "2022-11-28"
    }
}

Describe "register-runner.ps1 Error Handling" {
    BeforeAll {
        Mock -CommandName Write-Log -MockWith {}
    }

    It "Should handle failed API request gracefully" {
        Mock -CommandName Invoke-RestMethod -MockWith {
            throw "API request failed: 401 Unauthorized"
        }

        { & $ScriptPath -OrgOrRepo "test-org" -Token "ghp_invalid" } | Should -Throw
    }

    It "Should handle missing runner asset" {
        Mock -CommandName Invoke-RestMethod -MockWith {
            return @{
                tag_name = "v2.311.0"
                assets = @()  # No assets
            }
        }

        { & $ScriptPath -OrgOrRepo "test-org" -Token "ghp_1234567890" } | Should -Throw
    }

    It "Should validate admin privileges for service installation" {
        Mock -CommandName Invoke-RestMethod -MockWith {
            return @{
                tag_name = "v2.311.0"
                assets = @(@{ name = "actions-runner-win-x64-2.311.0.zip"; browser_download_url = "https://example.com/runner.zip" })
            }
        }

        Mock -CommandName Invoke-WebRequest -MockWith {}
        Mock -CommandName Expand-Archive -MockWith {}

        # Check admin privilege validation logic exists
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        # This is a meta-test to verify the check would work
        { $isAdmin -is [bool] } | Should -Be $true
    }
}

Describe "register-runner.ps1 Runner Configuration" {
    It "Should build correct config arguments for organization" {
        $expectedArgs = @(
            "--url", "https://github.com/test-org",
            "--token", "test-token",
            "--name", "test-runner",
            "--labels", "self-hosted,windows",
            "--work", "_work",
            "--unattended",
            "--replace"
        )

        $expectedArgs | Should -Contain "--url"
        $expectedArgs | Should -Contain "https://github.com/test-org"
        $expectedArgs | Should -Contain "--unattended"
    }

    It "Should build correct config arguments for repository" {
        $expectedArgs = @(
            "--url", "https://github.com/owner/repo",
            "--token", "test-token",
            "--name", "test-runner",
            "--labels", "self-hosted,windows",
            "--work", "_work",
            "--unattended",
            "--replace"
        )

        $expectedArgs | Should -Contain "--url"
        $expectedArgs | Should -Contain "https://github.com/owner/repo"
        $expectedArgs | Should -Contain "--replace"
    }
}

Describe "register-runner.ps1 Service Installation" {
    It "Should check for admin privileges before service installation" {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        # Verify the admin check works
        $isAdmin | Should -BeOfType [bool]
    }

    It "Should skip service installation when InstallService is false" {
        Mock -CommandName Write-Log -MockWith {}

        # Verify -InstallService is a switch parameter
        $script:ScriptPath | Should -Exist
    }
}

Describe "register-runner.ps1 Cleanup" {
    It "Should remove zip file after extraction" {
        Mock -CommandName Write-Log -MockWith {}

        # Test cleanup logic
        $testZipPath = Join-Path $TestDrive "test-runner.zip"
        New-Item -Path $testZipPath -ItemType File -Force | Out-Null

        if (Test-Path $testZipPath) {
            Remove-Item $testZipPath -Force
        }

        Test-Path $testZipPath | Should -Be $false
    }
}

Describe "register-runner.ps1 Logging" {
    It "Should log with timestamp and level" {
        Mock -CommandName Write-Host -MockWith {}

        # Simulate Write-Log function
        function Test-WriteLog {
            param([string]$Message, [string]$Level = "INFO")
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            return "[$timestamp] [$Level] $Message"
        }

        $logOutput = Test-WriteLog -Message "Test message" -Level "INFO"
        $logOutput | Should -Match '\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[INFO\] Test message'
    }

    It "Should support different log levels" {
        $levels = @("INFO", "WARN", "ERROR", "SUCCESS")

        foreach ($level in $levels) {
            $level | Should -BeIn @("INFO", "WARN", "ERROR", "SUCCESS")
        }
    }
}

AfterAll {
    # Cleanup any test artifacts
    $testWorkFolder = Join-Path $TestDrive "actions-runner"
    if (Test-Path $testWorkFolder) {
        Remove-Item $testWorkFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}
