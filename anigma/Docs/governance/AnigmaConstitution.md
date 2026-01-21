# Anigma Constitution

> Last updated: 2025-12-06

This document defines the fundamental principles governing the Anigma platform. Changes to this Constitution require an ADR.

---

## 1. What Anigma Is

**Anigma** is a Swift-based, ECS-driven, job/workflow platform for building institutional-grade automation systems.

- **AnigmaCore** is the single spine: ECS primitives, job model, workflow engine, shared components.
- **Domain Modules** are attached ecosystems that build on AnigmaCore:
  - **HarmoniaModule** – Dev-intelligence and AI-assisted coding workflows
  - **DiaplasionModule** – Alt-media transformation engine (OCR, EPUB, braille, audio)
  - **AccessumModule** – Client-facing accessibility shells and integration
  - **OutlineumModule** – Artwork outlines, zines, and print production

---

## 2. Core Architecture Principles

### 2.1 Single ECS and Job Model

AnigmaCore is the **only** source for:
- ECS primitives: `EntityId`, `Component`, `System`, `World`
- Job model: `Job`, `JobStatus`, `Scheduler`
- Workflow engine: `Workflow`, `WorkflowRegistry`, `WorkflowRunner`

**No module may define its own ECS framework.** Modules define only:
- Domain-specific `Component` types (conforming to `AnigmaCore.Component`)
- Domain-specific `System` implementations (conforming to `AnigmaCore.System`)
- Domain-specific `Workflow` definitions (conforming to `AnigmaCore.Workflow`)

### 2.2 Clean Boundaries

| Layer | Contains | Does NOT Contain |
|-------|----------|------------------|
| **AnigmaCore** | ECS, Jobs, Workflows, shared components (`FileComponent`, `QAComponent`), logging, errors | Domain logic, UI, app entry points |
| **Domain Modules** | Domain components, systems, workflows | Own ECS, own job scheduler, UI code |
| **App Shells** | Entry points, UI, daemon loops, CLI parsing | ECS internals, direct component storage |

### 2.3 Actor-Based Concurrency

- `World` is an actor for thread-safe entity/component management
- `Scheduler` is an actor for job queue management
- Systems are stateless and async-safe
- No shared mutable state outside actors

---

## 3. Language and Runtime Constraints

### 3.1 Swift Only (Core)

The Anigma repo contains **only Swift code** for all runtime logic.

Permitted:
- Swift (primary)
- System frameworks (Foundation, CoreImage, CoreGraphics, etc.)
- Permissively-licensed C/C++ libraries where necessary
- MLX/MLXNN for on-device ML

### 3.2 No Python, No Node at Runtime

The following are **permanently prohibited** in the Anigma repo:

| Prohibited | Reason |
|------------|--------|
| Python source files | Runtime dependency, deployment complexity |
| Python runtime dependencies | Breaks institutional deployment |
| Node.js runtime requirements | Same as above |
| AGPL/GPL-licensed code | License incompatibility for institutional use |

### 3.3 JavaScript Exception

JS/TS is permitted **only** for:
1. Build-time-only projects producing static assets (HTML/JS/CSS)
2. Prebuilt static assets committed as resources

Examples:
- Monaco editor bundle for Ergasterion (built, then bundled)
- Admin dashboard (React → static build → served by daemon)

**Node must never be required on deployed machines.**

### 3.4 License Allowlist

Only use dependencies with these licenses:
- MIT
- Apache 2.0
- BSD (2-clause, 3-clause)
- ISC
- Unlicense / CC0
- Zlib

---

## 4. Lab vs Production

### 4.1 Lab Repositories

External repositories are **lab/R&D** artifacts:
- `/Users/user/Developer/GitHub/Harmonia`
- `/Users/user/Developer/GitHub/Harmonia_DSPS_AltMediaEngine`
- `/Users/user/Developer/GitHub/Apertum_Accesum`
- `/Users/user/Developer/GitHub/Outlineum`

These may contain Python, experimental code, AGPL tools, etc.

### 4.2 Using Lab Code

The rule is: **"Interpret and re-design," not "copy and adapt."**

You may:
- Study structure and behavior
- Learn from algorithms and patterns
- Extract requirements and test cases

You must:
- Re-implement in fresh Swift
- Fit the AnigmaCore model
- Remove Python/AGPL dependencies

---

## 5. Governance

### 5.1 Architecture Decision Records (ADRs)

Major decisions are recorded in `Docs/ADR/`. An ADR is required for:
- Changes to ECS or Job model semantics
- New module creation
- Dependency additions
- Changes to this Constitution

### 5.2 Single Canonical Roadmap

`Docs/Roadmap.md` is the single source of truth for development plans.
- Legacy roadmaps are archived in `Docs/legacy/`
- Sprint-level details live in issue trackers, not the roadmap

### 5.3 Versioning and Compatibility

- AnigmaCore follows semantic versioning
- Breaking changes require deprecation period + migration guide
- Modules declare minimum AnigmaCore version dependency

---

## 6. Amendment Process

To change this Constitution:
1. Create an ADR proposing the change with rationale
2. Mark ADR as "proposed"
3. After review, mark as "accepted" and update this document
4. Reference the ADR in the change

---

## 7. Visualization Layer

### 7.1 Atlasum and Anigma Atlas

**Atlasum** is the canonical visualization engine for understanding Anigma's structure:

- **Anigma Atlas** (`Docs/Atlas/anigma-atlas.html`) is an interactive mind map of the platform
- It is a **derived view**, not a source of truth—documentation remains authoritative
- It must reflect the Constitution, Roadmap, and ADRs accurately
- Built at development time using JS/TS tooling; output is static HTML

See [ADR-0006: Atlasum Visual Atlas Engine](/ADR/0006-atlasum-visual-atlas-engine) for design decisions.

### 7.2 Atlas Maintenance

When adding modules, major subsystems, or documentation categories:
1. Update `Docs/Atlas/anigma-atlas.md` (the source)
2. Regenerate: `./Scripts/build_atlas.sh`
3. Verify the output opens correctly in a browser

---

## References

- `Docs/Roadmap.md` – Development plan
- `Docs/ADR/` – Architecture decisions
- `Docs/ImplementationRules.md` – Practical do/don't rules
- `Docs/LLM-Guidelines.md` – Instructions for AI assistants
- `Docs/Atlas/anigma-atlas.html` – Interactive platform map
