import Testing
@testable import VectorIndexCapsule

struct VectorIndexCapsuleTests {
    @Test func testSmokeTest() throws {
        let config = VectorIndexConfig(dimension: 128, maxElements: 100)
        let _ = try VectorIndexCapsule(config: config)
    }
}
