//
//  DevelopumDatabaseServiceTests.swift
//  DevelopumModuleTests
//
//  Tests for DevelopumDatabaseService operations.
//

import XCTest
import AnigmaCore
import DatabaseCore
@testable import DevelopumModule

final class DevelopumDatabaseServiceTests: XCTestCase {

    private var databaseAuthority: MockDatabaseAuthority!
    private var databaseService: DevelopumDatabaseService!

    override func setUp() {
        super.setUp()
        databaseAuthority = MockDatabaseAuthority()
        databaseService = DevelopumDatabaseService(databaseAuthority: databaseAuthority)
    }

    override func tearDown() {
        databaseAuthority = nil
        databaseService = nil
        super.tearDown()
    }

    // MARK: - RepoRecord Tests

    func testCreateRepoRecord() async throws {
        let record = RepoRecord(
            repoPath: "/test/repo",
            remoteUrl: "https://github.com/test/repo.git",
            currentBranch: "main",
            headSha: "abc123"
        )

        try await databaseService.createRepoRecord(record)

        XCTAssertEqual(databaseAuthority.mutationHistory.count, 1)
        let mutation = databaseAuthority.mutationHistory.first
        XCTAssertNotNil(mutation)
        XCTAssertTrue(mutation!.sql.contains("INSERT INTO developum_repos"))
        XCTAssertEqual(mutation!.parameters.count, 10)
    }

