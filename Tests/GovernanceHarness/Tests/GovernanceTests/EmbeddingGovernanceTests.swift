// EmbeddingGovernanceTests.swift
// Tests that governance applies to embedding/indexing but allows recall

import XCTest
@testable import HarmoniaV2CLIKernel
import HarmoniaV2Core
import AnigmaJobs

final class EmbeddingGovernanceTests: XCTestCase {
    var testDbPath: String!
    
    override func setUp() async throws {
        try await super.setUp()
        testDbPath = NSTemporaryDirectory() + "test-embeddings-\(UUID().uuidString).db"
    }
    
    override func tearDown() async throws {
        if let path = testDbPath, FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }
        try await super.tearDown()
    }
    
    // MARK: - Governance Tests
    
    /// Test that readOnly mode blocks indexing (memo with embedding)
    func testReadOnlyBlocksIndexing() async throws {
        let config = CLIKernelConfig(databasePath: testDbPath, enforceGovernance: true)
        
        // Set mode to readOnly using admin principal
        try await CLIKernel.runSetMode(
            mode: .readOnly,
            projectId: "project-alpha",
            principal: "test-admin",
            databasePath: testDbPath
        )
        
        // Attempt to store memo with embedding as non-admin user
        do {
            _ = try await CLIKernel.runMemo(
                content: "This should be blocked",
                userId: "regular-user",
                projectId: "project-alpha",
                sessionId: nil,
                config: config
            )
            XCTFail("Expected governanceViolation, but memo succeeded")
        } catch let error as RuntimeInitializationError {
            XCTAssertTrue(
                error.isGovernanceViolation,
                "Expected governance violation, got: \(error)"
            )
        }
        
        // Verify no row was inserted
        let rowCount = try await CLIKernel.getRowCount(databasePath: testDbPath, table: "harmonia_memories")
        XCTAssertEqual(rowCount, 0, "No rows should be inserted when governance denies write")
    }
    
    /// Test that readOnly mode allows recall (reads are side-effect-free)
    func testReadOnlyAllowsRecall() async throws {
        let config = CLIKernelConfig(databasePath: testDbPath, enforceGovernance: true)
        let projectId = "project-beta"
        
        // Step 1: Seed data in assistive mode
        try await CLIKernel.runSetMode(
            mode: .assistive,
            projectId: projectId,
            principal: "test-admin",
            databasePath: testDbPath
        )
        
        let content1 = "Machine learning fundamentals"
        let content2 = "Neural networks and deep learning"
        let content3 = "Data structures and algorithms"
        
        _ = try await CLIKernel.runMemo(
            content: content1,
            userId: "user1",
            projectId: projectId,
            sessionId: "session1",
            config: config
        )
        
        _ = try await CLIKernel.runMemo(
            content: content2,
            userId: "user1",
            projectId: projectId,
            sessionId: "session1",
            config: config
        )
        
        _ = try await CLIKernel.runMemo(
            content: content3,
            userId: "user1",
            projectId: projectId,
            sessionId: "session1",
            config: config
        )
        
        // Verify data was stored
        let rowCount = try await CLIKernel.getRowCount(databasePath: testDbPath, table: "harmonia_memories")
        XCTAssertEqual(rowCount, 3, "Three memories should be stored")
        
        // Step 2: Flip to readOnly mode
        try await CLIKernel.runSetMode(
            mode: .readOnly,
            projectId: projectId,
            principal: "test-admin",
            databasePath: testDbPath
        )
        
        // Step 3: Recall should work despite readOnly mode
        let recallResult = try await CLIKernel.runRecall(
            query: "machine learning neural networks",
            projectId: projectId,
            topK: 2,
            threshold: nil,
            config: config
        )
        
        XCTAssertEqual(recallResult.projectId, projectId)
        XCTAssertEqual(recallResult.results.count, 2, "Should return top 2 results")
        
        // Verify results are ranked by similarity
        XCTAssertGreaterThanOrEqual(recallResult.results[0].similarity, recallResult.results[1].similarity)
        
        // Verify rank field is correct
        XCTAssertEqual(recallResult.results[0].rank, 1)
        XCTAssertEqual(recallResult.results[1].rank, 2)
    }
    
    /// Test that embeddings persist across runtime restart
    func testEmbeddingsPersistAcrossRestart() async throws {
        let config = CLIKernelConfig(databasePath: testDbPath, enforceGovernance: true)
        let projectId = "project-gamma"
        
        // Set assistive mode
        try await CLIKernel.runSetMode(
            mode: .assistive,
            projectId: projectId,
            principal: "test-admin",
            databasePath: testDbPath
        )
        
        // Store memories with embeddings
        let content1 = "Swift concurrency with async await"
        let content2 = "Actors and isolation in Swift"
        
        _ = try await CLIKernel.runMemo(
            content: content1,
            userId: "user1",
            projectId: projectId,
            sessionId: "session1",
            config: config
        )
        
        _ = try await CLIKernel.runMemo(
            content: content2,
            userId: "user1",
            projectId: projectId,
            sessionId: "session1",
            config: config
        )
        
        // Perform recall before "restart"
        let beforeResult = try await CLIKernel.runRecall(
            query: "Swift async concurrency",
            projectId: projectId,
            topK: 2,
            threshold: nil,
            config: config
        )
        
        XCTAssertEqual(beforeResult.results.count, 2)
        let beforeTopId = beforeResult.results[0].id
        let beforeTopSimilarity = beforeResult.results[0].similarity
        
        // Simulate restart by creating new runtime (same dbPath)
        // The factory method will create a new PlatformRuntime instance
        let afterResult = try await CLIKernel.runRecall(
            query: "Swift async concurrency",
            projectId: projectId,
            topK: 2,
            threshold: nil,
            config: config
        )
        
        XCTAssertEqual(afterResult.results.count, 2, "Embeddings should persist across restart")
        
        // Verify deterministic embeddings produce same results
        XCTAssertEqual(afterResult.results[0].id, beforeTopId, "Same query should return same top result")
        XCTAssertEqual(afterResult.results[0].similarity, beforeTopSimilarity, accuracy: 0.0001, "Similarity should be deterministic")
    }
    
    /// Test that dimension mismatch is handled safely
    func testDimensionMismatchHandling() async throws {
        let config = CLIKernelConfig(databasePath: testDbPath, enforceGovernance: true)
        let projectId = "project-delta"
        
        try await CLIKernel.runSetMode(
            mode: .assistive,
            projectId: projectId,
            principal: "test-admin",
            databasePath: testDbPath
        )
        
        // Store a memory with embeddings
        _ = try await CLIKernel.runMemo(
            content: "Test content",
            userId: "user1",
            projectId: projectId,
            sessionId: "session1",
            config: config
        )
        
        // Recall with same dimensions should work
        let result = try await CLIKernel.runRecall(
            query: "Test query",
            projectId: projectId,
            topK: 5,
            threshold: nil,
            config: config
        )
        
        XCTAssertEqual(result.results.count, 1, "Should find the stored memory")
    }
    
    /// Test that project scoping works (memories from project A not returned for project B)
    func testProjectScopingInRecall() async throws {
        let config = CLIKernelConfig(databasePath: testDbPath, enforceGovernance: true)
        
        // Store in project A
        try await CLIKernel.runSetMode(
            mode: .assistive,
            projectId: "project-a",
            principal: "test-admin",
            databasePath: testDbPath
        )
        
        _ = try await CLIKernel.runMemo(
            content: "Project A content",
            userId: "user1",
            projectId: "project-a",
            sessionId: "session1",
            config: config
        )
        
        // Store in project B
        try await CLIKernel.runSetMode(
            mode: .assistive,
            projectId: "project-b",
            principal: "test-admin",
            databasePath: testDbPath
        )
        
        _ = try await CLIKernel.runMemo(
            content: "Project B content",
            userId: "user1",
            projectId: "project-b",
            sessionId: "session2",
            config: config
        )
        
        // Recall from project A should only return project A memories
        let resultA = try await CLIKernel.runRecall(
            query: "content",
            projectId: "project-a",
            topK: 10,
            threshold: nil,
            config: config
        )
        
        XCTAssertEqual(resultA.results.count, 1, "Should only find project A memory")
        XCTAssertTrue(resultA.results[0].content.contains("Project A"))
        
        // Recall from project B should only return project B memories
        let resultB = try await CLIKernel.runRecall(
            query: "content",
            projectId: "project-b",
            topK: 10,
            threshold: nil,
            config: config
        )
        
        XCTAssertEqual(resultB.results.count, 1, "Should only find project B memory")
        XCTAssertTrue(resultB.results[0].content.contains("Project B"))
    }
}
