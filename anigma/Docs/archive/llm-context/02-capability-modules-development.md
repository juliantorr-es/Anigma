# Capability Modules: Development Guide

This document provides comprehensive guidance for developing and working with Anigma's Capability Modules - the feature-rich ecosystem that extends the Core Governance Layer.

## 1. Capability Module Architecture

### 1.1 Module Structure and Responsibilities

**Standard Module Layout:**
```
Sources/{ModuleName}/
├── Components/          # Domain-specific ECS components
├── Systems/            # Domain-specific ECS systems
├── Pipelines/          # Job types and workflows
├── Services/           # Domain services and utilities
├── Extensions/         # Core type extensions
└── {ModuleName}.swift  # Module registration and public API

Tests/{ModuleName}Tests/
├── Components/         # Component tests
├── Systems/           # System tests
├── Pipelines/         # Workflow tests
└── Fixtures/          # Test data and mocks
```

**Module Responsibilities:**
- Domain-specific business logic
- ECS components and systems for the domain
- Job types and workflows for domain operations
- Integration with Core Governance Layer
- Domain-specific testing and fixtures

### 1.2 Module Registration Pattern

**Standard Registration Function:**
```swift
// In Sources/{ModuleName}/{ModuleName}.swift
import AnigmaCore
import DatabaseCore

public struct {ModuleName} {
    public static func register(
        world: World,
        registry: WorkflowRegistry,
        telemetry: TelemetryService? = nil,
        auditLog: AuditLog? = nil
    ) async throws {
        // Register components
        // Register systems
        // Register workflows
        // Set up telemetry hooks
    }
}
```

**Usage in Application:**
```swift
import {ModuleName}

// During application startup
try await {ModuleName}.register(
    world: world,
    registry: registry,
    telemetry: telemetry,
    auditLog: auditLog
)
```

## 2. Architectural Reuse Requirements

### 2.1 Mandatory "Search Before Create" Workflow

**Step 1: Search Existing Abstractions**
```bash
# Search for similar components
rg -t swift "struct.*:.*Component" Sources/*/Components/

# Search for similar systems
rg -t swift "struct.*:.*System" Sources/*/Systems/

# Search for similar workflows
rg -t swift "struct.*:.*Workflow" Sources/*/Pipelines/

# Search for memory/storage patterns
rg -t swift "Memory|Store|Database" Sources/
```

**Step 2: Evaluate Reuse Options**
- Can existing component be extended?
- Can existing system be generalized?
- Can existing workflow be adapted?
- Can existing service be reused?

**Step 3: Document Decision**
If creating new abstraction is necessary:
```markdown
## Reuse Evaluation for {NewType}

### Considered Options:
1. {ExistingType1} - Rejected because {reason}
2. {ExistingType2} - Rejected because {reason}
3. {ExistingType3} - Rejected because {reason}

### Decision:
Created {NewType} because {justification}
```

### 2.2 Core Abstraction Map

**ECS Patterns:**
```swift
// ✅ CORRECT: Use existing ECS patterns
import AnigmaCore

// Components
struct DocumentComponent: Component, Codable {
    let title: String
    let content: String
    let metadata: [String: String]
}

// Systems
struct DocumentProcessingSystem: System {
    var name: String { "DocumentProcessing" }
    
    func update(world: World) async {
        let documents = await world.query(DocumentComponent.self, ProcessingRequestComponent.self)
        // Process documents
    }
}

// Workflows
struct DocumentWorkflow: Workflow {
    var name: String { "Document Processing" }
    var jobTypeId: String { DocumentJobType.identifier }
    var systemNames: [String] { ["Load", "Process", "Save"] }
}
```

**Memory Patterns:**
```swift
// ✅ CORRECT: Use existing memory patterns
import HarmoniaMemory

// Use TriMemory for structured data
let triMemory = TriMemoryArchitecture()

// Use SQLite stores for persistence
let documentStore = SQLiteDocumentStore(database: database)

// Use HarmoniaMemory for AI operations
let aiMemory = HarmoniaMemory()
```

