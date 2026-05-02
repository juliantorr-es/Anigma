# Cathedral DSL Integration & Dependency Mapping

## Executive Summary

This document defines Cathedral DSL's integration points with the Saturated Platform, resource budgets, failure modes, and deployment requirements. Cathedral implements the `SaturationLane` protocol and integrates with governance, evidence authority, thermal prediction, and scheduling subsystems.

---

## 1. Platform Integration Architecture

### 1.1 SaturationLane Protocol Implementation

Cathedral DSL implements the Saturated Platform's `SaturationLane` protocol for GPU mission execution:

```swift
public protocol SaturationLane: Actor {
    /// Compile a mission descriptor into GPU kernels
    func compileMission(_ mission: AnyCathedralMission) async throws -> CompiledMegakernel
    
    /// Execute in GPU context and return results
    func executeInGPUContext(_ kernel: CompiledMegakernel) async throws -> MissionResult
    
    /// Integrate heartbeat results with platform
    func integrateResults(_ heartbeats: [HeartbeatSlot]) async throws
}

public actor CathedralSaturationLane: SaturationLane {
    // Implementation
}
```

### 1.2 Data Contracts

#### Mission Input Contract

```swift
/// Cathedral DSL Input Contract
public protocol CathedralMissionInput: Sendable {
    var missionId: String { get }
    var batchSize: Int { get }
    var evidenceSoA: EvidenceSoABatch { get }
    var operationType: String { get }  // "hash", "validate", "reconstruct"
    var governorSeal: GovernorSeal? { get }
}
```

#### Mission Output Contract

```swift
/// Cathedral DSL Output Contract
public struct CathedralMissionOutput: Sendable {
    public let missionId: String
    public let resultType: String  // "hashes", "validations", "proofs"
    public let resultData: [UInt32]  // Raw GPU results
    public let violationCount: UInt32
    public let proofData: [UInt8]?  // Optional Merkle proofs
    public let executionTimeMs: UInt32
}
```

#### Heartbeat Contract

```swift
/// Evidence heartbeat for Saturated Platform
public struct CathedralHeartbeat: Sendable {
    public let missionId: String
    public let phase: String  // "hash", "validate", "prove"
    public let success: Bool
    public let eventsProcessed: UInt32
    public let violationsDetected: UInt32
    public let gpuTimeMs: UInt32
    public let memoryUsedBytes: UInt32
    public let timestamp: UInt64
    
    /// Encode as platform heartbeat
    public func toPlatformHeartbeat() -> SaturatedHeartbeat {
        return SaturatedHeartbeat(
            laneId: "cathedral",
            phaseId: phase,
            status: success ? .complete : .failed,
            metricsData: [
                "events_processed": "\(eventsProcessed)",
                "violations": "\(violationsDetected)",
                "gpu_time_ms": "\(gpuTimeMs)",
                "memory_bytes": "\(memoryUsedBytes)"
            ]
        )
    }
}
```

---

## 2. Dependency Mapping

### 2.1 Direct Dependencies

| Dependency | Purpose | Interface | Status |
|-----------|---------|-----------|--------|
| **Governance (Governor)** | Cryptographic sealing of missions | `GovernorSeal` | Required |
| **Evidence Authority** | Global evidence storage + audit | `EvidenceSink` | Required |
| **Thermal Predictor** | Forecast GPU thermal budget | `ThermalBudget` | Required |
| **Lane Scheduler** | Prioritize missions across lanes | `LanePriority` | Required |
| **Write-Combine Buffer** | Async heartbeat persistence | `RingBufferWrite` | Optional |

### 2.2 Governance Integration

Cathedral DSL **requires** optional cryptographic sealing from the Governance layer for forensic-grade evidence operations:

```swift
// Governance Integration
public struct GovernorSeal: Sendable, Codable {
    /// Cryptographic signature of mission parameters
    public let signature: String
    
    /// Public key for signature verification
    public let publicKey: String
    
    /// Timestamp of signing
    public let timestamp: Date
    
    /// Audit policy level
    public let auditPolicy: AuditPolicy  // "standard", "forensic", "minimal"
}

// Mission with Governor seal
let mission = CathedralMission(
    missionId: "cath-sealed-001",
    batchSize: 1000,
    operationType: "validate",
    governorSeal: GovernorSeal(
        signature: "0x7f8e9d0a...",
        publicKey: "0x7f8e9d0b...",
        timestamp: Date(),
        auditPolicy: .forensic
    )
)
```

