# Event-Driven Architecture Guide

## Overview

This guide provides best practices, patterns, and examples for using the event-driven architecture in Anigma.

## Table of Contents

1. [Event Design Guidelines](#event-design-guidelines)
2. [Event Publishing Patterns](#event-publishing-patterns)
3. [Event Subscribing Patterns](#event-subscribing-patterns)
4. [Event Persistence](#event-persistence)
5. [Error Handling](#error-handling)
6. [Performance Considerations](#performance-considerations)
7. [Testing Strategies](#testing-strategies)
8. [Common Pitfalls](#common-pitfalls)
9. [Examples](#examples)

## Event Design Guidelines

### 1. Event Naming

**Conventions:**
- Use PascalCase for event type names
- End with "Event" suffix
- Be specific about what happened

**Good:**
```swift
WorkflowStartedEvent
WorkflowCompletedEvent
JobTokenEvent
```

**Avoid:**
```swift
WorkflowEvent  // Too generic
JobEvent       // Too generic
OnWorkflowStart // Prefix with "on"
```

### 2. Event Structure

**Recommended structure:**
```swift
public struct WorkflowStartedEvent: AnigmaEvent {
    public static let eventType = "workflow.started"
    
    public let workflowId: String
    public let workflowName: String
    public let initiatedBy: String?
    public let metadata: [String: String]?
    
    public init(workflowId: String, workflowName: String, initiatedBy: String? = nil, metadata: [String: String]? = nil) {
        self.workflowId = workflowId
        self.workflowName = workflowName
        self.initiatedBy = initiatedBy
        self.metadata = metadata
    }
}
```

**Key elements:**
- `static let eventType`: Unique identifier for the event
- Required fields: Core information needed by subscribers
- Optional fields: Additional context that may be useful
- `metadata`: Flexible key-value pairs for future extensibility

### 3. Event Types

**Common event categories:**

1. **Lifecycle Events** - Mark important state transitions
   - `WorkflowStartedEvent`, `WorkflowCompletedEvent`
   - `JobSubmittedEvent`, `JobCompletedEvent`

2. **Progress Events** - Report ongoing progress
   - `WorkflowProgressEvent`, `JobStatusUpdatedEvent`

3. **Data Events** - Communicate data changes
   - `DocumentProcessedEvent`, `ModelUpdatedEvent`

4. **Notification Events** - User-facing messages
   - `SystemNotificationEvent`, `UserMessageEvent`

5. **Error Events** - Report problems
   - `SystemErrorEvent`, `WorkflowFailedEvent`

## Event Publishing Patterns

### 1. Basic Publishing

```swift
import AnigmaEvents

// Publish a simple event
await sharedEventBus.publish(
    WorkflowStartedEvent(
        workflowId: "workflow-123",
        workflowName: "Document Processing"
    )
)
```

### 2. Publishing with Source

```swift
// Include source information for debugging
await sharedEventBus.publish(
    WorkflowStartedEvent(...),
    source: "HarmoniaExecutor"
)
```

### 3. Conditional Publishing

```swift
// Only publish if condition is met
if workflow.steps.count > 10 {
    await sharedEventBus.publish(
        WorkflowStartedEvent(
            workflowId: workflow.id,
            workflowName: workflow.name,
            metadata: ["largeWorkflow": "true"]
        )
    )
}
```

### 4. Batch Publishing

```swift
// Publish multiple related events
let events = [
    WorkflowStartedEvent(...),
    JobSubmittedEvent(...)
]

for event in events {
    await sharedEventBus.publish(event)
}
```

### 5. Error Handling

```swift
// Handle publishing errors
do {
    let task = await sharedEventBus.publish(event)
    try await task.value
} catch {
    // Log error and continue
    EventLogger.logError(event, error: error)
}
```

## Event Subscribing Patterns

### 1. Basic Subscription

```swift
// Subscribe to a single event type
let subscription = await sharedEventBus.subscribe(to: JobTokenEvent.self) { event in
    // Handle the event
    print("Received token: \(event.token)")
}
```

### 2. Multiple Subscriptions

```swift
// Subscribe to multiple event types
let tokenSubscription = await sharedEventBus.subscribe(to: JobTokenEvent.self) { event in
    // Handle token
}

let progressSubscription = await sharedEventBus.subscribe(to: WorkflowProgressEvent.self) { event in
    // Handle progress
}
```

### 3. Filtered Subscription

```swift
// Filter events based on content
await sharedEventBus.subscribe(to: WorkflowCompletedEvent.self) { event in
    if event.success {
        // Only handle successful workflows
        print("Workflow succeeded: \(event.workflowId)")
    }
}
```

### 4. Unsubscription

```swift
// Store subscription ID for later unsubscription
var subscriptionId: UUID?

subscriptionId = await sharedEventBus.subscribe(to: JobTokenEvent.self) { event in
    // Handle event
}

// Unsubscribe when no longer needed
await sharedEventBus.unsubscribe(id: subscriptionId!)
```

### 5. Bulk Unsubscription

```swift
// Unsubscribe all handlers for an event type
await sharedEventBus.unsubscribeAll(from: WorkflowProgressEvent.self)
```

## Event Persistence

### 1. Using Persistent Event Bus

```swift
// Create a persistent event bus
let persistentBus = PersistentEventBus(
    underlyingBus: sharedEventBus,
    persistence: FileBasedEventPersistence(config: .persistent),
    shouldPersist: defaultPersistenceStrategy
)

// Publish events (automatically persisted)
await persistentBus.publish(
    WorkflowStartedEvent(...),
    source: "MyModule"
)
```

### 2. Retrieving Persisted Events

```swift
// Get all persisted workflow events
let workflowEvents = await persistence.retrieve(
    eventType: WorkflowStartedEvent.self,
    since: nil,
    limit: 100
)

// Get events since a specific time
let recentEvents = await persistence.retrieve(
    eventType: JobCompletedEvent.self,
    since: Date().addingTimeInterval(-3600), // Last hour
    limit: nil
)
```

### 3. Clearing Persisted Events

```swift
// Clear all persisted events
let clearedCount = await persistence.clear(eventType: nil, olderThan: nil)

// Clear specific event type
let clearedCount = await persistence.clear(
    eventType: WorkflowCompletedEvent.self,
    olderThan: nil
)

// Clear old events
let clearedCount = await persistence.clear(
    eventType: nil,
    olderThan: Date().addingTimeInterval(-86400) // Older than 24 hours
)
```

### 4. Getting Statistics

```swift
// Get persistence statistics
let stats = await persistence.statistics()
print("Total events: \(stats.totalEvents)")
print("Storage size: \(stats.storageSize) bytes")
```

## Error Handling

### 1. Event Handler Errors

```swift
// Handle errors in event handlers
await sharedEventBus.subscribe(to: JobTokenEvent.self) { event in
    do {
        try await processToken(event.token)
    } catch {
        EventLogger.logError(event, error: error)
        // Continue processing other events
    }
}
```

### 2. Graceful Degradation

```swift
// Implement fallback behavior
await sharedEventBus.subscribe(to: WorkflowCompletedEvent.self) { event in
    do {
        try await updateDashboard(event)
    } catch {
        // Fallback: Log to file
        try? logToFile(event)
        EventLogger.logError(event, error: error)
    }
}
```

### 3. Retry Logic

```swift
// Retry failed event processing
var retryCount = 0
const let maxRetries = 3

func processEvent(_ event: WorkflowCompletedEvent) async throws {
    do {
        try await updateDashboard(event)
    } catch {
        guard retryCount < maxRetries else {
            throw error
        }
        retryCount += 1
        try await Task.sleep(for: .seconds(1 * Double(retryCount)))
        try await processEvent(event)
    }
}
```

## Performance Considerations

### 1. Event Throughput

**Best practices:**
- Keep events small and focused
- Avoid large payloads in events
- Use references (IDs) instead of full objects
- Batch related operations

**Example:**
```swift
// Good: Small event with reference
JobCompletedEvent(jobId: "job-123", success: true)

// Avoid: Large event with full object
JobCompletedEvent(job: FullJobObject(...))  // Too much data
```

### 2. Subscriber Performance

**Best practices:**
- Keep event handlers fast (< 100ms)
- Offload heavy processing to background tasks
- Use async/await properly

**Example:**
```swift
// Good: Fast handler with background processing
await sharedEventBus.subscribe(to: JobTokenEvent.self) { event in
    Task {
        await heavyProcessing(event.token)
    }
}

// Avoid: Slow synchronous processing
await sharedEventBus.subscribe(to: JobTokenEvent.self) { event in
    await slowSynchronousProcessing(event.token)  // Blocks event bus
}
```

### 3. Memory Management

**Best practices:**
- Use weak references to avoid retain cycles
- Clean up subscriptions when no longer needed
- Avoid storing event handlers in long-lived objects

**Example:**
```swift
// Good: Weak reference to self
let subscription = await sharedEventBus.subscribe(to: JobTokenEvent.self) { [weak self] event in
    guard let self = self else { return }
    await self.handleToken(event.token)
}
```

## Testing Strategies

### 1. Unit Testing Events

```swift
// Test event publishing
func testWorkflowStartedEvent() async {
    let bus = MockEventBus()
    let executor = WorkflowExecutor(bus: bus)
    
    await executor.execute()
    
    // Verify event was published
    let events = await bus.publishedEvents()
    XCTAssertEqual(events.count, 1)
    XCTAssertTrue(events[0] is WorkflowStartedEvent)
}
```

### 2. Integration Testing

```swift
// Test event flow between modules
func testWorkflowToUIIntegration() async {
    let bus = sharedEventBus
    var receivedEvents: [WorkflowCompletedEvent] = []
    
    // Subscribe to events
    await bus.subscribe(to: WorkflowCompletedEvent.self) { event in
        receivedEvents.append(event)
    }
    
    // Trigger workflow
    let workflow = Workflow(...)
    await workflow.execute()
    
    // Verify UI received event
    try await Task.sleep(for: .seconds(1))
    XCTAssertEqual(receivedEvents.count, 1)
    XCTAssertTrue(receivedEvents[0].success)
}
```

### 3. Performance Testing

```swift
// Test event throughput
func testEventThroughput() async {
    let bus = sharedEventBus
    let startTime = Date()
    let eventCount = 1000
    
    // Publish many events
    for i in 0..<eventCount {
        await bus.publish(
            JobStatusUpdatedEvent(
                jobId: "job-\(i)",
                status: "progress",
                progress: Double(i) / Double(eventCount)
            )
        )
    }
    
    let duration = Date().timeIntervalSince(startTime)
    let throughput = Double(eventCount) / duration
    
    print("Event throughput: \(throughput) events/sec")
    XCTAssertGreaterThan(throughput, 500) // Should handle at least 500 events/sec
}
```

## Common Pitfalls

### 1. Circular Dependencies

**Problem:** Event handlers calling back to publishers

**Solution:** Use one-way communication
```swift
// Bad: Event handler calls back
subscribe { event in
    publisher.publish(responseEvent)  // Circular!
}

// Good: Separate concerns
subscribe { event in
    updateUI(event)  // Only update UI
}
```

### 2. Event Storms

**Problem:** Events triggering more events recursively

**Solution:** Limit event propagation
```swift
// Bad: Event triggers event triggers event...
subscribe { event in
    publish(relatedEvent)  // Could cause infinite loop
}

// Good: Control event flow
subscribe { event in
    guard !event.processed else { return }
    publish(relatedEvent.withProcessed(true))
}
```

### 3. Memory Leaks

**Problem:** Event handlers retaining objects

**Solution:** Use weak references
```swift
// Bad: Strong reference cycle
class MyViewController {
    var subscription: UUID?
    
    func setup() {
        subscription = subscribe { [self] event in  // Strong self!
            self.updateUI(event)
        }
    }
}

// Good: Weak reference
class MyViewController {
    var subscription: UUID?
    
    func setup() {
        subscription = subscribe { [weak self] event in
            self?.updateUI(event)
        }
    }
}
```

### 4. Over-Publishing

**Problem:** Publishing too many events

**Solution:** Batch or throttle events
```swift
// Bad: Publish every keystroke
subscribe { event in
    publish(KeyPressedEvent(key: event.key))
}

// Good: Batch or throttle
var lastPublishTime = Date()
subscribe { event in
    let now = Date()
    if now.timeIntervalSince(lastPublishTime) > 0.1 {  // Throttle to 10Hz
        publish(KeyPressedEvent(key: event.key))
        lastPublishTime = now
    }
}
```

## Examples

### Example 1: Workflow Execution with Events

```swift
// In WorkflowExecutor
public func execute() async {
    // Publish workflow started
    await sharedEventBus.publish(
        WorkflowStartedEvent(
            workflowId: execution.id,
            workflowName: definition.name
        )
    )
    
    defer {
        // Publish workflow completed
        let duration = execution.endTime?.timeIntervalSince(execution.startTime ?? Date()) ?? 0
        await sharedEventBus.publish(
            WorkflowCompletedEvent(
                workflowId: execution.id,
                duration: duration,
                success: execution.state == .completed
            )
        )
    }
    
    // Execute workflow steps
    for step in definition.steps {
        await executeStep(step)
        
        // Publish progress
        let progress = Double(step.index) / Double(definition.steps.count)
        await sharedEventBus.publish(
            WorkflowProgressEvent(
                workflowId: execution.id,
                progress: progress,
                stepName: step.id
            )
        )
    }
}
```

### Example 2: UI Updates from Events

```swift
// In ChatPresenter
public func start() async {
    // Subscribe to job tokens
    self.tokenSubscription = await sharedEventBus.subscribe(to: JobTokenEvent.self) { [weak self] event in
        await TUIEventBus.shared.publish(.tokenReceived(token: event.token))
    }
    
    // Subscribe to workflow progress
    await sharedEventBus.subscribe(to: WorkflowProgressEvent.self) { [weak self] event in
        let message = "Workflow: \(Int(event.progress * 100))% complete"
        await TUIEventBus.shared.publish(.statusUpdated(message: message))
    }
    
    // Subscribe to completion
    await sharedEventBus.subscribe(to: WorkflowCompletedEvent.self) { [weak self] event in
        let message = event.success ? "✅ Success" : "❌ Failed"
        await TUIEventBus.shared.publish(.statusUpdated(message: message))
    }
}
```

### Example 3: Event-Driven Job Queue

```swift
// In JobQueueManager
public actor JobQueueManager {
    private let bus: EventBus
    
    public init(bus: EventBus = sharedEventBus) {
        self.bus = bus
        setupEventHandlers()
    }
    
    private func setupEventHandlers() {
        Task {
            // Subscribe to job submissions
            await bus.subscribe(to: JobSubmittedEvent.self) { [weak self] event in
                await self?.enqueueJob(event.jobId)
            }
            
            // Subscribe to job completions
            await bus.subscribe(to: JobCompletedEvent.self) { [weak self] event in
                await self?.removeJob(event.jobId)
            }
        }
    }
}
```

## Best Practices Summary

1. **Design:**
   - Use clear, specific event names
   - Keep events small and focused
   - Include required fields and optional metadata

2. **Publishing:**
   - Publish events at natural state transitions
   - Include source information for debugging
   - Handle publishing errors gracefully

3. **Subscribing:**
   - Use weak references to avoid memory leaks
   - Keep handlers fast and non-blocking
   - Handle errors in event handlers

4. **Persistence:**
   - Persist critical events (workflow, job, system)
   - Set appropriate retention policies
   - Monitor storage usage

5. **Performance:**
   - Keep events small
   - Batch related operations
   - Offload heavy processing

6. **Testing:**
   - Test event publishing and receiving
   - Test error scenarios
   - Test performance under load

## Further Reading

- [Event-Driven Architecture Migration Plan](EVENT_DRIVEN_ARCHITECTURE_MIGRATION_PLAN.md)
- [Event-Driven Integration Complete](EVENT_DRIVEN_INTEGRATION_COMPLETE.md)
- AnigmaEvents Module (external)

## Support

For questions or issues with event-driven architecture:
- Check existing event types in `AnigmaEvents/HarmoniaEvents.swift`
- Review the event bus protocol in `AnigmaEvents/AnigmaEvent.swift`
- Consult the event persistence guide in `AnigmaEvents/EventPersistence.swift`
