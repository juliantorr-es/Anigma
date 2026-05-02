# Project Instructions: Anigma

Welcome to the Anigma project. This file provides shared architecture, conventions, and workflows for the team and AI agents.

## Agent Skills

This repository is configured with specialized agent skills.

### Engineering & Productivity
- **diagnose**: Use for hard bugs and performance regressions.
- **grill-with-docs**: Use to stress-test plans against domain docs.
- **improve-codebase-architecture**: Use to find refactoring opportunities.
- **tdd**: Use for test-driven development cycles.
- **triage**: Use for managing the issue workflow.
- **zoom-out**: Use for broader context on unfamiliar code.
- **caveman**: Use for ultra-compressed communication.

### Configuration
- **Issue Tracker**: Local TD CLI and markdown files. (`docs/agents/issue-tracker.md`)
- **Triage Labels**: Canonical roles mapped to repo labels. (`docs/agents/triage-labels.md`)
- **Domain Docs**: Multi-context structure via `CONTEXT-MAP.md`. (`docs/agents/domain.md`)

## Development Workflows

### Task Management
We use a custom tool called `td` for task tracking.
- `td status`: Check current task status.
- `td show <id>`: View details of a specific task.

### Testing
- Prefer modern Swift Testing framework over legacy XCTest.
- Always run tests before committing changes.

## Architecture Guidelines
- Follow the multi-context domain documentation layout.
- Maintain `CONTEXT-MAP.md` as the index for all domain contexts.
