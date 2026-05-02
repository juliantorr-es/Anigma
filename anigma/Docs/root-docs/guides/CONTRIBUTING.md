---
title: "Contributing to Anigma"
description: "Guide for contributing to the Anigma project"
audience: ["contributors"]
complexity: "intermediate"
estimated_time: "20 minutes"
status: "stable"
last_updated: "2026-04-16"
---

# Contributing to Anigma

Welcome to the Anigma project! This guide explains how to contribute, how we organize work, and how to get involved.

## Quick Start

1. **Read the Project Structure**: [Project Structure Overview](../getting-started/project-structure.md)
2. **Set up Development**: [Development Workflow](../development/development-workflow.md)
3. **Understand Task System**: [Task System Reference](../reference/task-system-reference.md)
4. **Pick a Task**: `td ready` (shows tasks ready to start)
5. **Start Contributing**: Follow phase-specific guides below

## Working with the Task System

Anigma uses a structured task system called TD (Task Dispatcher) with a 3-phase model: Research → Design → Implementation. All work is tracked and linked to documentation.

### The 3-Phase Model

Every feature or improvement goes through three phases:

#### Phase 1: Research
**Goal**: Understand the problem space

**Your Role**:
- Investigate current state and constraints
- Analyze feasibility and trade-offs
- Document findings and decisions

**Getting Started**: [Research Phase Guide](../development/task-system-research-phase.md)

**Typical Tasks**:
- td-296847: Audit API surface for inconsistencies
- td-245892: Assess test coverage gaps
- td-256789: Analyze module dependencies

#### Phase 2: Design
**Goal**: Create a detailed implementation plan

**Your Role**:
- Choose an approach and justify it
- Create detailed specifications
- Break work into implementation tasks
- Document risks and mitigation strategies

**Getting Started**: [Design Phase Guide](../development/task-system-design-phase.md)

**Typical Tasks**:
- td-296848: Design API consistency standard
- td-276543: Design modular test infrastructure
- td-265234: Design persistence layer refactor

#### Phase 3: Implementation
**Goal**: Build what was designed

**Your Role**:
- Implement features following the design
- Write tests (>80% coverage required)
- Update documentation
- Get code reviewed

**Getting Started**: [Implementation Phase Guide](../development/task-system-implementation-phase.md)

**Typical Tasks**:
- td-296849: Implement URL API refactor
- td-276544: Implement test harness core
- td-265235: Migrate data to new schema

## Essential TD Commands

### Finding Work

```bash
# Check what needs to be done
td usage -q

# See ready-to-start tasks
td ready

# See tasks in review
td in-review

# See tasks blocked on dependencies
td blocked
```

### Working on a Task

```bash
# Start a task
td start <task-id>

# Log progress (every 2-3 hours)
td log <task-id> "What you did, what's next"

# Show task details
td show <task-id>

# Mark complete with summary
td handoff <task-id> \
  --done "What was delivered" \
  --remaining "Any follow-up work" \
  --decision "Why you chose this approach" \
  --uncertain "Open questions"
```

See [Task System Reference](../reference/task-system-reference.md) for complete command reference.

## Code Contribution Workflow

### 1. Claim a Task

```bash
# Find work
td ready

# Start it
td start <task-id>

# Log that you're working on it
td log <task-id> "Starting implementation"
```

### 2. Make Changes

```bash
# Make your code changes in anigma/Sources/[Package]/

# Build to verify
swift build

# Run tests
swift test

# Linting
swift-format lint --strict anigma/Sources/
swiftlint lint anigma/Sources/
```

### 3. Commit with Reference

Include the task ID in your commit message:

```bash
git commit -m "feat(AnigmaCore): refactor URL handling

- Simplified URLPath resolution
- Added 12 unit tests (coverage: 92%)
- Updated documentation

Implements: td-296849
Design: td-296848
Research: td-296847"
```

### 4. Get Code Review

```bash
# Push to your branch
git push origin <branch>

# Create pull request (reference task in PR description)

# Address review comments
```

### 5. Complete Task

```bash
# After approval and merge
td handoff <task-id> \
  --done "Implemented URLPathResolver with 5 implementations, all tests passing (92% coverage), docs updated, PR merged" \
  --remaining "None - task complete" \
  --decision "Used protocol-based design for extensibility" \
  --uncertain "Performance under high load not yet tested"
```

## Code Standards

### Style Guide
- Follow [Code Style Guide](../development/code-style-guide.md)
- Use Swift naming conventions (camelCase for variables, PascalCase for types)
- Max line length: 100 characters

### Testing Requirements
- All new code must have >80% test coverage
- Write tests that verify acceptance criteria
- Include both unit and integration tests where applicable
- See [Testing Strategy](../guides/testing.md)

### Documentation
- Update docs for all public API changes
- Link to task ID in code comments (sparingly)
- Add examples for complex features
- See [Architecture Documentation](../architecture/)

## Submission Checklist

Before marking a task complete:

- [ ] Code compiles: `swift build`
- [ ] All tests pass: `swift test`
- [ ] Test coverage >80%: `swift test --collect-coverage`
- [ ] Code style checked: `swift-format lint`
- [ ] Linting passes: `swiftlint lint`
- [ ] Documentation updated
- [ ] Task ID in commit message
- [ ] Code reviewed and approved
- [ ] Handoff recorded with `td handoff`

## Project Epics

Work is organized into 7 key epics. Pick an epic that interests you:

| Epic | ID | Tasks | Status |
|------|----|----|--------|
| **Harmonia Migration** | td-333894 | 18 | Open |
| **Backend Integration** | td-2c38e1 | 22 | In Progress |
| **CLI Enhancement** | td-9bf6ea | 8 | Open |
| **Performance** | td-9f6d1d | 12 | Open |
| **Testing Infrastructure** | td-0b6df7 | 15 | Open |
| **Architecture** | td-cb6861 | 20 | Open |
| **API Governance** | td-40a6ce | 14 | Open |

For each epic, see its documentation:
- [Harmonia Migration Guide](../architecture/harmonia-backend.md)
- [Build System Guide](../guides/building.md)
- [CLI Reference](../reference/command-line.md)
- [Performance Guide](../architecture/performance.md)
- [Testing Strategy](../guides/testing.md)
- [Architecture Overview](../concepts/architecture.md)
- [API Governance](../reference/api-governance.md)

## Getting Help

- **Understanding the codebase?** → [Project Structure](../getting-started/project-structure.md)
- **Build or test issues?** → [Troubleshooting](../troubleshooting/)
- **Architecture questions?** → [Architecture Guides](../architecture/)
- **Task system questions?** → [Task System Reference](../reference/task-system-reference.md)

## Communication

- **Task updates**: Use `td log` to keep work visible
- **Blockers**: Document with `td log "BLOCKED: reason"` and link with `td block`
- **Questions**: Add comments to task with `td log`
- **Review feedback**: Respond in pull request

## Next Steps

1. **Read**: [Project Structure](../getting-started/project-structure.md)
2. **Setup**: [Development Workflow](../development/development-workflow.md)
3. **Learn**: [Task System Reference](../reference/task-system-reference.md)
4. **Pick an Epic**: Choose from [7 Key Epics](#project-epics)
5. **Find Work**: Run `td ready`
6. **Start**: Follow the [Code Contribution Workflow](#code-contribution-workflow)

---

See also:
- [Development Guide](../development/) - For developers working on Anigma
- [Task System Reference](../reference/task-system-reference.md) - Complete task documentation
- [Back to Docs Home](../README.md)