### 2.3 Evidence Authority Integration

```swift
// Register Cathedral as an evidence sink
extension CathedralSaturationLane: EvidenceSink {
    public func record(
        receipt: CoreReceipt,
        payload: EvidencePayload,
        operation: CoreOperationType,
        governanceDecision: GovernanceDecision?,
        context: ExecutionContext
    ) async throws {
        // Convert receipt to Cathedral evidence
        let evidence = Evidence(
            id: receipt.id,
            type: evidenceTypeFromOperation(operation),
            sessionId: receipt.sessionId,
            agentId: receipt.principal.id,
            contentHash: payload.hash,
            metadata: EvidenceMetadata(
                source: "CathedralLane",
                operation: receipt.operationType,
                parameters: receipt.metadata,
                quality: .verified
            ),
            previousHash: context.previousEvidenceHash
        )
        
        // Record in Cathedral chain
        try await tamperSystem.recordEvidence(evidence)
    }
}
```

### 2.4 Thermal Integration

Cathedral DSL adjusts batch size and GPU load based on thermal forecasts:

```swift
public protocol ThermalPredictor: Actor {
    struct ThermalBudget: Sendable {
        /// Max batch size to stay within thermal envelope
        public let maxBatchSize: Int
        
        /// Max GPU load percentage (0-100)
        public let maxGPULoad: Float
        
        /// Recommend throttling
        public let recommendThrottle: Bool
        
        /// Predicted core temperature (°C)
        public let predictedCoreTemp: Float
    }
    
    func forecastBudget(durationMs: UInt32) async throws -> ThermalBudget
}

// Usage in executor
let thermalBudget = try await thermalPredictor.forecastBudget(durationMs: 100)
let adjustedBatchSize = min(mission.batchSize, thermalBudget.maxBatchSize)
```

### 2.5 Lane Scheduler Integration

Cathedral DSL respects lane scheduling and priority allocation:

```swift
public protocol LaneScheduler: Actor {
    struct LanePriority: Sendable {
        public let priority: UInt32  // 0-255
        public let weight: Float      // Scheduler weight
        public let reservedGPUMs: UInt32  // GPU milliseconds reserved
    }
    
    func allocatePriority(for laneId: String, missionId: String) async throws -> LanePriority
    func releaseAllocation(missionId: String) async throws
}

// Usage
let priority = try await laneScheduler.allocatePriority(
    for: "cathedral",
    missionId: mission.missionId
)
```

---

## 3. Resource Budgets

### 3.1 GPU Memory Budget

| Component | Batch=100 | Batch=1K | Batch=10K |
|-----------|-----------|----------|-----------|
| Input SoA | 8 KB | 66 KB | 660 KB |
| Hash output | 4 KB | 32 KB | 320 KB |
| Validation output | 2 KB | 16 KB | 160 KB |
| Merkle proofs | 8 KB | 64 KB | 640 KB |
| **Total** | **22 KB** | **178 KB** | **1.78 MB** |

**Typical allocation**: 256-512 MB per lane (allows 1,000-10,000 concurrent missions)

### 3.2 GPU Compute Budget

| Operation | Threads | Duration | Power |
|-----------|---------|----------|-------|
| Hash (1K records) | 1,024 | 8-12 ms | 4-6W |
| Validate (1K records) | 1,024 | 10-15 ms | 3-5W |
| Prove (1K records) | 256 | 5-10 ms | 1-2W |
| **Total** | 2,304 | 23-37 ms | 8-13W |

**GPU capacity**: Apple M2 Max = 10 GPU cores, ~5 TFLOPS = ~70-100W TDP

### 3.3 CPU Threading Budget

| Task | Threads | Duration | Overhead |
|------|---------|----------|----------|
| Mission compilation | 1 | 2-5 ms | <1% |
| Buffer marshaling | 2 | 5-10 ms | <1% |
| Result readback | 1 | 1-2 ms | <1% |
| Heartbeat drain | 1 | <1 ms | <0.1% |

**CPU overhead**: < 2% on 8-core CPU

### 3.4 Storage Budget

