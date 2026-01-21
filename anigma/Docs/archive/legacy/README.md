# Legacy Documentation Archive

> Created: 2025-12-06  
> Purpose: Historical reference for archived plans and designs from legacy repos

This directory contains documentation from the original project repositories that has been superseded by the canonical Anigma documentation.

## Archived Documents

### From Harmonia
- `harmonia-roadmap-to-production.md` - Original production roadmap
- `harmonia-roadmaps-tier-summary.md` - Summary of tier-based development phases

### From Apertum Accesum
- `accessum-omega-release-roadmap.md` - Original Omega release roadmap
- `accessum-ecs-migration-plan.md` - ECS migration notes

### From Outlineum
- `outlineum-implementation.md` - Original Python implementation notes

### From Harmonia_DSPS_AltMediaEngine
- `altmedia-technical-debt.md` - Known technical debt items

## Status

**These documents are ARCHIVED and no longer authoritative.**

For current information, see:
- `Docs/AnigmaConstitution.md` - Fundamental principles
- `Docs/Roadmap.md` - Current development plan
- `Docs/ADR/` - Architecture decisions
- `Docs/ImplementationRules.md` - Practical rules

## Key Insights Extracted

### From Harmonia Roadmaps

**Kept (moved to Roadmap.md or ADRs):**
- MLX integration strategy → Phase 5 roadmap item
- Actor-based concurrency model → ADR-0001
- Local-first architecture priority → Constitution principle

**Not Kept (scope changed):**
- Multi-tenant server mode (deferred)
- Zed extension (superseded by Ergasterion)
- Federation transport (not in scope for v1)

### From Apertum Accesum

**Kept:**
- UUID-based EntityId pattern → ADR-0001
- Document/OCR workflows → AltMediaModule scope
- Accessibility-first design → Constitution principle

**Not Kept:**
- Complex role hierarchy (simplified for v1)
- Federated node architecture (deferred)

### From Outlineum

**Kept:**
- Image → outline → QA pipeline → OutlineumModule (Swift port complete)
- Kids/Adult outline variants → Component design
- Zine workflow concept → ZineWorkflow

**Not Kept:**
- Python implementation (replaced with Swift)
- ImageMagick dependency (replaced with CoreImage)

### From AltMedia Engine

**Kept:**
- DSPS compliance requirements → Module scope
- OCR → EPUB pipeline → AltMediaModule roadmap
- Chunking strategies → Future system design

**Not Kept:**
- Python pipeline code (to be reimplemented)
- TCA architecture (simplified to ECS)

## How to Use This Archive

1. **Historical context**: If you need to understand why a decision was made, check these docs
2. **Algorithm reference**: Python implementations can inform Swift rewrites
3. **Do not copy**: Implementation must be fresh Swift fitting AnigmaCore model
4. **Update canonical docs**: If you find missing information, add it to the canonical documents, not here
