---
title: "Development Guide"
description: "Documentation hub for Development Guide"
audience: ["developers", "contributors", "operators", "all"]
complexity: "beginner"
estimated_time: "Varies by document"
status: "stable"
last_updated: "2026-04-16"
---

# Development Guide

Information for developers working on Anigma itself.

## Development Topics

### Core Guides
- **[Project Structure](./project-structure.md)** - How the codebase is organized
- **[Development Workflow](./development-workflow.md)** - Local development
- **[Code Style Guide](./code-style-guide.md)** - Coding conventions
- **[Linting](./linting.md)** - Code quality tools
- **[Testing Strategy](../guides/testing.md)** - How to test
- **[Performance Guidelines](../guides/performance.md)** - Performance expectations
- **[CI/CD Pipeline](./ci-cd-pipeline.md)** - Continuous integration setup

### Working with the Task System

The Anigma project uses a structured task system (TD) with a 3-phase model: Research → Design → Implementation. All work is tracked in TD and linked to documentation.

- **[Task System Reference](../reference/task-system-reference.md)** - Complete task system documentation, epics, and commands
- **[Research Phase Guide](./task-system-research-phase.md)** - What to do during investigation phase
- **[Design Phase Guide](./task-system-design-phase.md)** - What to do during planning phase
- **[Implementation Phase Guide](./task-system-implementation-phase.md)** - What to do during coding phase

#### Quick Start with Tasks

1. Check what to work on: `td usage -q`
2. Start a task: `td start <task-id>`
3. Log progress: `td log <task-id> "What you did and what's next"`
4. Complete: `td handoff <task-id> --done "Summary of work"`

See [Task System Reference](../reference/task-system-reference.md) for all epics and task tracking.

## Getting Started

1. Read [Project Structure](./project-structure.md)
2. Follow [Development Workflow](./development-workflow.md)
3. See [Code Style Guide](./code-style-guide.md) for conventions
4. Learn about [Task System](../reference/task-system-reference.md) for project tracking

---

See also:
- [Back to Docs Home](../README.md)
- [Contributing Guide](../guides/contributing.md)
