// EventPersistence.swift
// Event persistence for reliability and recovery

import Foundation
import AnigmaPrimitives

/// Event persistence strategy
public enum EventPersistenceStrategy: String, Sendable, Codable {
    case memoryOnly = "memory"
    case fileBased = "file"
    case database = "database"
}

/// Event persistence configuration
public struct EventPersistenceConfig: Sendable, Codable {
    public let strategy: EventPersistenceStrategy
    public let maxEvents: Int
    public let maxAge: TimeInterval
    public let filePath: String?
    
    public static let `default` = EventPersistenceConfig(
        strategy: .memoryOnly,
        maxEvents: 1000,
        maxAge: 3600, // 1 hour
        filePath: nil
    )
    
    public static let persistent = EventPersistenceConfig(
        strategy: .fileBased,
        maxEvents: 10000,
        maxAge: 86400, // 24 hours
        filePath: FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("anigma_events.json")
            .path
    )
}

/// Event persistence protocol
public protocol EventPersistence: Sendable {
    /// Persist an event
    /// - Parameters:
    ///   - event: The event to persist
    ///   - context: Additional context
    /// - Returns: Result indicating success or failure
    func persist<Event: AnigmaEvent>(_ event: Event, context: [String: String]?) async -> Result<Void, Error>
    
    /// Retrieve persisted events
    /// - Parameters:
    ///   - eventType: Optional event type filter
    ///   - since: Optional timestamp filter
    ///   - limit: Maximum number of events to retrieve
    /// - Returns: Array of persisted events
    func retrieve<Event: AnigmaEvent>(eventType: Event.Type?, since: Date?, limit: Int?) async -> [TypedEvent<Event>]
    
    /// Clear persisted events
    /// - Parameters:
    ///   - eventType: Optional event type to clear
    ///   - olderThan: Optional age threshold
    /// - Returns: Number of events cleared
    func clear(eventType: (any AnigmaEvent.Type)?, olderThan: Date?) async -> Int
    
    /// Get persistence statistics
    /// - Returns: Statistics about persisted events
    func statistics() async -> EventPersistenceStats
}

/// Event persistence statistics
public struct EventPersistenceStats: Sendable, Codable {
    public let totalEvents: Int
    public let eventTypes: [String: Int]
    public let oldestEvent: Date?
    public let newestEvent: Date?
    public let storageSize: Int64
}

/// File-based event persistence
public actor FileBasedEventPersistence: EventPersistence {
    private let config: EventPersistenceConfig
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    private var events: [TypedEventData] = []
    private var lastSaveTime: Date = .distantPast
    private let saveInterval: TimeInterval = 5.0 // Save every 5 seconds
    
    public init(config: EventPersistenceConfig = .persistent) {
        self.config = config
        self.fileManager = FileManager.default
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601

        // Load existing events asynchronously once actor initialization completes.
        Task {
            await loadEventsIfPresent()
        }
    }
    
    public func persist<Event: AnigmaEvent>(_ event: Event, context: [String: String]? = nil) async -> Result<Void, Error> {
        let typedEvent = TypedEvent(event: event, source: context?["source"])
        let eventData = TypedEventData(from: typedEvent)
        
        events.append(eventData)
        
        // Clean up old events
        cleanupOldEvents()
        
        // Save to file periodically
        if Date().timeIntervalSince(lastSaveTime) > saveInterval {
            try? saveEvents()
            lastSaveTime = Date()
        }
        
        return .success(())
    }
    
    public func retrieve<Event: AnigmaEvent>(eventType: Event.Type?, since: Date?, limit: Int?) async -> [TypedEvent<Event>] {
        let filter: (TypedEventData) -> Bool = { eventData in
            if eventType != nil, eventData.eventType != Event.eventType {
                return false
            }
            if let since = since, eventData.timestamp < since {
                return false
            }
            return true
        }
        
        let filtered = events.filter(filter)
        let sorted = filtered.sorted { $0.timestamp > $1.timestamp } // Newest first
        let limited = limit.map { Array(sorted.prefix($0)) } ?? sorted
        
        return limited.compactMap { try? $0.toTypedEvent() }
    }
    
    public func clear(eventType: (any AnigmaEvent.Type)?, olderThan: Date?) async -> Int {
        let beforeCount = events.count
        
        events = events.filter { eventData in
            if let eventType = eventType, eventData.eventType != eventType.eventType {
                return true // Keep events of different types
            }
            if let olderThan = olderThan, eventData.timestamp < olderThan {
                return false // Remove old events
            }
            return true // Keep events
        }
        
        let clearedCount = beforeCount - events.count
        try? saveEvents()
        
        return clearedCount
    }
    
    public func statistics() async -> EventPersistenceStats {
        let eventTypes = Dictionary(events.map { ($0.eventType, 1) }, uniquingKeysWith: +)
        let oldest = events.min(by: { $0.timestamp < $1.timestamp })?.timestamp
        let newest = events.max(by: { $0.timestamp < $1.timestamp })?.timestamp
        let size = events.reduce(Int64(0)) { $0 + Int64($1.size) }
        
        return EventPersistenceStats(
            totalEvents: events.count,
            eventTypes: eventTypes,
            oldestEvent: oldest,
            newestEvent: newest,
            storageSize: size
        )
    }
    
    // MARK: - Private Methods
    
    private func cleanupOldEvents() {
        let cutoffTime = Date().addingTimeInterval(-config.maxAge)
        events = events.filter { $0.timestamp >= cutoffTime }
        
        if events.count > config.maxEvents {
            events = Array(events.suffix(config.maxEvents))
        }
    }
    
    private func saveEvents() throws {
        guard let filePath = config.filePath, let data = try? encoder.encode(events) else {
            return
        }
        
        try fileManager.createDirectory(atPath: (filePath as NSString).deletingLastPathComponent, 
                                       withIntermediateDirectories: true, attributes: nil)
        try data.write(to: URL(fileURLWithPath: filePath))
    }
    
    private func loadEvents() throws {
        guard let filePath = config.filePath, fileManager.fileExists(atPath: filePath) else {
            return
        }
        
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        events = try decoder.decode([TypedEventData].self, from: data)
    }
    
    private func loadEventsIfPresent() async {
        do {
            try loadEvents()
        } catch {
            // Ignore startup load failures; persistence remains functional for new events.
        }
    }
}

