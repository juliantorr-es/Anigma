# Three-Tier Architecture Migration Roadmap

**Status:** Phase 1 Complete ✅
**Date:** 2026-01-08

## Overview

This document tracks the migration from the current two-tier architecture to the new three-tier architecture defined in ADR-0006.

## Phase 1: Create Runtime Skeleton ✅ COMPLETE

**Goal:** Add PlatformRuntime and authorities as wrappers around existing infrastructure.

**Completed:**
- ✅ Created `ADR-0006: Three-Tier Runtime Architecture`
- ✅ Created `AnigmaCore/Runtime/RuntimeTypes.swift` (Principal, ExecutionContext, Receipt, etc.)
- ✅ Created `AnigmaCore/Runtime/Authorities.swift` (Authority protocols)
- ✅ Created `AnigmaCore/Runtime/PlatformRuntime.swift` (Main runtime actor)
- ✅ Created `AnigmaCore/Runtime/AuthorityImplementations.swift` (Phase 1 implementations)
- ✅ Created `AnigmaCore/Runtime/ExampleModuleRegistration.swift` (Documentation)
- ✅ Updated `CLAUDE.md` to reflect three-tier architecture

**What works now:**
- PlatformRuntime can be instantiated
- Authorities wrap existing infrastructure (DatabaseActor, etc.)
- No breaking changes to existing code (backwards compatible)
- Example module shows registration pattern

**Files Created:**
```
Packages/AnigmaCore/Runtime/
├── RuntimeTypes.swift
├── Authorities.swift
├── PlatformRuntime.swift
├── AuthorityImplementations.swift
└── ExampleModuleRegistration.swift

Docs/ADR/
└── 0006-three-tier-runtime-architecture.md
```

## Phase 2: Wire Governance (Next Steps)

**Goal:** Enforce governance in authority mutation paths.

**Status:** NOT STARTED

**Tasks:**
1. [ ] Verify `DatabaseAuthority.mutate()` governance checks work
2. [ ] Add integration tests for KillSwitch enforcement
3. [ ] Add integration tests for WriteGate enforcement
4. [ ] Update one module (HarmoniaModule) to use DatabaseAuthority
5. [ ] Prove governance enforcement works end-to-end

**Success Criteria:**
- KillSwitch.activate() actually blocks mutations
- WriteGate.evaluate() runs before every mutation
- HarmoniaModule cannot bypass governance (compile-time + runtime)
- Audit log shows governance decisions

**Estimated Effort:** 2-3 days

## Phase 3: Migrate Modules (After Phase 2)

**Goal:** Move all capability modules to use runtime authorities.

**Status:** NOT STARTED

**Priority Order:**
1. [ ] **HarmoniaModule** (largest, most complex - proof of concept)
   - Migrate session management to use DatabaseAuthority
   - Consolidate evidence recording into EvidenceAuthority
   - Update workflows to receive ExecutionContext
   - Remove direct DatabaseActor usage

2. [ ] **CathedralModule** (consolidate into EvidenceAuthority)
   - Merge Cathedral evidence storage into EvidenceAuthority
   - Migrate existing evidence to new schema
   - Update ML operation evidence recording

3. [ ] **DiaplasionModule** (document processing)
   - Register schemas with runtime
   - Use DatabaseAuthority for document metadata
   - Use ArtifactAuthority for processed documents

4. [ ] **AccessumModule**, **OutlineumModule**, **ContextumModule**, etc.
   - Apply same pattern to remaining ~12 modules

**Success Criteria:**
- All modules use `PlatformRuntime` APIs
- Zero direct `DatabaseActor.execute()` calls in capability modules
- Evidence is unified in EvidenceAuthority
- All schemas registered via `runtime.registerSchema()`

**Estimated Effort:** 2-3 weeks (distributed over modules)

## Phase 4: Update App Shells (After Phase 3)

**Goal:** App shells create and own the PlatformRuntime.

**Status:** NOT STARTED

**Tasks:**
1. [ ] Update `AnigmaDaemon` to host runtime
   - Create runtime in main()
   - Register all modules
   - Expose runtime via gRPC for clients

2. [ ] Update `AnigmaAppMac` to create single runtime
   - Create runtime in App.init()
   - Register all modules
   - Pass runtime to views via environment

3. [ ] Update `HarmoniaCLI` to use runtime
   - For local mode: create runtime
   - For remote mode: connect to daemon runtime via gRPC

4. [ ] Add runtime lifecycle management
   - Graceful shutdown on app termination
   - Error handling for initialization failures
   - Health checks for runtime status

**Success Criteria:**
- ONE runtime per app instance (verifiable via status API)
- All work flows through the runtime (no direct module usage)
- Multi-platform ready (same runtime contract everywhere)

**Estimated Effort:** 1 week

## Phase 5: Cleanup and Lockdown (After Phase 4)

**Goal:** Remove escape hatches, enforce architecture.

**Status:** NOT STARTED

**Tasks:**
1. [ ] Make `DatabaseActor.execute()` internal (not public)
   - Only accessible to DatabaseAuthority
   - Compile-time enforcement of governance

2. [ ] Remove duplicate evidence systems
   - Remove `ReceiptEngine` (consolidated into EvidenceAuthority)
   - Remove `HarmoniaModule.EvidenceRecorder`
   - Migrate existing evidence data

