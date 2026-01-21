//
//  MasterLedgerStore.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Master ledger event that references content-addressed artifacts.
public struct MasterLedgerEvent: Sendable {
    /// Unique identifier for this event.
    public let eventID: String

    /// Type of event (e.g., "tool_call", "build_result", "inference").
    public let eventType: String

    /// Tool or operation name that produced this event.
    public let toolName: String

    /// Session or run ID that contains this event.
    public let sessionID: String

    /// Status of the operation ("success", "failure", "timeout").
    public let status: String

    /// Hash of the inputs to the operation (for precondition verification).
    public let preconditionHash: String?

    /// Hash of relevant files/content before operation.
    public let fileHashBefore: String?

    /// Hash of the tool output (stored separately in content-addressed store).
    public let resultContentHash: String?

    /// Summary of any error that occurred.
    public let errorSignature: String?

    /// When this event occurred.
    public let timestamp: Date

    /// Duration in milliseconds (if applicable).
    public let durationMs: Int?

    /// Optional metadata as JSON.
    public let metadata: Data?

    public init(
        eventID: String,
        eventType: String,
        toolName: String,
        sessionID: String,
        status: String,
        preconditionHash: String? = nil,
        fileHashBefore: String? = nil,
        resultContentHash: String? = nil,
        errorSignature: String? = nil,
        timestamp: Date,
        durationMs: Int? = nil,
        metadata: Data? = nil
    ) {
        self.eventID = eventID
        self.eventType = eventType
        self.toolName = toolName
        self.sessionID = sessionID
        self.status = status
        self.preconditionHash = preconditionHash
        self.fileHashBefore = fileHashBefore
        self.resultContentHash = resultContentHash
        self.errorSignature = errorSignature
        self.timestamp = timestamp
        self.durationMs = durationMs
        self.metadata = metadata
    }
}

