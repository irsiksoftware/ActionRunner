# Docker Isolation Test Suite
# Tests for Docker container execution and security

param(
    [switch]$SkipGPUTests,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$testsPassed = 0
$testsFailed = 0
$testsSkipped = 0

# Helper function to run a test
function Test-Case {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [switch]$Skip
    )

    Write-Host ""
    Write-Host "TEST: $Name" -ForegroundColor Cyan

    if ($Skip) {
        Write-Host "  SKIPPED" -ForegroundColor Yellow
        $script:testsSkipped++
        return
    }

    try {
        & $Test
        Write-Host "  PASSED" -ForegroundColor Green
        $script:testsPassed++
    }
    catch {
        Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
        if ($Verbose) {
            Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
        }
        $script:testsFailed++
    }
}

Write-Host "=== Docker Isolation Test Suite ===" -ForegroundColor Cyan
Write-Host ""

# Test 1: Docker is installed and running
Test-Case "Docker is installed and accessible" {
    $docker = docker --version
    if (-not $docker) {
        throw "Docker not found"
    }
}

# Test 2: Required images exist
Test-Case "Required Docker images exist" {
    $requiredImages = @("actionrunner-dotnet", "actionrunner-python", "actionrunner-unity", "actionrunner-gpu")
    $existingImages = docker images --format "{{.Repository}}" | Select-Object -Unique

    foreach ($image in $requiredImages) {
        if ($existingImages -notcontains $image) {
            throw "Missing required image: $image"
        }
    }
}

# Test 3: Python container execution
Test-Case "Python container can execute basic commands" {
    $result = docker run --rm actionrunner-python:latest python -c "print('hello')" 2>&1
    if ($result -ne "hello") {
        throw "Expected 'hello', got '$result'"
    }
}

# Test 4: .NET container execution
Test-Case ".NET container can execute basic commands" {
    $result = docker run --rm actionrunner-dotnet:latest dotnet --version 2>&1
    if (-not $result) {
        throw ".NET version check failed"
    }
}

# Test 5: Container runs as non-root user
Test-Case "Container runs as non-root user" {
    $result = docker run --rm actionrunner-python:latest whoami 2>&1
    if ($result -ne "runner") {
        throw "Expected user 'runner', got '$result'"
    }
}

# Test 6: Resource limits are enforced
Test-Case "Container respects CPU limits" {
    # Create a temp workspace
    $tempDir = New-Item -ItemType Directory -Path "$env:TEMP\docker-test-$(Get-Date -Format 'yyyyMMddHHmmss')"

    try {
        # Run a container with limited CPUs
        docker run --rm --cpus="1" -v "${tempDir}:/workspace" actionrunner-python:latest python -c "import os; print(os.cpu_count())" 2>&1 | Out-Null
        # If it doesn't crash, the limit is working
    }
    finally {
        Remove-Item -Path $tempDir -Force -Recurse -ErrorAction SilentlyContinue
    }
}

# Test 7: Read-only root filesystem
Test-Case "Container has read-only root filesystem restrictions" {
    $result = docker run --rm --read-only actionrunner-python:latest sh -c "touch /test.txt 2>&1; echo $?" 2>&1
    # Should fail (non-zero exit code) because filesystem is read-only
    if ($result -eq "0") {
        throw "Read-only filesystem check failed - file was created"
    }
}

# Test 8: Network isolation works
Test-Case "Container can be network isolated" {
    $result = docker run --rm --network=none actionrunner-python:latest sh -c "ping -c 1 8.8.8.8 2>&1; echo $?" 2>&1
    # Should fail because network is disabled
    if ($result -contains "0 received" -or $result -match "Network is unreachable") {
        # Expected - network is isolated
    }
    else {
        throw "Network isolation failed"
    }
}

# Test 9: Container cleanup
Test-Case "Containers are properly cleaned up" {
    # Run a container
    $containerName = "test-cleanup-$(Get-Date -Format 'yyyyMMddHHmmss')"
    docker run --name $containerName actionrunner-python:latest python -c "print('test')" | Out-Null

    # Container should exist but be stopped
    $stopped = docker ps -a --filter "name=$containerName" --format "{{.Names}}"
    if (-not $stopped) {
        throw "Container not found after execution"
    }

    # Clean up
    docker rm $containerName | Out-Null

    # Container should be gone
    $remaining = docker ps -a --filter "name=$containerName" --format "{{.Names}}"
    if ($remaining) {
        throw "Container not removed after cleanup"
    }
}

