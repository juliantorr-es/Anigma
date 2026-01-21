# Anigma Documentation

Welcome to the Anigma documentation. This guide helps you navigate the consolidated documentation structure.

---

## Quick Start

| Topic | Location |
|-------|----------|
| **Development Guide** | [DEVELOPMENT_GUIDE.md](./DEVELOPMENT_GUIDE.md) |
| **Claude Integration** | [guides/claude-integration/](./guides/claude-integration/) |
| **Contract System** | [guides/contract-enforcement.md](./guides/contract-enforcement.md) |
| **Roadmap** | [Roadmap.md](./Roadmap.md) |

---

## Project Foundation

### Core Documents
- [AnigmaConstitution.md](./AnigmaConstitution.md) - Core principles and philosophy
- [DEVELOPMENT_GUIDE.md](./DEVELOPMENT_GUIDE.md) - Getting started with development
- [Roadmap.md](./Roadmap.md) - Project roadmap and milestones
- [priority_matrix.md](./priority_matrix.md) - Design principles prioritization

### Performance & Quality
- [PerformanceBudgets.md](./PerformanceBudgets.md) - Latency and resource budgets
- [LLM-Guidelines.md](./LLM-Guidelines.md) - LLM usage and integration guidelines

---

## Guides

All consolidated guides are in the [guides/](./guides/) directory:

| Guide | Purpose |
|-------|---------|
| [Claude Integration](./guides/claude-integration/) | MCP server + Claude Desktop setup |
| [Contract Enforcement](./guides/contract-enforcement.md) | Design contracts + CI enforcement |
| [Cathedral](./guides/cathedral/) | Evidence system + court-safe auditing |
| [Harmonia](./guides/harmonia/) | AI coding assistant CLI |
| [Database](./guides/database/) | Database governance + optimization |
| [ML Worker](./guides/ml-worker/) | Inference architecture + model registry |
| [Capability System](./guides/capability-system/) | Module architecture |
| [Accessibility](./guides/accessibility/) | WCAG compliance + audits |
| [Installation](./guides/installation/) | Mac app + App Store |
| [Deployment](./guides/deployment/) | Apple + corporate deployment |

---

## Sprint Documentation

All sprint work is organized in [sprints/](./sprints/):

| Sprint | Status |
|--------|--------|
| [CLI Implementation](./sprints/2026-01-CLI-Implementation/) | ✅ Complete |
| [Cathedral Implementation](./sprints/2026-01-Cathedral-Implementation/) | ✅ Complete |
| [Harmonia Integration](./sprints/2026-01-Harmonia-Integration/) | ✅ Complete |
| [MCP Extension](./sprints/2026-01-MCP-Extension/) | ✅ Complete |
| [Model Registry](./sprints/2026-01-Model-Registry/) | ✅ Complete |
| [Contextum Implementation](./sprints/2026-01-Contextum-Implementation/) | ✅ Complete |
| [Contract Enforcement](./sprints/2026-01-Contract-Enforcement/) | ✅ Complete |
| [Binary Integration](./sprints/2026-01-Binary-Integration/) | ✅ Complete |

---

## Architecture & Governance

### Architecture
- [architecture/](./architecture/) - Detailed module architecture
- [ADR/](./ADR/) - Architecture Decision Records
- [architecture-guides/](./architecture-guides/) - Visual architecture guides

### Governance
- [governance/](./governance/) - Governance policies and contracts

---

## Reference

### Status & Progress
- [status-reports/](./status-reports/) - Build and implementation status
- [session-notes/](./session-notes/) - Session handoff notes

### Tools
- [tools/](./tools/) - Tool documentation

### Extensions
- [GEMINI_EXTENSION.md](./GEMINI_EXTENSION.md) - Gemini extension setup
- [guides/claude-integration/](./guides/claude-integration/) - Claude extension

---

## Archive

Historical and legacy documentation is preserved in [archive/](./archive/):

- `claude-legacy/` - Original Claude documentation (consolidated)
- `contract-legacy/` - Original contract docs (consolidated)
- `phases-legacy/` - Phase completion reports
- `implementation-notes/` - Implementation status notes
- `misc/` - Miscellaneous historical docs

---

## Directory Structure

```
Docs/
├── guides/                 # PRIMARY - Consolidated topic guides
│   ├── claude-integration/
│   ├── cathedral/
│   ├── harmonia/
│   ├── database/
│   ├── ml-worker/
│   ├── capability-system/
│   ├── accessibility/
│   ├── installation/
│   └── deployment/
├── sprints/                # Sprint documentation
├── architecture/           # Detailed module docs
├── ADR/                    # Architecture decisions
├── governance/             # Policies and contracts
├── status-reports/         # Build/status reports
├── session-notes/          # Session handoffs
├── tools/                  # Tool documentation
├── archive/                # Historical docs
└── *.md                    # Core reference docs
```

---

*Last Updated: January 10, 2026*
