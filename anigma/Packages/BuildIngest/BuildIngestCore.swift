//
//  BuildIngestCore.swift
//  BuildIngest
//
//  Core library for build diagnostics ingestion.
//  Separates CLI parsing from database operations and evidence processing.
//

import Foundation
import DatabaseCore
import ArgumentParser
import CryptoKit
import AnigmaPrimitives

/// Core service for build diagnostics ingestion
public struct BuildIngestService {
    private let db: DatabaseActor

    public init(db: DatabaseActor) {
        self.db = db
    }

    /// Ingest documentation files as evidence
    public func ingestDocumentationDefaults() async throws {
        let paths = [
            "README.md",
            "Docs/index.md",
            "Docs/TechDebt.md",
            "governance-logbook.md"
        ]

        for path in paths {
            try await ingestDoc(at: path, origin: "doc:governance")
        }
    }

    /// Ingest a single documentation file
    public func ingestDoc(at path: String, origin: String) async throws {
        guard let data = FileManager.default.contents(atPath: path) else {
            throw BuildIngestError.fileNotFound(path)
        }

        let contentHash = blake3Hex(data: data)
        let gitState = try await captureGitState(workingDirectory: FileManager.default.currentDirectoryPath)

        let record = DocumentUnitRecord(
            id: contentHash,
            origin: origin,
            path: path,
            contentHash: contentHash,
            gitCommit: gitState.commitHash,
            createdAtUnix: unixNow()
        )

        try await db.insertDocumentUnit(record)
    }

    /// Query documentation by origin type
    public func queryDocsSummary() async throws -> [DocumentUnitRecord] {
        return try await db.queryDocumentUnits(origin: "doc:governance", limit: 20)
    }

    /// Create build session record
    public func createBuildSessionFingerprint() async throws -> String {
        let sessionId = UUID().uuidString
        let gitState = try await captureGitState(workingDirectory: FileManager.default.currentDirectoryPath)

        let record = BuildSessionRecord(
            id: sessionId,
            gitStateId: gitState.id,
            target: "build-ingest",
            configuration: "debug",
            toolchain: "swift-6.0",
            startTimeUnix: unixNow(),
            buildStatus: "running"
        )

        try await db.insertBuildSession(record)
        return sessionId
    }

    /// Parse Swift compiler diagnostics from text
    public func parseSwiftDiagnostics(_ text: String) -> [SwiftDiagnostic] {
        let lines = text.components(separatedBy: .newlines)
        var diagnostics: [SwiftDiagnostic] = []

        for (index, line) in lines.enumerated() {
            if let diagnostic = parseSwiftDiagnosticLine(line, lineNumber: index + 1) {
                diagnostics.append(diagnostic)
            }
        }

        return diagnostics
    }

    /// Parse individual Swift diagnostic line
    private func parseSwiftDiagnosticLine(_ line: String, lineNumber: Int) -> SwiftDiagnostic? {
        // Swift compiler format: /path/to/file.swift:line:column: error: message
        let pattern = #"^(.+?):(\d+):(\d+):\s*(error|warning|note):\s*(.+)$"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(location: 0, length: line.utf16.count)
        guard let match = regex.firstMatch(in: line, options: [], range: range) else { return nil }

        guard match.numberOfRanges >= 5 else { return nil }

        return SwiftDiagnostic(
            severity: extractString(from: line, range: match.range(at: 3)),
            message: extractString(from: line, range: match.range(at: 4)),
            filePath: extractString(from: line, range: match.range(at: 1)),
            lineNumber: lineNumber,
            columnNumber: extractInt(from: line, range: match.range(at: 2)),
            buildSessionId: "", // Will be filled by caller
            category: "compiler",
            tool: "swiftc",
            codeSnippet: nil,
            functionName: nil,
            moduleName: nil,
            ruleId: nil,
            fixitAvailable: false
        )
    }

    // MARK: - Supporting Types

    public struct DocumentUnitRecord: Sendable, Codable {
        public let id: String
        public let origin: String
        public let path: String
        public let contentHash: String
        public let gitCommit: String?
        public let createdAtUnix: Int64
    }

    public struct BuildSessionRecord: Sendable, Codable {
        public let id: String
        public let gitStateId: String
        public let target: String
        public let configuration: String
        public let toolchain: String
        public let startTimeUnix: Int64
        public let buildStatus: String
    }