/// Event data for persistence (Codable)
private struct TypedEventData: Codable, Sendable {
    let eventType: String
    let eventData: Data
    let timestamp: Date
    let source: String?
    let size: Int
    
    init<Event: AnigmaEvent>(from event: TypedEvent<Event>) {
        self.eventType = Event.eventType
        if let encodable = event.event as? any Encodable {
            self.eventData = (try? JSONEncoder().encode(encodable)) ?? Data()
        } else {
            self.eventData = Data()
        }
        self.timestamp = event.timestamp
        self.source = event.source
        self.size = eventData.count
    }
    
    func toTypedEvent<Event: AnigmaEvent>() throws -> TypedEvent<Event>? {
        guard !eventData.isEmpty else { return nil }
        guard let decodableType = Event.self as? any Decodable.Type else {
            return nil
        }
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(decodableType, from: eventData)
        guard let event = decoded as? Event else {
            return nil
        }
        return TypedEvent(event: event, source: source)
    }
}

/// Event persistence wrapper for the shared event bus
public actor PersistentEventBus: EventBus {
    private let underlyingBus: EventBus
    private let persistence: EventPersistence
    private let shouldPersist: @Sendable (any AnigmaEvent.Type) -> Bool
    
    public init(
        underlyingBus: EventBus = sharedEventBus,
        persistence: EventPersistence = FileBasedEventPersistence(config: .persistent),
        shouldPersist: @escaping @Sendable (any AnigmaEvent.Type) -> Bool = { _ in true }
    ) {
        self.underlyingBus = underlyingBus
        self.persistence = persistence
        self.shouldPersist = shouldPersist
    }
    
    public func publish<Event: AnigmaEvent>(_ event: Event, source: String?) async -> Task<Void, any Error> {
        // Publish to underlying bus
        let task = await underlyingBus.publish(event, source: source)
        
        // Persist if needed
        if shouldPersist(Event.self) {
            let context = source.map { ["source": $0] }
            _ = await persistence.persist(event, context: context)
        }
        
        return task
    }
    
    public func subscribe<Event: AnigmaEvent>(to type: Event.Type, handler: @escaping @Sendable (TypedEvent<Event>) async -> Void) async -> UUID {
        // Subscribe to underlying bus
        let id = await underlyingBus.subscribe(to: type, handler: handler)
        
        // Replay persisted events
        Task {
            let persistedEvents = await persistence.retrieve(eventType: type, since: nil, limit: nil)
            for event in persistedEvents {
                await handler(event)
            }
        }
        
        return id
    }
    
    public func unsubscribe(id: UUID) async {
        await underlyingBus.unsubscribe(id: id)
    }
    
    public func unsubscribeAll<Event: AnigmaEvent>(from type: Event.Type) async {
        await underlyingBus.unsubscribeAll(from: type)
    }
    
    /// Get persistence statistics
    public func statistics() async -> EventPersistenceStats {
        await persistence.statistics()
    }
    
    /// Clear persisted events
    public func clearPersisted(eventType: (any AnigmaEvent.Type)?, olderThan: Date?) async -> Int {
        await persistence.clear(eventType: eventType, olderThan: olderThan)
    }
}

/// Convenience extension for common event types to persist
public extension EventPersistence {
    /// Should persist workflow events
    func shouldPersistWorkflowEvents() -> Bool {
        true
    }
    
    /// Should persist job events
    func shouldPersistJobEvents() -> Bool {
        true
    }
    
    /// Should persist system events
    func shouldPersistSystemEvents() -> Bool {
        true
    }
}

/// Default persistence strategy for common event types
public func defaultPersistenceStrategy(for eventType: any AnigmaEvent.Type) -> Bool {
    let eventTypeString = String(describing: eventType)
    
    // Always persist critical events
    if eventTypeString.contains("Workflow") || 
       eventTypeString.contains("Job") || 
       eventTypeString.contains("System") {
        return true
    }
    
    // Don't persist debug/progress events by default
    return false
}
