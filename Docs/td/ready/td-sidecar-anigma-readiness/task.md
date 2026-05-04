# td-sidecar-anigma-readiness

**Title**: Implement AnigmaSidecar readiness lane and receipt

**Priority**: P0

**Parent/Related**: td-p0-sidecar-readiness-gap-triage, td-7c0153-01

---

## Goal

Add deterministic readiness validation for AnigmaSidecar as a governed sidecar capability.

---

## Non-goals

- Do not merge AnigmaSidecar into generic BackendReadiness.
- Do not remove sidecar isolation.
- Do not add native dependencies to contract modules.
- Do not create fake stubs.

---

## Acceptance Criteria

- Dedicated readiness command/script exists.
- Readiness result emits or documents receipt/proof.
- Generic BackendReadiness does not require AnigmaSidecar.
- Graph invariants hold.
- No new cycles/tier violations.
