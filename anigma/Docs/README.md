Primary documentation hub for the repo.
Invariants: keep docs short, accurate, and anchored to real entry points.

Entry points:
- `Docs/` markdown references
- `Docs/root-docs/` for documentation imported from the former repository-root `docs/` tree
- `/Users/user/Developer/GitHub/Anigma_clean/anigma/Docs/root-docs/DOCUMENTATION_STATUS_CONTRACT.md`
- `/Users/user/Developer/GitHub/Anigma_clean/anigma/Docs/status-reports/CURRENT_BACKEND_STATUS.md`

Public surface:
- Architecture and governance documentation.

Status authority:
- `td` is the source of truth for active blockers, dependency order, and what should be worked on next.
- `current_build_status.txt` and `build_phase3_logs/` are evidence sources, not planning authorities.
- Older status reports in `Docs/status-reports/` and `Docs/sprints/` must be treated as dated snapshots unless they explicitly say otherwise.

Build/test:
- No build targets; update alongside code changes.

Consolidation:
- As of 2026-04-20, repository-root `docs/` was moved under `anigma/Docs/root-docs/`.
- New documentation should be created under `anigma/Docs/`, not repository-root `docs/`.
- `root-docs/` preserves older paths and historical navigation until individual pages are promoted or merged into canonical `anigma/Docs` sections.

Related docs:
- `../llmdocs/01-architecture-overview.md`
- `../llmdocs/18-build-and-release.md`
