# Cathedral DSL Architecture

## Executive Summary

**Cathedral DSL** (Cryptographic Spine Rebuilder) transforms the current **evidence collection → tamper-evident chain validation → forensic reconstruction** pipeline from a CPU-bound actor-based system into a **hardware-saturated megakernel**. The goal is to eliminate the coordination tax (evidence serialization, per-record hashing overhead, sequential chain validation) and achieve 5–10x throughput improvement on Apple Silicon for evidence integrity operations.

**Current Status**: Actor-bound evidence system performing sequential SHA-256 hashing and chain validation (TamperEvidenceSystem, CathedralCoordinator).  
**Saturated Vision**: Fused Metal kernel executing parallel hash tree construction, batch chain validation, and cryptographic verification on GPU, with asynchronous evidence persistence to storage layer.

---

## 1. Current Architecture Analysis

### 1.1 Data Flow (Existing ECS Implementation)

```
Evidence Event (Record)
    ↓
[TamperEvidenceSystem.recordEvidence()] (CPU: JSON serialization, SHA-256 hash)
    ├─ Outputs: Evidence (id, hash, previousHash, timestamp)
    ├─ Serialization overhead: ~0.5-2ms per record
    ├─ Hashing overhead: ~1-3ms per record (SHA-256)
    ↓
[Persistence Layer] (CPU: database write, transaction coordination)
    ├─ Outputs: persisted Evidence record
    ├─ Coordination: actor serialization, DB transaction
    ↓
[EvidenceSubstrate.enforceEvidenceSubstrate()] (CPU: chain validation)
    ├─ Outputs: EvidenceEnforcementResult
    ├─ Validation overhead: 1-5ms per operation
    ↓
[CathedralCoordinator.executeWithEvidence()] (CPU: verification)
    ├─ Outputs: OperationResult with proof
    ↓
Chain Integrity Report (signed)
```

### 1.2 Key Bottlenecks (Coordination Tax)

| Bottleneck | Mechanism | Impact | Latency |
|------------|-----------|--------|---------|
| **JSON Serialization** | Convert payload to String for hash input | 10-50% overhead | 0.5-2ms per record |
| **Per-Record Hashing** | SHA-256 for every evidence event | Sequential bottleneck | 1-3ms per record |
| **Chain Validation** | Linear scan through evidence chain | O(n) validation | 10-100ms per chain |
| **Actor Serialization** | Thread-safe actor queue for recordEvidence | Scheduling overhead | 2-5ms per call |
| **Database Coordination** | Transaction synchronization & ACID enforcement | Lock contention | 1-5ms per write |
| **No Batch Processing** | Single-record API | No parallelism | Compounded above |

**Real-world impact**: Evidence recording for 1,000 events = 3-10 seconds (no parallelism, sequential SHA-256)

### 1.3 Current Components & Systems

| Component | Role | Coordination Tax |
|-----------|------|------------------|
| **TamperEvidenceSystem** | Actor managing evidence chain | Serialization of evidence records |
| **Evidence** | Data structure for one record | Includes previousHash for validation |
| **EvidenceSubstrate** | Enforcement logic | Per-operation validation calls |
| **CathedralCoordinator** | High-level evidence API | Async/await threading overhead |
| **CathedralDatabasePersistence** | Storage layer | Transaction coordination |
| **EvidenceType, EvidenceMetadata** | Type system | Per-record serialization |

**Total components identified**: 6 major, 4 minor types  
**Total systems mapped**: 3 (Evidence Recording, Chain Validation, Persistence)

---

## 2. Proposed Saturated Architecture

### 2.1 High-Level Vision

Transform evidence operations into a **parallel megakernel pipeline**:

```
Evidence Batch (N events)
    ↓
[Stage 1: GPU Kernel - Parallel SHA-256 Hashing]
    ├─ Parallel hash computation for all N records
    ├─ GPU compute: 1,000x parallelism
    ├─ Output: Hash array (one per record)
    ↓
[Stage 2: GPU Kernel - Parallel Chain Construction]
    ├─ Compute chain tree (Merkle-like structure)
    ├─ Verify hash continuity in parallel
    ├─ Output: Merkle tree root + proofs
    ↓
[Stage 3: GPU Kernel - Chain Validation & Proof Generation]
    ├─ Validate integrity constraints
    ├─ Generate cryptographic proofs (zero-knowledge ready)
    ├─ Output: Validation proofs, violation flags
    ↓
[Write-Combine Buffer - Unified Evidence Ring]
    ├─ Gather GPU results into ring buffer
    ├─ Async persistence (off the critical path)
    ↓
Chain Integrity Proof (signed, GPU-verified)
```

