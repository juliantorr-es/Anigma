# DataEngine Event-Driven Migration Plan

## 📋 Migration Overview

**Module**: DataEngine
**Priority**: Highest (Central data processing engine)
**Current Dependencies**: DataCore, AnigmaPrimitives, AnigmaSystemSpine
**New Dependencies**: DataCore, AnigmaPrimitives, AnigmaSystemSpine, **AnigmaEvents**
**Migration Strategy**: Event-driven data processing pipeline

## 🎯 Migration Goals

1. **Decouple DataEngine** from direct dependencies on other modules
2. **Publish data processing events** for other modules to consume
3. **Subscribe to data source events** to trigger processing
4. **Enable real-time monitoring** of data processing operations
5. **Maintain backward compatibility** during transition

## 🏗️ Current Architecture Analysis

### Current DataEngine Operations

1. **Ingestion** - `ingest(source: URL)` → Artifact
2. **Profiling** - `profile(artifact: Artifact)` → ProfileArtifact
3. **Transformation** - `transform(artifact: Artifact, transform: TransformIR)` → (Artifact, ChangeArtifact)
4. **Query** - `query(viewSpec: ViewSpec)` → Artifact
5. **Rendering** - `render(viewSpec: ViewSpec)` → Artifact

### Current Dependencies

- **DataCore** - Core data structures (Artifact, ViewSpec, etc.)
- **AnigmaPrimitives** - Basic types and utilities
- **AnigmaSystemSpine** - System-level abstractions

### Current Communication Patterns

- **Direct method calls** from dependent modules
- **Synchronous operations** with some async/await
- **No event-based communication**
- **Tight coupling** with calling modules

## 🔄 Event-Driven Architecture Design

### Event Flow Design

```
[External Trigger] → (Data Processing Event) → [DataEngine]
[DataEngine] → (Data Processing Events) → [Subscribers]
[DataEngine] → (Work Item Events) → [Workflows]
[DataEngine] → (UI Events) → [DataUI]
```

### Event Types to Use

**Published by DataEngine:**
- `DataProcessingStartedEvent` - When processing begins
- `DataProcessingProgressEvent` - Progress updates
- `DataProcessingCompletedEvent` - When processing completes
- `DataProcessingFailedEvent` - When processing fails
- `WorkItemCreatedEvent` - When work items are created
- `WorkItemProgressEvent` - Work item progress
- `WorkItemCompletedEvent` - When work items complete

**Subscribed by DataEngine:**
- `DataProcessingStartedEvent` - From external triggers
- `WorkItemCreatedEvent` - From workflows
- `UIInteractionEvent` - From UI (optional)

### Event-Driven Pipeline

1. **Event Reception** - DataEngine subscribes to relevant events
2. **Event Processing** - Events trigger data processing operations
3. **Event Publishing** - DataEngine publishes progress and completion events
4. **Event Propagation** - Subscribers react to DataEngine events

## 🔧 Implementation Plan

### Step 1: Add AnigmaEvents Dependency

**File**: `anigma/Package.swift`

```swift
.target(name: "DataEngine", 
        dependencies: ["DataCore", "AnigmaPrimitives", "AnigmaSystemSpine", "AnigmaEvents"], 
        path: "Packages/DataEngine", 
        swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)])
```

### Step 2: Create Event-Driven DataEngine Extension

**File**: `anigma/Packages/DataEngine/DataEngine+Events.swift`

