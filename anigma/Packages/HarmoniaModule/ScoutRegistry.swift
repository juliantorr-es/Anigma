//
//  ScoutRegistry.swift
//  HarmoniaModule
//
//  Registry for project scouts with simplified AST services integration.
//

import AnigmaCore
import AnigmaPrimitives
import DatabaseCore
import DoctrineCore
@preconcurrency import Foundation
import SQLite3

/// Registry for project scouts.
public actor ScoutRegistry {
    /// Registered scouts by name.
    private var scouts: [String: any ProjectScout] = [:]

    /// Creates a new scout registry.
    public init() {
        let projectRoot = FileManager.default.currentDirectoryPath
        let scout = Swift6DiagnosticScout(projectRoot: projectRoot)
        // Inline registration to avoid calling isolated method from non-isolated init
        let scoutId = String(describing: type(of: scout))
        self.scouts[scoutId] = scout
    }

    public func register(_ scout: any ProjectScout) {
        // Use a simple identifier for now since ProjectScout protocol doesn't have id property
        let scoutId = String(describing: type(of: scout))
        scouts[scoutId] = scout
    }

    public func scout(for id: String) -> (any ProjectScout)? {
        scouts[id]
    }

    public func allScoutIds() -> [String] {
        Array(scouts.keys).sorted()
    }

    public func scoutDisplayName(for id: String) -> String {
        scouts[id] != nil ? id : "Unknown Scout"
    }

    /// Persists a single scout finding to the database.
    /// Returns true if successful, false otherwise.
    private static func persistScoutFinding(_ finding: ScoutFinding, db: OpaquePointer?) -> Bool {
        guard let db = db else {
            logError("Database connection is nil", category: "ScoutRegistry")
            return false
        }

        var stmt: OpaquePointer?
        let sql = """
                INSERT OR IGNORE INTO scout_findings (
                    id, projectId, filePath, problemKind, severity, description,
                    suggestedFix, lineStart, lineEnd, createdAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            logError("Failed to prepare insert statement: \(errMsg)", category: "ScoutRegistry")
            return false
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, finding.id.uuidString, -1, nil)

        let projectIdData = finding.projectId.asBlobData
        _ = projectIdData.withUnsafeBytes { bytes in
            sqlite3_bind_blob(stmt, 2, bytes.baseAddress, Int32(projectIdData.count), nil)
        }

        sqlite3_bind_text(stmt, 3, finding.filePath, -1, nil)
        sqlite3_bind_text(stmt, 4, finding.problemKind, -1, nil)
        sqlite3_bind_text(stmt, 5, finding.severity.rawValue, -1, nil)
        sqlite3_bind_text(stmt, 6, finding.description, -1, nil)

        // suggestedFix (optional)
        if let suggestedFix = finding.suggestedFix {
            sqlite3_bind_text(stmt, 7, suggestedFix, -1, nil)
        } else {
            sqlite3_bind_null(stmt, 7)
        }

        // lineStart and lineEnd from lineStart/lineEnd
        if let lineStart = finding.lineStart {
            sqlite3_bind_int64(stmt, 8, Int64(lineStart))
            sqlite3_bind_int64(stmt, 9, Int64(lineStart))
        } else {
            sqlite3_bind_null(stmt, 8)
            sqlite3_bind_null(stmt, 9)
        }

        // createdAt as ISO8601 string
        let formatter = ISO8601DateFormatter()
        let createdAtString = formatter.string(from: finding.createdAt)
        sqlite3_bind_text(stmt, 10, createdAtString, -1, nil)

        if sqlite3_step(stmt) == SQLITE_DONE {
            logDebug("Persisted scout finding \(finding.id)", category: "ScoutRegistry")
            return true
        } else {
            let errMsg = String(cString: sqlite3_errmsg(db))
            logError("Failed to insert scout finding: \(errMsg)", category: "ScoutRegistry")
            return false
        }
    }

    /// Persists multiple scout findings to the database.
    /// Returns: number of successfully persisted findings.
    public static func persistScoutFindings(_ findings: [ScoutFinding], db: OpaquePointer?) -> Int {
        guard let db = db else { return 0 }

        var successCount = 0
        for finding in findings {
            if persistScoutFinding(finding, db: db) {
                successCount += 1
            }
        }

        logInfo(
            "Persisted \(successCount) of \(findings.count) scout findings",
            category: "ScoutRegistry")
        return successCount
    }
}
