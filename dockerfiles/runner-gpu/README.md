# GPU Docker Image (runner-gpu)

Docker image for GitHub Actions runners with NVIDIA GPU support for AI/ML workloads.

## Requirements

### Host Requirements
- NVIDIA GPU with CUDA compute capability 3.5 or higher
- NVIDIA GPU drivers (version 525.60.13 or newer)
- Docker with NVIDIA Container Toolkit installed

### NVIDIA Container Toolkit Installation

**Ubuntu/Debian:**
```bash
# Add NVIDIA package repositories
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list

# Install nvidia-container-toolkit
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Restart Docker
sudo systemctl restart docker
```

**WSL2 (Windows):**
1. Install NVIDIA GPU drivers on Windows host (version 525.60.13+)
2. Update WSL2: `wsl --update`
3. Install NVIDIA Container Toolkit in WSL2 Ubuntu distribution (steps above)
4. Ensure Docker Desktop uses WSL2 backend

## Included Software

### CUDA Components
- CUDA 12.3.1
- cuDNN 8

### Python Environment
- Python 3.11
- pip, setuptools, wheel

### ML/AI Frameworks
- PyTorch 2.x (CUDA 12.1)
- TensorFlow 2.x (GPU support)
- Transformers (Hugging Face)
- Accelerate
- Datasets
- Tokenizers

### Scientific Libraries
- NumPy
- SciPy
- Pandas
- Scikit-learn
- Matplotlib
- Seaborn

### Development Tools
- Jupyter, JupyterLab, Notebook
- pytest (with coverage, xdist, asyncio, mock)
- black, flake8, pylint, mypy, isort
- git, curl, wget

## Building the Image

```bash
cd dockerfiles/runner-gpu
docker build -t runner-gpu:latest .
```

**Note:** This image is large (~8-10GB) due to CUDA libraries and ML frameworks.

## Testing GPU Access

Verify GPU is accessible in the container:

```bash
# Run nvidia-smi
docker run --gpus all runner-gpu:latest nvidia-smi

# Test PyTorch CUDA
docker run --gpus all runner-gpu:latest \
  python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA devices: {torch.cuda.device_count()}')"

# Test TensorFlow GPU
docker run --gpus all runner-gpu:latest \
  python -c "import tensorflow as tf; print(f'GPU devices: {tf.config.list_physical_devices(\"GPU\")}')"
```

## Usage in GitHub Actions

**Important:** The GitHub Actions runner host must have NVIDIA GPU and drivers installed.

```yaml
name: GPU Training

on:
  push:
    branches: [ main ]

jobs:
  train-model:
    runs-on: [self-hosted, linux, gpu]
    container:
      image: runner-gpu:latest
      options: --gpus all

    steps:
      - uses: actions/checkout@v4

      - name: Verify GPU access
        run: |
          python -c "import torch; assert torch.cuda.is_available()"
          nvidia-smi

      - name: Install project dependencies
        run: pip install -r requirements.txt

      - name: Train model
        run: python train.py --use-gpu

      - name: Run tests
        run: pytest tests/
```

## Runner Labels

When using this image, ensure your runner has the `gpu` label:

```bash
# When configuring the runner, add labels
./config.sh --url https://github.com/org/repo \
  --token TOKEN \
  --labels self-hosted,linux,docker,gpu
```

## Troubleshooting

### GPU Not Detected

**Check NVIDIA drivers on host:**
```bash
nvidia-smi
```

**Verify NVIDIA runtime:**
```bash
docker run --rm --gpus all nvidia/cuda:12.3.1-base-ubuntu22.04 nvidia-smi
```

**Check Docker daemon configuration:**
```bash
# /etc/docker/daemon.json should contain:
{
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  }
}
```

### Health Check Failures

The health check requires CUDA to be available. If it fails:

1. Ensure `--gpus all` is specified when running the container
2. Verify NVIDIA drivers are installed on host
3. Check NVIDIA Container Toolkit is properly configured
4. Verify GPU is not in use by other processes

### Windows/WSL2 Specific Issues

- Ensure Windows NVIDIA drivers are current (525.60.13+)
- Verify WSL2 is updated: `wsl --update`
- Docker Desktop must use WSL2 backend (not Hyper-V)
- Test GPU access in WSL2: `nvidia-smi` should work from Ubuntu shell

## Performance Considerations

- This image is hardware-dependent and requires NVIDIA GPU
- Build time: 15-30 minutes
- Image size: ~8-10GB
- First run may download additional CUDA libraries

## Security Notes

- Runs as non-root user `runner` (created during build)
- GPU access is controlled via `--gpus` flag
- Suitable for private repositories only
- Do not use with untrusted code (GPU access enables powerful compute)

## Version Information

- Base image: nvidia/cuda:12.3.1-cudnn8-runtime-ubuntu22.04
- Python: 3.11
- PyTorch: Latest compatible with CUDA 12.1
- TensorFlow: Latest with GPU support
- CUDA: 12.3.1
- cuDNN: 8

## References

- [NVIDIA Container Toolkit Documentation](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- [PyTorch CUDA Installation](https://pytorch.org/get-started/locally/)
- [TensorFlow GPU Support](https://www.tensorflow.org/install/gpu)
- [Docker GPU Support](https://docs.docker.com/config/containers/resource_constraints/#gpu)
