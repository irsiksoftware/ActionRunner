# Pester tests for install-runner-devstack.sh
# Tests the Jesus Project development stack installation script

$scriptPath = Join-Path (Join-Path $PSScriptRoot "..") "scripts\install-runner-devstack.sh"

Describe "install-runner-devstack.sh Script Validation" {
    Context "File Existence and Permissions" {
        It "Script file should exist" {
            $scriptPath | Should -Exist
        }

        It "Should be a valid shell script" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "^#!/bin/bash"
        }
    }

    Context "Script Structure and Documentation" {
        It "Should contain usage documentation" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "usage\(\)"
        }

        It "Should have installation log configuration" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "LOG_FILE="
        }

        It "Should contain version configuration" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'NODEJS_VERSION="20"'
            $content | Should -Match 'PNPM_VERSION="9"'
            $content | Should -Match 'PYTHON_VERSION="3.11"'
        }

        It "Should include error handling (set -e)" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "set -e"
        }
    }

    Context "Command-Line Options" {
        It "Should support --skip-nodejs option" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "--skip-nodejs"
            $content | Should -Match "SKIP_NODEJS"
        }

        It "Should support --skip-python option" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "--skip-python"
            $content | Should -Match "SKIP_PYTHON"
        }

        It "Should support --skip-docker option" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "--skip-docker"
            $content | Should -Match "SKIP_DOCKER"
        }

        It "Should support --skip-security option" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "--skip-security"
            $content | Should -Match "SKIP_SECURITY"
        }

        It "Should support --help option" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "--help"
        }
    }

    Context "Node.js Installation Functions" {
        It "Should contain Node.js installation function" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "install_nodejs\(\)"
        }

        It "Should check for existing Node.js installation" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "command -v node"
        }

        It "Should use NodeSource repository" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "nodesource"
        }

        It "Should verify Node.js installation" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "node --version"
        }

        It "Should contain pnpm installation function" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "install_pnpm\(\)"
        }

        It "Should install pnpm globally via npm" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "npm install -g pnpm"
        }

        It "Should configure pnpm cache directory" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "\.pnpm-store"
        }
    }

    Context "Python Installation Functions" {
        It "Should contain Python installation function" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "install_python\(\)"
        }

        It "Should use deadsnakes PPA for Python 3.11" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "deadsnakes"
        }

        It "Should install Python 3.11 with venv and dev packages" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "python3\.11-venv"
            $content | Should -Match "python3\.11-dev"
        }

        It "Should set Python 3.11 as default" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "update-alternatives"
        }

        It "Should contain Python security tools installation" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "install_python_security_tools\(\)"
        }

        It "Should install pip-audit" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "pip install.*pip-audit"
        }

        It "Should install detect-secrets" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "pip install.*detect-secrets"
        }
    }

    Context "Docker Installation Functions" {
        It "Should contain Docker installation function" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "install_docker\(\)"
        }

        It "Should check for existing Docker installation" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "command -v docker"
        }

        It "Should use official Docker repository" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "download\.docker\.com"
        }

        It "Should install Docker BuildKit plugin" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "docker-buildx-plugin"
        }

        It "Should install Docker Compose plugin" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "docker-compose-plugin"
        }

        It "Should enable BuildKit in daemon config" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "buildkit.*true"
        }

        It "Should add runner user to docker group" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "usermod -aG docker"
        }

        It "Should enable and start Docker service" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "systemctl enable docker"
            $content | Should -Match "systemctl restart docker"
        }
    }

    Context "Security Tools Installation" {
        It "Should contain OSV Scanner installation function" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "install_osv_scanner\(\)"
        }

        It "Should detect system architecture" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "uname -m"
        }

        It "Should download OSV Scanner from GitHub releases" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "github\.com/google/osv-scanner"
        }

        It "Should install OSV Scanner to /usr/local/bin" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "/usr/local/bin/osv-scanner"
        }

        It "Should verify OSV Scanner installation" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "osv-scanner --version"
        }
    }

    Context "Jesus Project Specific Requirements" {
        It "Should reference Jesus MCP Agentic AI Platform" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "Jesus.*MCP.*Agentic.*AI.*Platform"
        }

        It "Should install required Node.js version 20" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'NODEJS_VERSION="20"'
        }

        It "Should install required pnpm version 9" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'PNPM_VERSION="9"'
        }

        It "Should install required Python version 3.11" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match 'PYTHON_VERSION="3.11"'
        }

        It "Should mention runner labels in next steps" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "nodejs.*python.*docker"
        }

        It "Should recommend 100GB minimum disk space" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "100GB"
        }

        It "Should recommend 500GB for MCP development" {
            $content = Get-Content $scriptPath -Raw
            $content | Should -Match "500GB"
        }
    }
}
