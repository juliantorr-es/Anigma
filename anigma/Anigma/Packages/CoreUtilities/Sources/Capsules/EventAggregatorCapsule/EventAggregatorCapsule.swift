import Foundation
import CapsuleCore
import TelemetryCore
import QueueManager

// MARK: - Event Aggregator Capsule

/// Event processing and routing capsule
public final class EventAggregatorCapsule: Sendable {
    
    // MARK: - Properties
    
    public let id: String
    private let diagnostics: CapsuleDiagnostics
    private let configuration: EventAggregatorConfiguration
    private let queueManager: QueueManager
    private let eventProcessor: EventProcessor
    private let eventRouter: EventRouter
    private let eventStore: EventStore
    
    // MARK: - Initialization
    
    /// Initialize EventAggregatorCapsule
    /// - Parameters:
    ///   - id: Unique identifier for this event aggregator instance
    ///   - diagnostics: Diagnostics collector for observability
    ///   - configuration: Event aggregator configuration
    ///   - queueManager: Queue manager for event processing
    ///   - eventProcessor: Event processor
    ///   - eventRouter: Event router
    ///   - eventStore: Event store
    public init(
        id: String = UUID().uuidString,
        diagnostics: CapsuleDiagnostics,
        configuration: EventAggregatorConfiguration = .default,
        queueManager: QueueManager? = nil,
        eventProcessor: EventProcessor? = nil,
        eventRouter: EventRouter? = nil,
        eventStore: EventStore? = nil
    ) async throws {
        self.id = id
        self.diagnostics = diagnostics
        self.configuration = configuration
        self.queueManager = queueManager ?? QueueManager(diagnostics: diagnostics)
        self.eventProcessor = eventProcessor ?? DefaultEventProcessor(diagnostics: diagnostics)
        self.eventRouter = eventRouter ?? DefaultEventRouter(diagnostics: diagnostics)
        self.eventStore = eventStore ?? InMemoryEventStore()
        
        // Setup event processing
        try await setupEventProcessing()
        
        let span = diagnostics.beginSpan(
            name: "EventAggregatorCapsule.init",
            category: "event_aggregator.initialization",
            correlationID: nil,
            tags: ["aggregator_id": id]
        )
        
        span.end(status: .ok)
        
        diagnostics.event(
            level: .info,
            category: "event_aggregator.initialization",
            message: "EventAggregatorCapsule initialized",
            correlationID: nil,
            metadata: ["aggregator_id": id]
        )
    }
    
    deinit {
        Task {
            await shutdown()
        }
    }
    
    // MARK: - Public API
    
    /// Publish an event
    /// - Parameters:
    ///   - event: Event to publish
    ///   - correlationID: Request ID for tracing
    /// - Throws: CapsuleError if publishing fails
    public func publish(
        _ event: Event,
        correlationID: String? = nil
    ) async throws {
        let corrID = correlationID ?? CorrelationIDContext.current
        let span = diagnostics.beginSpan(
            name: "EventAggregatorCapsule.publish",
            category: "event_aggregator.publishing",
            correlationID: corrID,
            tags: [
                "event_type": event.type,
                "event_source": event.source
            ]
        )
        
        defer { span.end(status: .ok) }
        
        // Validate event
        try validateEvent(event)
        
        // Store event
        await eventStore.store(event)
        
        // Route event
        await eventRouter.route(event)
        
        // Submit for processing if async processing is enabled
        if configuration.enableAsyncProcessing {
            let job = try createEventProcessingJob(event, correlationID: corrID)
            _ = try await queueManager.submitJob(job, correlationID: corrID)
        } else {
            // Process synchronously
            try await eventProcessor.process(event)
        }
        
        diagnostics.event(
            level: .debug,
            category: "event_aggregator.publishing",
            message: "Event published: \(event.type)",
            correlationID: corrID,
            metadata: [
                "event_id": event.id,
                "event_type": event.type,
                "event_source": event.source
            ]
        )
    }
    
    /// Subscribe to events
    /// - Parameters:
    ///   - subscription: Event subscription
    ///   - correlationID: Request ID for tracing
    /// - Returns: Subscription ID
    /// - Throws: CapsuleError if subscription fails
    public func subscribe(
        _ subscription: EventSubscription,
        correlationID: String? = nil
    ) async throws -> String {
        let corrID = correlationID ?? CorrelationIDContext.current
        let subscriptionID = UUID().uuidString
        
        // Register subscription with router
        await eventRouter.registerSubscription(subscription, id: subscriptionID)
        
        diagnostics.event(
            level: .info,
            category: "event_aggregator.subscription",
            message: "Event subscription created",
            correlationID: corrID,
            metadata: [
                "subscription_id": subscriptionID,
                "event_type": subscription.eventType ?? "*",
                "event_source": subscription.source ?? "*"
            ]
        )
        
        return subscriptionID
    }
    