**Tool Patterns:**
```swift
// ✅ CORRECT: Extend existing tool patterns
import AnigmaCore

// Create tool descriptor
struct OcrTool: ToolDescriptor {
    var name: String { "ocr" }
    var description: String { "Extract text from images" }
    var parameters: [ToolParameter] { [...] }
}

// Extend existing runtime
extension FileToolRuntime {
    func performOcr(on file: URL) async throws -> String {
        // OCR implementation
    }
}

// Use tool orchestrator
let orchestrator = ToolOrchestrator()
await orchestrator.registerTool(OcrTool())
```

## 3. Domain-Specific Module Patterns

### 3.1 DiaplasionModule: Alt-Media Processing

**Core Components:**
```swift
// Document processing
struct DocumentComponent: Component, Codable {
    let path: URL
    let mimeType: String
    let size: Int64
    let checksum: String
}

// OCR results
struct OcrResultComponent: Component, Codable {
    let text: String
    let confidence: Double
    let boundingBoxes: [CGRect]
    let language: String
}

// Processing status
struct ProcessingStatusComponent: Component, Codable {
    let status: ProcessingStatus
    let progress: Double
    let error: String?
}
```

**Core Systems:**
```swift
// File loading and validation
struct FileLoadSystem: System {
    func update(world: World) async {
        // Load files, validate formats, create entities
    }
}

// OCR processing
struct OcrProcessingSystem: System {
    func update(world: World) async {
        // Process OCR requests, update results
    }
}

// Quality assurance
struct QualityAssuranceSystem: System {
    func update(world: World) async {
        // Validate OCR results, flag issues
    }
}
```

### 3.2 HarmoniaModule: Governed Inference

**Core Components:**
```swift
// Inference requests
struct InferenceRequestComponent: Component, Codable {
    let prompt: String
    let context: [String]
    let model: String
    let temperature: Double
}

// Inference results
struct InferenceResultComponent: Component, Codable {
    let response: String
    let confidence: Double
    let tokenCount: Int
    let processingTime: TimeInterval
}

// Reasoning safety
struct ReasoningSafetyComponent: Component, Codable {
    let safetyScore: Double
    let flaggedContent: [String]
    let policyViolations: [String]
}
```

**Core Systems:**
```swift
// Policy evaluation
struct PolicyEvaluationSystem: System {
    func update(world: World) async {
        // Evaluate requests against governance policies
    }
}

// Inference execution
struct InferenceExecutionSystem: System {
    func update(world: World) async {
        // Execute approved inference requests
    }
}

// Safety monitoring
struct SafetyMonitoringSystem: System {
    func update(world: World) async {
        // Monitor for policy violations and safety issues
    }
}
```

### 3.3 PragmaModule: Work Management

**Core Components:**
```swift
// Work items
struct WorkItemComponent: Component, Codable {
    let title: String
    let description: String
    let priority: Priority
    let assignee: String?
    let dueDate: Date?
}

// Workflow states
struct WorkflowStateComponent: Component, Codable {
    let currentState: String
    let availableTransitions: [String]
    let history: [WorkflowTransition]
}

// Permissions
struct PermissionComponent: Component, Codable {
    let userId: String
    let permissions: [String]
    let constraints: [String]
}
```

## 4. Integration with Core Governance Layer

### 4.1 Harmonia Integration

**Policy Enforcement:**
```swift
// Before executing any operation
let policyResult = await harmonia.evaluatePolicy(
    action: "process_document",
    context: ["user_id": userId, "document_type": docType]
)

if policyResult.allowed {
    // Execute operation
} else {
    // Log policy violation
    await auditLog.logPolicyViolation(policyResult)
}
```

**Evidence Generation:**
```swift
// After completing operation
let evidence = await harmonia.generateEvidence(
    operation: "ocr_processing",
    inputs: ["document_path": documentPath],
    outputs: ["ocr_text": ocrResult],
    agentId: "diaplasion-agent"
)

await accessum.storeEvidence(evidence)
```

