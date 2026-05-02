# ADR-0000: Template

> **Status:** Template  
> **Date:** YYYY-MM-DD  
> **Supersedes:** None  
> **Superseded by:** None

---

## Context

What is the issue that we're seeing that motivates this decision or change?

---

## Decision

What is the change that we're proposing and/or doing?

---

## Rationale

Why is this the best choice among the alternatives?

### Alternatives Considered

1. **Alternative A**: Description, pros, cons
2. **Alternative B**: Description, pros, cons

---

## Consequences

### Positive

- What becomes easier or better?

### Negative

- What becomes harder or requires migration?

### Neutral

- What changes but isn't clearly better or worse?

---

## Migration

If this changes existing code:
- What needs to be updated?
- What is the deprecation timeline?
- Are there adapters for compatibility?

---

## Ownership

### What This Owns

- Which concepts, APIs, data, or runtime responsibilities become canonical here?

### What This Does Not Own

- Which adjacent responsibilities are explicitly outside this ADR?
- Which systems should remain registries, projections, adapters, or caches instead of becoming owners?

---

## Runtime Budget

- CPU, GPU, ANE, memory, disk, network, and queue budgets.
- Stopping rules, eviction rules, backpressure, and operator-visible pressure states.

---

## Failure Behavior

- Fallback path.
- Degraded mode.
- Kill switch or block behavior.
- Retry and idempotency rule.
- What must never fail silently?

---

## Verification

- Tests, benchmarks, diff checks, receipt checks, or review gates needed before acceptance.
- Evidence that proves the loaded architecture terms map to exact mechanics.

---

## References

- Related ADRs: ADR-XXXX
- Related code: `path/to/file.swift`
- External docs: URL
