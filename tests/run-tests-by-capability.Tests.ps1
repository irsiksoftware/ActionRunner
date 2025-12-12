BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot "..\scripts\run-tests-by-capability.ps1"

    # Mock Invoke-Pester to prevent actual test execution
    Mock Invoke-Pester {
        return [PSCustomObject]@{
            TotalCount = 10
            PassedCount = 8
            FailedCount = 2
            SkippedCount = 0
        }
    }

    # Mock New-PesterConfiguration
    Mock New-PesterConfiguration {
        return [PSCustomObject]@{
            Run = [PSCustomObject]@{
                Path = @()
                PassThru = $false
                Exit = $false
            }
            Output = [PSCustomObject]@{
                Verbosity = 'Normal'
            }
        }
    }
}

Describe "run-tests-by-capability.ps1 - Parameter Validation" {
    It "Should accept valid capability value 'All'" {
        { & $scriptPath -Capability 'All' -WhatIf } | Should -Not -Throw
    }

    It "Should accept valid capability value 'Core'" {
        { & $scriptPath -Capability 'Core' -WhatIf } | Should -Not -Throw
    }

    It "Should accept valid capability value 'WebApp'" {
        { & $scriptPath -Capability 'WebApp' -WhatIf } | Should -Not -Throw
    }

    It "Should accept valid capability value 'Docker'" {
        { & $scriptPath -Capability 'Docker' -WhatIf } | Should -Not -Throw
    }

    It "Should accept valid capability value 'Mobile'" {
        { & $scriptPath -Capability 'Mobile' -WhatIf } | Should -Not -Throw
    }

    It "Should accept valid capability value 'AI'" {
        { & $scriptPath -Capability 'AI' -WhatIf } | Should -Not -Throw
    }

    It "Should accept valid capability value 'Integration'" {
        { & $scriptPath -Capability 'Integration' -WhatIf } | Should -Not -Throw
    }

    It "Should accept -CI switch" {
        { & $scriptPath -CI -WhatIf } | Should -Not -Throw
    }

    It "Should accept -DetailedOutput switch" {
        { & $scriptPath -DetailedOutput -WhatIf } | Should -Not -Throw
    }

    It "Should accept multiple parameters together" {
        { & $scriptPath -Capability 'Core' -CI -DetailedOutput -WhatIf } | Should -Not -Throw
    }
}

Describe "run-tests-by-capability.ps1 - Capability Bucket Structure" {
    BeforeAll {
        # Source the script to access internal structures
        $scriptContent = Get-Content $scriptPath -Raw
        # Extract the CapabilityBuckets definition
        $bucketMatch = $scriptContent -match '(?s)\$CapabilityBuckets = @\{(.+?)\n\}'
    }

    It "Should define Core capability bucket" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match "'Core'\s*=\s*@\{"
    }

    It "Should define WebApp capability bucket" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match "'WebApp'\s*=\s*@\{"
    }

    It "Should define Docker capability bucket" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match "'Docker'\s*=\s*@\{"
    }

    It "Should define Mobile capability bucket" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match "'Mobile'\s*=\s*@\{"
    }

    It "Should define AI capability bucket" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match "'AI'\s*=\s*@\{"
    }

    It "Should define Integration capability bucket" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match "'Integration'\s*=\s*@\{"
    }

    It "Should define Utilities capability bucket" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match "'Utilities'\s*=\s*@\{"
    }

    It "Core bucket should have required properties" {
        $scriptContent = Get-Content $scriptPath -Raw
        $coreSection = ($scriptContent -split "'Core'\s*=\s*@\{")[1] -split "'WebApp'")[0]
        $coreSection | Should -Match "Name\s*="
        $coreSection | Should -Match "Description\s*="
        $coreSection | Should -Match "Tags\s*="
        $coreSection | Should -Match "Tests\s*="
        $coreSection | Should -Match "Icon\s*="
    }

    It "Core bucket should include setup-runner.Tests.ps1" {
        $scriptContent = Get-Content $scriptPath -Raw
        $coreSection = ($scriptContent -split "'Core'\s*=\s*@\{")[1] -split "'WebApp'")[0]
        $coreSection | Should -Match "setup-runner\.Tests\.ps1"
    }
}

