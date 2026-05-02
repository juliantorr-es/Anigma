# Docs/td/ Task Index

## Overview

This index provides a **status-grouped** view of all active Anigma tasks. Each task is organized by its current status and linked to its epic/task documentation.

## Status Legend

| Status | Directory | Description |
|--------|-----------|-------------|
| ✅ Done | [`done/`](./done/) | Completed with proof artifacts |
| 🔄 In Progress | [`in_progress/`](./in_progress/) | Currently active |
| 🚀 Ready | [`ready/`](./ready/) | Queued for implementation |
| 🚧 Blocked | [`blocked/`](./blocked/) | Waiting on dependencies |
| 🎯 In Review | [`in_review/`](./in_review/) | Awaiting acceptance |
| 📚 Archived | [`archived/`](./archived/) | Historical context |

---

## ✅ Done (Completed with Proof)

| ID | Title | Type | Lane | Proof |
|----|-------|------|------|-------|
| p0-003 | [Polytropos Phase 0 Implementation](./done/p0-003/) | Epic | p0-critical-path | [p0-003-polytropos-phase0-implementation.md](../../proofs/p0-003-polytropos-phase0-implementation.md), [p0-003-test-results.md](../../proofs/p0-003-test-results.md) |
| p1-validate-tiers-green-gate | [Validate Tiers Green Gate](./done/p1-validate-tiers-green-gate/) | Task | architecture-governance | [p1-validate-tiers-green-gate.md](../../proofs/p1-validate-tiers-green-gate.md) |
| p1-documentation-artifacts-completion | [P1 Documentation-as-Code Artifact Completion](./done/p1-documentation-artifacts-completion/) | Task | documentation-infrastructure | [documentation-artifacts-completion.md](../../proofs/documentation-artifacts-completion.md) |

**Subtotal: 1 epic + 2 standalone tasks = 3 entries**

---

## 🔄 In Progress

| ID | Title | Type | Lane | Proof |
|----|-------|------|------|-------|
| p1-td-source-of-truth-recovery | [P1 — TD Source-of-Truth Recovery and Docs Sync](./in_progress/p1-td-source-of-truth-recovery/) | Epic | documentation-infrastructure | [td-source-of-truth-recovery.md](../../proofs/td-source-of-truth-recovery.md) |

**Subtotal: 1 epic**

---

## 🚀 Ready (Queued for Implementation)

| ID | Title | Type | Lane | Parent | Proof Required |
|----|-------|------|------|--------|----------------|
| p0-004 | [anigmad Subprocess Pooling](./ready/p0-004/) | Epic | daemon-runtime-isolation | None | [p0-004-anigmad-subprocess-pooling.md](../../proofs/p0-004-anigmad-subprocess-pooling.md) |
| > td-a84da2 | [Phase 1: SubprocessManager foundation with pool lifecycle](./ready/p0-004/tasks/td-a84da2/) | Task | daemon-runtime-isolation | [p0-004](./ready/p0-004/) | Test results from SubprocessManagerTests.swift |
| > td-80575e | [Phase 2: Direct integration of HarmoniaV2CLI and AnigmaCLIExecutable](./ready/p0-004/tasks/td-80575e/) | Task | daemon-runtime-isolation | [p0-004](./ready/p0-004/) | CLI commands produce expected output |
| > td-bfe7a3 | [Phase 3: MLWorker warm pool with UMA shared memory](./ready/p0-004/tasks/td-bfe7a3/) | Task | daemon-runtime-isolation | [p0-004](./ready/p0-004/) | Test results from MLWorkerPoolIntegrationTests.swift |
| > td-0dfb09 | [Phase 4: anigma-mcp warm pool with Unix domain sockets](./ready/p0-004/tasks/td-0dfb09/) | Task | daemon-runtime-isolation | [p0-004](./ready/p0-004/) | Test results for MCP worker pool and IPC |
| > td-73aea8 | [Phase 5: On-demand subprocesses for PDF, benchmarks](./ready/p0-004/tasks/td-73aea8/) | Task | daemon-runtime-isolation | [p0-004](./ready/p0-004/) | Test results for PDF sidecar worker, benchmark worker |
| > td-ce4439 | [Phase 6: AnigmaGeminiBridge fate - eliminate or keep](./ready/p0-004/tasks/td-ce4439/) | Task | daemon-runtime-isolation | [p0-004](./ready/p0-004/) | Verification of AnigmaGeminiBridge removal, migrations complete |
| p1-public-history-excision | [Public History Excision](./ready/p1-public-history-excision/) | Task | publication-cleanup | None | [public-history-excision-proof.md](../../proofs/public-history-excision-proof.md) |

