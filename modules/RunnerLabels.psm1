<#
.SYNOPSIS
    Centralized runner label definitions for GitHub Actions self-hosted runners.

.DESCRIPTION
    This module provides a single source of truth for all runner labels used across
    the ActionRunner scripts. Centralizing these values avoids magic strings and
    ensures consistency when labels are referenced in capability detection,
    registration, and workflow targeting.

.NOTES
    Author: ActionRunner Team
    Version: 1.0.0
    Issue: #185 - Runner labels are hardcoded magic strings in detect-capabilities.ps1
#>

#Requires -Version 5.1

# =============================================================================
# BASE LABELS
# These are fundamental labels applied to all runners based on their OS/platform
# =============================================================================

$script:BaseLabels = @{
    SelfHosted = "self-hosted"
    Windows    = "windows"
    Linux      = "linux"
    MacOS      = "macos"
}

# =============================================================================
# CAPABILITY LABELS
# These labels correspond to detected software/capabilities on the runner
# =============================================================================

$script:CapabilityLabels = @{
    DotNet   = "dotnet"
    Python   = "python"
    Unity    = "unity-pool"
    Docker   = "docker"
    Desktop  = "desktop"
    Mobile   = "mobile"
    GpuCuda  = "gpu-cuda"
    NodeJs   = "nodejs"
    AI       = "ai"
}

# =============================================================================
# CAPABILITY TO VERIFICATION SCRIPT MAPPING
# Maps capability names to their verification scripts and labels
# =============================================================================

$script:CapabilityMappings = @{
    dotnet = @{
        Name        = ".NET SDK"
        Script      = "verify-dotnet.ps1"
        Label       = $script:CapabilityLabels.DotNet
        Description = ".NET SDK development environment"
    }
    python = @{
        Name        = "Python"
        Script      = $null  # Uses inline check
        Label       = $script:CapabilityLabels.Python
        Description = "Python runtime environment"
    }
    unity = @{
        Name        = "Unity"
        Script      = "verify-unity.ps1"
        Label       = $script:CapabilityLabels.Unity
        Description = "Unity game engine development"
    }
    docker = @{
        Name        = "Docker"
        Script      = "verify-docker.ps1"
        Label       = $script:CapabilityLabels.Docker
        Description = "Docker container runtime"
    }
    desktop = @{
        Name        = "Desktop (MAUI/WPF)"
        Script      = "verify-desktop.ps1"
        Label       = $script:CapabilityLabels.Desktop
        Description = "Desktop application development (MAUI/WPF)"
    }
    mobile = @{
        Name        = "Mobile Development"
        Script      = "verify-mobile.ps1"
        Label       = $script:CapabilityLabels.Mobile
        Description = "Mobile application development (Android/Flutter/React Native)"
    }
    gpu = @{
        Name        = "GPU/CUDA"
        Script      = $null  # Uses inline check
        Label       = $script:CapabilityLabels.GpuCuda
        Description = "GPU acceleration with CUDA support"
    }
    nodejs = @{
        Name        = "Node.js"
        Script      = "verify-nodejs.ps1"
        Label       = $script:CapabilityLabels.NodeJs
        Description = "Node.js JavaScript runtime"
    }
}

# =============================================================================
# AI CAPABILITY MAPPINGS
# AI-related capabilities that contribute to the "ai" label
# =============================================================================

$script:AICapabilityMappings = @{
    openai = @{
        Name        = "OpenAI SDK"
        Script      = "verify-openai.ps1"
        Label       = $script:CapabilityLabels.AI
        Description = "OpenAI API SDK"
    }
    langchain = @{
        Name        = "LangChain"
        Script      = "verify-langchain.ps1"
        Label       = $script:CapabilityLabels.AI
        Description = "LangChain framework"
    }
    embeddings = @{
        Name        = "Embedding Models"
        Script      = "verify-embedding-models.ps1"
        Label       = $script:CapabilityLabels.AI
        Description = "Text embedding models"
    }
    pinecone = @{
        Name        = "Pinecone"
        Script      = "verify-pinecone.ps1"
        Label       = $script:CapabilityLabels.AI
        Description = "Pinecone vector database"
    }
    weaviate = @{
        Name        = "Weaviate"
        Script      = "verify-weaviate.ps1"
        Label       = $script:CapabilityLabels.AI
        Description = "Weaviate vector database"
    }
    vllm_tgi = @{
        Name        = "vLLM/TGI"
        Script      = "verify-vllm-tgi.ps1"
        Label       = $script:CapabilityLabels.AI
        Description = "vLLM/TGI model serving"
    }
}

