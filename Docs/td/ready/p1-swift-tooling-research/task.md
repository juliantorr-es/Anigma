# td-swift-tooling-research - Study SwiftPM, llbuild, Swift driver, and SwiftSyntax to improve Anigma build/test/code doctrine

> **Status**: Ready  
> **Type**: Task  
> **Priority**: P1  
> **Lane**: documentation-infrastructure  
> **Epic**: [p1-documentation-infrastructure](../)  
> **Worktree**: `docs/`

---

## Goal

Study upstream Swift tooling repositories and convert source-backed findings into Anigma doctrine updates for package graph hygiene, plugin policy, test behavior, build evidence, compiler-driver evidence, and SwiftSyntax-based validators.

## Context

This task is research-first. It must clone and inspect upstream Swift tooling repositories outside the Anigma package graph, then update Anigma doctrine and proof docs from exact upstream files, symbols, and commits.

## Scope

- Clone and inspect SwiftPM, llbuild, swift-driver, SwiftSyntax, and optionally Swift Build and swift.
- Record source-grounded findings with file, symbol, commit, and line citations.
- Update or create doctrine documents for build tooling, testing, and code doctrine.
- Create proof and index artifacts for the research package.
- Create follow-up TDs for implementation ideas instead of implementing them immediately.

## Acceptance Criteria

- Research docs exist for each studied upstream repository area.
- Findings cite exact upstream files, symbols, commits, and line ranges where available.
- `Docs/governance/BUILD_TOOLING_DOCTRINE.md` is created or updated with source-grounded rules.
- `Docs/governance/CODE_DOCTRINE.md` is created if absent and updated with source-grounded rules.
- `Docs/governance/TESTING_DOCTRINE.md` is updated with Swift Testing and receipt guidance grounded in upstream behavior.
- `Docs/proofs/swift-tooling-research-doctrine-update.md` exists and records the research outcome.
- Relevant indexes and manifests reference the new doctrine and proof artifacts.
- No upstream repository is vendored into Anigma.
- No production Anigma code is changed during the research phase.

## Non-Goals

- Do not fork SwiftPM.
- Do not vendor upstream Swift tooling into Anigma.
- Do not redesign Anigma build system yet.
- Do not replace validators yet.
- Do not implement follow-up ideas in production code during this task.

## Implementation Shape

## Source Files

- https://github.com/swiftlang/swift-package-manager
- https://github.com/swiftlang/swift-llbuild
- https://github.com/swiftlang/swift-driver
- https://github.com/swiftlang/swift-syntax
- https://github.com/swiftlang/swift-build
- Docs/governance/BUILD_TOOLING_DOCTRINE.md
- Docs/governance/CODE_DOCTRINE.md
- Docs/governance/TESTING_DOCTRINE.md
- Docs/proofs/swift-tooling-research-doctrine-update.md
- Docs/research/swift-tooling/README.md

## Validation Commands

- `python3 -c "import yaml; yaml.safe_load(open('Docs/manifests/documentation-artifacts.yaml'))"`
- `python3 Scripts/validate_td_docs_sync.py`
- `python3 Scripts/td_bootstrap_from_docs.py --apply`

## Proof Requirements

- Proof artifact with repositories cloned, commits studied, files/symbols inspected, doctrine changes, findings summary, recommendations, validation commands, and follow-up TDs created.

---

*Task ID: td-swift-tooling-research*  
*Created: 2026-05-03*
