#Requires -Version 5.1

<#
.SYNOPSIS
    Detects runner capabilities and returns applicable labels for registration.

.DESCRIPTION
    This script runs capability verification scripts to auto-detect what software and
    capabilities are installed on the runner. Based on detected capabilities, it returns
    a comma-separated list of labels suitable for runner registration.

    This implements the auto-detection feature described in the README:
    "Runners auto-detect their capabilities and apply labels accordingly."

    Capability to Label Mapping:
    - dotnet capability -> dotnet label
    - python capability -> python label
    - unity capability -> unity-pool label
    - docker capability -> docker label
    - desktop (MAUI/WPF) capability -> desktop label
    - mobile (Android/Flutter/React Native) capability -> mobile label
    - gpu/cuda capability -> gpu-cuda label
    - nodejs capability -> nodejs label
    - ios (Xcode/iOS SDK on macOS) capability -> ios label
    - ai (OpenAI/LangChain/embeddings/vector DBs) capability -> ai label

.PARAMETER IncludeBase
    Include base labels (self-hosted, windows/linux) in output. Default: $true

.PARAMETER JsonOutput
    Output results in JSON format instead of comma-separated labels.

.PARAMETER Verbose
    Show detailed output during capability detection.

.PARAMETER Timeout
    Timeout in seconds for each capability check. Default: 60

.EXAMPLE
    .\detect-capabilities.ps1
    Returns: self-hosted,windows,dotnet,docker,desktop

.EXAMPLE
    .\detect-capabilities.ps1 -JsonOutput
    Returns JSON with detected capabilities and labels

.EXAMPLE
    .\detect-capabilities.ps1 -IncludeBase:$false
    Returns only capability labels without base labels

.NOTES
    Author: ActionRunner Team
    Version: 1.2.0
    Created for Issue #168: Ghost Feature - Runner label auto-detection
    Updated for Issue #172: Ghost Feature - AI capability detection integration
    Updated for Issue #192: Ghost Feature - iOS build capability integration
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [bool]$IncludeBase = $true,

    [Parameter(Mandatory = $false)]
    [switch]$JsonOutput,

    [Parameter(Mandatory = $false)]
    [int]$Timeout = 60
)

$ErrorActionPreference = 'Continue'

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Results tracking
$script:Results = @{
    timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    capabilities = @{}
    labels = @()
    checks = @()
    errors = @()
}

function Write-StatusMessage {
    param(
        [string]$Message,
        [string]$Status = "INFO",
        [string]$Color = "White"
    )

    if (-not $JsonOutput) {
        $prefix = switch ($Status) {
            "OK"      { "[+]" }
            "FAIL"    { "[-]" }
            "SKIP"    { "[~]" }
            "INFO"    { "[*]" }
            "CHECK"   { "[?]" }
            default   { "[*]" }
        }
        Write-Host "$prefix $Message" -ForegroundColor $Color
    }
}

function Test-CapabilityScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$ScriptName,

        [Parameter(Mandatory = $true)]
        [string]$Label,

        [Parameter(Mandatory = $false)]
        [string]$Description = ""
    )

    $scriptPath = Join-Path $ScriptDir $ScriptName
    $checkResult = @{
        name = $Name
        script = $ScriptName
        label = $Label
        available = $false
        details = ""
        error = $null
    }

    if (-not (Test-Path $scriptPath)) {
        $checkResult.details = "Verification script not found"
        $checkResult.error = "Script not found: $scriptPath"
        Write-StatusMessage "$Name - Script not found" -Status "SKIP" -Color DarkGray
        $script:Results.checks += $checkResult
        return $false
    }

    Write-StatusMessage "Checking $Name..." -Status "CHECK" -Color Cyan

    try {
        # Run the verification script with JSON output and exit on failure
        $output = & $scriptPath -JsonOutput -ExitOnFailure 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            $checkResult.available = $true
            $checkResult.details = "Capability detected"

            # Try to parse JSON output for more details
            try {
                $jsonStr = ($output | Out-String)
                if ($jsonStr -match '(\{[\s\S]*\})') {
                    $json = $Matches[1] | ConvertFrom-Json -ErrorAction SilentlyContinue
                    if ($json.passed) {
                        $checkResult.details = "Passed $($json.passed)/$($json.passed + $json.failed) checks"
                    }
                }
            } catch {
                # JSON parsing failed, use default message
            }

            Write-StatusMessage "$Name - Available (label: $Label)" -Status "OK" -Color Green
            return $true
        }
        else {
            $checkResult.details = "Capability not detected or checks failed"
            Write-StatusMessage "$Name - Not available" -Status "FAIL" -Color DarkGray
            return $false
        }
    }
    catch {
        $checkResult.error = $_.Exception.Message
        $checkResult.details = "Error during check: $($_.Exception.Message)"
        $script:Results.errors += @{
            capability = $Name
            error = $_.Exception.Message
        }
        Write-StatusMessage "$Name - Error: $($_.Exception.Message)" -Status "FAIL" -Color Red
        return $false
    }
    finally {
        $script:Results.checks += $checkResult
    }
}

