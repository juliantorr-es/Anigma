// AnigmaEvent.swift
// Event protocol and base types for Anigma's event-driven architecture

import Foundation
import AnigmaPrimitives

/// Protocol that all Anigma events must conform to
public protocol AnigmaEvent: Sendable, CustomStringConvertible {
    /// Unique identifier for the event type
    static var eventType: String { get }
    
    /// Human-readable description of the event
    var description: String { get }
    
    /// Optional metadata for debugging and filtering
    var metadata: [String: String]? { get }
}

/// Default implementation for AnigmaEvent
public extension AnigmaEvent {
    var metadata: [String: String]? { nil }
    
    var description: String {
        "Event(type: \(Self.eventType))"
    }
}

/// Event wrapper for type-safe event handling
public struct TypedEvent<EventType: AnigmaEvent>: Sendable {
    public let event: EventType
    public let timestamp: Date
    public let source: String?
    
    public init(event: EventType, source: String? = nil) {
        self.event = event
        self.timestamp = Date()
        self.source = source
    }
}

/// Event bus protocol for cross-module communication
public protocol EventBus: Sendable {
    /// Publish an event to the bus
    /// - Parameters:
    ///   - event: The event to publish
    ///   - source: Optional source identifier
    /// - Returns: Task that completes when the event is published
    func publish<Event: AnigmaEvent>(_ event: Event, source: String?) async -> Task<Void, any Error>
    
    /// Subscribe to events of a specific type
    /// - Parameters:
    ///   - type: Event type to subscribe to
    ///   - handler: Handler to call when event is received
    /// - Returns: Subscription identifier for unsubscribing
    func subscribe<Event: AnigmaEvent>(to type: Event.Type, handler: @escaping @Sendable (TypedEvent<Event>) async -> Void) async -> UUID
    
    /// Unsubscribe from events
    /// - Parameter id: Subscription identifier
    func unsubscribe(id: UUID) async
    
    /// Unsubscribe all handlers for a specific event type
    /// - Parameter type: Event type to unsubscribe from
    func unsubscribeAll<Event: AnigmaEvent>(from type: Event.Type) async
}

/// Default event bus implementation
public actor DefaultEventBus: EventBus {
    private typealias AsyncHandler = @Sendable (any AnigmaEvent, String?) async -> Void
    private var asyncSubscribers: [String: [UUID: AsyncHandler]] = [:]
    private var subscriptionIndex: [UUID: String] = [:]
    
    public init() {}
    
    public func publish<Event: AnigmaEvent>(_ event: Event, source: String? = nil) async -> Task<Void, any Error> {
        let eventType = Event.eventType
        if let asyncHandlers = asyncSubscribers[eventType] {
            for handler in asyncHandlers {
                await handler.value(event, source)
            }
        }
        
        return Task {}
    }
    
    public func subscribe<Event: AnigmaEvent>(to type: Event.Type, handler: @escaping @Sendable (TypedEvent<Event>) async -> Void) async -> UUID {
        let eventType = Event.eventType
        let id = UUID()
        
        if asyncSubscribers[eventType] == nil { asyncSubscribers[eventType] = [:] }
        asyncSubscribers[eventType]?[id] = { event, source in
            if let casted = event as? Event {
                await handler(TypedEvent(event: casted, source: source))
            }
        }
        subscriptionIndex[id] = eventType
        
        return id
    }
    
    public func unsubscribe(id: UUID) async {
        guard let eventType = subscriptionIndex.removeValue(forKey: id) else { return }
        asyncSubscribers[eventType]?[id] = nil
    }
    
    public func unsubscribeAll<Event: AnigmaEvent>(from type: Event.Type) async {
        let eventType = Event.eventType
        if let ids = asyncSubscribers[eventType]?.keys {
            for id in ids {
                subscriptionIndex[id] = nil
            }
        }
        asyncSubscribers[eventType] = nil
    }
}

/// Shared event bus instance for the application
public let sharedEventBus = DefaultEventBus()

public extension EventBus where Self == DefaultEventBus {
    static var shared: DefaultEventBus { sharedEventBus }
}