    /// Unsubscribe from events
    /// - Parameters:
    ///   - subscriptionID: Subscription ID
    ///   - correlationID: Request ID for tracing
    /// - Throws: CapsuleError if unsubscription fails
    public func unsubscribe(
        _ subscriptionID: String,
        correlationID: String? = nil
    ) async throws {
        let corrID = correlationID ?? CorrelationIDContext.current
        
        // Remove subscription from router
        await eventRouter.unregisterSubscription(subscriptionID)
        
        diagnostics.event(
            level: .info,
            category: "event_aggregator.subscription",
            message: "Event subscription removed",
            correlationID: corrID,
            metadata: ["subscription_id": subscriptionID]
        )
    }
    
    /// Query events
    /// - Parameters:
    ///   - query: Event query
    ///   - correlationID: Request ID for tracing
    /// - Returns: Array of matching events
    /// - Throws: CapsuleError if query fails
    public func query(
        _ query: EventQuery,
        correlationID: String? = nil
    ) async throws -> [Event] {
        let corrID = correlationID ?? CorrelationIDContext.current
        
        let events = await eventStore.query(query)
        
        diagnostics.event(
            level: .debug,
            category: "event_aggregator.query",
            message: "Event query executed",
            correlationID: corrID,
            metadata: [
                "event_count": "\(events.count)",
                "query_type": query.type.rawValue
            ]
        )
        
        return events
    }
    
    /// Get event statistics
    /// - Returns: Event statistics
    public func getStatistics() -> EventStatistics {
        return EventStatistics(
            totalEvents: 0, // Would need to track this
            eventsByType: [:], // Would need to track this
            eventsBySource: [:], // Would need to track this
            averageProcessingTime: 0.0, // Would need to track this
            activeSubscriptions: 0 // Would need to track this
        )
    }
    
    /// Get aggregator health status
    /// - Returns: Health information
    public func getHealthStatus() -> EventAggregatorHealth {
        return EventAggregatorHealth(
            status: .healthy,
            queueHealth: await queueManager.getHealthStatus(),
            eventStoreType: String(describing: type(of: eventStore)),
            activeSubscriptions: 0, // Would need to track this
            lastEventTime: Date() // Would need to track this
        )
    }
    
    /// Shutdown the event aggregator
    public func shutdown() async {
        await queueManager.shutdown()
        await eventProcessor.shutdown()
        await eventRouter.shutdown()
        await eventStore.shutdown()
        
        diagnostics.event(
            level: .info,
            category: "event_aggregator.shutdown",
            message: "EventAggregatorCapsule shutdown completed",
            correlationID: nil,
            metadata: ["aggregator_id": id]
        )
    }
    
    // MARK: - Private Methods
    
    private func setupEventProcessing() async throws {
        // Register event processing job handler
        // In a real implementation, this would register with the queue manager
    }
    
    private func validateEvent(_ event: Event) throws {
        guard !event.id.isEmpty else {
            throw CapsuleError.invalidInput(
                field: "event.id",
                constraint: "Event ID cannot be empty"
            )
        }
        
        guard !event.type.isEmpty else {
            throw CapsuleError.invalidInput(
                field: "event.type",
                constraint: "Event type cannot be empty"
            )
        }
        
        guard !event.source.isEmpty else {
            throw CapsuleError.invalidInput(
                field: "event.source",
                constraint: "Event source cannot be empty"
            )
        }
    }
    
    private func createEventProcessingJob(_ event: Event, correlationID: String) throws -> Job {
        let jobData = try JSONEncoder().encode(EventProcessingJob(event: event))
        
        return Job(
            type: "event_processing",
            priority: .normal,
            payload: jobData,
            metadata: [
                "event_id": event.id,
                "event_type": event.type,
                "event_source": event.source
            ]
        )
    }
}

// MARK: - Event Models

/// Event data structure
public struct Event: Codable, Sendable, Identifiable {
    public let id: String
    public let type: String
    public let source: String
    public let timestamp: Date
    public let data: [String: Any]
    public let metadata: [String: String]
    public let correlationID: String?
    
    public init(
        id: String = UUID().uuidString,
        type: String,
        source: String,
        timestamp: Date = Date(),
        data: [String: Any] = [:],
        metadata: [String: String] = [:],
        correlationID: String? = nil
    ) {
        self.id = id
        self.type = type
        self.source = source
        self.timestamp = timestamp
        self.data = data
        self.metadata = metadata
        self.correlationID = correlationID
    }
    
    /// Get data value with type conversion
    /// - Parameter key: Data key
    /// - Returns: Data value if found
    public func getData<T>(_ key: String, as type: T.Type) -> T? where T: Codable {
        guard let value = data[key] else { return nil }
        
        if let result = value as? T {
            return result
        }
        
        // Try JSON conversion
        if let jsonData = try? JSONSerialization.data(withJSONObject: value) {
            return try? JSONDecoder().decode(T.self, from: jsonData)
        }
        
        return nil
    }
}

/// Event subscription
public struct EventSubscription: Codable, Sendable {
    public let eventType: String?
    public let source: String?
    public let filter: EventFilter?
    public let handler: EventHandler
    
