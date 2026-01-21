//
//  AuditLog.swift
//  AnigmaCore
//
//  [Brief description of file purpose]
//

import ContractsCore
import CryptoKit
import Foundation

// MARK: - Audit Entry (using AnigmaCore version)

// MARK: - Audit Filter

/// Filter for querying audit logs.
public struct AuditFilter: Sendable, Codable {
    public let startDate: Date?
    public let endDate: Date?
    public let eventTypes: [ContractsCore.AuditEventType]? // Changed to use AuditEventType
    public let principal: String?
    public let module: String?
    public let entityId: String?
    public let componentType: String?
    public let limit: Int?
    public let offset: Int?

    public init(
        startDate: Date? = nil,
        endDate: Date? = nil,
        eventTypes: [ContractsCore.AuditEventType]? = nil, // Changed to use AuditEventType
        principal: String? = nil,
        module: String? = nil,
        entityId: String? = nil,
        componentType: String? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.eventTypes = eventTypes
        self.principal = principal
        self.module = module
        self.entityId = entityId
        self.componentType = componentType
        self.limit = limit
        self.offset = offset
    }

    /// Checks if an entry matches this filter.
    public func matches(_ entry: AuditEntry) -> Bool { // Changed from AuditEvent
        if let start = startDate, entry.timestamp < start { return false }
        if let end = endDate, entry.timestamp > end { return false }
        if let types = eventTypes, !types.contains(ContractsCore.AuditEventType(rawValue: entry.operation) ?? .custom) { return false } // Adapt to AuditEntry.operation
        if let p = principal, entry.command != p { return false } // Adapt to AuditEntry.command
        if let m = module, entry.engineId != m { return false } // Adapt to AuditEntry.engineId
        if let eId = entityId, entry.metadata?["entity_id"] != eId { return false } // Adapt to AuditEntry.result
        if let cType = componentType, entry.metadata?["component_type"] != cType { return false } // Adapt to AuditEntry.result
        return true
    }
}

// MARK: - Audit Log Storage Protocol

/// Protocol for audit log storage backends.
public protocol AuditLogStorage: Sendable {
    /// Appends an entry to log.
    func append(_ entry: AuditEntry) async throws // Changed from AuditEvent

    /// Retrieves entries matching a filter.
    func query(filter: AuditFilter) async throws -> [AuditEntry] // Changed from AuditEvent

    /// Gets the latest entry for hash chaining.
    func queryLatestEntry() async throws -> AuditEntry? // Changed from AuditEvent

    /// Gets total count of entries.
    func count() async throws -> Int
}

// MARK: - In-Memory Storage (Simplified)

/// In-memory audit log storage for testing.
public actor InMemoryAuditStorage: AuditLogStorage {
    private var entries: [AuditEntry] = [] // Changed from AuditEvent

    public init() {}

    public func append(_ entry: AuditEntry) async throws { // Changed from AuditEvent
        entries.append(entry)
    }

    public func query(filter: AuditFilter) async throws -> [AuditEntry] { // Changed from AuditEvent
        var filteredEntries = entries.filter { filter.matches($0) }
        if let limit = filter.limit {
            filteredEntries = Array(filteredEntries.suffix(limit))
        }
        return filteredEntries
    }

    public func queryLatestEntry() async throws -> AuditEntry? { // Changed from AuditEvent
        entries.last
    }

    public func count() async throws -> Int {
        entries.count
    }
}

// MARK: - Audit Manager