function Test-GpuCapability {
    <#
    .SYNOPSIS
        Check for GPU/CUDA capability
    #>

    $checkResult = @{
        name = "GPU/CUDA"
        script = "nvidia-smi"
        label = "gpu-cuda"
        available = $false
        details = ""
        error = $null
    }

    Write-StatusMessage "Checking GPU/CUDA..." -Status "CHECK" -Color Cyan

    try {
        # Check for nvidia-smi
        $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
        if ($nvidiaSmi) {
            $gpuInfo = nvidia-smi --query-gpu=driver_version,name,memory.total --format=csv,noheader 2>&1
            if ($LASTEXITCODE -eq 0 -and $gpuInfo) {
                $checkResult.available = $true
                $checkResult.details = "NVIDIA GPU: $($gpuInfo.ToString().Trim())"
                Write-StatusMessage "GPU/CUDA - Available (label: gpu-cuda)" -Status "OK" -Color Green
                $script:Results.checks += $checkResult
                return $true
            }
        }

        # Fallback: Check PyTorch CUDA availability
        $python = Get-Command python -ErrorAction SilentlyContinue
        if ($python) {
            $cudaCheck = python -c "import torch; print('cuda' if torch.cuda.is_available() else 'no')" 2>&1
            if ($LASTEXITCODE -eq 0 -and $cudaCheck -match 'cuda') {
                $checkResult.available = $true
                $checkResult.details = "CUDA available via PyTorch"
                Write-StatusMessage "GPU/CUDA - Available via PyTorch (label: gpu-cuda)" -Status "OK" -Color Green
                $script:Results.checks += $checkResult
                return $true
            }
        }

        $checkResult.details = "No NVIDIA GPU or CUDA support detected"
        Write-StatusMessage "GPU/CUDA - Not available" -Status "FAIL" -Color DarkGray
    }
    catch {
        $checkResult.error = $_.Exception.Message
        $checkResult.details = "Error checking GPU: $($_.Exception.Message)"
    }

    $script:Results.checks += $checkResult
    return $false
}

function Test-PythonCapability {
    <#
    .SYNOPSIS
        Check for Python capability (simplified check)
    #>

    $checkResult = @{
        name = "Python"
        script = "python --version"
        label = "python"
        available = $false
        details = ""
        error = $null
    }

    Write-StatusMessage "Checking Python..." -Status "CHECK" -Color Cyan

    try {
        $python = Get-Command python -ErrorAction SilentlyContinue
        if ($python) {
            $version = python --version 2>&1
            if ($LASTEXITCODE -eq 0 -and $version -match 'Python (\d+\.\d+)') {
                $checkResult.available = $true
                $checkResult.details = $version.ToString().Trim()
                Write-StatusMessage "Python - $($checkResult.details) (label: python)" -Status "OK" -Color Green
                $script:Results.checks += $checkResult
                return $true
            }
        }

        $checkResult.details = "Python not found or not accessible"
        Write-StatusMessage "Python - Not available" -Status "FAIL" -Color DarkGray
    }
    catch {
        $checkResult.error = $_.Exception.Message
        $checkResult.details = "Error checking Python: $($_.Exception.Message)"
    }

    $script:Results.checks += $checkResult
    return $false
}

# ============================================================================
# MAIN DETECTION LOGIC
# ============================================================================

if (-not $JsonOutput) {
    Write-Host ""
    Write-Host "=== Runner Capability Detection ===" -ForegroundColor Cyan
    Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ""
}

# Add base labels
if ($IncludeBase) {
    $script:Results.labels += "self-hosted"

    # Detect OS
    if ($IsWindows -or $env:OS -match 'Windows' -or [System.Environment]::OSVersion.Platform -eq 'Win32NT') {
        $script:Results.labels += "windows"
        $script:Results.capabilities["os"] = "windows"
    }
    elseif ($IsLinux) {
        $script:Results.labels += "linux"
        $script:Results.capabilities["os"] = "linux"
    }
    elseif ($IsMacOS) {
        $script:Results.labels += "macos"
        $script:Results.capabilities["os"] = "macos"
    }
}

# Check .NET capability
if (Test-CapabilityScript -Name ".NET SDK" -ScriptName "verify-dotnet.ps1" -Label "dotnet") {
    $script:Results.labels += "dotnet"
    $script:Results.capabilities["dotnet"] = $true
}

# Check Python capability (simplified check, verify-pip.ps1 is more comprehensive)
if (Test-PythonCapability) {
    $script:Results.labels += "python"
    $script:Results.capabilities["python"] = $true
}

# Check Unity capability
if (Test-CapabilityScript -Name "Unity" -ScriptName "verify-unity.ps1" -Label "unity-pool") {
    $script:Results.labels += "unity-pool"
    $script:Results.capabilities["unity"] = $true
}

# Check Docker capability
if (Test-CapabilityScript -Name "Docker" -ScriptName "verify-docker.ps1" -Label "docker") {
    $script:Results.labels += "docker"
    $script:Results.capabilities["docker"] = $true
}

