---
title: "Project Structure Overview"
description: "Complete overview of the Anigma monorepo layout, package structure, and epic organization"
audience: ["developers", "contributors", "all"]
complexity: "intermediate"
estimated_time: "20min"
keywords: ["structure", "monorepo", "packages", "layout", "organization", "epics"]
status: "stable"
last_updated: "2026-04-16"
---

# Project Structure Overview

This guide explains the Anigma monorepo layout, how packages are organized, and how epics map to the codebase.

## Monorepo Layout

```
Anigma_clean/
├── anigma/                    # Main Swift package
│   ├── Sources/               # Source code
│   │   ├── AnigmaCore/        # Core framework
│   │   ├── AnigmaCorePlugins/ # Plugin system
│   │   ├── AnigmaUI/          # User interface
│   │   ├── AnigmaDaemon/      # Backend daemon
│   │   └── ...
│   └── Tests/                 # Unit tests
├── Docs/                      # Documentation hub
│   ├── README.md              # Landing page
│   ├── getting-started/       # Beginner guides
│   ├── concepts/              # Conceptual understanding
│   ├── guides/                # How-to guides
│   ├── reference/             # API and technical reference
│   ├── architecture/          # Architecture deep dives
│   ├── development/           # Development guides
│   ├── troubleshooting/       # Problem solving
│   └── _navigation.json       # Navigation metadata
├── scripts/                   # Build and utility scripts
├── tools/                     # Developer tools
├── Tests/                     # Integration tests
├── justfile                   # Just command recipes
└── Package.swift              # Swift package manifest

```

## Package Structure

### Core Packages

```
anigma/Sources/
├── AnigmaCore/
│   ├── Foundation/            # Base types and utilities
│   │   ├── Collections/
│   │   ├── Utilities/
│   │   └── Concurrency/
│   ├── Storage/               # Persistence layer
│   │   ├── Database/
│   │   ├── FileSystem/
│   │   └── Cache/
│   └── Runtime/               # Execution runtime
│       ├── Scheduler/
│       ├── Memory/
│       └── Observability/
│
├── AnigmaCorePlugins/
│   ├── Plugins/               # Plugin framework
│   ├── Registry/              # Plugin registry
│   └── Bundled/               # Built-in plugins
│
├── AnigmaUI/
│   ├── Components/            # UI components
│   ├── Views/                 # View hierarchy
│   ├── Navigation/            # Navigation system
│   └── Styling/               # Themes and styling
│
├── AnigmaDaemon/              # Backend daemon
│   ├── Server/                # Daemon server
│   ├── Protocol/              # Communication protocol
│   ├── Coordination/          # Coordination logic
│   └── Observability/         # Logging and metrics
│
├── HarmoniaRuntime/           # Harmonia V3 runtime
│   ├── Conductor/             # Task orchestration
│   ├── Engine/                # Evaluation engine
│   ├── Memory/                # Memory system
│   └── Contracts/             # Runtime contracts
│
└── HarmoniaModule/ (Legacy)   # Harmonia V2 (migrating)
    ├── Inference/
    ├── Tools/
    └── Utilities/
```

## Directory Structure: Where to Look

### For Different Tasks

| Task Type | Primary Location | Related Docs |
|-----------|------------------|--------------|
| **API Design** | `AnigmaCore/Foundation/` | [API Governance](../reference/api-governance.md) |
| **Database** | `AnigmaCore/Storage/Database/` | [Database Architecture](../architecture/database-architecture.md) |
| **UI/Frontend** | `AnigmaUI/` | [UI Architecture](../architecture/ui.md) |
| **Daemon/Backend** | `AnigmaDaemon/` | [Daemon Documentation](../guides/running-in-production.md) |
| **Plugin System** | `AnigmaCorePlugins/` | [Plugin System](../architecture/plugins.md) |
| **Harmonia V3** | `HarmoniaRuntime/` | [Harmonia Migration](../architecture/harmonia-backend.md) |
| **Tests** | `anigma/Tests/` and `Tests/` | [Testing Strategy](../guides/testing.md) |
| **Build Scripts** | `scripts/` and `justfile` | [Building Anigma](../guides/building.md) |

### Documentation Map

