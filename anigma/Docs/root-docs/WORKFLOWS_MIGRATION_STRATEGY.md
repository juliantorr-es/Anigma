# Workflows Event-Driven Migration Strategy

## 🎯 Migration Overview

**Module**: Workflows
**Priority**: High (Tight integration with existing events)
**Current Dependencies**: DataCore, DataEngine, AnigmaSystemSpine
**New Dependencies**: DataCore, DataEngine, AnigmaSystemSpine, **AnigmaEvents**
**Migration Strategy**: Event-driven workflow coordination

## 🏗️ Current Architecture Analysis

### Current Workflows Operations

1. **Workflow Execution** - `execute(workflow: WorkflowDefinition, context: String)` → WorkflowResult
2. **Workflow Steps** - Ingest, Profile, Transform, Query, Render, Export
3. **Artifact Management** - Creates and passes artifacts between steps
4. **Job Integration** - Uses JobEngine for background processing

### Current Dependencies

- **DataCore** - Core data structures (Artifact, ViewSpec, etc.)
- **DataEngine** - Data processing operations (ingest, profile, transform, query)
- **AnigmaSystemSpine** - System-level abstractions

### Current Communication Patterns

- **Direct method calls** to DataEngine for data processing
- **Synchronous workflow execution** with async/await
- **No event-based communication**
- **Tight coupling** with DataEngine

## 🔄 Event-Driven Architecture Design

### Event Flow Design

```
[Workflows] → (Workflow Events) → [HarmoniaModule]
[Workflows] → (Work Item Events) → [DataEngine]
[DataEngine] → (Data Processing Events) → [Workflows]
[Workflows] → (Workflow Progress Events) → [UI]
```

### Event Types to Use

**Published by Workflows:**
- `WorkflowStartedEvent` - When workflow execution begins
- `WorkflowProgressEvent` - Progress updates during execution
- `WorkflowCompletedEvent` - When workflow completes
- `WorkflowFailedEvent` - When workflow fails
- `WorkItemCreatedEvent` - When creating work items for DataEngine

**Subscribed by Workflows:**
- `DataProcessingCompletedEvent` - From DataEngine (step completion)
- `DataProcessingFailedEvent` - From DataEngine (step failure)
- `WorkItemCompletedEvent` - From DataEngine (work item completion)
- `WorkItemFailedEvent` - From DataEngine (work item failure)

### Event-Driven Workflow Pipeline

1. **Workflow Start** - Publish WorkflowStartedEvent
2. **Step Execution** - Create work items or call DataEngine directly
3. **Event Reception** - Receive data processing events from DataEngine
4. **Progress Updates** - Publish WorkflowProgressEvent
5. **Workflow Completion** - Publish WorkflowCompletedEvent

## 🔧 Implementation Plan

### Step 1: Add AnigmaEvents Dependency

**File**: `anigma/Package.swift`

```swift
.target(name: "Workflows", 
        dependencies: ["DataCore", "DataEngine", "AnigmaSystemSpine", "AnigmaEvents"], 
        path: "Packages/Workflows", 
        swiftSettings: strictConcurrencySettings + [.interoperabilityMode(.Cxx)])
```

### Step 2: Create Event-Driven Workflow Engine Extension

**File**: `anigma/Packages/Workflows/WorkflowEngine+Events.swift`