```swift
import AnigmaEvents
import Foundation

public extension DataEngine {
    // Event-driven ingestion
    func ingestWithEvents(source: URL, options: IngestionOptions = IngestionOptions()) async throws -> Artifact {
        let processingId = UUID().uuidString
        
        // Publish started event
        await sharedEventBus.publish(
            DataProcessingStartedEvent(
                processingId: processingId,
                dataSourceId: source.lastPathComponent,
                dataType: "url",
                initiatedBy: "DataEngine.ingest",
                metadata: [
                    "source": source.absoluteString,
                    "options": "default"
                ]
            ),
            source: "DataEngine"
        )
        
        defer {
            // Publish completion event
            let duration = Date().timeIntervalSince(Date())
            await sharedEventBus.publish(
                DataProcessingCompletedEvent(
                    processingId: processingId,
                    duration: duration,
                    success: true,
                    processedItems: 1,
                    metadata: ["artifactId": artifact.id]
                ),
                source: "DataEngine"
            )
        }
        
        // Publish progress event
        await sharedEventBus.publish(
            DataProcessingProgressEvent(
                processingId: processingId,
                progress: 0.5,
                processedItems: 0,
                totalItems: 1,
                message: "Starting ingestion",
                stage: "ingestion"
            ),
            source: "DataEngine"
        )
        
        // Perform actual ingestion
        let artifact = try await ingest(source: source, options: options)
        
        // Publish progress event
        await sharedEventBus.publish(
            DataProcessingProgressEvent(
                processingId: processingId,
                progress: 1.0,
                processedItems: 1,
                totalItems: 1,
                message: "Ingestion completed",
                stage: "ingestion"
            ),
            source: "DataEngine"
        )
        
        return artifact
    }
    
    // Event-driven profiling
    func profileWithEvents(artifact: Artifact) async throws -> ProfileArtifact {
        let processingId = UUID().uuidString
        
        // Publish started event
        await sharedEventBus.publish(
            DataProcessingStartedEvent(
                processingId: processingId,
                dataSourceId: artifact.id,
                dataType: "artifact",
                initiatedBy: "DataEngine.profile",
                metadata: ["artifactType": artifact.type.rawValue]
            ),
            source: "DataEngine"
        )
        
        defer {
            // Publish completion event
            let duration = Date().timeIntervalSince(Date())
            await sharedEventBus.publish(
                DataProcessingCompletedEvent(
                    processingId: processingId,
                    duration: duration,
                    success: true,
                    processedItems: 1,
                    metadata: ["profileId": profile.id]
                ),
                source: "DataEngine"
            )
        }
        
        // Perform actual profiling
        let profile = try await profile(artifact: artifact)
        
        return profile
    }
    
    // Event-driven transformation
    func transformWithEvents(artifact: Artifact, transform: TransformIR) async throws -> (Artifact, ChangeArtifact) {
        let processingId = UUID().uuidString
        
        // Publish started event
        await sharedEventBus.publish(
            DataProcessingStartedEvent(
                processingId: processingId,
                dataSourceId: artifact.id,
                dataType: "transformation",
                initiatedBy: "DataEngine.transform",
                metadata: ["transformType": transform.kind.rawValue]
            ),
            source: "DataEngine"
        )
        
        defer {
            // Publish completion event
            let duration = Date().timeIntervalSince(Date())
            await sharedEventBus.publish(
                DataProcessingCompletedEvent(
                    processingId: processingId,
                    duration: duration,
                    success: true,
                    processedItems: 1,
                    metadata: ["newArtifactId": newArtifact.id]
                ),
                source: "DataEngine"
            )
        }
        
        // Perform actual transformation
        let (newArtifact, change) = try await transform(artifact: artifact, transform: transform)
        
        return (newArtifact, change)
    }
    
    // Event-driven query
    func queryWithEvents(viewSpec: ViewSpec) async throws -> Artifact {
        let processingId = UUID().uuidString
        
        // Publish started event
        await sharedEventBus.publish(
            DataProcessingStartedEvent(
                processingId: processingId,
                dataSourceId: viewSpec.sourceSnapshotId,
                dataType: "query",
                initiatedBy: "DataEngine.query",
                metadata: ["queryType": "view"]
            ),
            source: "DataEngine"
        )
        
        defer {
            // Publish completion event
            let duration = Date().timeIntervalSince(Date())
            await sharedEventBus.publish(
                DataProcessingCompletedEvent(
                    processingId: processingId,
                    duration: duration,
                    success: true,
                    processedItems: 1,
                    metadata: ["resultId": result.id]
                ),
                source: "DataEngine"
            )
        }
        
        // Perform actual query
        let result = try await query(viewSpec: viewSpec)
        
        return result
    }
    
    // Subscribe to external events
    func setupEventSubscriptions() async {
        // Subscribe to data processing requests
        await sharedEventBus.subscribe(to: DataProcessingStartedEvent.self) { [weak self] event in
            guard let self = self else { return }
            
            // Handle external data processing requests
            if event.initiatedBy != "DataEngine" {
                Task {
                    do {
                        // Process based on data type
                        switch event.dataType {
                        case "url":
                            if let url = URL(string: event.metadata?["source"] ?? "") {
                                _ = try await self.ingest(source: url)
                            }
                        case "artifact":
                            // Would need artifact lookup
                            break
                        default:
                            break
                        }
                    } catch {
                        // Publish failure event
                        await sharedEventBus.publish(
                            DataProcessingFailedEvent(
                                processingId: event.processingId,
                                error: error,
                                processedItems: 0
                            ),
                            source: "DataEngine"
                        )
                    }
                }
            }
        }
        
        // Subscribe to work item events
        await sharedEventBus.subscribe(to: WorkItemCreatedEvent.self) { [weak self] event in
            guard let self = self else { return }
            
            // Handle work item creation
            if event.workItemType == "data_processing" {
                Task {
                    // Process work item based on metadata
                    if let sourceUrlString = event.metadata?["source"] {
                        if let url = URL(string: sourceUrlString) {
                            _ = try? await self.ingest(source: url)
                        }
                    }
                }
            }
        }
    }
}
```