```
Docs/
├── getting-started/           # 🚀 Where to begin
│   ├── README.md              # Getting started hub
│   ├── installation.md        # Setup and installation
│   └── first-project.md       # Your first project
│
├── concepts/                  # 📚 Understanding the system
│   ├── architecture.md        # System design
│   ├── modules.md             # Component inventory
│   ├── data-model.md          # How data flows
│   └── design-principles.md   # Why we design this way
│
├── guides/                    # 🔨 How-to guides
│   ├── building.md            # Compilation
│   ├── testing.md             # Running tests
│   ├── cli-view.md            # Command-line interface
│   └── implementing-features.md # Adding new features
│
├── reference/                 # 🔧 Technical reference
│   ├── api.md                 # API documentation
│   ├── api-governance.md      # API design policies
│   ├── configuration.md       # Configuration options
│   ├── task-system-reference.md # Task system guide
│   └── type-audits.md         # Type standards
│
├── architecture/              # 🏗️ Architecture deep dives
│   ├── README.md              # Architecture hub
│   ├── plugin-system.md       # Extensibility
│   ├── database-architecture.md # Persistence
│   ├── harmonia-backend.md    # Harmonia V3 migration
│   └── observability.md       # Logging and metrics
│
├── development/               # 👨‍💻 Developer guides
│   ├── README.md              # Development hub
│   ├── project-structure.md   # Codebase layout (this file)
│   ├── task-system-reference.md # Task system documentation
│   ├── task-system-research-phase.md # Research phase guide
│   ├── task-system-design-phase.md # Design phase guide
│   ├── task-system-implementation-phase.md # Implementation phase guide
│   └── code-style-guide.md    # Coding conventions
│
├── troubleshooting/           # ❓ Problem solving
│   ├── build-issues.md        # Build error solutions
│   ├── compilation.md         # Compilation troubleshooting
│   └── mlx-compilation.md     # MLX-specific issues
│
└── _navigation.json           # 🗺️ Navigation metadata
```

## Epic Organization

### By Category

#### 1. Harmonia Migration Epic
**ID**: `td-333894`  
**Status**: Open  
**Docs**: [Harmonia Migration Guide](../architecture/harmonia-backend.md)

**Scope**:
- Migrate from Harmonia V2 to V3 runtime
- Replace legacy HarmoniaModule functionality
- Implement modern architecture

**Related Packages**:
- `HarmoniaModule/` (being replaced)
- `HarmoniaRuntime/` (new implementation)

**Key Tasks**:
- Research: Understand V2 API surface
- Design: V3 architecture and migration strategy
- Implement: Conductor, engine, memory system

---

#### 2. Backend Integration Epic
**ID**: `td-2c38e1`  
**Status**: In Progress  
**Docs**: [Build System](../guides/building.md)

**Scope**:
- Stabilize AnigmaDaemon executable
- Fix compilation errors
- Establish backend contracts

**Related Packages**:
- `AnigmaDaemon/`
- `AnigmaCore/`

**Key Tasks**:
- Resolve AnigmaCore module errors
- Define daemon lifecycle contracts
- Implement backend observability

---

#### 3. CLI Enhancement Epic
**ID**: `td-9bf6ea`  
**Status**: Open  
**Docs**: [CLI Reference](../reference/command-line.md)

**Scope**:
- Improve command-line interface
- Add new CLI commands
- Standardize CLI patterns

**Related Packages**:
- `scripts/` (CLI tooling)

**Key Tasks**:
- Audit existing CLI
- Design new CLI patterns
- Implement commands

---

#### 4. Performance Optimization Epic
**ID**: `td-9f6d1d`  
**Status**: Open  
**Docs**: [Performance Guide](../architecture/performance.md)

**Scope**:
- Optimize AnigmaCore runtime
- Reduce memory footprint
- Improve throughput

**Related Packages**:
- `AnigmaCore/Runtime/`
- `AnigmaCore/Storage/`

**Key Tasks**:
- Profile and analyze
- Design optimization strategies
- Implement improvements

---

#### 5. Testing Infrastructure Epic
**ID**: `td-0b6df7`  
**Status**: Open  
**Docs**: [Testing Strategy](../guides/testing.md)

**Scope**:
- Build comprehensive test matrix
- Automate integration tests
- Standardize test practices

**Related Packages**:
- `anigma/Tests/`
- `Tests/` (integration tests)

**Key Tasks**:
- Design test infrastructure
- Implement test harness
- Add integration test suite

---

#### 6. Architecture Consolidation Epic
**ID**: `td-cb6861`  
**Status**: Open  
**Docs**: [Architecture Overview](../concepts/architecture.md)

**Scope**:
- Consolidate module redundancy
- Define canonical patterns
- Establish architecture governance

**Related Packages**:
- All packages

**Key Tasks**:
- Audit for redundancy
- Design consolidation strategy
- Implement merged modules

---

#### 7. Foundation API Governance Epic
**ID**: `td-40a6ce`  
**Status**: Open  
**Docs**: [API Governance](../reference/api-governance.md)

