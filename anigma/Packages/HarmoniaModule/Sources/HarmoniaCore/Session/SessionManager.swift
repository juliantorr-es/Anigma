//
//  SessionManager.swift
//  HarmoniaModule
//
//  Session management with master + temporary schema architecture.
//  Enables parallel agent execution with safe merging.
//

import Foundation



import DatabaseCore
import AnigmaCore
import ContractsCore
@preconcurrency import Foundation
import AnigmaPrimitives

// Session status enum
public enum SessionStatus: String, Codable, Sendable {
    case active
    case paused
    case completed
    case failed
    case archived
}

/// Session manager for multi-database architecture.
/// Handles master + session schema coordination.
public actor SessionManager {
    private let masterDb: any AnigmaFoundation.DatabaseAuthority
    private let sessionSchemaPrefix: String
    private var activeSessions: [String: ManagedSessionContext] = [:]

    public init(masterDb: any AnigmaFoundation.DatabaseAuthority, sessionSchemaPrefix: String = "session") {
        self.masterDb = masterDb
        self.sessionSchemaPrefix = sessionSchemaPrefix
    }

    /// Create new session with temporary schema.
    public func createSession(
        agentId: String,
        permissions: Set<Permission>,
        metadata: [String: String] = [:],
        context: ExecutionContext
    ) async throws -> String {
        let sessionId = UUID().uuidString
        let sessionReference = makeSessionReference(for: sessionId)

        // Initialize session schema (copy from master).
        try await initializeSessionSchema(schemaReference: sessionReference)

        // Record session start in master
        let mutation = DatabaseMutation(
            sql: """
                INSERT INTO session_lifecycle (
                    session_id, agent_id, start_time, status, permissions, metadata, database_reference
                ) VALUES (?, ?, ?, 'active', ?, ?, ?)
            """,
            parameters: [
                .text(sessionId),
                .text(agentId),
                .text(String(Int(Date().timeIntervalSince1970))),
                .text(
                    (try? JSONEncoder().encode(Array(permissions))).flatMap {
                        String(data: $0, encoding: .utf8)
                    } ?? "[]"),
                .text(
                    (try? JSONEncoder().encode(metadata)).flatMap {
                        String(data: $0, encoding: .utf8)
                    } ?? "{}"),
                .text(sessionReference)
            ],
            componentType: "session",
            entityId: EntityId(uuidString: sessionId)
        )

        _ = try await masterDb.mutate(mutation, context: context)

        let sessionContext = ManagedSessionContext(
            sessionId: sessionId,
            agentId: agentId,
            startTime: Date(),
            permissions: permissions,
            status: .active,
            metadata: metadata,
            databaseReference: sessionReference
        )

        activeSessions[sessionId] = sessionContext
        return sessionId
    }

    /// Get session context.
    public func getSession(_ sessionId: String) async throws -> ManagedSessionContext {
        guard let sessionContext = activeSessions[sessionId] else {
            throw SessionError.notFound(sessionId)
        }
        return sessionContext
    }

    /// Get the schema reference for a session database.
    public func getSessionDatabaseReference(_ sessionId: String) -> String? {
        activeSessions[sessionId]?.databaseReference
    }

    /// Delete a session and its schema reference.
    public func deleteSession(sessionId: String) async throws {
        guard let context = activeSessions[sessionId] else {
            return
        }
        try await cleanupSession(context)
    }

    /// Update session status.
    public func updateSessionStatus(
        _ sessionId: String,
        status: SessionStatus,
        context: ExecutionContext
    ) async throws {
        guard activeSessions[sessionId] != nil else {
            throw SessionError.notFound(sessionId)
        }

        activeSessions[sessionId]?.status = status

        let mutation = DatabaseMutation(
            sql: """
                UPDATE session_lifecycle
                SET status = ?, end_time = ?
                WHERE session_id = ?
            """,
            parameters: [
                .text(status.rawValue),
                .text(String(Int(Date().timeIntervalSince1970))),
                .text(sessionId)
            ],
            componentType: "session",
            entityId: EntityId(uuidString: sessionId)
        )

        _ = try await masterDb.mutate(mutation, context: context)
    }

    /// Merge session into master database.
    public func mergeSession(_ sessionId: String, context: ExecutionContext) async throws {
        guard let sessionContext = activeSessions[sessionId] else {
            throw SessionError.notFound(sessionId)
        }

        // Policy gate: only merge successful sessions
        let sessionResult = await evaluateSessionOutcome(sessionContext)
        guard sessionResult.canMerge else {
            throw SessionError.mergeNotAllowed(sessionResult.reason)
        }

        // Perform safe merge
        try await mergeSessionToMaster(sessionContext, context: context)

        // Update session status
        try await updateSessionStatus(sessionId, status: .completed, context: context)

        // Cleanup session
        try await cleanupSession(sessionContext)
    }

    /// Get all active sessions.
    public func getActiveSessions() async -> [ManagedSessionContext] {
        return Array(activeSessions.values)
    }

    /// Initialize session schema.
    private func initializeSessionSchema(schemaReference: String) async throws {
        let safeSchema = try requireSafeIdentifier(schemaReference)

        let systemContext = ExecutionContext(principal: .system)

        try await masterDb.mutate(
            DatabaseMutation(
                sql: "CREATE SCHEMA IF NOT EXISTS \(safeSchema);",
                componentType: "session",
                entityId: EntityId(uuidString: UUID().uuidString)
            ),
            context: systemContext
        )

        // Migration 1: Tool calls table
        try await masterDb.mutate(
            DatabaseMutation(
                sql: """
                CREATE TABLE IF NOT EXISTS \(safeSchema).tool_calls (
                    id TEXT PRIMARY KEY NOT NULL,
                    session_id TEXT NOT NULL,
                    tool_name TEXT NOT NULL,
                    started_at BIGINT NOT NULL,
                    completed_at BIGINT,
                    status TEXT NOT NULL,
                    input_hash TEXT NOT NULL,
                    parameters TEXT,
                    file_path TEXT,
                    output_hash TEXT,
                    error_signature TEXT,
                    created_at BIGINT NOT NULL DEFAULT (CAST(EXTRACT(EPOCH FROM CURRENT_TIMESTAMP) AS BIGINT))
                );
                """,
                componentType: "session",
                entityId: EntityId(uuidString: UUID().uuidString)
            ),
            context: systemContext
        )

        // Migration 2: Loop events table
        try await masterDb.mutate(
            DatabaseMutation(
                sql: """
                CREATE TABLE IF NOT EXISTS \(safeSchema).loop_events (
                    id TEXT PRIMARY KEY NOT NULL,
                    tool_call_id TEXT NOT NULL,
                    event_type TEXT NOT NULL,
                    signature_hash TEXT NOT NULL,
                    threshold INTEGER NOT NULL,
                    window_seconds INTEGER NOT NULL,
                    recovery_strategy TEXT,
                    context TEXT,
                    created_at BIGINT NOT NULL DEFAULT (CAST(EXTRACT(EPOCH FROM CURRENT_TIMESTAMP) AS BIGINT)),
                    FOREIGN KEY (tool_call_id) REFERENCES \(safeSchema).tool_calls(id)
                );
                """,
                componentType: "session",
                entityId: EntityId(uuidString: UUID().uuidString)
            ),
            context: systemContext
        )

        // Migration 3: Tool call artifacts table
        try await masterDb.mutate(
            DatabaseMutation(
                sql: """
                CREATE TABLE IF NOT EXISTS \(safeSchema).tool_call_artifacts (
                    id TEXT PRIMARY KEY NOT NULL,
                    tool_call_id TEXT NOT NULL,
                    artifact_type TEXT NOT NULL,
                    artifact_path TEXT NOT NULL,
                    content_hash TEXT NOT NULL,
                    size_bytes INTEGER NOT NULL,
                    created_at BIGINT NOT NULL DEFAULT (CAST(EXTRACT(EPOCH FROM CURRENT_TIMESTAMP) AS BIGINT)),
                    FOREIGN KEY (tool_call_id) REFERENCES \(safeSchema).tool_calls(id)
                );
                """,
                componentType: "session",
                entityId: EntityId(uuidString: UUID().uuidString)
            ),
            context: systemContext
        )
    }

    /// Evaluate session outcome for merge eligibility.
    private func evaluateSessionOutcome(_ context: ManagedSessionContext) async -> SessionResult {
        // Check session duration
        let duration = Date().timeIntervalSince(context.startTime)
        if duration < 5.0 {  // Less than 5 seconds
            return SessionResult(canMerge: false, reason: "Session too short (\(Int(duration))s)")
        }

        // Check for errors in session DB
        let errorRows = try? await masterDb.query(
            """
                SELECT COUNT(*) as count
                FROM \(context.databaseReference).tool_calls
                WHERE status = 'failed'
            """
        )
        let errorCount = errorRows?.first?.int(for: "count") ?? 0

        if errorCount > 10 {  // Too many errors
            return SessionResult(canMerge: false, reason: "Too many errors (\(errorCount))")
        }

        return SessionResult(canMerge: true, reason: "Session eligible for merge")
    }

    /// Merge session data into master database.
    private func mergeSessionToMaster(_ sessionContext: ManagedSessionContext, context: ExecutionContext) async throws {
        let safeSchema = try requireSafeIdentifier(sessionContext.databaseReference)

        // 1. Export tool calls
        let sessionCalls = try await masterDb.query(
            """
                SELECT * FROM \(safeSchema).tool_calls ORDER BY started_at
            """
        )

        // 2. Export loop events
        let loopEvents = try await masterDb.query(
            """
                SELECT * FROM \(safeSchema).loop_events
            """
        )

        // 3. Export artifacts
        let artifacts = try await masterDb.query(
            """
                SELECT * FROM \(safeSchema).tool_call_artifacts
            """
        )

        // Import to master in single transaction
        try await masterDb.transaction(context: context) {
            // Import calls
            for call in sessionCalls {
                let mutation = DatabaseMutation(
                    sql: """
                        INSERT INTO tool_calls (
                            id, session_id, tool_name, started_at, completed_at, status,
                            input_hash, output_hash, error_signature
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                        ON CONFLICT DO NOTHING
                    """,
                    parameters: [
                        .text(call.string(for: "id") ?? ""),
                        .text(call.string(for: "session_id") ?? ""),
                        .text(call.string(for: "tool_name") ?? ""),
                        .int(call.int(for: "started_at") ?? 0),
                        .int(call.int(for: "completed_at") ?? 0),
                        .text(call.string(for: "status") ?? ""),
                        .text(call.string(for: "input_hash") ?? ""),
                        .text(call.string(for: "output_hash") ?? ""),
                        .text(call.string(for: "error_signature") ?? "")
                    ],
                    componentType: "tool_call",
                    entityId: EntityId(uuidString: call.string(for: "id") ?? "")
                )
                _ = try await self.masterDb.mutate(mutation, context: context)
            }

            // Import loop events
            for event in loopEvents {
                let mutation = DatabaseMutation(
                    sql: """
                        INSERT INTO loop_events (
                            id, tool_call_id, event_type, signature_hash, threshold,
                            window_seconds, recovery_strategy, context
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        ON CONFLICT DO NOTHING
                    """,
                    parameters: [
                        .text(event.string(for: "id") ?? ""),
                        .text(event.string(for: "tool_call_id") ?? ""),
                        .text(event.string(for: "event_type") ?? ""),
                        .text(event.string(for: "signature_hash") ?? ""),
                        .int(event.int(for: "threshold") ?? 0),
                        .int(event.int(for: "window_seconds") ?? 0),
                        .text(event.string(for: "recovery_strategy") ?? ""),
                        .text(event.string(for: "context") ?? "{}")
                    ],
                    componentType: "loop_event",
                    entityId: EntityId(uuidString: event.string(for: "id") ?? "")
                )
                _ = try await self.masterDb.mutate(mutation, context: context)
            }

            // Import artifacts
            for artifact in artifacts {
                let mutation = DatabaseMutation(
                    sql: """
                        INSERT INTO tool_call_artifacts (
                            id, tool_call_id, artifact_type, artifact_path,
                            content_hash, size_bytes
                        ) VALUES (?, ?, ?, ?, ?, ?)
                        ON CONFLICT DO NOTHING
                    """,
                    parameters: [
                        .text(artifact.string(for: "id") ?? ""),
                        .text(artifact.string(for: "tool_call_id") ?? ""),
                        .text(artifact.string(for: "artifact_type") ?? ""),
                        .text(artifact.string(for: "artifact_path") ?? ""),
                        .text(artifact.string(for: "content_hash") ?? ""),
                        .int(artifact.int(for: "size_bytes") ?? 0)
                    ],
                    componentType: "artifact",
                    entityId: EntityId(uuidString: artifact.string(for: "id") ?? "")
                )
                _ = try await self.masterDb.mutate(mutation, context: context)
            }
        }

        // Recompute derived views in master
        try await recomputeMasterViews(context: context)
    }

    /// Recompute master database views.
    private func recomputeMasterViews(context: ExecutionContext) async throws {
        // Update session status view (now using the unified tool_calls table)
        let deleteMutation = DatabaseMutation(sql: "DELETE FROM session_status_view")
        _ = try? await masterDb.mutate(deleteMutation, context: context)

        let insertMutation = DatabaseMutation(
            sql: """
                INSERT INTO session_status_view
                SELECT session_id, MAX(started_at) as last_activity,
                       COUNT(*) as tool_calls,
                       SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as errors
                FROM tool_calls
                GROUP BY session_id
            """
        )
        _ = try? await masterDb.mutate(insertMutation, context: context)
    }

    /// Cleanup session database and context.
    private func cleanupSession(_ context: ManagedSessionContext) async throws {
        // Remove from active sessions
        activeSessions.removeValue(forKey: context.sessionId)
    }

    /// Terminate session without merging.
    public func terminateSession(_ sessionId: String, reason: String, context: ExecutionContext) async throws {
        guard let sessionContext = activeSessions[sessionId] else {
            throw SessionError.notFound(sessionId)
        }

        // Record termination reason
        let mutation = DatabaseMutation(
            sql: """
                UPDATE session_lifecycle
                SET status = 'terminated', end_time = ?, termination_reason = ?
                WHERE session_id = ?
            """,
            parameters: [
                .text(String(Int(Date().timeIntervalSince1970))),
                .text(reason),
                .text(sessionId)
            ],
            componentType: "session",
            entityId: EntityId(uuidString: sessionId)
        )

        _ = try await masterDb.mutate(mutation, context: context)

        // Cleanup session
        try await cleanupSession(sessionContext)
    }
}

