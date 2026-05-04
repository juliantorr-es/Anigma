# td-alignment-matrix-sidecar-rule-refinement

**Title**: Refine alignment matrix sidecar readiness detection for resolved products and exceptions

**Priority**: P1

---

## Goal

Update alignment matrix detection logic so:
- PDFSidecarExecutable resolved by td-7c0153-01 is not emitted as active P0.
- anigma-mcp exception reason is correct.
- Product type and existing readiness scripts/proofs are considered before emitting P0.
- Sidecar service-level gaps remain visible.

---

## Acceptance Criteria

- alignment-matrix output no longer reports resolved PDFSidecarExecutable as active P0.
- anigma-mcp diagnostic reason is corrected or moved to correct severity.
- real missing sidecar readiness lanes remain P0.
- JSON/CSV output remains deterministic.
- No production Swift code changes.
- No Package.swift architecture changes.
