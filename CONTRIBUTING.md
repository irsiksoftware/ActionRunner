# Contributing

This project is built by an AI swarm. These principles ensure quality and consistency.

## Development Principles

### TDD (Test-Driven Development)

Every feature requires tests. No exceptions.

1. **Write a failing test first** - Define what "working" means
2. **Implement the minimum to pass** - No gold-plating
3. **Refactor if needed** - Clean up while tests protect you

```
RED → GREEN → REFACTOR
```

### SOLID

- **S**ingle Responsibility - One reason to change per class/module
- **O**pen/Closed - Open for extension, closed for modification
- **L**iskov Substitution - Subtypes must be substitutable
- **I**nterface Segregation - Small, focused interfaces
- **D**ependency Inversion - Depend on abstractions

### DRY (Don't Repeat Yourself)

If you're copying code, extract it. But don't over-abstract - three instances of duplication is the threshold.

## Code Quality

- **No hardcoded secrets** - Use environment variables
- **No magic numbers or string** - Name your constants and keep them consolidated
- **No commented-out code** - Delete it; git remembers

## Commit Messages

```
<type>: <description>

[optional body]
```

Types: `feat`, `fix`, `docs`, `test`, `refactor`, `chore`

## Pull Requests

- One issue per PR
- Tests must pass
- PR description references the issue: `Fixes #123`

---

*These principles are enforced by Professor X (research) and CI (automation).*
