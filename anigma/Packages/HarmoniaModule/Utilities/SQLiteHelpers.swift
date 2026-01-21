//
//  SQLiteHelpers.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

import DatabaseCore
//
//  SQLiteHelpers.swift
//  HarmoniaModule/Utilities
//
//  SQLite helper functions with safe binding policies.
//  All bindings use SQLITE_TRANSIENT by default to prevent lifetime issues.
//

import Foundation
import SQLite3
import AnigmaCore
import AnigmaPrimitives

// MARK: - UUID Binding (Safe by Default)

/// Binds a UUID as BLOB to a SQLite statement at the given index.
/// Uses safe SQLITE_TRANSIENT policy by default.
func bindUUID(_ stmt: OpaquePointer?, _ index: Int32, _ uuid: UUID, category: String = "SQLite") {
    let uuidData = withUnsafeBytes(of: uuid) { Data($0) }
    let hexString = uuidData.map { String(format: "%02x", $0) }.joined()
    logDebug("Binding UUID \(uuid) as BLOB hex \(hexString)", category: category)
    _ = uuidData.withUnsafeBytes { bytes in
        sqlite3_bind_blob(stmt, Int32(index), bytes.baseAddress, Int32(uuidData.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }
}

/// Binds a UUID as TEXT (hex string) to a SQLite statement at the given index.
/// Uses safe SQLITE_TRANSIENT policy by default.
func bindUUIDAsText(_ stmt: OpaquePointer?, _ index: Int32, _ uuid: UUID, category: String = "SQLite") {
    let hex = uuid.hexString
    logDebug("Binding UUID \(uuid) as TEXT hex \(hex)", category: category)
    sqlite3_bind_text(stmt, Int32(index), hex, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
}

// MARK: - Safe Destructor

/// Swift-friendly replacement for `SQLITE_TRANSIENT`.
/// Makes a copy of the data, safe with Swift's automatic memory management.
public let sqliteTransientDestructor: sqlite3_destructor_type = unsafeBitCast(
    UnsafeMutableRawPointer(bitPattern: -1),
    to: (@convention(c) (UnsafeMutableRawPointer?) -> Void).self
)

// MARK: - Migration Task Queries

/// SQL builder helper to ensure parameter ordering matches SQL clauses
struct SQLBuilder {
    var base: String
    var conditions: [String] = []
    var orderBy: String?
    var limit: Int?
    var params: [Any] = []

    mutating func whereEq(_ column: String, _ value: Any?) {
        guard let value = value else { return }
        conditions.append("\(column) = ?")
        params.append(value)
    }

    func build() -> (String, [Any]) {
        var sql = base
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }
        if let orderBy = orderBy {
            sql += " ORDER BY \(orderBy)"
        }
        if limit != nil {
            sql += " LIMIT ?"
        }
        var finalParams = params
        if let limit = limit {
            finalParams.append(limit)
        }
        return (sql, finalParams)
    }
}

/// Executes a query that returns an array of migration tasks.
/// Uses safe binding practices.
func loadMigrationTasks(
    db: OpaquePointer?,
    projectId: UUID,
    featureCategory: String?,
    status: String,
    limit: Int
) throws -> [AnigmaCore.MigrationTaskRow] {
    var builder = SQLBuilder(base: """
        SELECT id, projectId, featureCategory, status, priority, findingId, research_bundle_id, path, pathDetail, createdAt
        FROM migration_tasks
        """)

    builder.whereEq("projectId", projectId.uuidString)
    if let featureCategory = featureCategory {
        builder.whereEq("featureCategory", featureCategory)
    } else {
        builder.whereEq("featureCategory", "any")
    }
    builder.whereEq("status", status)
    builder.orderBy = "priority DESC, createdAt ASC"
    builder.limit = limit

    let (sql, params) = builder.build()
    logInfo("Loading migration tasks (SIMPLIFIED): \(sql)", category: "SQLite")
    logInfo("Will filter for projectId: \(projectId)", category: "SQLite")
    logInfo("featureCategory: \(featureCategory ?? "any")", category: "SQLite")
    logInfo("status: \(status)", category: "SQLite")

    var stmt: OpaquePointer?
    let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
    logInfo("sqlite3_prepare_v2 for migration tasks returned: \(rc), stmt: \(stmt != nil ? "valid" : "nil")", category: "SQLite")

    guard rc == SQLITE_OK && stmt != nil else {
        throw NSError(domain: "SQLiteError", code: Int(rc), userInfo: [NSLocalizedDescriptionKey: "Failed to prepare query: \(sql)"])
    }

    defer { sqlite3_finalize(stmt) }

    var tasks: [AnigmaCore.MigrationTaskRow] = []
    var paramIndex = 1

    // Bind parameters in order
    for param in params {
        if let stringValue = param as? String {
            sqlite3_bind_text(stmt, Int32(paramIndex), stringValue, -1, sqliteTransientDestructor)
        } else if let intValue = param as? Int {
            sqlite3_bind_int(stmt, Int32(paramIndex), Int32(intValue))
        }
        paramIndex += 1
    }

    logInfo("Loaded \(tasks.count) migration tasks for project \(projectId) (scanned \(tasks.count) rows)", category: "SQLite")

    while sqlite3_step(stmt) == SQLITE_ROW {
        let id = String(cString: sqlite3_column_text(stmt, 0))
        let projectIdString = String(cString: sqlite3_column_text(stmt, 1))
        let featureCategory = String(cString: sqlite3_column_text(stmt, 2))
        let status = String(cString: sqlite3_column_text(stmt, 3))
        let priority = Int(sqlite3_column_int(stmt, 4))
        let findingId = sqlite3_column_text(stmt, 5)
        let findingIdString = findingId != nil ? String(cString: findingId!) : nil
        let researchBundleId = sqlite3_column_text(stmt, 6)
        let researchBundleIdString = researchBundleId != nil ? String(cString: researchBundleId!) : nil
        let path = sqlite3_column_text(stmt, 7)
        let pathString = path != nil ? String(cString: path!) : nil
        let pathDetail = sqlite3_column_text(stmt, 8)
        let pathDetailString = pathDetail != nil ? String(cString: pathDetail!) : nil
        let createdAt = sqlite3_column_double(stmt, 9)
        let createdAtDate = Date(timeIntervalSince1970: createdAt)

        let task = AnigmaPrimitives.MigrationTaskRow(
            id: id,
            originalTaskId: nil,
            engineType: "swift6-migration",
            featureCategory: featureCategory,
            filePath: pathString,
            fileHash: nil,
            fileModificationDate: nil,
            status: status,
            createdAt: createdAtDate,
            startedAt: nil,
            completedAt: nil,
            errorMessage: nil,
            priority: priority,
            metadata: nil,
            trustTier: nil,
            projectId: UUID(uuidString: projectIdString),
            findingId: findingIdString,
            researchBundleId: researchBundleIdString,
            path: pathString,
            pathDetail: pathDetailString
        )
        tasks.append(task)
    }

    return tasks
}
