//
//  DevelopumWorkflowsTests.swift
//  DevelopumModuleTests
//
//  Tests for DevelopumModule workflow execution.
//

import XCTest
import AnigmaCore
@testable import DevelopumModule

final class DevelopumWorkflowsTests: XCTestCase {

    private var world: World!
    private var mockDatabaseService: MockDevelopumDatabaseService!
    private var governance: GovernanceController!

    override func setUp() {
        super.setUp()
        world = World()
        mockDatabaseService = MockDevelopumDatabaseService()
        governance = GovernanceController()
    }

    override func tearDown() {
        world = nil
        mockDatabaseService = nil
        governance = nil
        super.tearDown()
    }

    // MARK: - OpenFileWorkflow Tests

    func testOpenFileWorkflowName() {
        let workflow = OpenFileWorkflow(databaseService: mockDatabaseService)
        XCTAssertEqual(workflow.name, "Open File")
    }

    func testOpenFileWorkflowJobTypeId() {
        let workflow = OpenFileWorkflow(databaseService: mockDatabaseService)
        XCTAssertEqual(workflow.jobTypeId, OpenFileJobType.identifier)
    }

    func testOpenFileWorkflowSystemNames() {
        let workflow = OpenFileWorkflow(databaseService: mockDatabaseService)
        XCTAssertEqual(workflow.systemNames, ["DevelopumEditorSystem"])
    }

    func testOpenFileWorkflowPrepareMissingRepoId() async {
        let workflow = OpenFileWorkflow(databaseService: mockDatabaseService)
        let job = Job(
            typeId: OpenFileJobType.identifier,
            metadata: ["filePath": "test.swift"]
        )

        do {
            try await workflow.prepare(job: job, world: world)
            XCTFail("Should throw error for missing repoId")
        } catch let error as WorkflowError {
            XCTAssertTrue(error.message.contains("Repository session not found"))
        }
    }

    func testOpenFileWorkflowPrepareMissingFilePath() async {
        let workflow = OpenFileWorkflow(databaseService: mockDatabaseService)
        let job = Job(
            typeId: OpenFileJobType.identifier,
            metadata: ["repoId": UUID().uuidString]
        )

        do {
            try await workflow.prepare(job: job, world: world)
            XCTFail("Should throw error for missing filePath")
        } catch let error as WorkflowError {
            XCTAssertTrue(error.message.contains("Missing filePath"))
        }
    }

    func testOpenFileWorkflowPrepareFileNotFound() async {
        let repoId = UUID()
        mockDatabaseService.getRepoResult = RepoRecord(repoPath: "/nonexistent/repo")

        let workflow = OpenFileWorkflow(databaseService: mockDatabaseService)
        let job = Job(
            typeId: OpenFileJobType.identifier,
            metadata: [
                "repoId": repoId.uuidString,
                "filePath": "missing.swift"
            ]
        )

        do {
            try await workflow.prepare(job: job, world: world)
            XCTFail("Should throw error for missing file")
        } catch let error as WorkflowError {
            XCTAssertTrue(error.message.contains("File not found"))
        }
    }

    func testOpenFileWorkflowFinalizeSuccess() async {
        let workflow = OpenFileWorkflow(databaseService: mockDatabaseService)
        let result = JobResult(outcome: .success, actionsApplied: 5)

        try? await workflow.finalize(
            job: Job(typeId: OpenFileJobType.identifier, metadata: ["filePath": "test.swift"]),
            world: world,
            result: result
        )
    }

    func testOpenFileWorkflowFinalizeError() async {
        let workflow = OpenFileWorkflow(databaseService: mockDatabaseService)
        let result = JobResult(outcome: .error, errorMessage: "Failed")

        try? await workflow.finalize(
            job: Job(typeId: OpenFileJobType.identifier, metadata: ["filePath": "test.swift"]),
            world: world,
            result: result
        )
    }

    // MARK: - SaveFileWorkflow Tests

    func testSaveFileWorkflowName() {
        let workflow = SaveFileWorkflow(databaseService: mockDatabaseService)
        XCTAssertEqual(workflow.name, "Save File")
    }

    func testSaveFileWorkflowJobTypeId() {
        let workflow = SaveFileWorkflow(databaseService: mockDatabaseService)
        XCTAssertEqual(workflow.jobTypeId, SaveFileJobType.identifier)
    }

    func testSaveFileWorkflowSystemNames() {
        let workflow = SaveFileWorkflow(databaseService: mockDatabaseService)
        XCTAssertEqual(workflow.systemNames, ["DevelopumEditorSystem"])
    }

