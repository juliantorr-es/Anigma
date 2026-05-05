//
//  SecurityEventStore.swift
//  SecurityEventsContracts
//
//  Portable contract protocol for security event persistence.
//  Part of Tier 1 (Contracts) - may be imported by any tier.
//
//  Implementations of this protocol provide concrete storage backends
//  (e.g., DatabaseCore-backed, in-memory, file-based).
//
//  SecurityEventsManager should depend on this protocol, not on DatabaseCore directly.

import Foundation

/// Protocol defining read operations for security event storage.
/// 
/// Implementations provide the ability to query persistence security events
/// without exposing concrete database types or SQL to Tier 1 modules.
public protocol SecurityEventReadStore: Sendable {
    /// Retrieves events by their type.
    func getEventsByType(_ type: String) async throws -> [SecurityEvent]
    
    /// Retrieves events within a date range.
    func getEventsByDateRange(from: Date, to: Date) async throws -> [SecurityEvent]
    
    /// Retrieves events filtered by severity level.
    func getEventsBySeverity(_ severity: String) async throws -> [SecurityEvent]
    
    /// Retrieves events by engine identifier.
    func getEventsByEngineId(_ engineId: String) async throws -> [SecurityEvent]
    
    /// Retrieves aggregated statistics for security events.
    func getEventStats() async throws -> SecurityEventStats
}

/// Protocol defining write operations for security event storage.
/// 
/// Implementations provide the ability to persist security events
/// without exposing concrete database types or SQL to Tier 1 modules.
public protocol SecurityEventWriteStore: Sendable {
    /// Records a new security event.
    func recordEvent(
        type: SecurityEventType,
        severity: SecurityEventSeverity,
        engineId: String?,
        operation: String?,
        details: SecurityEventDetails
    ) async throws
}

/// Combined protocol for full security event persistence.
/// 
/// This is the primary contract that SecurityEventsManager should depend on.
/// Implementations must conform to both read and write capabilities.
public protocol SecurityEventStore: SecurityEventReadStore, SecurityEventWriteStore {}

/// A date range for filtering events.
public struct DateRange: Sendable, Codable {
    public let from: Date
    public let to: Date

    public init(from: Date, to: Date) {
        self.from = from
        self.to = to
    }
}

/// Query filter for security events.
/// Used by more advanced query operations that may be added in the future.
public struct SecurityEventQuery: Sendable, Codable {
    public let type: String?
    public let severity: String?
    public let engineId: String?
    public let dateRange: DateRange?
    public let limit: Int?
    
    public init(
        type: String? = nil,
        severity: String? = nil,
        engineId: String? = nil,
        dateRange: DateRange? = nil,
        limit: Int? = nil
    ) {
        self.type = type
        self.severity = severity
        self.engineId = engineId
        self.dateRange = dateRange
        self.limit = limit
    }
}
