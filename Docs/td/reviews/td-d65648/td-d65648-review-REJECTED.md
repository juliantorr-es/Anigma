# REVIEW REJECTED: td-d65648 ReceiptSigner Extraction

**Reviewer**: Mistral Vibe  
**Date**: 2026-05-03  
**Task**: td-d65648 - Extract ReceiptSigner to Tier 1 Evidence Contract Surface  
**Decision**: **REJECT** - Critical Blocker Found  

---

## Executive Summary

The **architectural extraction** of ReceiptSigner from ExecutionCore to EvidenceContracts is **correct and well-executed**. The protocol is properly placed in Tier 1, no new dependency cycles or tier violations were introduced, and the compatibility bridge in ExecutionCore is appropriate.

However, **the implementation cannot be accepted** because EvidenceAuthorityImpl.swift was added with compilation errors that block the build. This file must be fixed before td-d65648 can be marked DONE.

---

## Review Checklist

### ✅ PASS: ReceiptSigner Contract Purity

| Check | Status | Evidence |
|-------|--------|----------|
| Protocol in EvidenceContracts | ✅ PASS | `anigma/Packages/ContractsCore/Sources/EvidenceContracts/EvidenceContracts.swift:586-595` |
| No implementation logic | ✅ PASS | Pure protocol definition only |
| No ExecutionCore types | ✅ PASS | Only uses `Data`, `String`, `Sendable` |
| No AnigmaCore types | ✅ PASS | No dependencies on AnigmaCore |
| No Apple/platform types | ✅ PASS | Only Foundation types |
| No database/daemon/runtime types | ✅ PASS | Contract is portable |

### ✅ PASS: ExecutionCore Compatibility Bridge

| Check | Status | Evidence |
|-------|--------|----------|
| ExecutionCore+Exports.swift exists | ✅ PASS | File present |
| ReceiptSigner typealias is intentional | ✅ PASS | `public typealias ReceiptSigner = EvidenceContracts.ReceiptSigner` |
| Typealias is documented | ✅ PASS | Comment explains move to break cycle |
| Import EvidenceContracts added | ✅ PASS | Line 11: `import EvidenceContracts` |
| Canonical imports preferred | ✅ PASS | New code should use EvidenceContracts directly |

### ✅ PASS: Mock Usage Audit

| Check | Status | Evidence |
|-------|--------|----------|
| EvidenceAuthorityImpl.swift uses ReceiptSigner | ✅ PASS | `signer: any ReceiptSigner` at line 23 |
| MockReceiptSigner exists in PlatformRuntime | ✅ PASS | Lines 912-926 |
| Mock is test/bootstrap-safe | ✅ PASS | Uses BLAKE3Digest from AnigmaPrimitives |
| TODO markers present | ✅ PASS | `// TODO: td-d65648 - Replace with injected DefaultReceiptSigner` |

### ❌ FAIL: Build Validation

| Check | Status | Evidence |
|-------|--------|----------|
| swift build --target AnigmaFoundation | ❌ FAIL | Compilation errors in EvidenceAuthorityImpl.swift |
| swift build --target AnigmaDaemonCore | ❌ FAIL | Blocked by AnigmaFoundation errors |
| swift build --target ExecutionCore | ✅ PASS | ExecutionCore compiles correctly |

### ✅ PASS: Architecture Validation

| Check | Status | Evidence |
|-------|--------|----------|
| No dependency cycle introduced | ✅ PASS | Manual analysis of Package.swift |
| No new tier violations | ✅ PASS | validate_tiers.py: only pre-existing SecurityEventsManager -> DatabaseCore |
| validate_tiers.py runs | ✅ PASS | 1 unrelated violation only |
| ReceiptSigner canonical home is EvidenceContracts | ✅ PASS | Tier 1 contract |

---

## Critical Findings

### BLOCKER: EvidenceAuthorityImpl.swift Compilation Errors

**File**: `anigma/Packages/AnigmaCore/Sources/AnigmaFoundation/Runtime/EvidenceAuthorityImpl.swift`  
**Status**: NEW FILE (untracked in git) with compilation errors  
**Impact**: BLOCKS AnigmaFoundation and AnigmaDaemonCore builds  

#### Errors Found:

1. **Syntax Error** (LINE 382) - FIXED
   - Orphaned `)` and code block after `storeReceipt` function
   - Fixed by removing corrupted lines 382-393

2. **Undefined Symbol Errors**:
   - Line 106: `cannot find 'emitGovernanceEvent' in scope`
   - Line 201: `cannot find 'emitGovernanceEvent' in scope`
   - Line 139: `cannot find 'convertRowToEvidenceBundle' in scope`

3. **Type Errors**:
   - Multiple issues with stubbed functions
   - Incomplete type conformance and references

#### Root Cause:

This file appears to be a work-in-progress implementation that was committed with incomplete code. It was created as part of the ReceiptSigner extraction to provide a concrete EvidenceAuthority implementation, but it contains stubbed functions and references to undefined symbols.

