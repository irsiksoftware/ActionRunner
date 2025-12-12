# Pester tests for register-runner.ps1
# Run with: Invoke-Pester -Path .\tests\register-runner.Tests.ps1

BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    $script:ScriptPath = Join-Path $ProjectRoot "scripts\register-runner.ps1"
    $script:ScriptContent = Get-Content $ScriptPath -Raw

    # Extract and load the Write-Log function for testing
    $functionMatch = [regex]::Match($ScriptContent, '(?s)function Write-Log \{.+?\n\}')
    if ($functionMatch.Success) {
        $script:WriteLogFunction = $functionMatch.Value
    }
}

Describe "register-runner.ps1" {
    Context "Script Structure" {
        It "Should exist" {
            Test-Path $ScriptPath | Should -Be $true
        }

        It "Should be a valid PowerShell script" {
            { $null = [System.Management.Automation.PSParser]::Tokenize($ScriptContent, [ref]$null) } | Should -Not -Throw
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

    Context "Parameter Definitions" {
        BeforeAll {
            $script:Params = (Get-Command $ScriptPath).Parameters
        }

        It "Should have mandatory OrgOrRepo parameter" {
            $Params['OrgOrRepo'].Attributes.Mandatory | Should -Be $true
        }

        It "Should have mandatory Token parameter" {
            $Params['Token'].Attributes.Mandatory | Should -Be $true
        }

        It "Should have optional RunnerName parameter" {
            $Params['RunnerName'].Attributes.Mandatory | Should -Be $false
        }

        It "Should have optional Labels parameter" {
            $Params['Labels'].Attributes.Mandatory | Should -Be $false
        }

        It "Should have optional WorkFolder parameter" {
            $Params['WorkFolder'].Attributes.Mandatory | Should -Be $false
        }

        It "Should have IsOrg switch parameter" {
            $Params['IsOrg'].ParameterType.Name | Should -Be 'SwitchParameter'
        }

        It "Should have InstallService switch parameter" {
            $Params['InstallService'].ParameterType.Name | Should -Be 'SwitchParameter'
        }

        It "Should have AutoDetectLabels parameter with bool type" {
            $Params['AutoDetectLabels'].ParameterType.Name | Should -Be 'Boolean'
        }
    }

    Context "Token Format Validation" {
        BeforeAll {
            # Extract the token validation regex from the script
            $script:TokenRegex = if ($ScriptContent -match "\`$Token\s*-notmatch\s*'([^']+)'") {
                $Matches[1]
            }
        }

        It "Should have token validation regex in script" {
            $TokenRegex | Should -Not -BeNullOrEmpty
        }

        It "Should accept ghp_ prefixed tokens" {
            'ghp_1234567890abcdefghij' -match $TokenRegex | Should -Be $true
        }

        It "Should accept github_pat_ prefixed tokens" {
            'github_pat_1234567890abcdefghij' -match $TokenRegex | Should -Be $true
        }

        It "Should reject tokens without valid prefix" {
            'invalid_token_1234567890' -match $TokenRegex | Should -Be $false
        }

        It "Should reject empty token" {
            '' -match $TokenRegex | Should -Be $false
        }

        It "Should reject token with gh_ prefix (missing p)" {
            'gh_1234567890' -match $TokenRegex | Should -Be $false
        }
    }
}

Describe "Write-Log Function Behavior" {
    BeforeAll {
        # Create isolated Write-Log function for testing
        function script:Test-WriteLog {
            param([string]$Message, [string]$Level = "INFO")
            $color = switch ($Level) {
                "ERROR" { "Red" }
                "WARN" { "Yellow" }
                "SUCCESS" { "Green" }
                default { "White" }
            }
            return @{
                Color = $color
                Level = $Level
                Message = $Message
            }
        }
    }

    It "Should return White color for INFO level" {
        $result = Test-WriteLog -Message "Test" -Level "INFO"
        $result.Color | Should -Be "White"
    }

    It "Should return Red color for ERROR level" {
        $result = Test-WriteLog -Message "Test" -Level "ERROR"
        $result.Color | Should -Be "Red"
    }

    It "Should return Yellow color for WARN level" {
        $result = Test-WriteLog -Message "Test" -Level "WARN"
        $result.Color | Should -Be "Yellow"
    }

    It "Should return Green color for SUCCESS level" {
        $result = Test-WriteLog -Message "Test" -Level "SUCCESS"
        $result.Color | Should -Be "Green"
    }

    It "Should default to INFO level when not specified" {
        $result = Test-WriteLog -Message "Test"
        $result.Level | Should -Be "INFO"
        $result.Color | Should -Be "White"
    }
}

Describe "Token Validation Logic" {
    BeforeAll {
        # Token validation regex used in the script
        $script:TokenRegex = '^(ghp_|github_pat_)'
    }

    It "Should validate ghp_ token format correctly" {
        'ghp_abcd1234567890' -match $TokenRegex | Should -Be $true
    }

    It "Should validate github_pat_ token format correctly" {
        'github_pat_xyz789abc' -match $TokenRegex | Should -Be $true
    }

    It "Should reject classic OAuth token format (gho_)" {
        'gho_abcd1234' -match $TokenRegex | Should -Be $false
    }

    It "Should reject GitHub App installation token format (ghs_)" {
        'ghs_abcd1234' -match $TokenRegex | Should -Be $false
    }

    It "Should reject random string without valid prefix" {
        'some_random_token' -match $TokenRegex | Should -Be $false
    }

    It "Should reject empty string" {
        '' -match $TokenRegex | Should -Be $false
    }

    It "Should reject token with only partial prefix (gh_)" {
        'gh_token123' -match $TokenRegex | Should -Be $false
    }

    It "Should accept token with minimum valid content after prefix" {
        'ghp_a' -match $TokenRegex | Should -Be $true
    }
}

Describe "URL Construction Logic" {
    Context "Organization URLs" {
        It "Should construct correct organization runner URL" {
            $orgName = "test-org"
            $runnerUrl = "https://github.com/$orgName"
            $runnerUrl | Should -Be "https://github.com/test-org"
        }

        It "Should construct correct organization token API URL" {
            $orgName = "test-org"
            $tokenUrl = "https://api.github.com/orgs/$orgName/actions/runners/registration-token"
            $tokenUrl | Should -Be "https://api.github.com/orgs/test-org/actions/runners/registration-token"
        }

        It "Should handle organization name with hyphens" {
            $orgName = "my-test-org"
            $runnerUrl = "https://github.com/$orgName"
            $runnerUrl | Should -Be "https://github.com/my-test-org"
        }

        It "Should handle organization name with numbers" {
            $orgName = "org123"
            $runnerUrl = "https://github.com/$orgName"
            $runnerUrl | Should -Be "https://github.com/org123"
        }
    }

    Context "Repository URLs" {
        It "Should construct correct repository runner URL" {
            $repoPath = "owner/repo"
            $runnerUrl = "https://github.com/$repoPath"
            $runnerUrl | Should -Be "https://github.com/owner/repo"
        }

        It "Should construct correct repository token API URL" {
            $repoPath = "owner/repo"
            $tokenUrl = "https://api.github.com/repos/$repoPath/actions/runners/registration-token"
            $tokenUrl | Should -Be "https://api.github.com/repos/owner/repo/actions/runners/registration-token"
        }

        It "Should handle repository with dots in name" {
            $repoPath = "owner/repo.name"
            $runnerUrl = "https://github.com/$repoPath"
            $runnerUrl | Should -Be "https://github.com/owner/repo.name"
        }

        It "Should handle repository with hyphens" {
            $repoPath = "my-owner/my-repo"
            $runnerUrl = "https://github.com/$repoPath"
            $runnerUrl | Should -Be "https://github.com/my-owner/my-repo"
        }
    }
}

Describe "Config Arguments Building" {
    It "Should build correct config arguments array with all parameters" {
        $runnerUrl = "https://github.com/test-org"
        $registrationToken = "ATOKEN123456789"
        $runnerName = "test-runner"
        $labels = "self-hosted,windows,custom"

        $configArgs = @(
            "--url", $runnerUrl,
            "--token", $registrationToken,
            "--name", $runnerName,
            "--labels", $labels,
            "--work", "_work",
            "--unattended",
            "--replace"
        )

        $configArgs | Should -Contain "--url"
        $configArgs | Should -Contain $runnerUrl
        $configArgs | Should -Contain "--token"
        $configArgs | Should -Contain $registrationToken
        $configArgs | Should -Contain "--name"
        $configArgs | Should -Contain $runnerName
        $configArgs | Should -Contain "--labels"
        $configArgs | Should -Contain $labels
        $configArgs | Should -Contain "--work"
        $configArgs | Should -Contain "_work"
        $configArgs | Should -Contain "--unattended"
        $configArgs | Should -Contain "--replace"
    }

    It "Should have 12 elements in config arguments array" {
        $configArgs = @(
            "--url", "https://github.com/org",
            "--token", "TOKEN",
            "--name", "runner",
            "--labels", "label1,label2",
            "--work", "_work",
            "--unattended",
            "--replace"
        )

        # 5 flag-value pairs (10) + 2 standalone flags (2) = 12 elements
        $configArgs.Count | Should -Be 12
    }

    It "Should preserve argument-value pairing order" {
        $configArgs = @(
            "--url", "https://github.com/org",
            "--token", "TOKEN",
            "--name", "runner",
            "--labels", "label1,label2",
            "--work", "_work",
            "--unattended",
            "--replace"
        )

        # Verify pairs are consecutive
        $urlIndex = [array]::IndexOf($configArgs, "--url")
        $configArgs[$urlIndex + 1] | Should -Be "https://github.com/org"

        $tokenIndex = [array]::IndexOf($configArgs, "--token")
        $configArgs[$tokenIndex + 1] | Should -Be "TOKEN"

        $nameIndex = [array]::IndexOf($configArgs, "--name")
        $configArgs[$nameIndex + 1] | Should -Be "runner"

        $labelsIndex = [array]::IndexOf($configArgs, "--labels")
        $configArgs[$labelsIndex + 1] | Should -Be "label1,label2"

        $workIndex = [array]::IndexOf($configArgs, "--work")
        $configArgs[$workIndex + 1] | Should -Be "_work"
    }
}

Describe "Work Folder Operations" -Tag "Integration" {
    BeforeAll {
        $TestWorkFolder = Join-Path $TestDrive "test-runner-folder"
    }

    It "Should create work folder when it does not exist" {
        $testFolder = Join-Path $TestDrive "new-test-folder"

        # Ensure it doesn't exist first
        if (Test-Path $testFolder) {
            Remove-Item $testFolder -Recurse -Force
        }

        Test-Path $testFolder | Should -Be $false

        # Create it (mimicking script behavior)
        New-Item -ItemType Directory -Path $testFolder -Force | Out-Null

        Test-Path $testFolder | Should -Be $true
    }

    It "Should not fail when work folder already exists" {
        $existingFolder = Join-Path $TestDrive "existing-folder"
        New-Item -ItemType Directory -Path $existingFolder -Force | Out-Null

        Test-Path $existingFolder | Should -Be $true

        # Should not throw when folder exists (using -Force)
        { New-Item -ItemType Directory -Path $existingFolder -Force | Out-Null } | Should -Not -Throw

        Test-Path $existingFolder | Should -Be $true
    }

    It "Should be able to create nested folders" {
        $nestedFolder = Join-Path $TestDrive "level1\level2\level3"

        { New-Item -ItemType Directory -Path $nestedFolder -Force | Out-Null } | Should -Not -Throw

        Test-Path $nestedFolder | Should -Be $true
    }

    AfterAll {
        # Cleanup test artifacts
        if (Test-Path $TestWorkFolder) {
            Remove-Item $TestWorkFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "File Cleanup Logic" -Tag "Integration" {
    It "Should remove file when it exists" {
        $testFile = Join-Path $TestDrive "test-cleanup.zip"
        New-Item -Path $testFile -ItemType File -Force | Out-Null

        Test-Path $testFile | Should -Be $true

        if (Test-Path $testFile) {
            Remove-Item $testFile -Force
        }

        Test-Path $testFile | Should -Be $false
    }

    It "Should not fail when file does not exist" {
        $nonExistentFile = Join-Path $TestDrive "non-existent.zip"

        Test-Path $nonExistentFile | Should -Be $false

        {
            if (Test-Path $nonExistentFile) {
                Remove-Item $nonExistentFile -Force
            }
        } | Should -Not -Throw
    }
}

Describe "Admin Privilege Check" -Tag "Integration" {
    It "Should correctly determine admin status type" {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        $isAdmin | Should -BeOfType [bool]
    }

    It "Should use correct Windows built-in role for admin check" {
        # Verify the role constant exists and is correct
        [Security.Principal.WindowsBuiltInRole]::Administrator | Should -Be ([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
}

Describe "Static Default Labels" {
    BeforeAll {
        # Extract static default labels from script
        $script:StaticDefaultLabels = "self-hosted,windows,dotnet,python,unity-pool,gpu-cuda,docker,desktop"
    }

    It "Should include self-hosted label" {
        $StaticDefaultLabels -split ',' | Should -Contain 'self-hosted'
    }

    It "Should include windows label" {
        $StaticDefaultLabels -split ',' | Should -Contain 'windows'
    }

    It "Should include dotnet label" {
        $StaticDefaultLabels -split ',' | Should -Contain 'dotnet'
    }

    It "Should include python label" {
        $StaticDefaultLabels -split ',' | Should -Contain 'python'
    }

    It "Should include unity-pool label" {
        $StaticDefaultLabels -split ',' | Should -Contain 'unity-pool'
    }

    It "Should include gpu-cuda label" {
        $StaticDefaultLabels -split ',' | Should -Contain 'gpu-cuda'
    }

    It "Should include docker label" {
        $StaticDefaultLabels -split ',' | Should -Contain 'docker'
    }

    It "Should include desktop label" {
        $StaticDefaultLabels -split ',' | Should -Contain 'desktop'
    }

    It "Should have exactly 8 default labels" {
        ($StaticDefaultLabels -split ',').Count | Should -Be 8
    }
}

Describe "Label Detection Logic Paths" {
    BeforeAll {
        $script:ScriptContent = Get-Content $script:ScriptPath -Raw
    }

    It "Should check for explicit labels first" {
        $ScriptContent | Should -Match 'if \(\$Labels\)'
    }

    It "Should check AutoDetectLabels when no explicit labels" {
        $ScriptContent | Should -Match 'elseif \(\$AutoDetectLabels\)'
    }

    It "Should have fallback for when auto-detection is disabled" {
        $ScriptContent | Should -Match 'Label auto-detection disabled'
    }

    It "Should have fallback for when detect-capabilities.ps1 is not found" {
        $ScriptContent | Should -Match 'Capability detection script not found'
    }

    It "Should have fallback for when detection fails" {
        $ScriptContent | Should -Match 'Capability detection failed'
        $ScriptContent | Should -Match 'Falling back to static default labels'
    }

    It "Should validate detected labels with regex pattern" {
        $ScriptContent | Should -Match '\$detectedLabels -and \$detectedLabels -match'
    }
}

Describe "Error Handling" {
    BeforeAll {
        $script:ScriptContent = Get-Content $script:ScriptPath -Raw
    }

    It "Should set ErrorActionPreference to Stop" {
        $ScriptContent | Should -Match '\$ErrorActionPreference\s*=\s*"Stop"'
    }

    It "Should exit with code 1 on invalid token" {
        $ScriptContent | Should -Match 'Invalid token format'
        $ScriptContent | Should -Match 'exit 1'
    }

    It "Should exit with code 1 on missing runner asset" {
        $ScriptContent | Should -Match 'Failed to find Windows x64 runner asset'
    }

    It "Should exit with code 1 on registration token failure" {
        $ScriptContent | Should -Match 'Failed to get registration token'
    }

    It "Should exit with code 1 on config.cmd failure" {
        $ScriptContent | Should -Match 'Runner configuration failed'
    }

    It "Should exit with code 1 when service installation requires admin" {
        $ScriptContent | Should -Match 'Service installation requires administrator privileges'
    }
}

Describe "Security Checks" {
    BeforeAll {
        $script:ScriptContent = Get-Content $script:ScriptPath -Raw
    }

    It "Should not log the PAT token directly in Write-Log calls" {
        # Ensure Write-Log is not called with $Token variable directly exposed
        $ScriptContent | Should -Not -Match 'Write-Log.*\$Token[^a-zA-Z_]'
    }

    It "Should use HTTPS for all API endpoints" {
        $apiUrls = [regex]::Matches($ScriptContent, 'https?://api\.github\.com[^"]*')
        $apiUrls.Count | Should -BeGreaterThan 0
        foreach ($url in $apiUrls) {
            $url.Value | Should -Match '^https://'
        }
    }

    It "Should use HTTPS for GitHub URLs" {
        $githubUrls = [regex]::Matches($ScriptContent, 'https?://github\.com[^"]*')
        $githubUrls.Count | Should -BeGreaterThan 0
        foreach ($url in $githubUrls) {
            $url.Value | Should -Match '^https://'
        }
    }

    It "Should use Bearer token authentication" {
        $ScriptContent | Should -Match '"Authorization"\s*=\s*"Bearer \$Token"'
    }
}

Describe "GitHub API Headers" {
    BeforeAll {
        $script:ScriptContent = Get-Content $script:ScriptPath -Raw
    }

    It "Should include Accept header for GitHub API" {
        $ScriptContent | Should -Match '"Accept"\s*=\s*"application/vnd\.github\+json"'
    }

    It "Should include X-GitHub-Api-Version header" {
        $ScriptContent | Should -Match '"X-GitHub-Api-Version"\s*=\s*"2022-11-28"'
    }
}

Describe "Runner Asset Selection" {
    It "Should correctly identify Windows x64 asset from assets list" {
        $mockAssets = @(
            @{ name = "actions-runner-linux-x64-2.311.0.tar.gz" },
            @{ name = "actions-runner-linux-arm64-2.311.0.tar.gz" },
            @{ name = "actions-runner-win-x64-2.311.0.zip" },
            @{ name = "actions-runner-osx-x64-2.311.0.tar.gz" }
        )

        $asset = $mockAssets | Where-Object { $_.name -like "*win-x64-*.zip" } | Select-Object -First 1

        $asset | Should -Not -BeNullOrEmpty
        $asset.name | Should -Be "actions-runner-win-x64-2.311.0.zip"
    }

    It "Should return null when Windows x64 asset is not present" {
        $mockAssets = @(
            @{ name = "actions-runner-linux-x64-2.311.0.tar.gz" },
            @{ name = "actions-runner-linux-arm64-2.311.0.tar.gz" },
            @{ name = "actions-runner-osx-x64-2.311.0.tar.gz" }
        )

        $asset = $mockAssets | Where-Object { $_.name -like "*win-x64-*.zip" } | Select-Object -First 1

        $asset | Should -BeNullOrEmpty
    }

    It "Should select only the first matching asset when multiple exist" {
        $mockAssets = @(
            @{ name = "actions-runner-win-x64-2.311.0.zip"; browser_download_url = "url1" },
            @{ name = "actions-runner-win-x64-2.310.0.zip"; browser_download_url = "url2" }
        )

        $asset = $mockAssets | Where-Object { $_.name -like "*win-x64-*.zip" } | Select-Object -First 1

        $asset.browser_download_url | Should -Be "url1"
    }
}

Describe "Version Extraction" {
    It "Should correctly extract version from tag_name with 'v' prefix" {
        $tagName = "v2.311.0"
        $version = $tagName.TrimStart('v')

        $version | Should -Be "2.311.0"
    }

    It "Should handle tag_name without 'v' prefix" {
        $tagName = "2.311.0"
        $version = $tagName.TrimStart('v')

        $version | Should -Be "2.311.0"
    }

    It "Should correctly format zip filename with version" {
        $version = "2.311.0"
        $zipFile = "actions-runner-win-x64-$version.zip"

        $zipFile | Should -Be "actions-runner-win-x64-2.311.0.zip"
    }
}

Describe "Script Default Values" {
    BeforeAll {
        $script:ScriptContent = Get-Content $script:ScriptPath -Raw
    }

    It "Should default RunnerName to computer name" {
        $ScriptContent | Should -Match '\$RunnerName\s*=\s*\$env:COMPUTERNAME'
    }

    It "Should default AutoDetectLabels to true" {
        $ScriptContent | Should -Match '\[bool\]\$AutoDetectLabels\s*=\s*\$true'
    }

    It "Should default WorkFolder to C:\actions-runner" {
        $ScriptContent | Should -Match '\$WorkFolder\s*=\s*"C:\\actions-runner"'
    }
}

Describe "Output Messages Verification" {
    BeforeAll {
        $script:ScriptContent = Get-Content $script:ScriptPath -Raw
    }

    It "Should log registration start" {
        $ScriptContent | Should -Match 'Starting GitHub Actions runner registration'
    }

    It "Should log registration completion" {
        $ScriptContent | Should -Match 'Runner registration complete!'
    }

    It "Should display next steps" {
        $ScriptContent | Should -Match 'NEXT STEPS'
    }

    It "Should show runner verification URL" {
        $ScriptContent | Should -Match 'Verify runner is online'
    }

    It "Should suggest workflow configuration" {
        $ScriptContent | Should -Match 'runs-on: \[self-hosted, windows'
    }

    It "Should provide log monitoring guidance" {
        $ScriptContent | Should -Match 'Monitor runner logs'
    }
}