### 2.2 Mission Descriptor Grammar (Swift)

```swift
/// Cathedral DSL Mission Descriptor
public struct CathedralMission: Sendable, Codable {
    /// Unique mission identifier
    public let missionId: String
    
    /// Evidence batch metadata
    public let batchSize: Int  // 1-10,000
    public let evidenceType: EvidenceType
    public let operationType: String  // "hash", "validate", "reconstruct"
    
    /// GPU kernel parameters
    public struct HashConfig: Sendable, Codable {
        public let algorithmFamily: HashFamily  // SHA-256, SHA-3, BLAKE3
        public let parallelism: UInt32  // threads per hash
        public let optimizationLevel: OptimizationLevel  // speed / energy
    }
    public let hashConfig: HashConfig
    
    /// Chain validation parameters
    public struct ValidationConfig: Sendable, Codable {
        public let validateTimestampOrdering: Bool
        public let validateChainContinuity: Bool
        public let detectTamperingPatterns: Bool
        public let computeMerkleProofs: Bool
    }
    public let validationConfig: ValidationConfig
    
    /// Evidence persistence
    public struct PersistenceConfig: Sendable, Codable {
        public let ringBufferSize: Int  // 64-256 MB
        public let persistAsync: Bool  // GPU-independent
        public let compressionLevel: Int  // 0-9
    }
    public let persistenceConfig: PersistenceConfig
    
    /// Governor integration
    public let governorSeal: GovernorSeal?  // Optional cryptographic proof
    public let evidenceQualityRequirement: EvidenceQuality
}

public enum HashFamily: String, Sendable, Codable {
    case sha256 = "sha256"
    case sha3 = "sha3"
    case blake3 = "blake3"
}

public enum OptimizationLevel: String, Sendable, Codable {
    case speed = "speed"
    case energy = "energy"
    case balanced = "balanced"
}
```

### 2.3 Mission Descriptor YAML Example

```yaml
# Cathedral DSL Mission: Batch Evidence Validation
mission_id: "cath-20250420-batch-001"
batch_size: 5000
evidence_type: "query_execution"
operation_type: "validate"

hash_config:
  algorithm_family: "sha256"
  parallelism: 32  # 32 threads per hash on GPU
  optimization_level: "speed"

validation_config:
  validate_timestamp_ordering: true
  validate_chain_continuity: true
  detect_tampering_patterns: true
  compute_merkle_proofs: true

persistence_config:
  ring_buffer_size_mb: 128
  persist_async: true
  compression_level: 6

governance:
  governor_seal: "0x7f8e9d0a1b2c3d4e..."  # Signed by governance
  quality_requirement: "verified"
  audit_policy: "forensic"

resource_budget:
  gpu_memory_mb: 512
  compute_time_ms: 500
  storage_io_mb: 256
```

### 2.4 Fused Kernel Design (Pseudocode)

#### Stage 1: Parallel Hash Kernel

```metal
// Compute kernel: parallel SHA-256 hashing
kernel void hashEvidenceBatch(
    constant Evidence *inputEvidence [[buffer(0)]],
    device uint32_t *outputHashes [[buffer(1)]],
    constant uint32_t *hashConfig [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    // Each thread hashes one evidence record
    Evidence ev = inputEvidence[gid];
    
    // Serialize evidence to bytes (optimized: pre-serialized in SoA format)
    uint8_t buffer[256];  // Fixed size for alignment
    serializeEvidenceSoA(ev, buffer);
    
    // Parallel SHA-256 (SIMD-friendly)
    uint32_t hash[8] = sha256_parallel(buffer, 256);
    
    // Store hash (aligned for coalesced writes)
    storeHashAligned(hash, gid, outputHashes);
}
```

#### Stage 2: Chain Construction Kernel

```metal
// Compute kernel: parallel chain tree construction
kernel void buildChainTree(
    constant uint32_t *evidenceHashes [[buffer(0)]],
    constant uint32_t *previousHashes [[buffer(1)]],
    device ChainNode *chainTree [[buffer(2)]],
    constant uint32_t &treeSize [[buffer(3)]],
    uint gid [[thread_position_in_grid]]
) {
    // Each thread validates one evidence hash
    uint32_t currentHash = evidenceHashes[gid];
    uint32_t expectedPrevHash = (gid > 0) ? evidenceHashes[gid - 1] : 0;
    
    // Verify hash continuity
    bool isValid = (previousHashes[gid] == expectedPrevHash || gid == 0);
    
    // Build tree node
    ChainNode node = {
        .hash = currentHash,
        .previousHash = previousHashes[gid],
        .isValid = isValid,
        .treeIndex = gid
    };
    
    chainTree[gid] = node;
}
```

