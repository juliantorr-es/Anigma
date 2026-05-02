import Testing
@testable import RankFusionCapsule

struct RankFusionCapsuleTests {
    @Test func testSmokeTest() throws {
        let capsule = try RankFusionCapsule()
        let results = try capsule.fuse(rankLists: [[1, 2, 3], [2, 3, 1]])
        #expect(!results.isEmpty)
    }
}
