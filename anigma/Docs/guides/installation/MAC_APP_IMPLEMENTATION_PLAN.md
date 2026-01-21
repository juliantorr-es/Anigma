# Mac App Implementation Plan
**Created:** 2026-01-07  
**Focus Areas:** Model Registry Metadata & Cathedral Integration  
**Priority:** High

---

## Executive Summary

The Anigma Mac app is **~85-90% complete** with excellent architecture. Two critical gaps remain:

1. **Model Registry Metadata Schema Mismatch** (15 TODOs) - UI expects richer `ModelRegistryEntry` but uses simplified `ModelSpec`
2. **Cathedral Module Integration** (Placeholder) - Federated coordination system is stubbed out

This document outlines the implementation plan for both areas.

---

## Part 1: Model Registry Metadata Tracking

### Problem Analysis

**Root Cause:** Schema evolution mismatch

- **UI Components** (`ModelRegistryCard.swift`, `ModelRegistryView.swift`) expect:
  - Runtime metadata: `isRunnable`, `status`, `usageCount`, `lastUsed`
  - Storage metadata: `storageBytes`, `installPath`  
  - Timestamps: `registeredAt`, `lastVerified`
  - Structured license: `{ allowed: Bool, reason: String? }`
  - Artifact tracking: `artifactHashes: [String: String]`

- **Current Data Model** (`ModelSpec` in `ModelContracts.swift`) provides only:
  - Core identity: `modelId`, `modelHash`, `taskKind`, `backendFormat`
  - Provenance: `source`, `trustTier`, `license` (String only)
  - Limited metadata: `dimension`, `tokenizerHash`

- **Database Layer** (`ModelRegistryEntry` in `ModelRegistryTypes.swift`) has:
  - Import-time fields: `importedAt`, `licenseDecision`, `artifactHash`
  - Backend compatibility matrix
  - **Missing:** Runtime status, usage stats, storage info

### Solution: Enhanced Model Registry Entry

Create a **r

ich `ModelRegistryEntry`** that wraps `ModelSpec` with runtime metadata:

```swift
// Sources/AnigmaAppMac/Model/Registry/ModelRegistryTypes.swift

public struct ModelRegistryEntry: Identifiable, Codable, Sendable, Hashable {
    // Core spec (immutable)
    public let spec: ModelSpec
    
    // Runtime status
    public let status: ModelStatus
    public let isRunnable: Bool
    
    // Storage tracking
    public let installPath: String
    public let storageBytes: Int64
    public let artifactHashes: [String: String]  // "model", "tokenizer", "config"
    
    // Timestamps
    public let registeredAt: Date
    public let lastVerified: Date
    public var lastUsed: Date?
    
    // Usage analytics
    public var usageCount: Int
    
    // License (structured)
    public let license: LicenseInfo
    
    // Backend compatibility
    public let backendCompatibility: ModelBackendCompatibility
    
    // Computed
    public var id: String { spec.modelId }
    public var modelId: String { spec.modelId }
}

public enum ModelStatus: String, Codable, Sendable, Hashable {
    case ready         // Verified and runnable
    case downloading   // Actively downloading
    case verifying     // Hash verification in progress
    case converting    // Format conversion (e.g., to MLX)
    case degraded      // Files missing or corrupted
    case quarantined   // Policy violation or security issue
}

public struct LicenseInfo: Codable, Sendable, Hashable {
    public let declared: String?     // SPDX identifier or name
    public let allowed: Bool         // Policy decision
    public let reason: String?       // Why allowed/denied
    public let reviewedAt: Date?     // When policy was applied
}
```

### Implementation Steps

#### Step 1: Extend `ModelRegistryTypes.swift` ✅
**File:** `Sources/AnigmaAppMac/Model/Registry/ModelRegistryTypes.swift`

**Changes:**
1. Add `ModelStatus` enum
2. Add `LicenseInfo` struct
3. Enhance `ModelRegistryEntry` with all missing fields
4. Keep `spec: ModelSpec` as the immutable core

#### Step 2: Update Database Schema ✅
**File:** `Sources/AnigmaAppMac/Model/Registry/ModelRegistryStore.swift`

