//
//  DevelopumDatabaseService.swift
//  DevelopumModule
//
//  Database service for Develop mode operations.
//  Provides thread-safe access to DevelopumModule tables.
//

import AnigmaCore
import Foundation
import DatabaseCore

public actor DevelopumDatabaseService {
    private let databaseAuthority: any AnigmaFoundation.DatabaseAuthority

    public init(databaseAuthority: any AnigmaFoundation.DatabaseAuthority) {
        self.databaseAuthority = databaseAuthority
    }

    public func createRepoRecord(_ record: RepoRecord) async throws {
        let mutation = DatabaseMutation(
            sql: """
            INSERT INTO developum_repos (
                id, repo_path, remote_url, current_branch, head_sha,
                created_at, last_activity_at, is_active, workspace_config, metadata
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(record.id.uuidString),
                .text(record.repoPath),
                record.remoteUrl.map { .text($0) } ?? .null,
                .text(record.currentBranch),
                .text(record.headSha),
                .double(record.createdAt.timeIntervalSince1970 * 1000),
                .double(record.lastActivityAt.timeIntervalSince1970 * 1000),
                .int(record.isActive ? 1 : 0),
                record.workspaceConfig.map { .text($0) } ?? .null,
                record.metadata.map { .text($0) } ?? .null
            ]
        )
        _ = try await databaseAuthority.mutate(mutation, context: ExecutionContext(principal: .system))
    }

    public func getRepoRecord(id: UUID) async throws -> RepoRecord? {
        let rows = try await databaseAuthority.query(
            "SELECT * FROM developum_repos WHERE id = ?",
            parameters: [DatabaseParameter.text(id.uuidString)]
        )

        guard let row = rows.first else { return nil }
        return try decodeRepoRecord(from: row)
    }

    public func getRepoRecord(path: String) async throws -> RepoRecord? {
        let rows = try await databaseAuthority.query(
            "SELECT * FROM developum_repos WHERE repo_path = ?",
            parameters: [DatabaseParameter.text(path)]
        )

        guard let row = rows.first else { return nil }
        return try decodeRepoRecord(from: row)
    }

    public func updateRepoRecordActivity(id: UUID, isActive: Bool = true) async throws {
        let mutation = DatabaseMutation(
            sql: """
            UPDATE developum_repos
            SET last_activity_at = ?, is_active = ?
            WHERE id = ?
            """,
            parameters: [
                DatabaseParameter.double(Date().timeIntervalSince1970 * 1000),
                DatabaseParameter.int(isActive ? 1 : 0),
                DatabaseParameter.text(id.uuidString)
            ]
        )
        _ = try await databaseAuthority.mutate(mutation, context: ExecutionContext(principal: .system))
    }

    public func listActiveRepoRecords(limit: Int = 100) async throws -> [RepoRecord] {
        let rows = try await databaseAuthority.query(
            """
            SELECT * FROM developum_repos
            WHERE is_active = 1
            ORDER BY last_activity_at DESC
            LIMIT ?
            """,
            parameters: [DatabaseParameter.int(limit)]
        )

        return try rows.map { try decodeRepoRecord(from: $0) }
    }

    public func deactivateRepoRecord(id: UUID) async throws {
        let mutation = DatabaseMutation(
            sql: """
            UPDATE developum_repos
            SET is_active = 0, last_activity_at = ?
            WHERE id = ?
            """,
            parameters: [
                .double(Date().timeIntervalSince1970 * 1000),
                .text(id.uuidString)
            ]
        )
        _ = try await databaseAuthority.mutate(mutation, context: ExecutionContext(principal: .system))
    }

    public func saveWorkspaceState(_ state: WorkspaceState) async throws {
        let mutation = DatabaseMutation(
            sql: """
            INSERT OR REPLACE INTO developum_workspace_states (
                id, repo_id, file_path, cursor_line, cursor_column,
                selection_start_line, selection_start_column,
                selection_end_line, selection_end_column,
                viewport_top_line, viewport_bottom_line,
                is_open, has_unsaved_changes, updated_at, editor_state
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(state.id.uuidString),
                .text(state.repoId.uuidString),
                .text(state.filePath),
                .int(state.cursorLine),
                .int(state.cursorColumn),
                state.selectionStartLine.map { .int($0) } ?? .null,
                state.selectionStartColumn.map { .int($0) } ?? .null,
                state.selectionEndLine.map { .int($0) } ?? .null,
                state.selectionEndColumn.map { .int($0) } ?? .null,
                state.viewportTopLine.map { .int($0) } ?? .null,
                state.viewportBottomLine.map { .int($0) } ?? .null,
                .int(state.isOpen ? 1 : 0),
                .int(state.hasUnsavedChanges ? 1 : 0),
                .double(state.updatedAt.timeIntervalSince1970 * 1000),
                state.editorState.map { .text($0) } ?? .null
            ]
        )
        _ = try await databaseAuthority.mutate(mutation, context: ExecutionContext(principal: .system))
    }

    public func getWorkspaceStates(repoId: UUID) async throws -> [WorkspaceState] {
        let rows = try await databaseAuthority.query(
            """
            SELECT * FROM developum_workspace_states
            WHERE repo_id = ?
            ORDER BY updated_at DESC
            """,
            parameters: [.text(repoId.uuidString)]
        )

        return try rows.map { try decodeWorkspaceState(from: $0) }
    }

    public func getWorkspaceState(repoId: UUID, filePath: String) async throws -> WorkspaceState? {
        let rows = try await databaseAuthority.query(
            """
            SELECT * FROM developum_workspace_states
            WHERE repo_id = ? AND file_path = ?
            LIMIT 1
            """,
            parameters: [.text(repoId.uuidString), .text(filePath)]
        )

        guard let row = rows.first else { return nil }
        return try decodeWorkspaceState(from: row)
    }

    public func closeWorkspaceState(repoId: UUID, filePath: String) async throws {
        let mutation = DatabaseMutation(
            sql: """
            UPDATE developum_workspace_states
            SET is_open = 0, updated_at = ?
            WHERE repo_id = ? AND file_path = ?
            """,
            parameters: [
                .double(Date().timeIntervalSince1970 * 1000),
                .text(repoId.uuidString),
                .text(filePath)
            ]
        )
        _ = try await databaseAuthority.mutate(mutation, context: ExecutionContext(principal: .system))
    }

    public func deleteWorkspaceStates(repoId: UUID) async throws {
        let mutation = DatabaseMutation(
            sql: """
            DELETE FROM developum_workspace_states WHERE repo_id = ?
            """,
            parameters: [.text(repoId.uuidString)]
        )
        _ = try await databaseAuthority.mutate(mutation, context: ExecutionContext(principal: .system))
    }

    public func saveIndexArtifact(_ artifact: IndexArtifactRecord) async throws {
        let mutation = DatabaseMutation(
            sql: """
            INSERT OR REPLACE INTO developum_index_artifacts (
                id, repo_id, artifact_hash, file_path, mime_type,
                language_id, file_size, file_modified_at, indexed_at,
                index_content, is_current
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(artifact.id.uuidString),
                .text(artifact.repoId.uuidString),
                .text(artifact.artifactHash),
                .text(artifact.filePath),
                .text(artifact.mimeType),
                artifact.languageId.map { .text($0) } ?? .null,
                .int(Int(artifact.fileSize)),
                .double(artifact.fileModifiedAt.timeIntervalSince1970 * 1000),
                .double(artifact.indexedAt.timeIntervalSince1970 * 1000),
                .blob(artifact.indexContent),
                .int(artifact.isCurrent ? 1 : 0)
            ]
        )
        _ = try await databaseAuthority.mutate(mutation, context: ExecutionContext(principal: .system))
    }

    public func getIndexArtifacts(repoId: UUID, filePath: String? = nil) async throws -> [IndexArtifactRecord] {
        var sql = "SELECT * FROM developum_index_artifacts WHERE repo_id = ?"
        var params: [DatabaseParameter] = [.text(repoId.uuidString)]

        if let filePath = filePath {
            sql += " AND file_path = ?"
            params.append(.text(filePath))
        }

        sql += " ORDER BY indexed_at DESC"

        let rows = try await databaseAuthority.query(sql, parameters: params)
        return try rows.map { try decodeIndexArtifact(from: $0) }
    }

    public func markIndexArtifactsStale(repoId: UUID, filePath: String) async throws {
        let mutation = DatabaseMutation(
            sql: """
            UPDATE developum_index_artifacts
            SET is_current = 0
            WHERE repo_id = ? AND file_path = ?
            """,
            parameters: [.text(repoId.uuidString), .text(filePath)]
        )
        _ = try await databaseAuthority.mutate(mutation, context: ExecutionContext(principal: .system))
    }

    public func deleteStaleIndexArtifacts(olderThan date: Date) async throws {
        let mutation = DatabaseMutation(
            sql: """
            DELETE FROM developum_index_artifacts
            WHERE is_current = 0 AND indexed_at < ?
            """,
            parameters: [.double(date.timeIntervalSince1970 * 1000)]
        )
        _ = try await databaseAuthority.mutate(mutation, context: ExecutionContext(principal: .system))
    }

    public func recordBridgeEvent(
        id: UUID = UUID(),
        repoId: UUID,
        sessionId: String,
        messageType: String,
        messageHash: String,
        messageBody: Data,
        receiptHash: String? = nil,
        artifactHash: String? = nil
    ) async throws {
        let mutation = DatabaseMutation(
            sql: """
            INSERT INTO developum_bridge_events (
                id, repo_id, session_id, message_type, message_hash,
                message_body, timestamp, receipt_hash, artifact_hash
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(id.uuidString),
                .text(repoId.uuidString),
                .text(sessionId),
                .text(messageType),
                .text(messageHash),
                .blob(messageBody),
                .double(Date().timeIntervalSince1970 * 1000),
                receiptHash.map { .text($0) } ?? .null,
                artifactHash.map { .text($0) } ?? .null
            ]
        )
        _ = try await databaseAuthority.mutate(mutation, context: ExecutionContext(principal: .system))
    }

    public func getBridgeEvents(sessionId: String, limit: Int = 100) async throws -> [BridgeEvent] {
        let rows = try await databaseAuthority.query(
            """
            SELECT * FROM developum_bridge_events
            WHERE session_id = ?
            ORDER BY timestamp DESC
            LIMIT ?
            """,
            parameters: [.text(sessionId), .int(limit)]
        )

        return try rows.map { try decodeBridgeEvent(from: $0) }
    }
    
    // MARK: - Virtual Documents
    
    public func saveVirtualDocument(_ doc: VirtualDocumentRecord) async throws {
        // Deactivate old versions
        let deactivateMutation = DatabaseMutation(
            sql: """
            UPDATE developum_virtual_documents
            SET is_active = 0
            WHERE repo_id = ? AND file_path = ?
            """,
            parameters: [.text(doc.repoId.uuidString), .text(doc.filePath)]
        )
        _ = try await databaseAuthority.mutate(deactivateMutation, context: ExecutionContext(principal: .system))
        
        let mutation = DatabaseMutation(
            sql: """
            INSERT INTO developum_virtual_documents (
                id, repo_id, file_path, chunks_json, mime_type, last_modified, is_active
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            parameters: [
                .text(doc.id.uuidString),
                .text(doc.repoId.uuidString),
                .text(doc.filePath),
                .text(doc.chunksJson),
                .text(doc.mimeType),
                .double(doc.lastModified.timeIntervalSince1970 * 1000),
                .int(doc.isActive ? 1 : 0)
            ]
        )
        _ = try await databaseAuthority.mutate(mutation, context: ExecutionContext(principal: .system))
    }
    
    public func getVirtualDocument(repoId: UUID, filePath: String) async throws -> VirtualDocumentRecord? {
        let rows = try await databaseAuthority.query(
            """
            SELECT * FROM developum_virtual_documents
            WHERE repo_id = ? AND file_path = ? AND is_active = 1
            LIMIT 1
            """,
            parameters: [.text(repoId.uuidString), .text(filePath)]
        )
        
        guard let row = rows.first else { return nil }
        return try decodeVirtualDocument(from: row)
    }
    
    public func getVirtualDocumentHistory(repoId: UUID, filePath: String, limit: Int = 50) async throws -> [VirtualDocumentRecord] {
        let rows = try await databaseAuthority.query(
            """
            SELECT * FROM developum_virtual_documents
            WHERE repo_id = ? AND file_path = ?
            ORDER BY last_modified DESC
            LIMIT ?
            """,
            parameters: [.text(repoId.uuidString), .text(filePath), .int(limit)]
        )
        
        return try rows.map { try decodeVirtualDocument(from: $0) }
    }

    private func decodeRepoRecord(from row: DatabaseRow) throws -> RepoRecord {
        guard let idString = row.string(for: "id"),
              let id = UUID(uuidString: idString) else {
            throw DatabaseError.queryError("Invalid UUID in id column")
        }

        return RepoRecord(
            id: id,
            repoPath: row.string(for: "repo_path") ?? "",
            remoteUrl: row.string(for: "remote_url"),
            currentBranch: row.string(for: "current_branch") ?? "",
            headSha: row.string(for: "head_sha") ?? "",
            createdAt: Date(timeIntervalSince1970: (row.double(for: "created_at") ?? 0) / 1000),
            lastActivityAt: Date(timeIntervalSince1970: (row.double(for: "last_activity_at") ?? 0) / 1000),
            isActive: (row.int(for: "is_active") ?? 0) != 0,
            workspaceConfig: row.string(for: "workspace_config"),
            metadata: row.string(for: "metadata")
        )
    }

    private func decodeWorkspaceState(from row: DatabaseRow) throws -> WorkspaceState {
        guard let idString = row.string(for: "id"),
              let id = UUID(uuidString: idString),
              let repoIdString = row.string(for: "repo_id"),
              let repoId = UUID(uuidString: repoIdString) else {
            throw DatabaseError.queryError("Invalid UUID in workspace state")
        }

        return WorkspaceState(
            id: id,
            repoId: repoId,
            filePath: row.string(for: "file_path") ?? "",
            cursorLine: row.int(for: "cursor_line") ?? 0,
            cursorColumn: row.int(for: "cursor_column") ?? 0,
            selectionStartLine: row.int(for: "selection_start_line"),
            selectionStartColumn: row.int(for: "selection_start_column"),
            selectionEndLine: row.int(for: "selection_end_line"),
            selectionEndColumn: row.int(for: "selection_end_column"),
            viewportTopLine: row.int(for: "viewport_top_line"),
            viewportBottomLine: row.int(for: "viewport_bottom_line"),
            isOpen: (row.int(for: "is_open") ?? 0) != 0,
            hasUnsavedChanges: (row.int(for: "has_unsaved_changes") ?? 0) != 0,
            updatedAt: Date(timeIntervalSince1970: (row.double(for: "updated_at") ?? 0) / 1000),
            editorState: row.string(for: "editor_state")
        )
    }

    private func decodeIndexArtifact(from row: DatabaseRow) throws -> IndexArtifactRecord {
        guard let idString = row.string(for: "id"),
              let id = UUID(uuidString: idString),
              let repoIdString = row.string(for: "repo_id"),
              let repoId = UUID(uuidString: repoIdString) else {
            throw DatabaseError.queryError("Invalid UUID in index artifact")
        }

        return IndexArtifactRecord(
            id: id,
            repoId: repoId,
            artifactHash: row.string(for: "artifact_hash") ?? "",
            filePath: row.string(for: "file_path") ?? "",
            mimeType: row.string(for: "mime_type") ?? "text/plain",
            languageId: row.string(for: "language_id"),
            fileSize: Int64(row.int64(for: "file_size") ?? 0),
            fileModifiedAt: Date(timeIntervalSince1970: (row.double(for: "file_modified_at") ?? 0) / 1000),
            indexedAt: Date(timeIntervalSince1970: (row.double(for: "indexed_at") ?? 0) / 1000),
            indexContent: row.data(for: "index_content") ?? Data(),
            isCurrent: (row.int(for: "is_current") ?? 0) != 0
        )
    }

    private func decodeBridgeEvent(from row: DatabaseRow) throws -> BridgeEvent {
        guard let idString = row.string(for: "id"),
              let id = UUID(uuidString: idString),
              let repoIdString = row.string(for: "repo_id"),
              let repoId = UUID(uuidString: repoIdString) else {
            throw DatabaseError.queryError("Invalid UUID in bridge event")
        }

        return BridgeEvent(
            id: id,
            repoId: repoId,
            sessionId: row.string(for: "session_id") ?? "",
            messageType: row.string(for: "message_type") ?? "",
            messageHash: row.string(for: "message_hash") ?? "",
            messageBody: row.data(for: "message_body") ?? Data(),
            timestamp: Date(timeIntervalSince1970: (row.double(for: "timestamp") ?? 0) / 1000),
            receiptHash: row.string(for: "receipt_hash"),
            artifactHash: row.string(for: "artifact_hash")
        )
    }
    
    private func decodeVirtualDocument(from row: DatabaseRow) throws -> VirtualDocumentRecord {
        guard let idString = row.string(for: "id"),
              let id = UUID(uuidString: idString),
              let repoIdString = row.string(for: "repo_id"),
              let repoId = UUID(uuidString: repoIdString) else {
            throw DatabaseError.queryError("Invalid UUID in virtual document")
        }
        
        let chunksJson = row.string(for: "chunks_json") ?? "[]"
        let chunks = (try? JSONDecoder().decode([String].self, from: chunksJson.data(using: .utf8) ?? Data())) ?? []
        
        return VirtualDocumentRecord(
            id: id,
            repoId: repoId,
            filePath: row.string(for: "file_path") ?? "",
            chunks: chunks,
            mimeType: row.string(for: "mime_type") ?? "text/plain",
            lastModified: Date(timeIntervalSince1970: (row.double(for: "last_modified") ?? 0) / 1000),
            isActive: (row.int(for: "is_active") ?? 0) != 0
        )
    }
}

public struct BridgeEvent: Codable, Sendable {
    public let id: UUID
    public let repoId: UUID
    public let sessionId: String
    public let messageType: String
    public let messageHash: String
    public let messageBody: Data
    public let timestamp: Date
    public let receiptHash: String?
    public let artifactHash: String?

    public init(
        id: UUID,
        repoId: UUID,
        sessionId: String,
        messageType: String,
        messageHash: String,
        messageBody: Data,
        timestamp: Date,
        receiptHash: String? = nil,
        artifactHash: String? = nil
    ) {
        self.id = id
        self.repoId = repoId
        self.sessionId = sessionId
        self.messageType = messageType
        self.messageHash = messageHash
        self.messageBody = messageBody
        self.timestamp = timestamp
        self.receiptHash = receiptHash
        self.artifactHash = artifactHash
    }
}
