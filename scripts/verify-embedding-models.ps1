#Requires -Version 5.1

<#
.SYNOPSIS
    Verifies embedding model dependencies and functionality for GitHub Actions runners.

.DESCRIPTION
    This script validates the installation and configuration of embedding model frameworks
    including sentence-transformers, PyTorch, and CUDA. It performs comprehensive checks
    for Python environment, package availability, GPU support, and basic embedding
    generation functionality.

.PARAMETER ExitOnFailure
    Exit with code 1 if any critical checks fail. Default is to continue and report all issues.

.PARAMETER JsonOutput
    Output results in JSON format instead of human-readable text.

.PARAMETER SkipGPU
    Skip GPU-related checks. Useful for CPU-only environments or testing.

.PARAMETER MinimumPythonVersion
    Minimum required Python version. Default is "3.8".

.PARAMETER TestModel
    Embedding model to use for testing. Default is "sentence-transformers/all-MiniLM-L6-v2".

.EXAMPLE
    .\verify-embedding-models.ps1
    Run all verification checks with default settings.

.EXAMPLE
    .\verify-embedding-models.ps1 -JsonOutput
    Run verification and output results in JSON format.

.EXAMPLE
    .\verify-embedding-models.ps1 -SkipGPU
    Run verification without GPU checks (CPU-only mode).

.EXAMPLE
    .\verify-embedding-models.ps1 -TestModel "sentence-transformers/paraphrase-MiniLM-L6-v2"
    Test with a specific embedding model.

.EXAMPLE
    .\verify-embedding-models.ps1 -ExitOnFailure
    Run verification and exit with code 1 if any critical checks fail.

.NOTES
    Requires Python 3.8+ with sentence-transformers and PyTorch installed.
    GPU support requires NVIDIA drivers and CUDA toolkit.
#>

[CmdletBinding()]
param(
    [switch]$ExitOnFailure,
    [switch]$JsonOutput,
    [switch]$SkipGPU,
    [string]$MinimumPythonVersion = "3.8",
    [string]$TestModel = "sentence-transformers/all-MiniLM-L6-v2"
)

$ErrorActionPreference = 'Continue'

# Initialize results tracking
$script:checks = @()
$script:passed = 0
$script:failed = 0
$script:warnings = 0

function Test-Requirement {
    param(
        [string]$Name,
        [scriptblock]$Check,
        [string]$Expected,
        [string]$FailureMessage,
        [string]$Severity = "Error"  # Error, Warning, Info
    )

    $result = @{
        name = $Name
        expected = $Expected
        severity = $Severity
        timestamp = (Get-Date -Format "o")
    }

    try {
        $output = & $Check
        $result.actual = $output
        $result.passed = $true
        $script:passed++

        if (-not $JsonOutput) {
            Write-Host "✅ $Name" -ForegroundColor Green
            if ($output) {
                Write-Host "   $output" -ForegroundColor Gray
            }
        }
    }
    catch {
        $result.passed = $false
        $result.actual = $_.Exception.Message
        $result.error = $FailureMessage

        if ($Severity -eq "Warning") {
            $script:warnings++
            if (-not $JsonOutput) {
                Write-Host "⚠️  $Name" -ForegroundColor Yellow
                Write-Host "   $FailureMessage" -ForegroundColor Yellow
            }
        }
        else {
            $script:failed++
            if (-not $JsonOutput) {
                Write-Host "❌ $Name" -ForegroundColor Red
                Write-Host "   $FailureMessage" -ForegroundColor Red
            }
        }
    }

    $script:checks += $result
}

# Display header
if (-not $JsonOutput) {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Embedding Models Environment Verification" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
}

# Check 1: Python Interpreter
Test-Requirement -Name "Python Interpreter" -Expected "Python $MinimumPythonVersion or higher" -Check {
    $pythonVersion = python --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Python not found"
    }

    $versionMatch = $pythonVersion -match '(\d+)\.(\d+)\.(\d+)'
    if (-not $versionMatch) {
        throw "Unable to parse Python version"
    }

    $major = [int]$matches[1]
    $minor = [int]$matches[2]
    $minMatch = $MinimumPythonVersion -match '(\d+)\.(\d+)'
    $minMajor = [int]$matches[1]
    $minMinor = [int]$matches[2]

    if ($major -lt $minMajor -or ($major -eq $minMajor -and $minor -lt $minMinor)) {
        throw "Python version $pythonVersion is below minimum $MinimumPythonVersion"
    }

    return $pythonVersion
} -FailureMessage "Python $MinimumPythonVersion or higher is required"

# Check 2: pip Package Manager
Test-Requirement -Name "pip Package Manager" -Expected "pip installed and functional" -Check {
    $pipVersion = python -m pip --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "pip not found"
    }
    return $pipVersion
} -FailureMessage "pip is required for package management"

# Check 3: PyTorch Package
Test-Requirement -Name "PyTorch Package" -Expected "PyTorch installed" -Check {
    $torchCheck = python -c "import torch; print(f'PyTorch {torch.__version__}')" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "PyTorch not installed"
    }
    return $torchCheck
} -FailureMessage "PyTorch is required. Install with: pip install torch"