**Changes:**
1. Add columns to `model_registry` table:
   ```sql
   ALTER TABLE model_registry ADD COLUMN status TEXT NOT NULL DEFAULT 'ready';
   ALTER TABLE model_registry ADD COLUMN is_runnable INTEGER NOT NULL DEFAULT 1;
   ALTER TABLE model_registry ADD COLUMN install_path TEXT;
   ALTER TABLE model_registry ADD COLUMN storage_bytes INTEGER DEFAULT 0;
   ALTER TABLE model_registry ADD COLUMN artifact_hashes TEXT; -- JSON blob
   ALTER TABLE model_registry ADD COLUMN last_verified TEXT;
   ALTER TABLE model_registry ADD COLUMN last_used TEXT;
   ALTER TABLE model_registry ADD COLUMN usage_count INTEGER DEFAULT 0;
   ALTER TABLE model_registry ADD COLUMN license_allowed INTEGER;
   ALTER TABLE model_registry ADD COLUMN license_reason TEXT;
   ```

2. Update `insertModel()` to handle new fields
3. Update `getAllModels()` / `getModel()` queries to populate `ModelRegistryEntry` fully

#### Step 3: Fix UI Components ✅
**File:** `Sources/AnigmaAppMac/Components/ModelRegistryCard.swift`

**Changes:**
Remove all 15 TODOs:

| Line | TODO | Fix |
|------|------|-----|
| 187 | `entry.isRunnable not available` | Use `entry.isRunnable` |
| 219 | `entry.storageBytes not available` | Use `formatBytes(entry.storageBytes)` |
| 262 | `entry.status not available` | Use `entry.status` |
| 283 | `entry.status not available` | Implement `statusColor` switch |
| 365 | `entry.status not available` | Show `entry.status.rawValue` |
| 377 | `entry.license is String, not struct` | Use `entry.license.allowed` |
| 391 | `entry.artifactHashes not available` | Iterate `entry.artifactHashes` |
| 417 | `entry.installPath not available` | Show `entry.installPath` |
| 432 | `entry.registeredAt not available` | Show `entry.registeredAt.formatted()` |
| 439 | `entry.lastUsed not available` | Show `entry.lastUsed?.formatted()` |

**File:** `Sources/AnigmaAppMac/Surfaces/ModelRegistry/ModelRegistryView.swift`

**Changes:**
| Line | TODO | Fix |
|------|------|-----|
| 120 | `spec.isRunnable not available` | Filter by `entry.isRunnable` |
| 131 | `spec.task not available` | Filter by `entry.spec.taskKind` |
| 168 | `entry.spec.task not available` | Use `entry.spec.taskKind` |
| 184 | `entry.usageCount not available` | Use `entry.usageCount` |
| 194 | `spec.isRunnable not available` | Check `entry.isRunnable` |

#### Step 4: Update AppStore Integration ✅
**File:** `Sources/AnigmaAppMac/Model/Registry/ModelRegistryAppStore.swift`

**Changes:**
1. Update `loadRegisteredModels()` to load full `ModelRegistryEntry` objects
2. Add `updateModelStatus(_:status:)` helper
3. Add `recordModelUsage(_:)` to increment `usageCount` and update `lastUsed`
4. Add `updateStorageInfo(_:path:bytes:)` after model import completes

#### Step 5: Integration with Import Flow ✅
**File:** `Sources/AnigmaAppMac/AppStore.swift`

**Changes in `importHuggingFaceModel()`:**
1. Set `status = .downloading` when starting
2. Calculate `storageBytes` after download
3. Extract `artifactHashes` for model/tokenizer/config files
4. Set `isRunnable` based on backend compatibility check
5. Populate `LicenseInfo` from HuggingFace metadata
6. Set `status = .ready` on success, `.degraded` on partial failure

---

## Part 2: Cathedral Module Integration

### Problem Analysis

**Current State:**
- `CathedralModule` defined in `Sources/CathedralModule/CathedralModule.swift`
- Returns `CathedralCoordinatorPlaceholder` with no-op implementations
- Used by `AppStore.swift` for evidence recording (lines 2416-2430)
- Comment: "Cathedral module is currently a placeholder"

**Purpose (from comments):**
- "Evidence-driven coordination system for Phase H"
- "Implements tamper-evident coordination with evidence enforcement"
- All coordination requests should flow through Cathedral (see `AnigmaWebServer.swift`)

### Solution: Implement Cathedral Evidence Coordinator

#### Architecture

```
┌─────────────────────────────────────────────┐
│         CathedralCoordinator                │
├─────────────────────────────────────────────┤
│  - validateEvidenceChain(sessionId)         │
│  - recordEvidence(evidence)                 │
│  - enforceViolationPolicy(severity)         │
│  - queryEvidenceChain(filters)              │
└─────────────────────────────────────────────┘
                    │
         ┌──────────┴──────────┐
         │                     │
  ┌──────▼──────┐      ┌──────▼──────┐
  │ EvidenceDB  │      │ PolicyGate  │
  │  (SQLite)   │      │  (Contracts)│
  └─────────────┘      └─────────────┘
```

