import Testing
@testable import HarmoniaInference

struct InferenceTests {
    @Test func testInferenceInitialization() {
        let engine = InferenceEngine()
        #expect(engine.isReady)
    }
}
