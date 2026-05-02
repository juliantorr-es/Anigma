// ChunkGovernanceTests.swift
// Tests that governance applies to chunk indexing but allows recall

import XCTest
@testable import HarmoniaV2CLIKernel
import HarmoniaV2Core
import AnigmaJobs

final class ChunkGovernanceTests: XCTestCase {
    var testDbPath: String!
    
    override func setUp() async throws {
        try await super.setUp()
        testDbPath = NSTemporaryDirectory() + "test-chunks-\(UUID().uuidString).db"
    }
    
    override func tearDown() async throws {
        if let path = testDbPath, FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }
        try await super.tearDown()
    }
    
    // MARK: - Chunk Governance Tests
    
    /// Test that readOnly mode blocks chunk indexing
    func testReadOnlyBlocksChunkIndexing() async throws {
        let config = CLIKernelConfig(databasePath: testDbPath, enforceGovernance: true)
        let projectId = "project-chunk-alpha"
        
        // Set mode to readOnly
        try await CLIKernel.runSetMode(
            mode: .readOnly,
            projectId: projectId,
            principal: "test-admin",
            databasePath: testDbPath
        )
        
        let content = """
        func calculateFibonacci(_ n: Int) -> Int {
            if n <= 1 { return n }
            return calculateFibonacci(n - 1) + calculateFibonacci(n - 2)
        }
        """
        
        // Attempt to index chunks
        do {
            _ = try await CLIKernel.runIndexChunks(
                content: content,
                filePath: "/Sources/Algo.swift",
                projectId: projectId,
                userId: "regular-user",
                config: config
            )
            XCTFail("Expected governanceViolation, but chunk indexing succeeded")
        } catch let error as RuntimeInitializationError {
            XCTAssertTrue(
                error.isGovernanceViolation,
                "Expected governance violation, got: \(error)"
            )
        }
        
        // Verify no chunks stored
        let rowCount = try await CLIKernel.getRowCount(databasePath: testDbPath, table: "harmonia_chunks")
        XCTAssertEqual(rowCount, 0, "No chunks should be stored")
    }
    
    /// Test that readOnly mode allows chunk recall
    func testReadOnlyAllowsChunkRecall() async throws {
        let config = CLIKernelConfig(databasePath: testDbPath, enforceGovernance: true)
        let projectId = "project-chunk-beta"
        
        // Set assistive mode
        try await CLIKernel.runSetMode(
            mode: .assistive,
            projectId: projectId,
            principal: "test-admin",
            databasePath: testDbPath
        )
        
        let content = """
        func binarySearch<T: Comparable>(_ array: [T], key: T) -> Int? {
            var lower = 0
            var upper = array.count
            while lower < upper {
                let mid = lower + (upper - lower) / 2
                if array[mid] == key { return mid }
                else if array[mid] < key { lower = mid + 1 }
                else { upper = mid }
            }
            return nil
        }
        """
        
        // Index chunks
        let indexResult = try await CLIKernel.runIndexChunks(
            content: content,
            filePath: "/Sources/Search.swift",
            projectId: projectId,
            userId: "user1",
            config: config
        )
        
        XCTAssertGreaterThan(indexResult.count, 0, "Should have indexed chunks")
        
        // Flip to readOnly
        try await CLIKernel.runSetMode(
            mode: .readOnly,
            projectId: projectId,
            principal: "test-admin",
            databasePath: testDbPath
        )
        
        // Recall chunks
        let recallResult = try await CLIKernel.runRecallChunks(
            query: "binary search algorithm",
            projectId: projectId,
            topK: 5,
            config: config
        )
        
        XCTAssertEqual(recallResult.results.count, 1, "Should find binary search chunk")
        XCTAssertTrue(recallResult.results[0].content.contains("binarySearch"))
        XCTAssertEqual(recallResult.results[0].filePath, "/Sources/Search.swift")
    }
    
    /// Test chunking determinism and persistence
    func testChunkPersistenceAndDeterminism() async throws {
        let config = CLIKernelConfig(databasePath: testDbPath, enforceGovernance: true)
        let projectId = "project-chunk-gamma"
        
        try await CLIKernel.runSetMode(
            mode: .assistive,
            projectId: projectId,
            principal: "test-admin",
            databasePath: testDbPath
        )
        
        let content = """
        struct Stack<Element> {
            private var items: [Element] = []
            mutating func push(_ item: Element) { items.append(item) }
            mutating func pop() -> Element? { return items.popLast() }
        }
        """
        
        _ = try await CLIKernel.runIndexChunks(
            content: content,
            filePath: "/Sources/Stack.swift",
            projectId: projectId,
            userId: "user1",
            config: config
        )
        
        // Recall before restart
        let beforeResult = try await CLIKernel.runRecallChunks(
            query: "stack data structure",
            projectId: projectId,
            topK: 1,
            config: config
        )
        
        XCTAssertEqual(beforeResult.results.count, 1)
        let beforeId = beforeResult.results[0].id
        
        // Recall after "restart" (new runtime)
        let afterResult = try await CLIKernel.runRecallChunks(
            query: "stack data structure",
            projectId: projectId,
            topK: 1,
            config: config
        )
        
        XCTAssertEqual(afterResult.results.count, 1)
        XCTAssertEqual(afterResult.results[0].id, beforeId, "Chunk ID should persist")
        XCTAssertEqual(afterResult.results[0].similarity, beforeResult.results[0].similarity, accuracy: 0.0001)
    }
    
    /// Test project scoping for chunks
    func testProjectScopingForChunks() async throws {
        let config = CLIKernelConfig(databasePath: testDbPath, enforceGovernance: true)
        
        // Project A
        try await CLIKernel.runSetMode(
            mode: .assistive,
            projectId: "proj-a",
            principal: "admin",
            databasePath: testDbPath
        )
        _ = try await CLIKernel.runIndexChunks(
            content: "func projectA() {}",
            filePath: "/A.swift",
            projectId: "proj-a",
            userId: "user1",
            config: config
        )
        
        // Project B
        try await CLIKernel.runSetMode(
            mode: .assistive,
            projectId: "proj-b",
            principal: "admin",
            databasePath: testDbPath
        )
        _ = try await CLIKernel.runIndexChunks(
            content: "func projectB() {}",
            filePath: "/B.swift",
            projectId: "proj-b",
            userId: "user1",
            config: config
        )
        
        // Recall A
        let resA = try await CLIKernel.runRecallChunks(query: "func", projectId: "proj-a", config: config)
        XCTAssertEqual(resA.results.count, 1)
        XCTAssertTrue(resA.results[0].content.contains("projectA"))
        
        // Recall B
        let resB = try await CLIKernel.runRecallChunks(query: "func", projectId: "proj-b", config: config)
        XCTAssertEqual(resB.results.count, 1)
        XCTAssertTrue(resB.results[0].content.contains("projectB"))
    }
}
