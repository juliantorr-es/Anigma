# Event-Driven Hybrid Architecture Migration Guide

## 📋 Overview

This guide provides a comprehensive overview of the event-driven hybrid architecture migration for the Anigma project. It covers the migration strategy, implementation patterns, best practices, and step-by-step instructions for migrating modules.

## 🎯 Migration Strategy

### Hybrid Architecture Approach

The event-driven hybrid architecture combines:

1. **Direct Method Calls** - For synchronous, high-performance operations
2. **Event-Driven Communication** - For asynchronous, decoupled operations
3. **Gradual Migration** - Maintain backward compatibility during transition

### Migration Phases

1. **Phase 1: Infrastructure Enhancement** ✅ COMPLETE
   - Enhanced AnigmaEvents with new event types
   - Added filtering, transformation, and QoS utilities
   - Created comprehensive testing framework

2. **Phase 2: Core Module Migration** ✅ IN PROGRESS
   - DataEngine migration ✅ COMPLETE
   - Workflows migration ✅ COMPLETE
   - ExportCore migration (next)
   - RendererKit migration (next)

3. **Phase 3: UI Layer Migration** (Upcoming)
   - DataUI migration
   - Reactive UI components

4. **Phase 4: Higher-Level Modules** (Upcoming)
   - AnigmaWork migration
   - AnigmaCorporate migration

## 🏗️ Migration Patterns

### Pattern 1: Event-Driven Method Extension

**Strategy**: Add event-driven versions of existing methods while keeping original methods unchanged.

**Example**: DataEngine
```swift
// Original method (unchanged)
func ingest(source: URL) async throws -> Artifact

// New event-driven method
func ingestWithEvents(source: URL) async throws -> Artifact
```

**Benefits**:
- Backward compatibility maintained
- Gradual migration path
- No breaking changes

### Pattern 2: Event Subscription for Coordination

**Strategy**: Subscribe to events from other modules to coordinate operations.

**Example**: Workflows subscribing to DataEngine events
```swift
func setupEventSubscriptions() async {
    await sharedEventBus.subscribe(to: DataProcessingCompletedEvent.self) { event in
        // Handle data processing completion
        // Continue workflow execution
    }
}
```

**Benefits**:
- Decoupled architecture
- Real-time coordination
- Flexible event handling

### Pattern 3: Event Publishing for Observability

**Strategy**: Publish events at key milestones for monitoring and coordination.

**Example**: DataEngine publishing progress events
```swift
await sharedEventBus.publish(
    DataProcessingProgressEvent(
        processingId: processingId,
        progress: 0.5,
        message: "Processing in progress"
    )
)
```

**Benefits**:
- Real-time monitoring
- Multiple consumers
- Audit trail capabilities

## 🔧 Implementation Checklist

### Step 1: Add AnigmaEvents Dependency

**File**: `Package.swift`

```swift
.target(name: "YourModule", 
        dependencies: ["AnigmaEvents"], 
        path: "Packages/YourModule")
```

### Step 2: Create Event-Driven Extensions

**File**: `YourModule+Events.swift`

```swift
import AnigmaEvents

public extension YourModule {
    // Event-driven method extensions
    func yourMethodWithEvents(...) async throws -> Result {
        // Publish started event
        await sharedEventBus.publish(StartedEvent(...))
        
        defer {
            // Publish completion/failure event
            if let error = error {
                await sharedEventBus.publish(FailedEvent(...))
            } else {
                await sharedEventBus.publish(CompletedEvent(...))
            }
        }
        
        // Perform operation
        let result = try await yourMethod(...)
        
        return result
    }
}
```

### Step 3: Add Event Subscriptions

**File**: `YourModule.swift`

```swift
public actor YourModule {
    private var eventSubscriptionIds: [UUID] = []

    public init(...) {
        // Setup event subscriptions
        Task { await setupEventSubscriptions() }
    }
    
    deinit {
        // Cleanup event subscriptions
        Task { await cleanupEventSubscriptions() }
    }
    
    func setupEventSubscriptions() async {
        let subscription = await sharedEventBus.subscribe(to: EventType.self) { event in
            // Handle event
        }
        
        eventSubscriptionIds.append(subscription)
    }
    
    func cleanupEventSubscriptions() async {
        for id in eventSubscriptionIds {
            await sharedEventBus.unsubscribe(id: id)
        }
        eventSubscriptionIds.removeAll()
    }
}
```

