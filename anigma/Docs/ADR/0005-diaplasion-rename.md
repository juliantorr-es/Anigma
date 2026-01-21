# ADR-0005: Rename AltMediaModule to DiaplasionModule

> **Status:** Accepted  
> **Date:** 2025-12-06  
> **Supersedes:** None  
> **Superseded by:** None

---

## Context

The original module name "AltMediaModule" was descriptive but:
- Did not fit the Anigma naming convention (Greek-inspired names)
- Was too generic ("alt-media" could mean many things)
- Did not convey the transformative nature of the module's purpose

The module is responsible for document transformation: taking source documents and reshaping them into accessible formats (OCR, EPUB, braille, audio-ready, etc.).

---

## Decision

Rename "AltMediaModule" to **"DiaplasionModule"**.

**Diaplasion** (Διάπλασις) is Greek for "reshaping" or "remolding." This captures the module's core purpose: transforming documents into new, accessible forms.

### Naming Convention

| Element | Value |
|---------|-------|
| Greek root | διάπλασις (diáplasis) |
| Meaning | Reshaping, remolding, transformation |
| Module name | `DiaplasionModule` |
| Ecosystem name | Diaplasion |
| Job type prefix | `diaplasion.*` |

### Affected Items

**Renamed:**
- `Sources/AltMediaModule/` → `Sources/DiaplasionModule/`
- `AltMediaModule` target → `DiaplasionModule` target
- `AltMediaModuleVersion` → `DiaplasionModuleVersion`
- `AltMediaModule.register()` → `DiaplasionModule.register()`

**New types defined:**
- `DiaplasionJobType` (with job type constants)
- `DocumentSourceComponent`, `TransformRequestComponent`
- `OCRResultComponent`, `ChunkedTextComponent`, `AccessibleOutputComponent`
- `DocumentIngestSystem`, `OCRExtractionSystem`, `TextChunkingSystem`
- `EPUBExportSystem`, `BrailleExportSystem`, `AudioPrepSystem`
- `DocumentToEPUBWorkflow`, `DocumentToBrailleWorkflow`, etc.

---

## Rationale

### Why Greek?

Anigma module names follow a Greek-inspired naming convention:
- **Anigma** (ἄνοιγμα) – Opening
- **Harmonia** (ἁρμονία) – Harmony, fitting together
- **Outlineum** – Latinized outline (hybrid, but fits the pattern)
- **Accessum** – Latinized access

"Diaplasion" fits this pattern and is distinctive enough to be memorable.

### Why "Reshaping"?

The module's purpose is transformation:
- PDF → OCR → Text → EPUB
- Image → OCR → Braille
- Document → Chunks → Audio-ready

"Diaplasion" (reshaping) captures this better than "alt-media" which focuses on the output rather than the process.

### Alternatives Considered

| Name | Reason Rejected |
|------|-----------------|
| AltMediaModule | Too generic, doesn't fit naming convention |
| MetamorphosisModule | Too long, overused term |
| TransformModule | Too generic |
| AllagmaModule | Less recognizable than Diaplasion |

---

## Consequences

### Positive

- Consistent naming convention across modules
- Name conveys purpose (transformation)
- Memorable and distinctive

### Negative

- Breaking change for any code importing `AltMediaModule`
- Documentation updates required

### Migration

Since the module was previously a stub with no external consumers, migration is trivial:
1. Rename directory and files
2. Update `Package.swift`
3. Update governance docs (Constitution, Roadmap, ADRs)
4. Update any imports (none external yet)

---

## References

- Constitution: `Docs/AnigmaConstitution.md` (updated)
- Roadmap: `Docs/Roadmap.md` Phase 2 (updated)
- Module boundaries: `Docs/ADR/0004-module-boundaries.md` (updated)
