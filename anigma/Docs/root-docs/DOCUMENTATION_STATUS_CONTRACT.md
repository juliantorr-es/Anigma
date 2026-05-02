# Documentation Status Contract

This repository has accumulated many roadmap, audit, status, and summary documents across different phases. They do not all have the same authority.

This file defines which sources are canonical for which questions.

## Canonical Sources

### Current work status
- `td`
- Use this for: active tasks, blockers, dependency order, review state, handoffs
- `td` is the source of truth for current status

### Current backend/build status
- `anigma/current_build_status.txt`
- `anigma/build_phase3_logs/`
- Use this for: latest local build evidence, current compiler frontier, executable outcomes
- These sources must be interpreted through the current `td` issue graph when turning evidence into status claims

### Product direction and intended architecture
- `anigma/Docs/governance/Roadmap.md`
- Use this for: roadmap direction, intended phases, architectural priorities
- Do not use this alone to infer that the current backend binaries build successfully

### Historical analysis and prior fix reports
- `BUILD_ANALYSIS_2026-02-07.md`
- `FINAL_STATUS_SUMMARY.md`
- `anigma/Docs/status-reports/`
- `anigma/Docs/sprints/`
- Use these for: historical context, prior frontiers, previous implementation reasoning
- Treat them as snapshots unless they explicitly say they are current

## Interpretation Rules

1. When `td` and an older status document disagree, trust `td`.
2. When a roadmap document and live build evidence disagree, trust live build evidence.
3. Older "complete", "final", or "success" documents are not current by default.
4. Any document that summarizes build health should include a date and should state whether it is historical or canonical.

## Documentation Hygiene Rules

1. New build-status docs should either:
   - update a canonical status doc, or
   - declare themselves as historical snapshots at the top.
2. Any document with words like `status`, `complete`, `final`, `integration`, `build`, or `summary` in the title must explicitly say whether it is:
   - canonical, or
   - a dated historical snapshot.
3. Status documents are allowed, but they must be written as evidence snapshots that defer to `td` for the current state.
4. If a status doc includes a progress number or completion claim, it must include:
   - the date of that claim, and
   - a pointer to `td` as the source of truth for what is currently blocked or in progress.
5. New roadmap updates should avoid claiming broad build health unless backed by current build evidence.
6. If a doc is superseded but still useful, keep it and add a historical banner instead of silently deleting it.
7. If a doc is actively misleading, either:
   - update it,
   - archive it, or
   - add a top-of-file warning that points to canonical sources.

## Recommended Status Banner

Use this pattern at the top of any non-canonical status doc:

```md
> Historical status snapshot. This file reflects the state observed on YYYY-MM-DD and is not the source of truth for current status.
>
> Source of truth:
> - `td`
> - `anigma/current_build_status.txt`
> - `anigma/build_phase3_logs/`
```

## Current Known Reality

As of 2026-04-09:
- the package graph is largely consolidated but backend integration is still incomplete
- `harmonia`, `anigmad`, and `anigma-app` remain gated by shared backend blockers
- `HarmoniaModule` is still under active decomposition / exclusion reduction
- some backend-relevant modules are still stub-backed or manifest-stranded

Use this contract to decide where to look first before trusting any status narrative.
