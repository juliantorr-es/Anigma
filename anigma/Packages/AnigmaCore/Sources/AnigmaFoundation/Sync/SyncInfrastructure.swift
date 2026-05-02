import AnigmaPrimitives

import AnigmaPrimitives

//
//  SyncInfrastructure.swift
//  AnigmaCore
//
//  Infrastructure for bidirectional synchronization between Anigma and external systems.
//  Supports both "overlay mode" (Anigma mirrors external) and "system-of-record mode"
//  (Anigma is authoritative, external systems mirror Anigma).
//
//  Design principles:
//  - Every domain can configure which fields are authoritative where
//  - Sync is idempotent and invertible
//  - Full audit trail for all sync operations
//  - Conflict resolution is explicit and logged
//

import Foundation
import AnigmaPrimitives
import ContractsCore

// MARK: - Authority Configuration

/// Defines which system is authoritative for a given data domain.
public enum DataAuthority: String, Codable, Sendable {
    /// External system is the source of truth; Anigma mirrors/annotates
    case external

    /// Anigma is the source of truth; external systems sync from Anigma
    case anigma

    /// Both can write; conflicts resolved by policy
    case bidirectional

    /// No sync; data exists only in one system
    case isolated
}

/// Configuration for a specific data domain's sync behavior.
public struct DomainSyncConfig: Codable, Sendable {
    public let domainName: String
    public var authority: DataAuthority
    public var externalSystemId: String?
    public var syncEnabled: Bool
    public var syncIntervalSeconds: Int
    public var conflictResolution: ConflictResolutionPolicy
    public var fieldOverrides: [String: DataAuthority]  // Per-field authority overrides

    public init(
        domainName: String,
        authority: DataAuthority = .external,
        externalSystemId: String? = nil,
        syncEnabled: Bool = true,
        syncIntervalSeconds: Int = 300,
        conflictResolution: ConflictResolutionPolicy = .latestWins,
        fieldOverrides: [String: DataAuthority] = [:]
    ) {
        self.domainName = domainName
        self.authority = authority
        self.externalSystemId = externalSystemId
        self.syncEnabled = syncEnabled
        self.syncIntervalSeconds = syncIntervalSeconds
        self.conflictResolution = conflictResolution
        self.fieldOverrides = fieldOverrides
    }
}

/// Policy for resolving sync conflicts.
public enum ConflictResolutionPolicy: String, Codable, Sendable {
    /// Most recent modification wins
    case latestWins

    /// External system always wins
    case externalWins

    /// Anigma always wins
    case anigmaWins

    /// Create a conflict record for manual resolution
    case manualReview

    /// Merge non-conflicting fields, flag conflicts
    case mergeWithConflicts
}

// MARK: - Sync Records

/// Unique identifier for sync records.
public struct SyncRecordId: Hashable, Codable, Sendable {
    public let value: UUID

    public init(_ value: UUID = UUID()) {
        self.value = value
    }
}

/// A record of a sync operation.
public struct SyncRecord: Codable, Sendable {
    public let id: SyncRecordId
    public let domainName: String
    public let externalSystemId: String
    public let externalRecordId: String
    public let anigmaEntityId: EntityId?
    public let operation: SyncOperation
    public let status: SyncStatus
    public let direction: SyncDirection
    public let timestamp: Date
    public let fieldsAffected: [String]
    public let conflictsDetected: [SyncConflict]
    public let errorMessage: String?

    public init(
        id: SyncRecordId = SyncRecordId(),
        domainName: String,
        externalSystemId: String,
        externalRecordId: String,
        anigmaEntityId: EntityId?,
        operation: SyncOperation,
        status: SyncStatus,
        direction: SyncDirection,
        timestamp: Date = Date(),
        fieldsAffected: [String] = [],
        conflictsDetected: [SyncConflict] = [],
        errorMessage: String? = nil
    ) {
        self.id = id
        self.domainName = domainName
        self.externalSystemId = externalSystemId
        self.externalRecordId = externalRecordId
        self.anigmaEntityId = anigmaEntityId
        self.operation = operation
        self.status = status
        self.direction = direction
        self.timestamp = timestamp
        self.fieldsAffected = fieldsAffected
        self.conflictsDetected = conflictsDetected
        self.errorMessage = errorMessage
    }
}

