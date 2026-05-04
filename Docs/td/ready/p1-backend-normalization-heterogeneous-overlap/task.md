# td-backend-normalization-heterogeneous-overlap - Map backend normalization against heterogeneous saturated architecture assumptions

> **Status**: In Progress  
> **Type**: Task  
> **Priority**: P1  
> **Lane**: architecture-diagnostics

## Purpose
Diagnose misaligned assumptions between the backend/executable consolidation work and the newer heterogeneous saturated architecture, ECS-inspired data runtime, chunk/SoA receipt, and sidecar isolation doctrine.

## Core Problem
Backend normalization has been consolidating modules, targets, executables, sidecars, and readiness lanes. Meanwhile, the heterogeneous saturated architecture research has clarified that Anigma must distinguish:
- portable contracts
- native executors
- sidecar-isolated capabilities
- ECS/data-oriented runtime storage
- copy-minimized versus zero-copy-proven paths
- materialization gates
- hardware-resident execution
- receipt-backed evidence

The task is to map where backend/executable consolidation assumptions conflict with or fail to account for these newer architecture rules.

## Source Hierarchy
1. **Primary evidence:**
   - `Docs/governance/HETEROGENEOUS_SATURATED_ARCHITECTURE_DOCTRINE.md`
   - `Docs/governance/CHUNK_STORAGE_RECEIPT_DOCTRINE.md`
   - `Package.swift`
   - `Scripts/anigma_package_graph_audit.py` results

2. **Corroborating evidence:**
   - Context7 (if used)
   - Older research/proof artifacts

## Research Questions
1. **Backend normalization assumptions:** What did consolidation assume belongs in the backend? Sidecars as normal executables or governed capabilities? Native executors as internals or isolated implementations?
2. **Heterogeneous architecture assumptions:** Which targets are contracts vs executors vs sidecar-isolated? Which own native linker settings?
3. **ECS/data-oriented overlap:** Which flows should become ECS component/chunk flows? Which current abstractions are component-like vs executor-like?
4. **Zero-copy/copy-minimized overlap:** Which claims are overclaims? Which paths are definitely materialized copies?
5. **Executable/sidecar assumptions:** Which products are sidecars vs tools vs entrypoints? Which should have dedicated readiness lanes?
6. **Package graph assumptions:** Which edges exist due to mixed implementation and contract surfaces? Which targets need classification updates?

## Research Deliverables
Create the following in `Docs/research/backend-normalization-heterogeneous-overlap/`:
1. `README.md`
2. `assumption-map.md`
3. `backend-target-classification.md`
4. `executable-sidecar-map.md`
5. `contract-executor-boundary-map.md`
6. `ecs-dataflow-overlap.md`
7. `materialization-and-copy-claims.md`
8. `misalignment-findings.md`
9. `followup-td-plan.md`

## Proof Artifact
`Docs/proofs/backend-normalization-heterogeneous-overlap-research.md`

## Acceptance Criteria
- Assumptions are mapped against doctrine.
- Sidecar/executable/readiness/contract/executor boundaries are classified.
- ECS/dataflow and zero-copy/copy-minimized audits are documented.
- Misalignments are turned into prioritized follow-up TDs.
- No implementation, Package.swift, or production Swift code changes.

## Non-goals
- Do not modify production Swift code.
- Do not change Package.swift.
- Do not move targets or create new modules.
- Do not implement ECS or sidecar logic.
- Do not claim zero-copy without receipts.
