# Architecture Maps

**Doc ID:** ARCHITECTURE_MAPS  
**Status:** ACTIVE  
**Owner:** Architecture Team  
**Last Updated:** 2026-05-02  
**Related:** 
- Docs/governance/VERIFICATION_PROFILES.md
- Docs/governance/TD_CONTEXT_GARBAGE_COLLECTION.md
- Docs/diagrams/likec4/README.md
- Docs/ANIGMA_ARCHITECTURE_DIAGRAM.md

---

## Overview

Architecture maps provide **machine-readable and human-readable** explanations of what major Anigma modules/files do, what logic flows they participate in, and how they align with canonical Anigma doctrine.

### Purpose

1. **Context Loading for Agents**: TD tasks reference these maps so agents load the right context
2. **Architecture Discovery**: New contributors understand the topology without reading all code
3. **Governance Alignment**: Maps link to canonical doctrine and validation rules
4. **Maintainability**: Changes to modules can be traced through their role definitions

### Relationship to Other Artifacts

| Artifact | Purpose | Scope |
|----------|---------|-------|
| **LikeC4 (Docs/diagrams/likec4/)** | Architecture topology (containers, components) | System/Container/Component level |
| **Mermaid (this directory)** | Logic flows and sequences | Process/flow level |
| **Module-Role Index** | What each module does, its tier, dependencies | Module level |
| **File-Role Index** | What each significant file does | File level |

---

## Directory Structure

```
Docs/architecture/maps/
├── README.md                          # This file
├── module-role-index.yaml             # Module-level role definitions
├── file-role-index.yaml               # File-level role definitions
└── logic-flows/
    ├── README.md                      # Logic flow index
    ├── media-materialization-flow.mmd  # MediaCore materialization
    ├── td-bootstrap-flow.mmd          # TD system bootstrap
    ├── public-history-excision-flow.mmd # History excision process
    └── subprocess-pooling-planned-flow.mmd # Subprocess pooling
```

---

## Maps

### Module-Role Index

The [module-role-index.yaml](./module-role-index.yaml) defines the purpose, responsibility, tier, and dependency constraints for each major Anigma module.

**See:** [Module-Role Index](./module-role-index.yaml)

### File-Role Index

The [file-role-index.yaml](./file-role-index.yaml) catalogs significant files with their module, tier, key symbols, canonical concepts, and doctrine alignment.

**See:** [File-Role Index](./file-role-index.yaml)

### Logic Flows

Mermaid diagrams in [logic-flows/](./logic-flows/) illustrate the major process flows:

| Diagram | Flow | Purpose |
|---------|------|---------|
| [media-materialization-flow.mmd](logic-flows/media-materialization-flow.mmd) | MediaCore surface materialization | Zero-copy enforcement path |
| [td-bootstrap-flow.mmd](logic-flows/td-bootstrap-flow.mmd) | TD descriptor generation | Docs → TD synchronization |
| [public-history-excision-flow.mmd](logic-flows/public-history-excision-flow.mmd) | Git history filtering | Public history preparation |
| [subprocess-pooling-planned-flow.mmd](logic-flows/subprocess-pooling-planned-flow.mmd) | anigmad worker pooling | Warm pool lifecycle |

---

## Usage for TD Tasks

### Referencing Maps in Task Descriptors

Tasks can reference architecture maps through their `related_docs` field:

```yaml
# In Docs/td/ready/<task-id>/task.yaml
related_docs:
  - Docs/architecture/maps/module-role-index.yaml
  - Docs/architecture/maps/file-role-index.yaml
  - Docs/architecture/maps/logic-flows/media-materialization-flow.mmd
  
related_diagrams:
  - Docs/diagrams/likec4/anigma.c4
```

### Using Maps for Context Loading

Agents should:
1. **On task claim**: Load the task descriptor and follow `related_docs` to maps
2. **On module changes**: Consult module-role-index for dependency constraints
3. **On file changes**: Consult file-role-index for doctrine alignment
4. **On flow questions**: Consult Mermaid diagrams for sequence understanding

---

## Doctrine Alignment

All entries in the indexes reference canonical Anigma doctrine:

| Doctrine | Location |
|----------|----------|
| Tier System | Docs/governance/TIER_GOVERNANCE.md (referenced) |
| Dependency Rules | Docs/governance/DEPENDENCY_GOVERNANCE.md (referenced) |
| TD System | Docs/governance/TD_SOURCE_OF_TRUTH_DOCTRINE.md |
| GC Policy | Docs/governance/TD_CONTEXT_GARBAGE_COLLECTION.md |
| Verification Profiles | Docs/governance/VERIFICATION_PROFILES.md |

---

## Maintenance

### Adding a New Module

1. Add entry to `module-role-index.yaml`
2. Add key files to `file-role-index.yaml`
3. Create/update LikeC4 model in `Docs/diagrams/likec4/anigma.c4`
4. Add any relevant logic flows to `logic-flows/`

### Adding a New Logic Flow

1. Create new `.mmd` file in `logic-flows/`
2. Follow the template (start/end, authorities/gates, proof points, failure paths)
3. Add entry to `logic-flows/README.md`
4. Reference from relevant task descriptors

### Validation

Run the following to validate all maps:

```bash
# JSON schemas
python3 -m json.tool Docs/schemas/file-role-index.schema.json
python3 -m json.tool Docs/schemas/module-role-index.schema.json

# YAML indexes
python3 -c "import yaml; yaml.safe_load(open('Docs/architecture/maps/module-role-index.yaml'))"
python3 -c "import yaml; yaml.safe_load(open('Docs/architecture/maps/file-role-index.yaml'))"

# Mermaid (if mmdc installed)
mmdc -i Docs/architecture/maps/logic-flows/*.mmd -o /tmp/mermaid-test/

# LikeC4 (if installed)
likec4 build Docs/diagrams/likec4 -o /tmp/likec4-test
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-05-02 | Initial architecture maps: module-role-index, file-role-index, 4 logic flows |
