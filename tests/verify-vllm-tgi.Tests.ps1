#Requires -Version 5.1

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\scripts\verify-vllm-tgi.ps1'
}

Describe "verify-vllm-tgi.ps1 - Script Validation" {
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

Describe "verify-vllm-tgi.ps1 - Parameter Validation" {
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

    It "Has SkipGPU switch parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'SkipGPU' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'SwitchParameter'
    }

    It "Has MinimumPythonVersion string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumPythonVersion' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }

    It "MinimumPythonVersion has default value of 3.8" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'MinimumPythonVersion' }
        $defaultValue = $param.DefaultValue.Extent.Text -replace '"', ''
        $defaultValue | Should -Be '3.8'
    }

    It "Has TestModel string parameter" {
        $param = $script:Params | Where-Object { $_.Name.VariablePath.UserPath -eq 'TestModel' }
        $param | Should -Not -BeNullOrEmpty
        $param.StaticType.Name | Should -Be 'String'
    }
}

Describe "verify-vllm-tgi.ps1 - Function Definitions" {
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

Describe "verify-vllm-tgi.ps1 - Content Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Contains Python version check" {
        $script:Content | Should -Match 'python --version'
    }

    It "Contains pip check" {
        $script:Content | Should -Match 'python -m pip --version'
    }

    It "Contains vLLM import check" {
        $script:Content | Should -Match 'import vllm'
    }

    It "Contains TGI (text-generation-inference) check" {
        $script:Content | Should -Match 'text-generation'
    }

    It "Contains GPU/CUDA check" {
        $script:Content | Should -Match 'nvidia-smi|cuda|gpu'
    }

    It "Contains PyTorch check" {
        $script:Content | Should -Match 'import torch'
    }

    It "Contains vLLM version check" {
        $script:Content | Should -Match 'vllm\.__version__'
    }

    It "Contains CUDA availability check" {
        $script:Content | Should -Match 'torch\.cuda\.is_available'
    }

    It "Contains model serving test" {
        $script:Content | Should -Match 'LLM|AsyncLLMEngine'
    }

    It "Uses proper error handling" {
        $script:Content | Should -Match '\$ErrorActionPreference'
    }

    It "Includes cleanup logic for temporary directories" {
        $script:Content | Should -Match 'Remove-Item.*-Recurse.*-Force'
    }

    It "Has JSON output support" {
        $script:Content | Should -Match 'ConvertTo-Json'
    }

    It "Has proper exit code handling" {
        $script:Content | Should -Match 'exit 1'
        $script:Content | Should -Match 'exit 0'
    }
}

