//
//  DatabaseExtensions.swift
//  BuildIngest
//
//  DatabaseActor extensions for BuildIngest operations.
//  Uses SQLITE_TRANSIENT for Swift string safety.
//

import Foundation
import DatabaseCore
import CryptoKit

// MARK: - DatabaseActor Extensions for BuildIngest

extension DatabaseActor {

    /// Insert document unit record with safe string binding.
    public func insertDocumentUnit(_ record: BuildIngestService.DocumentUnitRecord) async throws {
        let insertSQL = """
            INSERT INTO document_units (
                id, origin, path, content_hash, git_commit, created_at
            ) VALUES (?, ?, ?, ?, ?)
            """

        try await execute(insertSQL, parameters: [
            .text(record.id),
            .text(record.origin),
            .text(record.path),
            .text(record.contentHash),
            .text(record.gitCommit ?? ""),
            .text(String(record.createdAtUnix))
        ])
    }

    /// Insert build session record with safe string binding.
    public func insertBuildSession(_ record: BuildIngestService.BuildSessionRecord) async throws {
        let insertSQL = """
            INSERT INTO build_sessions (
                id, git_state_id, target, configuration, toolchain,
                start_timestamp, build_status
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """

        try await execute(insertSQL, parameters: [
            .text(record.id),
            .text(record.gitStateId),
            .text(record.target),
            .text(record.configuration),
            .text(record.toolchain),
            .text(String(record.startTimeUnix)),
            .text(record.buildStatus)
        ])
    }

    /// Insert Swift diagnostic record with safe string binding.
    public func insertSwiftDiagnostic(_ record: BuildIngestService.SwiftDiagnostic) async throws {
        let insertSQL = """
            INSERT INTO build_diagnostics (
                id, build_session_id, file_path, line_number, column_number,
                severity, category, tool, message, code_snippet,
                function_name, module_name, rule_id, fixit_available
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """

        try await execute(insertSQL, parameters: [
            .text(UUID().uuidString),
            .text(record.buildSessionId),
            .text(record.filePath),
            .int(record.lineNumber),
            .int(record.columnNumber),
            .text(record.severity),
            .text(record.category),
            .text(record.tool),
            .text(record.message),
            .text(record.codeSnippet ?? ""),
            .text(record.functionName ?? ""),
            .text(record.moduleName ?? ""),
            .text(record.ruleId ?? ""),
            .text(record.fixitAvailable ? "1" : "0")
        ])
    }

    /// Query document units by origin with safe string binding.
    public func queryDocumentUnits(origin: String, limit: Int = 10) throws -> [BuildIngestService.DocumentUnitRecord] {
        let query = """
            SELECT id, origin, path, content_hash, git_commit, created_at
            FROM document_units
            WHERE origin = ?
            ORDER BY created_at DESC
            LIMIT ?
            """

        let results = try query(query, parameters: [.text(origin), .int(limit)])
        return results.compactMap { row in
            guard let id = row.string(for: "id"),
                  let origin = row.string(for: "origin"),
                  let path = row.string(for: "path"),
                  let contentHash = row.string(for: "content_hash"),
                  let gitCommit = row.string(for: "git_commit"),
                  let createdAtString = row.string(for: "created_at"),
                  let createdAtUnix = Int64(createdAtString) else { return nil }

            return BuildIngestService.DocumentUnitRecord(
                id: id,
                origin: origin,
                path: path,
                contentHash: contentHash,
                gitCommit: gitCommit,
                createdAtUnix: createdAtUnix
            )
        }
    }

    /// Update build session with completion status.
    public func updateBuildSession(
        sessionId: String,
        exitCode: Int32,
        endTime: Date,
        totalErrors: Int,
        totalWarnings: Int,
        artifactPath: String?
    ) async throws {
        let updateSQL = """
            UPDATE build_sessions SET
                end_timestamp = ?, exit_code = ?, build_status = ?,
                total_errors = ?, total_warnings = ?, artifact_path = ?
            WHERE id = ?
            """

        let status: String
        if exitCode == 0 {
            status = "completed"
        } else {
            status = "failed"
        }

        try await execute(updateSQL, parameters: [
            .text(String(Int(endTime.timeIntervalSince1970))),
            .text(String(exitCode)),
            .text(status),
            .text(String(totalErrors)),
            .text(String(totalWarnings)),
            .text(artifactPath ?? ""),
            .text(sessionId)
        ])
    }

    /// Store diagnostic with safe string binding.
    public func storeDiagnostic(
        dbActor: DatabaseActor,
        buildSessionId: String,
        diagnostic: BuildIngestService.Diagnostic
    ) async throws {
        let insertSQL = """
            INSERT INTO build_diagnostics (
                id, build_session_id, file_path, line_number, column_number,
                severity, category, tool, message, code_snippet,
                function_name, module_name, rule_id, fixit_available
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """

        try await execute(insertSQL, parameters: [
            .text(diagnostic.id),
            .text(buildSessionId),
            .text(diagnostic.filePath),
            .int(diagnostic.lineNumber),
            .int(diagnostic.columnNumber),
            .text(diagnostic.severity),
            .text(diagnostic.category),
            .text(diagnostic.tool),
            .text(diagnostic.message),
            .text(diagnostic.codeSnippet ?? ""),
            .text(diagnostic.functionName ?? ""),
            .text(diagnostic.moduleName ?? ""),
            .text(diagnostic.ruleId ?? ""),
            .text(diagnostic.fixitAvailable ? "1" : "0")
        ])
    }
}

// MARK: - Safe String Binding Helpers

extension DatabaseActor {

    /// Bind text parameter with SQLITE_TRANSIENT for Swift safety.
    private func bindTextSafe(_ stmt: OpaquePointer?, _ index: Int32, _ text: String) {
        sqlite3_bind_text(stmt, index, text, -1, SQLITE_TRANSIENT)
    }

    /// Bind blob parameter with SQLITE_TRANSIENT for Swift safety.
    private func bindBlobSafe(_ stmt: OpaquePointer?, _ index: Int32, _ data: Data) {
        data.withUnsafeBytes { bytes in
            sqlite3_bind_blob(stmt, index, bytes.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
        }
    }
}