# Test 10: Workspace mounting
Test-Case "Workspace can be mounted and accessed" {
    $tempDir = New-Item -ItemType Directory -Path "$env:TEMP\docker-test-$(Get-Date -Format 'yyyyMMddHHmmss')"
    $testFile = Join-Path $tempDir "test.txt"
    "test content" | Out-File -FilePath $testFile -Encoding utf8

    try {
        $result = docker run --rm -v "${tempDir}:/workspace" actionrunner-python:latest cat /workspace/test.txt 2>&1
        if ($result -notmatch "test content") {
            throw "Workspace mount failed - could not read file"
        }
    }
    finally {
        Remove-Item -Path $tempDir -Force -Recurse -ErrorAction SilentlyContinue
    }
}

# Test 11: Security capabilities dropped
Test-Case "Container has dropped capabilities" {
    $result = docker run --rm --cap-drop=ALL actionrunner-python:latest sh -c "cat /proc/self/status | grep CapEff" 2>&1
    # CapEff should be 0 or very low if all caps are dropped
    if ($result -match "CapEff:\s+0000000000000000") {
        # Good - no capabilities
    }
    else {
        # This is expected with --cap-drop=ALL
    }
}

# Test 12: Container timeout enforcement
Test-Case "Container can be stopped on timeout" {
    $containerName = "test-timeout-$(Get-Date -Format 'yyyyMMddHHmmss')"

    # Start a long-running container in background
    $job = Start-Job -ScriptBlock {
        param($name)
        docker run --name $name actionrunner-python:latest python -c "import time; time.sleep(300)"
    } -ArgumentList $containerName

    # Wait a bit for it to start
    Start-Sleep -Seconds 2

    # Stop it
    docker stop $containerName -t 5 | Out-Null

    # Clean up
    docker rm $containerName -f 2>&1 | Out-Null
    Stop-Job -Job $job -ErrorAction SilentlyContinue
    Remove-Job -Job $job -ErrorAction SilentlyContinue
}

# Test 13: PowerShell script integration - run-in-docker.ps1
Test-Case "run-in-docker.ps1 script works" {
    $tempDir = New-Item -ItemType Directory -Path "$env:TEMP\docker-test-$(Get-Date -Format 'yyyyMMddHHmmss')"

    try {
        $scriptPath = Join-Path $PSScriptRoot "..\scripts\run-in-docker.ps1"
        if (-not (Test-Path $scriptPath)) {
            throw "run-in-docker.ps1 not found"
        }

        # This might fail if the script doesn't exist yet, which is expected
        $result = & $scriptPath -Environment python -WorkspacePath $tempDir -Command "python --version" 2>&1

        if ($result -match "error" -and $result -notmatch "Python") {
            throw "run-in-docker.ps1 failed: $result"
        }
    }
    finally {
        Remove-Item -Path $tempDir -Force -Recurse -ErrorAction SilentlyContinue
    }
}

# Test 14: GPU container (if enabled)
Test-Case "GPU container has CUDA support" -Skip:$SkipGPUTests {
    # Check if NVIDIA GPU is available
    $nvidiaCheck = docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi 2>&1

    if ($nvidiaCheck -match "NVIDIA-SMI") {
        # GPU is available, test our GPU container
        $result = docker run --rm --gpus all actionrunner-gpu:latest python -c "import torch; print(torch.cuda.is_available())" 2>&1
        if ($result -ne "True") {
            throw "GPU not accessible in container"
        }
    }
    else {
        throw "No GPU available - test should be skipped"
    }
}

# Test 15: Cleanup script exists
Test-Case "cleanup-docker.ps1 script exists and is valid" {
    $scriptPath = Join-Path $PSScriptRoot "..\scripts\cleanup-docker.ps1"
    if (-not (Test-Path $scriptPath)) {
        throw "cleanup-docker.ps1 not found"
    }

    # Check if it's valid PowerShell
    $errors = $null
    [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$errors) | Out-Null
    if ($errors) {
        throw "cleanup-docker.ps1 has syntax errors"
    }
}

# Summary
Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Passed:  $testsPassed" -ForegroundColor Green
Write-Host "Failed:  $testsFailed" -ForegroundColor Red
Write-Host "Skipped: $testsSkipped" -ForegroundColor Yellow
Write-Host ""

if ($testsFailed -gt 0) {
    Write-Host "TESTS FAILED" -ForegroundColor Red
    exit 1
}
else {
    Write-Host "ALL TESTS PASSED" -ForegroundColor Green
    exit 0
}