---

## EvidenceAuthorityImpl.swift Fix Required

### Immediate Actions:

1. **Remove or implement `emitGovernanceEvent`**
   - Either import the correct module that defines this function
   - Or remove all calls to this function

2. **Remove or implement `convertRowToEvidenceBundle`**
   - This function doesn't exist anywhere in the codebase
   - Either implement it or remove its usage

3. **Complete all stubbed functions**
   - `createUnifiedEvidenceReceipt`
   - `signReceipt`
   - `storeReceipt`
   - `validateCryptographicChain`
   - `validateTemporalConsistency`

4. **Ensure all types compile**
   - Verify all referenced types exist
   - Ensure all protocol conformances are complete

---

## Dependency Graph Verification

### Before Extraction (BLOCKED):
```
AnigmaFoundation → ExecutionCore (BLOCKED: creates cycle)
ExecutionCore → AnigmaCore
AnigmaCore → AnigmaFoundation
Cycle: AnigmaFoundation → ExecutionCore → AnigmaCore → AnigmaFoundation ❌
```

### After Extraction (RESOLVED):
```
AnigmaFoundation → EvidenceContracts (Tier 1) ✓
EvidenceContracts → FoundationContracts + GovernanceContracts + AnigmaPrimitives (all Tier 1) ✓
ExecutionCore → ContractsCore (includes EvidenceContracts) ✓
AnigmaFoundation does NOT transitively depend on ExecutionCore ✓
No cycle: AnigmaFoundation → ... → ExecutionCore → ... → AnigmaFoundation ✓
```

---

## Update: EvidenceAuthorityImpl.swift

I fixed one syntax error (orphaned code block) during review. The file now has fewer errors but still contains multiple compilation-blocking issues including:
- References to undefined `emitGovernanceEvent` function
- References to undefined `convertRowToEvidenceBundle` function  
- Incomplete stub implementations

These must be addressed before the build can pass.

---

## Files Changed (Architectural Changes - CORRECT)

1. **EvidenceContracts/EvidenceContracts.swift** - Added ReceiptSigner protocol ✓
2. **ExecutionCore/ExecutionCore+Exports.swift** - Added typealias and import ✓
3. **ExecutionCore/ReceiptTypes.swift** - Removed protocol, added comment ✓
4. **Package.swift** - Added ContractsCore dependency to ExecutionCore ✓
5. **PlatformRuntime.swift** - Added MockReceiptSigner ✓
6. **EvidenceAuthorityImpl.swift** - Added but **HAS COMPFILES ERRORS** ❌

---

## Acceptance Criteria Status

| Criterion | Status | Evidence |
|----------|--------|----------|
| ReceiptSigner canonical home is EvidenceContracts | ✅ DONE | Correctly placed in Tier 1 |
| No dependency cycle reintroduced | ✅ DONE | Manual analysis confirms |
| No Tier 1 pollution | ✅ DONE | ReceiptSigner uses only portable types |
| No fake production implementation introduced | ✅ DONE | MockReceiptSigner is clearly marked as mock |
| BackendReadiness advances past ReceiptSigner-related errors | ❌ BLOCKED | EvidenceAuthorityImpl.swift compilation errors |

---

## Final Decision: REJECT

**td-d65648 CANNOT be marked DONE** until EvidenceAuthorityImpl.swift is fixed and the builds pass.

### Reason:
The architectural extraction is correct, but the dependent implementation code was added with compilation errors that prevent the targets from building. A TD cannot be completed with broken builds.

### Next Steps:

1. **Fix EvidenceAuthorityImpl.swift** - Remove undefined symbols or implement missing functions
2. **Verify all builds pass**:
   - `swift build --target AnigmaFoundation` - Must succeed
   - `swift build --target AnigmaDaemonCore` - Must succeed
   - `swift build --target ExecutionCore` - Must succeed (already does)
3. **Re-run validation**:
   - `python3 tools/governance/scripts/validate_tiers.py`
   - Confirm no new violations
4. **Update proof artifact** with passing validation results
5. **Re-submit for review**

### Documentation Updated:

- ✅ Proof artifact updated: `Docs/proofs/td-d65648-receiptsigner-extraction-proof.md`
  - Added actual validation results (including failures)
  - Documented critical blocker
  - Updated acceptance criteria status
  - Updated conclusion to reflect REJECT decision

---

## Summary

| Aspect | Status |
|--------|--------|
| Architecture | ✅ CORRECT |
| Dependency Management | ✅ CORRECT |
| Contract Purity | ✅ CORRECT |
| Build Health | ❌ BROKEN |
| Documentation | ✅ UPDATED |
| **Overall** | **❌ REJECT** |

The ReceiptSigner extraction is architecturally sound but **implementation is incomplete**. Code that uses the extracted contract has compilation errors that must be fixed before acceptance.
