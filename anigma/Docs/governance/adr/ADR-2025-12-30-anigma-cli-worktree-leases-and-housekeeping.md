# ADR: Worktree Leases and Housekeeping for Anigma CLI (2025-12-30)

## Context
- Anigma operates multiple worktrees for isolated runs; prior sessions created drift and disk bloat.
- RepoIdentity/Stack gates depend on correct worktree metadata; housekeeping must be governed and auditable.

## Decision
- Every mutating run must create/use a worktree via orchestrator; leases are recorded in the session DB with fields: worktreePath, repoRoot, baseCommit, branchName, runId, createdAt, lastUsedAt, intendedTTL (default 72h), locked (bool), protectedReason, mergedStatus (unknown/merged/unmerged), removalEligibility (safe/approval-required/forbidden).
- Listing uses `git worktree list --porcelain` as the source of truth; CLI surfaces lease metadata alongside porcelain data.
- Locks: locked worktrees are immune to pruning/removal; unlocking requires explicit command and approval.
- Cleanup rules:
  - Safe removal: clean, merged worktrees with removalEligibility=safe can be pruned automatically.
  - Approval-required: unmerged or dirty worktrees require an approval flag to remove; default action is to skip.
  - Forbidden: locked worktrees or ones failing RepoIdentity gate cannot be removed until reconciled.
- Housekeeping runs on startup and via explicit command; supports dry-run mode that reports actions without mutation. RepoIdentity gate must pass before destructive cleanup.
- Override knobs: environment variable `ANIGMA_WORKTREE_TTL_HOURS` (default 72) and policy settings for approval prompts.

## Consequences
- Predictable lease metadata supports scheduling and conflict avoidance.
- Disk usage is controlled via governed cleanup; accidental deletion risk reduced by locks and approval requirements.
- Additional receipts/logs for cleanup actions enable auditability.

## Compatibility and migration
- Existing worktrees continue to function; initial lease entries can be backfilled by scanning porcelain list and tagging unknown leases as approval-required until verified.
- Migration requires adding lease tables to DatabaseCore and aligning RepoIdentity/Stack gates to read lease metadata.

## Acceptance and rollback criteria
- Acceptance: Surface/Praxis tests show lease creation per mutating run, porcelain-aligned listing, dry-run housekeeping output, locked worktrees protected, and approval required for unmerged removals.
- Rollback: if lease schema or cleanup flow blocks critical operations, revert to prior manual cleanup while retaining lease data for audit; locked worktrees remain untouched.
