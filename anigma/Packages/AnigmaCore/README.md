# AnigmaCore

**The foundational ECS, job system, and governance infrastructure for the Anigma platform**

AnigmaCore is the beating heart of Anigma, providing the Entity-Component-System (ECS) architecture, job scheduling, workflow orchestration, and governance primitives that power all capability modules.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     AnigmaCore                           │
├─────────────────────────────────────────────────────────┤
│  ECS Layer          │  Job Layer      │  Governance     │
│  ─────────          │  ─────────      │  ──────────     │
│  • EntityId         │  • Job          │  • KillSwitch   │
│  • Component        │  • Workflow     │  • WriteGate    │
│  • System           │  • Scheduler    │  • AccessCtrl   │
│  • World            │  • JobRecord    │  • Lifecycle    │
└─────────────────────────────────────────────────────────┘
         │                    │                  │
         ▼                    ▼                  ▼
   [Capability Modules] [Pipeline Execution] [Audit Log]
```

## Core Subsystems

### 1. Entity-Component-System (ECS)

The ECS architecture provides a flexible, data-oriented foundation for all Anigma operations.

#### Key Types

**EntityId**
```swift
public struct EntityId: Hashable, Sendable, Codable {
    public let uuid: UUID
}
```

**Component Protocol**
```swift
public protocol Component: Sendable {
    // Marker protocol for all components
}
```

**System Protocols**
```swift
public protocol System {
    func update(world: World, deltaTime: TimeInterval) throws
}

public protocol AsyncSystem: Actor {
    func update(world: World, deltaTime: TimeInterval) async throws
}
```

**World Actor**
```swift
public actor World {
    func createEntity() -> EntityId
    func addComponent<T: Component>(to entity: EntityId, component: T)
    func getComponent<T: Component>(from entity: EntityId) -> T?
    func removeComponent<T: Component>(from entity: EntityId)
    func entities(with componentType: Component.Type) -> [EntityId]
}
```

#### Built-in Components

| Component | Purpose |
|-----------|---------|
| `FileComponent` | File/resource references |
| `QAComponent` | Quality assurance scores |
| `MetadataComponent` | Generic key-value metadata |
| `JobComponent` | Job associations |
| `NameComponent` | Human-readable names |
| `TimestampComponent` | Creation/modification times |
| `TagComponent` | Simple tags |
| `StatusComponent` | Generic status tracking |

### 2. Job System

Asynchronous job scheduling and workflow orchestration.

#### Job Model

```swift
public struct Job: Sendable, Codable {
    public let id: JobId
    public let type: String
    public let priority: JobPriority
    public let payload: Data
    public let retryPolicy: RetryPolicy
}

public enum JobStatus: String, Sendable, Codable {
    case pending
    case running
    case completed
    case failed
    case cancelled
}
```

#### Workflow Abstraction

```swift
public protocol Workflow: Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable
    
    func execute(input: Input) async throws -> Output
}

public actor WorkflowRunner {
    func run<W: Workflow>(_ workflow: W, input: W.Input) async throws -> W.Output
}
```

#### Scheduler

```swift
public actor Scheduler {
    func schedule(_ job: Job) async throws
    func cancel(jobId: JobId) async throws
    func status(for jobId: JobId) async -> JobStatus?
    func stats() async -> SchedulerStats
}
```

### 3. Governance System

Policy-driven behavior control and audit logging.

#### Operating Modes

```swift
public enum OperatingMode: String, Sendable, Codable {
    case readOnly    // No modifications allowed
    case assistive   // Requires human confirmation
    case autopilot   // Autonomous execution with governance
}
```

#### Kill Switch

Emergency halt capability for all write operations.

```swift
public actor KillSwitch {
    func activate(reason: String, by principal: String) async
    func deactivate(by principal: String) async
    func isWriteAllowed(forProject projectId: String?) -> Bool
}
```

#### Write Gate

Quality checks before mutations are allowed.

```swift
public actor WriteGate {
    func registerCheck(_ check: WriteCheck)
    func evaluate(_ proposal: WriteProposal) async -> WriteGateDecision
}

public protocol WriteCheck: Sendable {
    var id: String { get }
    var isBlocking: Bool { get }
    func evaluate(_ proposal: WriteProposal) async -> WriteCheckResult
}
```

#### Access Control

Role-based and attribute-based access control.

```swift
public actor AccessController {
    func canRead(_ request: ReadRequest) async -> AccessDecision
    func canWrite(_ request: WriteRequest) async -> AccessDecision
    func registerPolicy(_ policy: AccessPolicy)
}

public enum DataSensitivity: String, Sendable, Codable {
    case public_
    case internal_
    case confidential
    case restricted
    case secret
}
```

#### Data Lifecycle

Automated data retention and expiration.

```swift
public actor LifecycleManager {
    func registerPolicy(_ policy: RetentionPolicy)
    func enforceRetention(world: World) async throws
}

public struct RetentionPolicy: Sendable {
    let componentType: String
    let retentionDays: Int
    let expirationAction: ExpirationAction
}
```

### 4. Governance Controller

Central coordination of all governance mechanisms.

```swift
public actor GovernanceController {
    public let killSwitch: KillSwitch
    public let writeGate: WriteGate
    public let accessController: AccessController
    public let lifecycleManager: LifecycleManager
    public let auditLog: AuditLogging
    
    func initialize() async
    func getMode() -> OperatingMode
    func setMode(_ mode: OperatingMode, by principal: String) async
    func canWrite(_ proposal: WriteProposal) async -> WriteGateDecision
    func status() async -> GovernanceStatus
}
```

## Usage Examples

### Basic ECS

```swift
import AnigmaCore