**Cathedral stores:**
- Evidence chain (linked list of evidence records)
- Violation logs (when operations are blocked)
- Policy decisions (why evidence was accepted/rejected)

### Implementation Steps

#### Step 1: Define Evidence Storage Schema ✅
**File:** `Sources/CathedralModule/EvidenceStorage.swift` (new)

```swift
/// SQLite schema for Cathedral evidence chain
actor EvidenceStorage {
    private let dbPath: String
    private var db: DatabaseConnection?
    
    init(dbPath: String) {
        self.dbPath = dbPath
    }
    
    func initialize() async throws {
        // Create tables:
        // - evidence_chain (id, session_id, evidence_id, hash, timestamp, payload)
        // - evidence_links (parent_hash, child_hash)
        // - policy_decisions (evidence_id, decision, reason, severity, timestamp)
        // - violations (session_id, operation, severity, reason, blocked_at)
    }
    
    func recordEvidence(_ evidence: Evidence) async throws -> String
    func getChain(sessionId: String) async throws -> [Evidence]
    func recordViolation(_ violation: EvidenceViolation) async throws
}
```

#### Step 2: Implement Real CathedralCoordinator ✅
**File:** `Sources/CathedralModule/CathedralCoordinator.swift` (new)

```swift
public actor CathedralCoordinator {
    private let config: CathedralConfig
    private let storage: EvidenceStorage
    private let policyEngine: PolicyEngine
    
    public init(config: CathedralConfig, dbPath: String) async throws {
        self.config = config
        self.storage = EvidenceStorage(dbPath: dbPath)
        self.policyEngine = PolicyEngine(config: config)
        try await storage.initialize()
    }
    
    /// Validate evidence chain for a session
    public func validateEvidenceChain(sessionId: String) async throws -> EvidenceChainValidation {
        let chain = try await storage.getChain(sessionId: sessionId)
        
        // Check chain integrity (hashes link properly)
        let violations = policyEngine.validateChain(chain, config: config)
        
        return EvidenceChainValidation(
            isValid: violations.isEmpty,
            violations: violations,
            chainLength: chain.count,
            lastHash: chain.last?.hash
        )
    }
    
    /// Record evidence and enforce policy
    public func recordEvidence(_ evidence: Evidence) async throws {
        // Policy check
        let decision = await policyEngine.evaluate(evidence, config: config)
        
        if decision.severity >= config.violationActionThreshold {
            // Record violation
            let violation = EvidenceViolation(
                evidenceId: evidence.id,
                severity: decision.severity,
                reason: decision.reason,
                timestamp: Date()
            )
            try await storage.recordViolation(violation)
            throw CathedralError.validationFailed([decision.reason])
        }
        
        // Store evidence
        _ = try await storage.recordEvidence(evidence)
    }
    
    /// Query evidence with filters
    public func queryEvidence(filters: EvidenceFilters) async throws -> [Evidence] {
        return try await storage.query(filters: filters)
    }
}
```

#### Step 3: Implement PolicyEngine ✅
**File:** `Sources/CathedralModule/PolicyEngine.swift` (new)

```swift
actor PolicyEngine {
    func evaluate(_ evidence: Evidence, config: CathedralConfig) async -> PolicyDecision {
        var violations: [String] = []
        var severity: EvidenceViolation.ViolationSeverity = .low
        
        // Check evidence freshness
        if config.requireFreshEvidence {
            let age = Date().timeIntervalSince(evidence.timestamp)
            if age > config.evidenceTimeoutSeconds {
                violations.append("Evidence is stale (age: \(age)s)")
                severity = .high
            }
        }
        
        // Check evidence format
        if config.evidenceValidationMode == .strict {
            // Validate required fields
            if evidence.actionId.isEmpty {
                violations.append("Missing actionId")
                severity = .medium
            }
        }
        
        return PolicyDecision(
            allowed: violations.isEmpty,
            severity: severity,
            reason: violations.joined(separator: "; ")
        )
    }
    
    func validateChain(_ chain: [Evidence], config: CathedralConfig) -> [String] {
        var violations: [String] = []
        
        // Check chain length
        if chain.count > config.maxEvidenceChainLength {
            violations.append("Chain exceeds max length (\(chain.count) > \(config.maxEvidenceChainLength))")
        }
        
        // Check hash links
        for i in 1..<chain.count {
            let previous = chain[i-1]
            let current = chain[i]
            
            if current.parentHash != previous.hash {
                violations.append("Hash chain broken at index \(i)")
            }
        }
        
        return violations
    }
}

struct PolicyDecision {
    let allowed: Bool
    let severity: EvidenceViolation.ViolationSeverity
    let reason: String
}
```

