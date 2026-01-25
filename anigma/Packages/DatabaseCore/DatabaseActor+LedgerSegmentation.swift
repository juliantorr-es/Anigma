//
//  DatabaseActor+LedgerSegmentation.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Extension on DatabaseActor for master ledger segmentation operations.
public extension DatabaseActor {

    /// Initialize the master ledger segmentation tables.
    func initializeLedgerSegmentationSchema() async throws {
        // Create segment metadata table
        try performExecute("""
            CREATE TABLE IF NOT EXISTS ledger_segments (
                segment_id TEXT PRIMARY KEY,
                created_at REAL NOT NULL,
                closed_at REAL,
                archived_at REAL,
                event_count INTEGER DEFAULT 0,
                bytes_estimated INTEGER DEFAULT 0,
                status TEXT DEFAULT 'active'
            )
        """)

        // Create indexes for segment metadata
        try performExecute("CREATE INDEX IF NOT EXISTS idx_segments_created ON ledger_segments(created_at)")
        try performExecute("CREATE INDEX IF NOT EXISTS idx_segments_status ON ledger_segments(status)")
        try performExecute("CREATE INDEX IF NOT EXISTS idx_segments_closed ON ledger_segments(closed_at)")
    }

    /// Initialize migration from existing master ledger to segments.
    func migrateMasterLedgerToSegmentation() async throws -> MigrationResult {
        // Check if we have existing master ledger table to migrate
        let ledgerExists = try await tableExists("master_ledger")
        if !ledgerExists {
            return MigrationResult(
                migratedEvents: 0,
                createdSegments: 0,
                duration: 0,
                success: true
            )
        }

        let startTime = Date()
        var migratedEvents = 0
        var createdSegments = 0

        // Get all events from master ledger
        let eventRows = try await query("""
            SELECT event_id, agent_id, workflow_id, event_type, timestamp,
                   payload_hash, metadata_json
            FROM master_ledger
            ORDER BY timestamp ASC
        """)

        // Process events into time-based segments
        var currentSegmentId: String?
        for eventRow in eventRows {
            guard let eventId = eventRow.string(for: "event_id"),
                  let agentId = eventRow.string(for: "agent_id"),
                  let event_type = eventRow.string(for: "event_type"),
                  let timestampDouble = eventRow.double(for: "timestamp") else {
                continue
            }

            let eventDate = Date(timeIntervalSince1970: timestampDouble)

            // Determine segment based on date
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: eventDate)

            let year = components.year ?? 0
            let month = String(format: "%02d", components.month ?? 0)
            let day = String(format: "%02d", components.day ?? 0)
            let hour = String(format: "%02d", components.hour ?? 0)

            let segmentId = "seg-\(year)-\(month)-\(day)-\(hour)"

            // Create new segment if needed
            if currentSegmentId != segmentId {
                currentSegmentId = segmentId
                try await createLedgerSegment(segmentId: segmentId, createdAt: eventDate)
                createdSegments += 1
            }

            // Insert event into segment
            try performExecute("""
                INSERT INTO ledger_segment_\(segmentId) (
                    event_id, agent_id, workflow_id, event_type, timestamp,
                    payload_hash, metadata_json, created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, parameters: [
                .text(eventId),
                .text(agentId),
                dbp(eventRow.string(for: "workflow_id")),
                .text(event_type),
                .double(timestampDouble),
                dbp(eventRow.string(for: "payload_hash")),
                dbp(eventRow.string(for: "metadata_json")),
                .double(eventDate.timeIntervalSince1970)
            ])

            migratedEvents += 1
        }

        // Close all migrated segments
        try performExecute("UPDATE ledger_segments SET closed_at = ?, status = 'closed' WHERE closed_at IS NULL")

        // Rename original master ledger table as backup before replacement
        try performExecute("ALTER TABLE master_ledger RENAME TO master_ledger_legacy_backup")

        let duration = Date().timeIntervalSince(startTime)

        return MigrationResult(
            migratedEvents: migratedEvents,
            createdSegments: createdSegments,
            duration: duration,
            success: true
        )
    }

    /// Write event to appropriate segment.
    func writeEventToSegment(_ event: LedgerEvent) async throws {
        // Get current active segment
        let segmentManager = MasterLedgerSegmentationManager(database: self)
        let activeSegment = try await segmentManager.getActiveSegment()

        // Check rotation before writing
        _ = try await segmentManager.rotateIfNeeded()

        // Insert event into the active segment
        try performExecute("""
            INSERT OR REPLACE INTO ledger_segment_\(activeSegment.segmentId) (
                event_id, agent_id, workflow_id, event_type, timestamp,
                payload_hash, metadata_json, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, parameters: [
            .text(event.eventId),
            .text(event.agentId),
            .text(event.workflowId ?? ""),
            .text(event.eventType),
            .double(event.timestamp.timeIntervalSince1970),
            .text(event.payloadHash ?? ""),
            .text(event.metadataJson ?? ""),
            .double(Date().timeIntervalSince1970)
        ])

        // Update segment event count
        try performExecute(
            "UPDATE ledger_segments SET event_count = event_count + 1 WHERE segment_id = ?",
            parameters: [.text(activeSegment.segmentId)]
        )
    }

    /// Get segment event count.
    func getSegmentEventCount(segmentId: String) async throws -> Int {
        let rows = try await query("SELECT COUNT(*) as count FROM ledger_segment_\(segmentId)")
        return rows.first?.int(for: "count") ?? 0
    }

    /// Check if a table exists.
    private func tableExists(_ tableName: String) async throws -> Bool {
        let rows = try await query("""
            SELECT name FROM sqlite_master
            WHERE type='table' AND name=?
            LIMIT 1
        """, parameters: [.text(tableName)])
        return !rows.isEmpty
    }

    /// Create a new segment table.
    private func createLedgerSegment(segmentId: String, createdAt: Date) async throws {
        // Create segment table
        try performExecute("""
            CREATE TABLE IF NOT EXISTS ledger_segment_\(segmentId) (
                event_id TEXT PRIMARY KEY,
                agent_id TEXT NOT NULL,
                workflow_id TEXT,
                event_type TEXT NOT NULL,
                timestamp REAL NOT NULL,
                payload_hash TEXT,
                metadata_json TEXT,
                created_at REAL DEFAULT (julianday('now'))
            )
        """)

        // Create indexes on segment
        try performExecute("CREATE INDEX IF NOT EXISTS idx_seg_\(segmentId)_agent ON ledger_segment_\(segmentId)(agent_id)")
        try performExecute("CREATE INDEX IF NOT EXISTS idx_seg_\(segmentId)_workflow ON ledger_segment_\(segmentId)(workflow_id)")
        try performExecute("CREATE INDEX IF NOT EXISTS idx_seg_\(segmentId)_timestamp ON ledger_segment_\(segmentId)(timestamp)")
        try performExecute("CREATE INDEX IF NOT EXISTS idx_seg_\(segmentId)_event_type ON ledger_segment_\(segmentId)(event_type)")

        // Register segment in metadata table
        try performExecute("""
            INSERT INTO ledger_segments (segment_id, created_at)
            VALUES (?, ?)
        """, parameters: [
            .text(segmentId),
            .double(createdAt.timeIntervalSince1970)
        ])
    }
}

/// Result of ledger migration.
public struct MigrationResult: Sendable, Codable {
    public let migratedEvents: Int
    public let createdSegments: Int
    public let duration: TimeInterval
    public let success: Bool
}
