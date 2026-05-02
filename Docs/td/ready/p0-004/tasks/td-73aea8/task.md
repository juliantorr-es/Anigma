# td-73aea8 - Phase 5: On-demand subprocesses for PDF, Gem, and benchmarks

> **Status**: Ready  
> **Type**: Task  
> **Priority**: P0  
> **Lane**: daemon-runtime-isolation  
> **Epic**: [p0-004](../)  
> **Worktree**: `anigma/`

---

## Goal

See acceptance criteria

## Context

No description available.

## Scope

## Acceptance Criteria

- PDFSidecarWorker for isolated PDF processing
- BenchmarkWorker for performance testing
- On-demand spawning with macOS sandbox support
- Per-request subprocess isolation


## Non-Goals

## Non-Goals

- Per-request PDFium server (future optimization)


## Implementation Shape

## Source Files

- anigma/Packages/SubprocessPooling/Sources/PDFSidecarWorker.swift
- anigma/Packages/SubprocessPooling/Sources/BenchmarkWorker.swift
- Docs/td/TD_PHASE6_UPDATE.md
- Docs/proofs/p0-004-anigmad-subprocess-pooling.md


## Acceptance Criteria

## Criteria

- PDFSidecarWorker for isolated PDF processing
- BenchmarkWorker for performance testing
- On-demand spawning with macOS sandbox support
- Per-request subprocess isolation


## Validation Commands

## Validation Commands

*None*


## Proof Requirements

## Proof

*No proof artifacts*


---

*Task ID: td-73aea8*  
*Created: 2026-01-01*
