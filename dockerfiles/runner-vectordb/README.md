# Vector Database Runner Docker Image

Docker image for GitHub Actions runners with vector database clients (Pinecone and Weaviate) and related dependencies.

## Features

- Python 3.11 base
- **Pinecone client** (2.0.0+) - Cloud vector database client
- **Weaviate client** (3.0.0+) - Open-source vector database client
- NumPy, Pandas, scikit-learn for vector operations
- Testing frameworks (pytest, pytest-cov, pytest-asyncio, pytest-mock)
- Code quality tools (black, flake8, pylint, mypy)

## Building the Image

```bash
docker build -t actionrunner-vectordb:latest -f dockerfiles/runner-vectordb/Dockerfile .
```

## Running the Container

```bash
docker run -it --rm actionrunner-vectordb:latest
```

## Using with Vector Databases

### Pinecone (Cloud Service)

To use Pinecone, you need an API key from [Pinecone](https://www.pinecone.io/):

```bash
docker run -it --rm \
  -e PINECONE_API_KEY="your-api-key" \
  actionrunner-vectordb:latest
```

### Weaviate (Local or Cloud)

For local Weaviate instance, use the provided Docker Compose setup:

```bash
# Start Weaviate instance
docker-compose -f docker/docker-compose.vectordb.yml up -d weaviate

# Run the runner container
docker run -it --rm \
  --network actionrunner_vectordb \
  -e WEAVIATE_URL="http://weaviate:8080" \
  actionrunner-vectordb:latest
```

## Verification Scripts

The following PowerShell scripts are available to verify the installations:

- `scripts/verify-pinecone.ps1` - Verify Pinecone client installation
- `scripts/verify-weaviate.ps1` - Verify Weaviate client installation

### Verify Pinecone

```powershell
# Basic verification
.\scripts\verify-pinecone.ps1

# With API key for connection test
.\scripts\verify-pinecone.ps1 -ApiKey "your-api-key"

# JSON output
.\scripts\verify-pinecone.ps1 -JsonOutput
```

### Verify Weaviate

```powershell
# Basic verification
.\scripts\verify-weaviate.ps1

# With custom Weaviate URL
.\scripts\verify-weaviate.ps1 -WeaviateUrl "http://localhost:8080"

# Skip connection test
.\scripts\verify-weaviate.ps1 -SkipConnectionTest

# JSON output
.\scripts\verify-weaviate.ps1 -JsonOutput
```

## Environment Variables

### Pinecone
- `PINECONE_API_KEY` - Your Pinecone API key
- `PINECONE_ENVIRONMENT` - Pinecone environment (e.g., us-west1-gcp)

### Weaviate
- `WEAVIATE_URL` - Weaviate instance URL (default: http://localhost:8080)
- `WEAVIATE_API_KEY` - Optional API key for cloud instances

## Testing

```bash
# Inside the container
python -c "import pinecone; print(f'Pinecone version: {pinecone.__version__}')"
python -c "import weaviate; print(f'Weaviate version: {weaviate.__version__}')"
```

## Image Size

Approximately 1.2GB

## Related Documentation

- [Pinecone Documentation](https://docs.pinecone.io/)
- [Weaviate Documentation](https://weaviate.io/developers/weaviate)
- [Issue #78 - Vector Database Verification](https://github.com/irsiksoftware/ActionRunner/issues/78)
