# Git Worktree Doctrine
Status: Canonical

## Purpose
Define the usage of Git worktrees for Anigma, ensuring isolated, epic-scoped task lanes while preventing filesystem clutter and branch churn.

## Core Rule
One worktree = one active epic/lane/merge boundary.
TD tasks are evidentiary units inside an epic; they do not automatically require new worktrees.

## Worktree Scope
- Create a new worktree ONLY when the work requires a separate merge boundary or distinct risk isolation.
- Do not create a new worktree merely because there is a new TD task within an existing active epic.
- Default parent directory: `../anigma-worktrees/`.

## Lane Closeout Protocol
Agents must perform the following before marking a lane complete or shifting focus:
1. **Validation**: Confirm all work is committed or explicitly documented as abandoned.
2. **Evidence**: Verify proof artifacts reside under `Docs/proofs/`.
3. **Hygiene**: Confirm no generated/untracked artifacts are staged.
4. **Merge/Abandon**: Merge or abandon the lane branch.
5. **Removal**: Run `git worktree remove <path>`.
6. **Prune**: Run `git worktree prune`.
7. **Branch Cleanup**: Delete local lane branch ONLY after successful merge or documented abandonment.
8. **Report**: Run `git worktree list` to verify workspace status.

## Safety Rules
- **No Force**: Do not use `git worktree remove --force` unless the lane is explicitly marked abandoned/superseded.
- **No Silent Deletion**: Never delete uncommitted work.
- **No Branch Deletion**: Only delete branches that are merged or explicitly abandoned.
- **Root Protection**: Do not create worktrees inside the repository root.

## Agent Permission
Agents follow Level 1 (prepare patch only) unless granted higher permissions for a specific lane.
Scripts in `Scripts/git/` are the blessed tools for managing this workflow.
