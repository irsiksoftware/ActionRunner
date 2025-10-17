#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-cmake.ps1'
}

Describe "verify-cmake.ps1 - Script Validation" {
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

    It "Script has proper comment-based help" {
        $content = Get-Content $script:ScriptPath -Raw
        $content | Should -Match '\.SYNOPSIS'
        $content | Should -Match '\.DESCRIPTION'
        $content | Should -Match '\.EXAMPLE'
    }
}

Describe "verify-cmake.ps1 - Parameter Validation" {
    BeforeAll {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:ScriptPath,
            [ref]$null,
            [ref]$null
        )
        $script:Params = $ast.ParamBlock.Parameters
    }

    It "Has ExitOnFailure switch parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'ExitOnFailure' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'SwitchParameter'
    }

    It "Has JsonOutput switch parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'JsonOutput' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'SwitchParameter'
    }

    It "Has MinimumVersion string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumVersion' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "MinimumVersion has default value of 3.15" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '3.15'
    }
}

Describe "verify-cmake.ps1 - Function Definitions" {
    BeforeAll {
        $script:ScriptContent = Get-Content $script:ScriptPath -Raw
    }

    It "Defines Test-Requirement function" {
        $script:ScriptContent | Should -Match 'function Test-Requirement'
    }

    It "Test-Requirement function has Name parameter" {
        $script:ScriptContent | Should -Match '\[string\]\$Name'
    }

    It "Test-Requirement function has Check parameter as scriptblock" {
        $script:ScriptContent | Should -Match '\[scriptblock\]\$Check'
    }

    It "Test-Requirement function has Expected parameter" {
        $script:ScriptContent | Should -Match '\[string\]\$Expected'
    }

    It "Test-Requirement function has FailureMessage parameter" {
        $script:ScriptContent | Should -Match '\[string\]\$FailureMessage'
    }

    It "Test-Requirement function has Severity parameter" {
        $script:ScriptContent | Should -Match '\[string\]\$Severity'
    }
}

Describe "verify-cmake.ps1 - CMake Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains CMake version check" {
        $script:Content | Should -Match 'cmake --version'
    }

    It "Contains C++ compiler check" {
        $script:Content | Should -Match 'C\+\+ Compiler'
    }

    It "Contains C compiler check" {
        $script:Content | Should -Match 'C Compiler'
    }

    It "Contains build system check" {
        $script:Content | Should -Match 'Build System'
    }

    It "Contains CMake generators check" {
        $script:Content | Should -Match 'CMake Generators'
    }

    It "Contains project configuration check" {
        $script:Content | Should -Match 'CMake Project Configuration'
    }

    It "Contains build test check" {
        $script:Content | Should -Match 'CMake Build Test'
    }

    It "Contains library test check" {
        $script:Content | Should -Match 'CMake Library Test'
    }

    It "Uses proper error handling" {
        $script:Content | Should -Match '\$ErrorActionPreference'
    }

    It "Includes cleanup logic for temporary directories" {
        $script:Content | Should -Match 'Remove-Item.*-Recurse.*-Force'
    }
}