Describe "run-tests-by-capability.ps1 - Test File Path Resolution" {
    BeforeAll {
        # Create temporary test directory structure
        $tempTestDir = Join-Path $TestDrive "tests"
        New-Item -ItemType Directory -Path $tempTestDir -Force | Out-Null

        # Create mock test files
        @(
            'setup-runner.Tests.ps1'
            'apply-config.Tests.ps1'
            'verify-jesus-environment.Tests.ps1'
            'setup-docker.Tests.ps1'
        ) | ForEach-Object {
            New-Item -ItemType File -Path (Join-Path $tempTestDir $_) -Force | Out-Null
        }
    }

    It "Should construct correct test file paths" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match '\$testsPath\s*=\s*Join-Path\s+\$PSScriptRoot\s+"\\\.\.\\tests"'
    }

    It "Should use Join-Path for test file concatenation" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match '\$testFiles\s*=.*Join-Path\s+\$testsPath'
    }

    It "Should filter for existing test files" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match 'Where-Object\s*\{\s*Test-Path'
    }
}

Describe "run-tests-by-capability.ps1 - Pester Configuration" {
    It "Should create new PesterConfiguration" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match 'New-PesterConfiguration'
    }

    It "Should set Run.Path configuration" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match '\$config\.Run\.Path\s*='
    }

    It "Should enable PassThru for results" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match '\$config\.Run\.PassThru\s*=\s*\$true'
    }

    It "Should disable Exit to prevent premature termination" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match '\$config\.Run\.Exit\s*=\s*\$false'
    }

    It "Should set verbosity based on DetailedOutput parameter" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match '\$config\.Output\.Verbosity\s*=\s*if\s*\(\s*\$DetailedOutput\s*\)'
    }

    It "Should use 'Detailed' verbosity when DetailedOutput is specified" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match "if\s*\(\s*\$DetailedOutput\s*\)\s*\{\s*'Detailed'\s*\}"
    }

    It "Should use 'Normal' verbosity by default" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match "else\s*\{\s*'Normal'\s*\}"
    }
}

Describe "run-tests-by-capability.ps1 - Write-CapabilityHeader Function" {
    It "Should define Write-CapabilityHeader function" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match 'function\s+Write-CapabilityHeader'
    }

    It "Write-CapabilityHeader should accept Capability parameter" {
        $scriptContent = Get-Content $scriptPath -Raw
        $functionMatch = $scriptContent -match '(?s)function Write-CapabilityHeader \{(.+?)^}'
        $scriptContent | Should -Match 'param\(\s*\$Capability'
    }

    It "Write-CapabilityHeader should accept Bucket parameter" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match 'function Write-CapabilityHeader.*param.*\$Bucket'
    }

    It "Write-CapabilityHeader should output bucket icon" {
        $scriptContent = Get-Content $scriptPath -Raw
        $functionSection = ($scriptContent -split 'function Write-CapabilityHeader')[1] -split 'function Write-CapabilitySummary')[0]
        $functionSection | Should -Match '\$Bucket\.Icon'
    }

    It "Write-CapabilityHeader should output bucket name" {
        $scriptContent = Get-Content $scriptPath -Raw
        $functionSection = ($scriptContent -split 'function Write-CapabilityHeader')[1] -split 'function Write-CapabilitySummary')[0]
        $functionSection | Should -Match '\$Bucket\.Name'
    }

    It "Write-CapabilityHeader should output bucket description" {
        $scriptContent = Get-Content $scriptPath -Raw
        $functionSection = ($scriptContent -split 'function Write-CapabilityHeader')[1] -split 'function Write-CapabilitySummary')[0]
        $functionSection | Should -Match '\$Bucket\.Description'
    }
}

Describe "run-tests-by-capability.ps1 - Write-CapabilitySummary Function" {
    It "Should define Write-CapabilitySummary function" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match 'function\s+Write-CapabilitySummary'
    }

    It "Write-CapabilitySummary should accept Results parameter" {
        $scriptContent = Get-Content $scriptPath -Raw
        $functionSection = ($scriptContent -split 'function Write-CapabilitySummary')[1]
        $functionSection | Should -Match 'param\(\s*\$Results'
    }

    It "Should calculate overall passed count" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match '\$overallPassed'
    }

    It "Should calculate overall failed count" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match '\$overallFailed'
    }

    It "Should calculate pass rate percentage" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match '\$passRate.*\[math\]::Round'
    }

    It "Should handle zero total count when calculating pass rate" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match 'if\s*\(.*TotalCount\s*-gt\s*0\s*\)'
    }

    It "Should use checkmark for passing tests" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match '\[char\]0x2713'
    }

    It "Should use warning symbol for partial pass" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match '\[char\]0x26A0'
    }

    It "Should use X mark for failing tests" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match '\[char\]0x2717'
    }

    It "Should determine status based on failed count" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match 'if\s*\(.*FailedCount\s*-eq\s*0'
    }

    It "Should use Green color for passing tests" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match '"Green"'
    }

    It "Should use Yellow color for warnings" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match '"Yellow"'
    }

    It "Should use Red color for failures" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match '"Red"'
    }
}

