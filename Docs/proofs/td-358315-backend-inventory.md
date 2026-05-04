# Backend/Executor Surface Inventory - td-358315

## Task: Define Backend Readiness Gates

**Task ID**: td-358315 (td-arch-005)  
**Status**: Inventory Phase  
**Date**: 2026-01-08

## Backend/Executor Surface Inventory

### 1. Inference Backends

**Location**: `anigma/Packages/PlatformCore/InferenceBackend.swift`

**Current State**:
```swift
public struct InferenceRequest: Codable, Sendable {
    public let id: String
    public let model: String
    public let prompt: String
    public let parameters: InferenceParameters
    public let metadata: [String: String]
}

public struct InferenceResponse: Codable, Sendable {
    public let requestId: String
    public let model: String
    public let output: String
}
```

**Classification**: ⚠️ AMBIGUOUS - Request/response models exist but no explicit backend registration/readiness

**Readiness Needs**:
- [ ] Backend registration with PlatformRuntime
- [ ] Readiness state tracking
- [ ] Lifecycle management
- [ ] Contract version compatibility
- [ ] Retry/fallback policies

### 2. Renderer Backends (PolytroposModule)

**Location**: `anigma/Packages/PolytroposModule/Sources/PolytroposModule/Backend/BackendProtocol.swift`

**Current State**:
```swift
public protocol RendererBackend: Sendable {
    var backendId: RendererBackendId { get }
    var displayName: String { get }
    var capabilities: RendererCapabilities { get }
    
    func isAvailable() async -> Bool
    func render(timeline: MultiTrackTimelineComponent, assets: [EntityId: MediaAssetInfo], configuration: ProExportConfiguration, progress: @escaping (RenderProgress) -> Void) async throws -> RenderResult
    func cancelRender(jobId: UUID) async
    func generatePreview(timeline: MultiTrackTimelineComponent, assets: [EntityId: MediaAssetInfo], atTime: TimeInterval, resolution: PreviewBackendResolution) async throws -> PreviewFrame
}
```

**Classification**: ✅ PARTIALLY GOVERNED - Has `isAvailable()` but no PlatformRuntime integration

**Readiness Needs**:
- [ ] Register with PlatformRuntime
- [ ] Lifecycle state management
- [ ] Readiness gate enforcement
- [ ] Evidence for backend operations
- [ ] Contract version compatibility

### 3. Database Executors

**Location**: `anigma/Packages/DatabaseCore/DatabaseExecutor.swift`

**Current State**:
```swift
public protocol DatabaseExecutor: Actor, Sendable {
    func execute(_ sql: String, parameters: [DatabaseParameter]) async throws -> Int
    func query(_ sql: String, parameters: [DatabaseParameter]) async throws -> [DatabaseRow]
    func executeAsync(_ sql: String, parameters: [DatabaseParameter]) async throws -> Int
    func transaction(_ block: @escaping @Sendable () async throws -> Void) async throws
    func open() throws
    func close()
    func isVectorAvailable() async -> Bool
    nonisolated var path: String { get }
}
```

**Classification**: ✅ ALREADY GOVERNED - Wrapped by DatabaseAuthority

**Current Governance**:
- ✅ DatabaseAuthority wraps DatabaseExecutor
- ✅ KillSwitch enforcement (td-arch-001)
- ✅ WriteGate enforcement (td-arch-001)
- ✅ Evidence recording (td-arch-001)
- ✅ MutationReceipt path established

**Readiness Needs**:
- [ ] Backend-specific readiness states
- [ ] Lifecycle state transitions
- [ ] Contract version compatibility
- [ ] Retry/fallback policies

### 4. ML Worker Backends

**Location**: `anigma/Packages/MLWorkerCommon/MLWorkerBackend.swift`

**Current State**: Need to examine this file

**Classification**: ❓ UNKNOWN - Need to examine

### 5. Render Backend Capsule

**Location**: `anigma/Packages/RenderBackendCapsule/`

**Current State**: Need to examine this package

**Classification**: ❓ UNKNOWN - Need to examine

### 6. CLI Tool Executor

