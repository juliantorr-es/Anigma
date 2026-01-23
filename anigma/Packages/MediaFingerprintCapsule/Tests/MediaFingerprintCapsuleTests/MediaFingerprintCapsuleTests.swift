import XCTest
@testable import MediaFingerprintCapsule

final class MediaFingerprintCapsuleTests: XCTestCase {
    
    func testMediaFingerprintCapsuleIdentity() throws {
        let identity = MediaFingerprintCapsuleWrapper.identity
        XCTAssertNotNil(identity)
        // Additional identity tests would go here
    }
    
    func testImageFingerprintCreation() throws {
        // Mock image data for testing
        let imageData = Data([0xFF, 0xD8, 0xFF, 0xE0]) // JPEG header
        
        let wrapper = try MediaFingerprintCapsuleWrapper()
        let fingerprint = try wrapper.generateImageFingerprint(imageData, algorithm: .averageHash)
        
        XCTAssertFalse(fingerprint.hash.isEmpty)
        XCTAssertGreaterThan(fingerprint.confidence, 0.0)
        XCTAssertLessThanOrEqual(fingerprint.confidence, 1.0)
    }
    
    func testDuplicateDetection() throws {
        let imageData1 = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let imageData2 = Data([0xFF, 0xD8, 0xFF, 0xE0]) // Same data
        
        let wrapper = try MediaFingerprintCapsuleWrapper()
        let fingerprint1 = try wrapper.generateImageFingerprint(imageData1, algorithm: .averageHash)
        let fingerprint2 = try wrapper.generateImageFingerprint(imageData2, algorithm: .averageHash)
        
        let similarity = try wrapper.compareFingerprints(fingerprint1, fingerprint2)
        XCTAssertEqual(similarity, 1.0, accuracy: 0.01) // Should be identical
    }
    
    func testBatchProcessing() throws {
        let imageDatas = [
            Data([0xFF, 0xD8, 0xFF, 0xE0]),
            Data([0x89, 0x50, 0x4E, 0x47]) // PNG header
        ]
        
        let wrapper = try MediaFingerprintCapsuleWrapper()
        let fingerprints = try wrapper.batchProcessImages(imageDatas, algorithm: .averageHash)
        
        XCTAssertEqual(fingerprints.count, 2)
        for fingerprint in fingerprints {
            XCTAssertFalse(fingerprint.hash.isEmpty)
        }
    }
}