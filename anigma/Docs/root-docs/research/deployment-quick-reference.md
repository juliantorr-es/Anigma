> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Deployment Quick Reference for Harmonia V3

**Task**: td-764087  
**Version**: 1.0  
**Last Updated**: April 2026

---

## Strategy Decision Matrix

| Scenario | Recommended | Reason | Rollback Time |
|----------|------------|--------|---------------|
| **Standard update** | Canary + Feature Flags | Balanced risk/speed | 30-60 sec |
| **Critical component** | Blue-Green | Zero downtime needed | 5-10 sec |
| **Bug fix (urgent)** | Feature flag disable | Instant rollback | < 1 sec |
| **Schema migration** | Blue-Green + Dual-write | Data safety critical | 30-60 sec |
| **New feature** | Feature flag rollout | User experience testing | < 1 sec |
| **Configuration change** | Canary + Health checks | Gradual impact testing | 30-60 sec |

---

## Pre-Deployment Checklist (T-24 hours)

```
SECTION: Code & Testing
  [ ] Build succeeds without warnings/errors
  [ ] All unit tests pass (>90overage)
  [ ] Integration tests pass
  [ ] Security scanning: No critical/high findings
  [ ] Performance testing: No regression >5