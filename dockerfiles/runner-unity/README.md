# Unity Docker Image (runner-unity)

Docker image for running Unity builds in GitHub Actions. Supports Unity 2021.3 LTS with GPU acceleration for mobile development.

## Features

- Unity 2021.3.31f1 LTS
- Android build support with SDK/NDK
- iOS build module (requires macOS for actual builds)
- GPU support via NVIDIA Docker
- Xvfb for headless rendering
- GitHub Actions runner compatible

## Requirements

- **Unity License**: Required for activation (personal, plus, or pro)
- **Disk Space**: ~10GB+ for image
- **GPU Support**: NVIDIA Docker runtime (optional but recommended)
- **Memory**: 8GB+ RAM recommended

## Usage

### Building the Image

```bash
docker build -t runner-unity:latest ./dockerfiles/runner-unity
```

### Running with License File

```bash
docker run -it \
  -v /path/to/Unity_lic.ulf:/root/.local/share/unity3d/Unity/Unity_lic.ulf \
  -v $(pwd)/UnityProject:/home/runner/project \
  runner-unity:latest
```

### Running with License Credentials

```bash
docker run -it \
  -e UNITY_USERNAME="your-email@example.com" \
  -e UNITY_PASSWORD="your-password" \
  -e UNITY_SERIAL="XX-XXXX-XXXX-XXXX-XXXX-XXXX" \
  -v $(pwd)/UnityProject:/home/runner/project \
  runner-unity:latest
```

### GPU Support

For GPU-accelerated builds:

```bash
docker run -it \
  --gpus all \
  -v /path/to/Unity_lic.ulf:/root/.local/share/unity3d/Unity/Unity_lic.ulf \
  runner-unity:latest
```

### Building Unity Projects

```bash
docker run -it \
  -v /path/to/Unity_lic.ulf:/root/.local/share/unity3d/Unity/Unity_lic.ulf \
  -v $(pwd)/UnityProject:/home/runner/project \
  -e UNITY_PROJECT_PATH=/home/runner/project \
  -e UNITY_BUILD_TARGET=Android \
  -e UNITY_BUILD_PATH=/home/runner/project/build \
  runner-unity:latest \
  unity-build
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `UNITY_VERSION` | Unity Editor version | `2021.3.31f1` |
| `UNITY_PROJECT_PATH` | Path to Unity project | `.` |
| `UNITY_BUILD_TARGET` | Build target platform | `StandaloneLinux64` |
| `UNITY_BUILD_PATH` | Output directory for build | `./build` |
| `UNITY_LOG_FILE` | Build log file path | `/tmp/unity-build.log` |
| `UNITY_USERNAME` | Unity account email | - |
| `UNITY_PASSWORD` | Unity account password | - |
| `UNITY_SERIAL` | Unity license serial | - |

## Build Targets

Supported build targets:
- `StandaloneLinux64`
- `Android`
- `iOS` (module installed, macOS required for builds)
- `StandaloneWindows64`
- `WebGL`

## GitHub Actions Example

```yaml
name: Unity Build

on: [push]

jobs:
  build:
    runs-on: self-hosted
    container:
      image: runner-unity:latest
      options: --gpus all

    steps:
      - uses: actions/checkout@v3

      - name: Build Unity Project
        env:
          UNITY_USERNAME: ${{ secrets.UNITY_USERNAME }}
          UNITY_PASSWORD: ${{ secrets.UNITY_PASSWORD }}
          UNITY_SERIAL: ${{ secrets.UNITY_SERIAL }}
          UNITY_PROJECT_PATH: ./UnityProject
          UNITY_BUILD_TARGET: Android
        run: unity-build

      - name: Upload Build
        uses: actions/upload-artifact@v3
        with:
          name: unity-build
          path: ./build
```

## License Activation

### Option 1: License File
Mount your Unity license file to `/root/.local/share/unity3d/Unity/Unity_lic.ulf`

### Option 2: Credentials
Set environment variables:
- `UNITY_USERNAME`
- `UNITY_PASSWORD`
- `UNITY_SERIAL`

The license will be automatically activated and returned after the build.

## Troubleshooting

### Build Fails with License Error
- Ensure license file is correctly mounted or credentials are set
- Check license is valid and not expired
- Verify license supports headless builds

### Out of Memory
- Increase Docker memory limit (8GB+ recommended)
- Close unnecessary applications
- Consider building on a machine with more RAM

### GPU Not Detected
- Install NVIDIA Docker runtime
- Verify `--gpus all` flag is used
- Check NVIDIA drivers are installed on host

## Notes

- Image size is ~10GB+ due to Unity Editor and modules
- First build may take longer due to library compilation
- License activation requires internet connection
- Floating licenses will be returned automatically after build

## Related

- Issue #69: Create Unity Docker image (runner-unity)
- Issue #16: Base runner infrastructure (dependency)
