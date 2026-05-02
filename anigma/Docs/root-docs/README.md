---
title: "Anigma Documentation"
description: "Welcome to Anigma - distributed AI inference and data processing platform"
audience: ["all"]
complexity: "beginner"
estimated_time: "Varies by section"
keywords: ["anigma", "documentation", "getting started", "learning"]
status: "stable"
last_updated: "2026-04-16"
---

# Anigma Documentation

Welcome to the Anigma documentation. This directory contains comprehensive guides for using, building, and contributing to Anigma.

## Quick Navigation

### 🚀 Getting Started
New to Anigma? Start here:
- [Installation Guide](./getting-started/mcp-installation.md) - Set up Anigma
- [Quick Start](./getting-started/quick-start.md) - Your first steps
- [MCP Setup](./getting-started/local-setup.md) - Configure MCP

### 📚 Learn Concepts
Understand the fundamentals:
- [Architecture Overview](./concepts/architecture.md) - System design
- [Components](./concepts/) - Key building blocks
- [Backend Architecture](./concepts/backend.md) - Backend systems

### 📖 How-To Guides
Step-by-step guides for common tasks:
- [Building Anigma](./guides/) - Compilation and build process
- [Testing](./guides/testing.md) - Running tests
- [CLI Usage](./guides/cli-view.md) - Command-line interface
- [Performance Tuning](./guides/performance.md) - Optimization

### 🔍 Reference Documentation
Detailed API and configuration reference:
- [API Governance](./reference/api-governance.md) - API design policies
- [Configuration Reference](./reference/) - Configuration options
- [Type Audits & Standards](./reference/type-audits.md) - Swift type standards
- [Linting Rules](./reference/linting.md) - Code quality standards

### 🏗️ Architecture Deep Dives
Advanced architecture documentation:
- [Event-Driven Architecture](./architecture/) - Event handling system
- [Plugin System](./architecture/plugins.md) - Extensibility
- [Harmonia Integration](./architecture/harmonia-backend.md) - Harmonia subsystem
- [Performance Characteristics](./architecture/performance.md) - Performance analysis

### 🚨 Troubleshooting
Solutions to common problems:
- [Build Issues](./troubleshooting/compilation.md) - Fixing build errors
- [MLX Compilation](./troubleshooting/mlx-compilation.md) - MLX-specific issues
- [Runtime Problems](./troubleshooting/) - Runtime troubleshooting

### 👨‍💻 Development
For developers working on Anigma:
- [Project Structure](./getting-started/project-structure.md) - Monorepo layout and epic organization
- [Development Workflow](./development/) - Local development
- [Task System Reference](./reference/task-system-reference.md) - How work is tracked and organized
- [Code Style Guide](./development/code-style-guide.md) - Coding conventions
- [Linting Guide](./development/linting.md) - Linting best practices

### 🎯 Working with Tasks
How to work on Anigma using the task system:
- [Task System Overview](./reference/task-system-reference.md) - Complete task documentation, all 7 epics
- [Research Phase Guide](./development/task-system-research-phase.md) - How to investigate and understand problems
- [Design Phase Guide](./development/task-system-design-phase.md) - How to plan and design solutions
- [Implementation Phase Guide](./development/task-system-implementation-phase.md) - How to build and verify
- [Contributing Guide](./guides/CONTRIBUTING.md) - Step-by-step contribution workflow

### 📦 Releases
Version history and upgrades:
- [Release Notes](./releases/) - What's new
- [Release Notes](./releases/) - Upgrading between versions

### 💡 Examples
Learn by example:
- [Examples](./examples/) - Visual guides
- [Code Examples](./examples/) - Example implementations

---

## Directory Structure

```
Docs/
├── README.md                    # This file
├── getting-started/             # First-time user guides
├── concepts/                    # Fundamental concepts
├── guides/                      # How-to guides and tutorials
├── reference/                   # API and configuration reference
│   ├── governance/              # API governance policies
│   ├── stubs/                   # Stub documentation
│   ├── audits/                  # Code audits and analysis
│   └── ...
├── troubleshooting/             # Problem-solving guides
├── development/                 # Developer-focused docs
├── architecture/                # Deep architectural dives
├── releases/                    # Release notes and migrations
├── examples/                    # Code examples and samples
├── generated/                   # Auto-generated documentation
├── archive/                     # Historical and session reports
│   ├── sessions/                # Past session summaries
│   ├── tasks/                   # Task completion reports
│   ├── migrations/              # Migration histories
│   ├── reports/                 # Status reports
│   └── ...
└── ...
```

---

## Finding What You Need

### By User Type

| I am... | Start with... |
|---------|---------------|
| A new user | [Getting Started](./getting-started/quick-start.md) |
| A developer | [Project Structure](./development/project-structure.md) |
| Contributing code | [Contributing](./guides/contributing.md) or [Development Workflow](./development/) |
| Debugging issues | [Troubleshooting](./troubleshooting/) |
| Deploying to production | [Production Deployment](./guides/running-in-production.md) |
| Learning the system | [Concepts](./concepts/) → [Architecture](./architecture/) |

### By Task

| I want to... | See... |
|--------------|--------|
| Install Anigma | [Installation](./getting-started/mcp-installation.md) |
| Build from source | [Building Guide](./guides/building-analysis.md) |
| Run tests | [Testing Guide](./guides/testing.md) |
| Understand architecture | [Architecture Overview](./concepts/architecture.md) |
| Fix a compilation error | [Build Troubleshooting](./troubleshooting/compilation.md) |
| Contribute changes | [Contributing Guide](./guides/contributing.md) |
| View API documentation | [API Reference](./reference/api-governance.md) |
| Check release history | [Releases](./releases/changelog.md) |

---

## Documentation Status

This documentation is organized into 10 main categories with cross-references. See Navigation metadata for machine-readable routing information.

**Last Updated**: April 2026

For historical context and session notes, see [Archive](./archive/).

---

## Contributing to Documentation

Found an issue or want to improve docs? 

1. Check the relevant section
2. Submit an update following the code contribution process
3. Ensure all internal links are correct

---

## Quick Links (for Agents)

- **Agent Quick Start**: See [AGENTS.md](../AGENTS.md) in repository root
- **Launch Instructions**: See [HOW_TO_LAUNCH.md](../HOW_TO_LAUNCH.md)
- **File Location Reference**: See [FILE_LOCATIONS_REFERENCE.md](../FILE_LOCATIONS_REFERENCE.md)