    func testSaveFileWorkflowPrepareMissingContentHash() async {
        let workflow = SaveFileWorkflow(databaseService: mockDatabaseService)
        let job = Job(
            typeId: SaveFileJobType.identifier,
            metadata: [
                "repoId": UUID().uuidString,
                "filePath": "test.swift"
            ]
        )

        do {
            try await workflow.prepare(job: job, world: world)
            XCTFail("Should throw error for missing contentHash")
        } catch let error as WorkflowError {
            XCTAssertTrue(error.message.contains("Missing contentHash"))
        }
    }

    // MARK: - SearchFilesWorkflow Tests

    func testSearchFilesWorkflowName() {
        let workflow = SearchFilesWorkflow(databaseService: mockDatabaseService)
        XCTAssertEqual(workflow.name, "Search Files")
    }

    func testSearchFilesWorkflowJobTypeId() {
        let workflow = SearchFilesWorkflow(databaseService: mockDatabaseService)
        XCTAssertEqual(workflow.jobTypeId, SearchFilesJobType.identifier)
    }

    func testSearchFilesWorkflowSystemNames() {
        let workflow = SearchFilesWorkflow(databaseService: mockDatabaseService)
        XCTAssertEqual(workflow.systemNames, ["DevelopumEditorSystem", "DevelopumIndexSystem"])
    }

    func testSearchFilesWorkflowPrepareEmptyQuery() async {
        let workflow = SearchFilesWorkflow(databaseService: mockDatabaseService)
        let job = Job(
            typeId: SearchFilesJobType.identifier,
            metadata: [
                "repoId": UUID().uuidString,
                "query": ""
            ]
        )

        do {
            try await workflow.prepare(job: job, world: world)
            XCTFail("Should throw error for empty query")
        } catch let error as WorkflowError {
            XCTAssertTrue(error.message.contains("Search query cannot be empty"))
        }
    }

    func testSearchFilesWorkflowPrepareValidQuery() async {
        mockDatabaseService.getRepoResult = RepoRecord(repoPath: "/test/repo")

        let workflow = SearchFilesWorkflow(databaseService: mockDatabaseService)
        let job = Job(
            typeId: SearchFilesJobType.identifier,
            metadata: [
                "repoId": UUID().uuidString,
                "query": "func.*test"
            ]
        )

        try? await workflow.prepare(job: job, world: world)
    }

    // MARK: - IndexFileWorkflow Tests

    func testIndexFileWorkflowName() {
        let workflow = IndexFileWorkflow(databaseService: mockDatabaseService)
        XCTAssertEqual(workflow.name, "Index File")
    }

    func testIndexFileWorkflowJobTypeId() {
        let workflow = IndexFileWorkflow(databaseService: mockDatabaseService)
        XCTAssertEqual(workflow.jobTypeId, IndexFileJobType.identifier)
    }

    func testIndexFileWorkflowSystemNames() {
        let workflow = IndexFileWorkflow(databaseService: mockDatabaseService)
        XCTAssertEqual(workflow.systemNames, ["DevelopumIndexSystem"])
    }

    // MARK: - CreateRepoSessionWorkflow Tests

    func testCreateRepoSessionWorkflowName() {
        let workflow = CreateRepoSessionWorkflow(databaseService: mockDatabaseService)
        XCTAssertEqual(workflow.name, "Create Repository Session")
    }

    func testCreateRepoSessionWorkflowJobTypeId() {
        let workflow = CreateRepoSessionWorkflow(databaseService: mockDatabaseService)
        XCTAssertEqual(workflow.jobTypeId, CreateRepoSessionJobType.identifier)
    }

    func testCreateRepoSessionWorkflowSystemNames() {
        let workflow = CreateRepoSessionWorkflow(databaseService: mockDatabaseService)
        XCTAssertEqual(workflow.systemNames, ["DevelopumEditorSystem"])
    }

    func testCreateRepoSessionWorkflowPrepareMissingRepoPath() async {
        let workflow = CreateRepoSessionWorkflow(databaseService: mockDatabaseService)
        let job = Job(typeId: CreateRepoSessionJobType.identifier, metadata: [:])

        do {
            try await workflow.prepare(job: job, world: world)
            XCTFail("Should throw error for missing repoPath")
        } catch let error as WorkflowError {
            XCTAssertTrue(error.message.contains("Missing repoPath"))
        }
    }

    func testCreateRepoSessionWorkflowPreparePathNotExists() async {
        let workflow = CreateRepoSessionWorkflow(databaseService: mockDatabaseService)
        let job = Job(
            typeId: CreateRepoSessionJobType.identifier,
            metadata: ["repoPath": "/nonexistent/path"]
        )

        do {
            try await workflow.prepare(job: job, world: world)
            XCTFail("Should throw error for non-existent path")
        } catch let error as WorkflowError {
            XCTAssertTrue(error.message.contains("Repository path does not exist"))
        }
    }

    // MARK: - CloseRepoSessionWorkflow Tests

