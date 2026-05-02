# Cathedral Quick Reference Card

## 🚀 Quick Start

```swift
import CathedralModule

// Create Cathedral facade
let cathedral = await CathedralModule.createFacade()

// Execute operation with evidence enforcement
let operation = MLOperation(
    type: .embedding,
    sessionId: "session-123",
    agentId: "agent-456"
)

let result = try await cathedral.executeOperation(
    operation: operation,
    requirement: .moderate
)
```

## 📁 Module Structure

```
CathedralModule/
├── CathedralModule.swift          # Entry point & configuration
├── Evidence.swift                 # Core evidence types
├── TamperEvidenceSystem.swift     # Hash chain management
├── EvidenceSubstrate.swift        # Enforcement interface
├── CathedralCoordinator.swift     # Coordination logic
├── ForensicMetadataTracker.swift  # Document tracking
├── RetrievalExplainability.swift  # Search explainability
├── EvidenceEnforcement.swift      # Violation detection
└── CathedralFacade.swift          # Unified API
```

## 🎯 Evidence Requirement Levels

| Level | Confidence | Use Case |
|-------|-----------|----------|
| `.none` | 0.0 | System operations |
| `.low` | 0.25 | Informational queries |
| `.moderate` | 0.50 | **Standard operations (DEFAULT)** |
| `.high` | 0.75 | Critical operations |
| `.strict` | 1.0 | Legally binding operations |

## 📊 Evidence Quality Levels

| Level | Confidence | Meaning |
|-------|-----------|---------|
| `.none` | 0.0 | No evidence |
| `.weak` | 0.25 | Minimal evidence |
| `.adequate` | 0.50 | Acceptable evidence |
| `.strong` | 0.75 | High-quality evidence |
| `.verified` | 1.0 | Cryptographically verified |

## ⚠️ Violation Severity

| Severity | Level | Action |
|----------|-------|--------|
| `.low` | 1 | Warning logged |
| `.medium` | 2 | Violation recorded |
| `.high` | 3 | **Operation blocked** |
| `.critical` | 4 | **Quarantine + block** |

## 🔑 Common Operations

### Execute ML Operation
```swift
let operation = MLOperation(
    type: .embedding,  // .retrieval, .generation, .classification
    sessionId: "session-id",
    agentId: "agent-id",
    parameters: ["model": "text-embedding-3"]
)

let result = try await cathedral.executeOperation(
    operation: operation,
    requirement: .moderate
)
```

### Track Document
```swift
// Record acquisition
try await cathedral.recordDocumentAcquisition(
    documentId: "doc-001",
    filePath: "/path/to/file.pdf",
    sessionId: "session-id",
    agentId: "agent-id",
    sourceMetadata: ["source": "upload"]
)

// Record transformation
let transform = DocumentTransformation(
    type: "pdf-to-text",
    toolName: "pdftotext",
    toolVersion: "2.1.0",
    inputHash: "input-hash",
    outputHash: "output-hash"
)

try await cathedral.recordDocumentTransformation(
    documentId: "doc-001",
    transformation: transform,
    sessionId: "session-id",
    agentId: "agent-id"
)
```

### Record Search Query
```swift
let query = SearchQuery(
    text: "contract obligations",
    type: .semantic,
    parameters: QueryParameters(topK: 10, threshold: 0.7)
)

let results = [
    SearchResult(documentId: "doc-001", score: 0.95, rank: 1),
    SearchResult(documentId: "doc-002", score: 0.88, rank: 2)
]

let record = try await cathedral.recordSearchQuery(
    query: query,
    results: results,
    sessionId: "session-id",
    agentId: "agent-id"
)
```

### Verify Reproducibility
```swift
let newResults = await runSearchAgain(query)

let report = try await cathedral.verifyQueryReproducibility(
    originalQueryId: record.id,
    newResults: newResults
)

print("Match rate: \(report.matchRate)")
print("Is reproducible: \(report.isReproducible)")  // >95% match
```

### Get Compliance Report
```swift
let report = try await cathedral.getComplianceReport(
    sessionId: "session-id"
)

print("Chain Valid: \(report.chainValid)")
print("Compliance Score: \(report.complianceScore)")
print("Is Compliant: \(report.isCompliant)")
print("Critical Violations: \(report.criticalViolations)")
print("High Violations: \(report.highViolations)")
```

