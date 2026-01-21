---
title: Consolidation Protocol
---

## Goal
Turn “consolidate duplicate modules” into a repeatable pipeline that leaves a structured audit trail, enforces Strangler-style migrations, and keeps coupling explicit.

## Key Roles
| Agent | Responsibility |
| --- | --- |
| **Scout** | Read-only duplicate detector. Emits Duplication Dossiers (concept, locations, semantics, proposed bucket). |
| **Judge** | Authority decision maker. Emits ADR/RFC artifact plus authority map entry (`shared-kernel`, `authority`, `adapter`). |
| **Migrator** | Strangler migrator working in scratch worktrees. Produces patchHashes + receipts without committing. |
| **Integrator** | Applies patches, runs gates, commits only when DoD receipts are green; plugin enforces receipt chain before apply/commit. |

## Consolidation Stages
1. **Discover** – Scout generates Duplication Dossier. Use `inspect_repo`, `.rg`, `swiftpm_log`, `embeddings` to gather evidence. No write operations allowed.
2. **Decide** – Judge produces ADR/RFC in `Docs/governance/contract-artifacts/` describing semantics, coupling risks, migration playbook, and buckets (shared kernel vs authority vs adapter).
3. **Migrate** – Migrator builds canonical surface + adapters in scratch worktree, runs strict concurrency builds, then produces patch via `generate_patch` → `propose_patch` → `validate_patch`. Plugin auto-quarantines failing patches.
4. **Integrate** – Integrator runs `repo_clean_check`, applies patches after ensuring receipts are in order, executes build/log gates, and finally invokes `commit_changes`.

## Enforcement Points
- Plugin ensures `apply_patch`/`commit_changes` only run after receipt chain and that quarantined hashes are blocked.
- Tools (`repo_clean_check`, `swiftpm`, `build_binary`, `vitepress_build`) provide gate outputs that feed DoD.
- `quarantine_patch` and `rollback_last_apply` give rollback/quarantine handles when migrations misfire.

## Outputs per Phase
- **Duplication Dossier** stored under `.opencode/generated/` or `Docs/tech-debt`.
- **ADR/RFC** describing decision and migration plan.
- **PatchHashes + Receipts** for Migrator actions.
- **Integrator DoD Note** referencing milestone, test/build evidence, and plugin receipts.

## Shared Kernel Rules
- Shared Kernel introduces explicit coupling only when the shared subset is small, stable, and versioned.
- Every Shared Kernel change must update the authority map and mention coupling risks in the ADR.
- If semantics diverge, build an anti-corruption adapter instead of merging.

## Parallel Workflows
- Subagents operate in separate worktrees (`worktree_create`, `scratch_worktree`). Each worktree produces patchHashes applied sequentially by the Integrator.
- Authority map updates include scope metadata so multiple subagents avoid overlapping files.

## Acceptance Criteria
1. Duplication Dossier + authority map update exist for each consolidation.
2. All patches go through inspect→generate→propose→validate receipts.
3. SwiftPM strict concurrency validation passes.
4. Commit includes linked ADR, gate receipts, and milestone DoD note.

## Decision Records
- Store ADRs under `Docs/governance/contract-artifacts/` with phase/milestone metadata.
- Use `Docs/phase-contracts/` (create if missing) to track which milestones are satisfied when Integrator commits.