    func testGetRepoRecordById() async throws {
        let testId = UUID()
        databaseAuthority.queryResult = createMockRepoRow(id: testId)

        let result = try await databaseService.getRepoRecord(id: testId)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.id, testId)
        XCTAssertEqual(databaseAuthority.lastQuery, "SELECT * FROM developum_repos WHERE id = ?")
    }

    func testGetRepoRecordByPath() async throws {
        let testPath = "/test/repo"
        let testId = UUID()
        databaseAuthority.queryResult = createMockRepoRow(id: testId, path: testPath)

        let result = try await databaseService.getRepoRecord(path: testPath)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.repoPath, testPath)
        XCTAssertEqual(databaseAuthority.lastQuery, "SELECT * FROM developum_repos WHERE repo_path = ?")
    }

    func testGetRepoRecordNotFound() async throws {
        databaseAuthority.queryResult = []

        let result = try await databaseService.getRepoRecord(id: UUID())

        XCTAssertNil(result)
    }

    func testUpdateRepoRecordActivity() async throws {
        let testId = UUID()

        try await databaseService.updateRepoRecordActivity(id: testId, isActive: true)

        XCTAssertEqual(databaseAuthority.mutationHistory.count, 1)
        let mutation = databaseAuthority.mutationHistory.first
        XCTAssertTrue(mutation!.sql.contains("UPDATE developum_repos"))
        XCTAssertTrue(mutation!.sql.contains("last_activity_at"))
        XCTAssertTrue(mutation!.sql.contains("is_active"))
    }

    func testListActiveRepoRecords() async throws {
        let id1 = UUID()
        let id2 = UUID()
        databaseAuthority.queryResult = [
            createMockRepoRow(id: id1, path: "/repo1"),
            createMockRepoRow(id: id2, path: "/repo2")
        ]

        let results = try await databaseService.listActiveRepoRecords(limit: 50)

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(databaseAuthority.lastQuery.contains("WHERE is_active = 1"))
        XCTAssertTrue(databaseAuthority.lastQuery.contains("ORDER BY last_activity_at DESC"))
    }

    func testDeactivateRepoRecord() async throws {
        let testId = UUID()

        try await databaseService.deactivateRepoRecord(id: testId)

        XCTAssertEqual(databaseAuthority.mutationHistory.count, 1)
        let mutation = databaseAuthority.mutationHistory.first
        XCTAssertTrue(mutation!.sql.contains("SET is_active = 0"))
    }

    // MARK: - WorkspaceState Tests

    func testSaveWorkspaceState() async throws {
        let repoId = UUID()
        let state = WorkspaceState(
            repoId: repoId,
            filePath: "src/main.swift",
            cursorLine: 42,
            cursorColumn: 10
        )

        try await databaseService.saveWorkspaceState(state)

        XCTAssertEqual(databaseAuthority.mutationHistory.count, 1)
        let mutation = databaseAuthority.mutationHistory.first
        XCTAssertTrue(mutation!.sql.contains("INSERT OR REPLACE INTO developum_workspace_states"))
        XCTAssertEqual(mutation!.parameters.count, 15)
    }

    func testGetWorkspaceStates() async throws {
        let repoId = UUID()
        databaseAuthority.queryResult = [
            createMockWorkspaceRow(repoId: repoId, filePath: "file1.swift"),
            createMockWorkspaceRow(repoId: repoId, filePath: "file2.swift")
        ]

        let results = try await databaseService.getWorkspaceStates(repoId: repoId)

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(databaseAuthority.lastQuery.contains("WHERE repo_id = ?"))
        XCTAssertTrue(databaseAuthority.lastQuery.contains("ORDER BY updated_at DESC"))
    }

    func testGetWorkspaceStateByFilePath() async throws {
        let repoId = UUID()
        let filePath = "src/main.swift"
        databaseAuthority.queryResult = [createMockWorkspaceRow(repoId: repoId, filePath: filePath)]

        let result = try await databaseService.getWorkspaceState(repoId: repoId, filePath: filePath)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.filePath, filePath)
        XCTAssertTrue(databaseAuthority.lastQuery.contains("WHERE repo_id = ? AND file_path = ?"))
    }

    func testGetWorkspaceStateNotFound() async throws {
        databaseAuthority.queryResult = []

        let result = try await databaseService.getWorkspaceState(repoId: UUID(), filePath: "missing.swift")

        XCTAssertNil(result)
    }

    func testCloseWorkspaceState() async throws {
        let repoId = UUID()
        let filePath = "src/main.swift"

        try await databaseService.closeWorkspaceState(repoId: repoId, filePath: filePath)

        XCTAssertEqual(databaseAuthority.mutationHistory.count, 1)
        let mutation = databaseAuthority.mutationHistory.first
        XCTAssertTrue(mutation!.sql.contains("SET is_open = 0"))
        XCTAssertTrue(mutation!.sql.contains("WHERE repo_id = ? AND file_path = ?"))
    }

    func testDeleteWorkspaceStates() async throws {
        let repoId = UUID()

        try await databaseService.deleteWorkspaceStates(repoId: repoId)

        XCTAssertEqual(databaseAuthority.mutationHistory.count, 1)
        let mutation = databaseAuthority.mutationHistory.first
        XCTAssertTrue(mutation!.sql.contains("DELETE FROM developum_workspace_states"))
        XCTAssertTrue(mutation!.sql.contains("WHERE repo_id = ?"))
    }

    // MARK: - IndexArtifactRecord Tests

    func testSaveIndexArtifact() async throws {
        let repoId = UUID()
        let artifact = IndexArtifactRecord(
            repoId: repoId,
            artifactHash: "sha256:abc123",
            filePath: "src/utils.swift",
            mimeType: "text/x-swift",
            languageId: "swift",
            fileSize: 1024,
            indexContent: "{\"tokens\": []}".data(using: .utf8)!
        )

        try await databaseService.saveIndexArtifact(artifact)

        XCTAssertEqual(databaseAuthority.mutationHistory.count, 1)
        let mutation = databaseAuthority.mutationHistory.first
        XCTAssertTrue(mutation!.sql.contains("INSERT OR REPLACE INTO developum_index_artifacts"))
        XCTAssertEqual(mutation!.parameters.count, 11)
    }

    func testGetIndexArtifacts() async throws {
        let repoId = UUID()
        databaseAuthority.queryResult = [
            createMockIndexRow(repoId: repoId, filePath: "file1.swift"),
            createMockIndexRow(repoId: repoId, filePath: "file2.swift")
        ]

        let results = try await databaseService.getIndexArtifacts(repoId: repoId)

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(databaseAuthority.lastQuery.contains("WHERE repo_id = ?"))
    }

    func testGetIndexArtifactsWithFilePath() async throws {
        let repoId = UUID()
        let filePath = "src/main.swift"
        databaseAuthority.queryResult = [createMockIndexRow(repoId: repoId, filePath: filePath)]

        let results = try await databaseService.getIndexArtifacts(repoId: repoId, filePath: filePath)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(databaseAuthority.lastQuery.contains("AND file_path = ?"))
    }

    func testMarkIndexArtifactsStale() async throws {
        let repoId = UUID()
        let filePath = "src/main.swift"

        try await databaseService.markIndexArtifactsStale(repoId: repoId, filePath: filePath)

        XCTAssertEqual(databaseAuthority.mutationHistory.count, 1)
        let mutation = databaseAuthority.mutationHistory.first
        XCTAssertTrue(mutation!.sql.contains("SET is_current = 0"))
        XCTAssertTrue(mutation!.sql.contains("WHERE repo_id = ? AND file_path = ?"))
    }

    func testDeleteStaleIndexArtifacts() async throws {
        let cutoffDate = Date().addingTimeInterval(-86400)

        try await databaseService.deleteStaleIndexArtifacts(olderThan: cutoffDate)

        XCTAssertEqual(databaseAuthority.mutationHistory.count, 1)
        let mutation = databaseAuthority.mutationHistory.first
        XCTAssertTrue(mutation!.sql.contains("DELETE FROM developum_index_artifacts"))
        XCTAssertTrue(mutation!.sql.contains("is_current = 0"))
        XCTAssertTrue(mutation!.sql.contains("indexed_at < ?"))
    }

    // MARK: - BridgeEvent Tests

    func testRecordBridgeEvent() async throws {
        let repoId = UUID()
        let messageBody = "{\"test\": true}".data(using: .utf8)!

        try await databaseService.recordBridgeEvent(
            repoId: repoId,
            sessionId: "session123",
            messageType: "searchRequest",
            messageHash: "hash456",
            messageBody: messageBody
        )

        XCTAssertEqual(databaseAuthority.mutationHistory.count, 1)
        let mutation = databaseAuthority.mutationHistory.first
        XCTAssertTrue(mutation!.sql.contains("INSERT INTO developum_bridge_events"))
    }

    func testGetBridgeEvents() async throws {
        let sessionId = "session123"
        databaseAuthority.queryResult = [createMockBridgeRow(sessionId: sessionId)]

        let results = try await databaseService.getBridgeEvents(sessionId: sessionId, limit: 50)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(databaseAuthority.lastQuery.contains("WHERE session_id = ?"))
        XCTAssertTrue(databaseAuthority.lastQuery.contains("ORDER BY timestamp DESC"))
        XCTAssertTrue(databaseAuthority.lastQuery.contains("LIMIT ?"))
    }

    // MARK: - Error Handling

    func testGetRepoRecordWithInvalidId() async throws {
        databaseAuthority.shouldThrowError = true
        databaseAuthority.errorToThrow = DatabaseError.queryError("Invalid UUID")

        do {
            _ = try await databaseService.getRepoRecord(id: UUID())
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(error as? DatabaseError, .queryError("Invalid UUID"))
        }
    }

    func testCreateRepoRecordWithInvalidData() async throws {
        databaseAuthority.shouldThrowError = true
        databaseAuthority.errorToThrow = DatabaseError.mutationError("Constraint violation")

        let record = RepoRecord(repoPath: "/test")

        do {
            try await databaseService.createRepoRecord(record)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(error as? DatabaseError, .mutationError("Constraint violation"))
        }
    }

    // MARK: - Mock Helpers

    private func createMockRepoRow(id: UUID, path: String = "/test/repo") -> DatabaseRow {
        var row = DatabaseRow()
        row["id"] = .text(id.uuidString)
        row["repo_path"] = .text(path)
        row["remote_url"] = .text("https://github.com/test/repo.git")
        row["current_branch"] = .text("main")
        row["head_sha"] = .text("abc123")
        row["created_at"] = .double(Date().timeIntervalSince1970 * 1000)
        row["last_activity_at"] = .double(Date().timeIntervalSince1970 * 1000)
        row["is_active"] = .int(1)
        row["workspace_config"] = .null
        row["metadata"] = .null
        return row
    }

    private func createMockWorkspaceRow(repoId: UUID, filePath: String) -> DatabaseRow {
        var row = DatabaseRow()
        row["id"] = .text(UUID().uuidString)
        row["repo_id"] = .text(repoId.uuidString)
        row["file_path"] = .text(filePath)
        row["cursor_line"] = .int(10)
        row["cursor_column"] = .int(5)
        row["selection_start_line"] = .null
        row["selection_start_column"] = .null
        row["selection_end_line"] = .null
        row["selection_end_column"] = .null
        row["viewport_top_line"] = .null
        row["viewport_bottom_line"] = .null
        row["is_open"] = .int(1)
        row["has_unsaved_changes"] = .int(0)
        row["updated_at"] = .double(Date().timeIntervalSince1970 * 1000)
        row["editor_state"] = .null
        return row
    }

    private func createMockIndexRow(repoId: UUID, filePath: String) -> DatabaseRow {
        var row = DatabaseRow()
        row["id"] = .text(UUID().uuidString)
        row["repo_id"] = .text(repoId.uuidString)
        row["artifact_hash"] = .text("sha256:test")
        row["file_path"] = .text(filePath)
        row["mime_type"] = .text("text/x-swift")
        row["language_id"] = .text("swift")
        row["file_size"] = .int64(1024)
        row["file_modified_at"] = .double(Date().timeIntervalSince1970 * 1000)
        row["indexed_at"] = .double(Date().timeIntervalSince1970 * 1000)
        row["index_content"] = .blob("{}".data(using: .utf8)!)
        row["is_current"] = .int(1)
        return row
    }

    private func createMockBridgeRow(sessionId: String) -> DatabaseRow {
        var row = DatabaseRow()
        row["id"] = .text(UUID().uuidString)
        row["repo_id"] = .text(UUID().uuidString)
        row["session_id"] = .text(sessionId)
        row["message_type"] = .text("searchRequest")
        row["message_hash"] = .text("hash123")
        row["message_body"] = .blob("{}".data(using: .utf8)!)
        row["timestamp"] = .double(Date().timeIntervalSince1970 * 1000)
        row["receipt_hash"] = .null
        row["artifact_hash"] = .null
        return row
    }
}