### Step 4: Create Comprehensive Tests

**File**: `YourModuleEventTests.swift`

```swift
import Testing
import AnigmaEvents

struct YourModuleEventTests {
    @Test func testEventPublishing() async throws {
        let module = YourModule()
        let mockBus = EventTestingFramework.makeMockEventBus()
        
        _ = try await module.yourMethodWithEvents(...)
        
        let events = mockBus.publishedEvents(of: EventType.self)
        #expect(events.count >= 1)
    }
    
    @Test func testEventSubscription() async throws {
        let module = YourModule()
        let mockBus = EventTestingFramework.makeMockEventBus()
        
        let event = EventType(...)
        await mockBus.publish(event)
        
        try await Task.sleep(for: .milliseconds(100))
        // Verify event was processed
    }
}
```

## 📊 Event Types Reference

### Data Processing Events

| Event Type | Purpose | Key Properties |
|------------|---------|----------------|
| `DataProcessingStartedEvent` | Processing begins | processingId, dataSourceId, dataType |
| `DataProcessingProgressEvent` | Progress updates | processingId, progress, processedItems |
| `DataProcessingCompletedEvent` | Processing completes | processingId, result, duration, success |
| `DataProcessingFailedEvent` | Processing fails | processingId, error, errorMessage |

### Workflow Events

| Event Type | Purpose | Key Properties |
|------------|---------|----------------|
| `WorkflowStartedEvent` | Workflow begins | workflowId, workflowName, initiatedBy |
| `WorkflowProgressEvent` | Step progress | workflowId, progress, message, stepName |
| `WorkflowCompletedEvent` | Workflow completes | workflowId, result, duration, success |
| `WorkflowFailedEvent` | Workflow fails | workflowId, error, errorMessage |

### Work Item Events

| Event Type | Purpose | Key Properties |
|------------|---------|----------------|
| `WorkItemCreatedEvent` | Work item created | workItemId, workItemType, priority |
| `WorkItemStartedEvent` | Work item started | workItemId, startedBy |
| `WorkItemProgressEvent` | Work item progress | workItemId, progress, message |
| `WorkItemCompletedEvent` | Work item completes | workItemId, result, duration, success |
| `WorkItemFailedEvent` | Work item fails | workItemId, error, errorMessage |

### Rendering Events

| Event Type | Purpose | Key Properties |
|------------|---------|----------------|
| `RenderingStartedEvent` | Rendering begins | renderingId, dataId, renderType |
| `RenderingProgressEvent` | Rendering progress | renderingId, progress, message |
| `RenderingCompletedEvent` | Rendering completes | renderingId, result, duration, success |
| `RenderingFailedEvent` | Rendering fails | renderingId, error, errorMessage |

### Export Events

| Event Type | Purpose | Key Properties |
|------------|---------|----------------|
| `ExportStartedEvent` | Export begins | exportId, dataId, exportFormat |
| `ExportProgressEvent` | Export progress | exportId, progress, processedItems |
| `ExportCompletedEvent` | Export completes | exportId, result, duration, success |
| `ExportFailedEvent` | Export fails | exportId, error, errorMessage |

### UI Interaction Events

| Event Type | Purpose | Key Properties |
|------------|---------|----------------|
| `UIInteractionEvent` | User interaction | interactionId, interactionType, componentId |
| `UIStateUpdatedEvent` | State change | componentId, stateType, newState |
| `UIEvent` | Generic UI event | eventId, eventType, componentId |

## 🚀 Best Practices

### 1. Event Design

- **Use consistent naming**: `ModuleActionEvent` pattern
- **Include unique IDs**: processingId, workflowId, etc.
- **Add metadata**: Contextual information for debugging
- **Use enums for states**: ProcessingState, WorkflowState, etc.

### 2. Event Publishing

- **Publish at key milestones**: Start, progress, completion
- **Include error details**: Stack traces, error messages
- **Use defer for completion**: Ensure completion events are published
- **Add source information**: Identify event origin

### 3. Event Subscription