    public init(
        eventType: String? = nil,
        source: String? = nil,
        filter: EventFilter? = nil,
        handler: @escaping EventHandler
    ) {
        self.eventType = eventType
        self.source = source
        self.filter = filter
        self.handler = handler
    }
}

/// Event handler closure
public typealias EventHandler = @Sendable (Event) async -> Void

/// Event filter
public struct EventFilter: Codable, Sendable {
    public let dataFilter: [String: Any]?
    public let metadataFilter: [String: String]?
    public let timeRange: TimeRange?
    
    public init(
        dataFilter: [String: Any]? = nil,
        metadataFilter: [String: String]? = nil,
        timeRange: TimeRange? = nil
    ) {
        self.dataFilter = dataFilter
        self.metadataFilter = metadataFilter
        self.timeRange = timeRange
    }
    
    /// Check if event matches filter
    /// - Parameter event: Event to check
    /// - Returns: True if event matches filter
    public func matches(_ event: Event) -> Bool {
        // Check data filter
        if let dataFilter = dataFilter {
            for (key, expectedValue) in dataFilter {
                guard let actualValue = event.data[key] else { return false }
                if !valuesEqual(actualValue, expectedValue) { return false }
            }
        }
        
        // Check metadata filter
        if let metadataFilter = metadataFilter {
            for (key, expectedValue) in metadataFilter {
                guard let actualValue = event.metadata[key] else { return false }
                if actualValue != expectedValue { return false }
            }
        }
        
        // Check time range
        if let timeRange = timeRange {
            switch timeRange {
            case .custom(let start, let end):
                return event.timestamp >= start && event.timestamp <= end
            default:
                // Would need to implement other time ranges
                return true
            }
        }
        
        return true
    }
    
    private func valuesEqual(_ value1: Any, _ value2: Any) -> Bool {
        // Simple equality check - in real implementation would be more robust
        return "\(value1)" == "\(value2)"
    }
}

/// Event query
public struct EventQuery: Codable, Sendable {
    public let type: QueryType
    public let eventType: String?
    public let source: String?
    public let filter: EventFilter?
    public let limit: Int?
    public let orderBy: EventOrderBy?
    
    public enum QueryType: String, Codable, Sendable {
        case all = "all"
        case byType = "by_type"
        case bySource = "by_source"
        case byCorrelationID = "by_correlation_id"
        case custom = "custom"
    }
    
    public enum EventOrderBy: String, Codable, Sendable {
        case timestamp = "timestamp"
        case type = "type"
        case source = "source"
    }
    
    public init(
        type: QueryType = .all,
        eventType: String? = nil,
        source: String? = nil,
        filter: EventFilter? = nil,
        limit: Int? = nil,
        orderBy: EventOrderBy? = nil
    ) {
        self.type = type
        self.eventType = eventType
        self.source = source
        self.filter = filter
        self.limit = limit
        self.orderBy = orderBy
    }
}

/// Event statistics
public struct EventStatistics: Codable, Sendable {
    public let totalEvents: Int
    public let eventsByType: [String: Int]
    public let eventsBySource: [String: Int]
    public let averageProcessingTime: TimeInterval
    public let activeSubscriptions: Int
}

/// Event aggregator configuration
public struct EventAggregatorConfiguration: Sendable {
    public let enableAsyncProcessing: Bool
    public let maxEventSize: Int
    public let retentionPeriod: TimeInterval
    public let maxEvents: Int
    public let enableEventStore: Bool
    
    public static let `default` = EventAggregatorConfiguration(
        enableAsyncProcessing: true,
        maxEventSize: 1024 * 1024, // 1MB
        retentionPeriod: 24 * 60 * 60, // 24 hours
        maxEvents: 100000,
        enableEventStore: true
    )
    
    public init(
        enableAsyncProcessing: Bool = true,
        maxEventSize: Int = 1024 * 1024,
        retentionPeriod: TimeInterval = 24 * 60 * 60,
        maxEvents: Int = 100000,
        enableEventStore: Bool = true
    ) {
        self.enableAsyncProcessing = enableAsyncProcessing
        self.maxEventSize = maxEventSize
        self.retentionPeriod = retentionPeriod
        self.maxEvents = maxEvents
        self.enableEventStore = enableEventStore
    }
}

/// Event aggregator health status
public struct EventAggregatorHealth: Codable, Sendable {
    public let status: HealthStatus
    public let queueHealth: QueueHealth
    public let eventStoreType: String
    public let activeSubscriptions: Int
    public let lastEventTime: Date?
    
    public init(
        status: HealthStatus,
        queueHealth: QueueHealth,
        eventStoreType: String,
        activeSubscriptions: Int,
        lastEventTime: Date?
    ) {
        self.status = status
        self.queueHealth = queueHealth
        self.eventStoreType = eventStoreType
        self.activeSubscriptions = activeSubscriptions
        self.lastEventTime = lastEventTime
    }
}

/// Event processing job data
private struct EventProcessingJob: Codable, Sendable {
    let event: Event
}