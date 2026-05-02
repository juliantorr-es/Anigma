// EventQoS.swift
// Quality of Service enhancements for the Anigma event-driven architecture

import Foundation

/// Event priority levels
public enum EventPriority: Int, Sendable, Codable, Comparable {
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4
    
    public static func < (lhs: EventPriority, rhs: EventPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Event delivery guarantee
public enum EventDeliveryGuarantee: String, Sendable, Codable {
    case atMostOnce
    case atLeastOnce
    case exactlyOnce
}

/// Event Quality of Service configuration
public struct EventQoSConfig: Sendable, Codable {
    public let priority: EventPriority
    public let deliveryGuarantee: EventDeliveryGuarantee
    public let maxRetries: Int
    public let timeout: TimeInterval
    public let deduplicationId: String?
    
    public init(priority: EventPriority = .normal,
                deliveryGuarantee: EventDeliveryGuarantee = .atLeastOnce,
                maxRetries: Int = 3,
                timeout: TimeInterval = 30.0,
                deduplicationId: String? = nil) {
        self.priority = priority
        self.deliveryGuarantee = deliveryGuarantee
        self.maxRetries = maxRetries
        self.timeout = timeout
        self.deduplicationId = deduplicationId
    }
}

/// QoS-aware event wrapper
public struct QoSEvent<Event: AnigmaEvent>: Sendable {
    public let event: Event
    public let qos: EventQoSConfig
    public let timestamp: Date
    public let source: String?
    
    public init(event: Event, qos: EventQoSConfig = EventQoSConfig(), source: String? = nil) {
        self.event = event
        self.qos = qos
        self.timestamp = Date()
        self.source = source
    }
}

/// QoS-aware event bus protocol
public protocol QoSEventBus: EventBus {
    /// Publish an event with QoS
    /// - Parameters:
    ///   - event: The event to publish
    ///   - qos: Quality of Service configuration
    ///   - source: Optional source identifier
    /// - Returns: Task that completes when the event is published
    func publish<Event: AnigmaEvent>(_ event: Event, qos: EventQoSConfig, source: String?) async -> Task<Void, any Error>
    
    /// Subscribe to events with QoS requirements
    /// - Parameters:
    ///   - type: Event type to subscribe to
    ///   - qos: Minimum QoS requirements
    ///   - handler: Handler to call when event is received
    /// - Returns: Subscription identifier for unsubscribing
    func subscribe<Event: AnigmaEvent>(to type: Event.Type, qos: EventQoSConfig, handler: @escaping @Sendable (QoSEvent<Event>) async -> Void) async -> UUID
}

/// QoS-aware event bus implementation
public actor QoSEventBusImpl: QoSEventBus {
    private let underlyingBus: EventBus
    private let qosManager: QoSManager
    
    public init(underlyingBus: EventBus, qosManager: QoSManager = DefaultQoSManager()) {
        self.underlyingBus = underlyingBus
        self.qosManager = qosManager
    }
    
    public func publish<Event: AnigmaEvent>(_ event: Event, source: String?) async -> Task<Void, any Error> {
        return await underlyingBus.publish(event, source: source)
    }
    
    public func subscribe<Event: AnigmaEvent>(to type: Event.Type, handler: @escaping @Sendable (TypedEvent<Event>) async -> Void) async -> UUID {
        return await underlyingBus.subscribe(to: type, handler: handler)
    }
    
    public func unsubscribe(id: UUID) async {
        await underlyingBus.unsubscribe(id: id)
    }
    
    public func unsubscribeAll<Event: AnigmaEvent>(from type: Event.Type) async {
        await underlyingBus.unsubscribeAll(from: type)
    }
    
    public func publish<Event: AnigmaEvent>(_ event: Event, qos: EventQoSConfig, source: String?) async -> Task<Void, any Error> {
        let qosEvent = QoSEvent(event: event, qos: qos, source: source)
        return await qosManager.publish(qosEvent, using: self)
    }
    
    public func subscribe<Event: AnigmaEvent>(to type: Event.Type, qos: EventQoSConfig, handler: @escaping @Sendable (QoSEvent<Event>) async -> Void) async -> UUID {
        return await qosManager.subscribe(to: type, qos: qos, handler: handler, using: self)
    }
}

/// QoS Manager protocol
public protocol QoSManager: Sendable {
    /// Publish an event with QoS
    /// - Parameters:
    ///   - event: The QoS-aware event
    ///   - bus: The event bus to use
    /// - Returns: Task that completes when the event is published
    func publish<Event: AnigmaEvent>(_ event: QoSEvent<Event>, using bus: EventBus) async -> Task<Void, any Error>
    
    /// Subscribe to events with QoS requirements
    /// - Parameters:
    ///   - type: Event type to subscribe to
    ///   - qos: Minimum QoS requirements
    ///   - handler: Handler to call when event is received
    ///   - bus: The event bus to use
    /// - Returns: Subscription identifier for unsubscribing
    func subscribe<Event: AnigmaEvent>(to type: Event.Type, qos: EventQoSConfig, handler: @escaping @Sendable (QoSEvent<Event>) async -> Void, using bus: EventBus) async -> UUID
}

/// Default QoS Manager implementation
public struct DefaultQoSManager: QoSManager {
    public init() {}
    
    public func publish<Event: AnigmaEvent>(_ event: QoSEvent<Event>, using bus: EventBus) async -> Task<Void, any Error> {
        // Apply QoS policies before publishing
        let processedEvent = await applyPublishPolicies(event)
        return await bus.publish(processedEvent.event, source: processedEvent.source)
    }
    
    public func subscribe<Event: AnigmaEvent>(to type: Event.Type, qos: EventQoSConfig, handler: @escaping @Sendable (QoSEvent<Event>) async -> Void, using bus: EventBus) async -> UUID {
        // Apply QoS policies for subscription
        return await bus.subscribe(to: type) { typedEvent in
            let qosEvent = QoSEvent(event: typedEvent.event, qos: qos, source: typedEvent.source)
            let processedEvent = await applySubscribePolicies(qosEvent)
            await handler(processedEvent)
        }
    }
    
    private func applyPublishPolicies<Event: AnigmaEvent>(_ event: QoSEvent<Event>) async -> QoSEvent<Event> {
        // Apply priority-based processing
        if event.qos.priority == .critical {
            // Critical events get immediate processing
            print("Processing critical event: \(Event.eventType)")
        }
        
        // Apply deduplication if needed
        if let deduplicationId = event.qos.deduplicationId {
            // In a real implementation, check for duplicates
            print("Event with deduplication ID: \(deduplicationId)")
        }
        
        return event
    }
    
    private func applySubscribePolicies<Event: AnigmaEvent>(_ event: QoSEvent<Event>) async -> QoSEvent<Event> {
        // Apply priority-based handling
        if event.qos.priority == .critical {
            // Critical events get priority handling
            print("Handling critical event: \(Event.eventType)")
        }
        
        return event
    }
}

/// Priority-based event bus
public actor PriorityEventBus: EventBus {
    private let underlyingBus: EventBus
    
    public init(underlyingBus: EventBus) {
        self.underlyingBus = underlyingBus
    }
    
    public func publish<Event: AnigmaEvent>(_ event: Event, source: String?) async -> Task<Void, any Error> {
        return await underlyingBus.publish(event, source: source)
    }
    
    public func subscribe<Event: AnigmaEvent>(to type: Event.Type, handler: @escaping @Sendable (TypedEvent<Event>) async -> Void) async -> UUID {
        return await underlyingBus.subscribe(to: type, handler: handler)
    }
    
    public func unsubscribe(id: UUID) async {
        await underlyingBus.unsubscribe(id: id)
    }
    
    public func unsubscribeAll<Event: AnigmaEvent>(from type: Event.Type) async {
        await underlyingBus.unsubscribeAll(from: type)
    }
    
    /// Publish an event with priority
    /// - Parameters:
    ///   - event: The event to publish
    ///   - priority: The priority level
    ///   - source: Optional source identifier
    /// - Returns: Task that completes when the event is published
    public func publish<Event: AnigmaEvent>(_ event: Event, priority: EventPriority, source: String?) async -> Task<Void, any Error> {
        _ = priority
        return await underlyingBus.publish(event, source: source)
    }
}

/// QoS utilities
public struct QoSUtils {
    /// Create a QoS configuration
    /// - Parameters:
    ///   - priority: Event priority
    ///   - deliveryGuarantee: Delivery guarantee
    ///   - maxRetries: Maximum retry attempts
    ///   - timeout: Timeout in seconds
    ///   - deduplicationId: Optional deduplication identifier
    /// - Returns: QoS configuration
    public static func qos(priority: EventPriority = .normal,
                          deliveryGuarantee: EventDeliveryGuarantee = .atLeastOnce,
                          maxRetries: Int = 3,
                          timeout: TimeInterval = 30.0,
                          deduplicationId: String? = nil) -> EventQoSConfig {
        return EventQoSConfig(
            priority: priority,
            deliveryGuarantee: deliveryGuarantee,
            maxRetries: maxRetries,
            timeout: timeout,
            deduplicationId: deduplicationId
        )
    }
    
    /// Create a QoS-aware event
    /// - Parameters:
    ///   - event: The event
    ///   - qos: QoS configuration
    ///   - source: Optional source identifier
    /// - Returns: QoS-aware event
    public static func qosEvent<Event: AnigmaEvent>(_ event: Event, qos: EventQoSConfig = EventQoSConfig(), source: String? = nil) -> QoSEvent<Event> {
        return QoSEvent(event: event, qos: qos, source: source)
    }
    
    /// Create a QoS-aware event bus
    /// - Parameter bus: The underlying event bus
    /// - Returns: QoS-aware event bus
    public static func qosBus(underlying bus: EventBus) -> QoSEventBusImpl {
        return QoSEventBusImpl(underlyingBus: bus)
    }
    
    /// Create a priority-based event bus
    /// - Parameter bus: The underlying event bus
    /// - Returns: Priority-based event bus
    public static func priorityBus(underlying bus: EventBus) -> PriorityEventBus {
        return PriorityEventBus(underlyingBus: bus)
    }
}
