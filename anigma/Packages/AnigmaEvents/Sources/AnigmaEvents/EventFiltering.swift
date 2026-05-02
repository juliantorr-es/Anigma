// EventFiltering.swift
// Event filtering utilities for the Anigma event-driven architecture

import Foundation

/// Event filter protocol
public protocol EventFilter: Sendable {
    /// Test if an event matches the filter criteria
    /// - Parameter event: The event to test
    /// - Returns: true if the event matches the filter
    func matches<Event: AnigmaEvent>(_ event: TypedEvent<Event>) -> Bool
}

/// Event filter builder
public struct EventFilterBuilder {
    private var filters: [any EventFilter]
    
    public init() {
        self.filters = []
    }
    
    /// Add a filter to the builder
    /// - Parameter filter: The filter to add
    /// - Returns: The updated builder
    public func add(_ filter: any EventFilter) -> EventFilterBuilder {
        var updated = self
        updated.filters.append(filter)
        return updated
    }
    
    /// Build the composite filter
    /// - Returns: A composite filter that applies all filters
    public func build() -> CompositeEventFilter {
        return CompositeEventFilter(filters: filters)
    }
}

/// Composite event filter that applies multiple filters
public struct CompositeEventFilter: EventFilter {
    private let filters: [any EventFilter]
    
    public init(filters: [any EventFilter]) {
        self.filters = filters
    }
    
    public func matches<Event: AnigmaEvent>(_ event: TypedEvent<Event>) -> Bool {
        return filters.allSatisfy { $0.matches(event) }
    }
    
    fileprivate func matches(eventType: String, source: String?, metadata: [String: String]?) -> Bool {
        return filters.allSatisfy {
            EventFilteringUtils.matches($0, eventType: eventType, source: source, metadata: metadata)
        }
    }
}

/// Event type filter
public struct EventTypeFilter: EventFilter {
    private let eventType: String
    
    public init(eventType: String) {
        self.eventType = eventType
    }
    
    public func matches<Event: AnigmaEvent>(_ event: TypedEvent<Event>) -> Bool {
        return Event.eventType == eventType
    }
    
    fileprivate func matches(eventType: String) -> Bool {
        self.eventType == eventType
    }
}

/// Event source filter
public struct EventSourceFilter: EventFilter {
    private let source: String
    
    public init(source: String) {
        self.source = source
    }
    
    public func matches<Event: AnigmaEvent>(_ event: TypedEvent<Event>) -> Bool {
        return event.source == source
    }
    
    fileprivate func matches(source: String?) -> Bool {
        source == self.source
    }
}

/// Event metadata filter
public struct EventMetadataFilter: EventFilter {
    private let key: String
    private let value: String
    
    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
    
    public func matches<Event: AnigmaEvent>(_ event: TypedEvent<Event>) -> Bool {
        return event.event.metadata?[key] == value
    }
    
    fileprivate func matches(metadata: [String: String]?) -> Bool {
        metadata?[key] == value
    }
}

/// Event predicate filter
public struct EventPredicateFilter<Event: AnigmaEvent>: EventFilter {
    private let predicate: @Sendable (TypedEvent<Event>) -> Bool
    
    public init(predicate: @escaping @Sendable (TypedEvent<Event>) -> Bool) {
        self.predicate = predicate
    }
    
    public func matches<EventType: AnigmaEvent>(_ event: TypedEvent<EventType>) -> Bool {
        guard let typedEvent = event.event as? Event else {
            return false
        }
        return predicate(TypedEvent(event: typedEvent, source: event.source))
    }
}

/// Event filtering event bus wrapper
public actor FilteringEventBus: EventBus {
    private let underlyingBus: EventBus
    private let filter: @Sendable (String, String?, [String: String]?) -> Bool
    
    public init(
        underlyingBus: EventBus,
        filter: @escaping @Sendable (String, String?, [String: String]?) -> Bool
    ) {
        self.underlyingBus = underlyingBus
        self.filter = filter
    }
    
    public func publish<Event: AnigmaEvent>(_ event: Event, source: String?) async -> Task<Void, any Error> {
        return await underlyingBus.publish(event, source: source)
    }
    
    public func subscribe<Event: AnigmaEvent>(to type: Event.Type, handler: @escaping @Sendable (TypedEvent<Event>) async -> Void) async -> UUID {
        let localFilter = filter
        return await underlyingBus.subscribe(to: type) { event in
            if localFilter(Event.eventType, event.source, event.event.metadata) {
                await handler(event)
            }
        }
    }
    
    public func unsubscribe(id: UUID) async {
        await underlyingBus.unsubscribe(id: id)
    }
    
    public func unsubscribeAll<Event: AnigmaEvent>(from type: Event.Type) async {
        await underlyingBus.unsubscribeAll(from: type)
    }
}

/// Event filtering utilities
public struct EventFilteringUtils {
    fileprivate static func matches(
        _ filter: any EventFilter,
        eventType: String,
        source: String?,
        metadata: [String: String]?
    ) -> Bool {
        switch filter {
        case let typed as EventTypeFilter:
            return typed.matches(eventType: eventType)
        case let typed as EventSourceFilter:
            return typed.matches(source: source)
        case let typed as EventMetadataFilter:
            return typed.matches(metadata: metadata)
        case let typed as CompositeEventFilter:
            return typed.matches(eventType: eventType, source: source, metadata: metadata)
        default:
            // Predicate and unknown filters require concrete event payloads.
            return true
        }
    }
    
    /// Create a filter for specific event types
    /// - Parameter eventTypes: Array of event types to filter
    /// - Returns: Composite filter
    public static func filter(for eventTypes: [String]) -> CompositeEventFilter {
        return CompositeEventFilter(filters: eventTypes.map { EventTypeFilter(eventType: $0) })
    }
    
    /// Create a filter for specific event sources
    /// - Parameter sources: Array of source names to filter
    /// - Returns: Composite filter
    public static func filter(from sources: [String]) -> CompositeEventFilter {
        return CompositeEventFilter(filters: sources.map { EventSourceFilter(source: $0) })
    }
    
    /// Create a filter for events with specific metadata
    /// - Parameter metadata: Dictionary of key-value pairs to filter
    /// - Returns: Composite filter
    public static func filter(with metadata: [String: String]) -> CompositeEventFilter {
        return CompositeEventFilter(filters: metadata.map { EventMetadataFilter(key: $0.key, value: $0.value) })
    }
    
    /// Create a filtering event bus
    /// - Parameters:
    ///   - bus: The underlying event bus
    ///   - filter: The filter to apply
    /// - Returns: Filtering event bus
    public static func filteringBus(underlying bus: EventBus, with filter: any EventFilter) -> FilteringEventBus {
        return FilteringEventBus(underlyingBus: bus) { eventType, source, metadata in
            matches(filter, eventType: eventType, source: source, metadata: metadata)
        }
    }
}
