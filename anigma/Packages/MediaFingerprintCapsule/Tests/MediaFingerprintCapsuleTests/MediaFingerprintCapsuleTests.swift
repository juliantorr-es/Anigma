import Testing
@testable import MediaFingerprintCapsule

struct MediaFingerprintCapsuleTests {
    @Test func testSmokeTest() throws {
        let capsule = try MediaFingerprintCapsule()
        #expect(capsule.imageConfiguration.hashSize > 0)
    }
}
