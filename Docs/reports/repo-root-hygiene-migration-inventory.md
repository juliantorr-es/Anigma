# Repo Root Hygiene Migration Inventory

**Date**: 2026-05-01
**Inventory Source**: `chore/repo-root-hygiene` worktree

## 1. Root Inventory Summary
- **Tracked Documentation**: `Docs/`, `AGENTS.md`, `LICENSE`, `README.md`.
- **Untracked/Stale**: Numerous `.codex*`, `.gemini`, `.vibe` agent directories.
- **Root Pollution**: `Logo.png`, `justfile`, `scripts/`, `tools/`.

## 2. Root Markdown List
(Excerpts from inventory)
- `AGENTS.md`
- `ANIGMA_MACOS_CAPABILITY_MAP.md`
- `ASSISTANT_ARCHITECTURE.md`
- `BUILD_ANALYSIS_SUMMARY.md`
- `COMPILATION_FIXES_SUMMARY.md`
- `Docs/ROADMAP_INDEX.md`
- `Docs/P0_CRITICAL_PATH.md`
- `Docs/COMPLETION_LEDGER.md`
- `Docs/testing/TESTING_EXECUTION_DOCTRINE.md`
- `Docs/governance/GIT_COMMIT_AND_REMOTE_DOCTRINE.md`
- `Docs/governance/TABULAR_DOCUMENTATION_DOCTRINE.md`

## 3. Docs/proofs/docs Casing Observations
- Canonical directory identified as `Docs/`.
- No lingering `docs/` found in the root scan.

## 4. Risks
- Potential broken links from moved proof artifacts.
- Stale root Markdown needs careful categorization before moving to `Docs/archive/` or `Docs/td/`.
