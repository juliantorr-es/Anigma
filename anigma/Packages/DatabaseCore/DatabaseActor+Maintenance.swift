//
//  DatabaseActor+Maintenance.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Extension on DatabaseActor for maintenance operations.
public extension DatabaseActor {

    /// Initialize the maintenance history tables.
    func initializeMaintenanceSchema() async throws {
        // Create maintenance history table
        try performExecute("""
            CREATE TABLE IF NOT EXISTS maintenance_history (
                operation_id TEXT PRIMARY KEY,
                operation_type TEXT NOT NULL,
                started_at REAL NOT NULL,
                completed_at REAL NOT NULL,
                result_json TEXT,
                config_json TEXT
            )
        """)

        // Create invariant checks table for governance compliance
        try performExecute("""
            CREATE TABLE IF NOT EXISTS invariant_checks (
                check_id TEXT PRIMARY KEY,
                timestamp REAL NOT NULL,
                passed BOOLEAN NOT NULL,
                details_json TEXT,
                violations_json TEXT
            )
        """)

        // Create indexes
        try performExecute("CREATE INDEX IF NOT EXISTS idx_maintenance_operation_type ON maintenance_history(operation_type)")
        try performExecute("CREATE INDEX IF NOT EXISTS idx_maintenance_started_at ON maintenance_history(started_at)")
    }

    /// Perform WAL checkpoint operation and record in history.
    func performAndRecordCheckpoint(config: WALConfig) async throws -> WALCheckpointResult {
        let walManager = WALManager(database: self, config: config)
        let result = try await walManager.performCheckpoint()

        // Record in maintenance history
        let history = MaintenanceHistory(database: self)
        let operationResult = MaintenanceOperationResult(
            success: true,
            durationSeconds: result.duration,
            bytesFreed: result.bytesFreed
        )
        try await history.recordMaintenance(operation: .walCheckpoint, result: operationResult)

        return result
    }

    /// Perform VACUUM operation and record in history.
    func performAndRecordVacuum(config: MaintenanceConfig, mode: VacuumMode = .full) async throws -> VacuumResult {
        let maintenance = DatabaseMaintenance(database: self, config: config)
        let result = try await maintenance.performVacuum(mode: mode)

        // Record in maintenance history
        let history = MaintenanceHistory(database: self)
        let operationResult = MaintenanceOperationResult(
            success: result.vacuumPerformed,
            durationSeconds: result.duration,
            bytesFreed: Int64(result.spaceSavedMb * 1024 * 1024)
        )
        try await history.recordMaintenance(operation: .vacuum, result: operationResult)

        return result
    }

    /// Record ANALYZE operation and record in history.
    func performAndRecordAnalyze(config: MaintenanceConfig) async throws -> AnalyzeResult {
        let maintenance = DatabaseMaintenance(database: self, config: config)
        let result = try await maintenance.analyzeDatabase()

        // Record in maintenance history
        let history = MaintenanceHistory(database: self)
        let operationResult = MaintenanceOperationResult(
            success: result.analyzed,
            durationSeconds: result.duration,
            bytesFreed: 0
        )
        try await history.recordMaintenance(operation: .analyze, result: operationResult)

        // Verify governance invariants
        let invariantChecker = GovernanceInvariantChecker(database: self)
        let invariantResult = try await invariantChecker.verifyAllInvariants()

        if !invariantResult.passed {
            // Store invariants for audit
            try await recordInvariantCheck(result: invariantResult)
        }

        return result
    }
    /// Get statistics about database usage and health.
    func getDatabaseHealthStats() async throws -> DatabaseHealthStats {
        let dbSize = try await getDatabaseSizeInternal()

        // Get WAL size
        let walPath = path + "-wal"
        var walSize: Int64 = 0
        if FileManager.default.fileExists(atPath: walPath) {
            let attributes = try FileManager.default.attributesOfItem(atPath: walPath)
            if let size = attributes[FileAttributeKey.size] as? NSNumber {
                walSize = size.int64Value
            }
        }

        // Get page count information
        let pageCountRows = try await query("PRAGMA page_count")
        let totalPages = pageCountRows.first?.int(for: "page_count") ?? 0

        let freelistRows = try await query("PRAGMA freelist_count")
        let freePages = freelistRows.first?.int(for: "freelist_count") ?? 0

        // Get fragment ratio
        let fragmentationRatio = totalPages > 0 ? Double(freePages) / Double(totalPages) : 0

        return DatabaseHealthStats(
            databaseSizeBytes: dbSize,
            walSizeBytes: walSize,
            totalPages: totalPages,
            freePages: freePages,
            fragmentationRatio: fragmentationRatio
        )
    }

    /// Get size of a segment in bytes.
    private func getSegmentSize(segmentId: String) async throws -> Int64 {
        // Improved size estimation including all columns and overhead
        let rows = try await query("""
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

    /// Record invariant check results for audit trail.
    private func recordInvariantCheck(result: InvariantCheckResult) async throws {
        let resultData = try JSONEncoder().encode(result)
        let resultJson = String(data: resultData, encoding: .utf8) ?? "{}"

        try performExecute("""
            INSERT INTO invariant_checks (
                check_id, timestamp, passed, details_json,
                violations_json
            ) VALUES (?, ?, ?, ?, ?)
        """, parameters: [
            .text(UUID().uuidString),
            .double(result.timestamp.timeIntervalSince1970),
            .int(result.passed ? 1 : 0),
            .text(result.checks.map { "\($0.name):\($0.passed)" }.joined(separator: ", ")),
            .text(resultJson)
        ])
    }

    private func getDatabaseSizeInternal() async throws -> Int64 {
        let dbPath = path
        guard FileManager.default.fileExists(atPath: dbPath) else { return 0 }
        let attributes = try FileManager.default.attributesOfItem(atPath: dbPath)
        if let size = attributes[FileAttributeKey.size] as? NSNumber {
            return size.int64Value
        }
        return 0
    }

    /// Backwards compatibility helper: initialize maintenance history schema.
    func initializeMaintenanceHistorySchema() async throws {
        try await initializeMaintenanceSchema()
    }

    /// Backwards compatibility helper: initialize retention-related tables.
    func initializeRetentionSchema() async throws {
        _ = try await makeContentAddressedStore()
    }

    /// Backwards compatibility helper: initialize garbage-collection tables.
    func initializeGarbageCollectionSchema() async throws {
        try await initializeRetentionSchema()
    }

}

/// Database health statistics.
public struct DatabaseHealthStats: Sendable, Codable {
    public let databaseSizeBytes: Int64
    public let walSizeBytes: Int64
    public let totalPages: Int
    public let freePages: Int
    public let fragmentationRatio: Double

    public init(databaseSizeBytes: Int64 = 0, walSizeBytes: Int64 = 0, totalPages: Int = 0, freePages: Int = 0, fragmentationRatio: Double = 0) {
        self.databaseSizeBytes = databaseSizeBytes
        self.walSizeBytes = walSizeBytes
        self.totalPages = totalPages
        self.freePages = freePages
        self.fragmentationRatio = fragmentationRatio
    }

    /// Format database size for display.
    public var formattedDatabaseSize: String {
        ByteCountFormatter.string(fromByteCount: databaseSizeBytes, countStyle: .file)
    }

    /// Format WAL size for display.
    public var formattedWalSize: String {
        ByteCountFormatter.string(fromByteCount: walSizeBytes, countStyle: .file)
    }

    /// Fragmentation percentage.
    public var fragmentationPercent: String {
        String(format: "%.1f%%", fragmentationRatio * 100)
    }
}