# =============================================================================
# PUBLIC FUNCTIONS
# =============================================================================

<#
.SYNOPSIS
    Gets the base labels hashtable.

.OUTPUTS
    Hashtable of base label names and values.

.EXAMPLE
    $labels = Get-BaseLabels
    Write-Host $labels.SelfHosted  # Outputs: self-hosted
#>
function Get-BaseLabels {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return $script:BaseLabels.Clone()
}

<#
.SYNOPSIS
    Gets the capability labels hashtable.

.OUTPUTS
    Hashtable of capability label names and values.

.EXAMPLE
    $labels = Get-CapabilityLabels
    Write-Host $labels.Docker  # Outputs: docker
#>
function Get-CapabilityLabels {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return $script:CapabilityLabels.Clone()
}

<#
.SYNOPSIS
    Gets the capability mappings for standard capabilities.

.OUTPUTS
    Hashtable of capability mappings with Name, Script, Label, and Description.

.EXAMPLE
    $mappings = Get-CapabilityMappings
    $docker = $mappings['docker']
    Write-Host $docker.Label  # Outputs: docker
#>
function Get-CapabilityMappings {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    # Deep clone to prevent modification
    $clone = @{}
    foreach ($key in $script:CapabilityMappings.Keys) {
        $clone[$key] = $script:CapabilityMappings[$key].Clone()
    }
    return $clone
}

<#
.SYNOPSIS
    Gets the AI capability mappings.

.OUTPUTS
    Hashtable of AI capability mappings with Name, Script, Label, and Description.

.EXAMPLE
    $aiMappings = Get-AICapabilityMappings
    $openai = $aiMappings['openai']
    Write-Host $openai.Script  # Outputs: verify-openai.ps1
#>
function Get-AICapabilityMappings {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    # Deep clone to prevent modification
    $clone = @{}
    foreach ($key in $script:AICapabilityMappings.Keys) {
        $clone[$key] = $script:AICapabilityMappings[$key].Clone()
    }
    return $clone
}

<#
.SYNOPSIS
    Gets the OS-specific base label based on the current platform.

.OUTPUTS
    String containing the OS label (windows, linux, or macos).

.EXAMPLE
    $osLabel = Get-OSLabel
    Write-Host $osLabel  # Outputs: windows (on Windows)
#>
function Get-OSLabel {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($IsWindows -or $env:OS -match 'Windows' -or [System.Environment]::OSVersion.Platform -eq 'Win32NT') {
        return $script:BaseLabels.Windows
    }
    elseif ($IsLinux) {
        return $script:BaseLabels.Linux
    }
    elseif ($IsMacOS) {
        return $script:BaseLabels.MacOS
    }

    return $null
}

<#
.SYNOPSIS
    Gets all available labels as a flat array.

.OUTPUTS
    Array of all label strings (base + capability).

.EXAMPLE
    $allLabels = Get-AllLabels
    # Returns: @("self-hosted", "windows", "linux", "macos", "dotnet", "python", ...)
#>
function Get-AllLabels {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    $labels = @()
    $labels += $script:BaseLabels.Values
    $labels += $script:CapabilityLabels.Values
    return $labels | Select-Object -Unique
}

<#
.SYNOPSIS
    Validates that a label string is a known label.

.PARAMETER Label
    The label string to validate.

.OUTPUTS
    Boolean indicating if the label is valid.

.EXAMPLE
    Test-ValidLabel -Label "docker"  # Returns: $true
    Test-ValidLabel -Label "invalid" # Returns: $false
#>
function Test-ValidLabel {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $allLabels = Get-AllLabels
    return $allLabels -contains $Label
}

# =============================================================================
# MODULE EXPORTS
# =============================================================================

Export-ModuleMember -Function @(
    'Get-BaseLabels',
    'Get-CapabilityLabels',
    'Get-CapabilityMappings',
    'Get-AICapabilityMappings',
    'Get-OSLabel',
    'Get-AllLabels',
    'Test-ValidLabel'
)
