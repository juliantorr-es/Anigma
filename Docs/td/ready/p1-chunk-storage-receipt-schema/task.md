# td-chunk-storage-receipt-schema - Define chunk/SoA storage receipt schema for ECS-inspired data runtime

> **Status**: Ready  
> **Type**: Task  
> **Priority**: P1  
> **Lane**: architecture-research

## Purpose
Define the receipt schema Anigma will use to prove chunk/SoA data layout, materialization events, copy-minimized execution, and zero-copy claims before implementing runtime storage logic.

## Goal
Create a versioned receipt schema for chunk/SoA storage operations that can classify and prove:
- chunk allocation
- chunk compaction
- component layout
- SoA column layout
- materialized copy
- no-copy wrapping
- shared-memory access
- hardware-resident execution
- sidecar transfer
- unknown/unverified movement

## Source of Truth
- `Docs/governance/HETEROGENEOUS_SATURATED_ARCHITECTURE_DOCTRINE.md`
- `Docs/research/heterogeneous-saturated-architecture/ecs-data-oriented-zero-copy.md`
- `Docs/research/heterogeneous-saturated-architecture/apple-silicon-metal.md`
- `Docs/research/heterogeneous-saturated-architecture/anigma-doctrine-gap-analysis.md`
- `Docs/proofs/heterogeneous-saturated-architecture-research.md`

## Deliverables
- `Docs/schemas/chunk-storage-receipt.schema.json`
- `Docs/governance/CHUNK_STORAGE_RECEIPT_DOCTRINE.md`
- `Docs/proofs/chunk-storage-receipt-schema.md`
- `Docs/td/ready/p1-chunk-storage-receipt-schema/task.md`
- `Docs/td/ready/p1-chunk-storage-receipt-schema/task.yaml`

## Acceptance Criteria
- Schema distinguishes zero-copy from copy-minimized.
- Schema does not rely on native handles.
- Schema can represent Metal/CPU/shared/sidecar memory without exposing platform APIs.
- Schema supports materialization gate evidence.
- Schema supports fallback evidence.
- Doctrine forbids zero-copy claims unless receipt movementClassification is zero_copy_proven or no_copy_wrap with proof.
- No production code changes.

## Non-goals
- Do not implement runtime ECS storage.
- Do not add Metal/CUDA/ROCm code.
- Do not modify Package.swift.
- Do not add dependencies.
- Do not claim zero-copy without instrumentation.
- Do not expose native handles in portable contracts.