/// High-level audit log management.
public actor AuditLogManager: AuditLogging { // Conforms to AuditLogging
    private let storage: AuditLogStorage
    private var lastHash: String?
    public init(storage: AuditLogStorage = InMemoryAuditStorage()) {
        self.storage = storage
    }

    /// Records an event in the audit log.
    public func recordEvent(
        id: UUID,
        type: ContractsCore.AuditEventType, // Changed to AuditEventType
        principal: String?,
        module: String?,
        description: String,
        metadata: [String: String]
    ) async throws { // Added throws
        let previousHash = try await resolveChainHead() ?? AuditLogManager.chainGenesis
        let baseMetadata = sanitizeMetadata(metadata)
        let baseEntry = AuditEntry(
            id: id,
            timestamp: Date(),
            engineId: module ?? "unknown",
            operation: type.rawValue,
            command: principal,
            arguments: nil,
            error: description.isEmpty ? nil : description,
            metadata: baseMetadata
        )
        let chainHash = try computeChainHash(entry: baseEntry, previousHash: previousHash)
        var finalMetadata = baseMetadata
        finalMetadata[AuditLogManager.chainPrevKey] = previousHash
        finalMetadata[AuditLogManager.chainHashKey] = chainHash
        let entry = AuditEntry(
            id: baseEntry.id,
            timestamp: baseEntry.timestamp,
            engineId: baseEntry.engineId,
            operation: baseEntry.operation,
            command: baseEntry.command,
            arguments: baseEntry.arguments,
            error: baseEntry.error,
            metadata: finalMetadata
        )

        do {
            try await storage.append(entry)
            lastHash = chainHash
        } catch {
            print("Audit log storage failure: \(error)") // Log and rethrow
            throw error
        }
    }

    /// Queries the audit log.
    public func query(filter: AuditFilter) async throws -> [AuditEntry] { // Changed from AuditEvent
        try await storage.query(filter: filter)
    }

    /// Gets recent entries.
    public func recent(count: Int = 100) async throws -> [AuditEntry] { // Changed from AuditEvent
        try await storage.query(filter: AuditFilter(limit: count))
    }

    // MARK: - AuditLogging Protocol Conformance
    // Implementing getChainHead, entryCount, verifyChain as required by AuditLogging

    public func getChainHead() async -> String? {
        if let hash = lastHash {
            return hash
        }
        return try? await resolveChainHead()
    }

    public func entryCount() async -> Int {
        do {
            return try await storage.count()
        } catch {
            print("Error getting entry count from storage: \(error)")
            return 0
        }
    }

    public func verifyChain() async -> Bool {
        do {
            let entries = try await storage.query(filter: AuditFilter())
            let sorted = entries.sorted { lhs, rhs in
                if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            var previousHash: String?
            for entry in sorted {
                let metadata = entry.metadata ?? [:]
                let storedPrev = metadata[AuditLogManager.chainPrevKey] ?? AuditLogManager.chainGenesis
                if let previousHash, storedPrev != previousHash {
                    return false
                }
                if previousHash == nil && storedPrev != AuditLogManager.chainGenesis {
                    return false
                }
                guard let storedHash = metadata[AuditLogManager.chainHashKey] else {
                    return false
                }
                let expected = try computeChainHash(entry: entry, previousHash: storedPrev)
                if storedHash != expected {
                    return false
                }
                previousHash = storedHash
            }
            lastHash = previousHash
            return true
        } catch {
            return false
        }
    }

    private func resolveChainHead() async throws -> String? {
        if let lastHash {
            return lastHash
        }
        if let latest = try await storage.queryLatestEntry(),
           let hash = latest.metadata?[AuditLogManager.chainHashKey] {
            lastHash = hash
            return hash
        }
        return nil
    }

    private func computeChainHash(entry: AuditEntry, previousHash: String) throws -> String {
        let payload = AuditChainPayload(
            id: entry.id.uuidString,
            timestamp: entry.timestamp,
            engineId: entry.engineId,
            operation: entry.operation,
            command: entry.command,
            arguments: entry.arguments,
            error: entry.error,
            metadata: sanitizeMetadata(entry.metadata ?? [:]),
            previousHash: previousHash
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func sanitizeMetadata(_ metadata: [String: String]) -> [String: String] {
        var cleaned = metadata
        cleaned[AuditLogManager.chainPrevKey] = nil
        cleaned[AuditLogManager.chainHashKey] = nil
        return cleaned
    }

    private static let chainPrevKey = "chain_prev_hash"
    private static let chainHashKey = "chain_hash"
    private static let chainGenesis = "genesis"
}

private struct AuditChainPayload: Codable {
    let id: String
    let timestamp: Date
    let engineId: String
    let operation: String
    let command: String?
    let arguments: [String]?
    let error: String?
    let metadata: [String: String]
    let previousHash: String
}

public typealias AuditLog = AuditLogManager
