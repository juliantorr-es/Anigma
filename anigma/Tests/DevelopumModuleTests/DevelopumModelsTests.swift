//
//  DevelopumModelsTests.swift
//  DevelopumModuleTests
//
//  Tests for DevelopumModule data models.
//

import XCTest
@testable import AnigmaCore
@testable import DevelopumModule

final class DevelopumModelsTests: XCTestCase {

    // MARK: - RepoRecord Tests

    func testRepoRecordInitialization() {
        let record = RepoRecord(
            repoPath: "/test/repo",
            remoteUrl: "https://github.com/test/repo.git",
            currentBranch: "develop",
            headSha: "abc123"
        )

        XCTAssertEqual(record.repoPath, "/test/repo")
        XCTAssertEqual(record.remoteUrl, "https://github.com/test/repo.git")
        XCTAssertEqual(record.currentBranch, "develop")
        XCTAssertEqual(record.headSha, "abc123")
        XCTAssertTrue(record.isActive)
        XCTAssertNil(record.workspaceConfig)
        XCTAssertNil(record.metadata)
    }

    func testRepoRecordDefaultValues() {
        let record = RepoRecord(repoPath: "/test/repo")

        XCTAssertFalse(record.id.uuidString.isEmpty)
        XCTAssertEqual(record.currentBranch, "main")
        XCTAssertEqual(record.headSha, "")
        XCTAssertTrue(record.isActive)
        XCTAssertNotNil(record.createdAt)
        XCTAssertNotNil(record.lastActivityAt)
    }

    func testRepoRecordDatabaseTableName() {
        XCTAssertEqual(RepoRecord.databaseTableName, "developum_repos")
    }

    func testRepoRecordColumnDefinitions() {
        XCTAssertEqual(RepoRecord.Columns.id.name, "id")
        XCTAssertEqual(RepoRecord.Columns.repoPath.name, "repo_path")
        XCTAssertEqual(RepoRecord.Columns.remoteUrl.name, "remote_url")
        XCTAssertEqual(RepoRecord.Columns.currentBranch.name, "current_branch")
        XCTAssertEqual(RepoRecord.Columns.headSha.name, "head_sha")
        XCTAssertEqual(RepoRecord.Columns.createdAt.name, "created_at")
        XCTAssertEqual(RepoRecord.Columns.lastActivityAt.name, "last_activity_at")
        XCTAssertEqual(RepoRecord.Columns.isActive.name, "is_active")
        XCTAssertEqual(RepoRecord.Columns.workspaceConfig.name, "workspace_config")
        XCTAssertEqual(RepoRecord.Columns.metadata.name, "metadata")
    }

