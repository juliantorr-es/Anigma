---
title: Phase 06 – Harmonia Swift 6 Migration
---

Phase ID: PHASE-06  
Status: Active  
Owner: Julian Torres  
Last updated: 2025-12-16  
Applies to: HarmoniaModule, AnigmaCore integration surfaces  
Primary gates: Scripts/verify_swift6_compliance.sh, Scripts/verify_dependency_boundaries.sh, Scripts/verify_escape_hatches.sh

## Purpose
Upgrade HarmoniaModule and the AnigmaCore integration boundaries to Swift 6 semantics with strict concurrency assurances so future tooling can rely on Sendable DTOs and deterministic call graphs.

## Scope
Includes `Sources/HarmoniaModule/**`, `Sources/AnigmaCore/**`, and the corresponding `Docs/governance/**` policies. Allowed imports must flow toward `HarmoniaModule` and only use the listed shared kernels (HarmoniaMemory, DoctrineCore). Forbidden surfaces (e.g., SwiftTerm, GRDB) remain off-limits for this phase.

## Non-goals
Do not refactor unrelated capability modules, touch `Sources/AnigmaASTServices/**`, or introduce new public APIs outside the defined shared kernel. Experimental features and docs outside `Docs/governance/` stay frozen until later phases.

## Invariants
- Core governance surfaces must not import SwiftTerm, GRDB, or other platform GUIs.  
- Any cross-module payload must be Sendable and respect actor isolation.  
- Patch receipts must carry `phaseId = PHASE-06` and cite at least one acceptance criterion.

## Deliverables
- Swift 6-safe versions of the highlighted HarmoniaModule files in `.build/`/`Sources`.  
- Updated `type-authority-map.json` documenting new dependencies.  
- Ledger receipts proving each consolidation/gate (including SwiftPM strict-concurrency builds).

## Success metrics
- `Scripts/verify_swift6_compliance.sh` and `Scripts/verify_dependency_boundaries.sh` exit successfully.  
- `swift test` with `SWIFT_STRICT_CONCURRENCY=complete` produces zero errors in the touched modules.  
- Change in `type-authority-map.json` is approved and referenced in the patch receipt detail.

## Acceptance criteria
1. Every consolidation patch cites PHASE-06 and references at least one acceptance criterion from this section.  
2. No new imports reach forbidden targets (SwiftTerm, GRDB).  
3. Ledger contains receipts for the primary gates listed above after each patch.  
4. Migration includes updated documentation under `Docs/governance/Swift6-Migration-Guidance.md`.

## Definition of done
Always obey the global DoD: tests pass, docs updated, forbidden imports unchanged, strict concurrency builds succeed, receipts exist in `.opencode/ledger/workflow.jsonl`.

## Evidence and audit
Record patchHash + proposal receipts with `phaseId = PHASE-06`. Store gate output (stdout/stderr) in `.opencode/logs/phase-06-gates-<timestamp>.log`. Reference the phase doc path and acceptance criteria list in your proposal detail.

## Rollback and stop conditions
If gate commands start failing or SwiftPM strict concurrency errors rise week-over-week, pause the phase, run `rollback_last_apply` on the latest patch, and re-evaluate the DoD before continuing.
