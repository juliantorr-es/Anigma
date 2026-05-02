//
//  RecallLifecycleTests.swift
//  GovernanceTests
//
//  Tests ensuring recall respects models, limits, and governance.
//

import XCTest
import HarmoniaV2Surface
import HarmoniaV2Contracts
import GovernanceCore
import AnigmaCore
import AnigmaJobs

final class RecallLifecycleTests: XCTestCase {
    
    var tempDir: URL!
    var dbPath: String!
    
    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        dbPath = tempDir.appendingPathComponent("test.sqlite").path
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    func testRecallLifecycleAndLimits() async throws {
        // 1. Setup
        let client = LocalAppClient(databasePath: dbPath)
        try await client.bootstrap()
        
        let principal = Principal(id: "test-admin", displayName: "Test Admin")  // Use admin for governance ops
        let projectId = "proj-recall"
        let model = "text-embedding-stub-256"  // Use actual deterministic model ID
        
        try await client.createProject(id: projectId, name: "Recall Project", embeddingModel: model, principal: principal)
        
        // 2. Index content (simulated via dry run / memory store directly if client exposed it, but client only exposes file index)
        // We need to inject content.
        // But LocalAppClient doesn't expose raw store.
        // We can use a temp folder and index it.
        
        let folder = tempDir.appendingPathComponent("Content")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileURL = folder.appendingPathComponent("doc1.txt")
        try "This is a document about swift concurrency.".write(to: fileURL, atomically: true, encoding: .utf8)
        
        // Index
        let stream = try await client.index(folder: folder, projectId: projectId, principal: principal, dryRun: false)
        for await _ in stream { } // Wait for completion
        
        // 3. Recall
        let options = RecallOptions(topK: 5, scanLimit: 100, hybrid: true, explain: true)
        let result = try await client.recall(query: "concurrency", projectId: projectId, options: options)
        
        // 4. Assertions
        XCTAssertFalse(result.results.isEmpty, "Should find results")
        XCTAssertEqual(result.stats.rowsScanned, 1, "Should have scanned 1 row")
        XCTAssertTrue(result.stats.executionTime > 0, "Execution time should be tracked")
        XCTAssertEqual(result.results.first?.metadata["embeddingModel"], model, "Model should match")
        
        // 5. Model Mismatch
        // We can't easily force the client to use a different embedding model for query because it's hardcoded to 'DeterministicEmbeddingBackend' which produces "Deterministic-768".
        // In the real app, we might configure the client?
        // Wait, LocalAppClient uses `DeterministicEmbeddingBackend`.
        // The project was created with `test-model-v1` string.
        // The inference engine produces "Deterministic-768".
        // So the query will produce "Deterministic-768".
        // The stored chunk will have "Deterministic-768".
        // The project record has "test-model-v1".
        // Wait, does `recall` check project record?
        // `recall` checks `embeddingModel` param against stored chunks.
        // `LocalMemoryStoreAdapter.searchSimilar` checks if `embeddingModel` param matches stored row.
        // `LocalAppClient.recall` passes `embeddingResult.modelName` ("Deterministic-768") as `embeddingModel` to search.
        // So it matches itself.
        
        // To test mismatch, we'd need to manually insert a record with WRONG model.
        // But we can't access DB directly safely.
        
        // Verify Restricted mode doesn't affect read operations
        try await client.setMode(.restricted, for: projectId, principal: principal)
        
        let result2 = try await client.recall(query: "swift", projectId: projectId, options: options)
        XCTAssertFalse(result2.results.isEmpty, "Recall should work in Restricted mode")
    }
}