Describe "run-tests-by-capability.ps1 - All Capabilities Mode" {
    It "Should check if Capability equals 'All'" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match "if\s*\(\s*\$Capability\s*-eq\s*'All'\s*\)"
    }

    It "Should iterate through all capability keys" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match "foreach\s*\(\s*\$capKey\s+in\s+@\("
    }

    It "Should include Core in capability iteration" {
        $scriptContent = Get-Content $scriptPath -Raw
        $allSection = ($scriptContent -split "if\s*\(\s*\$Capability\s*-eq\s*'All'\s*\)")[1] -split 'Write-CapabilitySummary')[0]
        $allSection | Should -Match "'Core'"
    }

    It "Should include WebApp in capability iteration" {
        $scriptContent = Get-Content $scriptPath -Raw
        $allSection = ($scriptContent -split "if\s*\(\s*\$Capability\s*-eq\s*'All'\s*\)")[1] -split 'Write-CapabilitySummary')[0]
        $allSection | Should -Match "'WebApp'"
    }

    It "Should include Docker in capability iteration" {
        $scriptContent = Get-Content $scriptPath -Raw
        $allSection = ($scriptContent -split "if\s*\(\s*\$Capability\s*-eq\s*'All'\s*\)")[1] -split 'Write-CapabilitySummary')[0]
        $allSection | Should -Match "'Docker'"
    }

    It "Should skip capabilities with no tests" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match 'if\s*\(.*Tests\.Count\s*-eq\s*0\s*\)'
    }

    It "Should call Write-CapabilitySummary after all capabilities" {
        $scriptContent = Get-Content $scriptPath -Raw
        $allSection = ($scriptContent -split "if\s*\(\s*\$Capability\s*-eq\s*'All'\s*\)")[1]
        $allSection | Should -Match 'Write-CapabilitySummary\s+-Results'
    }

    It "Should collect results for each capability" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match '\$results\s*\+=\s*@\{'
    }
}

Describe "run-tests-by-capability.ps1 - Single Capability Mode" {
    It "Should have else branch for single capability" {
        $scriptContent = Get-Content $scriptPath -Raw
        # Find the main if/else structure
        $scriptContent | Should -Match '(?s)Write-CapabilitySummary.*?\}\s*else\s*\{'
    }

    It "Should retrieve bucket for specified capability" {
        $scriptContent = Get-Content $scriptPath -Raw
        $elseSection = ($scriptContent -split 'Write-CapabilitySummary -Results \$results')[1] -split '# Export results')[0]
        $elseSection | Should -Match '\$bucket\s*=\s*\$CapabilityBuckets\[\$Capability\]'
    }

    It "Should check if bucket has tests defined" {
        $scriptContent = Get-Content $scriptPath -Raw
        $elseSection = ($scriptContent -split 'Write-CapabilitySummary -Results \$results')[1] -split '# Export results')[0]
        $elseSection | Should -Match 'if\s*\(\s*\$bucket\.Tests\.Count\s*-eq\s*0\s*\)'
    }

    It "Should exit with 0 if no tests defined" {
        $scriptContent = Get-Content $scriptPath -Raw
        $elseSection = ($scriptContent -split 'Write-CapabilitySummary -Results \$results')[1] -split '# Export results')[0]
        $elseSection | Should -Match 'exit\s+0'
    }

    It "Should call Write-CapabilityHeader for single capability" {
        $scriptContent = Get-Content $scriptPath -Raw
        $elseSection = ($scriptContent -split 'Write-CapabilitySummary -Results \$results')[1] -split '# Export results')[0]
        $elseSection | Should -Match 'Write-CapabilityHeader.*-Capability.*-Bucket'
    }

    It "Should invoke Pester for single capability" {
        $scriptContent = Get-Content $scriptPath -Raw
        $elseSection = ($scriptContent -split 'Write-CapabilitySummary -Results \$results')[1] -split '# Export results')[0]
        $elseSection | Should -Match 'Invoke-Pester\s+-Configuration'
    }

    It "Should calculate and display pass rate for single capability" {
        $scriptContent = Get-Content $scriptPath -Raw
        $elseSection = ($scriptContent -split 'Write-CapabilitySummary -Results \$results')[1] -split '# Export results')[0]
        $elseSection | Should -Match '\$passRate\s*=.*PassedCount.*TotalCount'
    }
}

