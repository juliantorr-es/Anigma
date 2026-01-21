# Build Audit - January 7, 2026

## Summary
Comprehensive audit of warnings, errors, and integration issues across the Anigma codebase following Contextum Phases 0-6 implementation.

## Critical Integration Issues (P0)

### 1. ArtifactStoreEventBridge Missing Dependencies
**File**: `Sources/ContextumModule/Integration/ArtifactStoreEventBridge.swift:70,86`

**Issue**: References undefined methods:
- `contextumModule.enqueueWorkflow()` - method doesn't exist on ContextumModule
- `telemetry.record()` - telemetry is not defined in scope

**Fix Required**: 
- Add `enqueueWorkflow()` method to ContextumModule
- Inject telemetry dependency in ArtifactStoreEventBridge init
- OR use existing job submission API

### 2. ArtifactCommitEvent Initializer Mismatch
**File**: `Sources/ContextumModule/Integration/ArtifactStoreEventBridge.swift:60-65`

**Issue**: Creating ArtifactCommitEvent with 4 parameters but init requires 7 (missing sourceHash, mediaType, embeddingModelID)

**Fix Required**: Use all required parameters or make some optional

### 3. ContextumModule Missing World/Registry Registration
**File**: `Sources/ContextumModule/ContextumModule.swift`

**Issue**: Module needs proper ECS registration following Anigma patterns
- Missing `register(world:registry:telemetry:auditLog:)` method
- Systems not registered with World
- Components not registered with ComponentRegistry

**Fix Required**: Implement full ECS registration pattern

### 4. LocalLLMOrchestrator Contextum Integration Incomplete
**File**: `Sources/AnigmaAppMac/Governance/LocalLLMOrchestrator.swift`

**Issue**: Orchestrator references Contextum but integration is partial
- Preflight/postflight correlation tracking incomplete
- No actual job submission to Contextum
- Missing correlation tuple propagation

**Fix Required**: Complete orchestrator-to-Contextum wiring with proper job envelopes

## Build Warnings (P1)

### 1. Model Contract Missing Types
**Issue**: ExecutionReceipt, ModelSpec, RunSpec referenced but may not have all required fields for embedding use case

**Verify**: Check ContractsCore for complete type definitions

### 2. Database Migration Status Unknown
**Issue**: Multiple new tables added (embeddings, analytics_rollups, forensics, etc.) but migration status unclear

**Action Required**: 
- Verify DatabaseActor migration chain
- Test clean install + upgrade paths
- Document schema version

### 3. Job/Workflow Type Registration
**Issue**: New job kinds referenced (context.ingest, context.search, etc.) but registration status unknown

**Action Required**: Verify all job types are registered in scheduler

## Code Quality Issues (P2)

### 1. Placeholder Implementations
**Files**:
- `MLWorkerEmbeddingExecutor.swift:102` - parseVector has placeholder comment
- `HuggingFaceAdapter.swift:151` - TODO for quarantined model import

**Action**: Complete implementations or document as known limitations

### 2. Error Handling Gaps
**Issue**: Some async methods lack proper error propagation
- Auto-indexing workflow errors may be silently swallowed
- Debounce task cancellation doesn't log

**Action**: Add explicit error telemetry

### 3. Test Coverage
**Issue**: No test files found for:
- ContextumModule systems
- ArtifactStoreModule
- MLWorkerEmbeddingExecutor
- Orchestrator sandboxing

**Action**: Add integration tests per phase completion criteria

## Architecture Debt (P3)

### 1. XPC Service Target Missing
**Issue**: ContextumModule designed for XPC service but no `AnigmaContextDaemonHost` target exists in Package.swift

**Status**: Deferred - can run in-process for now, but violates stated architecture

### 2. Model Registry Not Fully Wired
**Issue**: ModelRegistry exists but integration with Contextum embedding model resolution is incomplete

**Action**: Complete registry lookup path in MLWorkerEmbeddingExecutor

### 3. Trust Tier Enforcement Partial
**Issue**: Trust tier filtering mentioned in design but not fully implemented in search paths

**Action**: Add tier gate checks to HybridSearchSystem

## Documentation Gaps (P4)

### 1. Phase Status Docs Out of Sync
**Files**: Multiple CONTEXTUM_*.md files with conflicting status claims

**Fixed**: Updated CONTEXTUM_INTEGRATION_COMPLETE.md to reflect Phases 0-2 done

**Remaining**: Update or consolidate other status files

### 2. Missing ADRs
**Issue**: No ADR for "Anigma supports tasks, not model repos" mentioned in design

**Action**: Create formal ADR

### 3. API Documentation
**Issue**: Public APIs in ContextumModule lack doc comments

**Action**: Add comprehensive documentation for all public types

## Recommended Fix Order

1. **P0 Critical Integration** (Blocks compilation/runtime)
   - Fix ArtifactStoreEventBridge API mismatches
   - Complete ContextumModule ECS registration
   - Wire orchestrator correlation fully

2. **P1 Build Warnings** (Blocks production readiness)
   - Verify/complete type definitions
   - Test database migrations
   - Register all job types

3. **P2 Code Quality** (Blocks maintainability)
   - Complete placeholder implementations
   - Add error telemetry
   - Build integration test suite

4. **P3 Architecture** (Blocks scalability)
   - Consider XPC target for Phase 2+
   - Complete model registry integration
   - Enforce trust tiers

5. **P4 Documentation** (Blocks team understanding)
   - Consolidate status docs
   - Write missing ADRs
   - Document public APIs

## Clean Build Criteria

Build is "clean" when:
- ✅ Zero compilation errors
- ✅ Zero warnings (excluding external dependencies)
- ✅ All integration tests pass
- ✅ Schema migrations tested (clean + upgrade)
- ✅ Orchestrator end-to-end runs produce receipts with correlation
- ✅ Contextum Phase 0-2 tests pass per completion criteria

## Next Steps

1. Address P0 issues to restore compilable state
2. Run full integration test suite
3. Build audit report into CI/CD checks
4. Schedule P1-P4 remediation

---
*Generated: 2026-01-07*
*Audit Scope: Full project post-Contextum integration*
