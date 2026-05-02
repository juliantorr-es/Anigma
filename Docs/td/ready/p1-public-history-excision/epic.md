# p1-public-history-excision - Public History Excision

> **Status**: Ready  
> **Type**: Epic  
> **Priority**: P1  
> **Lane**: publication-cleanup  
> **Worktree**: `anigma/`

---

## Summary

Remove sensitive data, large binaries, and generated artifacts from
Git history before public GitHub publication.

## Current Status

**READY**

## Epic Tasks

*No child tasks*


## Acceptance Criteria

## Acceptance Criteria

- Generated artifacts are removed from Git history
- Vendored binaries with unclear provenance are excluded
- No blobs over 100MB remain in history
- Remote push succeeds without errors
- Repository builds cleanly after cleanup


## Non-Goals

## Non-Goals

- Public website generation
- Rewriting commit history (only cleanup)
- Removing canonical documentation


## Proof Links

## Proof

*No proof artifacts*


## Source Documentation

## Source Docs

- Docs/reports/public-release-dependency-exclusion-audit.md
- Docs/proofs/github-publication-readiness.md
- Docs/proofs/p1-validate-tiers-green-gate.md
- .gitignore


## Agent Handoff

> **For AI agents working on this epic**:
> 
> Check the `tasks/` subdirectory for individual task descriptors.
> Refer to `epic.yaml` for structured data and proofs for completion evidence.
> Preserve MaterializationGate patterns when extending.

---

*Epic ID: p1-public-history-excision*  
*Created: 2026-01-01*
