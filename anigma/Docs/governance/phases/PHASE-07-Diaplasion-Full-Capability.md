---
title: Phase 07 - Diaplasion Full Capability
---

Phase ID: PHASE-07
Status: Active
Owner: Diaplasion Maintainers
Last updated: 2025-01-16
Applies to: DiaplasionModule, DiaplasionPipeline, AccessumFlow
Primary gates: Scripts/verify_dependency_boundaries.sh, Scripts/verify_swift6_compliance.sh --target DiaplasionModule, swift test --filter DiaplasionModuleTests

## Purpose
Deliver full, parity-safe Diaplasion capability across ingest, OCR/QA, and exports so the same ECS workflows power both CLI and AccessumFlow.

## Scope
- Sources/DiaplasionModule/**
- Sources/DiaplasionPipeline/**
- Sources/AccessumFlow/**
- Docs/governance/contract-artifacts/SURFACE.DiaplasionFullCapability.md
- Tests/DiaplasionModuleTests/**

## Non-goals
- No new third-party dependencies without contract update and allowlist review.
- No runtime Python or Node execution in production workflows.
- No changes to Core Governance Layer beyond required contracts.

## Invariants
- All supported inputs must land in the canonical ECS component graph.
- OCR and ingest failures are captured in structured components, not log-only paths.
- CLI and AccessumFlow use the same Diaplasion workflows and systems.
- Output artifacts include provenance metadata (hashes, pipeline version, requestId).

## Deliverables
- Ingest support for pdf, image, docx, rtf, html, txt.
- Export coverage for epub, epubFixedLayout, brailleReady (brf/pef), audioReady (ssml + manifest), structuredHTML, largePrint PDF, tagged PDF.
- Workflow parity in DiaplasionPipeline and AccessumFlow, with demo-only paths labeled.
- Tests and TechDebt updates.

## Success metrics
- Phase gates pass.
- DiaplasionModuleTests include ingest-to-export fixtures for each supported output format.
- AccessumFlow and diaplasion-pipeline produce matching output hashes for shared fixtures.

## Acceptance criteria
1. Phase contract and SURFACE.DiaplasionFullCapability contract artifact exist under Docs/governance/.
2. Supported input types (.pdf, .png/.jpg, .docx, .rtf, .html, .txt) ingest into the same ECS component graph with structured error components for failures.
3. Every OutputFormat declared as supported yields an OutputReference with provenance metadata, or is removed or explicitly deferred in TechDebt with a target date.
4. DiaplasionPipeline and AccessumFlow run the same registered workflows and systems; demo-only paths are labeled and blocked from production outputs.
5. OCR failures and language detection edge cases produce structured error components with retry rules and never bypass QA.
6. Tests cover ingest-to-export for at least one fixture per output format and verify CLI vs AccessumFlow parity.
7. Diaplasion-related TechDebt entries are closed or deferred with explicit acceptance criteria and dates.

## Definition of done
- Contract artifact updated.
- Tests green for DiaplasionModule and parity coverage.
- Ledger receipts cite PHASE-07 acceptance criteria.

## Evidence and audit
Record patchHash and proposal receipts with phaseId = PHASE-07. Store gate output in .opencode/logs/phase-07-gates-<timestamp>.log.

## Rollback and stop conditions
If parity tests or gates fail, stop and quarantine the patch, then re-run inspect_repo and validate_patch after corrections.
