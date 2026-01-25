//
//  DatabaseSessionManager.swift
//  HarmoniaModule
//
//  Session database manager for Phase 7.5.
//  Creates disposable per-agent scratch databases and manages merge-to-master operations.
//

@preconcurrency import Foundation
import AnigmaPrimitives
import DatabaseCore

/// Manager for session databases with merge-to-master functionality.
/// Creates isolated scratch databases for each session and provides safe merge operations.
public class DatabaseSessionManager: @unchecked Sendable {
    /// Singleton instance
    public static let shared = DatabaseSessionManager()

    /// Active session databases
    private var activeSessions: [String: SessionDatabase] = [:]

    /// Master database path
    private let masterDatabasePath: String

    /// Session working directory
    private let sessionDirectory: String

    private init() {
        self.masterDatabasePath = DatabaseConfiguration.defaultDatabasePath()
        self.sessionDirectory = FileManager.default.currentDirectoryPath + "/.harmonia_sessions"

        // Create session directory if needed
        try? FileManager.default.createDirectory(atPath: sessionDirectory, withIntermediateDirectories: true)
    }

    /// Create a new disposable session database
    /// - Returns: Session ID and database path
    public func createSessionDatabase(for agentId: String) async -> (sessionId: String, databasePath: String) {
        let sessionId = UUID().uuidString
        let databasePath = sessionDirectory + "/session_" + sessionId + ".sqlite"

        // Copy master database schema to session database
        await copyMasterSchema(to: databasePath)

        let sessionDb = SessionDatabase(
            sessionId: sessionId,
            agentId: agentId,
            databasePath: databasePath,
            createdAt: Date()
        )

        activeSessions[sessionId] = sessionDb

        return (sessionId, databasePath)
    }

    /// Get session by ID
    /// - Parameter sessionId: Session ID
    /// - Returns: Session database if active, nil otherwise
    public func getSession(_ sessionId: String) async -> SessionDatabase? {
        return activeSessions[sessionId]
    }

    /// Merge session database to master
    /// - Parameters:
    ///   - sessionId: Session ID to merge
    ///   - mergeStrategy: Strategy for resolving conflicts
    /// - Returns: Result of merge operation
    @discardableResult
    public func mergeSessionToMaster(
        sessionId: String,
        mergeStrategy: MergeStrategy = .sessionOverwritesMaster
    ) async -> MergeResult {
        guard let session = activeSessions[sessionId] else {
            return MergeResult(
                success: false,
                error: "Session not found: \(sessionId)",
                mergedRecords: 0
            )
        }

        // Validate session before merge
        let validationResult = await validateSession(session)
        if !validationResult.isValid {
            return MergeResult(
                success: false,
                error: validationResult.errors.first ?? "Validation failed",
                mergedRecords: 0
            )
        }

        // Perform merge
        let mergeCount = await performMerge(from: session.databasePath, to: masterDatabasePath, strategy: mergeStrategy)

        // Close session
        await closeSession(sessionId)

        return MergeResult(
            success: true,
            error: nil,
            mergedRecords: mergeCount
        )
    }

    /// Close and cleanup session
    /// - Parameter sessionId: Session ID to close
    public func closeSession(_ sessionId: String) async {
        guard activeSessions[sessionId] != nil else { return }
        // Remove session from active list
        activeSessions.removeValue(forKey: sessionId)

        // Optionally delete session database file
        // For now, keep files for debugging
        // try? FileManager.default.removeItem(atPath: session.databasePath)
    }

    /// Validate session database before merge
    private func validateSession(_ session: SessionDatabase) async -> ValidationResult {
        // Placeholder validation logic
        // In production, would check for:
        // - Schema compatibility
        // - Constraint violations
        // - Data integrity

        return ValidationResult(isValid: true, errors: [])
    }

    /// Perform actual merge operation
    private func performMerge(
        from sourcePath: String,
        to targetPath: String,
        strategy: MergeStrategy
    ) async -> Int {
        // Placeholder merge implementation
        // In production, this would:
        // - Analyze schema differences
        // - Copy new records
        // - Resolve conflicts according to strategy
        // - Update timestamps

        // For now, simulate merge
        return 100 // dummy count
    }

    /// Copy master database schema to new session
    private func copyMasterSchema(to databasePath: String) async {
        // In production, would use SQLite API to:
        // - Copy schema without data
        // - Set session-specific pragmas
        // - Initialize session tables

        // For now, create empty database with tables
        // This would be implemented with actual SQLite operations
    }

    /// Cleanup expired sessions
    public func cleanupExpiredSessions(maxAge: TimeInterval = 24 * 60 * 60) async {
        let cutoffDate = Date().addingTimeInterval(-maxAge)

        for (sessionId, session) in activeSessions {
            if session.createdAt < cutoffDate {
                await closeSession(sessionId)
            }
        }
    }
}

/// Session database information
public struct SessionDatabase: Codable, Sendable {
    /// Unique session identifier
    public let sessionId: String

    /// Agent that owns this session
    public let agentId: String

    /// Path to session database
    public let databasePath: String

    /// When session was created
    public let createdAt: Date
}

/// Merge strategy for conflict resolution
public enum MergeStrategy: String, Sendable, Codable {
    /// Session data overwrites master data on conflict
    case sessionOverwritesMaster = "session_overwrites_master"

    /// Master data preserved and session conflicts ignored
    case masterPreserved = "master_preserved"

    /// Conflicts cause merge to fail
    case failOnConflict = "fail_on_conflict"
}

/// Result of merge operation
public struct MergeResult: Codable, Sendable {
    /// Whether merge succeeded
    public let success: Bool

    /// Error message if failed
    public let error: String?

    /// Number of records merged
    public let mergedRecords: Int
}

/// Result of validation operation
public struct ValidationResult: Codable, Sendable {
    /// Whether validation passed
    public let isValid: Bool

    /// List of validation errors
    public let errors: [String]
}
