# Docs/td/ - Task Documentation System

## Purpose

`Docs/td/` is the **canonical, durable source of truth** for all Anigma task definitions. The local TD database is the **executable queue** derived from this documentation.

## Doctrine

- **Docs/ is the source of truth** - Task definitions, acceptance criteria, and proofs are durable documentation
- **TD is the execution queue** - The local `td` CLI database is rebuilt from Docs/td/ after any reset
- ** human-navigable** - Organized by status for easy browsing
- **Agent-executable** - Machine-readable YAML descriptors enable scripted task management

## Directory Structure

```
Docs/td/
├── README.md              # This file - system overview
├── INDEX.md               # Status-grouped task inventory
├── td-task-registry.yaml  # Machine-readable registry (generated)
│
├── ready/                 # Tasks ready for implementation
│   └── <epic-id>/
│       ├── epic.md        # Human-readable epic summary
│       ├── epic.yaml      # Machine-readable epic descriptor
│       └── tasks/
│           └── <task-id>/ # Individual task folders
│               ├── task.md
│               └── task.yaml
│
├── in_progress/            # Currently active work
├── blocked/               # Tasks waiting on dependencies
├── in_review/              # Tasks awaiting acceptance
├── done/                  # Completed tasks with proof
└── archived/              # Historical/grounded context tasks
    └── historical-td-recovery/
        └── README.md      # Recovery context from TD reset
```

## Status Directories

| Directory | Status | Description |
|-----------|--------|-------------|
| `ready/` | ready | Tasks queued for implementation |
| `in_progress/` | in_progress | Currently being worked on |
| `blocked/` | blocked | Waiting on external dependencies |
| `in_review/` | in_review | Awaiting acceptance/review |
| `done/` | complete/done | Completed with proof artifacts |
| `archived/` | archived | Historical context, not actionable |

## File Types

### Markdown Files (`.md`)
- **Purpose**: Human explanation, agent context, handoff prompts
- **Audience**: Developers, reviewers, AI agents needing narrative context
- **Content**: Summary, rationale, scope, non-goals, architecture constraints, handoff notes

### YAML Files (`.yaml`)
- **Purpose**: Machine-readable task/epic descriptors for scripts and validation
- **Audience**: Automation scripts, validation tools, TD bootstrap
- **Schema**: Validated against `Docs/schemas/td-epic.schema.json` and `Docs/schemas/td-task.schema.json`

## Epic Structure

Each epic folder contains:

```
<epic-id>/
├── epic.md          # Human-readable epic documentation
├── epic.yaml        # Machine-readable epic descriptor
├── tasks/           # Sub-tasks (if any)
│   └── <task-id>/
│       ├── task.md
│       └── task.yaml
└── diagrams/        # Epic-specific diagrams (optional)
    └── *.mmd, *.dot
```

## Task Descriptor Shape

See `Docs/schemas/td-task.schema.json` for the full schema. Key fields:

- `id`: Unique task identifier (e.g., `p0-003`, `td-a84da2`)
- `title`: Human-readable title
- `priority`: P0, P1, P2, P3
- `type`: epic, task, chore, bug, feature
- `status`: new, ready, in_progress, in_review, complete, blocked, cancelled
- `lane`: Functional grouping (e.g., `daemon-runtime-isolation`, `architecture-governance`)
- `epic`: Parent epic ID (if applicable)
- `source_docs`: List of related documentation paths
- `acceptance`: List of acceptance criteria
- `proof`: List of proof artifact paths under `Docs/proofs/`
- `td_labels`: Additional labels for TD database
- `worktree`: Recommended worktree path

## Epic Descriptor Shape

See `Docs/schemas/td-epic.schema.json`. Key fields:

- `id`: Epic identifier
- `title`: Epic title
- `priority`: Overall priority
- `status`: Current status
- `lane`: Functional lane
- `summary`: One-sentence summary
- `tasks`: List of child task IDs
- `source_docs`: Related documentation
- `proofs`: Paths to proof artifacts
- `diagrams`: Epic-specific diagram paths
- `recommended_worktree`: Default worktree for child tasks

## Relationship to TD Database

### Bootstrap

To rebuild the TD database from Docs/td/:

```bash
python3 Scripts/td_bootstrap_from_docs.py --apply
```