### Export Evidence Bundle
```swift
let bundle = try await cathedral.exportEvidenceBundle(
    sessionId: "session-id"
)

print("Court Admissible: \(bundle.isCourtAdmissible)")
print("Evidence Count: \(bundle.evidence.count)")
print("Documents: \(bundle.documents.count)")
print("Queries: \(bundle.queries.count)")
print("Bundle Hash: \(bundle.bundleHash)")

// Serialize to JSON
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let json = try encoder.encode(bundle)
try json.write(to: URL(fileURLWithPath: "bundle.json"))
```

## 🏛️ Cathedral Invariants

1. **Evidence is Mandatory Input** - No operation proceeds without evidence
2. **Evidence Chain Integrity is Enforced** - Tampering triggers system failure
3. **Evidence Enforcement Creates Audit Trails** - All actions permanently recorded
4. **Operations Have Finite Execution Windows** - Time-bounded leases (300s default)
5. **Coordination is Idempotent** - Same evidence → same results
6. **Last-Writer-Wins by Default** - Temporal conflict resolution
7. **Conflicts Require Evidence Revalidation** - Fresh evidence after conflicts
8. **Evidence Access is Authenticated** - All access tracked
9. **Evidence Modification is Prohibited** - Append-only chains
10. **Evidence Retirement is Logged** - Deletion creates records

## ⚙️ Configuration

```swift
let config = CathedralConfig(
    maxEvidenceChainLength: 2000,        // Max chain length
    evidenceTimeoutSeconds: 600,         // Evidence freshness (10 min)
    violationActionThreshold: .high,     // Block threshold
    requireFreshEvidence: true,          // Enforce freshness
    evidenceValidationMode: .strict      // Validation strictness
)

let cathedral = await CathedralModule.createFacade(config: config)
```

### Validation Modes

- `.strict` - Block on any violation
- `.lenient` - Allow minor violations, warn
- `.auditOnly` - Log violations, don't block

## 🐛 Error Handling

```swift
do {
    let result = try await cathedral.executeOperation(operation)
} catch CathedralError.evidenceChainCorrupted(let details) {
    print("Chain corrupted: \(details)")
} catch CathedralError.validationFailed(let violations) {
    print("Validation failed: \(violations)")
} catch CathedralError.evidenceTimeout(let details) {
    print("Evidence timeout: \(details)")
} catch {
    print("Unexpected error: \(error)")
}
```

## 📈 Performance Characteristics

| Operation | Complexity | Typical Time |
|-----------|-----------|--------------|
| Evidence recording | O(1) | < 5ms |
| Chain validation | O(n) | < 100ms (1000 events) |
| Evidence lookup | O(1) | < 2ms |
| Bundle export | O(n) | < 500ms |

## 🔗 Integration Points

### With Web Server
```swift
actor AnigmaWebServer {
    let cathedral: CathedralFacade
    
    init() async {
        self.cathedral = await CathedralModule.createFacade()
    }
}
```

### With Agents
```swift
actor DocumentAgent {
    let cathedral: CathedralFacade
    
    func process(_ doc: Document) async throws {
        try await cathedral.recordDocumentAcquisition(...)
    }
}
```

### With Database
```swift
import DatabaseCore

let db = try await DatabaseConnection.connect(...)
let cathedral = await CathedralModule.createFacade(database: db)
```

## 📚 Resources

- **Full Guide**: `Docs/CathedralModuleGuide.md`
- **Demo Script**: `Scripts/cathedral-demo.swift`
- **Invariants**: `Docs/governance/Cathedral-Invariants.md`
- **Implementation**: `CATHEDRAL_FULL_IMPLEMENTATION_COMPLETE.md`

## 🎯 Key Takeaways

✅ **Evidence is mandatory** - No bypass possible  
✅ **Tamper-evident chains** - Cryptographic verification  
✅ **Court-safe bundles** - Legal discovery ready  
✅ **Production-hardened** - Swift 6, actor-safe  
✅ **Institutionally defensible** - Complete audit trails

---

**Version**: 2.0.0 | **Status**: Production Ready | **Swift**: 6.0+