**Subtotal: 1 epic + 6 child tasks + 1 standalone task = 8 entries**

---

## 🚧 Blocked

*None currently*

---

## 📚 Archived

| ID | Title | Type | Lane | Status |
|----|-------|------|------|--------|
| *TBD* | Historical TD Recovery | Epic | N/A | archived |

**Subtotal: 0 active, see [historical-td-recovery/README.md](./archived/historical-td-recovery/README.md) for recovery context**

---

## Totals

| Status | Count |
|--------|-------|
| Done | 3 |
| In Progress | 1 |
| Ready | 8 |
| In Review | 0 |
| Blocked | 0 |
| Archived | 0 |
| **Total** | **12** |

---

## Current Recommended Next Lane

### 🎯 Priority: P1 Documentation Infrastructure

**Epic**: [p1-td-source-of-truth-recovery](./in_progress/p1-td-source-of-truth-recovery/) - **In Progress**

**Status**: TD Source-of-Truth Doctrine is established. Docs/td/ folder structure is being created. Bootstrap and validation scripts need updates.

**Recommended Actions**:
1. Complete folder system migration (this document summarize)
2. Update `Scripts/validate_td_docs_sync.py` for new structure
3. Update `Scripts/td_bootstrap_from_docs.py` to read from folder structure
4. Run full validation suite
5. Create proof artifact

**Lane**: documentation-infrastructure  
**Worktree**: `docs/`  

### 🎯 Priority: P1 Publication Cleanup

**Task**: [p1-public-history-excision](./ready/p1-public-history-excision/) - **Ready**

**Status**: Git history cleanup before public GitHub publication.

**Recommended Action**:
- Execute history cleanup commands
- Verify no large binaries remain
- Document cleanup process in proof artifact
- Mark complete when repo is publication-ready

**Lane**: publication-cleanup  
**Worktree**: `anigma/`, `.`

### 🎯 Priority: P1 Architecture Governance

**Task**: [p1-validate-tiers-green-gate](./done/p1-validate-tiers-green-gate/) - **Done**

**Status**: ✅ Validator commands pass for tiers, cycles, and exported imports.

---

## Quick Navigation

```bash
# List all done tasks
ls -la Docs/td/done/

# List all ready tasks  
ls -la Docs/td/ready/

# Find an epic by ID (case-insensitive)
find Docs/td -iname "*p0*004*" -type d

# View epic descriptor
cat Docs/td/done/p0-004/epic.yaml

# Validate entire structure
python3 Scripts/validate_td_docs_sync.py

# Bootstrap TD database from descriptors
python3 Scripts/td_bootstrap_from_docs.py --apply

# Get count of descriptor files
find Docs/td/{done,ready,in_progress} -type f \( -name "*.md" -o -name "*.yaml" \) | wc -l
```

---

## Agent Commands

### Discover All Tasks

```python
import yaml
from pathlib import Path

td_dir = Path("Docs/td")
task_count = 0

for status_dir in sorted(td_dir.iterdir()):
    if status_dir.is_dir() and not status_dir.name.startswith('.'):
        for epic_dir in sorted(status_dir.iterdir()):
            if epic_dir.is_dir():
                epic_yaml = epic_dir / 'epic.yaml'
                if epic_yaml.exists():
                    with open(epic_yaml) as f:
                        epic = yaml.safe_load(f)
                    print(f"{epic['id']}: {epic['title']} ({status_dir.name})")
                    task_count += 1
                    # Count child tasks
                    tasks_dir = epic_dir / 'tasks'
                    if tasks_dir.exists():
                        for task_dir in tasks_dir.iterdir():
                            if task_dir.is_dir():
                                task_yaml = task_dir / 'task.yaml'
                                if task_yaml.exists():
                                    task_count += 1

print(f"Total: {task_count} descriptors")
```

### Validate Before TD Operations

```bash
# Always validate before bootstrapping
python3 Scripts/validate_td_docs_sync.py

# Verify exit code 0
if [ $? -ne 0 ]; then
    echo "VALIDATION FAILED - do not bootstrap"
    exit 1
fi

# Then bootstrap (idempotent)
python3 Scripts/td_bootstrap_from_docs.py --apply
```

---

*Last updated: 2026-05-02 - p0-004 moved to ready, descriptors regenerated*  
*Registry: Docs/td/td-task-registry.yaml (13 tasks)*  
*Descriptors: 24 files generated from registry*