// MARK: - Supporting Types

/// Session context with database and metadata.
public struct ManagedSessionContext: Sendable {
    public let sessionId: String
    public let agentId: String
    public let startTime: Date
    public let permissions: Set<Permission>
    public var status: SessionStatus
    public let metadata: [String: String]
    public let databaseReference: String

    public init(
        sessionId: String,
        agentId: String,
        startTime: Date,
        permissions: Set<Permission>,
        status: SessionStatus,
        metadata: [String: String],
        databaseReference: String
    ) {
        self.sessionId = sessionId
        self.agentId = agentId
        self.startTime = startTime
        self.permissions = permissions
        self.status = status
        self.metadata = metadata
        self.databaseReference = databaseReference
    }
}

/// Session evaluation result.
public struct SessionResult: Sendable {
    public let canMerge: Bool
    public let reason: String

    public init(canMerge: Bool, reason: String) {
        self.canMerge = canMerge
        self.reason = reason
    }
}

/// Session-specific errors.
public enum SessionError: Error, LocalizedError {
    case notFound(String)
    case mergeNotAllowed(String)
    case initializationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let sessionId):
            return "Session not found: \(sessionId)"
        case .mergeNotAllowed(let reason):
            return "Merge not allowed: \(reason)"
        case .initializationFailed(let message):
            return "Session initialization failed: \(message)"
        }
    }
}

extension SessionManager {
    private func makeSessionReference(for sessionId: String) -> String {
        let raw = "\(sessionSchemaPrefix)_\(sessionId)"
        return raw.replacingOccurrences(of: "-", with: "_")
    }

    private func requireSafeIdentifier(_ value: String) throws -> String {
        guard !value.isEmpty else {
            throw SessionError.initializationFailed("empty identifier")
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        if value.rangeOfCharacter(from: allowed.inverted) != nil {
            throw SessionError.initializationFailed("unsafe identifier: \(value)")
        }
        return value
    }
}
