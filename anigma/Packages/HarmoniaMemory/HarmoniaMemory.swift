//
//  HarmoniaMemory.swift
//  HarmoniaMemory
//
//  PostgreSQL-backed memory persistence for tri-memory architecture.
//
//  This module provides:
//  - PostgresMemoryStore: PostgreSQL implementation of memory persistence
//  - MemoryObservation: ECS component for capturing observations
//  - ObservationCaptureSystem: System that captures tool calls and events
//  - MemorySessionSummary: Aggregated session summaries
//

import AnigmaCore
import TelemetryCore

// MARK: - Module Info

public enum HarmoniaMemoryVersion {
    public static let major = 0
    public static let minor = 1
    public static let patch = 0
    public static let string = "\(major).\(minor).\(patch)"
}

// MARK: - Module Registration

/// Registers Harmonia Memory systems with the ECS.
/// Call this during application startup.
///
/// ## Usage
/// ```swift
/// let world = World()
/// let registry = WorkflowRegistry()
/// await HarmoniaMemory.register(world: world, registry: registry)
/// ```
public enum HarmoniaMemory {
    public static func register(
        world: World,
        registry: WorkflowRegistry,
        config: MemoryConfig = .default,
        telemetry: TelemetryClient? = nil
    ) async throws {
        // Create PostgreSQL memory store
        let memoryStore = try await PostgresMemoryStore(config: config)

        // Create memory service
        let memoryService = MemoryService(memoryStore: memoryStore)

        // Register observation capture system
        try await world.registerSystem(
            ObservationCaptureSystem(
                memoryService: memoryService,
                telemetryClient: telemetry
            ))

        print("[HarmoniaMemory] v\(HarmoniaMemoryVersion.string) registered")
    }

    /// Creates a configured memory service.
    /// Useful for testing or standalone usage.
    public static func createMemoryService(config: MemoryConfig = .default) async throws
        -> MemoryService {
        let memoryStore = try await PostgresMemoryStore(config: config)
        return MemoryService(memoryStore: memoryStore)
    }
}

// MARK: - Memory Service

/// Main service for memory operations.
public actor MemoryService {
    private let memoryStore: PostgresMemoryStore

    public init(memoryStore: PostgresMemoryStore) {
        self.memoryStore = memoryStore
    }

    /// Stores an observation.
    public func storeObservation(_ observation: MemoryObservation) async throws {
        try await memoryStore.storeObservation(observation)
    }

    /// Searches observations.
    public func searchObservations(
        query: String,
        sessionId: String? = nil,
        tenantId: String? = nil,
        limit: Int = 100
    ) async throws -> [MemoryObservation] {
        try await memoryStore.searchObservations(
            query: query,
            sessionId: sessionId,
            tenantId: tenantId,
            limit: limit
        )
    }

    /// Gets session summary.
    public func getSessionSummary(sessionId: String) async throws -> MemorySessionSummary? {
        try await memoryStore.getSessionSummary(sessionId: sessionId)
    }

    /// Updates session summary.
    public func updateSessionSummary(_ summary: MemorySessionSummary) async throws {
        try await memoryStore.updateSessionSummary(summary)
    }

    /// Gets active sessions.
    public func getActiveSessions(tenantId: String? = nil) async throws -> [MemorySessionSummary] {
        try await memoryStore.getActiveSessions(tenantId: tenantId)
    }

    /// Ends a session.
    public func endSession(sessionId: String) async throws {
        try await memoryStore.endSession(sessionId: sessionId)
    }
}

// MARK: - Configuration

/// Configuration for memory subsystem.
public struct MemoryConfig: Sendable {
    /// PostgreSQL connection string or backend reference.
    public var databasePath: String

    /// Enable FTS5 full-text search.
    public var enableFTS: Bool

    /// Maximum number of observations per session (soft limit).
    public var maxObservationsPerSession: Int

    /// Whether to enable memory for tri-memory bridge.
    public var enableTriMemoryBridge: Bool

    public init(
        databasePath: String = "postgresql://localhost:5432/harmonia_memory",
        enableFTS: Bool = true,
        maxObservationsPerSession: Int = 1000,
        enableTriMemoryBridge: Bool = true
    ) {
        self.databasePath = databasePath
        self.enableFTS = enableFTS
        self.maxObservationsPerSession = maxObservationsPerSession
        self.enableTriMemoryBridge = enableTriMemoryBridge
    }

    public static let `default` = MemoryConfig()
}