### 4.2 DatabaseCore Integration

**Secure Data Access:**
```swift
// Use DatabaseActor for all database operations
let database = DatabaseActor(path: databasePath)

// Parameterized queries to prevent SQL injection
let documents = await database.query(
    "SELECT * FROM documents WHERE user_id = ? AND processed = ?",
    [userId, false]
)

// Transaction safety
try await database.transaction { tx in
    await tx.execute("INSERT INTO processing_logs ...", [...])
    await tx.execute("UPDATE documents SET processed = ? WHERE id = ?", [true, docId])
}
```

### 4.3 Telemetry Integration

**Metrics Collection:**
```swift
// Collect domain-specific metrics
await telemetry.recordMetric(
    name: "ocr_processing_duration",
    value: processingDuration,
    tags: ["document_type": docType, "model": ocrModel]
)

// Error tracking
await telemetry.recordError(
    error: processingError,
    context: ["document_id": docId, "operation": "ocr"]
)
```

## 5. Testing Strategies

### 5.1 Component Testing

**Isolated Component Tests:**
```swift
import XCTest
import AnigmaCore
@testable import DiaplasionModule

class OcrResultComponentTests: XCTestCase {
    func testComponentSerialization() {
        let component = OcrResultComponent(
            text: "Sample text",
            confidence: 0.95,
            boundingBoxes: [CGRect(x: 0, y: 0, width: 100, height: 50)],
            language: "en"
        )
        
        let encoded = try! JSONEncoder().encode(component)
        let decoded = try! JSONDecoder().decode(OcrResultComponent.self, from: encoded)
        
        XCTAssertEqual(component.text, decoded.text)
        XCTAssertEqual(component.confidence, decoded.confidence)
    }
}
```

### 5.2 System Testing

**Mock World Testing:**
```swift
class OcrProcessingSystemTests: XCTestCase {
    func testSystemProcessesOcrRequests() async {
        let world = World()
        let system = OcrProcessingSystem()
        
        // Create test entity
        let entityId = await world.createEntity()
        await world.addComponent(entityId, FileComponent(path: "/test/document.png"))
        await world.addComponent(entityId, OcrRequestComponent(language: "en"))
        
        // Run system
        await system.update(world: world)
        
        // Verify results
        let results = await world.query(OcrResultComponent.self)
        XCTAssertFalse(results.isEmpty)
    }
}
```

### 5.3 Workflow Testing

**End-to-End Workflow Tests:**
```swift
class OcrWorkflowTests: XCTestCase {
    func testOcrWorkflow() async throws {
        let world = World()
        let registry = WorkflowRegistry()
        let runner = WorkflowRunner(world: world, registry: registry)
        
        // Register workflow
        await registry.register(OcrWorkflow())
        
        // Create job
        let job = Job(
            typeId: OcrJobType.identifier,
            inputRefs: ["/test/document.png"],
            metadata: ["language": "en"]
        )
        
        // Run workflow
        await runner.enqueue(job: job)
        await runner.runNext()
        
        // Verify results
        let results = await world.query(OcrResultComponent.self)
        XCTAssertFalse(results.isEmpty)
    }
}
```

## 6. Performance and Scalability

### 6.1 Efficient Entity Queries

**Optimized Query Patterns:**
```swift
// ✅ GOOD: Specific component queries
let documents = await world.query(FileComponent.self, ProcessingRequestComponent.self)

// ❌ AVOID: Broad queries that require filtering
let allEntities = await world.allEntities()
let documents = allEntities.filter { await world.hasComponent($0, FileComponent.self) }
```

### 6.2 Batch Processing

**Efficient Batch Operations:**
```swift
// Process multiple entities efficiently
let documents = await world.query(FileComponent.self, OcrRequestComponent.self)

for batch in documents.chunked(into: 10) {
    await withTaskGroup(of: Void.self) { group in
        for (entity, file, request) in batch {
            group.addTask {
                await self.processDocument(entity: entity, file: file, request: request)
            }
        }
    }
}
```

