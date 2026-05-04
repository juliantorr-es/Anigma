# td-sidecar-translate-readiness

**Title**: Implement SidecarTranslateService readiness lane and receipt

**Priority**: P0

**Parent/Related**: td-p0-sidecar-readiness-gap-triage

---

## Goal

Add deterministic readiness validation for SidecarTranslateService as a governed sidecar service.

---

## Acceptance Criteria

- Dedicated readiness lane exists.
- Service dependencies are checked deterministically.
- Missing environment is classified explicitly.
- Generic BackendReadiness remains independent.
- No new cycles/tier violations.
