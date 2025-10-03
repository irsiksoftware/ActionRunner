#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests for Docker isolation setup
#>

Describe "Docker Isolation Tests" {
    BeforeAll {
        $dockerDir = Join-Path $PSScriptRoot "..\docker"
        $scriptsDir = Join-Path $PSScriptRoot "..\scripts"
    }

    Context "Docker Configuration Files" {
        It "Should have Dockerfile.unity" {
            $path = Join-Path $dockerDir "Dockerfile.unity"
            Test-Path $path | Should -Be $true
        }

        It "Should have Dockerfile.python" {
            $path = Join-Path $dockerDir "Dockerfile.python"
            Test-Path $path | Should -Be $true
        }

        It "Should have Dockerfile.dotnet" {
            $path = Join-Path $dockerDir "Dockerfile.dotnet"
            Test-Path $path | Should -Be $true
        }

        It "Should have Dockerfile.gpu" {
            $path = Join-Path $dockerDir "Dockerfile.gpu"
            Test-Path $path | Should -Be $true
        }

        It "Should have .dockerignore" {
            $path = Join-Path $dockerDir ".dockerignore"
            Test-Path $path | Should -Be $true
        }
    }

    Context "Setup Script" {
        It "Should have setup-docker.ps1 script" {
            $path = Join-Path $scriptsDir "setup-docker.ps1"
            Test-Path $path | Should -Be $true
        }

        It "setup-docker.ps1 should be valid PowerShell" {
            $path = Join-Path $scriptsDir "setup-docker.ps1"
            { . $path -ErrorAction Stop } | Should -Not -Throw
        }
    }

    Context "Dockerfile Syntax" {
        It "Dockerfile.unity should have FROM instruction" {
            $path = Join-Path $dockerDir "Dockerfile.unity"
            $content = Get-Content $path -Raw
            $content | Should -Match "FROM\s+"
        }

        It "Dockerfile.python should have FROM instruction" {
            $path = Join-Path $dockerDir "Dockerfile.python"
            $content = Get-Content $path -Raw
            $content | Should -Match "FROM\s+"
        }

        It "Dockerfile.dotnet should have FROM instruction" {
            $path = Join-Path $dockerDir "Dockerfile.dotnet"
            $content = Get-Content $path -Raw
            $content | Should -Match "FROM\s+"
        }

        It "Dockerfile.gpu should have FROM instruction" {
            $path = Join-Path $dockerDir "Dockerfile.gpu"
            $content = Get-Content $path -Raw
            $content | Should -Match "FROM\s+"
        }

        It "All Dockerfiles should create non-root user" {
            $dockerfiles = @(
                "Dockerfile.unity",
                "Dockerfile.python",
                "Dockerfile.dotnet",
                "Dockerfile.gpu"
            )

            foreach ($dockerfile in $dockerfiles) {
                $path = Join-Path $dockerDir $dockerfile
                $content = Get-Content $path -Raw
                $content | Should -Match "useradd.*runner"
            }
        }

        It "All Dockerfiles should set USER to runner" {
            $dockerfiles = @(
                "Dockerfile.unity",
                "Dockerfile.python",
                "Dockerfile.dotnet",
                "Dockerfile.gpu"
            )

            foreach ($dockerfile in $dockerfiles) {
                $path = Join-Path $dockerDir $dockerfile
                $content = Get-Content $path -Raw
                $content | Should -Match "USER\s+runner"
            }
        }

        It "All Dockerfiles should have WORKDIR" {
            $dockerfiles = @(
                "Dockerfile.unity",
                "Dockerfile.python",
                "Dockerfile.dotnet",
                "Dockerfile.gpu"
            )

            foreach ($dockerfile in $dockerfiles) {
                $path = Join-Path $dockerDir $dockerfile
                $content = Get-Content $path -Raw
                $content | Should -Match "WORKDIR\s+"
            }
        }

        It "All Dockerfiles should have HEALTHCHECK" {
            $dockerfiles = @(
                "Dockerfile.unity",
                "Dockerfile.python",
                "Dockerfile.dotnet",
                "Dockerfile.gpu"
            )

            foreach ($dockerfile in $dockerfiles) {
                $path = Join-Path $dockerDir $dockerfile
                $content = Get-Content $path -Raw
                $content | Should -Match "HEALTHCHECK"
            }
        }
    }

    Context "Docker Image Validation" -Skip {
        # These tests require Docker to be installed and running
        # Skip by default, run manually with -Skip:$false

        BeforeAll {
            $dockerAvailable = $null -ne (Get-Command docker -ErrorAction SilentlyContinue)
        }

        It "Should have Docker installed" {
            $dockerAvailable | Should -Be $true
        }

        It "Docker should be running" {
            if ($dockerAvailable) {
                { docker ps } | Should -Not -Throw
            }
        }

        It "Should build Unity image successfully" {
            if ($dockerAvailable) {
                $path = Join-Path $dockerDir "Dockerfile.unity"
                $result = docker build -t actionrunner/unity:test -f $path $dockerDir 2>&1
                $LASTEXITCODE | Should -Be 0
            }
        }

        It "Should build Python image successfully" {
            if ($dockerAvailable) {
                $path = Join-Path $dockerDir "Dockerfile.python"
                $result = docker build -t actionrunner/python:test -f $path $dockerDir 2>&1
                $LASTEXITCODE | Should -Be 0
            }
        }

        It "Should build .NET image successfully" {
            if ($dockerAvailable) {
                $path = Join-Path $dockerDir "Dockerfile.dotnet"
                $result = docker build -t actionrunner/dotnet:test -f $path $dockerDir 2>&1
                $LASTEXITCODE | Should -Be 0
            }
        }

        It "Should build GPU image successfully" {
            if ($dockerAvailable) {
                $path = Join-Path $dockerDir "Dockerfile.gpu"
                $result = docker build -t actionrunner/gpu:test -f $path $dockerDir 2>&1
                $LASTEXITCODE | Should -Be 0
            }
        }
    }

    Context "Security Configuration" {
        It "Dockerfiles should not run as root" {
            $dockerfiles = @(
                "Dockerfile.unity",
                "Dockerfile.python",
                "Dockerfile.dotnet",
                "Dockerfile.gpu"
            )

            foreach ($dockerfile in $dockerfiles) {
                $path = Join-Path $dockerDir $dockerfile
                $content = Get-Content $path -Raw
                # Should switch to non-root user before CMD
                $userIndex = $content.IndexOf("USER runner")
                $cmdIndex = $content.IndexOf("CMD")
                $userIndex | Should -BeLessThan $cmdIndex
            }
        }

        It ".dockerignore should exclude sensitive files" {
            $path = Join-Path $dockerDir ".dockerignore"
            $content = Get-Content $path -Raw

            # Check for common sensitive patterns
            $content | Should -Match "\.env"
            $content | Should -Match "\.git"
        }
    }

    Context "Documentation" {
        It "Should have docker-isolation.md documentation" {
            $path = Join-Path $PSScriptRoot "..\docs\docker-isolation.md"
            Test-Path $path | Should -Be $true
        }

        It "Documentation should include setup instructions" {
            $path = Join-Path $PSScriptRoot "..\docs\docker-isolation.md"
            $content = Get-Content $path -Raw
            $content | Should -Match "(?i)setup|installation"
        }

        It "Documentation should include usage examples" {
            $path = Join-Path $PSScriptRoot "..\docs\docker-isolation.md"
            $content = Get-Content $path -Raw
            $content | Should -Match "(?i)usage|example"
        }

        It "Documentation should include security section" {
            $path = Join-Path $PSScriptRoot "..\docs\docker-isolation.md"
            $content = Get-Content $path -Raw
            $content | Should -Match "(?i)security"
        }
    }
}
