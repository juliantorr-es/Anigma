---
title: "Task System Reference"
description: "Complete reference documentation for the Anigma task system"
audience: ["developers", "contributors", "all"]
complexity: "intermediate"
estimated_time: "20min"
keywords: ["tasks", "td", "epics", "system", "reference", "documentation"]
status: "stable"
last_updated: "2026-04-16"
---

# Task System Reference

This document provides a complete reference for the Anigma task system and how to use TD (Task Dispatcher).

## Overview

The task system is built on the **3-phase model**:

1. **Research Phase** - Investigate and understand the problem
2. **Design Phase** - Create a detailed plan
3. **Implementation Phase** - Build the solution

All work is tracked in **TD (Task Dispatcher)**, a local task management CLI that serves as the source of truth for project status.

## Task Structure

### Task Hierarchy

```
Epic (td-333894)
├── Task (td-296847) [Research]
├── Task (td-296848) [Design]
└── Task (td-296849) [Implementation]
    ├── Subtask (td-296850) [Implementation detail]
    └── Subtask (td-296851) [Implementation detail]
```

### Task Statuses

| Status | Meaning | Action |
|--------|---------|--------|
| `open` | Not started | Can be started with `td start` |
| `in_progress` | Actively being worked on | Use `td log` for updates |
| `in_review` | Waiting for approval | Awaiting reviewer feedback |
| `blocked` | Cannot proceed | Blocked on another task |
| `done` | Completed and approved | No further action needed |

### Task Priority Levels

| Priority | Meaning | Focus |
|----------|---------|-------|
| P0 | Critical - ship blocker | Must be done before release |
| P1 | High - unblock other work | Do before general features |
| P2 | Medium - scheduled work | Standard sprint velocity |
| P3 | Low - nice to have | Do if time permits |
| P4 | Backlog - future consideration | Not scheduled |

## Current Epics

### Core Development Epics

| Epic ID | Title | Status | Tasks | Docs |
|---------|-------|--------|-------|------|
| td-7ff1d3 | Hardware Saturation & Megakernel Inference | started | 25 | [Hardware Saturation](../../guides/HARMONIA_V3_BACKEND_STABILIZATION.md) |
| td-333894 | Harmonia Migration: V2 to V3 | open | 18 | [Harmonia Migration](../../guides/HARMONIA_MIGRATION_EPIC.md) |
| td-2c38e1 | Backend executable rebuild stabilization | in_progress | 22 | [Build System](../../guides/building.md) |
| td-751620 | Frontend UX unblock track | in_review | 15 | [UI Architecture](../../architecture/) |
| td-9c5f4b | Assistant reliability unblock track | in_review | 12 | [Reliability](../../architecture/observability.md) |
| td-40a6ce | Backend database architecture consolidation | open | 20 | [Persistence](../../architecture/database-architecture.md) |
| td-0729fd | Personal context as evolving memory | open | 16 | [Memory System](../../concepts/architecture.md) |
| td-c71ebd | Harden long-run agent runtime | open | 14 | [Runtime](../../architecture/runtime.md) |

### Documentation Epics

| Epic ID | Title | Status | Tasks | Docs |
|---------|-------|--------|-------|------|
| td-aee273 | Documented Intent Cleanup and Canonicalization | started | 1 | [Cleanup](../README.md) |
| td-9bf6ea | Documentation Architecture and Restructuring | open | 8 | [Documentation](../../README.md) |
| td-d8a870 | Consolidate and reorganize top-level documentation | in_progress | 5 | [This guide](../reference/task-system-reference.md) |
| td-262712 | Integrate task documentation | open | 6 | [Task Integration](../reference/task-system-research-phase.md) |

## Quick Reference Table: All 8 Key Epics