**Scope**:
- Define API design policies
- Enforce API consistency
- Document API patterns

**Related Packages**:
- `AnigmaCore/Foundation/`

**Key Tasks**:
- Research current API patterns
- Design consistency guidelines
- Implement linting/enforcement

---

## Quick Lookup: Package to Epic

| Package | Primary Epic | Secondary Epics | Status |
|---------|--------------|-----------------|--------|
| AnigmaCore | Foundation API | Performance | Active |
| AnigmaUI | Frontend UX | (Separate tracking) | Active |
| AnigmaDaemon | Backend Integration | Reliability | Active |
| HarmoniaRuntime | Harmonia Migration | Performance | Active |
| AnigmaCorePlugins | Architecture Consolidation | (Separate) | Open |

## Quick Lookup: Epic to Documentation

| Epic | Title | Docs | Tasks | Status |
|------|-------|------|-------|--------|
| td-333894 | Harmonia Migration | [Link](../architecture/harmonia-backend.md) | 18 | Open |
| td-2c38e1 | Backend Integration | [Link](../guides/building.md) | 22 | In Progress |
| td-9bf6ea | CLI Enhancement | [Link](../reference/command-line.md) | 8 | Open |
| td-9f6d1d | Performance | [Link](../architecture/performance.md) | 12 | Open |
| td-0b6df7 | Testing | [Link](../guides/testing.md) | 15 | Open |
| td-cb6861 | Architecture | [Link](../concepts/architecture.md) | 20 | Open |
| td-40a6ce | API Governance | [Link](../reference/api-governance.md) | 14 | Open |

## File Organization Best Practices

### Creating New Code

1. **Determine Epic**: Which epic is this work part of?
2. **Locate Package**: Find the appropriate package in `anigma/Sources/`
3. **Create Module**: Add code in appropriate module directory
4. **Link Task**: Reference task ID in commit message

### Creating New Documentation

1. **Determine Audience**: Who needs to know this?
2. **Pick Category**: Which Docs/ subdirectory?
3. **Add Navigation**: Update _navigation.json
4. **Link to Tasks**: Reference related task IDs

### Linking Package Changes to Epics

In commit message:
```
feat(AnigmaCore): refactor URLPath handling

- Simplified URLPath resolution logic
- Improved error handling
- Added 12 new unit tests

See epic: td-40a6ce (API Governance)
Implementation task: td-296849
```

In code comments (sparingly):
```swift
// URLPath design: see td-296848 and [URL Path Guide](../../Docs/guides/url-paths.md)
public struct URLPath {
    // ...
}
```

## Development Workflow by Epic

### Example: Working on Backend Integration (td-2c38e1)

```
1. Start with: /Docs/guides/building.md (understand build process)
2. Check epic status: td usage -q | grep td-2c38e1
3. Pick a task: td start <task-id>
4. Work in: anigma/Sources/AnigmaDaemon/
5. Test: swift test TestAnigmaDaemon
6. Log progress: td log <task-id> "Fixed 15 errors in Server module"
7. Commit: git commit -m "fix(AnigmaDaemon): resolve compilation errors

   - Fixed Server initialization
   - Added contract validation
   - See epic: td-2c38e1"
8. Complete: td handoff <task-id> --done "..."
```

### Example: Working on Harmonia Migration (td-333894)

```
1. Start with: /Docs/architecture/harmonia-backend.md
2. Check epic: td show td-333894
3. Pick research/design/implementation task
4. Work in: HarmoniaRuntime/ package
5. Cross-reference: HarmoniaModule/ (legacy, being replaced)
6. Test: swift test TestHarmoniaRuntime
7. Log: td log <task-id> "Implemented Conductor facade"
8. Commit with epic link: git commit -m "feat(HarmoniaRuntime): implement Conductor

   - Created Conductor orchestration layer
   - Added task execution contract
   - See epic: td-333894 (Harmonia Migration)"
```

## Navigation Quick Links

- 🚀 [Getting Started](../getting-started/) - New? Start here
- 📚 [Concepts](../concepts/) - Understand the system
- 🔨 [Guides](../guides/) - How-to and step-by-step
- 🔧 [Reference](../reference/) - API and technical details
- 🏗️ [Architecture](../architecture/) - Deep technical dives
- 👨‍💻 [Development](../development/) - For developers working on Anigma
- ❓ [Troubleshooting](../troubleshooting/) - Problem solving

---

See also:
- [Task System Reference](../reference/task-system-reference.md) - Understand how tasks work
- [Back to Development Guide](./README.md)
- [Back to Docs Home](../README.md)