### Step 3: Update DataEngine Main File

**File**: `anigma/Packages/DataEngine/DataEngine.swift`

Add event subscription setup to initializer:

```swift
public actor DataEngine {
    // ... existing properties ...
    
    private var eventSubscriptionIds: [UUID] = []
    
    public init(policy: DataGovernancePolicy = .standard, cacheConfig: CacheConfig = CacheConfig()) {
        self.policy = policy
        self.cacheManager = CacheManager(config: cacheConfig)
        
        // Setup event subscriptions
        Task { await setupEventSubscriptions() }
    }
    
    // ... existing methods ...
    
    deinit {
        // Cleanup event subscriptions
        for id in eventSubscriptionIds {
            Task { await sharedEventBus.unsubscribe(id: id) }
        }
    }
    
    // ... rest of the file ...
}
```

### Step 4: Create Event-Driven DataEngine Tests

**File**: `anigma/Packages/DataEngine/Tests/DataEngineEventTests.swift`

```swift
import Testing
import DataEngine
import AnigmaEvents

struct DataEngineEventTests {
    // MARK: - Event Publishing Tests

    @Test func testIngestionPublishesEvents() async throws {
        // Given
        let engine = DataEngine()
        let mockBus = EventTestingFramework.makeMockEventBus()
        
        // When - Use event-driven ingestion
        let url = URL(string: "https://example.com/data.json")!
        _ = try await engine.ingestWithEvents(source: url)
        
        // Then - Verify events were published
        let startedEvents = mockBus.publishedEvents(of: DataProcessingStartedEvent.self)
        let progressEvents = mockBus.publishedEvents(of: DataProcessingProgressEvent.self)
        let completedEvents = mockBus.publishedEvents(of: DataProcessingCompletedEvent.self)
        
        #expect(startedEvents.count >= 1)
        #expect(progressEvents.count >= 2) // 50% and 100%
        #expect(completedEvents.count >= 1)
    }

    @Test func testTransformationPublishesEvents() async throws {
        // Given
        let engine = DataEngine()
        let mockBus = EventTestingFramework.makeMockEventBus()
        
        // When - Create test artifact
        let artifact = Artifact(
            id: "test-artifact",
            type: .tabularIR,
            contentHash: "test-hash",
            metadata: ["rowCount": "100"]
        )
        
        let transform = TransformIR(
            kind: .filter,
            predicate: "column > 0"
        )
        
        // When - Use event-driven transformation
        _ = try await engine.transformWithEvents(artifact: artifact, transform: transform)
        
        // Then - Verify events were published
        let startedEvents = mockBus.publishedEvents(of: DataProcessingStartedEvent.self)
        let completedEvents = mockBus.publishedEvents(of: DataProcessingCompletedEvent.self)
        
        #expect(startedEvents.count >= 1)
        #expect(completedEvents.count >= 1)
    }

    // MARK: - Event Subscription Tests

    @Test func testEventSubscriptions() async throws {
        // Given
        let engine = DataEngine()
        let mockBus = EventTestingFramework.makeMockEventBus()
        
        // When - Publish data processing event
        let event = DataProcessingStartedEvent(
            processingId: "test-123",
            dataSourceId: "test-source",
            dataType: "url",
            initiatedBy: "External",
            metadata: ["source": "https://example.com/data.json"]
        )
        
        await mockBus.publish(event, source: "External")
        
        // Then - DataEngine should process it
        try await Task.sleep(for: .milliseconds(100))
        
        // Verify processing completed
        let completedEvents = mockBus.publishedEvents(of: DataProcessingCompletedEvent.self)
        #expect(completedEvents.count >= 1)
    }

    // MARK: - Integration Tests

    @Test func testEventDrivenPipeline() async throws {
        // Given
        let engine = DataEngine()
        let mockBus = EventTestingFramework.makeMockEventBus()
        
        // When - Create a work item
        let workItemEvent = WorkItemCreatedEvent(
            workItemId: "workitem-123",
            workItemType: "data_processing",
            priority: 1,
            metadata: ["source": "https://example.com/data.json"]
        )
        
        await mockBus.publish(workItemEvent, source: "Workflows")
        
        // Then - DataEngine should process the work item
        try await Task.sleep(for: .milliseconds(200))
        
        // Verify full pipeline
        let startedEvents = mockBus.publishedEvents(of: DataProcessingStartedEvent.self)
        let progressEvents = mockBus.publishedEvents(of: DataProcessingProgressEvent.self)
        let completedEvents = mockBus.publishedEvents(of: DataProcessingCompletedEvent.self)
        
        #expect(startedEvents.count >= 1)
        #expect(progressEvents.count >= 2)
        #expect(completedEvents.count >= 1)
    }
}
```