#### Step 4: Update CathedralModule Entry Point ✅
**File:** `Sources/CathedralModule/CathedralModule.swift`

**Changes:**
```swift
public struct CathedralModule {
    public static let version = \"1.0.0\"
    public static let defaultConfig = CathedralConfig()
    
    public static func create(config: CathedralConfig = defaultConfig) async throws -> CathedralCoordinator {
        // Determine DB path (Application Support/Anigma/cathedral.db)
        let dbPath = try getCathedralDatabasePath()
        
        // Create real coordinator
        return try await CathedralCoordinator(config: config, dbPath: dbPath)
    }
    
    private static func getCathedralDatabasePath() throws -> String {
        let fileManager = FileManager.default
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let anigmaDir = appSupport.appendingPathComponent(\"Anigma\", isDirectory: true)
        try fileManager.createDirectory(at: anigmaDir, withIntermediateDirectories: true)
        return anigmaDir.appendingPathComponent(\"cathedral.db\").path
    }
}

// Remove CathedralCoordinatorPlaceholder entirely
```

#### Step 5: Update AppStore Integration ✅
**File:** `Sources/AnigmaAppMac/AppStore.swift`

**Changes:**
```swift
// Line 679-687: Update initialization
init() async {
    // ... existing code ...
    
    // Initialize Cathedral evidence coordinator (REAL implementation)
    let cathedralConfig = CathedralConfig(
        maxEvidenceChainLength: 10000,
        evidenceTimeoutSeconds: 3600,
        violationActionThreshold: .high,
        requireFreshEvidence: true,
        evidenceValidationMode: .strict
    )
    
    // This now returns real CathedralCoordinator, not placeholder
    self.cathedralCoordinator = try await CathedralModule.create(config: cathedralConfig)
    
    // ... rest of init ...
}

// Line 2416-2430: Remove placeholder comment, use real implementation
private func recordExecutionReceipt(_ receipt: Receipt) async {
    let evidence = Evidence(
        id: receipt.deterministicHash,
        actionId: receipt.actionId,
        timestamp: receipt.timestamp,
        payload: receipt.payload,
        hash: receipt.deterministicHash,
        parentHash: nil  // TODO: Link to previous evidence in chain
    )
    
    do {
        // Store via Cathedral's evidence recording (NOW REAL)
        try await cathedralCoordinator.recordEvidence(evidence)
        print(\"📝 [Cathedral] Recording execution receipt: \\(receipt.deterministicHash)\")
    } catch {
        print(\"⚠️ [Cathedral] Failed to record evidence: \\(error)\")
        // Fallback: log to telemetry but don't block operation
        await telemetry.send(
            level: .error,
            message: \"Cathedral evidence recording failed\",
            source: \"Cathedral\",
            metadata: [\"error\": error.localizedDescription]
        )
    }
}
```

#### Step 6: Add Cathedral Admin UI ✅
**File:** `Sources/AnigmaAppMac/Surfaces/CathedralAuditView.swift` (new)

```swift
/// Cathedral evidence audit UI for Admin role
struct CathedralAuditView: View {
    @Environment(AppStore.self) private var store
    @State private var evidenceChain: [Evidence] = []
    @State private var violations: [EvidenceViolation] = []
    @State private var selectedSession: String?
    
    var body: some View {
        VStack {
            // Session selector
            // Evidence chain timeline
            // Violation log
            // Policy decision history
        }
        .task {
            await loadCathedralData()
        }
    }
    
    func loadCathedralData() async {
        // Query Cathedral for evidence chains and violations
    }
}
```

---

## Testing Plan

### Model Registry Tests

**File:** `Tests/AnigmaAppMacTests/ModelRegistryTests.swift`

```swift
class ModelRegistryTests: XCTestCase {
    func testEnhancedEntryRoundTrip() async throws {
        // Create ModelRegistryEntry with all fields
        // Encode to JSON
        // Decode from JSON
        // Assert all fields match
    }
    
    func testDatabasePersistence() async throws {
        // Insert entry with metadata
        // Query back
        // Assert runtime fields preserved
    }
    
    func testUsageTracking() async throws {
        // Record multiple uses
        // Assert usageCount increments
        // Assert lastUsed updates
    }
    
    func testStatusTransitions() async throws {
        // Test: ready -> verifying -> ready
        // Test: downloading -> degraded (on failure)
        // Test: ready -> quarantined (on policy violation)
    }
}
```

