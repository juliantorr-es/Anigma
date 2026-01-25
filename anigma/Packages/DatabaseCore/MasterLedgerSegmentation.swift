//
//  MasterLedgerSegmentation.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Master ledger segmentation strategy for bounded growth and archival.
/// Divides master ledger into time-based segments to prevent single table bloat.
public actor MasterLedgerSegmentationManager {
    private let db: DatabaseActor
    private let config: LedgerSegmentationConfig

    public init(database: DatabaseActor, config: LedgerSegmentationConfig = .default) {
        self.db = database
        self.config = config
    }

    /// Get or create the current active segment.
    public func getActiveSegment() async throws -> LedgerSegment {
        let now = Date()
        let segmentId = generateSegmentId(from: now)

        // Check if segment exists
        let rows = try await db.query(
            "SELECT segment_id, created_at, closed_at FROM ledger_segments WHERE segment_id = ?",
            parameters: [.text(segmentId)]
        )

        if let row = rows.first {
            return LedgerSegment(
                segmentId: row.string(for: "segment_id") ?? segmentId,
                createdAt: Date(timeIntervalSince1970: row.double(for: "created_at") ?? 0),
                closedAt: row.double(for: "closed_at").map { Date(timeIntervalSince1970: $0) },
                eventCount: 0
            )
        }

        // Create new segment
        try await createSegment(segmentId: segmentId)
        return LedgerSegment(segmentId: segmentId, createdAt: Date(), closedAt: nil, eventCount: 0)
    }

    /// Rotate to a new segment if the current one exceeds thresholds.
    public func rotateIfNeeded() async throws -> SegmentRotationResult {
        let activeSegment = try await getActiveSegment()

        // Check if rotation is needed
        let eventCount = try await getSegmentEventCount(segmentId: activeSegment.segmentId)
        let ageSeconds = Date().timeIntervalSince(activeSegment.createdAt)

        let exceedsEventCount = eventCount >= config.maxEventsPerSegment
        let exceedsAge = ageSeconds >= config.maxSegmentAgeSeconds

        if exceedsEventCount || exceedsAge {
            return try await performRotation(currentSegment: activeSegment)
        }

        return SegmentRotationResult(
            rotationPerformed: false,
            previousSegmentId: activeSegment.segmentId,
            newSegmentId: activeSegment.segmentId,
            eventsMigrated: 0,
            duration: 0
        )
    }

    /// Perform segment rotation.
    private func performRotation(currentSegment: LedgerSegment) async throws -> SegmentRotationResult {
        let startTime = Date()
        let eventCount = try await getSegmentEventCount(segmentId: currentSegment.segmentId)

        // Close current segment
        try await closeSegment(segmentId: currentSegment.segmentId)

        // Create new segment
        let newSegmentId = generateSegmentId(from: Date())
        try await createSegment(segmentId: newSegmentId)

        let duration = Date().timeIntervalSince(startTime)

        return SegmentRotationResult(
            rotationPerformed: true,
            previousSegmentId: currentSegment.segmentId,
            newSegmentId: newSegmentId,
            eventsMigrated: eventCount,
            duration: duration
        )
    }

    /// Get all segments matching criteria.
    public func getSegments(
        status: SegmentStatus? = nil,
        olderThan: Date? = nil,
        limit: Int = 100
    ) async throws -> [LedgerSegment] {
        var query = "SELECT segment_id, created_at, closed_at FROM ledger_segments WHERE 1=1"
        var parameters: [DatabaseParameter] = []

        if status == .active {
            query += " AND closed_at IS NULL"
        } else if status == .closed {
            query += " AND closed_at IS NOT NULL"
        }

        if let olderThan = olderThan {
            query += " AND created_at < ?"
            parameters.append(.double(olderThan.timeIntervalSince1970))
        }

        query += " ORDER BY created_at DESC LIMIT ?"
        parameters.append(.int(limit))

        let rows = try await db.query(query, parameters: parameters)

        return rows.compactMap { row in
            guard let segmentId = row.string(for: "segment_id"),
                  let createdAtDouble = row.double(for: "created_at") else {
                return nil
            }

            return LedgerSegment(
                segmentId: segmentId,
                createdAt: Date(timeIntervalSince1970: createdAtDouble),
                closedAt: row.double(for: "closed_at").map { Date(timeIntervalSince1970: $0) },
                eventCount: 0
            )
        }
    }

    /// Archive old segments to external storage.
    public func archiveSegments(olderThan: Date) async throws -> SegmentArchiveResult {
        let segments = try await getSegments(status: .closed, olderThan: olderThan)

        var archivedCount = 0
        var totalBytes: Int64 = 0

        for segment in segments {
            let size = try await getSegmentSize(segmentId: segment.segmentId)
            totalBytes += size

            // Mark as archived
            try await markSegmentArchived(segmentId: segment.segmentId)
            archivedCount += 1
        }

        return SegmentArchiveResult(
            segmentsArchived: archivedCount,
            bytesArchived: totalBytes,
            duration: 0
        )
    }

    /// Get statistics about all segments.
    public func getSegmentationStats() async throws -> LedgerSegmentationStats {
        let allSegments = try await getSegments(limit: 1000)

        var activeSegments = 0
        var closedSegments = 0
        var archivedSegments = 0
        var totalEvents = 0
        var totalBytes: Int64 = 0

        for segment in allSegments {
            let isArchived = try await isSegmentArchived(segmentId: segment.segmentId)
            let eventCount = try await getSegmentEventCount(segmentId: segment.segmentId)
            let size = try await getSegmentSize(segmentId: segment.segmentId)

            totalEvents += eventCount
            totalBytes += size

            if isArchived {
                archivedSegments += 1
            } else if segment.closedAt != nil {
                closedSegments += 1
            } else {
                activeSegments += 1
            }
        }

        return LedgerSegmentationStats(
            totalSegments: allSegments.count,
            activeSegments: activeSegments,
            closedSegments: closedSegments,
            archivedSegments: archivedSegments,
            totalEvents: totalEvents,
            totalBytes: totalBytes
        )
    }

    // MARK: - Private Helpers

    /// Generate segment ID from date (format: YYYY-MM-DD-HH)
    private func generateSegmentId(from date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)

        let year = components.year ?? 0
        let month = String(format: "%02d", components.month ?? 0)
        let day = String(format: "%02d", components.day ?? 0)
        let hour = String(format: "%02d", components.hour ?? 0)

        return "seg-\(year)-\(month)-\(day)-\(hour)"
    }

    /// Create a new ledger segment table.
    private func createSegment(segmentId: String) async throws {
        // Create segment table
        try await db.executeAsync("""
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
        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_seg_\(segmentId)_agent ON ledger_segment_\(segmentId)(agent_id)")
        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_seg_\(segmentId)_workflow ON ledger_segment_\(segmentId)(workflow_id)")
        try await db.executeAsync("CREATE INDEX IF NOT EXISTS idx_seg_\(segmentId)_timestamp ON ledger_segment_\(segmentId)(timestamp)")

        // Register segment in metadata table
        try await db.executeAsync("""
            INSERT INTO ledger_segments (segment_id, created_at)
            VALUES (?, ?)
        """, parameters: [
            .text(segmentId),
            .double(Date().timeIntervalSince1970)
        ])
    }

    /// Close a segment for writing.
    private func closeSegment(segmentId: String) async throws {
        try await db.executeAsync(
            "UPDATE ledger_segments SET closed_at = ? WHERE segment_id = ?",
            parameters: [
                .double(Date().timeIntervalSince1970),
                .text(segmentId)
            ]
        )
    }

    /// Mark a segment as archived.
    private func markSegmentArchived(segmentId: String) async throws {
        try await db.executeAsync(
            "UPDATE ledger_segments SET archived_at = ? WHERE segment_id = ?",
            parameters: [
                .double(Date().timeIntervalSince1970),
                .text(segmentId)
            ]
        )
    }

    /// Check if a segment is archived.
    private func isSegmentArchived(segmentId: String) async throws -> Bool {
        let rows = try await db.query(
            "SELECT archived_at FROM ledger_segments WHERE segment_id = ?",
            parameters: [.text(segmentId)]
        )
        return rows.first?.double(for: "archived_at") != nil
    }

    /// Get event count for a segment.
    private func getSegmentEventCount(segmentId: String) async throws -> Int {
        let rows = try await db.query("SELECT COUNT(*) as count FROM ledger_segment_\(segmentId)")
        return rows.first?.int(for: "count") ?? 0
    }

    /// Get size of a segment in bytes.
    private func getSegmentSize(segmentId: String) async throws -> Int64 {
        // Improved size estimation including all columns and overhead
        let rows = try await db.query("""
            SELECT SUM(
                LENGTH(event_id) +
                LENGTH(agent_id) +
                LENGTH(COALESCE(workflow_id, '')) +
                LENGTH(event_type) +
                8 + -- timestamp (REAL)
                LENGTH(COALESCE(payload_hash, '')) +
                LENGTH(COALESCE(metadata_json, '')) +
                8 + -- created_at (REAL)
                100 -- Estimated row overhead (headers, indexes)
            ) as total_size
            FROM ledger_segment_\(segmentId)
        """)
        return Int64(rows.first?.int(for: "total_size") ?? 0)
    }
}

// MARK: - Query Interface for Segments

/// Cross-segment query executor.
public actor CrossSegmentQueryExecutor {
    private let db: DatabaseActor
    private let segmentManager: MasterLedgerSegmentationManager

    public init(database: DatabaseActor, segmentManager: MasterLedgerSegmentationManager) {
        self.db = database
        self.segmentManager = segmentManager
    }

    /// Query events across all segments.
    public func queryAllSegments(
        filter: EventFilter,
        limit: Int = 1000
    ) async throws -> [LedgerEvent] {
        let segments = try await segmentManager.getSegments(limit: 1000)
        var allEvents: [LedgerEvent] = []

        for segment in segments {
            let events = try await querySegment(segmentId: segment.segmentId, filter: filter, limit: limit)
            allEvents.append(contentsOf: events)

            if allEvents.count >= limit {
                break
            }
        }

        return Array(allEvents.prefix(limit))
    }

    /// Query a specific segment.
    public func querySegment(
        segmentId: String,
        filter: EventFilter,
        limit: Int = 1000
    ) async throws -> [LedgerEvent] {
        var query = "SELECT event_id, agent_id, workflow_id, event_type, timestamp, payload_hash, metadata_json FROM ledger_segment_\(segmentId) WHERE 1=1"
        var parameters: [DatabaseParameter] = []

        if let agentId = filter.agentId {
            query += " AND agent_id = ?"
            parameters.append(.text(agentId))
        }

        if let eventType = filter.eventType {
            query += " AND event_type = ?"
            parameters.append(.text(eventType))
        }

        if let after = filter.after {
            query += " AND timestamp > ?"
            parameters.append(.double(after.timeIntervalSince1970))
        }

        if let before = filter.before {
            query += " AND timestamp < ?"
            parameters.append(.double(before.timeIntervalSince1970))
        }

        query += " ORDER BY timestamp DESC LIMIT ?"
        parameters.append(.int(limit))

        let rows = try await db.query(query, parameters: parameters)

        return rows.compactMap { row in
            guard let eventId = row.string(for: "event_id"),
                  let eventType = row.string(for: "event_type"),
                  let timestamp = row.double(for: "timestamp") else {
                return nil
            }

            return LedgerEvent(
                eventId: eventId,
                agentId: row.string(for: "agent_id") ?? "",
                workflowId: row.string(for: "workflow_id"),
                eventType: eventType,
                timestamp: Date(timeIntervalSince1970: timestamp),
                payloadHash: row.string(for: "payload_hash"),
                metadataJson: row.string(for: "metadata_json")
            )
        }
    }
}

// MARK: - Configuration & Data Types

/// Ledger segmentation configuration.
public struct LedgerSegmentationConfig: Sendable {
    public let maxEventsPerSegment: Int
    public let maxSegmentAgeSeconds: TimeInterval
    public let segmentationStrategy: SegmentationStrategy
    public let archivalPolicy: ArchivalPolicy

    public static let `default` = LedgerSegmentationConfig(
        maxEventsPerSegment: 100_000,
        maxSegmentAgeSeconds: 86400, // 1 day
        segmentationStrategy: .hourly,
        archivalPolicy: ArchivalPolicy(retentionDays: 90, archiveAfterDays: 30)
    )

    public static let aggressive = LedgerSegmentationConfig(
        maxEventsPerSegment: 50_000,
        maxSegmentAgeSeconds: 43200, // 12 hours
        segmentationStrategy: .hourly,
        archivalPolicy: ArchivalPolicy(retentionDays: 60, archiveAfterDays: 14)
    )

    public init(
        maxEventsPerSegment: Int = 100_000,
        maxSegmentAgeSeconds: TimeInterval = 86400,
        segmentationStrategy: SegmentationStrategy = .hourly,
        archivalPolicy: ArchivalPolicy = ArchivalPolicy(retentionDays: 90, archiveAfterDays: 30)
    ) {
        self.maxEventsPerSegment = maxEventsPerSegment
        self.maxSegmentAgeSeconds = maxSegmentAgeSeconds
        self.segmentationStrategy = segmentationStrategy
        self.archivalPolicy = archivalPolicy
    }
}

/// Segmentation strategy.
public enum SegmentationStrategy: String, Sendable, Codable {
    case hourly
    case daily
    case weekly
    case monthly
}

/// Archival policy for old segments.
public struct ArchivalPolicy: Sendable, Codable {
    public let retentionDays: Int
    public let archiveAfterDays: Int

    public init(retentionDays: Int, archiveAfterDays: Int) {
        self.retentionDays = retentionDays
        self.archiveAfterDays = archiveAfterDays
    }
}

/// Ledger segment metadata.
public struct LedgerSegment: Sendable, Codable {
    public let segmentId: String
    public let createdAt: Date
    public let closedAt: Date?
    public let eventCount: Int

    public var isClosed: Bool { closedAt != nil }
}

/// Segment status.
public enum SegmentStatus: Sendable {
    case active
    case closed
    case archived
}

/// Event filter for querying.
public struct EventFilter: Sendable {
    public let agentId: String?
    public let eventType: String?
    public let after: Date?
    public let before: Date?

    public init(agentId: String? = nil, eventType: String? = nil, after: Date? = nil, before: Date? = nil) {
        self.agentId = agentId
        self.eventType = eventType
        self.after = after
        self.before = before
    }
}

/// Ledger event record.
public struct LedgerEvent: Sendable, Codable {
    public let eventId: String
    public let agentId: String
    public let workflowId: String?
    public let eventType: String
    public let timestamp: Date
    public let payloadHash: String?
    public let metadataJson: String?
}

// MARK: - Results

/// Result of segment rotation.
public struct SegmentRotationResult: Sendable {
    public let rotationPerformed: Bool
    public let previousSegmentId: String
    public let newSegmentId: String
    public let eventsMigrated: Int
    public let duration: TimeInterval
}

/// Result of segment archival.
public struct SegmentArchiveResult: Sendable {
    public let segmentsArchived: Int
    public let bytesArchived: Int64
    public let duration: TimeInterval
}

/// Statistics about ledger segmentation.
public struct LedgerSegmentationStats: Sendable, Codable {
    public let totalSegments: Int
    public let activeSegments: Int
    public let closedSegments: Int
    public let archivedSegments: Int
    public let totalEvents: Int
    public let totalBytes: Int64
}
