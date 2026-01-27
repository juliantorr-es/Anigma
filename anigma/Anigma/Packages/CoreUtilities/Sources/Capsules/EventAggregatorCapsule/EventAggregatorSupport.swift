import Foundation
import CapsuleCore
import TelemetryCore

// MARK: - Event Processor Protocol

/// Protocol for event processing
public protocol EventProcessor: Sendable {
    /// Process an event
    /// - Parameter event: Event to process
    /// - Throws: CapsuleError if processing fails
    func process(_ event: Event) async throws
    
    /// Shutdown processor
    func shutdown() async
}

// MARK: - Default Event Processor

/// Default event processor implementation
public class DefaultEventProcessor: EventProcessor {
    private let diagnostics: CapsuleDiagnostics
    private let handlers: [String: EventHandler]
    
    public init(diagnostics: CapsuleDiagnostics) {
        self.diagnostics = diagnostics
        self.handlers = [:]
    }
    
    public func process(_ event: Event) async throws {
        let startTime = Date()
        
        let span = diagnostics.beginSpan(
            name: "DefaultEventProcessor.process",
            category: "event_processing",
            correlationID: event.correlationID,
            tags: [
                "event_type": event.type,
                "event_source": event.source
            ]
        )
        
        do {
            // Find and execute handler
            if let handler = handlers[event.type] {
                await handler(event)
            } else {
                // Default event processing
                await processDefaultEvent(event)
            }
            
            span.end(status: .ok)
            
            let duration = Date().timeIntervalSince(startTime)
            diagnostics.event(
                level: .debug,
                category: "event_processing",
                message: "Event processed successfully: \(event.type)",
                correlationID: event.correlationID,
                metadata: [
                    "event_id": event.id,
                    "processing_time": String(format: "%.3f", duration)
                ]
            )
            
        } catch {
            span.end(status: .error)
            
            let duration = Date().timeIntervalSince(startTime)
            diagnostics.event(
                level: .error,
                category: "event_processing",
                message: "Event processing failed: \(event.type)",
                correlationID: event.correlationID,
                metadata: [
                    "event_id": event.id,
                    "error": "\(error)",
                    "processing_time": String(format: "%.3f", duration)
                ]
            )
            
            throw error
        }
    }
    
    public func shutdown() async {
        // Cleanup resources
    }
    
    private func processDefaultEvent(_ event: Event) async {
        // Default event processing - could log, store, or forward
        diagnostics.event(
            level: .info,
            category: "event_processing.default",
            message: "Processing event: \(event.type)",
            correlationID: event.correlationID,
            metadata: [
                "event_id": event.id,
                "event_source": event.source,
                "data_keys": Array(event.data.keys).joined(separator: ",")
            ]
        )
    }
}

// MARK: - Event Router Protocol

/// Protocol for event routing
public protocol EventRouter: Sendable {
    /// Route an event to subscribers
    /// - Parameter event: Event to route
    func route(_ event: Event) async
    
    /// Register a subscription
    /// - Parameters:
    ///   - subscription: Event subscription
    ///   - id: Subscription ID
    func registerSubscription(_ subscription: EventSubscription, id: String) async
    
    /// Unregister a subscription
    /// - Parameter subscriptionID: Subscription ID
    func unregisterSubscription(_ subscriptionID: String) async
    
    /// Get active subscriptions count
    /// - Returns: Number of active subscriptions
    func getActiveSubscriptionCount() async -> Int
    
    /// Shutdown router
    func shutdown() async
}

// MARK: - Default Event Router

/// Default event router implementation
public class DefaultEventRouter: EventRouter {
    private let diagnostics: CapsuleDiagnostics
    private let lock = NSLock()
    private nonisolated(unsafe) var subscriptions: [String: EventSubscription] = [:]
    
    public init(diagnostics: CapsuleDiagnostics) {
        self.diagnostics = diagnostics
    }
    
    public func route(_ event: Event) async {
        lock.lock()
        let currentSubscriptions = Array(subscriptions.values)
        lock.unlock()
        
        for subscription in currentSubscriptions {
            if shouldRoute(event: event, to: subscription) {
                await subscription.handler(event)
            }
        }
    }
    