## 📊 Migration Benefits

### 1. **Decoupled Architecture**
- DataEngine no longer requires direct dependencies on calling modules
- Modules communicate via events instead of method calls
- Easier to test and develop modules in isolation

### 2. **Real-Time Monitoring**
- All data processing operations visible through events
- Easy to add monitoring and analytics
- Enables audit trails and replay capabilities

### 3. **Scalability**
- Multiple consumers can react to same events
- Enables distributed processing scenarios
- Better load balancing capabilities

### 4. **Error Handling**
- Comprehensive error events with stack traces
- Easy to implement retry logic
- Better error propagation and handling

### 5. **Backward Compatibility**
- Original methods remain unchanged
- New event-driven methods are additions
- Gradual migration path for calling modules

## 🚀 Implementation Timeline

### Week 3-4: DataEngine Migration
- **Day 1-2**: Add AnigmaEvents dependency and create event-driven extensions
- **Day 3-4**: Implement event publishing in all data processing methods
- **Day 5-6**: Implement event subscriptions for external triggers
- **Day 7**: Create comprehensive test suite
- **Day 8**: Test and debug event-driven pipeline

### Week 5-6: Workflows Integration
- **Day 9-10**: Integrate with existing workflow events
- **Day 11-12**: Test event-driven workflow coordination
- **Day 13**: Optimize event flow between DataEngine and Workflows

## ✅ Success Criteria

1. **Event Publishing** - All data processing operations publish appropriate events
2. **Event Subscription** - DataEngine responds to external events
3. **Backward Compatibility** - Original methods still work
4. **Test Coverage** - 100% test coverage for new functionality
5. **Performance** - No significant performance degradation
6. **Reliability** - Event-driven operations as reliable as original

## 📋 Next Steps

1. **Implement DataEngine+Events.swift** - Event-driven extensions
2. **Update Package.swift** - Add AnigmaEvents dependency
3. **Update DataEngine.swift** - Add event subscription setup
4. **Create DataEngineEventTests.swift** - Comprehensive test suite
5. **Test Integration** - Verify event flows work correctly
6. **Document Migration** - Create migration guide for calling modules

## 🎯 Conclusion

The DataEngine migration to event-driven architecture will:
- Decouple the central data processing engine from direct dependencies
- Enable real-time monitoring and observability
- Provide a foundation for scalable, distributed processing
- Maintain backward compatibility during transition
- Improve error handling and reliability

This migration is the highest priority because DataEngine is the central data processing hub that all other modules depend on. Successfully migrating DataEngine will demonstrate the event-driven pattern and provide a template for migrating other modules.