```swift
import AnigmaEvents
import Foundation
import DataCore
import DataEngine
import AnigmaSystemSpine

public extension WorkflowEngine {
    // MARK: - Event-Driven Workflow Execution

    /// Event-driven workflow execution that publishes workflow events
    /// - Parameters:
    ///   - workflow: Workflow definition
    ///   - context: Execution context
    /// - Returns: Workflow result
    /// - Throws: Errors during execution
    func executeWithEvents(workflow: WorkflowDefinition, context: String) async throws -> WorkflowResult {
        let workflowId = UUID().uuidString
        let startTime = Date()
        
        // Publish workflow started event
        await sharedEventBus.publish(
            WorkflowStartedEvent(
                workflowId: workflowId,
                workflowName: workflow.name,
                initiatedBy: "Workflows",
                metadata: [
                    "workflowType": workflow.type.rawValue,
                    "stepCount": String(workflow.steps.count),
                    "context": context
                ]
            ),
            source: "Workflows"
        )
        
        defer {
            let duration = Date().timeIntervalSince(startTime)
            
            if let error = error {
                // Publish workflow failed event
                await sharedEventBus.publish(
                    WorkflowFailedEvent(
                        workflowId: workflowId,
                        error: error,
                        errorMessage: error.localizedDescription
                    ),
                    source: "Workflows"
                )
            } else {
                // Publish workflow completed event
                await sharedEventBus.publish(
                    WorkflowCompletedEvent(
                        workflowId: workflowId,
                        result: "Workflow completed successfully",
                        duration: duration,
                        success: true
                    ),
                    source: "Workflows"
                )
            }
        }
        
        var artifacts: [Artifact] = []
        let receipts: [Receipt] = []
        var lastArtifact: Artifact?
        var knownArtifacts: [String: Artifact] = [:]
        
        // Execute workflow steps with event-driven coordination
        for (index, step) in workflow.steps.enumerated() {
            let stepProgress = Double(index) / Double(workflow.steps.count)
            
            // Publish progress event
            await sharedEventBus.publish(
                WorkflowProgressEvent(
                    workflowId: workflowId,
                    progress: stepProgress,
                    message: "Executing step \(index + 1) of \(workflow.steps.count): \(step.description)",
                    stepName: step.description
                ),
                source: "Workflows"
            )
            
            // Execute step based on type
            switch step {
            case .ingest(let source):
                let artifact = try await executeIngestStep(source: source, context: context, workflowId: workflowId)
                artifacts.append(artifact)
                knownArtifacts[artifact.id] = artifact
                lastArtifact = artifact
                
            case .profile:
                if let input = lastArtifact {
                    let artifact = try await executeProfileStep(input: input, workflowId: workflowId)
                    artifacts.append(artifact)
                    knownArtifacts[artifact.id] = artifact
                    lastArtifact = artifact
                }
                
            case .transform(let transform):
                if let input = lastArtifact {
                    let (newArtifact, change) = try await executeTransformStep(
                        input: input,
                        transform: transform,
                        workflowId: workflowId
                    )
                    artifacts.append(newArtifact)
                    knownArtifacts[newArtifact.id] = newArtifact
                    lastArtifact = newArtifact
                }
                
            case .query(let viewSpec):
                if let input = lastArtifact {
                    let artifact = try await executeQueryStep(
                        viewSpec: viewSpec,
                        input: input,
                        workflowId: workflowId
                    )
                    artifacts.append(artifact)
                    lastArtifact = artifact
                }
                
            case .render(let viewSpec):
                if let input = lastArtifact {
                    let artifact = try await executeRenderStep(
                        viewSpec: viewSpec,
                        input: input,
                        workflowId: workflowId
                    )
                    artifacts.append(artifact)
                    lastArtifact = artifact
                }
                
            case .export(let format):
                if let input = lastArtifact {
                    try await executeExportStep(
                        format: format,
                        input: input,
                        workflowId: workflowId
                    )
                }
            }
        }
        
        return WorkflowResult(workflowId: workflowId, artifacts: artifacts, receipts: receipts)
    }
    
    // MARK: - Event-Driven Step Execution

    /// Execute ingestion step with event-driven coordination
    private func executeIngestStep(source: URL, context: String, workflowId: String) async throws -> Artifact {
        let stepId = UUID().uuidString
        
        // Publish step started event
        await sharedEventBus.publish(
            WorkflowProgressEvent(
                workflowId: workflowId,
                progress: 0.0,
                message: "Starting ingestion",
                stepName: "ingest"
            ),
            source: "Workflows"
        )
        
        do {
            // Use event-driven ingestion from DataEngine
            let artifact = try await dataEngine.ingestWithEvents(source: source)
            
            // Publish step completed event
            await sharedEventBus.publish(
                WorkflowProgressEvent(
                    workflowId: workflowId,
                    progress: 1.0,
                    message: "Ingestion completed",
                    stepName: "ingest"
                ),
                source: "Workflows"
            )
            
            return artifact
            
        } catch {
            // Publish step failed event
            await sharedEventBus.publish(
                WorkflowProgressEvent(
                    workflowId: workflowId,
                    progress: 0.0,
                    message: "Ingestion failed: \(error.localizedDescription)",
                    stepName: "ingest"
                ),
                source: "Workflows"
            )
            
            throw error
        }
    }
    
    /// Execute profile step with event-driven coordination
    private func executeProfileStep(input: Artifact, workflowId: String) async throws -> Artifact {
        let stepId = UUID().uuidString
        
        // Publish step started event
        await sharedEventBus.publish(
            WorkflowProgressEvent(
                workflowId: workflowId,
                progress: 0.0,
                message: "Starting profiling",
                stepName: "profile"
            ),
            source: "Workflows"
        )
        
        do {
            // Use event-driven profiling from DataEngine
            let profileArtifact = try await dataEngine.profileWithEvents(artifact: input)
            
            // Convert profile artifact to regular artifact
            let artifact = Artifact(
                id: UUID().uuidString,
                type: .profile,
                contentHash: "profile_\(input.contentHash)",
                metadata: ["parent_id": input.id, "profile_id": profileArtifact.id]
            )
            
            // Publish step completed event
            await sharedEventBus.publish(
                WorkflowProgressEvent(
                    workflowId: workflowId,
                    progress: 1.0,
                    message: "Profiling completed",
                    stepName: "profile"
                ),
                source: "Workflows"
            )
            
            return artifact
            
        } catch {
            // Publish step failed event
            await sharedEventBus.publish(
                WorkflowProgressEvent(
                    workflowId: workflowId,
                    progress: 0.0,
                    message: "Profiling failed: \(error.localizedDescription)",
                    stepName: "profile"
                ),
                source: "Workflows"
            )
            
            throw error
        }
    }
    
    // MARK: - Event Subscriptions

    /// Setup event subscriptions for workflow coordination
    func setupEventSubscriptions() async {
        // Subscribe to data processing completion events from DataEngine
        let subscription1 = await sharedEventBus.subscribe(to: DataProcessingCompletedEvent.self) { [weak self] event in
            guard let self = self else { return }
            
            // Handle data processing completion
            if let resultId = event.result {
                // In a real implementation, we would:
                // 1. Look up the workflow that triggered this processing
                // 2. Update the workflow state
                // 3. Continue to the next step
                
                print("Data processing completed: \(resultId)")
            }
        }
        
        // Subscribe to data processing failure events from DataEngine
        let subscription2 = await sharedEventBus.subscribe(to: DataProcessingFailedEvent.self) { [weak self] event in
            guard let self = self else { return }
            
            // Handle data processing failure
            print("Data processing failed: \(event.errorMessage)")
            
            // In a real implementation, we would:
            // 1. Look up the workflow that triggered this processing
            // 2. Mark the workflow as failed
            // 3. Publish workflow failed event
        }
        
        // Subscribe to work item completion events from DataEngine
        let subscription3 = await sharedEventBus.subscribe(to: WorkItemCompletedEvent.self) { [weak self] event in
            guard let self = self else { return }
            
            // Handle work item completion
            if event.workItemType == "data_processing" {
                print("Work item completed: \(event.workItemId)")
                
                // In a real implementation, we would:
                // 1. Look up the workflow that created this work item
                // 2. Update the workflow state
                // 3. Continue to the next step
            }
        }
        
        // Subscribe to work item failure events from DataEngine
        let subscription4 = await sharedEventBus.subscribe(to: WorkItemFailedEvent.self) { [weak self] event in
            guard let self = self else { return }
            
            // Handle work item failure
            print("Work item failed: \(event.errorMessage)")
            
            // In a real implementation, we would:
            // 1. Look up the workflow that created this work item
            // 2. Mark the workflow as failed
            // 3. Publish workflow failed event
        }
        
        // Store subscription IDs for cleanup
        eventSubscriptionIds.append(subscription1)
        eventSubscriptionIds.append(subscription2)
        eventSubscriptionIds.append(subscription3)
        eventSubscriptionIds.append(subscription4)
    }
    
    /// Cleanup event subscriptions
    func cleanupEventSubscriptions() async {
        for id in eventSubscriptionIds {
            await sharedEventBus.unsubscribe(id: id)
        }
        eventSubscriptionIds.removeAll()
    }
}

// MARK: - Workflow Engine Event Extensions

public extension WorkflowEngine {
    /// Create a work item for data processing from a workflow
    /// - Parameters:
    ///   - source: Data source URL
    ///   - workflowId: Workflow ID
    ///   - priority: Work item priority
    ///   - metadata: Additional metadata
    /// - Returns: Created work item ID
    func createDataProcessingWorkItem(
        source: URL,
        workflowId: String,
        priority: Int = 1,
        metadata: [String: String]? = nil
    ) async -> String {
        var workItemMetadata = metadata ?? [:]
        workItemMetadata["workflowId"] = workflowId
        workItemMetadata["source"] = source.absoluteString
        workItemMetadata["processingType"] = "workflow_step"
        
        // Publish work item created event
        await sharedEventBus.publish(
            WorkItemCreatedEvent(
                workItemId: UUID().uuidString,
                workItemType: "data_processing",
                priority: priority,
                createdBy: "Workflows",
                metadata: workItemMetadata
            ),
            source: "Workflows"
        )
        
        return workItemMetadata["workItemId"] ?? UUID().uuidString
    }
    
    /// Request data processing for a workflow step
    /// - Parameters:
    ///   - source: Data source URL
    ///   - workflowId: Workflow ID
    ///   - metadata: Additional metadata
    /// - Returns: Processing ID
    func requestDataProcessing(
        source: URL,
        workflowId: String,
        metadata: [String: String]? = nil
    ) async -> String {
        var requestMetadata = metadata ?? [:]
        requestMetadata["workflowId"] = workflowId
        requestMetadata["source"] = source.absoluteString
        requestMetadata["processingType"] = "workflow_step"
        
        // Publish data processing started event
        await sharedEventBus.publish(
            DataProcessingStartedEvent(
                processingId: UUID().uuidString,
                dataSourceId: source.lastPathComponent,
                dataType: "url",
                initiatedBy: "Workflows",
                metadata: requestMetadata
            ),
            source: "Workflows"
        )
        
        return requestMetadata["processingId"] ?? UUID().uuidString
    }
}
```