# Check 4: CUDA Availability (if not skipped)
if (-not $SkipGPU) {
    Test-Requirement -Name "CUDA Availability" -Expected "CUDA available for GPU acceleration" -Check {
        $cudaCheck = python -c "import torch; available = torch.cuda.is_available(); version = torch.version.cuda if available else 'N/A'; print(f'CUDA Available: {available}, Version: {version}')" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to check CUDA availability"
        }

        $isAvailable = $cudaCheck -match 'CUDA Available: True'
        if (-not $isAvailable) {
            throw "CUDA is not available"
        }

        return $cudaCheck
    } -FailureMessage "CUDA is recommended for GPU acceleration" -Severity "Warning"

    # Check 5: GPU Count
    Test-Requirement -Name "GPU Device Count" -Expected "At least 1 GPU available" -Check {
        $gpuCount = python -c "import torch; print(torch.cuda.device_count())" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to check GPU count"
        }

        $count = [int]$gpuCount
        if ($count -eq 0) {
            throw "No GPUs detected"
        }

        return "$count GPU(s) detected"
    } -FailureMessage "No GPUs found" -Severity "Warning"

    # Check 6: NVIDIA Driver
    Test-Requirement -Name "NVIDIA GPU Driver" -Expected "nvidia-smi available" -Check {
        $nvidiaOutput = nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "nvidia-smi not found or failed"
        }
        return $nvidiaOutput
    } -FailureMessage "NVIDIA drivers not found" -Severity "Warning"
}

# Check 7: sentence-transformers Package
Test-Requirement -Name "sentence-transformers Package" -Expected "sentence-transformers installed" -Check {
    $stCheck = python -c "import sentence_transformers; print(f'sentence-transformers {sentence_transformers.__version__}')" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "sentence-transformers not installed"
    }
    return $stCheck
} -FailureMessage "sentence-transformers is required. Install with: pip install sentence-transformers"

# Check 8: transformers Package
Test-Requirement -Name "transformers Package" -Expected "HuggingFace transformers installed" -Check {
    $hfCheck = python -c "import transformers; print(f'transformers {transformers.__version__}')" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "transformers not installed"
    }
    return $hfCheck
} -FailureMessage "transformers is required. Install with: pip install transformers"

# Check 9: Model Loading and Embedding Test
$testDir = Join-Path $env:TEMP "embedding_test_$(Get-Random)"
New-Item -ItemType Directory -Path $testDir -Force | Out-Null

try {
    $testScript = @"
import sys
import torch
from sentence_transformers import SentenceTransformer, util
import time

# Set device
device = 'cuda' if torch.cuda.is_available() and '$($SkipGPU)' != 'True' else 'cpu'
print(f'Using device: {device}')

# Load model
print(f'Loading model: $TestModel')
start_time = time.time()
model = SentenceTransformer('$TestModel', device=device)
load_time = time.time() - start_time
print(f'Model loaded in {load_time:.2f}s')

# Test embedding generation
test_sentences = [
    'This is a test sentence.',
    'Another example for embedding.',
    'Semantic similarity test.'
]

print('Generating embeddings...')
start_time = time.time()
embeddings = model.encode(test_sentences, convert_to_tensor=True)
encode_time = time.time() - start_time
print(f'Embeddings generated in {encode_time:.2f}s')

# Verify embedding shape
print(f'Embedding shape: {embeddings.shape}')
print(f'Embedding dimension: {embeddings.shape[1]}')

# Test cosine similarity
similarities = util.cos_sim(embeddings[0], embeddings[1:])
print(f'Cosine similarities: {similarities}')

# Test normalization
norms = torch.norm(embeddings, dim=1)
print(f'Embedding norms: {norms}')

print('SUCCESS: All embedding tests passed')
sys.exit(0)
"@

    $testFile = Join-Path $testDir "test_embeddings.py"
    Set-Content -Path $testFile -Value $testScript -Encoding UTF8

    Test-Requirement -Name "Embedding Model Test" -Expected "Model loads and generates embeddings" -Check {
        $output = python $testFile 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            throw "Embedding test failed: $output"
        }

        if ($output -notmatch 'SUCCESS: All embedding tests passed') {
            throw "Embedding test did not complete successfully"
        }

        return $output.Trim()
    } -FailureMessage "Failed to load model and generate embeddings"
}
finally {
    # Cleanup
    if (Test-Path $testDir) {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Output results
if ($JsonOutput) {
    $output = @{
        timestamp = (Get-Date -Format "o")
        passed = $script:passed
        failed = $script:failed
        warnings = $script:warnings
        checks = $script:checks
    }
    $output | ConvertTo-Json -Depth 10
}
else {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Passed:   $script:passed" -ForegroundColor Green
    Write-Host "Failed:   $script:failed" -ForegroundColor Red
    Write-Host "Warnings: $script:warnings" -ForegroundColor Yellow
    Write-Host "========================================`n" -ForegroundColor Cyan
}

# Exit with appropriate code
if ($ExitOnFailure -and $script:failed -gt 0) {
    exit 1
}

exit 0
