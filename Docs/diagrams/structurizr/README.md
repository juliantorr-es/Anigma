# Structurizr Architecture Models (Legacy)

## Status: **LEGACY / OPTIONAL**

**⚠️ Structurizr CLI is deprecated and no longer required for Anigma architecture modeling.**

This directory is reserved for **legacy Structurizr DSL files** that may exist from previous architecture modeling efforts. It is **not required** for current Anigma development.

## Current State

| Aspect | Status |
|--------|--------|
| **Structurizr CLI** | Deprecated/Archived |
| **LikeC4** | ✅ Primary architecture tool |
| **Requirement** | Optional (legacy only) |
| **existing files** | None (directory is placeholder) |

## Migration to LikeC4

Anigma has migrated from Structurizr CLI to [LikeC4](../../likec4/) as the primary architecture model-as-code tool.

### Why the Change?

| Factor | Structurizr CLI | LikeC4 |
|--------|----------------|--------|
| **Maintenance** | Archived/deprecated | Actively maintained |
| **Installation** | Separate download | npm package |
| **Format** | JSON/YAML/DSL | Text-to-diagram (PlantUML-like) |
| **Rendering** | Cloud/server required | Self-contained HTML |
| **Integration** | Separate workspace | Fits with Docs-as-Code |
| **Dependencies** | External | Uses Graphviz (already available) |

### Existing Structurizr Files

If any Structurizr DSL or JSON files exist in this directory:
- They are **legacy only** and **not actively maintained**
- They can be **converted to LikeC4** format on demand
- They are **not required** for any Anigma operations
- They serve as **historical reference** only

## LikeC4 Alternative

The **active architecture model** is now maintained in:

📁 **[`../../likec4/`](../../likec4/)**

| File | Purpose |
|------|---------|
| [`anigma.c4`](../../likec4/anigma.c4) | Complete Anigma architecture model |
| [`README.md`](../../likec4/README.md) | LikeC4 usage and documentation |

### Quick Conversion Guide

If you have existing Structurizr DSL files that need to be converted:

1. **Manual conversion** (recommended for small models):
   - LikeC4 uses PlantUML-like syntax
   - Structurizr DSL maps directly to LikeC4 elements
   - See [LikeC4 docs救护car](https://like-c4.com/) for syntax

2. **Automated assistance:**
   - Use LikeC4's import capabilities (if available)
   - Or manually recreate using the LikeC4 model as template

## Structure (If Populated)

If this directory contains files, they would follow this structure:

```
Docs/diagrams/structurizr/
├── README.md                    # This file
├── anigma-system.dsl           # Structurizr DSL (legacy)
├── anigma-system.json          # Structurizr JSON export (legacy)
└── workspace/                  # Structurizr workspace (legacy)
    └── ...
```

## Tool Status

| Tool | Status | Replacement |
|------|--------|-------------|
| Structurizr CLI | ❌ Deprecated | LikeC4 |
| Structurizr Cloud | ❌ Archived | Self-hosted LikeC4 HTML |
| Structurizr DSL | ⚠️ Legacy | LikeC4 text format |
| Java runtime (for Structurizr) | ❌ Not required | Node.js (for LikeC4) |

## Maintenance Policy

- **No new Structurizr files** should be added
- **Existing files** may remain as historical artifacts
- **No validation** is required for Structurizr files
- **No CI/CD integration** for Structurizr CLI
- **Migration assistance** available on request

## Verification

To confirm that Structurizr CLI is **not required**:

```bash
# LikeC4 is the primary tool
likec4 --version
# Expected: 1.21.1 or higher

# Structurizr CLI is not required
which structurizr-cli || echo "Structurizr CLI not installed (OK)"
# Expected: "Structurizr CLI not installed (OK)"

# LikeC4 model validates
likec4 build ../../likec4 -o /tmp/test
# Expected: Exit code 0
```

## See Also

- [LikeC4 Architecture Model](../../likec4/) - **Active replacement**
- [LikeC4 Documentation](https://like-c4.com/)
- [Structurizr Website](https://structurizr.com/) - Legacy reference only
- [Anigma Timeline - Architecture Decisions](../../timeline/decisions.yaml)