/// Type of sync operation.
public enum SyncOperation: String, Codable, Sendable {
    case create
    case update
    case delete
    case link      // Link existing records without data change
    case unlink    // Unlink records
    case resolve   // Resolve a conflict
}

/// Status of a sync operation.
public enum SyncStatus: String, Codable, Sendable {
    case pending
    case inProgress
    case completed
    case failed
    case conflicted
    case skipped
}

/// Direction of sync.
public enum SyncDirection: String, Codable, Sendable {
    case inbound   // External → Anigma
    case outbound  // Anigma → External
}

/// A detected sync conflict.
public struct SyncConflict: Codable, Sendable {
    public let fieldName: String
    public let externalValue: String
    public let anigmaValue: String
    public let resolution: ConflictResolution?
    public let resolvedAt: Date?
    public let resolvedBy: String?

    public init(
        fieldName: String,
        externalValue: String,
        anigmaValue: String,
        resolution: ConflictResolution? = nil,
        resolvedAt: Date? = nil,
        resolvedBy: String? = nil
    ) {
        self.fieldName = fieldName
        self.externalValue = externalValue
        self.anigmaValue = anigmaValue
        self.resolution = resolution
        self.resolvedAt = resolvedAt
        self.resolvedBy = resolvedBy
    }
}

/// How a conflict was resolved.
public enum ConflictResolution: String, Codable, Sendable {
    case acceptExternal
    case acceptAnigma
    case merge
    case skip
    case manual
}

// MARK: - External System Adapter Protocol

/// Protocol for adapters that sync with external systems.
public protocol ExternalSystemAdapter: Actor {
    /// Unique identifier for this external system.
    var systemId: String { get }

    /// Human-readable name.
    var systemName: String { get }

    /// Domains this adapter can sync.
    var supportedDomains: Set<String> { get }

    /// Fetch records from external system.
    func fetchRecords(
        domain: String,
        since: Date?,
        limit: Int
    ) async throws -> [ExternalRecord]

    /// Push a record to external system.
    func pushRecord(
        domain: String,
        record: ExternalRecord
    ) async throws -> ExternalRecord

    /// Delete a record in external system.
    func deleteRecord(
        domain: String,
        externalId: String
    ) async throws

    /// Check connection health.
    func healthCheck() async -> Bool
}

/// A record from an external system.
public struct ExternalRecord: Codable, Sendable {
    public let externalId: String
    public let domain: String
    public var fields: [String: AnyCodableValue]
    public let createdAt: Date?
    public let updatedAt: Date?
    public let version: String?

    public init(
        externalId: String,
        domain: String,
        fields: [String: AnyCodableValue],
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        version: String? = nil
    ) {
        self.externalId = externalId
        self.domain = domain
        self.fields = fields
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
    }
}

import AnigmaPrimitives

public typealias AnyCodableValue = AnyCodable

// MARK: - Sync Manager