| # | Epic | ID | Phase | Tasks | Key Blockers |
|---|------|----|----|-------|--------------|
| 1 | Hardware Saturation | td-7ff1d3 | Phase 3 | 25 | SaturatedSearch logic |
| 2 | Harmonia Migration | td-333894 | Phases 2-4 | 18 | HarmoniaModule errors |
| 3 | Build Stabilization | td-2c38e1 | Phase 2 | 22 | AnigmaCore compilation |
| 4 | Frontend UX | td-751620 | Phase 1 | 15 | UI framework updates |
| 5 | Assistant Reliability | td-9c5f4b | Phase 2 | 12 | Runtime contracts |
| 6 | Database Architecture | td-40a6ce | Phase 1 | 20 | Schema migration |
| 7 | Personal Context | td-0729fd | Phase 2 | 16 | Memory system design |
| 8 | Runtime Hardening | td-c71ebd | Phase 2 | 14 | Contract definitions |

## Essential TD Commands

### Starting Work

```bash
# Check what to work on
td usage -q

# Start a specific task
td start <task-id>

# Start a task with reason
td start <task-id> --reason "Fixing the X component"

# Create a new work session
td ws start "session-name"

# Add tasks to current session
td ws tag <task-id> [task-id...]
```

### Tracking Progress

```bash
# Log progress update
td log <task-id> "Fixed URLParser, next: implement validation"

# Send heartbeat (every 30-45 minutes for active work)
td log <task-id> "HEARTBEAT: active on URLPath refactoring; next: integration tests"

# Show task details
td show <task-id>

# List tasks by status
td ready        # Tasks ready to start
td in-review    # Tasks awaiting approval
td blocked      # Tasks waiting on dependencies
```

### Handling Blockers

```bash
# Block a task on another
td block <task-id> <blocker-task-id>

# Log blocker info
td log <task-id> "BLOCKED: Waiting on td-XXXXX. Blocker is: X"

# Check stale tasks
Scripts/td_stale_tasks.sh
```

### Completing Work

```bash
# Mark task complete with summary
td handoff <task-id> \
  --done "Implemented URLPathResolver with 5 implementations" \
  --remaining "Integration testing needed" \
  --decision "Used protocol pattern for extensibility" \
  --uncertain "Performance under high load untested"

# Check current session
td session

# Start independent agent session
td session --new
```

## Task Phases in Detail

### Phase 1: Research

**Goal**: Understand the problem space

**Activities**:
- Investigate current state
- Analyze constraints
- Document findings
- Create decision records

**Deliverables**:
- Research artifacts (decision records, diagrams, analysis)
- Clear problem statement
- Documented constraints

**Success**: Ready to design

**See Also**: [Research Phase Guide](./task-system-research-phase.md)

### Phase 2: Design

**Goal**: Create a detailed implementation plan

**Activities**:
- Evaluate approaches
- Create specifications
- Break into implementation tasks
- Document trade-offs

**Deliverables**:
- Design specification
- Implementation task list
- Risk mitigation plans

**Success**: Ready to implement

**See Also**: [Design Phase Guide](./task-system-design-phase.md)

### Phase 3: Implementation

**Goal**: Build what was designed

**Activities**:
- Implement features
- Write tests
- Update documentation
- Get code reviewed

**Deliverables**:
- Working code
- Test coverage > 80%
- Updated documentation
- Code review approval

**Success**: Task complete and deployed

**See Also**: [Implementation Phase Guide](./task-system-implementation-phase.md)

## Linking Tasks to Documentation

### From Documentation to Tasks

In documentation files, reference tasks like this:

```markdown
## URL Path Resolution

This feature is tracked in:
- Research: [td-296847](https://td.local/tasks/td-296847)
- Design: [td-296848](https://td.local/tasks/td-296848)
- Implementation: [td-296849](https://td.local/tasks/td-296849)

See also: [URL Path Design Guide](../guides/url-paths.md)
```

### From Tasks to Documentation

In task descriptions, link to docs:

```
Implementation of URL path resolution system

See: /Docs/guides/url-paths.md
Research phase: td-296847
Design phase: td-296848

Acceptance Criteria:
- [ ] URLPathResolver protocol implemented
- [ ] 5 concrete implementations working
- [ ] >85% test coverage
- [ ] Documentation updated
```

## Auto-Generated Tasks

The system automatically generates tasks from epics:

1. **Epic Created** → Automatic task scaffolding
2. **Phase Assigned** → Phase-specific guidance
3. **Task Started** → Activity tracking begins
4. **Task Complete** → Automatic summary generation

