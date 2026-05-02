# Anigma Project Timeline

**Purpose:** Durable project record tracking key events across the Anigma project.

## Structure

```
Docs/timeline/
├── README.md                  # This file - overview
├── project-timeline.yaml     # Machine-readable project timeline
├── project-timeline.md       # Human-readable project timeline
├── decisions.yaml            # Architectural decision timeline (rollup from epic decision logs)
└── canonical-doc-changes.yaml # Canonical documentation change log (rollup from task effects)
```

## Event Types

| Type | Description | Example |
|------|-------------|---------|
| `research_start` | Research phase began | "Started source code review for P0-004" |
| `research_complete` | Research phase ended | "Completed doctrine alignment for td-a84da2" |
| `decision` | Architectural decision made | "Chosen SubprocessManager over ProcessPool" |
| `implementation_start` | Code modification began | "Started modifying SubprocessManager.swift" |
| `implementation_complete` | Code modification ended | "Completed warm pool lifecycle implementation" |
| `verification_start` | Verification began | "Started running integration tests" |
| `verification_complete` | Verification ended | "All tests passing, validators green" |
| `proof_created` | Proof artifact created | "Generated p0-004-phase1-proof.md" |
| `task_complete` | Task marked complete | "td-a84da2 marked done" |
| `epic_complete` | Epic marked complete | "p0-004 all phases complete" |
| `blocker_found` | Issue discovered | "Found tier violation in MediaCore import" |
| `blocker_resolved` | Issue resolved | "Fixed by refactoring to use contract interface" |
| `milestone` | Project milestone | "P0-004 all phases complete" |
| `lane_start` | Lane started | "P1 TD Research State lane started" |
| `lane_complete` | Lane completed | "P1 TD Folder System lane complete" |
| `release` | Release event | "v1.0.0 released" |
| `event` | General event | "TD database reset" |
| `meeting` | Meeting or discussion | "Architecture review meeting" |
| `review` | Review event | "Code review completed" |
| `merge` | Merge event | "Merged p0-004 changes" |

## Rollup Hierarchy

```
Task Timeline (Docs/td/<status>/<epic>/tasks/<task-id>/timeline.yaml)
    ↓ Rollup
Epic Timeline (Docs/td/<status>/<epic>/timeline/events.yaml)
    ↓ Rollup
Project Timeline (Docs/timeline/project-timeline.yaml)
```

Each timeline file contains events with:
- `event_id`: Unique within the file
- `timestamp`: ISO 8601 datetime
- `task_id`: The task that generated this (if applicable)
- `epic_id`: The epic containing the task (if applicable)
- `type`: One of the event types above
- `summary`: Human-readable description
- `actor`: Who performed the action (agent, human, script)
- `evidence`: Path to proof or artifact
- `affected_docs`: Docs/ files affected
- `affected_code`: Source files affected
- `canonical_effect`: Effect on canonical documentation
- `followups`: Related event/task IDs

## Timeline Event Model

See `Docs/governance/TD_RESEARCH_AND_TIMELINE_DOCTRINE.md` for detailed event model semantics.

### Event ID Convention

- Task-level events: `{task-id}-{type}-{seq}` (e.g., `td-a84da2-research-start-001`)
- Epic-level events: `{epic-id}-{type}-{seq}` (e.g., `p0-004-milestone-001`)
- Project-level events: `proj-{type}-{YYYYMMDD}-{seq}` (e.g., `proj-lane-start-20250115-001`)

### Sequence Numbers

Events within a timeline file should have unique IDs. Sequence numbers (seq) should be zero-padded to 3 digits (001, 002, etc.) for consistent sorting.

## Validation

```bash
# Validate all timeline YAML files parse
python3 -c "import yaml, pathlib; [yaml.safe_load(open(p)) for p in pathlib.Path('Docs/timeline').glob('*.yaml')]; print('All timeline YAML valid')"

# Validate event IDs are unique within each file
python3 Scripts/validate_td_folder_system.py --check-timeline
```

## How Events Are Generated

1. **Manual recording**: Humans or agents record events directly in timeline files
2. **Automated capture**: Scripts can auto-generate events from git history, TD commands, or proof artifacts
3. **Rollup**: Task-level events can be rolled up to epic and project timelines

## Event Retention

Timeline events are **durable** and should never be deleted. Even if task artifacts are compacted by GC policies, the event history in `Docs/timeline/` must be retained.

## References

- [TD Research and Timeline Doctrine](../governance/TD_RESEARCH_AND_TIMELINE_DOCTRINE.md)
- [TD Folder System README](../td/README.md)
- [Verification Profiles](../manifests/verification-profiles.yaml)

## See Also

- [Docs/timeline/project-timeline.yaml](project-timeline.yaml) - Machine-readable timeline
- [Docs/timeline/project-timeline.md](project-timeline.md) - Human-readable timeline
- [Docs/timeline/decisions.yaml](decisions.yaml) - Decision timeline
- [Docs/timeline/canonical-doc-changes.yaml](canonical-doc-changes.yaml) - Documentation changes