### Cathedral Tests

**File:** `Tests/CathedralModuleTests/CathedralCoordinatorTests.swift`

```swift
class CathedralCoordinatorTests: XCTestCase {
    func testEvidenceRecording() async throws {
        let coordinator = try await CathedralCoordinator(
            config: .defaultConfig,
            dbPath: \":memory:\"
        )
        
        let evidence = Evidence(
            id: \"test-1\",
            actionId: \"test-action\",
            timestamp: Date(),
            payload: [:],
            hash: \"hash1\",
            parentHash: nil
        )
        
        try await coordinator.recordEvidence(evidence)
        
        let chain = try await coordinator.queryEvidence(filters: .all)
        XCTAssertEqual(chain.count, 1)
    }
    
    func testChainValidation() async throws {
        // Create chain with broken hash
        // Assert validation fails
    }
    
    func testPolicyEnforcement() async throws {
        // Create evidence that violates policy
        // Assert CathedralError.validationFailed is thrown
    }
    
    func testViolationRecording() async throws {
        // Trigger policy violation
        // Query violations log
        // Assert violation recorded
    }
}
```

---

## Migration Strategy

### Phase 1: Model Registry (Week 1)
- **Day 1-2:** Implement enhanced `ModelRegistryEntry` and database schema
- **Day 3:** Update query logic and AppStore integration
- **Day 4:** Fix all 15 TODOs in UI components
- **Day 5:** Write tests and validate end-to-end

### Phase 2: Cathedral Integration (Week 2)
- **Day 1-2:** Implement `EvidenceStorage`, `PolicyEngine`, `CathedralCoordinator`
- **Day 3:** Update `CathedralModule` entry point and remove placeholder
- **Day 4:** Integrate with `AppStore` and test evidence recording
- **Day 5:** Build Cathedral audit UI for Admin role

### Phase 3: Integration Testing (Week 3)
- **Day 1:** End-to-end test: Import model → verify metadata → run inference → check Cathedral evidence
- **Day 2:** Stress test: Import 20 models, verify all metadata tracked correctly
- **Day 3:** Policy violation test: Trigger stale evidence, verify Cathedral blocks operation
- **Day 4:** UI polish: Ensure all model cards show complete information
- **Day 5:** Documentation and handoff

---

## Success Criteria

### Model Registry
- ✅ All 15 TODOs removed from UI components
- ✅ Model cards show complete information (status, storage, usage stats)
- ✅ Database persists all metadata fields
- ✅ Import flow populates all fields correctly
- ✅ Tests validate round-trip encoding and state transitions

### Cathedral
- ✅ Real `CathedralCoordinator` replaces placeholder
- ✅ Evidence stored in SQLite with hash chains
- ✅ Policy engine enforces freshness and format rules
- ✅ Violations logged and queryable
- ✅ AppStore integrates without fallback comments
- ✅ Admin UI shows evidence chains and violations

---

## Risk Assessment

### Low Risk
- **Model Registry:** Clear schema design, well-contained changes
- **Database migration:** Additive columns, no breaking changes

### Medium Risk
- **Cathedral async initialization:** Need to handle `async throws` in AppStore init
  - **Mitigation:** Use Task.detached() and retry logic
- **Evidence chain performance:** Large chains may slow queries
  - **Mitigation:** Index on `session_id`, add pagination

### High Risk
- **None identified** - Both changes are isolated and well-scoped

---

## Dependencies

### Model Registry
- No external dependencies
- Uses existing DatabaseCore for SQLite operations

### Cathedral
- Depends on: `DatabaseCore`, `ContractsCore`, `TelemetryCore`
- No new external packages required

---

## Next Steps

1. **Review this plan** - Confirm approach and priorities
2. **Create feature branch** - `feature/model-registry-metadata`
3. **Start with Model Registry** - Simpler, no async complications
4. **PR and review** - Get Model Registry merged
5. **Create Cathedral branch** - `feature/cathedral-integration`
6. **Implement Cathedral** - Larger scope, more testing needed
7. **Integration testing** - Both features together
8. **Update roadmap** - Mark Mac app ~95% complete

---

**Estimated Effort:** 2-3 weeks with one developer  
**Current Blockers:** None - ready to start  
**Documentation Status:** This plan + inline code comments