**Location**: `anigma/Packages/AnigmaCLI/Database/CLIToolExecutor.swift`

**Current State**: Need to examine this file

**Classification**: ❓ UNKNOWN - Need to examine

### 7. Cloud Provider Adapters

**Location**: `anigma/Packages/AnigmaCLI/Providers/CloudProviderEmbeddingAdapter.swift`

**Current State**: Need to examine this file

**Classification**: ❓ UNKNOWN - Need to examine

### 8. ML Backend Coordinator

**Location**: `anigma/Packages/AnigmaCLI/ML/MLBackendCoordinator.swift`

**Current State**: Need to examine this file

**Classification**: ❓ UNKNOWN - Need to examine

### 9. Local Inference Backends

**Location**: `anigma/Packages/AnigmaCLI/Sources/LocalInference/`

**Files**:
- `LlamaCppBackend.swift`
- `OllamaBackend.swift`

**Current State**: Need to examine these files

**Classification**: ❓ UNKNOWN - Need to examine

## Current Backend/Executor Patterns

### Pattern 1: Direct Instantiation (Problematic)

**Example**:
```swift
// Various places create executors/backends directly
let backend = LlamaCppBackend()  // No readiness check
let executor = DatabaseActor()    // Should use DatabaseAuthority
```

**Issues**:
- ❌ No readiness verification
- ❌ No lifecycle management
- ❌ No contract compatibility check
- ❌ No evidence trail

### Pattern 2: Local Adapter Creation (Problematic)

**Example**:
```swift
// PragmaModule BEFORE migration (now fixed in td-c43f68)
let databaseAdapter = DatabaseAuthorityAdapter(databaseAuthority: databaseAuthority)
let database = PragmaDatabase(dbActor: databaseAdapter)
```

**Issues**:
- ❌ Authority ownership unclear
- ❌ Module creates adapter instead of using PlatformRuntime
- ❌ No explicit readiness check

### Pattern 3: PlatformRuntime Governed (Good)

**Example**:
```swift
// PragmaModule AFTER migration (td-c43f68)
let databaseAuthority = runtime.database  // PlatformRuntime provides it
let database = PragmaDatabase(databaseAuthority: databaseAuthority)
```

**Strengths**:
- ✅ PlatformRuntime owns authorities
- ✅ Clear authority path
- ✅ Governance enforced
- ✅ Evidence recorded

## Required Readiness Model

### Backend Readiness Contract

```swift
/// Backend readiness state
public enum BackendReadinessState: String, Codable, Sendable {
    case unregistered
    case registered
    case initializing
    case ready
    case degraded
    case unavailable
    case failed
    case draining
    case shuttingDown
}

/// Backend capability contract
public struct BackendCapabilityContract: Codable, Sendable {
    public let backendId: String
    public let contractId: String
    public let contractVersion: Int
    public let supportedOperations: [String]
    public let minPlatformVersion: String?
    public let dependencies: [String]
}

/// Backend readiness check result
public struct BackendReadinessCheck: Codable, Sendable {
    public let backendId: String
    public let isReady: Bool
    public let state: BackendReadinessState
    public let contractCompatibility: ContractCompatibility
    public let lifecycleState: BackendLifecycleState
    public let retryPolicy: RetryPolicy?
    public let fallbackBackendId: String?
    public let lastValidation: Date?
    public let denialReason: String?
}

/// Contract compatibility
public enum ContractCompatibility: String, Codable, Sendable {
    case compatible
    case incompatible
    case downgraded
    case upgraded
}

/// Backend lifecycle state
public enum BackendLifecycleState: String, Codable, Sendable {
    case uninitialized
    case initialized
    case active
    case draining
    case terminated
}

/// Retry policy
public struct RetryPolicy: Codable, Sendable {
    public let maxAttempts: Int
    public let backoffStrategy: BackoffStrategy
    public let timeout: TimeInterval
}

/// Backoff strategy
public enum BackoffStrategy: String, Codable, Sendable {
    case none
    case linear
    case exponential
    case custom
}
```

### PlatformRuntime Backend Registry

