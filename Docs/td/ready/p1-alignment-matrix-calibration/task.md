# td-alignment-matrix-calibration - Calibrate alignment diagnostic matrix rules and deduplicate findings

> **Status**: Ready  
> **Type**: Task  
> **Priority**: P1  
> **Lane**: architecture-diagnostics

## Problem
The alignment diagnostic matrix is operational and produces P0/P1 diagnostics, but the initial P1 baseline contains high-noise false positives, especially "zero-copy" meta-mentions in doctrine and research documents.

## Goal
Reduce diagnostic noise without hiding real architecture risks.

## Scope
- Deduplicate repeated findings.
- Separate doctrine/meta-discussion mentions from actual overclaims.
- Preserve true P0 sidecar readiness gaps.
- Preserve real native leakage graph findings.
- Add documented accepted exceptions where appropriate.
- Keep outputs deterministic.

## Source of Truth
- `Docs/governance/alignment-diagnostic-rules.yaml`
- `Docs/governance/HETEROGENEOUS_SATURATED_ARCHITECTURE_DOCTRINE.md`
- `Docs/governance/CHUNK_STORAGE_RECEIPT_DOCTRINE.md`
- `Docs/research/backend-normalization-heterogeneous-overlap/`
- `Docs/proofs/alignment-diagnostic-matrix-workflow.md`

## Required Analysis
1. **Review all P0 findings**: Confirm each has a follow-up TD owner.
2. **Cluster P1 findings**: Group by diagnostic class (native leakage, zero-copy overclaim, sidecar readiness gap, missing receipt, ECS terminology).
3. **Identify false-positive classes**: Doctrine rule definitions, research meta-discussion, proof artifacts quoting previous warnings, generated diagnostic output.
4. **Update rules**: Add claim context filters, allowed meta-discussion paths, accepted exceptions, and deduplication keys to `alignment-diagnostic-rules.yaml`.

## Acceptance Criteria
- P1 noise is reduced.
- P0 findings remain visible and actionable.
- Zero-copy doctrine/meta-discussion is not flagged as an overclaim.
- Real zero-copy claims without receipts remain flagged.
- Native leakage graph findings remain graph-backed.
- Output stays deterministic.

## Non-goals
- Do not fix the actual P0/P1 architecture findings.
- Do not suppress all zero-copy scans.
- Do not downgrade real graph reachability findings.
- Do not change production Swift code.
- Do not change Package.swift architecture.
- Do not remove the alignment-matrix workflow.
