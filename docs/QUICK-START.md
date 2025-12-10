# Quick Start

Get your runner pool up in three steps.

## Step 1: Get a Registration Token

1. Go to your GitHub organization settings
2. Navigate to **Actions** > **Runners** > **New runner**
3. Copy the registration token

## Step 2: Deploy Runners

Run the deployment script from this repository. Runners auto-detect their capabilities (GPU, Docker, Unity) and label themselves accordingly.

For detailed deployment options, see [installation.md](installation.md).

## Step 3: Use in Workflows

```yaml
jobs:
  build:
    runs-on: [self-hosted, unity-pool]  # or docker, gpu, etc.
    steps:
      - uses: actions/checkout@v4
      - run: your-build-command
```

That's it. Push code. Builds run on your hardware.

## Next Steps

- [Installation Guide](installation.md) - Detailed setup for Windows, Linux, macOS
- [Troubleshooting](troubleshooting.md) - Common issues and solutions
- [Security](security.md) - Best practices for private infrastructure