    func testCloseRepoSessionWorkflowName() {
        let workflow = CloseRepoSessionWorkflow(databaseService: mockDatabaseService)
        XCTAssertEqual(workflow.name, "Close Repository Session")
    }

    func testCloseRepoSessionWorkflowJobTypeId() {
        let workflow = CloseRepoSessionWorkflow(databaseService: mockDatabaseService)
        XCTAssertEqual(workflow.jobTypeId, CloseRepoSessionJobType.identifier)
    }

    func testCloseRepoSessionWorkflowSystemNames() {
        let workflow = CloseRepoSessionWorkflow(databaseService: mockDatabaseService)
        XCTAssertEqual(workflow.systemNames, ["DevelopumEditorSystem"])
    }

    func testCloseRepoSessionWorkflowPrepareInvalidRepoId() async {
        let workflow = CloseRepoSessionWorkflow(databaseService: mockDatabaseService)
        let job = Job(
            typeId: CloseRepoSessionJobType.identifier,
            metadata: ["repoId": "not-a-uuid"]
        )

        do {
            try await workflow.prepare(job: job, world: world)
            XCTFail("Should throw error for invalid repoId")
        } catch let error as WorkflowError {
            XCTAssertTrue(error.message.contains("Invalid or missing repoId"))
        }
    }

    func testCloseRepoSessionWorkflowPrepareRepoNotFound() async {
        mockDatabaseService.getRepoResult = nil

        let workflow = CloseRepoSessionWorkflow(databaseService: mockDatabaseService)
        let job = Job(
            typeId: CloseRepoSessionJobType.identifier,
            metadata: ["repoId": UUID().uuidString]
        )

        do {
            try await workflow.prepare(job: job, world: world)
            XCTFail("Should throw error for repo not found")
        } catch let error as WorkflowError {
            XCTAssertTrue(error.message.contains("Repository session not found"))
        }
    }

    func testCloseRepoSessionWorkflowPrepareValid() async {
        mockDatabaseService.getRepoResult = RepoRecord(repoPath: "/test/repo")

        let workflow = CloseRepoSessionWorkflow(databaseService: mockDatabaseService)
        let job = Job(
            typeId: CloseRepoSessionJobType.identifier,
            metadata: [
                "repoId": UUID().uuidString,
                "saveUnsavedChanges": "true"
            ]
        )

        try? await workflow.prepare(job: job, world: world)
    }

    // MARK: - Job Type Identifiers

    func testJobTypeIdentifiers() {
        XCTAssertEqual(OpenFileJobType.identifier, "developum.openFile")
        XCTAssertEqual(SaveFileJobType.identifier, "developum.saveFile")
        XCTAssertEqual(SearchFilesJobType.identifier, "developum.searchFiles")
        XCTAssertEqual(IndexFileJobType.identifier, "developum.indexFile")
        XCTAssertEqual(CreateRepoSessionJobType.identifier, "developum.createRepoSession")
        XCTAssertEqual(CloseRepoSessionJobType.identifier, "developum.closeRepoSession")
    }
}

// MARK: - Mock Database Service

final class MockDevelopumDatabaseService {
    var getRepoResult: RepoRecord?
    var createdRecords: [RepoRecord] = []
    var deactivatedRepoIds: [UUID] = []

    func getRepoRecord(id: UUID) async throws -> RepoRecord? {
        return getRepoResult
    }

    func getRepoRecord(path: String) async throws -> RepoRecord? {
        return getRepoResult
    }

    func createRepoRecord(_ record: RepoRecord) async throws {
        createdRecords.append(record)
    }

    func deactivateRepoRecord(id: UUID) async throws {
        deactivatedRepoIds.append(id)
    }
}

// MARK: - Job Type Definitions

struct OpenFileJobType: JobType {
    static let identifier = "developum.openFile"
}

struct SaveFileJobType: JobType {
    static let identifier = "developum.saveFile"
}

struct SearchFilesJobType: JobType {
    static let identifier = "developum.searchFiles"
}

struct IndexFileJobType: JobType {
    static let identifier = "developum.indexFile"
}

struct CreateRepoSessionJobType: JobType {
    static let identifier = "developum.createRepoSession"
}

struct CloseRepoSessionJobType: JobType {
    static let identifier = "developum.closeRepoSession"
}

// MARK: - Job Result

struct JobResult: Sendable {
    let outcome: Outcome
    var actionsApplied: Int = 0
    var errorMessage: String?

    enum Outcome: String, Sendable {
        case success
        case failure
        case error
        case partial
    }
}

// MARK: - Workflow Error

struct WorkflowError: Error, Sendable {
    let workflow: String
    let message: String

    static func executionFailed(workflow: String, error: String) -> WorkflowError {
        WorkflowError(workflow: workflow, message: error)
    }
}
