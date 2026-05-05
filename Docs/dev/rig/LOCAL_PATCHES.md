# Rig Local Patch Proposals

Rig local patch proposals are advisory only.

## Purpose
- Let the local MLX model propose a small, task-scoped patch or edit plan.
- Keep the main worktree untouched in MVP.
- Validate patch structure and scope before any sandbox application.

## Safety Rules
- No Git mutation in the main worktree.
- No staging, committing, pushing, pulling, rebasing, or merging.
- No binary patches.
- No deletions unless explicitly allowlisted in a future revision.
- No absolute paths or path traversal.
- No `.git`, `.venv-rig`, `Session-bundles`, or unrelated `.build` paths.
- No `shell=True`.

## Commands
- `python scripts/rig.py patch status`
- `python scripts/rig.py patch propose --task <task> --backend mlx --allowed-path Docs/dev/rig --allowed-path scripts`
- `python scripts/rig.py patch check --patch .build/rig/patches/<patch_id>/changes.patch`
- `python scripts/rig.py patch apply-sandbox --patch .build/rig/patches/<patch_id>/changes.patch`
- `python scripts/rig.py patch validate --patch .build/rig/patches/<patch_id>/changes.patch`

## Artifacts
- `.build/rig/patches/<patch_id>/patch.json`
- `.build/rig/patches/<patch_id>/changes.patch`
- `.build/rig/patches/<patch_id>/proposal.md`
- `.build/rig/patches/<patch_id>/validation.json`
- `.build/rig/patches/<patch_id>/validation.md`
- `.build/rig/patches/latest.json`
- `.build/rig/patches/latest.md`

## Status
- The local patch lane is a proposal surface, not an authority.
- Sandbox application is for review and validation only.