| Component | Per-Mission | Rate | Monthly |
|-----------|------------|------|---------|
| Evidence records | 256 KB (1K × 256B) | 1 KB/sec | 2.6 GB |
| Validation proofs | 64 KB (1K × 64B) | 100 B/sec | 260 MB |
| Heartbeats | 4 KB | 10 B/sec | 26 MB |
| **Total** | 324 KB | 1.1 KB/sec | 2.9 GB |

---

## 4. Failure Modes & Recovery

### 4.1 Failure Mode Matrix

| Failure | Cause | Detection | Recovery | Impact |
|---------|-------|-----------|----------|--------|
| **GPU Kernel Hang** | Infinite loop in compute shader | Command buffer timeout (5s) | Revert to CPU, escalate to scheduler | Mission timeout, no evidence loss |
| **GPU Memory OOM** | Batch too large for GPU memory | Metal allocation error | Reduce batch size, retry | Mission retry, CPU fallback |
| **Hash Mismatch** | GPU computation error or bit flip | Output validation against CPU | Replay with verification | Evidence integrity flag |
| **Chain Discontinuity** | Evidence records lost between GPU/CPU | Validation kernel detects broken hash | Reconstruct from ring buffer | Audit flag, chain repair |
| **Thermal Throttle** | GPU exceeds temp limit | Thermal sensor reading > 80°C | Reduce batch size, pause missions | Graceful degradation |
| **Scheduler Starvation** | Higher-priority lanes starve Cathedral | Mission timeout in queue | Raise priority for critical missions | Delayed evidence processing |
| **Ring Buffer Overflow** | Heartbeats accumulate faster than drain | Write offset overflow | Escalate drain frequency | Loss of recent heartbeats |

### 4.2 Recovery Strategies

#### GPU Kernel Hang Recovery

```swift
public actor CathedralLaneRecoveryManager {
    func recoverFromKernelHang(mission: CathedralMission) async throws {
        // 1. Abort GPU command buffer
        try await gpuContext.abortPendingCommands()
        
        // 2. Fall back to CPU implementation
        let cpuExecutor = CPUCathedralExecutor()
        let cpuResult = try await cpuExecutor.executeMission(mission)
        
        // 3. Escalate to scheduler
        try await laneScheduler.reportFailure(
            missionId: mission.missionId,
            reason: "GPU kernel hang, fell back to CPU",
            severity: .warning
        )
        
        // 4. Publish heartbeat with error flag
        try await publishHeartbeat(CathedralHeartbeat(
            missionId: mission.missionId,
            phase: "recovery",
            success: false,
            eventsProcessed: UInt32(mission.batchSize),
            violationsDetected: 0,
            gpuTimeMs: 0,
            memoryUsedBytes: 0,
            timestamp: UInt64(Date().timeIntervalSince1970 * 1000)
        ))
    }
}
```

#### Hash Mismatch Recovery

```swift
public func recoverFromHashMismatch(
    gpuHash: UInt32,
    cpuHash: UInt32,
    recordIndex: UInt32
) async throws {
    // 1. Log discrepancy
    print("Hash mismatch at record \(recordIndex): GPU=\(gpuHash) CPU=\(cpuHash)")
    
    // 2. Flag evidence as suspicious
    let violation = EvidenceViolation(
        type: .integrityMismatch,
        severity: .critical,
        description: "GPU/CPU hash divergence at index \(recordIndex)",
        evidenceId: String(recordIndex)
    )
    try await tamperSystem.recordViolation(violation, sessionId: "recovery")
    
    // 3. Trigger full chain audit
    let report = try await tamperSystem.performComprehensiveValidation(sessionId: "recovery")
    
    // 4. Quarantine affected batch
    try await quarantineEvidence(recordIndex: recordIndex)
}
```

#### Thermal Throttle Recovery

```swift
public func recoverFromThermalThrottle() async throws {
    // 1. Read current thermal status
    let thermal = try await thermalPredictor.getCurrentBudget()
    
    // 2. Reduce batch size and queue depth
    let nextBatchSize = max(10, thermal.maxBatchSize / 2)
    
    // 3. Pause non-critical missions
    try await laneScheduler.pauseNonCritical(reason: "Thermal throttle")
    
    // 4. Drain heartbeats to reduce GPU load
    try await heartbeatRing.drainHeartbeats()
    
    // 5. Wait for temperature to normalize
    try await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
    
    // 6. Resume with reduced rate
    try await laneScheduler.resumeWithReducedRate(factor: 0.5)
}
```

