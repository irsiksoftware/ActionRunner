# Runner Labels Configuration
# Central source of truth for GitHub Actions self-hosted runner labels
# Both install-runner.ps1 and register-runner.ps1 consume this file

@{
    # Default labels applied to all runners
    # These are used when no custom labels are specified via -Labels parameter
    DefaultLabels = @(
        'self-hosted'
        'windows'
        'dotnet'
        'python'
        'unity'
        'gpu-cuda'
        'docker'
    )

    # Available label sets for common runner configurations
    # Use with: -Labels (Get-RunnerLabels -Profile 'GPU')
    Profiles = @{
        # Minimal runner with basic capabilities
        Minimal = @(
            'self-hosted'
            'windows'
        )

        # General purpose development runner
        General = @(
            'self-hosted'
            'windows'
            'dotnet'
            'python'
            'docker'
        )

        # GPU-enabled runner for CUDA workloads
        GPU = @(
            'self-hosted'
            'windows'
            'gpu-cuda'
            'dotnet'
            'python'
            'docker'
        )

        # Unity game development runner
        Unity = @(
            'self-hosted'
            'windows'
            'unity'
            'dotnet'
            'docker'
        )

        # Full-featured runner with all capabilities
        Full = @(
            'self-hosted'
            'windows'
            'dotnet'
            'python'
            'unity'
            'gpu-cuda'
            'docker'
        )
    }

    # Label descriptions for documentation and validation
    LabelDescriptions = @{
        'self-hosted'  = 'Identifies this as a self-hosted runner (required by GitHub)'
        'windows'      = 'Windows operating system'
        'dotnet'       = '.NET SDK available for building .NET applications'
        'python'       = 'Python runtime available'
        'unity'        = 'Unity Editor installed for game development builds'
        'gpu-cuda'     = 'NVIDIA GPU with CUDA support available'
        'docker'       = 'Docker engine available for containerized builds'
    }
}
