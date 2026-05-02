// HybridSearchTests.swift
// Tests for Hybrid Search (Vector + FTS)

import XCTest
@testable import HarmoniaV2CLIKernel
import HarmoniaV2Core
import AnigmaJobs
import AnigmaCore
import HarmoniaV2Inference
import GovernanceCore
import DatabaseCore

final class HybridSearchTests: XCTestCase {
    var testDbPath: String!
    
    override func setUp() async throws {
        try await super.setUp()
        testDbPath = NSTemporaryDirectory() + "test-hybrid-\(UUID().uuidString).db"
    }
    
    override func tearDown() async throws {
        if let path = testDbPath, FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }
        try await super.tearDown()
    }
    
    func testHybridRecallKeywordOnly() async throws {
        let config = CLIKernelConfig(databasePath: testDbPath, enforceGovernance: false)
        let projectId = "proj-hybrid-1"
        
        // Insert "Apple Pie"
        _ = try await CLIKernel.runMemo(
            content: "Apple Pie",
            userId: "u1",
            projectId: projectId,
            sessionId: "s1",
            config: config
        )
        
        // Search "Apple"
        let result = try await CLIKernel.runHybridRecall(
            query: "Apple",
            projectId: projectId,
            topK: 5,
            config: config
        )
        
        XCTAssertEqual(result.results.count, 1)
        XCTAssertTrue(result.results[0].tags.contains("keyword"))
    }
    
    func testHybridRecallVectorOnly() async throws {
        let config = CLIKernelConfig(databasePath: testDbPath, enforceGovernance: false)
        let projectId = "proj-hybrid-2"
        
        // Access adapter directly.
        let kernelConfig = PlatformRuntime.KernelConfig(databasePath: testDbPath, enforceGovernance: false)
        let runtime = try await PlatformRuntime.makeForKernel(kernelConfig)
        let memoryStore = SimpleMemoryStoreAdapter(database: runtime.database)
        try await memoryStore.initializeSchema()
        
        // Compute embedding for "Target"
        let backend = DeterministicEmbeddingBackend(modelName: "stub", dimensions: 256)
        let engine = InferenceEngine(embeddingBackend: backend)
        // Use HarmoniaV2Core.ExecutionContext
        let context = HarmoniaV2Core.ExecutionContext(sessionId: "x")
        let embedding = try await engine.embed(text: "Target", context: context).vector
        
        // Store memory "Hidden" with embedding of "Target"
        _ = try await memoryStore.store(
            content: "Hidden Content",
            metadata: ["tenantId": projectId],
            embedding: embedding
        )
        
        // Search "Target"
        let result = try await CLIKernel.runHybridRecall(
            query: "Target",
            projectId: projectId,
            topK: 5,
            config: config
        )
        
        XCTAssertEqual(result.results.count, 1)
        XCTAssertEqual(result.results[0].content, "Hidden Content")
        XCTAssertTrue(result.results[0].tags.contains("vector"))
        XCTAssertFalse(result.results[0].tags.contains("keyword"))
    }
    
    func testHybridRecallBoth() async throws {
        let config = CLIKernelConfig(databasePath: testDbPath, enforceGovernance: false)
        let projectId = "proj-hybrid-3"
        
        _ = try await CLIKernel.runMemo(
            content: "Exact Match",
            userId: "u1",
            projectId: projectId,
            sessionId: "s1",
            config: config
        )
        
        let result = try await CLIKernel.runHybridRecall(
            query: "Exact Match",
            projectId: projectId,
            topK: 5,
            config: config
        )
        
        XCTAssertEqual(result.results.count, 1)
        let tags = result.results[0].tags
        XCTAssertTrue(tags.contains("vector"))
        XCTAssertTrue(tags.contains("keyword"))
        
        // Check new provenance fields
        XCTAssertNotNil(result.results[0].vectorRank)
        XCTAssertNotNil(result.results[0].ftsRank)
        XCTAssertNotNil(result.results[0].rrfScore)
        XCTAssertGreaterThan(result.totalTime, 0)
    }
    
    func testFTSPopulation() async throws {
        // Test that existing data is populated into FTS
        let config = CLIKernelConfig(databasePath: testDbPath, enforceGovernance: false)
        let projectId = "proj-pop"
        
        // Manually insert row into base table BEFORE FTS setup
        let kernelConfig = PlatformRuntime.KernelConfig(databasePath: testDbPath, enforceGovernance: false)
        let runtime = try await PlatformRuntime.makeForKernel(kernelConfig)
        let db = runtime.database
        
        // Use real types (now that local test types are renamed to Test...)
        let principal = Principal(id: "system", displayName: "System")
        
        let context = ExecutionContext(
            principal: principal,
            projectId: nil,
            sessionId: "setup",
            startedAt: Date(),
            metadata: [:],
            correlationId: UUID().uuidString
        )
        
        let createSQL = "CREATE TABLE IF NOT EXISTS harmonia_memories (id TEXT PRIMARY KEY, content TEXT, created_at INTEGER, project_id TEXT)"
        // Use DatabaseMutation (unqualified)
        // Check if entityId is String (it should be)
        _ = try await db.mutate(DatabaseMutation(sql: createSQL, parameters: [], componentType: "schema", entityId: ""), context: context)
        
        let insertSQL = "INSERT INTO harmonia_memories (id, content, created_at, project_id) VALUES (?, ?, ?, ?)"
        _ = try await db.mutate(DatabaseMutation(sql: insertSQL, parameters: [.text("1"), .text("Old Data"), .int(0), .text(projectId)], componentType: "x", entityId: ""), context: context)
        
        // Now run Hybrid Recall, which triggers initializeSchema -> setupFTS -> populate
        let result = try await CLIKernel.runHybridRecall(
            query: "Old",
            projectId: projectId,
            topK: 5,
            config: config
        )
        
        XCTAssertEqual(result.results.count, 1)
        XCTAssertEqual(result.results[0].content, "Old Data")
        XCTAssertTrue(result.results[0].tags.contains("keyword"))
    }
    
    func testRebuildFTS() async throws {
        let config = CLIKernelConfig(databasePath: testDbPath, enforceGovernance: false)
        let projectId = "proj-rebuild"
        
        // 1. Insert data
        _ = try await CLIKernel.runMemo(content: "Rebuild Me", userId: "u", projectId: projectId, sessionId: "s", config: config)
        
        // 2. Verify it's searchable
        var result = try await CLIKernel.runHybridRecall(query: "Rebuild", projectId: projectId, topK: 5, config: config)
        XCTAssertEqual(result.results.count, 1)
        
        // 3. Run Rebuild (should succeed and not break anything)
        let count = try await CLIKernel.runRebuildFTS(projectId: projectId, config: config)
        XCTAssertGreaterThanOrEqual(count, 1)
        
        // 4. Verify search STILL works
        result = try await CLIKernel.runHybridRecall(query: "Rebuild", projectId: projectId, topK: 5, config: config)
        XCTAssertEqual(result.results.count, 1)
        XCTAssertTrue(result.results[0].tags.contains("keyword"))
    }
}