3. [ ] Add architecture tests
   - Test: Modules cannot import DatabaseCore
   - Test: Direct DatabaseActor usage fails to compile
   - Test: KillSwitch blocks all mutations

4. [ ] Update all documentation
   - Update CLAUDE.md examples
   - Create migration guide for future modules
   - Update README with new architecture

5. [ ] Add runtime observability
   - Metrics: mutation rate, evidence recording rate
   - Monitoring: governance decision distribution
   - Alerts: Kill switch activation

**Success Criteria:**
- Modules CANNOT bypass runtime (compile-time + runtime enforcement)
- Architecture tests pass in CI/CD
- Documentation matches implementation (100% accuracy)
- Observability dashboard shows runtime health

**Estimated Effort:** 1 week

## Migration Checklist (Per Module)

Use this checklist when migrating a module from direct access to runtime authorities:

### Pre-Migration
- [ ] Audit module for direct `DatabaseActor` usage (grep for `dbActor.execute`)
- [ ] Audit module for evidence recording (grep for `ReceiptEngine`, `EvidenceStore`)
- [ ] Identify all database tables created by module
- [ ] List all workflows that need `ExecutionContext`

### Migration
- [ ] Create `ModuleSchema` definitions for all tables
- [ ] Add `register(runtime:)` static method
- [ ] Update workflows to accept `ExecutionContext` parameter
- [ ] Replace `dbActor.execute()` with `runtime.database.mutate()`
- [ ] Replace evidence recording with `runtime.evidence.record()`
- [ ] Update tests to use `PlatformRuntime.testing()`

### Verification
- [ ] Build succeeds (no direct DatabaseActor imports)
- [ ] Tests pass (runtime enforces governance)
- [ ] Evidence appears in unified schema
- [ ] KillSwitch blocks mutations when activated
- [ ] Audit log shows governance decisions

### Cleanup
- [ ] Remove direct DatabaseActor references
- [ ] Remove module-specific evidence tables
- [ ] Update module documentation

## Current Architecture Status

### What Works (Phase 1)
✅ PlatformRuntime can be instantiated
✅ Authorities delegate to existing infrastructure
✅ Governance primitives exist (KillSwitch, WriteGate)
✅ Example module shows registration pattern
✅ Documentation matches implementation

### What's Missing (Phase 2+)
❌ Governance NOT enforced in production code
❌ Evidence still fragmented across 3 systems
❌ Modules still use direct DatabaseActor access
❌ No shared World instance in production
❌ Architecture not enforced (modules can bypass)

## Success Metrics (End State)

When migration is complete, these metrics should be:

1. **Governance Enforcement:** 100% of mutations pass through WriteGate and KillSwitch
2. **Evidence Unification:** All evidence stored in EvidenceAuthority (one schema)
3. **Module Compliance:** 0 direct `DatabaseActor.execute()` calls in capability modules
4. **Architecture Tests:** 100% pass rate (cannot bypass runtime)
5. **Multi-Platform Readiness:** Same `PlatformRuntime` contract works on macOS, iOS, web

## Rollback Plan

If migration causes production issues:

1. **Phase 2-3:** Can rollback individual modules (keep both old and new code paths)
2. **Phase 4:** Can revert app shells to direct module usage
3. **Phase 5:** CANNOT rollback once old APIs are removed (point of no return)

**Recommendation:** Complete Phase 2-4 before Phase 5 to maintain rollback option.

## Timeline Estimate

| Phase | Estimated Duration | Dependencies |
|-------|-------------------|--------------|
| Phase 1 | ✅ Complete (1 day) | None |
| Phase 2 | 2-3 days | Phase 1 |
| Phase 3 | 2-3 weeks | Phase 2 |
| Phase 4 | 1 week | Phase 3 |
| Phase 5 | 1 week | Phase 4 |
| **Total** | **4-6 weeks** | Sequential |

**Risk Factors:**
- Module migration may uncover unexpected dependencies
- Evidence data migration may require custom tooling
- Multi-platform testing may reveal iOS-specific issues
- Governance enforcement may impact performance (measure!)

## Next Steps (Immediate)

To start Phase 2, run:

```bash
# 1. Build the project with new runtime
swift build

# 2. Run tests to establish baseline
swift test

# 3. Create governance integration tests
# Tests/AnigmaCoreTests/Runtime/GovernanceEnforcementTests.swift

# 4. Migrate one module (HarmoniaModule) as proof-of-concept
# Packages/HarmoniaModule/HarmoniaModule.swift
```

## Questions / Decisions Needed

- [ ] **Performance:** Should we measure governance overhead before Phase 5? (Recommendation: Yes)
- [ ] **Evidence Migration:** How do we migrate existing evidence from Cathedral/ReceiptEngine to unified schema? (Recommendation: Write migration script)
- [ ] **Multi-Platform:** Should we target iOS in Phase 4 or later? (Recommendation: Phase 4 - same contract, different UI)
- [ ] **Observability:** What metrics should we track? (Recommendation: mutation rate, governance decision rate, evidence recording rate)

## References

- **ADR-0006:** Three-Tier Runtime Architecture (full specification)
- **CLAUDE.md:** Updated architecture documentation
- **ExampleModuleRegistration.swift:** Pattern for module migration
- **Backend Integration Analysis (2026-01-08):** Original analysis that motivated this migration

---

**Maintained By:** Claude Code + User
**Last Updated:** 2026-01-08
**Status:** Phase 1 Complete, Phase 2 Ready to Start