---

## 5. Deployment Checklist

### 5.1 Pre-Deployment

- [ ] Metal kernel compilation successful on target hardware
- [ ] GPU memory allocation tested (up to 512 MB)
- [ ] Thermal predictor calibrated for target device
- [ ] Lane scheduler tested with Cathedral as one of N lanes
- [ ] Evidence authority integration tested with real governance seals
- [ ] Fallback CPU executor verified and benchmarked
- [ ] Heartbeat ring draining tested at 1,000 Hz

### 5.2 Runtime Configuration

```swift
let config = CathedralDeploymentConfig(
    maxBatchSize: 10_000,
    maxGPUMemory: 512 * 1024 * 1024,  // 512 MB
    thermalThresholdCelsius: 75,
    kernelTimeoutSeconds: 5,
    heartbeatDrainIntervalMs: 100,
    cpuFallbackEnabled: true,
    governanceSealsRequired: true,
    auditPolicyDefault: .forensic
)
```

### 5.3 Monitoring

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Avg mission duration | < 50 ms | > 100 ms |
| Kernel failures | 0 per 10K missions | > 1 |
| GPU memory peak | < 256 MB | > 400 MB |
| Thermal events | 0 per hour | > 1 |
| Chain discontinuities | 0 per hour | > 0 |
| CPU fallback rate | < 0.1% | > 1% |

---

## 6. Platform Integration Example

### 6.1 Complete Integration Flow

```swift
// In SaturatedPlatform.swift
public actor SaturatedPlatform {
    let cathedral: CathedralSaturationLane
    let scheduler: LaneScheduler
    let thermalPredictor: ThermalPredictor
    let governor: Governor
    
    public func registerCathedralLane() async throws {
        // Initialize Cathedral DSL
        cathedral = try await CathedralSaturationLane(
            laneScheduler: scheduler,
            thermalPredictor: thermalPredictor
        )
        
        // Register as evidence sink
        try await evidenceAuthority.registerSink(cathedral)
        
        // Start heartbeat drain loop
        Task {
            while true {
                try await cathedral.drainHeartbeats()
                try await Task.sleep(nanoseconds: 100_000_000)  // 100 ms
            }
        }
    }
    
    public func executeCathedralMission(_ mission: CathedralMission) async throws -> MissionResult {
        // 1. Get Governor seal (optional)
        let seal = try await governor.seal(mission: mission)
        var missionWithSeal = mission
        missionWithSeal.governorSeal = seal
        
        // 2. Allocate scheduler priority
        let priority = try await scheduler.allocatePriority(
            for: "cathedral",
            missionId: missionWithSeal.missionId
        )
        
        // 3. Check thermal budget
        let thermalBudget = try await thermalPredictor.forecastBudget(durationMs: 100)
        let adjustedMission = missionWithSeal.withBatchSize(
            min(missionWithSeal.batchSize, thermalBudget.maxBatchSize)
        )
        
        // 4. Compile and execute
        let kernel = try await cathedral.compileMission(adjustedMission)
        let result = try await cathedral.executeInGPUContext(kernel)
        
        // 5. Release scheduler allocation
        try await scheduler.releaseAllocation(missionId: missionWithSeal.missionId)
        
        return result
    }
}
```

---

## 7. Compliance & Governance

### 7.1 Evidence Integrity Guarantees

Cathedral DSL provides three levels of evidence integrity:

1. **Standard**: SHA-256 hashing + chain validation (no governance seal)
2. **Forensic**: SHA-256 + Merkle proofs + Governor cryptographic seal
3. **Minimal**: Hash-only, no validation (fastest, least audit trail)

### 7.2 Audit Trail

Every Cathedral mission produces an audit-grade heartbeat:

```swift
public struct AuditHeartbeat: Sendable {
    let missionId: String
    let phase: String
    let eventsProcessed: UInt32
    let violations: UInt32
    let governorSeal: String?  // Signed proof
    let chainRootHash: UInt32
    let timestamp: UInt64
}
```

---

End of Integration Document
