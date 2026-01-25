//
//  EvidenceRecorder.swift
//  HarmoniaModule
//
//  Evidence recording for all tool calls.
//  Provides auditable trace of all agent actions.
//

import AnigmaCore
@preconcurrency import Foundation
import DatabaseCore
import ContractsCore
import AnigmaPrimitives

/// Evidence recorder that tracks all tool calls with full provenance.
public actor GovernedEvidenceRecorder: EvidenceRecorderProtocol {
    private let masterDb: any DatabaseCore.DatabaseExecutor
    private let artifactStore: ArtifactStore
    private let artifactAuthority: (any ArtifactAuthority)?

    public init(masterDb: any DatabaseCore.DatabaseExecutor) {
        self.masterDb = masterDb
        self.artifactAuthority = nil
        self.artifactStore = ArtifactStore(db: masterDb)
    }
    
    public init(artifactAuthority: any ArtifactAuthority, masterDb: (any DatabaseCore.DatabaseExecutor)? = nil) {
        self.artifactAuthority = artifactAuthority
        self.masterDb = masterDb ?? (artifactAuthority as? any DatabaseCore.DatabaseExecutor) ?? DummyDatabaseExecutor()
        self.artifactStore = ArtifactStore(artifactAuthority: artifactAuthority, db: self.masterDb)
    }

    /// Start recording evidence for tool call.
    public func startToolCall(_ request: AnigmaCore.ToolCallRequest, evidenceId: String? = nil) async -> String {
        let insertionId = evidenceId ?? UUID().uuidString
        let timestamp = Int(Date().timeIntervalSince1970)

        do {
            _ = try await masterDb.executeAsync(
                """
                INSERT INTO evidence_chain (
                    evidence_id, session_id, agent_id, tool_name, request_id,
                    parameters, file_path, start_time, status
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                parameters: [
                    .text(insertionId),
                    .text(request.sessionId),
                    .text(request.agentId),
                    .text(request.toolName),
                    .text(request.requestId),
                    .null,
                    .null,
                    .int(timestamp),
                    .text(OperationExecutionStatus.started.rawValue)
                ]
            )
        } catch {
            print("[GovernedEvidenceRecorder] failed to insert evidence row: \(error)")
        }

        return insertionId
    }

    /// Record successful tool call completion.
    public func recordSuccess(_ evidenceId: String, result: Codable) async {
        let timestamp = Int(Date().timeIntervalSince1970)
        let payload = encodeResult(result)

        do {
            _ = try await masterDb.executeAsync(
                """
                UPDATE evidence_chain
                SET status = ?,
                    result = ?,
                    end_time = ?
                WHERE evidence_id = ?
                """,
                parameters: [
                    .text(OperationExecutionStatus.success.rawValue),
                    .text(payload),
                    .int(timestamp),
                    .text(evidenceId)
                ]
            )
        } catch {
            print("[GovernedEvidenceRecorder] failed to update success state: \(error)")
        }
    }

    /// Record failed tool call.
    public func recordFailure(_ evidenceId: String, error: Error) async {
        let timestamp = Int(Date().timeIntervalSince1970)
        let message = error.localizedDescription
        let details = String(describing: error)

        do {
            _ = try await masterDb.executeAsync(
                """
                UPDATE evidence_chain
                SET status = ?,
                    error = ?,
                    error_details = ?,
                    end_time = ?
                WHERE evidence_id = ?
                """,
                parameters: [
                    .text(OperationExecutionStatus.failed.rawValue),
                    .text(message),
                    .text(details),
                    .int(timestamp),
                    .text(evidenceId)
                ]
            )
        } catch {
            print("[GovernedEvidenceRecorder] failed to update failure state: \(error)")
        }
    }

    /// Record edit-specific result details.
    private func recordEditResult(_ evidenceId: String, _ result: EditToolResponse) async throws {
        _ = try await masterDb.executeAsync("""
            INSERT INTO edit_results (
                evidence_id, success, changes_count, new_file_hash, applied_diff
            ) VALUES (?, ?, ?, ?, ?)
        """, parameters: [
            .text(evidenceId),
            .text(result.success ? "1" : "0"),
            .text(String(result.actualChanges)),
            .text(result.newFileHash),
            .text(result.appliedDiff ?? "")
        ])

        // Record individual changes
        for (index, change) in result.changes.enumerated() {
            let sql = """
                INSERT INTO file_changes (
                    evidence_id, change_index, change_type, start_offset, end_offset,
                    old_content, new_content
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """
            let parameters: [DatabaseParameter] = [
                .text(evidenceId),
                .int(index),
                .text(change.type.rawValue),
                .int(change.startOffset),
                .int(change.endOffset),
                .text(change.oldContent ?? ""),
                .text(change.newContent ?? "")
            ]
            _ = try await masterDb.executeAsync(sql, parameters: parameters)
        }
    }

    /// Record read-specific result details.
    private func recordReadResult(_ evidenceId: String, _ result: ReadToolResponse) async throws {
        _ = try await masterDb.executeAsync("""
            INSERT INTO read_results (
                evidence_id, file_size, file_hash, last_modified, permissions_readable,
                permissions_writable, permissions_executable
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
        """, parameters: [
            .text(evidenceId),
            .text(String(result.size)),
            .text(result.hash),
            .text(String(result.lastModified)),
            .text((result.permissions?.readable ?? false) ? "1" : "0"),
            .text((result.permissions?.writable ?? false) ? "1" : "0"),
            .text((result.permissions?.executable ?? false) ? "1" : "0")
        ])
    }

    /// Query evidence for a session.
    public func getSessionEvidence(_ sessionId: String, limit: Int = 100) async throws -> [EvidenceRecord] {
        let rows = try await masterDb.query("""
            SELECT evidence_id, session_id, agent_id, tool_name, request_id,
                   parameters, file_path, content_hash, start_time, end_time,
                   status, result, error, error_details
            FROM evidence_chain
            WHERE session_id = ?
            ORDER BY start_time DESC
            LIMIT ?
        """, parameters: [.text(sessionId), .text(String(limit))])

        return rows.compactMap { row in
            guard let evidenceId = row.string(for: "evidence_id"),
                  let sessionId = row.string(for: "session_id"),
                  let agentId = row.string(for: "agent_id"),
                  let toolName = row.string(for: "tool_name"),
                  let requestId = row.string(for: "request_id"),
                  let statusString = row.string(for: "status"),
                  let _ = OperationExecutionStatus(rawValue: statusString) else { return nil }

            return EvidenceRecord(
                evidenceId: evidenceId,
                sessionId: sessionId,
                agentId: agentId,
                toolName: toolName,
                requestId: requestId,
                parameters: row.string(for: "parameters") ?? "{}",
                filePath: row.string(for: "file_path"),
                contentHash: row.string(for: "content_hash"),
                startTime: row.string(for: "start_time") ?? "",
                endTime: row.string(for: "end_time"),
                status: OperationExecutionStatus(rawValue: statusString) ?? .unknown,
                result: row.string(for: "result"),
                error: row.string(for: "error"),
                errorDetails: row.string(for: "error_details")
            )
        }
    }

    /// Get evidence statistics for a session.
    public func getSessionStats(_ sessionId: String) async throws -> EvidenceStats {
        let rows = try await masterDb.query("""
            SELECT tool_name, status, COUNT(*) as count
            FROM evidence_chain
            WHERE session_id = ?
            GROUP BY tool_name, status
        """, parameters: [.text(sessionId)])

        var toolStats: [String: [String: Int]] = [:]
        for row in rows {
            guard let tool = row.string(for: "tool_name"),
                  let status = row.string(for: "status"),
                  let count = row.int(for: "count") else { continue }

            toolStats[tool, default: [:]][status] = count
        }

        return EvidenceStats(sessionId: sessionId, toolStats: toolStats)
    }

    private func encodeResult(_ value: Codable) -> String {
        do {
            let data = try JSONEncoder().encode(value)
            return String(data: data, encoding: .utf8) ?? String(describing: value)
        } catch {
            return String(describing: value)
        }
    }
}

// MARK: - Supporting Types

/// Evidence record from database.
public struct EvidenceRecord: Sendable, Codable {
    public let evidenceId: String
    public let sessionId: String
    public let agentId: String
    public let toolName: String
    public let requestId: String
    public let parameters: String
    public let filePath: String?
    public let contentHash: String?
    public let startTime: String
    public let endTime: String?
    public let status: OperationExecutionStatus
    public let result: String?
    public let error: String?
    public let errorDetails: String?

    public init(
        evidenceId: String,
        sessionId: String,
        agentId: String,
        toolName: String,
        requestId: String,
        parameters: String,
        filePath: String?,
        contentHash: String?,
        startTime: String,
        endTime: String?,
        status: OperationExecutionStatus,
        result: String?,
        error: String?,
        errorDetails: String?
    ) {
        self.evidenceId = evidenceId
        self.sessionId = sessionId
        self.agentId = agentId
        self.toolName = toolName
        self.requestId = requestId
        self.parameters = parameters
        self.filePath = filePath
        self.contentHash = contentHash
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.result = result
        self.error = error
        self.errorDetails = errorDetails
    }
}

/// Evidence statistics for session.
public struct EvidenceStats: Sendable, Codable {
    public let sessionId: String
    public let toolStats: [String: [String: Int]]

    public init(sessionId: String, toolStats: [String: [String: Int]]) {
        self.sessionId = sessionId
        self.toolStats = toolStats
    }

    public func totalCalls() -> Int {
        return toolStats.values.flatMap { $0.values }.reduce(0, +)
    }

    public func successRate() -> Double {
        let total = totalCalls()
        let successes = toolStats.values.compactMap { $0["success"] ?? 0 }.reduce(0, +)
        return total > 0 ? Double(successes) / Double(total) : 0.0
    }
}

private actor DummyDatabaseExecutor: DatabaseCore.DatabaseExecutor {
    @discardableResult
    func execute(_ sql: String, parameters: [DatabaseParameter]) async throws -> Int { 0 }
    func query(_ sql: String, parameters: [DatabaseParameter]) async throws -> [DatabaseRow] { [] }
    @discardableResult
    func executeAsync(_ sql: String, parameters: [DatabaseParameter]) async throws -> Int { 0 }
    func transaction(_ block: @Sendable () async throws -> Void) async throws { try await block() }
    func open() throws {}
    func close() {}
    var path: String { "" }
}