// Create world
let world = World()

// Create entity
let entity = await world.createEntity()

// Add components
await world.addComponent(
    to: entity,
    component: NameComponent(name: "My Document")
)

await world.addComponent(
    to: entity,
    component: FileComponent(url: documentURL)
)

// Query entities
let documentsWithNames = await world.entities(
    with: NameComponent.self
)
```

### Job Scheduling

```swift
import AnigmaCore

let scheduler = Scheduler()

// Schedule a job
let job = Job(
    id: JobId(),
    type: "pdf.render",
    priority: .high,
    payload: try JSONEncoder().encode(renderRequest),
    retryPolicy: RetryPolicy(maxAttempts: 3)
)

try await scheduler.schedule(job)

// Check status
if let status = await scheduler.status(for: job.id) {
    print("Job status: \(status)")
}
```

### Workflow Execution

```swift
struct PDFRenderWorkflow: Workflow {
    typealias Input = PDFRenderRequest
    typealias Output = PDFRenderResult
    
    func execute(input: Input) async throws -> Output {
        // Workflow implementation
    }
}

let runner = WorkflowRunner()
let result = try await runner.run(
    PDFRenderWorkflow(),
    input: renderRequest
)
```

### Governance Integration

```swift
let governance = GovernanceController()
await governance.initialize()

// Set operating mode
await governance.setMode(.assistive, by: "admin@example.com")

// Check if write is allowed
let proposal = WriteProposal(
    principal: "user@example.com",
    module: "HarmoniaModule",
    operation: "update_document",
    entityId: documentId
)

let decision = await governance.canWrite(proposal)
if decision.allowed {
    // Proceed with write
} else {
    print("Write blocked: \(decision.failedChecks)")
}
```

### Access Control

```swift
let accessController = AccessController()

// Register policies
await accessController.registerPolicy(
    RoleBasedPolicy(
        requiredRole: "editor",
        allowedOperations: ["read", "write"]
    )
)

// Check access
let request = ReadRequest(
    principal: "user@example.com",
    module: "DocumentModule",
    entityId: documentId
)

let decision = await accessController.canRead(request)
```

## System Integration

### Creating Custom Systems

```swift
struct MySystem: AsyncSystem {
    nonisolated let id = "my.system"
    nonisolated let priority = 100
    
    func update(world: World, deltaTime: TimeInterval) async throws {
        // Get entities with specific components
        let entities = await world.entities(with: MyComponent.self)
        
        for entity in entities {
            if let component = await world.getComponent(
                from: entity,
                as: MyComponent.self
            ) {
                // Process component
                let updated = process(component)
                await world.addComponent(to: entity, component: updated)
            }
        }
    }
}
```

### System Registration

```swift
let world = World()
let system = MySystem()

// Systems run in priority order
await world.registerSystem(system)
await world.update(deltaTime: 1.0/60.0)
```

## Thread Safety

All core types are designed for safe concurrent access:

- **World**: `actor` - all mutations serialized
- **Scheduler**: `actor` - thread-safe job management
- **GovernanceController**: `actor` - coordinated governance
- **All Components**: `Sendable` - safe to pass between actors
- **All Systems**: `AsyncSystem` protocol for actor isolation

## Migration Guide

### From OrchestrumCore (Harmonia)

```swift
// Before
import OrchestrumCore
let entity = Entity()

// After
import AnigmaCore
let entity = await world.createEntity()
```

### From Apertum Accessum

```swift
// Before
let entityID = EntityID()

// After
import AnigmaCore
let entityId = EntityId() // Typealias provided for compatibility
```

## Testing

```swift
import XCTest
@testable import AnigmaCore

final class ECSTests: XCTestCase {
    func testComponentStorage() async throws {
        let world = World()
        let entity = await world.createEntity()
        
        let component = NameComponent(name: "Test")
        await world.addComponent(to: entity, component: component)
        
        let retrieved = await world.getComponent(
            from: entity,
            as: NameComponent.self
        )
        
        XCTAssertEqual(retrieved?.name, "Test")
    }
}
```

## Dependencies

- **AnigmaPrimitives**: Core types and utilities
- **ContractsCore**: Workflow contracts and audit logging
- **DatabaseCore**: Persistence layer

## Performance Characteristics

- **Entity Creation**: O(1)
- **Component Add/Remove**: O(1)
- **Component Query**: O(n) where n = entities with component
- **System Update**: O(n × m) where n = entities, m = components per entity

## Best Practices

1. **Keep Components Small**: Single responsibility principle
2. **Use Systems for Logic**: Don't put logic in components
3. **Leverage Actors**: Use `AsyncSystem` for concurrent operations
4. **Governance First**: Always check governance before mutations
5. **Audit Everything**: Use `AuditLogging` for all significant operations

## See Also

- [Governance Documentation](../../Docs/governance.md)
- [ECS Architecture](../../Docs/ecs-architecture.md)
- [Job System Guide](../../Docs/job-system.md)
- [Capability Modules](../CapabilityCore/README.md)

## License

Part of the Anigma project. See LICENSE for details.