### Step 3: Update WorkflowEngine Main File

**File**: `anigma/Packages/Workflows/WorkflowEngine.swift`

Add event subscription support:

```swift
public actor WorkflowEngine {
    private let dataEngine: DataEngine
    private let jobEngine: JobEngine

    /// Event subscription IDs for cleanup
    private var eventSubscriptionIds: [UUID] = []

    public init(dataEngine: DataEngine, jobEngine: JobEngine) {
        self.dataEngine = dataEngine
        self.jobEngine = jobEngine
        
        // Setup event subscriptions
        Task { await setupEventSubscriptions() }
    }
    
    deinit {
        // Cleanup event subscriptions
        Task { await cleanupEventSubscriptions() }
    }
    
    // ... rest of the file ...
}
```

### Step 4: Create Event-Driven Workflow Tests

**File**: `anigma/Packages/Workflows/Tests/WorkflowEventTests.swift`

```swift
import Testing
import Workflows
import AnigmaEvents
import DataCore
import DataEngine

struct WorkflowEventTests {
    // MARK: - Event Publishing Tests

    @Test func testWorkflowExecutionPublishesEvents() async throws {
        // Given
        let dataEngine = DataEngine()
        let jobEngine = JobEngine()
        let workflowEngine = WorkflowEngine(dataEngine: dataEngine, jobEngine: jobEngine)
        let mockBus = EventTestingFramework.makeMockEventBus()
        
        // When - Create test workflow
        let workflow = WorkflowDefinition(
            id: "test-workflow",
            name: "Test Workflow",
            type: .dataProcessing,
            steps: [
                .ingest(URL(string: "https://example.com/data.json")!)
            ]
        )
        
        // When - Execute workflow with events
        _ = try await workflowEngine.executeWithEvents(workflow: workflow, context: "test")
        
        // Then - Verify events were published
        let startedEvents = mockBus.publishedEvents(of: WorkflowStartedEvent.self)
        let progressEvents = mockBus.publishedEvents(of: WorkflowProgressEvent.self)
        let completedEvents = mockBus.publishedEvents(of: WorkflowCompletedEvent.self)
        
        #expect(startedEvents.count >= 1)
        #expect(progressEvents.count >= 2) // Start and completion
        #expect(completedEvents.count >= 1)
    }

    @Test func testWorkflowStepPublishesEvents() async throws {
        // Given
        let dataEngine = DataEngine()
        let jobEngine = JobEngine()
        let workflowEngine = WorkflowEngine(dataEngine: dataEngine, jobEngine: jobEngine)
        let mockBus = EventTestingFramework.makeMockEventBus()
        
        // When - Create workflow with multiple steps
        let workflow = WorkflowDefinition(
            id: "multi-step-workflow",
            name: "Multi-Step Workflow",
            type: .dataProcessing,
            steps: [
                .ingest(URL(string: "https://example.com/data.json")!),
                .profile,
                .transform(TransformIR(kind: .filter, predicate: "column > 0"))
            ]
        )
        
        // When - Execute workflow
        _ = try await workflowEngine.executeWithEvents(workflow: workflow, context: "test")
        
        // Then - Verify progress events for each step
        let progressEvents = mockBus.publishedEvents(of: WorkflowProgressEvent.self)
        #expect(progressEvents.count >= 6) // 2 per step * 3 steps
    }

    // MARK: - Event Subscription Tests

    @Test func testDataProcessingCompletionSubscription() async throws {
        // Given
        let dataEngine = DataEngine()
        let jobEngine = JobEngine()
        let workflowEngine = WorkflowEngine(dataEngine: dataEngine, jobEngine: jobEngine)
        let mockBus = EventTestingFramework.makeMockEventBus()
        
        // When - Publish data processing completion event
        let event = DataProcessingCompletedEvent(
            processingId: "test-123",
            result: "artifact-456",
            duration: 5.0,
            success: true,
            processedItems: 1
        )
        
        await mockBus.publish(event, source: "DataEngine")
        
        // Then - WorkflowEngine should handle it
        try await Task.sleep(for: .milliseconds(100))
        
        // Verify the event was processed
        // In a real test, we would verify workflow state updates
    }

    // MARK: - Integration Tests

    @Test func testEventDrivenWorkflowPipeline() async throws {
        // Given
        let dataEngine = DataEngine()
        let jobEngine = JobEngine()
        let workflowEngine = WorkflowEngine(dataEngine: dataEngine, jobEngine: jobEngine)
        let mockBus = EventTestingFramework.makeMockEventBus()
        
        // When - Create and execute workflow
        let workflow = WorkflowDefinition(
            id: "integration-workflow",
            name: "Integration Workflow",
            type: .dataProcessing,
            steps: [
                .ingest(URL(string: "https://example.com/data.json")!)
            ]
        )
        
        // When - Execute workflow
        let result = try await workflowEngine.executeWithEvents(workflow: workflow, context: "test")
        
        // Then - Verify full event pipeline
        let startedEvents = mockBus.publishedEvents(of: WorkflowStartedEvent.self)
        let progressEvents = mockBus.publishedEvents(of: WorkflowProgressEvent.self)
        let completedEvents = mockBus.publishedEvents(of: WorkflowCompletedEvent.self)
        let dataProcessingEvents = mockBus.publishedEvents(of: DataProcessingStartedEvent.self)
        
        #expect(startedEvents.count >= 1)
        #expect(progressEvents.count >= 2)
        #expect(completedEvents.count >= 1)
        #expect(dataProcessingEvents.count >= 1)
        
        // Verify workflow result
        #expect(result.artifacts.count >= 1)
    }
}
```