    public func registerSubscription(_ subscription: EventSubscription, id: String) async {
        lock.lock()
        defer { lock.unlock() }
        
        subscriptions[id] = subscription
        
        diagnostics.event(
            level: .debug,
            category: "event_routing.subscription",
            message: "Event subscription registered",
            correlationID: nil,
            metadata: [
                "subscription_id": id,
                "event_type": subscription.eventType ?? "*",
                "event_source": subscription.source ?? "*"
            ]
        )
    }
    
    public func unregisterSubscription(_ subscriptionID: String) async {
        lock.lock()
        defer { lock.unlock() }
        
        subscriptions.removeValue(forKey: subscriptionID)
        
        diagnostics.event(
            level: .debug,
            category: "event_routing.subscription",
            message: "Event subscription unregistered",
            correlationID: nil,
            metadata: ["subscription_id": subscriptionID]
        )
    }
    
    public func getActiveSubscriptionCount() async -> Int {
        lock.lock()
        defer { lock.unlock() }
        return subscriptions.count
    }
    
    public func shutdown() async {
        lock.lock()
        defer { lock.unlock() }
        subscriptions.removeAll()
    }
    
    private func shouldRoute(event: Event, to subscription: EventSubscription) -> Bool {
        // Check event type filter
        if let eventType = subscription.eventType, eventType != event.type {
            return false
        }
        
        // Check source filter
        if let source = subscription.source, source != event.source {
            return false
        }
        
        // Check custom filter
        if let filter = subscription.filter {
            return filter.matches(event)
        }
        
        return true
    }
}

// MARK: - Event Store Protocol

/// Protocol for event storage
public protocol EventStore: Sendable {
    /// Store an event
    /// - Parameter event: Event to store
    func store(_ event: Event) async
    
    /// Query events
    /// - Parameter query: Event query
    /// - Returns: Array of matching events
    func query(_ query: EventQuery) async -> [Event]
    
    /// Get event by ID
    /// - Parameter eventID: Event ID
    /// - Returns: Event if found
    func getEvent(_ eventID: String) async -> Event?
    
    /// Delete events
    /// - Parameters:
    ///   - olderThan: Delete events older than this time
    ///   - eventIDs: Specific event IDs to delete
    func delete(olderThan: Date?, eventIDs: [String]?) async
    
    /// Get events count
    /// - Returns: Number of stored events
    func getEventsCount() async -> Int
    
    /// Shutdown store
    func shutdown() async
}

// MARK: - In-Memory Event Store

/// In-memory event store implementation
public class InMemoryEventStore: EventStore {
    private let lock = NSLock()
    private nonisolated(unsafe) var events: [Event] = []
    private let maxEvents: Int
    
    public init(maxEvents: Int = 10000) {
        self.maxEvents = maxEvents
    }
    
    public func store(_ event: Event) async {
        lock.lock()
        defer { lock.unlock() }
        
        events.append(event)
        
        // Remove oldest events if we exceed the limit
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }
    
    public func query(_ query: EventQuery) async -> [Event] {
        lock.lock()
        var sourceEvents = events
        lock.unlock()
        
        // Apply filters
        if let eventType = query.eventType {
            sourceEvents = sourceEvents.filter { $0.type == eventType }
        }
        
        if let source = query.source {
            sourceEvents = sourceEvents.filter { $0.source == source }
        }
        
        if let filter = query.filter {
            sourceEvents = sourceEvents.filter { filter.matches($0) }
        }
        
        // Apply ordering
        if let orderBy = query.orderBy {
            switch orderBy {
            case .timestamp:
                sourceEvents.sort { $0.timestamp < $1.timestamp }
            case .type:
                sourceEvents.sort { $0.type < $1.type }
            case .source:
                sourceEvents.sort { $0.source < $1.source }
            }
        }
        
        // Apply limit
        if let limit = query.limit, limit > 0 {
            sourceEvents = Array(sourceEvents.prefix(limit))
        }
        
        return sourceEvents
    }
    
    public func getEvent(_ eventID: String) async -> Event? {
        lock.lock()
        defer { lock.unlock() }
        
        return events.first { $0.id == eventID }
    }
    
    public func delete(olderThan: Date?, eventIDs: [String]?) async {
        lock.lock()
        defer { lock.unlock() }
        
        events = events.filter { event in
            var shouldKeep = true
            
            if let olderThan = olderThan {
                shouldKeep = shouldKeep && event.timestamp >= olderThan
            }
            
            if let eventIDs = eventIDs {
                shouldKeep = shouldKeep && !eventIDs.contains(event.id)
            }
            
            return shouldKeep
        }
    }
    
