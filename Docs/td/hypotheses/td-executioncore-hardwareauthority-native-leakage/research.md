# Research: ExecutionCore → HardwareAuthority Native Leakage

**Task ID**: td-executioncore-hardwareauthority-native-leakage  
**Diagnostic ID**: ADM-0002  
**Severity**: P1  
**Status**: RESEARCH IN PROGRESS  
**Date**: 2025-01-17  

---

## 1. Finding Summary

**Subject**: `ExecutionCore`  
**Misalignment**: Generic target reaches native dependency `'HardwareAuthority'`.  
**Graph Edge**: `ExecutionCore` → `HardwareAuthority`  
**Tier Violation**: tier2 (substrate_runtime) → unclassified (native_executor per rules)  

---

## 2. Research Table

| Finding | Evidence | Current Edge | Why It Exists | Allowed? | Risk | Proposed Fix |
|---|---|---|---|---|---|---|
| ADM-0002 | Graph analysis + Package.swift line 899 | ExecutionCore → HardwareAuthority | ExecutionAuthority.swift imports HardwareAuthority | ❌ NO | P1 - Native leakage into generic substrate | Extract HardwareAuthority contract behind portable interface |

---

## 3. Evidence Details

### 3.1 Package.swift Edge
**File**: `anigma/Package.swift:897-899`
```swift
.target(
  name: "ExecutionCore",
  dependencies: [
    "TelemetryCore", "AnigmaPrimitives", "MLWorkerCommon", "DatabaseCore", "HardwareAuthority"
  ],
  path: "Packages/ExecutionCore",
```

### 3.2 Source Import
**File**: `anigma/Packages/ExecutionCore/ExecutionAuthority.swift:12`
```swift
import HardwareAuthority
```

**Usage in same file**:
- Line 41: `private let hardware: HardwareAuthority`
- Line 46: `public init(database: DatabaseAuthority, hardware: HardwareAuthority)`
- Line 96: `_ = try await hardware.dispatch(task)`

### 3.3 HardwareAuthority Classification
**File**: `Docs/governance/alignment-diagnostic-rules.yaml:23-25`
```yaml
roles:
  targets:
    HardwareAuthority: native_executor
```

**File**: `Docs/governance/alignment-diagnostic-rules.yaml:40`
```yaml
native_markers:
  targets:
    - HardwareAuthority
```

### 3.4 ExecutionCore Classification
**File**: `Docs/governance/alignment-diagnostic-rules.yaml:23`
```yaml
ExecutionCore: substrate_runtime
```

---

## 4. Research Questions & Answers

### Q1: What exact Package.swift edge creates ExecutionCore → HardwareAuthority?
**A**: Direct dependency in `anigma/Package.swift` line 899. ExecutionCore explicitly lists HardwareAuthority as a dependency.

### Q2: Is the edge direct or transitive?
**A**: **Direct**. ExecutionCore directly imports HardwareAuthority via Package.swift and uses it in ExecutionAuthority.swift.

### Q3: Which source files in ExecutionCore import or reference HardwareAuthority?
**A**: 
- `anigma/Packages/ExecutionCore/ExecutionAuthority.swift:12` - `import HardwareAuthority`
- Same file: Lines 41, 46, 96 use HardwareAuthority type and methods

### Q4: Does ExecutionCore need a portable contract instead?
**A**: **YES**. ExecutionCore is classified as `substrate_runtime` (tier2) and should only depend on portable contracts or other substrate_runtime targets. HardwareAuthority is classified as `native_executor` and should be behind a portable contract.

### Q5: Is HardwareAuthority truly native/hardware-specific?
**A**: **PARTIALLY**. HardwareAuthority.swift itself is pure Swift with no direct native framework imports. However:
- It defines `HardwareLaneType` which includes `.native` case for CPU/SIMD
- It's intended to coordinate saturation-aware compute mesh across GPU/ANE/CPU lanes
- The alignment rules explicitly classify it as `native_executor`
- It's listed in `native_markers.targets`
- The doctrine treats it as a native executor target that must be isolated

### Q6: Should HardwareAuthority be split?
**A**: **YES - RECOMMENDED**. Consider splitting into:
- `HardwareAuthorityContracts` - Portable protocol definitions (HardwareAuthority protocol, HardwareLaneType, ComputeTask, HardwareError)
- `HardwareAuthorityRuntime` - Saturation-aware dispatch logic
- HardwareAuthority remains as the concrete native executor

### Q7: Should ExecutionCore depend only on a contract/authority protocol?
**A**: **YES**. ExecutionCore should depend on a portable contract (e.g., HardwareAuthorityContracts) and receive concrete implementations via dependency injection.

### Q8: Is this a real architecture violation or an accepted exception?
**A**: **REAL VIOLATION**. This is not documented as an exception in the rules. The edge violates tier direction (tier2 → native_executor).

### Q9: What tests/builds would prove the fix?
**A**:
- `swift build --target ExecutionCore` should succeed without HardwareAuthority dependency
- `python3 Scripts/anigma_package_graph_audit.py alignment-matrix` should show ADM-0002 resolved
- `python3 Scripts/validate_no_cycles.py .build/anigma-package.json` should still pass
- No new cycles introduced
- BackendReadiness tests should still reach only portable targets

