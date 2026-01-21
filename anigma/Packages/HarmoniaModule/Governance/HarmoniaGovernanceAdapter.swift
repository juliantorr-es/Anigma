//
//  HarmoniaGovernanceAdapter.swift
//  HarmoniaModule
//
//  Adapter to bridge HarmoniaModule to the new Tier 2 Governance system.
//  Demonstrates migration from DatabaseActor to DatabaseAuthority.
//

import Foundation
import AnigmaPrimitives
import AnigmaCore
import DatabaseCore

/// Adapter to bridge HarmoniaModule to the new Tier 2 Governance system.
public actor HarmoniaGovernanceAdapter {
    private let database: any DatabaseAuthority

    public init(database: any DatabaseAuthority) {
        self.database = database
    }

    /// Initialize the adapter schema
    public func initialize() async throws {
        let schema = ModuleSchema(
            name: "harmonia_governance_adapter",
            version: 1,
            module: "harmonia",
            migrations: [
                1: """
                CREATE TABLE IF NOT EXISTS session_lifecycle_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    session_id TEXT NOT NULL,
                    event TEXT NOT NULL,
                    timestamp INTEGER NOT NULL
                )
                """
            ]
        )
        try await database.registerSchema(schema)
    }

    /// Record a session lifecycle event using governed mutation
    public func recordSessionLifecycle(
        sessionId: String,
        event: String,
        context: ExecutionContext
    ) async throws -> MutationReceipt {
        let mutation = DatabaseMutation(
            sql: "INSERT INTO session_lifecycle_events (session_id, event, timestamp) VALUES (?, ?, ?)",
            parameters: [
                .text(sessionId),
                .text(event),
                .int(Int(Date().timeIntervalSince1970))
            ],
            componentType: "harmonia_session", // For governance check
            entityId: EntityId(raw: UUID(uuidString: sessionId) ?? UUID())
        )

        return try await database.mutate(mutation, context: context)
    }
}