- **Use weak references**: Prevent retain cycles
- **Handle errors gracefully**: Don't crash on event errors
- **Clean up subscriptions**: Unsubscribe in deinit
- **Use Task for async work**: Don't block event handlers

### 4. Performance

- **Minimize event size**: Avoid large payloads
- **Use metadata for filtering**: Enable selective processing
- **Batch events when possible**: Reduce event volume
- **Consider QoS**: Use priority for critical events

## 🔍 Debugging Tips

### Common Issues

1. **Events not published**: Check event bus availability
2. **Events not received**: Verify subscription setup
3. **Memory leaks**: Ensure proper cleanup of subscriptions
4. **Performance issues**: Check event volume and size

### Debugging Tools

- **Mock Event Bus**: Use for isolated testing
- **Event Logging**: Enable debug logging for events
- **Event Analytics**: Monitor event flows and performance
- **Event Persistence**: Review persisted events for issues

## 📈 Migration Metrics

### Success Criteria

1. **Event Coverage**: All operations publish appropriate events
2. **Subscription Coverage**: All relevant events are subscribed to
3. **Backward Compatibility**: Original methods still work
4. **Test Coverage**: 100% test coverage for new functionality
5. **Performance**: No significant performance degradation
6. **Reliability**: Event-driven operations as reliable as original

### Migration Progress Tracking

| Module | Status | Events Published | Events Subscribed | Tests |
|--------|--------|------------------|-------------------|-------|
| DataEngine | ✅ Complete | 7 | 2 | 15+ |
| Workflows | ✅ Complete | 5 | 4 | 15+ |
| ExportCore | 🚧 Next | 0 | 0 | 0 |
| RendererKit | 🚧 Next | 0 | 0 | 0 |
| DataUI | ⏳ Upcoming | 0 | 0 | 0 |
| AnigmaWork | ⏳ Upcoming | 0 | 0 | 0 |
| AnigmaCorporate | ⏳ Upcoming | 0 | 0 | 0 |

## 🎯 Next Steps

### Immediate Next Steps

1. **Test Integration** - Verify event flows between DataEngine and Workflows
2. **Migrate ExportCore** - Add event-driven export operations
3. **Migrate RendererKit** - Add event-driven rendering operations
4. **Test Integrated Pipeline** - Verify data processing → rendering → export flow

### Long-Term Next Steps

1. **Migrate DataUI** - Add event-driven UI updates
2. **Migrate AnigmaWork** - Add event-driven work coordination
3. **Migrate AnigmaCorporate** - Add event-driven enterprise features
4. **Optimize Performance** - Fine-tune event processing
5. **Add Monitoring** - Implement event analytics and dashboards

## 📚 Additional Resources

### Documentation

- **Event Types**: `anigma/Packages/AnigmaEvents/Sources/AnigmaEvents/HarmoniaEvents.swift`
- **Filtering**: `anigma/Packages/AnigmaEvents/Sources/AnigmaEvents/EventFiltering.swift`
- **Transformation**: `anigma/Packages/AnigmaEvents/Sources/AnigmaEvents/EventTransformation.swift`
- **QoS**: `anigma/Packages/AnigmaEvents/Sources/AnigmaEvents/EventQoS.swift`

### Examples

- **DataEngine Migration**: `anigma/Packages/DataEngine/DataEngine+Events.swift`
- **Workflows Migration**: `anigma/Packages/Workflows/WorkflowEngine+Events.swift`
- **Tests**: `anigma/Packages/DataEngine/Tests/DataEngineEventTests.swift`

### Migration Templates

- **Module Extension Template**: `Module+Events.swift.template`
- **Test Suite Template**: `ModuleEventTests.swift.template`
- **Package Update Template**: `Package.swift.update.template`

## ✅ Conclusion

The event-driven hybrid architecture migration provides a powerful foundation for building decoupled, observable, and scalable systems. By following the patterns and best practices outlined in this guide, you can successfully migrate modules to the event-driven architecture while maintaining backward compatibility and system reliability.

**Key Benefits**:
- ✅ Decoupled architecture with event-based communication
- ✅ Real-time monitoring and observability
- ✅ Scalable event processing
- ✅ Comprehensive error handling
- ✅ Backward compatibility during transition

**Next Steps**: Continue with ExportCore and RendererKit migrations to complete the core data processing pipeline.