Describe "verify-vllm-tgi.ps1 - Execution Tests" {
    Context "When Python is not available" {
        BeforeAll {
            # Mock python command by temporarily clearing PATH
            $script:OriginalPath = $env:PATH
            $env:PATH = ""
        }

        AfterAll {
            $env:PATH = $script:OriginalPath
        }

        It "Should handle missing Python gracefully" {
            { & $script:ScriptPath -JsonOutput 2>&1 } | Should -Not -Throw
        }
    }

    Context "When Python is available" {
        BeforeAll {
            # Check if python is available
            $script:PythonAvailable = $null -ne (Get-Command python -ErrorAction SilentlyContinue)
        }

        It "Should execute without errors when python is available" -Skip:(-not $script:PythonAvailable) {
            { & $script:ScriptPath -JsonOutput -SkipGPU 2>&1 } | Should -Not -Throw
        }

        It "Should return valid JSON output with -JsonOutput" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -JsonOutput -SkipGPU 2>&1 | Out-String
            { $output | ConvertFrom-Json } | Should -Not -Throw
        }

        It "Should include timestamp in JSON output" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -JsonOutput -SkipGPU 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.timestamp | Should -Not -BeNullOrEmpty
        }

        It "Should include checks array in JSON output" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -JsonOutput -SkipGPU 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.checks | Should -Not -BeNullOrEmpty
        }

        It "Should include passed/failed/warnings counts in JSON output" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -JsonOutput -SkipGPU 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $json.passed | Should -BeOfType [int]
            $json.failed | Should -BeOfType [int]
            $json.warnings | Should -BeOfType [int]
        }

        It "Should perform Python interpreter check" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -JsonOutput -SkipGPU 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $pythonCheck = $json.checks | Where-Object { $_.name -eq 'Python Interpreter' }
            $pythonCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform pip package manager check" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -JsonOutput -SkipGPU 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $pipCheck = $json.checks | Where-Object { $_.name -eq 'pip Package Manager' }
            $pipCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform PyTorch package check" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -JsonOutput -SkipGPU 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $pytorchCheck = $json.checks | Where-Object { $_.name -eq 'PyTorch Package' }
            $pytorchCheck | Should -Not -BeNullOrEmpty
        }

        It "Should perform vLLM package check" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -JsonOutput -SkipGPU 2>&1 | Out-String
            $json = $output | ConvertFrom-Json
            $vllmCheck = $json.checks | Where-Object { $_.name -eq 'vLLM Package' }
            $vllmCheck | Should -Not -BeNullOrEmpty
        }

        It "Should accept MinimumPythonVersion parameter" -Skip:(-not $script:PythonAvailable) {
            { & $script:ScriptPath -MinimumPythonVersion "3.8" -JsonOutput -SkipGPU 2>&1 } | Should -Not -Throw
        }

        It "Should accept TestModel parameter" -Skip:(-not $script:PythonAvailable) {
            { & $script:ScriptPath -TestModel "facebook/opt-125m" -JsonOutput -SkipGPU 2>&1 } | Should -Not -Throw
        }

        It "Should accept SkipGPU parameter" -Skip:(-not $script:PythonAvailable) {
            { & $script:ScriptPath -SkipGPU -JsonOutput 2>&1 } | Should -Not -Throw
        }

        It "Should exit with code 1 when -ExitOnFailure is used and checks fail" {
            # Force a failure by requiring a very high Python version
            $result = & $script:ScriptPath -MinimumPythonVersion "99.0" -ExitOnFailure -JsonOutput -SkipGPU 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context "Output Formatting" {
        BeforeAll {
            $script:PythonAvailable = $null -ne (Get-Command python -ErrorAction SilentlyContinue)
        }

        It "Should display checkmarks for passed tests (non-JSON mode)" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -SkipGPU 2>&1 | Out-String
            $output | Should -Match '✅|✓|PASS'
        }

        It "Should display summary section (non-JSON mode)" -Skip:(-not $script:PythonAvailable) {
            $output = & $script:ScriptPath -SkipGPU 2>&1 | Out-String
            $output | Should -Match 'Summary'
        }
    }
}

Describe "verify-vllm-tgi.ps1 - Security and Best Practices" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Uses ErrorActionPreference" {
        $script:Content | Should -Match '\$ErrorActionPreference\s*='
    }

    It "Uses CmdletBinding attribute" {
        $script:Content | Should -Match '\[CmdletBinding\(\)\]'
    }

    It "Cleans up temporary test directories" {
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

Describe "verify-vllm-tgi.ps1 - Model Serving Specific Checks" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Creates a Python test file for testing" {
        $script:Content | Should -Match 'test_vllm_tgi\.py|test_model_serving\.py'
    }

    It "Tests vLLM LLM class" {
        $script:Content | Should -Match 'from vllm import LLM'
    }

    It "Tests vLLM SamplingParams" {
        $script:Content | Should -Match 'SamplingParams'
    }

    It "Tests model generation/inference" {
        $script:Content | Should -Match 'generate|llm\.generate'
    }

    It "Checks for CUDA availability" {
        $script:Content | Should -Match 'torch\.cuda\.is_available'
    }

    It "Checks for GPU count" {
        $script:Content | Should -Match 'torch\.cuda\.device_count|nvidia-smi'
    }

    It "Tests HuggingFace transformers integration" {
        $script:Content | Should -Match 'from transformers import'
    }

    It "Tests text-generation client or library" {
        $script:Content | Should -Match 'text_generation|InferenceClient'
    }

    It "Includes model loading test" {
        $script:Content | Should -Match 'model.*=.*LLM'
    }

    It "Includes inference performance check" {
        $script:Content | Should -Match 'time|duration|latency'
    }

    It "Tests tokenization" {
        $script:Content | Should -Match 'tokenizer|encode|decode'
    }
}

Describe "verify-vllm-tgi.ps1 - GPU Requirements" {
    BeforeAll {
        $script:Content = Get-Content $script:ScriptPath -Raw
    }

    It "Checks for NVIDIA GPU driver" {
        $script:Content | Should -Match 'nvidia-smi'
    }

    It "Checks CUDA version" {
        $script:Content | Should -Match 'cuda|nvcc --version'
    }

    It "Reports GPU memory" {
        $script:Content | Should -Match 'memory|mem'
    }

    It "Allows skipping GPU checks with -SkipGPU" {
        $script:Content | Should -Match '\$SkipGPU'
    }

    It "Warns when GPU is not available" {
        $script:Content | Should -Match 'warning|warn'
    }
}