Describe "run-tests-by-capability.ps1 - CI Mode JSON Export" {
    It "Should check for CI mode and All capability" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match "if\s*\(\s*\$CI\s+-and\s+\$Capability\s+-eq\s+'All'\s*\)"
    }

    It "Should create summary hashtable" {
        $scriptContent = Get-Content $scriptPath -Raw
        $ciSection = ($scriptContent -split '# Export results for CI')[1]
        $ciSection | Should -Match '\$summary\s*=\s*@\{'
    }

    It "Should include timestamp in summary" {
        $scriptContent = Get-Content $scriptPath -Raw
        $ciSection = ($scriptContent -split '# Export results for CI')[1]
        $ciSection | Should -Match "Timestamp\s*=\s*Get-Date.*-Format\s+'o'"
    }

    It "Should create Capabilities hashtable in summary" {
        $scriptContent = Get-Content $scriptPath -Raw
        $ciSection = ($scriptContent -split '# Export results for CI')[1]
        $ciSection | Should -Match 'Capabilities\s*=\s*@\{\}'
    }

    It "Should populate capability results" {
        $scriptContent = Get-Content $scriptPath -Raw
        $ciSection = ($scriptContent -split '# Export results for CI')[1]
        $ciSection | Should -Match '\$summary\.Capabilities\[\$result\.Capability\]'
    }

    It "Should include Name in capability results" {
        $scriptContent = Get-Content $scriptPath -Raw
        $ciSection = ($scriptContent -split '# Export results for CI')[1]
        $ciSection | Should -Match "Name\s*=\s*\$result\.Bucket\.Name"
    }

    It "Should include Total count in capability results" {
        $scriptContent = Get-Content $scriptPath -Raw
        $ciSection = ($scriptContent -split '# Export results for CI')[1]
        $ciSection | Should -Match "Total\s*=\s*\$result\.Result\.TotalCount"
    }

    It "Should include Passed count in capability results" {
        $scriptContent = Get-Content $scriptPath -Raw
        $ciSection = ($scriptContent -split '# Export results for CI')[1]
        $ciSection | Should -Match "Passed\s*=\s*\$result\.Result\.PassedCount"
    }

    It "Should include Failed count in capability results" {
        $scriptContent = Get-Content $scriptPath -Raw
        $ciSection = ($scriptContent -split '# Export results for CI')[1]
        $ciSection | Should -Match "Failed\s*=\s*\$result\.Result\.FailedCount"
    }

    It "Should include PassRate in capability results" {
        $scriptContent = Get-Content $scriptPath -Raw
        $ciSection = ($scriptContent -split '# Export results for CI')[1]
        $ciSection | Should -Match "PassRate\s*=\s*\$passRate"
    }

    It "Should include Status in capability results" {
        $scriptContent = Get-Content $scriptPath -Raw
        $ciSection = ($scriptContent -split '# Export results for CI')[1]
        $ciSection | Should -Match "Status\s*="
    }

    It "Should set Status to 'Pass' for all passing tests" {
        $scriptContent = Get-Content $scriptPath -Raw
        $ciSection = ($scriptContent -split '# Export results for CI')[1]
        $ciSection | Should -Match "'Pass'"
    }

    It "Should set Status to 'Warning' for 80%25+ pass rate" {
        $scriptContent = Get-Content $scriptPath -Raw
        $ciSection = ($scriptContent -split '# Export results for CI')[1]
        $ciSection | Should -Match "'Warning'"
    }

    It "Should set Status to 'Fail' for low pass rate" {
        $scriptContent = Get-Content $scriptPath -Raw
        $ciSection = ($scriptContent -split '# Export results for CI')[1]
        $ciSection | Should -Match "'Fail'"
    }

    It "Should define output path for JSON file" {
        $scriptContent = Get-Content $scriptPath -Raw
        $ciSection = ($scriptContent -split '# Export results for CI')[1]
        $ciSection | Should -Match '\$outputPath\s*=\s*Join-Path'
    }

    It "Should write to test-capability-status.json" {
        $scriptContent = Get-Content $scriptPath -Raw
        $ciSection = ($scriptContent -split '# Export results for CI')[1]
        $ciSection | Should -Match 'test-capability-status\.json'
    }

    It "Should convert summary to JSON" {
        $scriptContent = Get-Content $scriptPath -Raw
        $ciSection = ($scriptContent -split '# Export results for CI')[1]
        $ciSection | Should -Match '\$summary.*ConvertTo-Json'
    }

    It "Should use Depth 10 for JSON conversion" {
        $scriptContent = Get-Content $scriptPath -Raw
        $ciSection = ($scriptContent -split '# Export results for CI')[1]
        $ciSection | Should -Match 'ConvertTo-Json\s+-Depth\s+10'
    }

    It "Should output JSON to file with UTF8 encoding" {
        $scriptContent = Get-Content $scriptPath -Raw
        $ciSection = ($scriptContent -split '# Export results for CI')[1]
        $ciSection | Should -Match 'Out-File.*-Encoding\s+UTF8'
    }

    It "Should display export confirmation message" {
        $scriptContent = Get-Content $scriptPath -Raw
        $ciSection = ($scriptContent -split '# Export results for CI')[1]
        $ciSection | Should -Match 'Write-Host.*Capability status exported'
    }
}

