# ActionRunner

> Build any project type on your own hardware - without burning GitHub Actions minutes.

## What You Can Do

- **Build anything** - Unity games, web apps, mobile apps, desktop apps, AI projects
- **Stop paying per-minute** - Your hardware, zero overage charges
- **Scale with your swarm** - Parallel builds across your entire org
- **Pick labels, not infrastructure** - Runners auto-detect their capabilities
- **One pool, all repos** - Shared infrastructure serves every repository

## The Magic Moment

Your AI swarm opens 10 PRs across 5 repos. Ten builds start simultaneously on your runner pool. They all finish. Your GitHub bill shows $0 in overage charges.

A developer creates a new Unity project, pushes it, adds `runs-on: [self-hosted, unity-pool]` to the workflow. The build runs. No tickets, no setup, no "please install Unity on the runner."

## Who This Is For

**Teams running AI swarms** that burn through GitHub-hosted minutes faster than budgets allow.

**Organizations with diverse projects** - Unity games, web services, mobile apps, AI/ML pipelines - who want one build infrastructure that handles everything.

**Anyone tired of GitHub Actions bills** who has hardware sitting idle.

## Build Capabilities

| Project Type | Label |
|--------------|-------|
| Unity games | `unity-pool` |
| Web apps (Python, Node, .NET) | `self-hosted` |
| Mobile apps (Android, iOS, React Native, Flutter) | `mobile` |
| Desktop apps (MAUI, WPF) | `desktop` |
| AI/LLM projects | `gpu`, `ai` |
| Docker builds | `docker` |

Runners auto-detect what they can build. Use the label. Get a capable runner.

## Getting Started

Deploy runners to your org. Push code. Builds run on your hardware.

See [docs/QUICK-START.md](docs/QUICK-START.md) for setup.

## Security

This infrastructure is for **private repositories only**. Never use with public repos, untrusted PRs, or third-party forks.