### 6.3 Memory Management

**Resource Cleanup:**
```swift
// Clean up temporary components
struct TemporaryFileComponent: Component, Codable {
    let path: URL
    let cleanupDate: Date
}

// Cleanup system
struct TemporaryFileCleanupSystem: System {
    func update(world: World) async {
        let tempFiles = await world.query(TemporaryFileComponent.self)
        let now = Date()
        
        for (entity, tempFile) in tempFiles {
            if tempFile.cleanupDate < now {
                try? FileManager.default.removeItem(at: tempFile.path)
                await world.removeComponent(entity, componentType: TemporaryFileComponent.self)
            }
        }
    }
}
```

## 7. Error Handling and Resilience

### 7.1 Error Component Pattern

**Structured Error Handling:**
```swift
struct ErrorComponent: Component, Codable {
    let code: String
    let message: String
    let timestamp: Date
    let context: [String: String]
    let retryable: Bool
}

// Error handling system
struct ErrorHandlingSystem: System {
    func update(world: World) async {
        let errors = await world.query(ErrorComponent.self)
        
        for (entity, error) in errors {
            if error.retryable {
                // Schedule retry
                await scheduleRetry(for: entity, error: error)
            } else {
                // Log and mark as failed
                await logPermanentFailure(entity: entity, error: error)
            }
        }
    }
}
```

### 7.2 Retry Logic

**Exponential Backoff:**
```swift
struct RetryComponent: Component, Codable {
    let attempt: Int
    let maxAttempts: Int
    let nextRetry: Date
    let backoffMultiplier: Double
}

struct RetrySystem: System {
    func update(world: World) async {
        let retries = await world.query(RetryComponent.self)
        let now = Date()
        
        for (entity, retry) in retries {
            if retry.nextRetry <= now && retry.attempt < retry.maxAttempts {
                // Retry the operation
                await retryOperation(for: entity, attempt: retry.attempt + 1)
            } else if retry.attempt >= retry.maxAttempts {
                // Mark as permanently failed
                await markAsFailed(entity: entity)
            }
        }
    }
}
```

## 8. Documentation and Maintenance

### 8.1 Code Documentation

**Public API Documentation:**
```swift
/// Processes documents using OCR to extract text content
/// 
/// This system handles OCR processing for documents that have both
/// a FileComponent and OcrRequestComponent. It updates entities with
/// OcrResultComponent containing the extracted text and metadata.
/// 
/// - Note: Requires OCR model to be configured in Harmonia
/// - Important: All OCR operations are logged for audit purposes
public struct OcrProcessingSystem: System {
    /// The system name used for registration and logging
    public var name: String { "OcrProcessing" }
    
    /// Processes all pending OCR requests
    /// 
    /// This method queries for entities with OCR requests and processes
    /// them using the configured OCR model. Results are stored as
    /// OcrResultComponent on the same entities.
    /// 
    /// - Parameter world: The ECS world containing entities to process
    public func update(world: World) async {
        // Implementation
    }
}
```

### 8.2 Tech Debt Tracking

**Stub Tracking:**
```swift
#warning("STUB: Advanced OCR language detection not implemented")
// STUB_TRACK: DiaplasionModule - Advanced language detection for OCR. See Docs/TechDebt.md.

struct LanguageDetectionComponent: Component, Codable {
    let detectedLanguage: String
    let confidence: Double
}
```

**TechDebt.md Entry:**
```markdown
## DiaplasionModule - Advanced Language Detection

### Description:
Current OCR processing assumes English language. Need to implement
automatic language detection for multilingual documents.

### Impact:
- Reduced OCR accuracy for non-English documents
- Manual language specification required
- Limited international support

### Implementation Plan:
1. Research language detection libraries
2. Integrate with OCR pipeline
3. Add language detection tests
4. Update documentation

### Priority: Medium
### Target: Phase 6
```

Capability Modules provide the rich functionality that makes Anigma useful while maintaining security and governance through strict adherence to Core Layer contracts and patterns.