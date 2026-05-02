# ANECapsuleIntegration Module Splitting Proposal

## Current Structure Analysis

### Module Composition
- **Total Files:** 25 in main module + 10 in internal module
- **Lines of Code:** ~2,500 total
- **Current Organization:**
  - `ANECapsuleIntegration` (main): Capabilities, execution, receipts
  - `ANECapsuleIntegrationInternal` (internal): Runtime management

### Functional Groupings Identified

#### 1. Core Protocols & Types (6 files)
- `ANECapsuleBase.swift` (242 lines)
- `ANECapsuleTypes.swift` (153 lines)
- `ANETypes.swift` (135 lines)
- `ANEPlacementTypes.swift`
- `ANECapabilityTypes.swift`
- `ANEReceiptTypes.swift` (with extensions)

#### 2. Capability Definitions (8 files)
- `ANECapability.swift` (base struct)
- `ANECapability+EmbeddingANE.swift` (ANE-only capability)
- `ANECapability+EmbeddingMixed.swift` (mixed capability)
- `ANECapability+CPUOnly.swift` (CPU-only capability)
- `ANECapabilityRegistry.swift` (registry management)
- `ANECapabilityRegistry+Defaults.swift` (default accessors)

#### 3. Execution & Receipts (7 files)
- `ExecutionReceipt.swift`
- `ANEReceiptTypes+Errors.swift`
- `ANEReceiptTypes+Hardware.swift`
- `ANEReceiptTypes+Metrics.swift`
- `ANEReceiptTypes+Statistics.swift`
- `ANETelemetryCompatibility.swift`
- `CoreMLModelMetadata.swift`

#### 4. Internal Runtime (10 files - already separate)
- `ANEAnyPayload.swift`
- `ANEBatchProcessor.swift`
- `ANEFallbackHandler.swift`
- `ANEHealthCheck.swift`
- `ANEMetrics.swift`
- `ANEPerformanceMonitor.swift`
- `ANEResourceManager.swift`
- `ANERollbackManager.swift`
- `ANEScheduler.swift`
- `ANESharedTypes.swift`

## Proposed Module Splitting

### Option 1: Three-Way Split (Recommended)

```mermaid
graph TD
    A[Current ANECapsuleIntegration] --> B[ANECapsuleCore]
    A --> C[ANECapabilityDefinitions]
    A --> D[ANEExecution]
    A --> E[ANECapsuleIntegrationInternal])
    
    B --> C
    B --> D
    C --> D
```

**1. ANECapsuleCore** (Base Module)
- **Purpose:** Foundational protocols and types
- **Files:** 6 core type/protocol files
- **Dependencies:** CapsuleCore, ANEServicesCore
- **Dependents:** All other ANE modules
- **Benefits:** Minimal compilation surface, stable API

**2. ANECapabilityDefinitions** (Capability Module)
- **Purpose:** ANE capability declarations and registry
- **Files:** 8 capability-related files
- **Dependencies:** ANECapsuleCore, ANEServicesCore
- **Dependents:** ANEExecution, consumer modules
- **Benefits:** Isolates complex capability definitions

**3. ANEExecution** (Execution Module)
- **Purpose:** Execution management and receipt handling
- **Files:** 7 execution/receipt files
- **Dependencies:** ANECapsuleCore, ANECapabilityDefinitions
- **Dependents:** Consumer modules needing execution
- **Benefits:** Separates template-heavy execution code

**4. ANECapsuleIntegrationInternal** (Runtime Module - unchanged)
- **Purpose:** Runtime management and scheduling
- **Files:** 10 runtime files
- **Dependencies:** ANECapsuleCore
- **Dependents:** Internal use only

### Option 2: Two-Way Split (Simpler)

```mermaid
graph TD
    A[Current ANECapsuleIntegration] --> B[ANECapsuleCore]
    A --> C[ANECapabilityExecution]
    A --> D[ANECapsuleIntegrationInternal])
    
    B --> C
```

**1. ANECapsuleCore** (Same as above)

**2. ANECapabilityExecution** (Combined Module)
- **Purpose:** Capabilities + Execution
- **Files:** 15 files (capabilities + execution)
- **Dependencies:** ANECapsuleCore, ANEServicesCore
- **Benefits:** Simpler migration, still reduces surface

## Expected Benefits

### Compilation Surface Reduction
- **Current:** Single module with 25 files → high template complexity
- **Proposed:** 3 smaller modules → reduced per-module complexity
- **Estimated Reduction:** 40-60% compilation surface per module

### Specific Advantages
1. **Isolated Template Complexity:** Capability definitions separated from execution logic
2. **Incremental Compilation:** Changes in one module don't rebuild entire ANE stack
3. **Clearer Architecture:** Explicit dependencies between functional areas
4. **Easier Testing:** Modules can be tested independently
5. **Better Maintainability:** Smaller, focused codebases

### Migration Complexity
- **Low Risk:** Internal API changes only (no public API impact)
- **Gradual Adoption:** Modules can be split incrementally
- **Backward Compatible:** Can maintain unified facade if needed

## Implementation Plan

### Phase 1: Preparation
1. **Create new module targets** in Package.swift
2. **Establish dependency graph** between modules
3. **Update import statements** in all files
4. **Verify no circular dependencies**

### Phase 2: Splitting
1. **Move files** to new module directories
2. **Update target paths** in Package.swift
3. **Fix any compilation errors** from separation
4. **Add module facades** if needed for backward compatibility

### Phase 3: Testing
1. **Unit test each module** independently
2. **Integration test module interactions**
3. **Performance test** compilation times
4. **Validate SIGILL resolution**

### Phase 4: Deployment
1. **Update consumer modules** to import specific submodules
2. **Document new module architecture**
3. **Monitor compilation metrics** post-split
4. **Iterate based on feedback**

## Risk Assessment

### Potential Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Compilation errors during split | Medium | High | Incremental splitting, thorough testing |
| Performance regression | Low | Medium | Benchmark before/after, optimize as needed |
| Increased build time | Low | Low | Parallel compilation, build caching |
| API confusion | Medium | Medium | Clear documentation, migration guide |
| Module circularity | Medium | High | Dependency graph analysis upfront |

## Recommendation

**Proceed with Option 1 (Three-Way Split)** due to:
- Better compilation surface isolation
- Clearer separation of concerns
- More flexible for future growth
- Aligns with existing Internal module pattern

**Estimated Effort:** 4-8 hours
**Expected Outcome:** Resolved SIGILL issues, improved compilation times, better architecture

## Next Steps

1. ✅ **Create this proposal** (COMPLETED)
2. ⏳ **Get architectural review** (NEXT)
3. ⏳ **Implement three-way split**
4. ⏳ **Test and validate**
5. ⏳ **Deploy to consumers**

**Status:** ✅ **PROPOSAL READY FOR REVIEW**