# Check Desktop capability (MAUI/WPF)
if (Test-CapabilityScript -Name "Desktop (MAUI/WPF)" -ScriptName "verify-desktop.ps1" -Label "desktop") {
    $script:Results.labels += "desktop"
    $script:Results.capabilities["desktop"] = $true
}

# Check Mobile capability
if (Test-CapabilityScript -Name "Mobile Development" -ScriptName "verify-mobile.ps1" -Label "mobile") {
    $script:Results.labels += "mobile"
    $script:Results.capabilities["mobile"] = $true
}

# Check GPU/CUDA capability
if (Test-GpuCapability) {
    $script:Results.labels += "gpu-cuda"
    $script:Results.capabilities["gpu"] = $true
}

# Check Node.js capability
if (Test-CapabilityScript -Name "Node.js" -ScriptName "verify-nodejs.ps1" -Label "nodejs") {
    $script:Results.labels += "nodejs"
    $script:Results.capabilities["nodejs"] = $true
}

# Check iOS build capability (macOS only)
if (Test-CapabilityScript -Name "iOS Build" -ScriptName "verify-ios-build.ps1" -Label "ios") {
    $script:Results.labels += "ios"
    $script:Results.capabilities["ios"] = $true
}

# ============================================================================
# AI CAPABILITY DETECTION
# ============================================================================

# AI capability is detected if ANY of the AI-related verification scripts pass.
# This includes: OpenAI SDK, LangChain, embedding models, and vector databases.

$aiDetected = $false
$aiComponents = @()

Write-StatusMessage "Checking AI/LLM capabilities..." -Status "CHECK" -Color Cyan

# Check OpenAI SDK
if (Test-CapabilityScript -Name "OpenAI SDK" -ScriptName "verify-openai.ps1" -Label "ai") {
    $aiDetected = $true
    $aiComponents += "openai"
}

# Check LangChain
if (Test-CapabilityScript -Name "LangChain" -ScriptName "verify-langchain.ps1" -Label "ai") {
    $aiDetected = $true
    $aiComponents += "langchain"
}

# Check Embedding Models
if (Test-CapabilityScript -Name "Embedding Models" -ScriptName "verify-embedding-models.ps1" -Label "ai") {
    $aiDetected = $true
    $aiComponents += "embeddings"
}

# Check Pinecone Vector DB
if (Test-CapabilityScript -Name "Pinecone" -ScriptName "verify-pinecone.ps1" -Label "ai") {
    $aiDetected = $true
    $aiComponents += "pinecone"
}

# Check Weaviate Vector DB
if (Test-CapabilityScript -Name "Weaviate" -ScriptName "verify-weaviate.ps1" -Label "ai") {
    $aiDetected = $true
    $aiComponents += "weaviate"
}

# Check vLLM/TGI Model Serving
if (Test-CapabilityScript -Name "vLLM/TGI" -ScriptName "verify-vllm-tgi.ps1" -Label "ai") {
    $aiDetected = $true
    $aiComponents += "vllm-tgi"
}

# Add AI label if any AI capability was detected
if ($aiDetected) {
    $script:Results.labels += "ai"
    $script:Results.capabilities["ai"] = $true
    $script:Results.capabilities["ai_components"] = $aiComponents
    Write-StatusMessage "AI capability detected (components: $($aiComponents -join ', '))" -Status "OK" -Color Green
}
else {
    Write-StatusMessage "No AI capabilities detected" -Status "FAIL" -Color DarkGray
}

# ============================================================================
# OUTPUT RESULTS
# ============================================================================

if ($JsonOutput) {
    $output = @{
        timestamp = $script:Results.timestamp
        labels = $script:Results.labels
        labelsString = ($script:Results.labels -join ",")
        capabilities = $script:Results.capabilities
        checks = $script:Results.checks
        errors = $script:Results.errors
        summary = @{
            totalLabels = $script:Results.labels.Count
            capabilitiesDetected = ($script:Results.capabilities.Keys | Where-Object { $script:Results.capabilities[$_] -eq $true }).Count
            checksRun = $script:Results.checks.Count
            errorsEncountered = $script:Results.errors.Count
        }
    }
    # Output JSON only - no return statement to avoid extra output
    $output | ConvertTo-Json -Depth 10
}
else {
    Write-Host ""
    Write-Host "=== Detection Summary ===" -ForegroundColor Cyan
    Write-Host "Labels detected: $($script:Results.labels.Count)" -ForegroundColor White
    Write-Host ""
    Write-Host "Detected Labels:" -ForegroundColor Yellow
    Write-Host "  $($script:Results.labels -join ', ')" -ForegroundColor Green
    Write-Host ""
    Write-Host "Labels String (for registration):" -ForegroundColor Yellow
    Write-Host "  $($script:Results.labels -join ',')" -ForegroundColor Cyan
    Write-Host ""

    if ($script:Results.errors.Count -gt 0) {
        Write-Host "Errors encountered: $($script:Results.errors.Count)" -ForegroundColor Red
        foreach ($err in $script:Results.errors) {
            Write-Host "  - $($err.capability): $($err.error)" -ForegroundColor Red
        }
        Write-Host ""
    }

    # Return labels string for use in scripts (only in non-JSON mode)
    return ($script:Results.labels -join ",")
}