Describe "run-tests-by-capability.ps1 - Error Handling" {
    It "Should set ErrorActionPreference to Stop" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match "\`$ErrorActionPreference\s*=\s*'Stop'"
    }
}

Describe "run-tests-by-capability.ps1 - Capability Ordering" {
    It "Should process capabilities in specific order when running All" {
        $scriptContent = Get-Content $scriptPath -Raw
        $allSection = ($scriptContent -split "if\s*\(\s*\$Capability\s*-eq\s*'All'\s*\)")[1] -split 'Write-CapabilitySummary')[0]

        # Extract the array of capabilities
        if ($allSection -match "@\('Core',\s*'WebApp',\s*'Docker',\s*'Integration',\s*'Utilities',\s*'Mobile',\s*'AI'\)") {
            $true | Should -Be $true
        } else {
            # Check if at least Core comes before others
            $corePos = $allSection.IndexOf("'Core'")
            $webAppPos = $allSection.IndexOf("'WebApp'")
            $dockerPos = $allSection.IndexOf("'Docker'")

            $corePos | Should -BeLessThan $webAppPos
            $corePos | Should -BeLessThan $dockerPos
        }
    }
}

Describe "run-tests-by-capability.ps1 - Status Symbols and Thresholds" {
    It "Should use 80%25 threshold for warning status" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match '\$passRate\s+-ge\s+80'
    }

    It "Should use 90%25 threshold for overall green status in single capability mode" {
        $scriptContent = Get-Content $scriptPath -Raw
        $elseSection = ($scriptContent -split 'Write-CapabilitySummary -Results \$results')[1]
        $elseSection | Should -Match '\$totalPassRate\s+-ge\s+90'
    }

    It "Should use 70%25 threshold for overall yellow status" {
        $scriptContent = Get-Content $scriptPath -Raw
        $elseSection = ($scriptContent -split 'Write-CapabilitySummary -Results \$results')[1]
        $elseSection | Should -Match '\$totalPassRate\s+-ge\s+70'
    }
}

Describe "run-tests-by-capability.ps1 - Test File Filtering" {
    It "Should skip capability if no existing test files found" {
        $scriptContent = Get-Content $scriptPath -Raw
        $allSection = ($scriptContent -split "if\s*\(\s*\$Capability\s*-eq\s*'All'\s*\)")[1] -split 'Write-CapabilitySummary')[0]
        $allSection | Should -Match 'if\s*\(\s*\$existingTests\.Count\s*-eq\s*0\s*\)'
    }

    It "Should display message when no test files found" {
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent | Should -Match 'No test files found'
    }
}
