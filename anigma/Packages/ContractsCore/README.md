# ContractsCore

**Workflow boundary contracts with versioning and governance**

ContractsCore provides the contract system that defines and validates workflow boundaries, ensuring type-safe communication between modules with built-in versioning, schema validation, and audit logging.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   ContractsCore                          │
├─────────────────────────────────────────────────────────┤
│  Contract Layer                                          │
│  ├─ ContractID (name + version + schema hash)           │
│  ├─ WorkflowContract Protocol                           │
│  ├─ ContractEnvelope<Payload>                           │
│  └─ Schema Validation                                    │
├─────────────────────────────────────────────────────────┤
│  Governance Layer                                        │
│  ├─ AuditLogging Protocol                               │
│  ├─ EvidenceRecording Protocol                          │
│  ├─ SecurityZone Enum                                    │
│  └─ TraceContentPolicy Protocol                         │
└─────────────────────────────────────────────────────────┘
```

## Core Concepts

### Contract Identity

Every contract has a unique identity with versioning:

```swift
public struct ContractID: Hashable, Sendable, Codable {
    let name: String        // "harmonia.retrieve.request"
    let major: Int          // Breaking changes
    let minor: Int          // Additive changes
    let schemaHash: String  // Stable snapshot hash
}
```

### Workflow Contracts

All workflow boundaries implement this protocol:

```swift
public protocol WorkflowContract: Sendable, Codable {
    static var id: ContractID { get }
    static func validateInvariants(_ value: Self) throws
}
```

### Contract Envelope

Versioned wrapper that carries identity and validation:

```swift
public struct ContractEnvelope<Payload: WorkflowContract>: Sendable, Codable {
    let id: ContractID
    let payload: Payload
    
    init(_ payload: Payload) {
        self.id = Payload.id
        self.payload = payload
    }
}
```

## Security Zones

Execution isolation levels:

```swift
public enum SecurityZone: String, Sendable, Codable {
    case sandbox            // Untrusted code
    case restricted         // Limited permissions
    case standard           // Normal operations
    case privileged         // Elevated permissions
    case system             // System-level operations
    case selfHost           // Self-hosted execution
    case inspiration        // AI-generated content
    case externalServices   // Third-party services
    case untrusted          // Completely untrusted
}
```

## Audit Logging

### AuditLogging Protocol

```swift
public protocol AuditLogging: Sendable {
    func recordEvent(
        id: UUID,
        type: AuditEventType,
        principal: String?,
        module: String?,
        description: String,
        metadata: [String: String]
    ) async throws
}
```

### Audit Event Types

```swift
public enum AuditEventType: String, Sendable, Codable {
    // Access Control
    case accessGranted
    case accessDenied
    
    // Policy & Governance
    case policyViolation
    case policyEvaluated
    case configChange
    case trustChange
    
    // Automation & Reasoning
    case automationTriggered
    case automationExecuted
    case automationFailed
    
    // Data Lifecycle
    case dataAccessed
    case dataCreated
    case dataModified
    case dataDeleted
    
    // Security
    case threatDetected
    case enforcementAction
    
    // Custom
    case custom
}
```

## Usage Examples

### Defining a Contract

```swift
import ContractsCore

struct PDFRenderRequest: WorkflowContract {
    static let id = ContractID(
        name: "pdf.render.request",
        major: 1,
        minor: 0,
        schemaHash: "abc123..."
    )
    
    let documentId: String
    let pageNumber: Int
    let resolution: Double
    
    static func validateInvariants(_ value: Self) throws {
        guard value.pageNumber > 0 else {
            throw ValidationError.invalidRequest("Page number must be positive")
        }
        guard value.resolution > 0 else {
            throw ValidationError.invalidRequest("Resolution must be positive")
        }
    }
}
```

### Using Contract Envelopes

```swift
let request = PDFRenderRequest(
    documentId: "doc123",
    pageNumber: 1,
    resolution: 144.0
)

let envelope = ContractEnvelope(request)

// Validate before sending
try PDFRenderRequest.validateInvariants(envelope.payload)

// Serialize
let data = try JSONEncoder().encode(envelope)

// Deserialize
let decoded = try JSONDecoder().decode(
    ContractEnvelope<PDFRenderRequest>.self,
    from: data
)
```

### Implementing Audit Logging

```swift
actor MyAuditLogger: AuditLogging {
    func recordEvent(
        id: UUID,
        type: AuditEventType,
        principal: String?,
        module: String?,
        description: String,
        metadata: [String: String]
    ) async throws {
        // Store in database
        try await database.write { db in
            var event = AuditEvent(
                id: id,
                type: type.rawValue,
                principal: principal,
                module: module,
                description: description,
                metadata: metadata,
                timestamp: Date()
            )
            try event.insert(db)
        }
    }
}
```

### Using Audit Logging

```swift
let auditLog = MyAuditLogger()

try await auditLog.recordEvent(
    id: UUID(),
    type: .accessGranted,
    principal: "user@example.com",
    module: "DocumentModule",
    description: "User accessed document",
    metadata: [
        "documentId": "doc123",
        "action": "read"
    ]
)
```

## Evidence Recording

For cryptographic provenance:

```swift
public protocol EvidenceRecording: Sendable {
    func recordEvidence(
        head: EvidenceHead,
        content: Data
    ) async throws
    
    func recordStateDelta(
        sessionId: String,
        delta: StateDelta,
        timestamp: Date
    ) async throws
}

public struct EvidenceHead: Sendable, Codable {
    let headId: String
    let headHash: String
    let timestamp: Date
    let lastActor: String
}
```

## Validation Errors

```swift
public enum ValidationError: Error, Sendable {
    case invalidRequest(String)
    case invalidResponse(String)
    case invalidEvidence(String)
    case policyViolation(String)
    case securityViolation(String)
    case schemaViolation(String)
}
```

## Versioning Strategy

### Major Version Changes
- Breaking changes to contract structure
- Incompatible with previous versions
- Requires migration

### Minor Version Changes
- Additive changes only
- Backward compatible
- Optional new fields

### Schema Hash
- Cryptographic hash of contract structure
- Ensures exact schema match
- Prevents silent corruption

## Best Practices

1. **Always Validate**: Call `validateInvariants` before processing
2. **Version Carefully**: Major bumps break compatibility
3. **Audit Everything**: Log all significant operations
4. **Use Envelopes**: Wrap contracts for versioning
5. **Test Migrations**: Ensure old contracts still work

## Thread Safety

- All protocols require `Sendable` conformance
- Audit logging implementations should be `actor`-based
- Contract validation is pure and thread-safe

## Testing

```swift
import XCTest
@testable import ContractsCore

final class ContractTests: XCTestCase {
    func testContractValidation() throws {
        let request = PDFRenderRequest(
            documentId: "doc123",
            pageNumber: 1,
            resolution: 144.0
        )
        
        // Should not throw
        try PDFRenderRequest.validateInvariants(request)
    }
    
    func testInvalidContract() {
        let request = PDFRenderRequest(
            documentId: "doc123",
            pageNumber: -1,  // Invalid!
            resolution: 144.0
        )
        
        XCTAssertThrowsError(
            try PDFRenderRequest.validateInvariants(request)
        )
    }
}
```

## Dependencies

- **AnigmaPrimitives**: Core types
- **ArgumentParser**: CLI argument parsing

## See Also

- [Contract Design Guide](../../Docs/contract-design.md)
- [Versioning Strategy](../../Docs/contract-versioning.md)
- [Audit Logging Best Practices](../../Docs/audit-logging.md)

## License

Part of the Anigma project. See LICENSE for details.