// MARK: - Mock Database Authority

final class MockDatabaseAuthority: DatabaseAuthority {
    var mutationHistory: [DatabaseMutation] = []
    var lastQuery: String = ""
    var queryResult: [DatabaseRow] = []
    var shouldThrowError = false
    var errorToThrow: Error?

    func query(_ sql: String, parameters: [DatabaseParameter]) async throws -> [DatabaseRow] {
        if shouldThrowError {
            throw errorToThrow ?? DatabaseError.queryError("Mock error")
        }
        lastQuery = sql
        return queryResult
    }

    func mutate(_ mutation: DatabaseMutation, context: ExecutionContext) async throws -> Int {
        if shouldThrowError {
            throw errorToThrow ?? DatabaseError.mutationError("Mock error")
        }
        mutationHistory.append(mutation)
        return 1
    }
}

// MARK: - DatabaseRow Extension for Mock

extension DatabaseRow {
    subscript(key: String) -> DatabaseValue {
        get {
            return values[key] ?? .null
        }
        set {
            values[key] = newValue
        }
    }

    private var values: [String: DatabaseValue] = [:]

    func string(for column: String) -> String? {
        guard case .text(let value) = values[column] else { return nil }
        return value
    }

    func int(for column: String) -> Int? {
        guard case .int(let value) = values[column] else { return nil }
        return value
    }

    func int64(for column: String) -> Int64? {
        guard case .int64(let value) = values[column] else { return nil }
        return value
    }

    func double(for column: String) -> Double? {
        guard case .double(let value) = values[column] else { return nil }
        return value
    }

    func data(for column: String) -> Data? {
        guard case .blob(let value) = values[column] else { return nil }
        return value
    }
}