#### Stage 3: Validation & Proof Kernel

```metal
// Compute kernel: validation and proof generation
kernel void validateAndProve(
    constant ChainNode *chainTree [[buffer(0)]],
    device ValidationResult *results [[buffer(1)]],
    constant ValidationConfig *config [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    ChainNode node = chainTree[gid];
    ValidationResult result = { .violations = 0, .proofValid = true };
    
    // Check timestamp ordering (if configured)
    if (config->checkTimestampOrdering) {
        if (gid > 0 && chainTree[gid].timestamp < chainTree[gid - 1].timestamp) {
            result.violations |= VIOLATION_TIMESTAMP_ORDER;
            result.proofValid = false;
        }
    }
    
    // Check chain continuity
    if (!node.isValid) {
        result.violations |= VIOLATION_CHAIN_BROKEN;
        result.proofValid = false;
    }
    
    // Generate Merkle proof (if configured)
    if (config->computeMerkleProofs) {
        result.merkleProof = computeMerklePath(node, gid, chainTree);
    }
    
    results[gid] = result;
}
```

### 2.5 Structure-of-Arrays (SoA) Layout

**Challenge**: GPU kernels expect coalesced memory access. Cathedral's Evidence struct (id, type, sessionId, hash, metadata) has poor GPU cache locality.

**Solution**: Pre-marshal evidence into SoA format:

```swift
/// GPU-optimized SoA layout for evidence batch
public struct EvidenceSoABatch: Sendable {
    // Separate arrays for each field (GPU cache-friendly)
    public var ids: [UInt64]              // Coalesced reads
    public var types: [UInt8]             // Packed type codes
    public var hashes: [UInt32]           // Hash values (32-bit for speed)
    public var previousHashes: [UInt32]   // Previous hash values
    public var timestamps: [UInt64]       // Millisecond timestamps
    public var sessionIds: [UInt32]       // Session index references
    public var agentIds: [UInt32]         // Agent index references
    
    /// Metadata lookup (separate)
    public var metadata: [EvidenceMetadataCompact]
    
    public init(from batch: [Evidence]) {
        // Convert from AoS to SoA for GPU consumption
        self.ids = batch.map { UInt64(truncatingIfNeeded: $0.id.hashValue) }
        self.types = batch.map { UInt8($0.type.rawValue.hashValue & 0xFF) }
        // ... etc
    }
    
    /// Convert GPU results back to Evidence objects
    public func toEvidenceArray(with hashes: [UInt32]) -> [Evidence] {
        // Reconstruct Evidence from SoA + GPU results
        return zip(0..<ids.count, hashes).map { index, hash in
            Evidence(
                id: String(ids[index]),
                type: EvidenceType(rawValue: String(types[index])) ?? .operationExecution,
                hash: String(format: "%08x", hash),
                previousHash: String(format: "%08x", previousHashes[index]),
                timestamp: Date(timeIntervalSince1970: Double(timestamps[index]) / 1000)
            )
        }
    }
}
```

### 2.6 Evidence Collection Model

```swift
/// GPU evidence heartbeat ring (Write-Combine Buffer integration)
public struct EvidenceHeartbeatRing: Sendable {
    public let ringBufferSize: Int  // 64-256 MB
    private var buffer: UnsafeMutableBufferPointer<EvidenceHeartbeatSlot>
    private var writeOffset: UInt64 = 0  // Atomic counter
    
    /// Lightweight heartbeat pushed by GPU kernels
    public struct EvidenceHeartbeatSlot: Sendable {
        public let missionId: String
        public let chainRootHash: UInt32
        public let eventsProcessed: UInt32
        public let violationsDetected: UInt32
        public let validationProof: [UInt8]  // Compact proof
        public let timestamp: UInt64
    }
    
    /// Append heartbeat without GPU-CPU sync
    public func appendHeartbeat(_ slot: EvidenceHeartbeatSlot) {
        let offset = OSAtomicIncrement64(&writeOffset) % UInt64(ringBufferSize)
        buffer[Int(offset)] = slot
    }
    
    /// Consume heartbeats asynchronously
    public func drainHeartbeats() -> [EvidenceHeartbeatSlot] {
        // Non-blocking drain for logging/audit
        var results: [EvidenceHeartbeatSlot] = []
        let currentOffset = writeOffset
        // ... drain logic
        return results
    }
}
```

