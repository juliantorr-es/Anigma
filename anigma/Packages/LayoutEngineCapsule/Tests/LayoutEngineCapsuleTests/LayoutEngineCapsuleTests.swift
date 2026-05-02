import Testing
@testable import LayoutEngineCapsule

struct LayoutEngineCapsuleTests {
    @Test func testSmokeTest() throws {
        let config = LayoutEngineConfig()
        let _ = try LayoutEngineCapsule(config: config)
    }
}
