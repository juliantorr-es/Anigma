# TD Priority Reorganization - 2026-04-30

## 📌 CURRENT STATUS NOTE (2026-05-01)

**This reorganization is ACTIVE and REFLECTED in the TD tracker.**

- **P0 Tasks**: 7 tasks in Unified Compute epic (td-12f9d2) - see `td list --priority P0`
- **P1 Tasks**: ~100+ tasks including all previously P0 epics (PostgreSQL, Golden Codebase, Saturated Media, etc.)
- **Saturated Local Inference (td-sli-2026)**: Documentation-only epic, NOT in TD tracker (see separate file)
- **RESEARCH STAGE**: All tasks now require Research Stage completion before implementation. See `.agents/skills/triage/RESEARCH_STAGE.md`

To verify current state: `td list --priority P0` and `td list --priority P1`

---

## Summary

Completed comprehensive reorganization of TD task priorities to reflect the new **P0 epic: Unify Under anigmad with Warm Subprocess Pooling** (td-12f9d2).

## Changes Made

### New P0 Epic Created
**Epic ID:** td-12f9d2  
**Title:** Epic: Unify Under anigmad with Warm Subprocess Pooling  
**Points:** 21  
**Priority:** P0  
**Status**: in_progress

### Child Tasks Created (All P0)
1. **td-a84da2** - Phase 1: Implement SubprocessManager foundation with pool lifecycle (5pts) - **in_review**
2. **td-80575e** - Phase 2: Direct integration of HarmoniaV2CLI and AnigmaCLIExecutable (3pts) - **in_review**
3. **td-bfe7a3** - Phase 3: Implement MLWorker warm pool with UMA shared memory (5pts) - **in_progress**
4. **td-0dfb09** - Phase 4: Implement anigma-mcp warm pool with Unix domain sockets (3pts) - **in_progress**
5. **td-73aea8** - Phase 5: On-demand subprocesses for PDF, Gemini Bridge, and benchmarks (3pts) - **in_review**
6. **td-ce4439** - Phase 6: Decide AnigmaGeminiBridge fate - eliminate or keep (2pts) - **in_review**

**Total P0 Points**: 21 (epic) + 5 + 3 + 5 + 3 + 3 + 2 = **42 points**

### All Other Tasks Moved to P1
Approximately **100+ tasks** previously at P0 have been moved to P1, including:
- PostgreSQL First-Class Implementation (td-89a996) and all sub-tasks
- Golden Codebase Digestion (td-cb7bdb) and all sub-tasks
- Saturated Media Backend (td-21d7e4) and all sub-tasks
- Saturated Autonomous Compute Fabric (td-7cb8d5) and all sub-tasks
- Saturated Inference Plane (td-43be02) and all sub-tasks
- Saturated Compute: UMA Zero-Copy (td-e09a63) and all sub-tasks
- Continuous Garbage Collection Governance (td-427648) and all sub-tasks
- Recovered P0 catch-up queue (td-ee24d8) and all sub-tasks
- Task refinement work (td-820d0e)
- All other standalone P0 tasks

### Documentation Created
1. **ADR:** `Docs/architecture/SUBPROCESS_POOLING_ARCHITECTURE.md`
   - Comprehensive architecture decision record
   - Research on process pooling vs fresh spawning
   - IPC mechanism comparison
   - Industry precedents (Chrome, VS Code, Docker, Nginx)
   - Apple-specific considerations
   - Success metrics

2. **This Document**: Priority reorganization summary

3. **Related**: [TD_PHASE6_UPDATE.md](./TD_PHASE6_UPDATE.md) - Multi-provider LLM integration status

---

## Current P0 State

```
P0 TASKS (7 total, 42 points):
├── td-12f9d2  Epic: Unify Under anigmad with Warm Subprocess Pooling [21pts] [in_progress]
├── td-a84da2  Phase 1: SubprocessManager foundation [5pts] [in_review]
├── td-80575e  Phase 2: Direct CLI integration [3pts] [in_review]
├── td-bfe7a3  Phase 3: MLWorker warm pool [5pts] [in_progress]
├── td-0dfb09  Phase 4: anigma-mcp warm pool [3pts] [in_progress]
├── td-73aea8  Phase 5: On-demand subprocesses [3pts] [in_review]
└── td-ce4439  Phase 6: AnigmaGeminiBridge decision [2pts] [open]
```

**Verification Command:**
```bash
td list --priority P0
```

---

## Architecture Decision Summary

After comprehensive research of industry-leading systems (Chrome, VS Code, Docker, Nginx, Apache), the **warm subprocess pooling with tiered strategy** was selected:

### Tier 1: Unified Deep Interface
- All legacy CLIs (Harmonia, AnigmaCLI, Verifier) are absorbed into the single `anigmad` deep module interface.
- All heavy parsing and inference workloads are delegated across the seam to `SubprocessWorker` adapters.

### Tier 2: Warm Process Pool
- `anigma-mcp`: 2-4 workers with Unix domain sockets
- `MLWorkerExecutable`: 1-2 workers per GPU with UMA shared memory

### Tier 3: On-Demand Spawning
- `PDFSidecarExecutable`: Per-request with macOS sandbox
- `AnigmaGeminiBridge`: Per-session (or eliminate - see Phase 6 decision)
- `anigma-capsule-bench`: Per-benchmark session

### IPC Strategy
- **UMA Shared Memory** for ML tensor data (~0.1-0.5μs latency)
- **Unix Domain Sockets** for MCP/PDF structured messages (~1-5μs latency)
- **stdin/stdout pipes** for CLI delegation (~10-50μs latency)

### Performance Targets
| Metric | Target | Improvement |
|--------|--------|-------------|
| Subprocess spawn latency | < 10ms | - |
| Pool worker ready time | < 50ms | - |
| IPC latency (shared memory) | < 1μs | - |
| IPC latency (Unix socket) | < 5μs | - |
| Throughput improvement | +15-50% | vs on-demand spawning |
| Cold start elimination | 100% | For pooled workers |

---

## Rationale

This reorganization reflects the user's priority: **consolidating all executables into `anigmad`** (except `anigma-app`) with subprocesses for parallelization/isolation. The warm pooling approach, based on research of production systems at Chrome, Nginx, and Apache, provides:

1. **15-50% performance improvement** for high-frequency operations
2. **Deterministic latency** (no cold-start jitter)
3. **Preserved isolation** (security and fault tolerance)
4. **Production-proven patterns**
5. **Apple Silicon optimization** (UMA support)

All other work is now P1, to be addressed after the subprocess architecture is in place.

---

## Next Steps

1. **Start the epic:** `td start td-12f9d2`
2. **Implement Phase 1:** SubprocessManager foundation (td-a84da2)
3. **Review ADR:** Ensure architecture aligns with Anigma's standards
4. **Execute phases:** Work through the 6 phases in order
5. **Complete Phase 6:** Decision on AnigmaGeminiBridge fate (td-ce4439) - see [TD_PHASE6_UPDATE.md](./TD_PHASE6_UPDATE.md)

---

## Verification

```bash
# View the new P0 epic
td show td-12f9d2

# View all P0 tasks (should only show 7 tasks)
td list --priority P0

# View all P1 tasks (should show ~100+ tasks)
td list --priority P1

# View the ADR
open Docs/architecture/SUBPROCESS_POOLING_ARCHITECTURE.md
```

---

**Date:** 2026-04-30  
**Session:** ses_423937  
**Author:** Vibe  
**Status:** Complete  
**Current State:** ACTIVE - P0 tasks are live in TD tracker