---

## 3. Integration Points with Saturated Platform

### 3.1 Lane Protocol (SaturationLane)

```swift
// Cathedral implements SaturationLane
public protocol SaturationLane {
    func compileMission(_ mission: CathedralMission) async throws -> CompiledMegakernel
    func executeInGPUContext(_ kernel: CompiledMegakernel) async throws -> EvidenceHeartbeatRing
    func integrateResults(_ heartbeats: [EvidenceHeartbeatRing.EvidenceHeartbeatSlot]) async throws
}

extension CathedralLane: SaturationLane {
    public func compileMission(_ mission: CathedralMission) async throws -> CompiledMegakernel {
        // Compile Metal kernels from mission descriptor
        let metalLibrary = try compileMetalKernels(from: mission)
        return CompiledMegakernel(
            computeKernels: [metalLibrary.makeFunction(name: "hashEvidenceBatch")!],
            threadgroupSize: [simd_uint2(32, 1), simd_uint2(256, 1), simd_uint2(1024, 1)],
            memorySoA: try marshalEvidenceToSoA(mission)
        )
    }
}
```

### 3.2 Dependency Mapping

| Dependency | Interface | Use Case |
|-----------|-----------|----------|
| **Governance (Governor)** | GovernorSeal | Cryptographic proof of validation (optional) |
| **Evidence Authority** | EvidenceSink | Integration with global evidence store |
| **Thermal Prediction** | ThermalBudget | Throttle batch sizes based on temp forecast |
| **Lane Scheduler** | LanePriority | Prioritize high-value evidence batches |
| **Write-Combine Buffer** | RingBufferWrite | Async heartbeat persistence |

### 3.3 Resource Budgets

| Resource | Per-Mission Budget | Rationale |
|----------|-------------------|-----------|
| **GPU Memory** | 256-1,024 MB | Batch size 1,000-10,000 records × 256 bytes SoA |
| **Compute Time** | 100-1,000 ms | GPU parallelism: 1,000 records in ~10ms |
| **GPU Threads** | 256-1,024 | Hash kernel: 32 threads per SIMD group |
| **Ring Buffer** | 64-256 MB | Heartbeat drain rate: ~1 MB/sec |

### 3.4 Failure Modes & Recovery

| Failure | Cause | Recovery |
|---------|-------|----------|
| **Kernel Timeout** | GPU hung or blocked | Revert to CPU SHA-256, escalate to scheduler |
| **Hash Mismatch** | Tampered evidence detected | Flag violation, trigger forensic audit |
| **Memory Exhaustion** | Batch too large | Reduce batch size, retry in chunks |
| **Chain Discontinuity** | Evidence loss or reordering | Reconstruct from ring buffer, validate proof |

---

## 4. Current Pain Points Summary

1. **Sequential Hashing**: 3-10 seconds for 1,000 events (CPU-bound)
2. **Actor Serialization**: 2-5ms overhead per recordEvidence call
3. **No Batch API**: Single-record design prevents parallelism
4. **Chain Validation**: O(n) linear scan, no parallel verification
5. **Database Contention**: Transaction locks during persistence

---

## 5. Opportunity Assessment

| Dimension | Current | Saturated | Improvement |
|-----------|---------|-----------|-------------|
| **Throughput** | 100-200 records/sec | 10,000-50,000 records/sec | 50-250x |
| **Latency** | 3-10 seconds (1K records) | 50-200 ms (1K records) | 15-150x |
| **Parallelism** | 1 (sequential) | 1,000+ (GPU threads) | 1,000x |
| **Energy** | 10-20W (CPU SHA-256) | 2-5W (GPU SHA-256, power-efficient) | 2-10x better |
| **Cost per op** | ~5-10 µs | ~0.05-0.1 µs | 50-200x cheaper |

**Feasibility Verdict**: ✅ **HIGHLY FEASIBLE** (See Phase 5 report for details)

---

## 6. Comparison to Other DSLs

| DSL | Focus | GPU Fit | Priority |
|-----|-------|---------|----------|
| **Cathedral** | Evidence verification (hash, validate) | ★★★★★ | HIGH (P2) |
| **Diaplasion** | Document ingestion (OCR, transform) | ★★★★★ | DONE |
| **Vector** | Embedding indexing (dot product, ANN) | ★★★★★ | HIGH (P2) |
| **Contextum** | Memory eviction heuristics (scoring) | ★★★ | MEDIUM (P3) |
| **Observatorium** | Trace aggregation (heartbeat batching) | ★★★★ | HIGH (P2) |

---

End of Architecture Analysis
