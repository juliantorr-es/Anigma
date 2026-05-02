import Testing
import CapsuleCore
@testable import TextPipelineCapsule

struct TextPipelineTests {
    @Test func testBatchProcessing() async throws {
        let config = TextPipelineConfig()
        let pipeline = try TextPipelineCapsuleWrapper(config: config)
        let results = try await pipeline.transformBatch(["test"])
        #expect(results.count == 1)
    }

    @Test func testCrossLanguageMetrics() {
        CrossLanguageCallMetrics.record(boundary: "test.boundary")
        let snapshot = CrossLanguageCallMetrics.snapshot()
        #expect(snapshot.totalCalls > 0)
    }
}
