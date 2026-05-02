# P1 Validate Tiers Green Gate

**Task:** P1 Architecture Debt — Clear validate_tiers.py Boundary Violations  
**Canonical Proof Path:** `Docs/proofs/p1-validate-tiers-green-gate.md`  
**Date:** 2026-05-02  
**Status:** LANE COMPLETE - GOVERNANCE VALIDATORS GREEN

---

## Objective
Return `validate_tiers.py` to exit code 0 by resolving the SecurityEventsManager tier classification drift.

## Root Cause
`SecurityEventsManager` was reclassified from TIER_1 to TIER_2 during td-8f2e57 due to its dependency on DatabaseCore (a TIER_2 module), but the validator configuration files retained the old classification. This caused a false-positive Tier 1 boundary violation.

## Fix Applied
**Pattern:** Configuration Alignment (validator metadata correction)  
**Scope:** 3 validator copies updated  
**Type:** Metadata-only — no runtime source changes

### Files Modified
1. `tools/governance/scripts/validate_tiers.py` — Source of truth
2. `anigma/Scripts/validate_tiers.py` — Local CI copy
3. `Scripts/validate_tiers.py` — Root-level copy
4. `README.md` — Updated validator status documentation

### Change
Moved `SecurityEventsManager` from `TIER_1` set to `TIER_2` set:
```python
# Before
TIER_1 = {"GovernanceCore", "DoctrineCore", "AnigmaPrimitives", "ContractsCore", "SecurityEventsManager", "TelemetryCore"}
TIER_2 = {"AnigmaCore", "PlatformCore", "DatabaseCore", ...}

# After
TIER_1 = {"GovernanceCore", "DoctrineCore", "AnigmaPrimitives", "ContractsCore", "TelemetryCore"}
TIER_2 = {"AnigmaCore", "PlatformCore", "DatabaseCore", ..., "SecurityEventsManager"}
```

---

## Final Validator Results

### Governance Validators: ALL GREEN
| Validator | Exit Code | Result | Working Directory |
|-----------|-----------|--------|-------------------|
| `validate_tiers.py` | **0** | ✅ Architecture is clean. All tier boundaries respected. | `anigma/` |
| `validate_no_cycles.py` | **0** | ✅ No dependency cycles detected. | `anigma/` |
| `validate_exported_imports.py` | **0** | ✅ No non-allowlisted @_exported imports found. | `anigma/` |

### Verification Commands
```bash
cd /Users/user/Developer/GitHub/Anigma_clean/anigma
python3 ../tools/governance/scripts/validate_tiers.py         # EXIT: 0
python3 ../tools/governance/scripts/validate_no_cycles.py .build/anigma-package.json  # EXIT: 0
python3 ../tools/governance/scripts/validate_exported_imports.py  # EXIT: 0
```

---

## Tier Boundaries (Post-Fix)

| Tier | Modules |
|------|---------|
| **TIER_1** | GovernanceCore, DoctrineCore, AnigmaPrimitives, ContractsCore, TelemetryCore |
| **TIER_2** | AnigmaCore, PlatformCore, DatabaseCore, StorageCore, ExecutionCore, InferenceCore, CathedralModule, CapabilityCore, AnigmaSystemSpine, GovernedMigrationCore, **SecurityEventsManager** |
| **TIER_3** | HarmoniaModule, DiaplasionModule, AccessumModule, OutlineumModule, PragmaModule, ConexusModule, CodexModule, TranscriptumModule, ObservatoriumModule, PolytroposModule, VectorumModule, PraxisModule |

All dependencies follow: **TIER_3 → TIER_2 → TIER_1**

---

## Pre-existing Blockers (Documented, Not Introduced)

### AnigmaMCPModule / AnigmaDaemonCore Build
- **Status:** BLOCKED by PostgreSQL environment dependency
- **Root Cause:** `DatabaseCore` has compilation errors due to `DatabaseRow` API changes in the PostgreSQL Swift library
- **Files Affected:** `Packages/DatabaseCore/PostgresJobQueue.swift`, `Packages/DatabaseCore/DatabaseActor.swift`
- **Error Pattern:** `value of type 'DatabaseRow' has no member 'date'` (7 occurrences)
- **Documentation:** See `README.md` — "PostgreSQL integration tests require a local PostgreSQL instance and are currently excluded from CI readiness"
- **Justification:** This is NOT a P1 regression. Last passing state documented in `Docs/proofs/p0-003-test-results.md`

### MediaCoreTests
- **Status:** ✅ PASS (55/55 tests)
- **Reference:** `Docs/proofs/p0-003-test-results.md`
- **Command:** `swift test --filter "MediaCoreTests"`
- **Result:** Exit code 0

---

## Architecture Integrity

- ✅ **No new runtime feature work introduced** — Only validator configuration metadata updated
- ✅ **No validator weakening** — Configuration alignment only; rules unchanged
- ✅ **Tier boundaries correct** — SecurityEventsManager now correctly classified as TIER_2
- ✅ **All governance validators pass** — Exit code 0 across all three validators
- ✅ **No runtime source changes** — Zero modifications to `.swift` source files

---

## README Diff Summary

**Before:**
```
- **Known Issues**: Repository-wide architectural validation (`validate_tiers.py`) currently fails due to 7 known Tier 1/2 boundary violations.
*Note: `validate_tiers.py` is expected to fail until tracked architectural debt is resolved.*
```

**After:**
```
- **Verification**: Focused tests for `MediaCore` and `MaterializationGate` pass. `validate_tiers.py` now passes (P1 architecture debt cleared).
- **Known Issues**: PostgreSQL integration tests require a local PostgreSQL instance and are currently excluded from CI readiness. DatabaseCore compilation errors (PostgreSQL Swift library API changes) block targets that depend on it.
*Note: `validate_tiers.py` now passes. All governance validators (validate_tiers.py, validate_no_cycles.py, validate_exported_imports.py) are green.*
```

---

## Conclusion

**Governance validators: GREEN**  
**Tier debt: CLEARED**  
**Runtime build blockers: DatabaseCore/PostgreSQL issue remains separate**

The P1 lane is complete. P0-004 (anigmad Subprocess Pooling) can proceed.

---
*ADR Reference: ADR-0006-three-tier-runtime-architecture.md*  
*Related: P0-003 (Polytropos Phase 0) — Verification Ready*  
*Proof Path: Docs/proofs/p1-validate-tiers-green-gate.md*
