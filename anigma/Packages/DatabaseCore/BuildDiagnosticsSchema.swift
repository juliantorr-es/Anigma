//
//  BuildDiagnosticsSchema.swift
//  DatabaseCore
//
//  Loads and applies the build diagnostics schema from bundled SQL.
//

import Foundation

private class CurrentBundleFinder {}

public enum BuildDiagnosticsSchema {
    public static func apply(using db: DatabaseActor) async throws {
        // Find the bundle containing this class to access resources
        let bundle = Bundle(for: CurrentBundleFinder.self)
        guard let url = bundle.url(forResource: "Schema_BuildDiagnostics", withExtension: "sql") else {
            throw DatabaseError.queryError("Schema_BuildDiagnostics.sql not found in DatabaseCore resources")
        }

        let sql = try String(contentsOf: url, encoding: .utf8)
        _ = try await db.executeScript(sql)
    }
}