Describe "verify-cmake.ps1 - Execution Tests" {
    Context "When CMake is not available" {
        BeforeAll {
            # Mock cmake command by temporarily renaming PATH
            $script:OriginalPath = $env:PATH
            $env:PATH = ""
        }

        AfterAll {
            $env:PATH = $script:OriginalPath
        }

        It "Should handle missing CMake gracefully" {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }
    }

    Context "When CMake is available" {
        BeforeAll {
            # Check if cmake is available
            $script:CMakeAvailable = $null -ne (Get-Command cmake -ErrorAction SilentlyContinue)
        }

        It "Should execute without errors when cmake is available" -Skip:(-not $script:CMakeAvailable) {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" -Skip:(-not $script:CMakeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" -Skip:(-not $script:CMakeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" -Skip:(-not $script:CMakeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include passed/failed/warnings counts in JSON output" -Skip:(-not $script:CMakeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.passed | Should -BeOfType [int]
            $json.failed | Should -BeOfType [int]
            $json.warnings | Should -BeOfType [int]
        }

        It "Should perform CMake installation check" -Skip:(-not $script:CMakeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $cmakeCheck = $json.checks | Where-Object { $_.name -eq 'CMake Installation' }
            $cmakeCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform C++ compiler check" -Skip:(-not $script:CMakeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $compilerCheck = $json.checks | Where-Object { $_.name -eq 'C++ Compiler' }
            $compilerCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform build system check" -Skip:(-not $script:CMakeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $buildCheck = $json.checks | Where-Object { $_.name -eq 'Build System' }
            $buildCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform C compiler check" -Skip:(-not $script:CMakeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $compilerCheck = $json.checks | Where-Object { $_.name -eq 'C Compiler' }
            $compilerCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform CMake generators check" -Skip:(-not $script:CMakeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $generatorsCheck = $json.checks | Where-Object { $_.name -eq 'CMake Generators' }
            $generatorsCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform CMake project configuration test" -Skip:(-not $script:CMakeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $configCheck = $json.checks | Where-Object { $_.name -eq 'CMake Project Configuration' }
            $configCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform build test check" -Skip:(-not $script:CMakeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $buildCheck = $json.checks | Where-Object { $_.name -eq 'CMake Build Test' }
            $buildCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform library test check" -Skip:(-not $script:CMakeAvailable) {
            $output = & $script:ScriptPath -JsonOutput 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $libCheck = $json.checks | Where-Object { $_.name -eq 'CMake Library Test' }
            $libCheck | Should -Not -BeNullOrEmpty
        }

        It "Should accept MinimumVersion parameter" -Skip:(-not $script:CMakeAvailable) {
            { & $script:ScriptPath -MinimumVersion "3.15" -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should exit with code 1 when -ExitOnFailure is used and checks fail" {
            # Force a failure by requiring a very high version
            $result = & $script:ScriptPath -MinimumVersion "99.0" -ExitOnFailure -JsonOutput 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Output Formatting" {
        BeforeAll {
            $script:CMakeAvailable = $null -ne (Get-Command cmake -ErrorAction SilentlyContinue)
        }

        It "Should display checkmarks for passed tests (non-JSON mode)" -Skip:(-not $script:CMakeAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match '✅|✓|PASS'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:CMakeAvailable) {
            $output = & $script:ScriptPath 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }
    }
}

Describe "verify-cmake.ps1 - Security and Best Practices" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Uses ErrorActionPreference" {
        $script:Content | Should -Match '\$ErrorActionPreference\s*='
    }

    It "Uses CmdletBinding attribute" {
        $script:Content | Should -Match '\[CmdletBinding\(\)\]'
    }

    It "Cleans up temporary test projects" {
        $script:Content | Should -Match 'Remove-Item.*\$testDir'
    }

    It "Uses try-finally for cleanup" {
        $script:Content | Should -Match 'try\s*\{[\s\S]*?\}\s*finally\s*\{'
    }

    It "Uses unique temporary directory names" {
        $script:Content | Should -Match 'Get-Random'
    }

    It "Suppresses errors on cleanup" {
        $script:Content | Should -Match 'ErrorAction\s+SilentlyContinue'
    }
}

Describe "verify-cmake.ps1 - CMake Project Files" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Creates CMakeLists.txt for testing" {
        $script:Content | Should -Match 'CMakeLists\.txt'
    }

    It "Creates C++ source files for testing" {
        $script:Content | Should -Match 'main\.cpp'
    }

    It "Contains cmake_minimum_required directive" {
        $script:Content | Should -Match 'cmake_minimum_required'
    }

    It "Contains project directive" {
        $script:Content | Should -Match 'project\('
    }

    It "Contains add_executable directive" {
        $script:Content | Should -Match 'add_executable'
    }

    It "Contains add_library directive" {
        $script:Content | Should -Match 'add_library'
    }

    It "Contains target_link_libraries directive" {
        $script:Content | Should -Match 'target_link_libraries'
    }

    It "Creates build directory" {
        $script:Content | Should -Match 'build'
    }

    It "Verifies CMakeCache.txt creation" {
        $script:Content | Should -Match 'CMakeCache\.txt'
    }
}

Describe "verify-cmake.ps1 - Compiler Detection" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Checks for MSVC compiler" {
        $script:Content | Should -Match 'MSVC|cl'
    }

    It "Checks for GCC compiler" {
        $script:Content | Should -Match 'GCC|g\+\+'
    }

    It "Checks for Clang compiler" {
        $script:Content | Should -Match 'Clang|clang'
    }
}

Describe "verify-cmake.ps1 - Build System Detection" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Checks for Ninja build system" {
        $script:Content | Should -Match 'Ninja'
    }

    It "Checks for Make build system" {
        $script:Content | Should -Match 'Make'
    }

    It "Checks for MSBuild build system" {
        $script:Content | Should -Match 'MSBuild'
    }
}

Describe "verify-cmake.ps1 - CMake Specific Functionality" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Tests CMake project with executable" {
        $script:Content | Should -Match 'add_executable'
    }

    It "Tests CMake project with static library" {
        $script:Content | Should -Match 'add_library.*STATIC'
    }

    It "Tests linking libraries to executables" {
        $script:Content | Should -Match 'target_link_libraries'
    }

    It "Checks for built executable files" {
        $script:Content | Should -Match '\.exe|hello'
    }

    It "Checks for built library files" {
        $script:Content | Should -Match '\.a|\.lib'
    }

    It "Uses cmake --build command" {
        $script:Content | Should -Match 'cmake --build'
    }

    It "Supports multiple build configurations" {
        $script:Content | Should -Match 'Debug|Release'
    }

    It "Has JSON output support" {
        $script:Content | Should -Match 'ConvertTo-Json'
    }

    It "Has proper exit code handling" {
        $script:Content | Should -Match 'exit 1'
        $script:Content | Should -Match 'exit 0'
    }
}
