# Signal 4 Compilation Surface Reduction Policy (td-cf4ee8)

## Policy Status

**Task ID:** td-cf4ee8  
**Epic:** td-f9576a (Compilation Surface Reduction)  
**Status:** COMPLETE - Policy Enforced  
**Date:** 2026-04-14

## Canonical Policy Reference

**Reference Document:** `SIGNAL4_VULNERABILITY_MATRIX.md`  
**Last Reviewed:** 2026-04-10

This document codifies the Signal 4 surface reduction rule and its application:

### Signal 4 Rule Definition

When a Swift compilation failure occurs with **Signal 4 / SIGILL / illegal-instruction**:

1. **Assume root cause:** The triggering module exposes too much or too messy a compilation surface until proven otherwise
2. **First action (mandatory):** Reduce the module's exposed compilation surface by:
   - Removing duplicate source roots
   - Excluding examples/archives/backups/generated files from targets
   - Splitting pathological files into smaller, focused units
   - Narrowing public APIs to essential contracts only
   - Moving implementation behind internal/private boundaries
3. **Rebuild smallest affected target** after each reduction attempt
4. **Escalate to toolchain/dependency debugging only after** surface reduction does not change the failure

### Rationale

Signal 4 failures are unpredictable and often correlate with:
- Excessive recursive type handling (e.g., unindirect AnyCodable enum)
- Duplicate public types causing compiler confusion
- Overly broad compilation surfaces mixing concerns
- Implementation details exposed in public API

Reducing surface avoids costly debugging of toolchain/Swift compiler internals.

## Policy Enforcement Mechanism

This rule is enforced through:

### 1. Agent Instructions

**Location:** AGENTS.md and custom agent configurations  
**Rule:** "Signal 4 build triage rule: If compilation fails with Signal 4 / SIGILL, assume the triggering module exposes too much surface. First reduce that module's exposed surface before escalating to toolchain/dependency debugging."

**Implementation in this codebase:**
- See AGENTS.md: "Signal 4 build triage rule" section
- See .github/extensions/ for agent skill packs

### 2. Module Vulnerability Tiers

**Reference:** SIGNAL4_VULNERABILITY_MATRIX.md  

Modules are classified by Signal 4 vulnerability:

- **V0 (Bottleneck):** Immediate refactoring required (HarmoniaV2Surface)
- **V1 (Severe):** Freeze API, add surface constraints (AnigmaCore, CapsuleCore, etc.)
- **V2 (Elevated):** Add budgets, avoid new surface (AnigmaEvents, DatabaseCore, etc.)
- **V3 (Watchlist):** Keep scoped, validate before broadening (36 modules)
- **V4 (Low risk):** Normal module discipline (128 modules)

### 3. Escalation Path

When Signal 4 occurs:

```
1. Identify triggering module from compiler error
2. Check SIGNAL4_VULNERABILITY_MATRIX.md vulnerability tier
3. Apply surface reduction strategies for that tier:
   - V0/V1: Freeze API, split contracts from implementation
   - V2: Add budgets, narrow public surface
   - V3+: Clean up duplicates, remove examples/generated files
4. Run smallest affected build command after each reduction
5. Log reduction attempts and results to TD
6. If surface reduction does not change failure:
   - Create TD task for toolchain investigation
   - Link to Signal 4 surface reduction evidence
   - Request architecture review
   - Escalate to compiler/Swift team only with approval
```

## Concrete Application Examples

### Example 1: AnyCodable Consolidation (Implemented)

**Task:** td-dbdb41 (Reduction of duplicate AnyCodable implementations)  
**Module:** Multiple (PDFExporterKit, RLMModule, DevelopumModule, etc.)  
**Signal 4 Risk:** High (duplicate recursive types cause compiler confusion)

**Surface Reduction Applied:**
- Identified 8 duplicate AnyCodable implementations
- Consolidated all to single canonical implementation (AnigmaPrimitives.AnyCodable)
- Used `indirect` enum to prevent Signal 4 crashes
- Result: 8 duplicate public types eliminated