### Example: Auto-Generated Task from Epic

**Epic**: `td-333894 "Harmonia Migration: V2 to V3"`

**Auto-Generated Sub-Tasks**:
- `td-0cb66d` - Implement Harmonia Conductor (Research)
- `td-1edbaa` - Wire memory and retrieval backend (Design)
- `td-e3b75e` - Wire tool execution runtime (Implementation)

Each has standard lifecycle: Research → Design → Implementation

## Navigation Metadata

Tasks are discoverable through navigation metadata in `_navigation.json`:

```json
{
  "epics": {
    "harmonia-migration": {
      "id": "td-333894",
      "title": "Harmonia Migration: V2 to V3",
      "docs": "/Docs/architecture/harmonia-backend.md",
      "status": "open"
    }
  }
}
```

This enables agent queries like:

```bash
# Find all tasks for an epic
td query "epics:harmonia-migration"

# Find tasks by status
td query "status:in_progress"

# Find tasks by priority
td query "priority:P0"
```

## Best Practices

### ✅ DO

- **Log progress daily** - Keep work visible
- **Break into small tasks** - 3-7 day tasks are ideal
- **Link to documentation** - Make connections discoverable
- **Document blockers immediately** - Don't work around them
- **Use phase model** - Research → Design → Implementation
- **Link commits to tasks** - Reference task ID in commit messages

### ❌ DON'T

- **Work silently** - Log progress regularly
- **Create huge tasks** - Break them down
- **Skip phases** - All three phases matter
- **Leave blockers unlinked** - Document dependencies
- **Assume tasks are independent** - Map dependencies
- **Forget to handoff** - Use `td handoff` at end of work

## Common Workflows

### Workflow 1: Starting a New Initiative

```bash
# 1. Create epic
td create "epic" --title "New Feature X"

# 2. Add research task
td create --parent <epic-id> "task" --title "Research Feature X" --phase research

# 3. Start research
td start <research-task-id>

# 4. Log progress
td log <research-task-id> "Completed investigation, see decision record"

# 5. Create design task
td create --parent <epic-id> "task" --title "Design Feature X" --phase design

# 6. Continue phases
...
```

### Workflow 2: Recovering Stale Work

```bash
# 1. Check stale tasks
Scripts/td_stale_tasks.sh

# 2. Review abandoned work
td show <stale-task-id>

# 3. Recover and resume
td start <stale-task-id> --reason "Recovering stale work"
td log <stale-task-id> "RECOVERY: Resuming from prior session"

# 4. Continue work
...
```

### Workflow 3: Handling Blockers

```bash
# 1. Identify blocker
td log <task-id> "BLOCKED: Depends on td-XXXXX"

# 2. Link blocker
td block <task-id> <blocker-id>

# 3. Work on blocker if assigned
td start <blocker-id>

# 4. Unblock when done
# (Automatic when blocker task completes)
```

## Related Documentation

- [Research Phase Guide](./task-system-research-phase.md) - How to do research
- [Design Phase Guide](./task-system-design-phase.md) - How to design
- [Implementation Phase Guide](./task-system-implementation-phase.md) - How to implement

## Troubleshooting

### Q: How do I find related tasks?
```bash
td query "epic:td-333894"  # All tasks for an epic
td query "blocker:td-XXXXX"  # All tasks blocked by X
```

### Q: Where do I log a blocker?
```bash
td log <task-id> "BLOCKED on td-XXXXX: [reason]"
td block <task-id> <blocker-id>
```

### Q: When should I use handoff?
```bash
# Use handoff when:
# - Task is complete (use --done with summary)
# - Task is blocked (use --blocker)
# - Switching to a different person/agent
# - End of work session
```

### Q: How do I recover a stale task?
```bash
# Check stale tasks
Scripts/td_stale_tasks.sh

# Resume the work
td start <task-id> --reason "Recovering stale work"
td log <task-id> "RECOVERY: Continuing from prior session"
```

---

See also:
- [Back to Development Guide](./README.md)
- [Back to Docs Home](../README.md)
