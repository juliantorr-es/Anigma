# TD Context Garbage Collection Doctrine

## Overview

This document establishes the garbage collection (GC) policy for TD (Technical Debt) context artifacts in the Anigma project. The goal is to balance disk space efficiency with the need to maintain historical context for auditing, verification, and knowledge continuity.

## Problem Statement

As tasks move through their lifecycle (new → ready → in_progress → complete → done), they accumulate:
- Worktree snapshots and file copies
- Build artifacts and test outputs
- Log files and console output
- Temporary analysis files
- Cached validation results

Without managed cleanup, these artifacts can:
- Bloat the repository size
- Slow down file system operations
- Make it difficult to locate relevant current context
- Create confusion about what is authoritative

## Guiding Principles

| Principle | Description |
|-----------|-------------|
| **Active Tasks Rich** | Active tasks (ready, in_progress, in_review) retain full context |
| **Completed Tasks Compacted** | Completed tasks discard ephemeral artifacts but preserve proof |
| **Done Tasks Discoverable** | Done tasks are minimally retained but still discoverable via descriptors |
| **No Data Loss** | Proof artifacts are NEVER deleted by GC |
| **Reproducibility** | Sufficient context must remain to reproduce validation |
| **Audit Trail** | All GC operations are logged and reversible (via git) |

## GC Policy Levels

### `retain_all`
- **Applies to:** Epic descriptors (default), P0 critical path tasks
- **Behavior:** No automatic cleanup. All worktrees, artifacts, and cache files are preserved.
- **Rationale:** P0 work and epics serve as reference implementations and may be needed for debugging.

### `compact_on_complete`
- **Applies to:** Most P1 tasks (default)
- **Behavior:** On status transition to `complete`:
  - Remove worktree snapshots
  - Remove build artifacts
  - Remove test outputs
  - Remove temporary analysis files
  - Preserve: task descriptor, proof artifacts, diagrams, source_docs references
- **Rationale:** Reasonable balance for completed but not yet verified work.

### `compact_on_done`
- **Applies to:** P2+ tasks, infrastructure tasks (default)
- **Behavior:** On status transition to `done`:
  - All compact_on_complete actions
  - Additionally remove cached validation results
  - Preserve only: descriptor YAML, proof artifact paths (files remain in Docs/proofs/)
- **Rationale:** Done tasks with proof artifacts don't need runtime context.

### `archive_only`
- **Applies to:** Cancelled tasks, superseded tasks
- **Behavior:** On status transition to `cancelled` or when superseded:
  - Move task directory to `Docs/td/archived/<task-id>/`
  - Preserve descriptor with `archived: true` flag
  - Preserve all proof artifacts
- **Rationale:** Maintain history without cluttering active workspace.

## Context Load Policy

The `context_load_policy` determines how much context is loaded when a task is accessed:

| Policy | Description | When to Use |
|--------|-------------|-------------|
| `eager` | Load all context upfront | Epics, complex tasks needing full context |
| `lazy` | Load context as needed (default) | Most tasks, balance of performance and completeness |
| `on_demand` | Load only when explicitly requested | Simple tasks, fast access |
| `minimal` | Load only descriptor, not full context | Archivable tasks, reference-only access |

## Implementation

### Directory Structure

```
Docs/td/
├── new/
├── ready/
├── in_progress/
├── in_review/
├── complete/
├── done/
├── archived/          # GC-moved tasks
│   └── <task-id>/
│       ├── task.yaml
│       └── archived_meta.yaml  # Original location, timestamp, reason
└── blocked/
```

### File Classification

| Category | Examples | GC Behavior |
|----------|----------|-------------|
| **Descriptor** | task.yaml, epic.yaml | NEVER deleted |
| **Proof** | *.md in Docs/proofs/ | NEVER deleted |
| **Worktree** | Copied source files | Deleted on compact |
| **Build Artifact** | .build/, DerivedData/ | Deleted on compact |
| **Test Output** | test-results/, *.log | Deleted on compact |
| **Cache** | .cache/, *.tmp | Deleted on compact |
| **Diagram** | *.mmd, *.dot, *.svg | NEVER deleted |

### GC Triggers

1. **Manual:** `python3 Scripts/td_context_gc.py`
2. **Status Transition:** Automated via CI on PR merge (when status changes)
3. **Scheduled:** Weekly via GitHub Actions (dry-run only, reports to issue)
4. **Pre-publication:** Full GC with manual review before major releases

## GC Script Interface

```bash
# Dry run (default)
python3 Scripts/td_context_gc.py

# Apply changes
python3 Scripts/td_context_gc.py --apply

# Target specific task
python3 Scripts/td_context_gc.py --task td-123456

#Target specific lane
python3 Scripts/td_context_gc.py --lane daemon-runtime-isolation

# Force policy override
python3 Scripts/td_context_gc.py --policy compact_on_done --apply

# Verbose output
python3 Scripts/td_context_gc.py --verbose
```

## GC Manifest

The `Docs/manifests/td-context-gc-policy.yaml` file defines:
- Default policies per lane
- Default policies per priority
- Task-specific overrides
- Protected paths (never cleaned)
- Expiration rules

## Validations

The following checks are enforced:

1. **VP-GC-001:** GC policy values must be valid enum (`retain_all`, `compact_on_complete`, `compact_on_done`, `archive_only`)
2. **VP-GC-002:** `archive_only` policy requires `archived` directory to exist
3. **VP-GC-003:** Proof artifacts must not be in GC deletion list
4. **VP-GC-004:** Active tasks (ready, in_progress, in_review) must not have `compact_on_done` or `archive_only`
5. **VP-GC-005:** Descriptors must never be targeted for deletion

## Recovery

All GC operations are:
- Logged to `Docs/logs/gc/<timestamp>.log`
- Committed as atomic git operations
- Reversible via `git revert`
- Reported to `#anigma-gc` Slack channel (when configured)

## Examples

### Example 1: P0 Task with Full Retention

```yaml
id: td-a84da2
priority: P0
gc_policy: retain_all
context_load_policy: eager
# All artifacts preserved indefinitely
```

### Example 2: P1 Task with Default Compaction

```yaml
id: td-xyz123
priority: P1
gc_policy: compact_on_complete  # default for P1
context_load_policy: lazy
# Worktree removed when status -> complete
```

### Example 3: Cancelled Task

```yaml
id: td-abc789
status: cancelled
gc_policy: archive_only
context_load_policy: minimal
# Moved to archived/ on next GC run
```

## Migration

Existing tasks without `gc_policy` will receive defaults based on priority:
- P0: `retain_all`
- P1: `compact_on_complete`
- P2+: `compact_on_done`

Tasks can override these defaults by setting `gc_policy` explicitly.

##See Also

- [VERIFICATION_PROFILES.md](./VERIFICATION_PROFILES.md) - Verification profile definitions
- [Docs/manifests/td-context-gc-policy.yaml](../../manifests/td-context-gc-policy.yaml) - GC policy manifest
- [Scripts/td_context_gc.py](../../../Scripts/td_context_gc.py) - GC implementation