This:
- Scans all status directories for epic/task descriptors
- Reads `*.yaml` files for machine-readable task data
- Creates TD entries with `task_id:<id>` labels for tracking
- Skips tasks that already exist (idempotent)

### Sync Validation

To validate Docs/td/ ↔ TD database synchronization:

```bash
python3 Scripts/validate_td_docs_sync.py
```

This validates:
- Folder structure matches expected conventions
- Each epic has `epic.md` and `epic.yaml`
- Each task has `task.md` and `task.yaml`
- Task IDs are unique across all descriptors
- Status directory matches YAML `status` field
- Proof paths point to existing files under `Docs/proofs/`
- Source docs and related docs exist
- Registry entries match per-task YAML descriptors

## How Humans Navigate

1. **Browse by status**: Enter the `ready/`, `in_progress/`, etc. directory to see what's in each state
2. **Read epic summaries**: Each epic's `epic.md` provides context and task list
3. **Deep-dive into tasks**: Individual `task.md` files contain full implementation details
4. **Follow proofs**: `proof` fields in YAML link to `Docs/proofs/` for completed work evidence

## How Agents Consume

1. **Discover tasks**: Parse `td-task-registry.yaml` or scan status directories for `*.yaml` files
2. **Read descriptors**: Load `task.yaml` for structured task data
3. **Get context**: Read `task.md` for narrative context and handoff notes
4. **Verify完成**: Check `proof` paths exist under `Docs/proofs/`
5. **Validate**: Run `validate_td_docs_sync.py` before any TD modifications

## How TD Maps to Docs/td/

| TD Field | Docs/td/ Source |
|----------|---------------|
| ID | Auto-generated `td-<hash>` (not stored in Docs) |
| Title | `task.yaml:title` |
| Priority | `task.yaml:priority` |
| Type | `task.yaml:type` |
| Status | `task.yaml:status` (and directory location) |
| Labels | `task.yaml:td_labels` + `task_id:<id>` |
| Description | `task.yaml:description` + `task.md` content |
| Acceptance | `task.yaml:acceptance` |

## Proofs Close Tasks

A task is considered complete when:
1. All acceptance criteria in `task.yaml:acceptance` are met
2. Proof artifacts listed in `task.yaml:proof` exist under `Docs/proofs/`
3. The task's status is updated to `complete` or `done` in its YAML
4. The task folder is moved to `done/` directory

## Worktrees Map to Lanes

| Lane | Worktree | Description |
|------|----------|-------------|
| `p0-critical-path` | `anigma/` | P0 delivery work |
| `daemon-runtime-isolation` | `anigma/` | Daemon subprocess pooling |
| `architecture-governance` | `anigma/` | Tier validation, cycle detection |
| `documentation-infrastructure` | `docs/` | Docs-as-Code, schemas, manifests |
| `publication-cleanup` | `anigma/`, `.` | Git history cleanup for publication |

## Recovery After TD Reset

If the TD database is lost or reset:

1. Ensure `Docs/td/` is intact (check git status)
2. Run `python3 Scripts/td_bootstrap_from_docs.py --apply`
3. Verify with `python3 Scripts/validate_td_docs_sync.py`

The bootstrap is **idempotent** - running it multiple times will not duplicate tasks (detected by `task_id:<id>` labels).

## Adding New Tasks

1. Determine status (ready, in_progress, blocked)
2. Create epic folder under appropriate status directory (or add to existing epic)
3. Create `epic.yaml` with epic descriptor
4. Create `epic.md` with human-readable context
5. For each task:
   - Create `<task-id>/` folder under epic's `tasks/`
   - Create `task.yaml` with structured descriptor
   - Create `task.md` with narrative context
6. Update `Docs/td/td-task-registry.yaml` (can be auto-generated)
7. Run validation: `python3 Scripts/validate_td_docs_sync.py`
8. Bootstrap TD: `python3 Scripts/td_bootstrap_from_docs.py --apply`

## Do NOT Do

- ❌ Store canonical task data only in TD database
- ❌ Commit TD database files to git
- ❌ Create tasks without corresponding Docs/td/ entries
- ❌ Mark tasks complete without proof artifacts
- ❌ Move or duplicate `Docs/proofs/` content into task folders