    public struct SwiftDiagnostic: Sendable, Codable {
        public let severity: String
        public let message: String
        public let filePath: String
        public let lineNumber: Int
        public let columnNumber: Int
        public let buildSessionId: String
        public let category: String
        public let tool: String
        public let codeSnippet: String?
        public let functionName: String?
        public let moduleName: String?
        public let ruleId: String?
        public let fixitAvailable: Bool
    }

    // MARK: - Database Extensions

    extension DatabaseActor {
        /// Insert document unit record
        public func insertDocumentUnit(_ record: DocumentUnitRecord) async throws {
            let insertSQL = """
            INSERT INTO document_units (
                id, origin, path, content_hash, git_commit, created_at
            ) VALUES (?, ?, ?, ?, ?, ?)
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

        /// Insert build session record
        public func insertBuildSession(_ record: BuildSessionRecord) async throws {
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

        /// Insert Swift diagnostic record
        public func insertSwiftDiagnostic(_ record: SwiftDiagnostic) async throws {
            let insertSQL = """
            INSERT INTO build_diagnostics (
                id, build_session_id, file_path, line_number, column_number,
                severity, category, tool, message, code_snippet,
                function_name, module_name, rule_id, fixit_available
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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

        /// Query document units by origin
        public func queryDocumentUnits(origin: String, limit: Int = 10) throws -> [DocumentUnitRecord] {
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
                      let createdAtUnix = Int64(createdAtString ?? "0") else { return nil }

                return DocumentUnitRecord(
                    id: id,
                    origin: origin,
                    path: path,
                    contentHash: contentHash,
                    gitCommit: gitCommit,
                    createdAtUnix: createdAtUnix
                )
            }
        }
    }

    // MARK: - Git State Capture

    private func captureGitState(workingDirectory: String) async throws -> GitState {
        let process = Process()
        process.currentDirectoryPath = workingDirectory
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = [
            "rev-parse", "HEAD",
            "--abbrev-ref", "HEAD",
            "status", "--porcelain"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        let lines = output.components(separatedBy: .newlines)

        guard lines.count >= 2 else {
            throw BuildIngestError.gitStateCaptureFailed("Insufficient git output")
        }

        let commitHash = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let branch = lines[1].trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if working tree is dirty
        let statusProcess = Process()
        statusProcess.currentDirectoryPath = workingDirectory
        statusProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        statusProcess.arguments = ["status", "--porcelain=v1"]

        let statusPipe = Pipe()
        statusProcess.standardOutput = statusPipe
        try statusProcess.run()
        statusProcess.waitUntilExit()

        let statusOutput = String(data: statusPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        let isDirty = !statusOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return GitState(
            id: UUID().uuidString,
            commitHash: commitHash,
            branch: branch,
            isDirty: isDirty,
            diffHash: isDirty ? try await captureDiffHash(workingDirectory: workingDirectory) : nil,
            authorName: nil,
            authorEmail: nil,
            commitTimestamp: nil,
            message: nil
        )
    }

    private func captureDiffHash(workingDirectory: String) async throws -> String {
        let process = Process()
        process.currentDirectoryPath = workingDirectory
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["diff", "--staged", "--raw"]

        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        return String(format: "%02x", output.hash)
    }

    // MARK: - Utility Functions

    private func extractString(from string: String, range: NSRange) -> String {
        guard range.location != NSNotFound else { return "" }
        let start = String.Index(utf16Offset: range.location, in: string)
        let end = String.Index(utf16Offset: range.location + range.length, in: string)
        return String(string[start..<end])
    }

    private func extractInt(from string: String, range: NSRange) -> Int {
        guard range.location != NSNotFound else { return 0 }
        let substring = extractString(from: string, range: range)
        return Int(substring) ?? 0
    }

    private func blake3Hex(_ data: Data) -> String {
        return BLAKE3Digest.hex(of: data)
    }

    private func unixNow() -> Int64 {
        return Int64(Date().timeIntervalSince1970)
    }

    private func currentCommit() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "HEAD"]

        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Supporting Types

public struct GitState {
    public let id: String
    public let commitHash: String
    public let branch: String
    public let isDirty: Bool
    public let diffHash: String?
    public let authorName: String?
    public let authorEmail: String?
    public let commitTimestamp: Int?
    public let message: String?
}

public enum BuildIngestError: Error, LocalizedError {
    case gitStateCaptureFailed(String)
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .gitStateCaptureFailed(let message):
            return "Failed to capture git state: \(message)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        }
    }
}