## 📊 Migration Benefits

### 1. **Event-Driven Workflow Coordination**
- Workflows publish state changes as events
- Other modules can react to workflow progress
- Enables real-time monitoring and dashboards

### 2. **Tight Integration with DataEngine**
- Workflows subscribe to DataEngine events
- DataEngine publishes events for workflow steps
- Loose coupling between workflows and data processing

### 3. **Real-Time Progress Tracking**
- Workflow progress visible through events
- UI can react to progress updates
- Better user experience with real-time feedback

### 4. **Error Handling and Recovery**
- Comprehensive error events from workflows
- Easy to implement retry logic
- Better error propagation and handling

### 5. **Backward Compatibility**
- Original methods remain unchanged
- New event-driven methods are additions
- Gradual migration path for calling modules

## 🚀 Implementation Timeline

### Week 5-6: Workflows Migration
- **Day 1-2**: Add AnigmaEvents dependency and create event-driven extensions
- **Day 3-4**: Implement event publishing in workflow execution
- **Day 5-6**: Implement event subscriptions for DataEngine integration
- **Day 7**: Create comprehensive test suite
- **Day 8**: Test event-driven workflow coordination

### Week 7-8: Integration Testing
- **Day 9-10**: Test integration with DataEngine events
- **Day 11-12**: Test integration with HarmoniaModule events
- **Day 13**: Optimize event flow and performance