    public func getEventsCount() async -> Int {
        lock.lock()
        defer { lock.unlock() }
        return events.count
    }
    
    public func shutdown() async {
        lock.lock()
        defer { lock.unlock() }
        events.removeAll()
    }
}

// MARK: - Utility Functions

/// Create an event with basic information
public func event(
    type: String,
    source: String,
    data: [String: Any] = [:],
    metadata: [String: String] = [:],
    correlationID: String? = nil
) -> Event {
    return Event(
        type: type,
        source: source,
        data: data,
        metadata: metadata,
        correlationID: correlationID
    )
}

/// Create an event subscription
public func subscription(
    eventType: String? = nil,
    source: String? = nil,
    handler: @escaping EventHandler
) -> EventSubscription {
    return EventSubscription(
        eventType: eventType,
        source: source,
        handler: handler
    )
}

/// Create a filtered event subscription
public func subscription(
    eventType: String? = nil,
    source: String? = nil,
    dataFilter: [String: Any]? = nil,
    metadataFilter: [String: String]? = nil,
    handler: @escaping EventHandler
) -> EventSubscription {
    let filter = EventFilter(
        dataFilter: dataFilter,
        metadataFilter: metadataFilter
    )
    
    return EventSubscription(
        eventType: eventType,
        source: source,
        filter: filter,
        handler: handler
    )
}

/// Create an event query for all events
public func allEvents(
    limit: Int? = nil,
    orderBy: EventQuery.EventOrderBy? = nil
) -> EventQuery {
    return EventQuery(
        type: .all,
        limit: limit,
        orderBy: orderBy
    )
}

/// Create an event query by type
public func eventsByType(
    _ type: String,
    limit: Int? = nil,
    orderBy: EventQuery.EventOrderBy? = nil
) -> EventQuery {
    return EventQuery(
        type: .byType,
        eventType: type,
        limit: limit,
        orderBy: orderBy
    )
}

/// Create an event query by source
public func eventsBySource(
    _ source: String,
    limit: Int? = nil,
    orderBy: EventQuery.EventOrderBy? = nil
) -> EventQuery {
    return EventQuery(
        type: .bySource,
        source: source,
        limit: limit,
        orderBy: orderBy
    )
}

/// Create an event query by correlation ID
public func eventsByCorrelationID(
    _ correlationID: String,
    limit: Int? = nil,
    orderBy: EventQuery.EventOrderBy? = nil
) -> EventQuery {
    return EventQuery(
        type: .byCorrelationID,
        metadataFilter: ["correlation_id": correlationID],
        limit: limit,
        orderBy: orderBy
    )
}

/// Event builder for fluent API
public class EventBuilder {
    private var id: String = UUID().uuidString
    private var type: String = ""
    private var source: String = ""
    private var timestamp: Date = Date()
    private var data: [String: Any] = [:]
    private var metadata: [String: String] = [:]
    private var correlationID: String?
    
    public init() {}
    
    public func id(_ id: String) -> EventBuilder {
        self.id = id
        return self
    }
    
    public func type(_ type: String) -> EventBuilder {
        self.type = type
        return self
    }
    
    public func source(_ source: String) -> EventBuilder {
        self.source = source
        return self
    }
    
    public func timestamp(_ timestamp: Date) -> EventBuilder {
        self.timestamp = timestamp
        return self
    }
    
    public func data(_ data: [String: Any]) -> EventBuilder {
        self.data = data
        return self
    }
    
    public func data(key: String, value: Any) -> EventBuilder {
        self.data[key] = value
        return self
    }
    
    public func metadata(_ metadata: [String: String]) -> EventBuilder {
        self.metadata = metadata
        return self
    }
    
    public func metadata(key: String, value: String) -> EventBuilder {
        self.metadata[key] = value
        return self
    }
    
    public func correlationID(_ correlationID: String) -> EventBuilder {
        self.correlationID = correlationID
        return self
    }
    
    public func build() -> Event {
        return Event(
            id: id,
            type: type,
            source: source,
            timestamp: timestamp,
            data: data,
            metadata: metadata,
            correlationID: correlationID
        )
    }
}