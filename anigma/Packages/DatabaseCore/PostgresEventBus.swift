//
//  PostgresEventBus.swift
//  DatabaseCore
//
//  EventBus abstraction on PostgreSQL LISTEN/NOTIFY.
//  Provides pub/sub messaging for database events.
//
//  See td-cfa52e: Create EventBus abstraction on LISTEN/NOTIFY
//  See td-89a996: PostgreSQL First-Class Implementation Epic
//

import Foundation
import AnigmaPrimitives

// MARK: - Event Types

/// Event types that can be published/subscribed to
public enum PostgresEventType: String, Sendable, Codable, CaseIterable {
    case jobQueued
    case jobCompleted
    case jobFailed
    case modelCreated
    case modelUpdated
    case modelDeleted
    case schemaChanged
    case migrationApplied
    case governanceEvent
    case custom
}

/// Event payload structure
public struct PostgresEvent: Sendable, Codable {
    public let id: UUID
    public let type: PostgresEventType
    public let channel: String
    public let payload: [String: AnyCodable]
    public let timestamp: Date
    public let source: String
    
    public init(
        id: UUID = UUID(),
        type: PostgresEventType,
        channel: String,
        payload: [String: AnyCodable] = [:],
        timestamp: Date = Date(),
        source: String = "unknown"
    ) {
        self.id = id
        self.type = type
        self.channel = channel
        self.payload = payload
        self.timestamp = timestamp
        self.source = source
    }
    
    public func toJSON() -> String {
        (try? String(data: JSONEncoder().encode(self), encoding: .utf8)) ?? "{}"
    }
    
    public static func fromJSON(_ json: String) -> PostgresEvent? {
        try? JSONDecoder().decode(PostgresEvent.self, from: json.data(using: .utf8) ?? Data())
    }
}

// MARK: - Event Handler

/// Event handler protocol for subscribing to PostgreSQL events
public protocol PostgresEventHandler: Sendable {
    associatedtype EventType: Sendable
    func handle(_ event: EventType) async throws
}

/// Concrete event handler wrapper for type-erased storage
public final class AnyPostgresEventHandler: Sendable {
    private let _handle: @Sendable (PostgresEvent) async throws -> Void
    
    public init<H: PostgresEventHandler>(_ handler: H) where H.EventType == PostgresEvent {
        self._handle = handler.handle
    }
    
    public init(_ closure: @escaping @Sendable (PostgresEvent) async throws -> Void) {
        self._handle = closure
    }
    
    public func handle(_ event: PostgresEvent) async throws {
        try await _handle(event)
    }
}

// MARK: - Event Bus

/// PostgreSQL EventBus using LISTEN/NOTIFY
/// Provides publish-subscribe messaging within the database cluster
public final actor PostgresEventBus {
    private let database: any DatabaseExecutor
    private var handlers: [String: [AnyPostgresEventHandler]] = [:]
    private var isListening = false
    
    public init(database: any DatabaseExecutor) {
        self.database = database
    }
    
    // MARK: - Publish
    
    /// Publish an event to a channel
    public func publish(
        _ event: PostgresEvent,
        channel: String = "anigma.events"
    ) async throws {
        let json = event.toJSON().replacingOccurrences(of: "'", with: "''")
        let sql = "NOTIFY \(channel), '\(json)'"
        _ = try await database.executeAsync(sql)
    }
    
    /// Publish a simple string message to a channel
    public func publish(
        message: String,
        channel: String = "anigma.events"
    ) async throws {
        let escaped = message.replacingOccurrences(of: "'", with: "''")
        let sql = "NOTIFY \(channel), '\(escaped)'"
        _ = try await database.executeAsync(sql)
    }
    
    // MARK: - Subscribe
    
    /// Subscribe to a channel with a handler
    public func subscribe(
        to channel: String,
        handler: AnyPostgresEventHandler
    ) {
        handlers[channel, default: []].append(handler)
        startListeningIfNeeded()
    }
    
    /// Subscribe to a channel with a closure
    public func subscribe(
        to channel: String,
        onEvent: @escaping @Sendable (PostgresEvent) async throws -> Void
    ) {
        subscribe(to: channel, handler: AnyPostgresEventHandler(onEvent))
    }
    
    /// Subscribe to all events on the default channel
    public func subscribe(
        to type: PostgresEventType,
        onEvent: @escaping @Sendable (PostgresEvent) async throws -> Void
    ) {
        subscribe(to: type.rawValue, onEvent: onEvent)
    }
    
    // MARK: - Start Listening
    
    private func startListeningIfNeeded() {
        guard !isListening else { return }
        isListening = true
        // In a real async context, we'd start a background task
        // For now, this is a marker that listening is active
    }
    
    /// Start listening to PostgreSQL notifications
    /// This would typically be called in an async context
    public func start() async throws {
        // Listen on all registered channels
        for channel in handlers.keys {
            let sql = "LISTEN \(channel)"
            _ = try await database.executeAsync(sql)
        }
        isListening = true
    }
    
    /// Stop listening to notifications
    public func stop() async throws {
        for channel in handlers.keys {
            let sql = "UNLISTEN \(channel)"
            _ = try await database.executeAsync(sql)
        }
        isListening = false
    }
    
    // MARK: - Unsubscribe
    
    /// Unsubscribe from a channel
    public func unsubscribe(from channel: String) {
        handlers[channel] = nil
    }
    
    /// Unsubscribe a specific handler from a channel
    public func unsubscribe(from channel: String, handler: AnyPostgresEventHandler) {
        handlers[channel]?.removeAll { $0 === handler }
    }
    
    // MARK: - Channel Management
    
    /// Get all active channels
    public func getActiveChannels() async throws -> [String] {
        let rows = try await database.query("SELECT channel FROM pg_listening_channels()")
        return rows.compactMap { $0.string(for: "channel") }
    }
    
    /// Check if we're listening on a specific channel
    public func isListening(on channel: String) async throws -> Bool {
        let channels = try await getActiveChannels()
        return channels.contains(channel)
    }
}

// MARK: - Global Event Bus

/// Singleton global event bus for PostgreSQL events
public enum GlobalPostgresEventBus {
    private static var _instance: PostgresEventBus?
    private static let lock = NSLock()
    
    public static func shared(database: any DatabaseExecutor) -> PostgresEventBus {
        lock.lock()
        defer { lock.unlock() }
        if let instance = _instance {
            return instance
        }
        let instance = PostgresEventBus(database: database)
        _instance = instance
        return instance
    }
    
    public static func reset() {
        lock.lock()
        defer { lock.unlock() }
        _instance = nil
    }
}