## ✅ Success Criteria

1. **Event Publishing** - All workflow operations publish appropriate events
2. **Event Subscription** - Workflows respond to DataEngine events
3. **Integration** - Tight integration with existing HarmoniaModule events
4. **Backward Compatibility** - Original methods still work
5. **Test Coverage** - 100% test coverage for new functionality
6. **Performance** - No significant performance degradation
7. **Reliability** - Event-driven operations as reliable as original

## 📋 Next Steps

1. **Implement WorkflowEngine+Events.swift** - Event-driven extensions
2. **Update Package.swift** - Add AnigmaEvents dependency
3. **Update WorkflowEngine.swift** - Add event subscription setup
4. **Create WorkflowEventTests.swift** - Comprehensive test suite
5. **Test Integration** - Verify event flows with DataEngine
6. **Document Migration** - Create migration guide for calling modules

## 🎯 Conclusion

The Workflows migration to event-driven architecture will:
- Enable tight integration with existing HarmoniaModule events
- Provide real-time workflow visibility and monitoring
- Decouple workflow execution from direct DataEngine calls
- Enable better error handling and recovery
- Maintain backward compatibility during transition

This migration builds on the DataEngine foundation and demonstrates the event-driven pattern for workflow coordination. The next step after Workflows is to migrate ExportCore and RendererKit, which will complete the core data processing pipeline.