    func testRepoRecordCodableRoundtrip() throws {
        let original = RepoRecord(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!,
            repoPath: "/test/repo",
            remoteUrl: "https://github.com/test/repo.git",
            currentBranch: "feature/test",
            headSha: "def456",
            workspaceConfig: "{\"theme\": \"dark\"}",
            metadata: "{\"version\": \"1.0\"}"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RepoRecord.self, from: data)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.repoPath, decoded.repoPath)
        XCTAssertEqual(original.remoteUrl, decoded.remoteUrl)
        XCTAssertEqual(original.currentBranch, decoded.currentBranch)
        XCTAssertEqual(original.headSha, decoded.headSha)
        XCTAssertEqual(original.workspaceConfig, decoded.workspaceConfig)
        XCTAssertEqual(original.metadata, decoded.metadata)
    }

    // MARK: - WorkspaceState Tests

    func testWorkspaceStateInitialization() {
        let repoId = UUID()
        let state = WorkspaceState(
            repoId: repoId,
            filePath: "src/main.swift",
            cursorLine: 42,
            cursorColumn: 10,
            selectionStartLine: 40,
            selectionStartColumn: 0,
            selectionEndLine: 42,
            selectionEndColumn: 15
        )

        XCTAssertEqual(state.repoId, repoId)
        XCTAssertEqual(state.filePath, "src/main.swift")
        XCTAssertEqual(state.cursorLine, 42)
        XCTAssertEqual(state.cursorColumn, 10)
        XCTAssertEqual(state.selectionStartLine, 40)
        XCTAssertEqual(state.selectionEndLine, 42)
        XCTAssertTrue(state.isOpen)
        XCTAssertFalse(state.hasUnsavedChanges)
    }

    func testWorkspaceStateDefaultValues() {
        let repoId = UUID()
        let state = WorkspaceState(repoId: repoId, filePath: "test.swift")

        XCTAssertFalse(state.id.uuidString.isEmpty)
        XCTAssertEqual(state.cursorLine, 0)
        XCTAssertEqual(state.cursorColumn, 0)
        XCTAssertNil(state.selectionStartLine)
        XCTAssertNil(state.viewportTopLine)
        XCTAssertTrue(state.isOpen)
        XCTAssertFalse(state.hasUnsavedChanges)
    }

    func testWorkspaceStateDatabaseTableName() {
        XCTAssertEqual(WorkspaceState.databaseTableName, "developum_workspace_states")
    }

    func testWorkspaceStateColumnDefinitions() {
        XCTAssertEqual(WorkspaceState.Columns.id.name, "id")
        XCTAssertEqual(WorkspaceState.Columns.repoId.name, "repo_id")
        XCTAssertEqual(WorkspaceState.Columns.filePath.name, "file_path")
        XCTAssertEqual(WorkspaceState.Columns.cursorLine.name, "cursor_line")
        XCTAssertEqual(WorkspaceState.Columns.cursorColumn.name, "cursor_column")
        XCTAssertEqual(WorkspaceState.Columns.selectionStartLine.name, "selection_start_line")
        XCTAssertEqual(WorkspaceState.Columns.isOpen.name, "is_open")
        XCTAssertEqual(WorkspaceState.Columns.updatedAt.name, "updated_at")
    }

    func testWorkspaceStateCodableRoundtrip() throws {
        let id = UUID(uuidString: "87654321-4321-4321-4321-abcdef123456")!
        let repoId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let original = WorkspaceState(
            id: id,
            repoId: repoId,
            filePath: "Tests/CoreTests.swift",
            cursorLine: 100,
            cursorColumn: 25,
            selectionStartLine: 95,
            selectionStartColumn: 10,
            selectionEndLine: 100,
            selectionEndColumn: 30,
            viewportTopLine: 90,
            viewportBottomLine: 110,
            isOpen: true,
            hasUnsavedChanges: true,
            editorState: "{\"fold\": [5, 10]}"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WorkspaceState.self, from: data)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.repoId, decoded.repoId)
        XCTAssertEqual(original.filePath, decoded.filePath)
        XCTAssertEqual(original.cursorLine, decoded.cursorLine)
        XCTAssertEqual(original.cursorColumn, decoded.cursorColumn)
        XCTAssertEqual(original.hasUnsavedChanges, decoded.hasUnsavedChanges)
        XCTAssertEqual(original.editorState, decoded.editorState)
    }

    // MARK: - IndexArtifactRecord Tests

    func testIndexArtifactRecordInitialization() {
        let repoId = UUID()
        let record = IndexArtifactRecord(
            repoId: repoId,
            artifactHash: "sha256:abc123",
            filePath: "src/utils.swift",
            mimeType: "text/x-swift",
            languageId: "swift",
            fileSize: 1024
        )

        XCTAssertEqual(record.repoId, repoId)
        XCTAssertEqual(record.artifactHash, "sha256:abc123")
        XCTAssertEqual(record.filePath, "src/utils.swift")
        XCTAssertEqual(record.mimeType, "text/x-swift")
        XCTAssertEqual(record.languageId, "swift")
        XCTAssertEqual(record.fileSize, 1024)
        XCTAssertTrue(record.isCurrent)
    }

    func testIndexArtifactRecordDefaultValues() {
        let repoId = UUID()
        let record = IndexArtifactRecord(
            repoId: repoId,
            artifactHash: "sha256:test",
            filePath: "test.txt"
        )

        XCTAssertFalse(record.id.uuidString.isEmpty)
        XCTAssertEqual(record.mimeType, "text/plain")
        XCTAssertNil(record.languageId)
        XCTAssertEqual(record.fileSize, 0)
        XCTAssertNotNil(record.fileModifiedAt)
        XCTAssertNotNil(record.indexedAt)
        XCTAssertEqual(record.indexContent, Data())
        XCTAssertTrue(record.isCurrent)
    }

    func testIndexArtifactRecordDatabaseTableName() {
        XCTAssertEqual(IndexArtifactRecord.databaseTableName, "developum_index_artifacts")
    }

    func testIndexArtifactRecordColumnDefinitions() {
        XCTAssertEqual(IndexArtifactRecord.Columns.id.name, "id")
        XCTAssertEqual(IndexArtifactRecord.Columns.repoId.name, "repo_id")
        XCTAssertEqual(IndexArtifactRecord.Columns.artifactHash.name, "artifact_hash")
        XCTAssertEqual(IndexArtifactRecord.Columns.filePath.name, "file_path")
        XCTAssertEqual(IndexArtifactRecord.Columns.mimeType.name, "mime_type")
        XCTAssertEqual(IndexArtifactRecord.Columns.languageId.name, "language_id")
        XCTAssertEqual(IndexArtifactRecord.Columns.fileSize.name, "file_size")
        XCTAssertEqual(IndexArtifactRecord.Columns.isCurrent.name, "is_current")
    }

    func testIndexArtifactRecordCodableRoundtrip() throws {
        let repoId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let original = IndexArtifactRecord(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            repoId: repoId,
            artifactHash: "sha256:def789",
            filePath: "lib/core.swift",
            mimeType: "text/x-swift",
            languageId: "swift",
            fileSize: 4096,
            indexContent: "{\"tokens\": [\"func\", \"class\", \"struct\"]}".data(using: .utf8)!
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(IndexArtifactRecord.self, from: data)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.repoId, decoded.repoId)
        XCTAssertEqual(original.artifactHash, decoded.artifactHash)
        XCTAssertEqual(original.filePath, decoded.filePath)
        XCTAssertEqual(original.languageId, decoded.languageId)
        XCTAssertEqual(original.fileSize, decoded.fileSize)
        XCTAssertEqual(original.indexContent, decoded.indexContent)
    }

    // MARK: - Enum Tests

    func testRepoSessionStatusCases() {
        XCTAssertEqual(RepoSessionStatus.active.rawValue, "active")
        XCTAssertEqual(RepoSessionStatus.paused.rawValue, "paused")
        XCTAssertEqual(RepoSessionStatus.closed.rawValue, "closed")
        XCTAssertEqual(RepoSessionStatus.archived.rawValue, "archived")
    }

    func testIndexArtifactTypeCases() {
        XCTAssertEqual(IndexArtifactType.fileStructure.rawValue, "fileStructure")
        XCTAssertEqual(IndexArtifactType.symbolTable.rawValue, "symbolTable")
        XCTAssertEqual(IndexArtifactType.textTokens.rawValue, "textTokens")
        XCTAssertEqual(IndexArtifactType.fullText.rawValue, "fullText")
    }

    // MARK: - Edge Cases

    func testRepoRecordWithNilOptionals() {
        let record = RepoRecord(
            repoPath: "/test",
            remoteUrl: nil,
            workspaceConfig: nil,
            metadata: nil
        )

        XCTAssertNil(record.remoteUrl)
        XCTAssertNil(record.workspaceConfig)
        XCTAssertNil(record.metadata)
    }

    func testWorkspaceStateWithNilSelections() {
        let repoId = UUID()
        let state = WorkspaceState(
            repoId: repoId,
            filePath: "test.swift",
            cursorLine: 10,
            cursorColumn: 5,
            selectionStartLine: nil,
            selectionEndLine: nil
        )

        XCTAssertNil(state.selectionStartLine)
        XCTAssertNil(state.selectionEndLine)
    }

    func testIndexArtifactRecordWithEmptyIndexContent() {
        let repoId = UUID()
        let record = IndexArtifactRecord(
            repoId: repoId,
            artifactHash: "sha256:empty",
            filePath: "empty.swift",
            indexContent: Data()
        )

        XCTAssertEqual(record.indexContent, Data())
    }

    func testLargeFileSize() {
        let repoId = UUID()
        let record = IndexArtifactRecord(
            repoId: repoId,
            artifactHash: "sha256:large",
            filePath: "large.swift",
            fileSize: Int64.max
        )

        XCTAssertEqual(record.fileSize, Int64.max)
    }

    func testSpecialCharactersInPaths() {
        let record = RepoRecord(
            repoPath: "/test/path with spaces/and'quotes",
            remoteUrl: "https://example.com/repo(with)parentheses.git"
        )

        XCTAssertEqual(record.repoPath, "/test/path with spaces/and'quotes")
        XCTAssertEqual(record.remoteUrl, "https://example.com/repo(with)parentheses.git")
    }
}