/// Thinned master ledger that stores events with hash references to content-addressed artifacts.
public actor MasterLedgerStore {
    private let db: DatabaseActor
    private var searchManager: SemanticSearchManager?
    private var eventIndexer: LedgerEventIndexer?

    public init(database: DatabaseActor) async throws {
        self.db = database
        try await setupSchema()

        // Initialize semantic search components
        do {
            let searchManager = SemanticSearchManager(database: db)
            try await searchManager.initialize()
            self.searchManager = searchManager
            self.eventIndexer = LedgerEventIndexer(searchManager: searchManager)
        } catch {
            self.searchManager = nil
            self.eventIndexer = nil
        }
    }

    /// Set up master ledger tables with thinned payloads (only hashes, no embedded blobs).
    private func setupSchema() async throws {
        // Initialize ledger segmentation schema
        try await db.initializeLedgerSegmentationSchema()
        try await db.execute(
            "CREATE TABLE IF NOT EXISTS master_ledger_events (event_id TEXT PRIMARY KEY, event_type TEXT NOT NULL, tool_name TEXT NOT NULL, session_id TEXT NOT NULL, status TEXT NOT NULL, precondition_hash TEXT, file_hash_before TEXT, result_content_hash TEXT, error_signature TEXT, timestamp REAL NOT NULL, duration_ms INTEGER, metadata BLOB);"
        )

        // Indexes for efficient querying
        try await db.execute(
            "CREATE INDEX IF NOT EXISTS idx_master_events_session ON master_ledger_events(session_id, timestamp);"
        )

        try await db.execute(
            "CREATE INDEX IF NOT EXISTS idx_master_events_type ON master_ledger_events(event_type, status);"
        )

        try await db.execute(
            "CREATE INDEX IF NOT EXISTS idx_master_events_tool ON master_ledger_events(tool_name);"
        )

        try await db.execute(
            "CREATE INDEX IF NOT EXISTS idx_master_events_timestamp ON master_ledger_events(timestamp);"
        )

        // Table for tracking retention events (which artifacts were deleted and why)
        try await db.execute(
            "CREATE TABLE IF NOT EXISTS retention_events (retention_id TEXT PRIMARY KEY, policy_version_hash TEXT NOT NULL, started_at REAL NOT NULL, completed_at REAL NOT NULL, artifacts_deleted INTEGER, payload_bytes_freed INTEGER, deletion_reason TEXT, metadata BLOB);"
        )

        try await db.execute(
            "CREATE INDEX IF NOT EXISTS idx_retention_events_timestamp ON retention_events(started_at);"
        )
    }

    /// Record a tool execution event.
    public func recordToolCallEvent(
        toolName: String,
        sessionID: String,
        status: String,
        preconditionHash: String? = nil,
        resultContentHash: String? = nil,
        errorSignature: String? = nil,
        durationMs: Int? = nil,
        metadata: Data? = nil
    ) async throws -> MasterLedgerEvent {
        let eventID = UUID().uuidString
        let timestamp = Date()
        
        // Try using segmented ledger first
        let ledgerEvent = LedgerEvent(
            eventId: eventID,
            agentId: sessionID,
            workflowId: nil,
            eventType: "tool_call",
            timestamp: timestamp,
            payloadHash: resultContentHash,
            metadataJson: metadata.flatMap { String(data: $0, encoding: .utf8) }
        )
        try await db.writeEventToSegment(ledgerEvent)

        // Index event for semantic search if available
        if let indexer = eventIndexer {
            let textContent = buildTextContentForIndexing(toolName: toolName, metadata: metadata)
            try await indexer.indexEvent(
                segmentId: "current", // Will be resolved by the segmentation manager
                eventId: eventID,
                contentHash: resultContentHash ?? "",
                textContent: textContent
            )
        }

        return MasterLedgerEvent(
            eventID: eventID,
            eventType: "tool_call",
            toolName: toolName,
            sessionID: sessionID,
            status: status,
            preconditionHash: preconditionHash,
            fileHashBefore: nil,
            resultContentHash: resultContentHash,
            errorSignature: errorSignature,
            timestamp: timestamp,
            durationMs: durationMs,
            metadata: metadata
        )
    }

    /// Fetch master ledger events for a session.
    public func fetchSessionEvents(sessionID: String) async throws -> [MasterLedgerEvent] {
        let rows = try await db.query(
            "SELECT event_id, event_type, tool_name, session_id, status, precondition_hash, file_hash_before, result_content_hash, error_signature, timestamp, duration_ms, metadata FROM master_ledger_events WHERE session_id = ? ORDER BY timestamp ASC",
            parameters: [.text(sessionID)]
        )

        return rows.compactMap { row in
            guard let eventID = row.string(for: "event_id"),
                  let eventType = row.string(for: "event_type"),
                  let toolName = row.string(for: "tool_name"),
                  let sessionID = row.string(for: "session_id"),
                  let status = row.string(for: "status"),
                  let timestampDouble = row.double(for: "timestamp") else {
                return nil
            }

            return MasterLedgerEvent(
                eventID: eventID,
                eventType: eventType,
                toolName: toolName,
                sessionID: sessionID,
                status: status,
                preconditionHash: row.string(for: "precondition_hash"),
                fileHashBefore: row.string(for: "file_hash_before"),
                resultContentHash: row.string(for: "result_content_hash"),
                errorSignature: row.string(for: "error_signature"),
                timestamp: Date(timeIntervalSince1970: timestampDouble),
                durationMs: row.int(for: "duration_ms"),
                metadata: row.data(for: "metadata")
            )
        }
    }

    /// Record a retention event (when artifacts were deleted).
    public func recordRetentionEvent(
        policyVersionHash: String,
        artifactsDeleted: Int,
        payloadBytesFreed: Int,
        deletionReason: String,
        metadata: Data? = nil
    ) async throws -> String {
        let retentionID = UUID().uuidString
        let now = Date()

        try await db.execute(
            "INSERT INTO retention_events (retention_id, policy_version_hash, started_at, completed_at, artifacts_deleted, payload_bytes_freed, deletion_reason, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            parameters: [
                .text(retentionID),
                .text(policyVersionHash),
                .double(now.timeIntervalSince1970),
                .double(now.timeIntervalSince1970),
                .int(artifactsDeleted),
                .int(payloadBytesFreed),
                .text(deletionReason),
                metadata.map { .blob($0) } ?? .null
            ]
        )

        return retentionID
    }

    /// Get statistics about the master ledger.
    public func getStatistics() async throws -> (totalEvents: Int, successCount: Int, failureCount: Int, averageDurationMs: Double) {
        let rows = try await db.query(
            "SELECT COUNT(*) as total_events, SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) as success_count, SUM(CASE WHEN status = 'failure' THEN 1 ELSE 0 END) as failure_count, AVG(duration_ms) as avg_duration FROM master_ledger_events"
        )

        guard let row = rows.first else {
            return (0, 0, 0, 0.0)
        }

        let totalEvents = row.int(for: "total_events") ?? 0
        let successCount = row.int(for: "success_count") ?? 0
        let failureCount = row.int(for: "failure_count") ?? 0
        let avgDuration = row.double(for: "avg_duration") ?? 0.0

        return (totalEvents, successCount, failureCount, avgDuration)
    }

    /// Check if an event references a specific content hash (for retention checks).
    public func eventReferencesContent(contentHash: String) async throws -> Bool {
        // Check segmented ledger first
        do {
            let segmentManager = MasterLedgerSegmentationManager(database: db)
            let crossSegmentQuery = CrossSegmentQueryExecutor(database: db, segmentManager: segmentManager)

            // Query all segments looking for content hash
            let events = try await crossSegmentQuery.queryAllSegments(
                filter: EventFilter(),
                limit: 1000
            )

            return events.contains { $0.payloadHash == contentHash }
        } catch {
            // Fallback to legacy table
            let rows = try await db.query(
                "SELECT COUNT(*) as count FROM master_ledger_events WHERE result_content_hash = ?",
                parameters: [.text(contentHash)]
            )

            guard let row = rows.first else { return false }
            return (row.int(for: "count") ?? 0) > 0
        }
    }

    /// Get events by session ID using segmented ledger (new method).
    public func getEventsBySessionSegmented(
        sessionID: String,
        limit: Int = 100
    ) async throws -> [MasterLedgerEvent] {
        let segmentManager = MasterLedgerSegmentationManager(database: db)
        let crossSegmentQuery = CrossSegmentQueryExecutor(database: db, segmentManager: segmentManager)
        let filter = EventFilter(agentId: sessionID)

        let segmentEvents = try await crossSegmentQuery.queryAllSegments(filter: filter, limit: limit)

        // Convert segment events to MasterLedgerEvent format
        return segmentEvents.compactMap { segmentEvent -> MasterLedgerEvent? in
            let metadataJSON = segmentEvent.metadataJson?.data(using: .utf8)
            return MasterLedgerEvent(
                eventID: segmentEvent.eventId,
                eventType: segmentEvent.eventType,
                toolName: segmentEvent.eventType, // Use eventType as toolName for migration
                sessionID: segmentEvent.agentId,
                status: "success", // Default status since not stored in segmented
                preconditionHash: nil,
                fileHashBefore: nil,
                resultContentHash: segmentEvent.payloadHash,
                errorSignature: nil,
                timestamp: segmentEvent.timestamp,
                durationMs: nil,
                metadata: metadataJSON
            )
        }
    }

    /// Get segmentation statistics.
    public func getSegmentationStats() async throws -> LedgerSegmentationStats? {
        let segmentManager = MasterLedgerSegmentationManager(database: db)
        return try await segmentManager.getSegmentationStats()
    }

    /// Perform migration to segmented ledger if needed.
    public func migrateToSegmentation() async throws -> MigrationResult {
        return try await db.migrateMasterLedgerToSegmentation()
    }

    /// Perform semantic search on ledger events.
    public func semanticSearch(
        query: String,
        userId: String? = nil,
        filters: SearchFilters? = nil,
        limit: Int = 100
    ) async throws -> SearchResult? {
        guard let searchManager = searchManager else {
            throw SearchError.searchNotAvailable
        }

        return try await searchManager.search(
            query: query,
            userId: userId,
            filters: filters,
            limit: limit
        )
    }

    /// Get search history.
    public func getSearchHistory(
        userId: String? = nil,
        limit: Int = 100
    ) async throws -> [SearchQueryRecord] {
        guard let searchManager = searchManager else {
            throw SearchError.searchNotAvailable
        }

        return try await searchManager.getSearchHistory(userId: userId, limit: limit)
    }

    /// Get search statistics.
    public func getSearchStatistics() async throws -> SearchStatistics? {
        guard let searchManager = searchManager else {
            throw SearchError.searchNotAvailable
        }

        return try await searchManager.getSearchStats()
    }

    /// Build searchable text content for indexing.
    private func buildTextContentForIndexing(toolName: String, metadata: Data?) -> String {
        var textContent = toolName

        // Include metadata if present
        if let metadata = metadata,
           let metadataString = String(data: metadata, encoding: .utf8) {
            textContent += " " + metadataString
        }

        return textContent
    }
}

/// Errors that can occur during search operations.
public enum SearchError: LocalizedError {
    case searchNotAvailable

    public var errorDescription: String? {
        switch self {
        case .searchNotAvailable:
            return "Search functionality is not available"
        }
    }
}