```swift
/// Backend registry in PlatformRuntime
exension PlatformRuntime {
    /// Register a backend with readiness requirements
    public func registerBackend(
        _ backend: any Backend,
        contract: BackendCapabilityContract,
        readinessChecker: @escaping (any Backend) async -> BackendReadinessCheck
    ) async throws -> BackendRegistrationReceipt
    
    /// Get backend readiness status
    public func backendReadiness(
        for backendId: String
    ) async -> BackendReadinessCheck
    
    /// Select a ready backend for execution
    public func selectBackend(
        contractId: String,
        minVersion: Int
    ) async throws -> (any Backend, BackendReadinessCheck)
    
    /// Execute with readiness enforcement
    public func executeWithBackend<
        B: Backend,
        T
    >(
        _ backendId: String,
        operation: @escaping (B) async throws -> T
    ) async throws -> (T, MutationReceipt)
}
```

### Backend Protocol with Readiness

```swift
public protocol PlatformBackend: Sendable {
    var backendId: String { get }
    var contract: BackendCapabilityContract { get }
    
    /// Check readiness (called by PlatformRuntime)
    func checkReadiness() async -> BackendReadinessCheck
    
    /// Initialize backend
    func initialize() async throws
    
    /// Shutdown backend
    func shutdown() async
    
    /// Execute operation with context
    func execute<
        Operation: BackendOperation,
        Result
    >(
        _ operation: Operation,
        context: ExecutionContext
    ) async throws -> Result
}

/// Backend operation with evidence
public protocol BackendOperation: Sendable {
    var operationId: String { get }
    var operationType: String { get }
    var requiresEvidence: Bool { get }
}
```

## Implementation Plan

### Phase 1: Define Readiness Contracts
- [ ] Create BackendReadinessState enum
- [ ] Create BackendCapabilityContract struct
- [ ] Create BackendReadinessCheck struct
- [ ] Create ContractCompatibility enum
- [ ] Create RetryPolicy struct

### Phase 2: Add PlatformRuntime Backend Registry
- [ ] Add backend registration API
- [ ] Add readiness checking
- [ ] Add backend selection with readiness enforcement
- [ ] Add evidence for backend operations

### Phase 3: Migrate Existing Backends
- [ ] InferenceBackend registration
- [ ] RendererBackend registration  
- [ ] DatabaseExecutor (already governed, add readiness)
- [ ] MLWorkerBackend registration
- [ ] CLIToolExecutor registration

### Phase 4: Add Readiness Gates
- [ ] PlatformRuntime.checkBackendReadiness()
- [ ] PlatformRuntime.selectReadyBackend()
- [ ] PlatformRuntime.executeWithReadinessCheck()
- [ ] Evidence for readiness decisions

### Phase 5: Add Tests
- [ ] Backend registration tests
- [ ] Readiness check tests
- [ ] Unready backend rejection tests
- [ ] Evidence trail tests

### Phase 6: Validation
- [ ] Run enhanced validator (no new bypasses)
- [ ] Run architecture tests
- [ ] Run backend-specific tests
- [ ] Create proof artifact

## Next Steps

1. ✅ **Inventory Complete** (Current phase)
2. [ ] Define readiness contracts
3. [ ] Implement PlatformRuntime backend registry
4. [ ] Migrate existing backends
5. [ ] Add readiness gates
6. [ ] Add comprehensive tests
7. [ ] Create proof artifact

**Estimated Timeline**: 2-3 weeks

## Files to Examine Next

1. `anigma/Packages/MLWorkerCommon/MLWorkerBackend.swift`
2. `anigma/Packages/RenderBackendCapsule/Sources/RenderBackendCapsule/`
3. `anigma/Packages/AnigmaCLI/Sources/LocalInference/`
4. `anigma/Packages/AnigmaCLI/ML/MLBackendCoordinator.swift`

## Task Status

**Current Phase**: ✅ Inventory Complete
**Next Phase**: Define readiness contracts and models
**Risk Level**: Medium (complex but well-scoped)
**Epic Progress**: p1-runtime-architecture-lockdown ~80% complete

**Next Action**: Define BackendReadinessState enum and related contracts
