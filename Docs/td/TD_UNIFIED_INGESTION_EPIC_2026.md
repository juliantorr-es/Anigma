# TD Epic: Unified Ingestion Architecture

**TD ID**: td-ingest-2026  
**Epic Type**: Implementation Epic  
**Priority**: P1 (moved from P0 - see [TD_PRIORITY_REORGANIZATION_20260430.md](./TD_PRIORITY_REORGANIZATION_20260430.md))  
**Total Points**: 24  
**Total Tasks**: 6  
**Timeline**: Weeks 1-4 (2026)  
**Status**: NOT STARTED  
**Workstream**: Ingestion  

## 📌 IMPORTANT NOTE FOR AGENTS

**Dependency Status**: This epic depends on `td-12f9d2` (Unified Compute epic) which is currently **in_progress** with phases in various states:
- Phase 1-2: in_review
- Phase 3-4: in_progress  
- Phase 5: in_review
- Phase 6: open

**Do NOT start this epic** until `td-12f9d2` and specifically Phase 3 (td-bfe7a3: MLWorker warm pool) are complete, as this epic requires the SubprocessManager foundation.

---

## 🎯 Goal
Implement the architectural mandates for a unified, crash-resilient ingestion pipeline as defined in `UNIFIED_INGESTION_ARCHITECTURE.md`. This epic centralizes routing, isolates unsafe C-based AST parsing, and standardizes semantic chunking across all media and codebase ingestion workflows.

**Depends On**: `td-12f9d2` (Subprocess Pooling) - **BLOCKING**

---

## 📝 Tasks

| TD ID | Task | Points | Status | Assignee | Priority | Depends On | Notes |
|---|---|---|---|---|---|---|---|
| td-ingest-2026-1 | **Implement ArtifactIntakeAuthority** | 5 | Not Started | Core Team | P1 | None | See note below |
| td-ingest-2026-2 | Implement File Signature & Magic Byte Routing | 3 | Not Started | Core Team | P1 | td-ingest-2026-1 | |
| td-ingest-2026-3 | **Implement ASTParserWorkerExecutable Adapter** | 5 | Not Started | Core Team | P1 | td-12f9d2 | **BLOCKED** on SubprocessManager |
| td-ingest-2026-4 | Implement Subprocess Crash Recovery Loop | 3 | Not Started | Core Team | P1 | td-ingest-2026-3 | **BLOCKED** on td-12f9d2 |
| td-ingest-2026-5 | **Implement SemanticChunkingAuthority** | 5 | Not Started | ML Team | P1 | td-ingest-2026-1 | |
| td-ingest-2026-6 | Implement Tokenizer-Aware Context Packing | 3 | Not Started | ML Team | P1 | td-ingest-2026-5 | |

**Note**: These task IDs are **DOCUMENTATION-ONLY** and do NOT exist in the TD task tracker. To create actual TD tasks, use: `td create "<task name>" --priority P1`

---

## 🛠️ Detailed Task Breakdown

#### td-ingest-2026-1: Implement ArtifactIntakeAuthority
**Points**: 5 | **Priority**: P1 | **Workstream**: Core Backend  
**Description**: Build the single, deep universal front door for all data ingestion. Deprecate legacy callers accessing `DiaplasionPipeline` or `BuildIngest` directly.

**Current Status**: NOT STARTED - Blocked on architecture decision for ingestion authority placement

---

#### td-ingest-2026-3: Implement ASTParserWorkerExecutable Adapter
**Points**: 5 | **Priority**: P1 | **Workstream**: Core Backend  
**Description**: Wrap `tree-sitter` (or SourceKitten) in a standalone Swift executable that conforms to the `SubprocessWorker` interface. Move all codebase parsing logic out of the main `anigmad` process to guarantee crash resilience against malformed syntaxes.

**Blocker**: Requires `SubprocessWorker` interface from `td-12f9d2` Phase 1 (td-a84da2) to be complete

---

#### td-ingest-2026-5: Implement SemanticChunkingAuthority
**Points**: 5 | **Priority**: P1 | **Workstream**: ML  
**Description**: Establish a strict seam between ingestion and vectorization. Implement an authority that receives extracted text from any adapter and perfectly chunks/packs it using the active local LLM's tokenizer, maximizing RAG precision globally.

**Note**: This task can potentially start before td-12f9d2 completes, as it has different dependencies

---

## 🎯 Next Steps

1. **Complete td-12f9d2** (Unified Compute epic) - All phases must finish
2. **Verify SubprocessWorker interface** is stable and documented
3. **Create actual TD tasks** for this epic using `td create`
4. **Start with td-ingest-2026-1** (ArtifactIntakeAuthority) as it has no dependencies
5. **Then td-ingest-2026-3** (ASTParserWorkerExecutable) once SubprocessManager is available

---

## 📊 Status Summary

| Phase | Status | Blockers |
|-------|--------|----------|
| Architecture & Planning | ✅ Complete | None |
| Task Definitions | ✅ Complete | None |
| TD Task Creation | ❌ NOT STARTED | Waiting on td-12f9d2 |
| Implementation | ❌ NOT STARTED | Blocked on td-12f9d2 |

---

**Last Updated**: 2026-05-01  
**Priority**: P1 (deferred from P0 due to td-12f9d2 taking P0 priority)  
**Blocker**: td-12f9d2 must complete before implementation can begin