/// Central manager for all sync operations.
public actor SyncManager {
    private var configs: [String: DomainSyncConfig] = [:]
    private var adapters: [String: any ExternalSystemAdapter] = [:]
    private var linkages: [String: EntityId] = [:]  // "systemId:externalId" -> EntityId
    private var syncHistory: [SyncRecord] = []
    private let auditLog: AuditLogging?

    public init(auditLog: AuditLogging? = nil) {
        self.auditLog = auditLog
    }

    // MARK: - Configuration

    /// Registers a domain sync configuration.
    public func registerDomain(_ config: DomainSyncConfig) {
        configs[config.domainName] = config
    }

    /// Gets configuration for a domain.
    public func getConfig(for domain: String) -> DomainSyncConfig? {
        configs[domain]
    }

    /// Updates authority for a domain (the "flip the switch" operation).
    public func setAuthority(
        for domain: String,
        to authority: DataAuthority,
        by principal: String
    ) async {
        guard var config = configs[domain] else { return }
        let oldAuthority = config.authority
        config.authority = authority
        configs[domain] = config

        try? await auditLog?.recordEvent(
            id: UUID(),
            type: ContractsCore.AuditEventType.configChange,
            principal: principal,
            module: "SyncManager",
            description: "Authority changed for \(domain): \(oldAuthority.rawValue) → \(authority.rawValue)",
            metadata: [:]
        )
    }

    /// Registers an external system adapter.
    public func registerAdapter(_ adapter: any ExternalSystemAdapter) async {
        let systemId = await adapter.systemId
        adapters[systemId] = adapter
    }

    // MARK: - Linkage Management

    /// Links an external record to an Anigma entity.
    public func linkRecord(
        systemId: String,
        externalId: String,
        to entityId: EntityId
    ) {
        let key = "\(systemId):\(externalId)"
        linkages[key] = entityId
    }

    /// Gets the Anigma entity linked to an external record.
    public func getLinkedEntity(
        systemId: String,
        externalId: String
    ) -> EntityId? {
        let key = "\(systemId):\(externalId)"
        return linkages[key]
    }

    /// Gets the external ID linked to an Anigma entity.
    public func getLinkedExternalId(
        systemId: String,
        entityId: EntityId
    ) -> String? {
        for (key, entity) in linkages {
            if entity == entityId && key.hasPrefix("\(systemId):") {
                return String(key.dropFirst(systemId.count + 1))
            }
        }
        return nil
    }

    // MARK: - Sync Operations

    /// Performs an inbound sync for a domain.
    public func syncInbound(
        domain: String,
        since: Date? = nil,
        limit: Int = 1000,
        world: World,
        mapper: @escaping (ExternalRecord) async -> (any Component)?
    ) async throws -> [SyncRecord] {
        guard let config = configs[domain] else {
            throw SyncError.domainNotConfigured(domain)
        }

        guard config.syncEnabled else {
            throw SyncError.syncDisabled(domain)
        }

        guard config.authority == .external || config.authority == .bidirectional else {
            throw SyncError.authorityMismatch(domain: domain, expected: .external, actual: config.authority)
        }

        guard let systemId = config.externalSystemId,
              let adapter = adapters[systemId] else {
            throw SyncError.noAdapterConfigured(domain)
        }

        var records: [SyncRecord] = []
        let externalRecords = try await adapter.fetchRecords(domain: domain, since: since, limit: limit)

        for external in externalRecords {
            let record = await processInboundRecord(
                external: external,
                config: config,
                systemId: systemId,
                world: world,
                mapper: mapper
            )
            records.append(record)
            syncHistory.append(record)
        }

        return records
    }

    private func processInboundRecord(
        external: ExternalRecord,
        config: DomainSyncConfig,
        systemId: String,
        world: World,
        mapper: @escaping (ExternalRecord) async -> (any Component)?
    ) async -> SyncRecord {
        let existingEntity = getLinkedEntity(systemId: systemId, externalId: external.externalId)

        // Map external record to component
        guard let component = await mapper(external) else {
            return SyncRecord(
                domainName: config.domainName,
                externalSystemId: systemId,
                externalRecordId: external.externalId,
                anigmaEntityId: existingEntity,
                operation: .update,
                status: .skipped,
                direction: .inbound,
                errorMessage: "Mapper returned nil"
            )
        }

        let operation: SyncOperation = existingEntity == nil ? .create : .update

        let entityId: EntityId
        if let existing = existingEntity {
            entityId = existing
        } else {
            let newEntityId = await world.createEntity()
            linkRecord(systemId: systemId, externalId: external.externalId, to: newEntityId)
            entityId = newEntityId
        }

        await world.addComponent(entityId, component)

        return SyncRecord(
            domainName: config.domainName,
            externalSystemId: systemId,
            externalRecordId: external.externalId,
            anigmaEntityId: entityId,
            operation: operation,
            status: .completed,
            direction: .inbound,
            fieldsAffected: Array(external.fields.keys)
        )
    }

    // MARK: - History & Reporting

    /// Gets sync history for a domain.
    public func getHistory(
        domain: String? = nil,
        since: Date? = nil,
        limit: Int = 100
    ) -> [SyncRecord] {
        var result = syncHistory

        if let domain = domain {
            result = result.filter { $0.domainName == domain }
        }

        if let since = since {
            result = result.filter { $0.timestamp >= since }
        }

        return Array(result.suffix(limit))
    }

    /// Gets sync statistics.
    public func getStats(for domain: String? = nil) -> SyncStats {
        let records = domain.map { d in syncHistory.filter { $0.domainName == d } } ?? syncHistory

        return SyncStats(
            totalOperations: records.count,
            successful: records.filter { $0.status == .completed }.count,
            failed: records.filter { $0.status == .failed }.count,
            conflicted: records.filter { $0.status == .conflicted }.count,
            inbound: records.filter { $0.direction == .inbound }.count,
            outbound: records.filter { $0.direction == .outbound }.count
        )
    }
}

