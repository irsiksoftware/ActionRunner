# Build Capability Testing

This project uses capability-based test organization to provide clear visibility into which build environments and frameworks are supported.

## Quick Start

### Run All Capability Tests
```powershell
.\scripts\run-tests-by-capability.ps1 -Capability All
```

### Run Specific Capability Tests
```powershell
# Core infrastructure (runner setup, config, monitoring)
.\scripts\run-tests-by-capability.ps1 -Capability Core

# Web application support (Python, .NET, Node.js)
.\scripts\run-tests-by-capability.ps1 -Capability WebApp

# Docker and containers
.\scripts\run-tests-by-capability.ps1 -Capability Docker

# Integration and workflows
.\scripts\run-tests-by-capability.ps1 -Capability Integration

# Mobile support (Unity, Android, iOS, etc.)
.\scripts\run-tests-by-capability.ps1 -Capability Mobile

# AI/LLM support (LangChain, OpenAI, etc.)
.\scripts\run-tests-by-capability.ps1 -Capability AI
```

## Capability Categories

### ⚙️ Core Infrastructure
**Status Goal:** ✓ Must Pass

Essential runner functionality:
- Runner setup and configuration
- Health monitoring
- Maintenance mode
- Update management
- Configuration management

**Tests:**
- `setup-runner.Tests.ps1`
- `apply-config.Tests.ps1`
- `health-check.Tests.ps1`
- `monitor-runner.Tests.ps1`
- `maintenance-mode.Tests.ps1`
- `update-runner.Tests.ps1`
- `check-runner-updates.Tests.ps1`

### 🌐 Web Application Build Support
**Status Goal:** ✓ Must Pass (Priority 1)

Web frameworks and languages:
- Python (Flask, Django)
- .NET (ASP.NET Core)
- Node.js (Express, Next.js)
- Package managers (pip, npm, pnpm, NuGet)

**Tests:**
- `verify-jesus-environment.Tests.ps1`
- `install-runner-devstack.Tests.ps1`

**Current Status:** Partial - needs Docker images and framework verification

### 🐳 Docker & Container Support
**Status Goal:** ✓ Must Pass (Priority 1)

Container infrastructure:
- Docker Desktop / WSL2
- Container images for each framework
- GPU support (optional)
- Container orchestration

**Tests:**
- `setup-docker.Tests.ps1`
- `cleanup-docker.Tests.ps1`

**Current Status:** Partial - needs Docker images built

### 📱 Mobile Build Support
**Status Goal:** ⚠ Optional (Priority 3)

Mobile development frameworks:
- Unity (3D/2D games)
- Android (SDK, Gradle)
- iOS (Xcode) - macOS only
- React Native
- Flutter

**Tests:**
- (To be created in Phase 3)

**Current Status:** Not implemented

### 🤖 AI/LLM Build Support
**Status Goal:** ⚠ Optional (Priority 4)

AI/ML frameworks:
- LangChain
- OpenAI SDK
- Vector databases (Pinecone, Weaviate)
- Model serving (vLLM, TGI)
- Embedding models

**Tests:**
- (To be created in Phase 4)

**Current Status:** Not implemented

### 🔄 Integration & Workflows
**Status Goal:** ✓ Must Pass

GitHub Actions integration:
- Workflow configuration
- Runner registration
- Self-hosted migration
- Dashboard and reporting

**Tests:**
- `Workflows.Tests.ps1`
- `migrate-to-self-hosted.Tests.ps1`
- `register-runner.Tests.ps1`
- `self-hosted-runner.Tests.ps1`
- `dashboard.Tests.ps1`

## CI/CD Integration

### GitHub Actions Workflow

The project includes a capability-based CI workflow at `.github/workflows/capability-tests.yml` that:

1. Runs each capability as a separate job
2. Shows clear status for each build capability
3. Generates visual status reports
4. Uploads test results as artifacts

### Status Indicators

- ✓ **Pass** (Green) - All tests passing, capability fully functional
- ⚠ **Warning** (Yellow) - 80%+ tests passing, mostly functional
- ✗ **Fail** (Red) - <80% tests passing, needs attention

### Viewing Results

#### In GitHub Actions UI
Each capability appears as a separate job with icon:
- ⚙️ Core Infrastructure
- 🌐 Web Application Support
- 🐳 Docker & Container Support
- 📱 Mobile Build Support
- 🤖 AI/LLM Build Support
- 🔄 Integration & Workflows

#### Local Testing
Run `.\scripts\run-tests-by-capability.ps1 -Capability All` to see:
- Visual status for each capability
- Pass/fail counts
- Overall build health

## Development Workflow

### Adding New Capabilities

1. **Add tests to appropriate capability bucket** in `run-tests-by-capability.ps1`
2. **Tag tests appropriately** (if using Pester tags)
3. **Update workflow** if needed
4. **Run capability tests** to verify

### Improving Test Coverage

Follow the roadmap in `test-improvement-roadmap.csv`:

1. **Phase 1 (Priority 1):** Web app support - Quick wins
   - Create Docker images for Python, .NET, Node.js
   - Add framework verification tests
   - Target: 80% overall pass rate

2. **Phase 2 (Priority 2):** Infrastructure & Integration
   - Docker/WSL2 setup
   - GitHub API integration
   - Database verification
   - Target: 90% overall pass rate

3. **Phase 3 (Priority 3):** Mobile support
   - Android, React Native, Flutter
   - Unity (if needed)
   - Target: 95% overall pass rate

4. **Phase 4 (Priority 4):** AI/LLM support
   - LangChain, OpenAI, vector databases
   - Model serving
   - Target: 100% pass rate

## Monitoring Build Capabilities

### Quick Status Check
```powershell
# Run all tests and show summary
.\scripts\run-tests-by-capability.ps1 -Capability All

# Output shows:
# ⚙️ ✓ Core Infrastructure: 45/45 (100%)
# 🌐 ⚠ Web Application Support: 18/25 (72%)
# 🐳 ✗ Docker & Container Support: 12/40 (30%)
# ...
```

### Generate Report for CI
```powershell
.\scripts\run-tests-by-capability.ps1 -Capability All -CI
# Creates: test-capability-status.json
```

## Files Created

- `scripts/run-tests-by-capability.ps1` - Capability test runner
- `.github/workflows/capability-tests.yml` - CI workflow
- `test-capability-status.json` - JSON status output (generated by CI)

## Next Steps

1. Review `test-improvement-roadmap.csv` for prioritized issues
2. Start with Priority 1 (Web App) quick wins:
   - Fix error handling in apply-config.ps1
   - Create Python/NET/Node.js Docker images
   - Add framework verification tests
3. Run capability tests to track progress
4. Generate dashboard to visualize improvements

## Support

See `test-improvement-summary.md` for:
- Detailed roadmap
- Sprint planning
- Dependency mapping
- Risk assessment
