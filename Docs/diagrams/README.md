# Diagrams Directory

**Doc ID:** DIAGRAMS_README  
**Status:** ACTIVE  
**Owner:** Architecture Team  
**Last Updated:** 2026-05-02  

---

## Overview

This directory contains architecture and system diagrams for Anigma, organized by tool/diagram type.

## Directory Structure

```
 Docs/diagrams/
├── README.md                          # This file
├── likec4/                            # LikeC4 C4 model diagrams (PRIMARY)
│   ├── anigma.c4                       # Main LikeC4 architecture model
│   └── README.md                       # LikeC4 usage and migration guide
├── structurizr/                       # Structurizr CLI diagrams (LEGACY)
│   ├── anigma-workspace.dsl            # Structurizr workspace definition
│   └── README.md                       # Structurizr legacy documentation
├── mermaid/                           # Mermaid flow diagrams
│   ├── git-worktree-flow.mmd           # Git worktree management
│   ├── materialization-gate-flow.mmd  # Materialization gate sequence
│   ├── task-lifecycle.mmd             # TD task lifecycle
│   └── testing-lanes.mmd               # Testing lane flows
└── graphviz/                          # Graphviz dependency graphs
    ├── package-target-graph-example.dot  # Example package dependency graph
    └── tier-violations-example.dot       # Example tier violation graph
```

## Diagram Tools

### LikeC4 (PRIMARY)

**Tool:** `likec4` v1.21.1+  
**Purpose:** C4 model architecture diagrams (Context, Containers, Components, Code)  
**Status:** PRIMARY - Actively maintained and required for architecture validation  
**File:** `Docs/diagrams/likec4/anigma.c4`

**Usage:**
```bash
# Validate LikeC4 model
likec4 build Docs/diagrams/likec4 -o /tmp/anigma-diagrams

# Generate diagrams
likec4 build Docs/diagrams/likec4 -o output/ --format png
```

### Structurizr (LEGACY)

**Tool:** `structurizr` CLI  
**Purpose:** C4 model diagrams  
**Status:** LEGACY - Not required, not deleted (historical)  
**File:** `Docs/diagrams/structurizr/anigma-workspace.dsl`

**Note:** LikeC4 has replaced Structurizr as the PRIMARY architecture modeling tool. Structurizr files remain for historical reference but are not required for validation.

### Mermaid

**Tool:** `mmdc` (Mermaid CLI) v11.12.0+  
**Purpose:** Flow charts, sequence diagrams, and process flows  
**Status:** OPTIONAL - Used for logic flow documentation  
**Files:** `Docs/diagrams/mermaid/*.mmd`

**Usage:**
```bash
# Render a Mermaid diagram
mmdc -i Docs/diagrams/mermaid/media-materialization-flow.mmd -o output.png

# Batch render all Mermaid diagrams
mmdc -i Docs/diagrams/mermaid/*.mmd -o output/
```

### Graphviz

**Tool:** `dot` (Graphviz) v14.1.5+  
**Purpose:** Dependency graphs and network diagrams  
**Status:** OPTIONAL - Used for dependency visualization  
**Files:** `Docs/diagrams/graphviz/*.dot`

**Usage:**
```bash
# Render a DOT file
dot -Tpng Docs/diagrams/graphviz/package-target-graph-example.dot -o output.png

# Generate SVG
dot -Tsvg input.dot -o output.svg
```

## Validation

### Architecture Diagrams Profile

The `architecture-diagrams` verification profile validates diagrams:

```bash
# Run architecture diagram validation
python3 Scripts/validate_verification_profiles.py --profile architecture-diagrams
```

This profile checks:
- LikeC4 model parsing (`likec4 build`)
- Mermaid diagram parsing (if mmdc installed)
- Graphviz files syntax (if dot installed)

### LikeC4 Specific

```bash
# Build and validate LikeC4 model
likec4 build Docs/diagrams/likec4 -o /tmp/likec4-validate
# Exit code 0 = valid
```

### Mermaid Specific

```bash
# Validate all Mermaid files
for f in Docs/diagrams/mermaid/*.mmd; do
  mmdc -i "$f" -o /tmp/test.png 2>&1 | grep -q "Generating" && echo "✅ $f"
done
```

---

## Related Documentation

- [Architecture Maps](../architecture/maps/README.md) - Module/file role indexes
- [LikeC4 README](likec4/README.md) - LikeC4 tool documentation
- [VERIFICATION_PROFILES.md](../governance/VERIFICATION_PROFILES.md) - Verification profile definitions
- [ANIGMA_ARCHITECTURE_DIAGRAM.md](../ANIGMA_ARCHITECTURE_DIAGRAM.md) - Historical architecture documentation

---

## Maintenance

### Adding a New Diagram

1. Choose the appropriate tool (LikeC4 for architecture, Mermaid for flows)
2. Place in the corresponding subdirectory
3. Reference from relevant documentation
4. Ensure it validates (parse test via tool CLI)

### Deprecating a Diagram

1. Move to `Docs/archive/diagrams/`
2. Add a note explaining the deprecation
3. Update references

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-05-02 | Initial diagrams README with tool structure |