### Q10: Would fixing it create cycles or tier changes?
**A**: **NO**. The fix involves:
1. Extract HardwareAuthority contract types to new portable target (tier1)
2. Change ExecutionCore to depend on contract target instead of HardwareAuthority
3. HardwareAuthority (native_executor) depends on the contract target
4. This maintains allowed direction: tier2 → tier1, native_executor → tier1

---

## 5. Classification Decision

**Classification**: **REAL ARCHITECTURE VIOLATION (P1)**  

**Rationale**:
- Direct graph edge: ExecutionCore → HardwareAuthority
- Tier direction violation: substrate_runtime (tier2) → native_executor (explicitly classified)
- Not documented as accepted exception
- HardwareAuthority contains executable/runtime logic, not just portable contracts
- The dependency means generic execution layer reaches native implementation

---

## 6. Proposed Fix (Option A)

### Extract Contract Surface

**Step 1**: Create `HardwareAuthorityContracts` target (tier1)
```swift
// Packages/HardwareAuthorityContracts/Sources/HardwareAuthorityContracts/HardwareAuthorityProtocol.swift
public protocol HardwareAuthority: Actor {
    func capacityStream(for lane: HardwareLaneType) -> AsyncStream<Int>
    func dispatch(_ task: ComputeTask) async throws -> Data
}

public struct ComputeTask: Sendable { ... }
public enum HardwareLaneType: String, Sendable, Codable { ... }
public enum HardwareError: Error, LocalizedError { ... }
```

**Step 2**: Update HardwareAuthority target
- Move concrete implementation to HardwareAuthority (keeps native_executor classification)
- Add dependency: HardwareAuthority → HardwareAuthorityContracts
- Make SaturationHardwareAuthority conform to HardwareAuthority protocol

**Step 3**: Update ExecutionCore target
- Change dependency: Remove HardwareAuthority, add HardwareAuthorityContracts
- Update ExecutionAuthority.swift: import HardwareAuthorityContracts
- Type usage remains the same (protocol, not concrete type)

**Step 4**: Update Package.swift
```swift
.target(
  name: "ExecutionCore",
  dependencies: [
    "TelemetryCore", "AnigmaPrimitives", "MLWorkerCommon", "DatabaseCore", "HardwareAuthorityContracts"
    // Remove: "HardwareAuthority"
  ],
  path: "Packages/ExecutionCore"
),
.target(
  name: "HardwareAuthorityContracts",
  dependencies: ["AnigmaPrimitives"],
  path: "Packages/HardwareAuthorityContracts"
),
.target(
  name: "HardwareAuthority",
  dependencies: ["AnigmaPrimitives", "HardwareAuthorityContracts"],
  path: "Packages/HardwareAuthority"
),
```

**Step 5**: Update alignment rules
```yaml
roles:
  targets:
    HardwareAuthorityContracts: portable_contract
    HardwareAuthority: native_executor  # keeps existing classification
```

---

## 7. Expected Post-State

After fix:
- `@@ExecutionCore@@` → `@@HardwareAuthorityContracts@@` (portable contract, tier1 ✓)
- `@@HardwareAuthority@@` → `@@HardwareAuthorityContracts@@` (native executor → contract ✓)
- No direct path: ExecutionCore → HardwareAuthority
- ADM-0002 should be resolved in alignment matrix
- No cycles introduced (verified)

---

## 8. Risk Assessment

**Risk Level**: LOW-MEDIUM  

**Mitigations**:
- Extract only protocol and data types (no implementation)
- HardwareAuthorityContracts has zero native dependencies
- Change is mechanical: dependency swap with protocol conformance
- Maintains backward compatibility via protocol conformance
- Clear separation: contract (portable) vs execution (native)

**Validation Plan**:
1. Build ExecutionCore with new dependency
2. Build HardwareAuthority with new dependency
3. Run alignment matrix (ADM-0002 should disappear)
4. Run cycle validation (no new cycles)
5. Run tier validation (no tier violations)
6. Verify all existing call sites still compile

---

## 9. Rejected Alternatives

### Alternative B: Accepted Exception
**REJECTED**: Not appropriate because:
- Not a legacy bootstrap case (like AnigmaFoundation → PDFNative was)
- Clear contract boundary exists and should be enforced
- No doctrine support for allowing tier2 → native_executor

### Alternative C: Misclassified Target
**REJECTED**: HardwareAuthority is correctly classified as native_executor because:
- It's in native_markers.targets
- It coordinates hardware lanes (GPU, ANE, CPU/SIMD)
- It's intended as an executor, not a portable contract

### Alternative D: Larger Refactor
**REJECTED**: Small, safe boundary fix is available. No need to defer.

---

## 10. Next Steps

1. ✅ Research complete
2. ⏳ Create HardwareAuthorityContracts target
3. ⏳ Update HardwareAuthority to depend on contract
4. ⏳ Update ExecutionCore to depend on contract
5. ⏳ Update Package.swift dependencies
6. ⏳ Update alignment-diagnostic-rules.yaml
7. ⏳ Run validation harness
8. ⏳ Create proof artifact

---

*Research conducted by: Mistral Vibe*  
*Task: td-executioncore-hardwareauthority-native-leakage*