/// Sync statistics.
public struct SyncStats: Sendable {
    public let totalOperations: Int
    public let successful: Int
    public let failed: Int
    public let conflicted: Int
    public let inbound: Int
    public let outbound: Int

    public var successRate: Double {
        guard totalOperations > 0 else { return 0 }
        return Double(successful) / Double(totalOperations)
    }
}

// MARK: - Sync Errors

public enum SyncError: Error, LocalizedError {
    case domainNotConfigured(String)
    case syncDisabled(String)
    case authorityMismatch(domain: String, expected: DataAuthority, actual: DataAuthority)
    case noAdapterConfigured(String)
    case externalSystemUnavailable(String)
    case conflictUnresolved(SyncConflict)
    case mappingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .domainNotConfigured(let d):
            return "Domain not configured for sync: \(d)"
        case .syncDisabled(let d):
            return "Sync disabled for domain: \(d)"
        case .authorityMismatch(let d, let expected, let actual):
            return "Authority mismatch for \(d): expected \(expected.rawValue), got \(actual.rawValue)"
        case .noAdapterConfigured(let d):
            return "No external system adapter configured for domain: \(d)"
        case .externalSystemUnavailable(let s):
            return "External system unavailable: \(s)"
        case .conflictUnresolved(let c):
            return "Unresolved sync conflict in field: \(c.fieldName)"
        case .mappingFailed(let m):
            return "Failed to map record: \(m)"
        }
    }
}

// MARK: - Sync Component

/// Component that tracks sync metadata for an entity.
public struct SyncMetadataComponent: Component, Sendable {
    public var syncedSystems: [SyncedSystemInfo]
    public var lastSyncAt: Date?
    public var syncConflicts: [SyncConflict]
    public var manualOverrides: Set<String>  // Fields manually overridden, skip sync

    public init(
        syncedSystems: [SyncedSystemInfo] = [],
        lastSyncAt: Date? = nil,
        syncConflicts: [SyncConflict] = [],
        manualOverrides: Set<String> = []
    ) {
        self.syncedSystems = syncedSystems
        self.lastSyncAt = lastSyncAt
        self.syncConflicts = syncConflicts
        self.manualOverrides = manualOverrides
    }

    public mutating func addSyncedSystem(_ info: SyncedSystemInfo) {
        if let idx = syncedSystems.firstIndex(where: { $0.systemId == info.systemId }) {
            syncedSystems[idx] = info
        } else {
            syncedSystems.append(info)
        }
        lastSyncAt = Date()
    }
}

/// Info about sync with a specific external system.
public struct SyncedSystemInfo: Codable, Sendable {
    public let systemId: String
    public let externalId: String
    public var lastSyncAt: Date
    public var syncDirection: SyncDirection
    public var version: String?

    public init(
        systemId: String,
        externalId: String,
        lastSyncAt: Date = Date(),
        syncDirection: SyncDirection,
        version: String? = nil
    ) {
        self.systemId = systemId
        self.externalId = externalId
        self.lastSyncAt = lastSyncAt
        self.syncDirection = syncDirection
        self.version = version
    }
}