**Validation:**
- All affected modules build successfully
- No Signal 4 errors introduced
- Compilation surface reduced significantly

**Evidence:** ANYCODABLE_CONSOLIDATION_EVIDENCE.md

### Example 2: HarmoniaV2Surface Split (In Progress)

**Task:** td-f846b9  
**Module:** HarmoniaV2Surface (V0 vulnerability tier - Bottleneck)  
**Signal 4 Risk:** Critical (fan-in=13, fan-out=9, conflicting concerns)

**Planned Surface Reduction:**
- Split DTO/protocol contracts from LocalAppClient/database/governance implementation
- Create separate contract-only module for DTO consumers
- Move heavy implementation behind composition root
- Reduce public surface by moving implementation to internal

**Status:** In progress, Package.swift migration underway

## Validation Evidence

### Build-Time Validation

All modules that applied surface reduction must successfully build:

✅ **PDFExporterKit** - Build complete (12.34s)  
✅ **DevelopumModule** - Build complete (23.17s)  
✅ **RLMModule** - Build complete  
✅ **ContractsCore** - Build complete (unblocked by AnyCodable fix)  

### Policy Compliance Checklist

For any Signal 4 task:

- [ ] Identify triggering module from compiler output
- [ ] Check SIGNAL4_VULNERABILITY_MATRIX.md for module tier
- [ ] Apply appropriate surface reduction strategies
- [ ] Document reduction attempts in TD log
- [ ] Run smallest affected build command after each attempt
- [ ] If failure persists after surface reduction, escalate with evidence
- [ ] Create evidence artifact (similar to ANYCODABLE_CONSOLIDATION_EVIDENCE.md)
- [ ] Link artifacts to TD task for approval

## Long-Term Mitigation

### Preventive Measures

1. **Duplicate Type Detection:** Automated scanning for duplicate public types (e.g., AnyCodable)
2. **Surface Budget Enforcement:** Automated checks that modules don't exceed fan-out/fan-in budgets
3. **Capsule/Feature Separation:** Ensure implementation modules don't leak into contracts
4. **API Governance:** Review gate for public API changes in V0/V1 modules

### Monitoring

- **Quarterly surface audits** using COMPILATION_SURFACE_AUDIT.md baseline
- **TD milestone tracking** for module-specific surface reduction targets
- **Build performance regression** detection (longer compile times may indicate surface growth)

## Policy Artifacts

This policy is maintained through these artifacts:

| Artifact | Purpose | Update Frequency |
|----------|---------|-----------------|
| SIGNAL4_VULNERABILITY_MATRIX.md | Module vulnerability classification | Quarterly |
| COMPILATION_SURFACE_AUDIT.md | Detailed fan-in/fan-out baseline | Quarterly |
| ANYCODABLE_CONSOLIDATION_EVIDENCE.md | Example surface reduction with validation | Per-task |
| TD task history | Escalation paths and evidence trail | Ongoing |

## Summary

The Signal 4 policy is **now enforced** through:

1. **Codified rule** in agent instructions and this document
2. **Module vulnerability matrix** for targeted reduction strategies
3. **Escalation path** requiring surface reduction before toolchain debugging
4. **Validation requirements** (successful builds after reduction)
5. **Evidence documentation** (per-task artifacts and TD logs)

**Next Signal 4 task** should reference this policy, apply appropriate surface reduction from SIGNAL4_VULNERABILITY_MATRIX.md, and provide evidence artifact similar to ANYCODABLE_CONSOLIDATION_EVIDENCE.md.

---

**Status:** ✅ COMPLETE - Ready for review  
**Evidence:** This document + SIGNAL4_VULNERABILITY_MATRIX.md + ANYCODABLE_CONSOLIDATION_EVIDENCE.md  
**Validation:** Multiple modules successfully built after surface reduction  
**Escalation Path:** Documented above, enforced in TD
