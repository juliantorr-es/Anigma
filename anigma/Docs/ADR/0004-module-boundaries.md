# ADR-0004: Module Boundaries

> **Status:** Accepted  
> **Date:** 2025-12-06  
> **Supersedes:** None  
> **Superseded by:** None

---

## Context

The Anigma ecosystem serves multiple domains:
- **Harmonia**: Developer intelligence, AI coding assistance
- **Diaplasion**: Document transformation, alt-media, DSPS accessibility
- **Accessum**: Client-facing accessibility tools
- **Outlineum**: Artwork outlines, zines, print production

Each domain has unique components, systems, and workflows, but they share infrastructure. We need clear boundaries to prevent:
- Infrastructure duplication
- Circular dependencies
- Domain logic leaking into core
- UI coupling to internal details

---

## Decision

**Three-layer architecture with strict boundaries:**

```
┌─────────────────────────────────────────────┐
│              App Shells                      │
│  (Daemons, CLIs, Ergasterion, Consoles)     │
├─────────────────────────────────────────────┤
│           Domain Modules                     │
│  Harmonia │ Diaplasion │ Accessum │ Outlineum │
├─────────────────────────────────────────────┤
│              AnigmaCore                      │
│    (ECS, Jobs, Workflows, Utilities)        │
└─────────────────────────────────────────────┘
```

### Layer Rules

| Layer | Contains | Depends On |
|-------|----------|------------|
| **AnigmaCore** | ECS, Jobs, Workflows, shared components, logging, errors | Foundation, system frameworks |
| **Domain Modules** | Domain components, systems, workflows | AnigmaCore only |
| **App Shells** | Entry points, UI, config loading, daemon loops | Core + one or more modules |

### AnigmaCore Contents

```
AnigmaCore/
├── ECS/
│   ├── EntityId.swift
│   ├── Component.swift
│   ├── System.swift
│   └── World.swift
├── Jobs/
│   ├── Job.swift
│   ├── Workflow.swift
│   └── Scheduler.swift
├── Components/
│   └── SharedComponents.swift  # FileComponent, QAComponent, etc.
└── Utilities/
    ├── Logging.swift
    ├── Configuration.swift
    └── Errors.swift
```

### Domain Module Contents

```
{Module}/
├── Components/
│   └── {Domain}Component.swift
├── Systems/
│   └── {Domain}System.swift
├── Pipelines/
│   └── {Domain}Workflow.swift
└── {Module}.swift  # Registration entry point
```

### What Belongs Where

| Type | Location | Example |
|------|----------|---------|
| EntityId, World, System protocol | AnigmaCore | `EntityId.swift` |
| Job, Scheduler, Workflow protocol | AnigmaCore | `Job.swift` |
| FileComponent, QAComponent | AnigmaCore | Generic, domain-agnostic |
| DocumentSourceComponent, OCRResultComponent | DiaplasionModule | Alt-media transformation |
| CodeComponent, RefactorComponent | HarmoniaModule | Dev-specific |
| ImageComponent, OutlineComponent | OutlineumModule | Art-specific |
| OCRExtractionSystem, EPUBExportSystem | DiaplasionModule | Alt-media transformation |
| IngestSystem, OutlineSystem | OutlineumModule | Art-specific |

---

## Rationale

### Why Three Layers?

1. **Core stability**: AnigmaCore changes rarely, modules more often
2. **Independent evolution**: Modules can add features without core changes
3. **Clear testing**: Core tests, module tests, integration tests
4. **Deployment flexibility**: Different apps use different module subsets

### Why Strict Dependencies?

Prevents:
- Circular dependencies (A → B → A)
- Hidden coupling (module importing another module's internals)
- Infrastructure duplication (modules reimplementing core)

### Why Domain Components in Modules?

- Domain experts own their components
- No "god component" with every field
- Modules can evolve independently
- Core stays generic

### Alternatives Considered

1. **Single package**: Rejected (too coupled, slow builds)
2. **Microservices**: Rejected (deployment complexity)
3. **Plugin architecture**: Deferred (may add later)

---

## Consequences

### Positive

- Clear ownership and responsibility
- Modules can be tested in isolation
- Core changes are rare and well-tested
- New modules can be added without touching others

### Negative

- Some ceremony to add components to correct location
- Cross-module features need careful design

### Neutral

- Module registration required at app startup

---

## Migration

### New Components

1. Determine domain: Is this Harmonia? Diaplasion? Outlineum?
2. Create in `{Module}/Components/`
3. Import AnigmaCore, conform to Component

### New Systems

1. Determine domain
2. Create in `{Module}/Systems/`
3. Import AnigmaCore, conform to System
4. Register in module's `register()` function

### Shared Logic

If logic is truly domain-agnostic:
1. Propose addition to AnigmaCore
2. Create ADR if significant
3. Add to appropriate AnigmaCore subdirectory

---

## References

- Constitution: `Docs/AnigmaConstitution.md` Section 2.2
- Implementation rules: `Docs/ImplementationRules.md`
- Package structure: `Package.swift`
