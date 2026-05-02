# LikeC4 Architecture Model

## Overview

This directory contains the **primary architecture model-as-code** for Anigma using [LikeC4](https://like-c4.com/), replacing the deprecated Structurizr CLI dependency.

LikeC4 is a **text-to-diagram** tool that uses PlantUML-like syntax specifically designed for C4 model architecture diagrams. It provides a stable, modern alternative to Structurizr CLI while maintaining compatibility with the Anigma project's documentation-as-code approach.

## Current Status

| Aspect | Status |
|--------|--------|
| **Primary Architecture Tool** | LikeC4 (replacing Structurizr CLI) |
| **Structurizr CLI** | Legacy/Optional - no longer required |
| **LikeC4 Version** | 1.21.1 |
| **Model File** | [`anigma.c4`](./anigma.c4) |
| **Validation** | Build passes via `likec4 build` |

## Model Structure

The `anigma.c4` file contains the following views:

### 1. **System Context Diagram** (`Anigma System Context`)
- **External Actors:** End User (Operator)
- **Primary Systems:**
  - Anigma macOS Application (main GUI)
  - anigmad Daemon (background service)
  - Governance Control Plane (validation scripts)
  - MediaCore (media processing substrate)
  - SubprocessPooling (worker pool management)
- **External Dependencies:**
  - Postgres/SQLite Database
  - External LLM Providers (Gemini, Claude)

### 2. **Anigma macOS Application - Container View**
- AnigmaCLI (command-line interface)
- UI Layer (SwiftUI/Swift user interface)
- DataUI (data binding and UI state)
- ContractsCore (type-safe interfaces)
- ExecutionCore (task orchestration)
- HarmoniaModule (LLM integration, memory, RAG)
- AnigmaDaemonControl (daemon communication)

### 3. **anigmad Daemon - Container View**
- AnigmaDaemonCore (core daemon services)
- SubprocessPooling (generic warm pool management)
- Worker Pools:
  - MLWorkerPool (machine learning with GPU)
  - MCPWorkerPool (Model Context Protocol)
  - BenchmarkWorkerPool (performance testing)

### 4. **MediaCore - Container View**
- MediaCore (core media operations)
- CPDFium (PDF rendering engine wrapper)
- VectorCapsule (vector graphics processing)
- ImageDecodeCapsule (image decoding)
- DocumentRenderKit (document rendering pipeline)
- MaterializationGate (zero-copy enforcement)

### 5. **Governance Control Plane - Component View**
- validate_tiers.py (tier boundary validation)
- validate_no_cycles.py (dependency cycle detection)
- validate_exported_imports.py (exported import checking)
- validate_yaml_manifests.py (YAML manifest validation)
- validate_verification_profiles.py (verification profile validation)
- validate_td_folder_system.py (TD folder system validation)
- validate_td_docs_sync.py (TD/Docs synchronization validation)

### 6. **SubprocessPooling - Component View**
- SubprocessManager (generic pool lifecycle management)
- MLWorker (machine learning subprocess worker)
- MCPWorker (Model Context Protocol worker)
- BenchmarkWorker (performance testing worker)
- PoolMetrics (pool observability)
- PoolConfiguration (pool configuration)
- WorkerState (worker lifecycle tracking)
- UMABufferPool (unified memory architecture for zero-copy)
- ModelCache (GPU model caching)

### 7. **Evidence Store - Data Flow**
- Docs/proofs/ (proof artifacts)
- Docs/td/ (technical debt tracking)
- Docs/schemas/ (JSON schema definitions)
- Docs/diagrams/ (architecture diagrams as code)

## Why LikeC4?

| Criteria | LikeC4 | Structurizr CLI |
|----------|--------|-----------------|
| **Maintenance Status** | Actively maintained | Deprecated/Archived |
| **Integration** | Text-to-diagram, fits with Docs-as-Code | Separate database/workspace |
| **Tool availability** | npm/shell installation | Requires separate download |
| **Format** | PlantUML-like text files | JSON/YAML/DSL files |
| **Rendering** | Self-contained HTML build | Requires Structurizr cloud/server |
| **Open Source** | Yes (MIT) | Yes (Apache 2.0) |

## Usage

### Validate Model

```bash
# Build the model to validate syntax
likec4 build Docs/diagrams/likec4 -o /tmp/anigma-likec4

# Check exit code
echo $?  # Should be 0 if valid
```

### Local Preview

```bash
# Start local dev server
likec4 start Docs/diagrams/likec4

# Or preview production build
likec4 preview Docs/diagrams/likec4
```

### Export Diagrams

```bash
# Export to PNG
likec4 export png Docs/diagrams/likec4 -o /tmp/diagrams

# Export to SVG
likec4 export svg Docs/diagrams/likec4 -o /tmp/diagrams

# Export to JSON
likec4 export json Docs/diagrams/likec4 -o /tmp/anigma-model.json
```

## File Format

LikeC4 uses a **PlantUML-like syntax** with C4 model extensions:

```c4plantuml
# LikeC4 Model
$shapeDescriptions = {
  person: "User or external actor"
  system: "Autonomous software system"
}

person(user, "User", "Description")
system(app, "Application", "Tech", "Description")

Rel(user, app, "Uses", "Protocol")
```

## Migration from Structurizr

### Before (Structurizr)
```
- Required Structurizr CLI installation
- Separate workspace/DSL files
- JSON export/import
- External rendering dependencies
```

### After (LikeC4)
```
- Single .c4 text file
- Self-contained HTML build
- Integrates with existing plantUML tooling
- Uses Graphviz (dot) for layout
```

### Structural Mapping

| Structurizr Concept | LikeC4 Equivalent |
|--------------------|------------------|
| Person | `person(id, name, desc, tech)` |
| SoftwareSystem | `system(id, name, desc, tech)` |
| Container | `container(id, name, desc, tech)` |
| Component | `component(id, name, desc, tech)` |
| Relationship | `Rel(from, to, desc, tech)` |
| Container boundary | `container(parent) { ... }` |

## Tool Requirements

| Tool | Purpose | Requirement | Status |
|------|---------|-------------|--------|
| **likec4** | Model validation and rendering | Required | ✅ Available (v1.21.1) |
| **dot** (graphviz) | Diagram layout | Optional | ✅ Available (v2.54.1) |
| **Node.js** | Runtime for LikeC4 CLI | Required | Included with likec4 |

## LikeC4 Installation

```bash
# Global npm install
npm install -g @likec4/likec4

# Or use npx without installation
npx @likec4/likec4 build Docs/diagrams/likec4

# Verify installation
likec4 --version
```

## Verification

```bash
# 1. LikeC4 version
likec4 --version
# Expected: 1.21.1 or higher

# 2. Validate model builds
likec4 build Docs/diagrams/likec4 -o /tmp/test-build
echo "Exit code: $?"
# Expected: 0 (success)

# 3. Check Graphviz (dot)
dot -V
# Expected: graphviz version X.X.X

# 4. Check Mermaid (mmdc)
mmdc --version
# Expected: version number
```

## Integration with Existing Tools

LikeC4 complements Anigma's existing diagram tooling:

| Tool | Purpose | Status |
|------|---------|--------|
| **LikeC4** | Architecture context/container/component diagrams | Primary |
| **Mermaid** | Sequence diagrams, flowcharts, Gantt | Supported |
| **Graphviz (dot)** | Used by LikeC4 for layout | Supported |
| **Structurizr DSL** | Legacy architecture models | Optional (not required) |

## See Also

- [LikeC4 Documentation](https://like-c4.com/)
- [LikeC4 GitHub](https://github.com/likec4/likec4)
- [C4 Model](https://c4model.com/)
- [Structurizr](https://structurizr.com/) (legacy reference)
- [Anigma Architecture Decision Timeline](../../timeline/decisions.yaml) (AD-002: TD Context GC)

## Maintenance

- **Model updates:** Edit `anigma.c4` directly
- **Validation:** Run `likec4 build` before committing changes
- **Rendering:** Generate static HTML via `likec4 build -o output/dir`
- **New views:** Add new sections with `''' == Title ==` syntax
- **Styling:** Use `$shapeDescriptions` for custom element descriptions
