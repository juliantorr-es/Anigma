import XCTest
@testable import HarmoniaV2CLIKernel
import HarmoniaV2Core
import AnigmaCore
import HarmoniaV2Inference
import GovernanceCore

final class ModelCompatibilityTests: XCTestCase {
    var testDbPath: String!
    
    override func setUp() async throws {
        try await super.setUp()
        testDbPath = NSTemporaryDirectory() + "test-model-compat-\(UUID().uuidString).db"
    }
    
    override func tearDown() async throws {
        if let path = testDbPath, FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
        }
        try await super.tearDown()
    }
    
    func testMismatchThrowsError() async throws {
        let projectId = "proj-mismatch"
        
        // 1. Manually insert a record with a DIFFERENT model
        let kernelConfig = PlatformRuntime.KernelConfig(databasePath: testDbPath, enforceGovernance: false)
        let runtime = try await PlatformRuntime.makeForKernel(kernelConfig)
        let memoryStore = SimpleMemoryStoreAdapter(database: runtime.database)
        try await memoryStore.initializeSchema()
        
        // Use a backend stub that produces a valid embedding but we will store it with "WRONG-MODEL"
        let backend = DeterministicEmbeddingBackend(modelName: "WRONG-MODEL", dimensions: 256)
        let engine = InferenceEngine(embeddingBackend: backend)
        let context = HarmoniaV2Core.ExecutionContext(sessionId: "x")
        let embeddingResult = try await engine.embed(text: "Content", context: context)
        
        _ = try await memoryStore.store(
            content: "Content",
            metadata: ["tenantId": projectId, "embeddingModel": "WRONG-MODEL"],
            embedding: embeddingResult.vector
        )
        
        // 2. Try to search with the DEFAULT model ("text-embedding-stub-256")
        // CLIKernel.runRecall uses the default model internally.
        
        let cliConfig = CLIKernelConfig(databasePath: testDbPath, enforceGovernance: false)
        
        do {
            _ = try await CLIKernel.runRecall(
                query: "Content",
                projectId: projectId,
                config: cliConfig
            )
            XCTFail("Should have thrown model mismatch error")
        } catch let error as HarmoniaError {
            // Verify it's the right error
            if case .embeddingModelMismatch = error {
                // Success
            } else {
                XCTFail("Wrong HarmoniaError type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testCorrectModelPasses() async throws {
         let projectId = "proj-correct"
         let config = CLIKernelConfig(databasePath: testDbPath, enforceGovernance: false)
         
         // Insert using runMemo (uses correct default model)
         _ = try await CLIKernel.runMemo(
             content: "Content",
             userId: "u",
             projectId: projectId,
             sessionId: "s",
             config: config
         )
         
         // Recall should succeed
         let result = try await CLIKernel.runRecall(
             query: "Content",
             projectId: projectId,
             config: config
         )
         
         XCTAssertEqual(result.results.count, 1)
    }
}
