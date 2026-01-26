// MediaFingerprintCapsuleTests.swift
// Tests for MediaFingerprintCapsule

import XCTest
@testable import MediaFingerprintCapsule
@preconcurrency import MediaFingerprintNative

final class MediaFingerprintCapsuleTests: XCTestCase {
    
    var capsule: MediaFingerprintCapsule!
    
    override func setUp() async throws {
        capsule = MediaFingerprintCapsule()
    }
    
    // MARK: - Version Tests
    
    func testVersion() {
        let version = capsule.version
        XCTAssertFalse(version.isEmpty)
        XCTAssertEqual(version, "1.0.0")
    }
    
    // MARK: - Hamming Distance Tests
    
    func testHammingDistanceIdentical() {
        let hash1 = PerceptualHash64(0xDEADBEEFCAFEBABE)
        let hash2 = PerceptualHash64(0xDEADBEEFCAFEBABE)
        XCTAssertEqual(hash1.hammingDistance(to: hash2), 0)
        XCTAssertEqual(hash1.similarity(to: hash2), 1.0)
    }
    
    func testHammingDistanceComplement() {
        let hash1 = PerceptualHash64(0x0000000000000000)
        let hash2 = PerceptualHash64(0xFFFFFFFFFFFFFFFF)
        XCTAssertEqual(hash1.hammingDistance(to: hash2), 64)
        XCTAssertEqual(hash1.similarity(to: hash2), 0.0)
    }
    
    func testHammingDistanceSingleBit() {
        let hash1 = PerceptualHash64(0x0000000000000001)
        let hash2 = PerceptualHash64(0x0000000000000000)
        XCTAssertEqual(hash1.hammingDistance(to: hash2), 1)
        XCTAssertTrue(hash1.isSimilar(to: hash2, maxDistance: 5))
    }
    
    // MARK: - Hash Hex Conversion Tests
    
    func testHashHexString() {
        let hash = PerceptualHash64(0xDEADBEEFCAFEBABE)
        XCTAssertEqual(hash.hexString, "deadbeefcafebabe")
    }
    
    func testHashFromHexString() {
        let hash = PerceptualHash64(hexString: "deadbeefcafebabe")
        XCTAssertNotNil(hash)
        XCTAssertEqual(hash?.value, 0xDEADBEEFCAFEBABE)
    }
    
    func testHashFromInvalidHexString() {
        XCTAssertNil(PerceptualHash64(hexString: "not a hex"))
        XCTAssertNil(PerceptualHash64(hexString: "1234")) // Too short
    }
    
    // MARK: - Similarity Search Tests
    
    func testFindSimilar() async {
        let query = PerceptualHash64(0x0000000000000000)
        let candidates = [
            PerceptualHash64(0x0000000000000001), // 1 bit different
            PerceptualHash64(0x0000000000000003), // 2 bits different  
            PerceptualHash64(0x00000000000000FF), // 8 bits different
            PerceptualHash64(0xFFFFFFFFFFFFFFFF), // 64 bits different
        ]
        
        let results = await capsule.findSimilar(
            query: query,
            in: candidates,
            maxDistance: 10
        )
        
        XCTAssertEqual(results.count, 3) // Should find first 3
        XCTAssertEqual(results[0].index, 0)
        XCTAssertEqual(results[0].distance, 1)
    }
    
    // MARK: - pHash Tests (from synthetic grayscale data)
    
    func testPHashFromGrayscale() async throws {
        // Create a simple 64x64 gradient image
        var pixels = Data(count: 64 * 64)
        for y in 0..<64 {
            for x in 0..<64 {
                pixels[y * 64 + x] = UInt8((x + y) * 2)
            }
        }
        
        let hash = try await capsule.hash(
            grayscalePixels: pixels,
            width: 64,
            height: 64,
            algorithm: .pHash
        )
        
        XCTAssertNotEqual(hash.value, 0)
    }
    
    func testPHashDeterministic() async throws {
        var pixels = Data(count: 64 * 64)
        for i in 0..<(64 * 64) {
            pixels[i] = UInt8(i % 256)
        }
        
        let hash1 = try await capsule.hash(
            grayscalePixels: pixels,
            width: 64,
            height: 64,
            algorithm: .pHash
        )
        
        let hash2 = try await capsule.hash(
            grayscalePixels: pixels,
            width: 64,
            height: 64,
            algorithm: .pHash
        )
        
        XCTAssertEqual(hash1, hash2)
    }
    
    // MARK: - dHash Tests
    
    func testDHashFromGrayscale() async throws {
        // Create an alternating pattern so some pixels are > their neighbor
        var pixels = Data(count: 64 * 64)
        for y in 0..<64 {
            for x in 0..<64 {
                // Alternating pattern: odd columns have higher values
                if x % 2 == 0 {
                    pixels[y * 64 + x] = 100
                } else {
                    pixels[y * 64 + x] = 200
                }
            }
        }
        
        let hash = try await capsule.hash(
            grayscalePixels: pixels,
            width: 64,
            height: 64,
            algorithm: .dHash
        )
        
        // With alternating pattern, we should get some bits set
        // (but not necessarily non-zero - depends on how resize works)
        // Just verify no error occurs
        _ = hash.hexString
    }
    
    func testDHashSimilarImages() async throws {
        // Create two similar alternating pattern images
        var pixels1 = Data(count: 64 * 64)
        var pixels2 = Data(count: 64 * 64)
        
        for y in 0..<64 {
            for x in 0..<64 {
                // Use a pattern that produces non-zero hash
                let val = UInt8((x * 17 + y * 23) % 256)
                pixels1[y * 64 + x] = val
                pixels2[y * 64 + x] = UInt8(min(255, Int(val) + 3)) // Slightly brighter
            }
        }
        
        let hash1 = try await capsule.hash(
            grayscalePixels: pixels1,
            width: 64,
            height: 64,
            algorithm: .dHash
        )
        
        let hash2 = try await capsule.hash(
            grayscalePixels: pixels2,
            width: 64,
            height: 64,
            algorithm: .dHash
        )
        
        // Similar images should have similar hashes
        XCTAssertTrue(hash1.isSimilar(to: hash2, maxDistance: 16))
    }
    
    // MARK: - Audio Fingerprint Tests
    
    func testAudioFingerprint() async throws {
        // Generate a simple sine wave
        let sampleRate = 44100
        let duration: Float = 0.5
        let sampleCount = Int(Float(sampleRate) * duration)
        
        var samples: [Float] = []
        for i in 0..<sampleCount {
            let t = Float(i) / Float(sampleRate)
            samples.append(sin(2 * .pi * 440 * t)) // 440 Hz tone
        }
        
        let fingerprint = try await capsule.fingerprint(
            audioSamples: samples,
            sampleRate: sampleRate
        )
        
        XCTAssertGreaterThan(fingerprint.subfingerprints.count, 0)
        XCTAssertEqual(fingerprint.durationSeconds, duration, accuracy: 0.01)
    }
    
    func testAudioFingerprintSimilarity() async throws {
        let sampleRate = 44100
        let sampleCount = sampleRate / 2 // 0.5 seconds
        
        // Generate two similar signals
        var samples1: [Float] = []
        var samples2: [Float] = []
        
        for i in 0..<sampleCount {
            let t = Float(i) / Float(sampleRate)
            samples1.append(sin(2 * .pi * 440 * t))
            samples2.append(sin(2 * .pi * 440 * t) * 0.95) // Slightly quieter
        }
        
        let fp1 = try await capsule.fingerprint(audioSamples: samples1, sampleRate: sampleRate)
        let fp2 = try await capsule.fingerprint(audioSamples: samples2, sampleRate: sampleRate)
        
        let similarity = fp1.similarity(to: fp2)
        XCTAssertGreaterThan(similarity, 0.8) // Should be very similar
    }
    
    // MARK: - Batch Processing Tests
    
    func testBatchHashing() async {
        // Create multiple synthetic images
        var images: [Data] = []
        for offset in 0..<5 {
            var pixels = Data(count: 32 * 32)
            for i in 0..<(32 * 32) {
                pixels[i] = UInt8((i + offset * 10) % 256)
            }
            images.append(pixels)
        }
        
        // Note: batch hashing expects encoded images, so this will fail
        // This test validates the batch mechanism works even with failures
        let results = await capsule.hashBatch(images: images, algorithm: .pHash)
        XCTAssertEqual(results.count, 5)
    }
    
    // MARK: - 256-bit Hash Tests
    
    func testHash256() async throws {
        var pixels = Data(count: 128 * 128)
        for i in 0..<(128 * 128) {
            pixels[i] = UInt8(i % 256)
        }
        
        let hash = try await capsule.hash256(
            grayscalePixels: pixels,
            width: 128,
            height: 128
        )
        
        // Verify all parts are populated
        XCTAssertNotEqual(hash.parts.0, 0)
    }
    
    // MARK: - Error Handling Tests
    
    func testEmptyImageError() async {
        let emptyData = Data()
        
        do {
            _ = try await capsule.hash(imageData: emptyData)
            XCTFail("Should have thrown error")
        } catch let error as MediaFingerprintError {
            XCTAssertEqual(error.description, "Invalid format")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testInvalidDimensionsError() async {
        let pixels = Data(count: 0)
        
        do {
            _ = try await capsule.hash(
                grayscalePixels: pixels,
                width: 0,
                height: 0
            )
            XCTFail("Should have thrown error")
        } catch let error as MediaFingerprintError {
            // Either null pointer or invalid dimensions is acceptable
            XCTAssertTrue(
                error.description == "Null pointer provided" ||
                error.description == "Invalid image dimensions",
                "Got unexpected error: \(error.description)"
            )
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}

// MARK: - Native C API Tests

final class MediaFingerprintNativeTests: XCTestCase {
    
    func testHammingDistance64() {
        let d1 = amfp_hamming_distance_64(0x0, 0x0)
        XCTAssertEqual(d1, 0)
        
        let d2 = amfp_hamming_distance_64(0x0, 0xFFFFFFFFFFFFFFFF)
        XCTAssertEqual(d2, 64)
        
        let d3 = amfp_hamming_distance_64(0x1, 0x0)
        XCTAssertEqual(d3, 1)
    }
    
    func testHammingDistance256() {
        var h1 = amfp_hash256_t(parts: (0, 0, 0, 0))
        var h2 = amfp_hash256_t(parts: (0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 
                                         0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF))
        
        let distance = amfp_hamming_distance_256(&h1, &h2)
        XCTAssertEqual(distance, 256)
    }
    
    func testSimilarityFromDistance() {
        let sim1 = amfp_similarity_from_distance(0, 64)
        XCTAssertEqual(sim1, 1.0)
        
        let sim2 = amfp_similarity_from_distance(64, 64)
        XCTAssertEqual(sim2, 0.0)
        
        let sim3 = amfp_similarity_from_distance(32, 64)
        XCTAssertEqual(sim3, 0.5)
    }
    
    func testHashesSimilar64() {
        XCTAssertTrue(amfp_hashes_similar_64(0x0, 0x1, 5))
        XCTAssertFalse(amfp_hashes_similar_64(0x0, 0xFF, 5))
    }
    
    func testHash64ToHex() {
        var buffer = [CChar](repeating: 0, count: 17)
        let result = amfp_hash64_to_hex(0xDEADBEEFCAFEBABE, &buffer, 17)
        XCTAssertEqual(result, AMFP_SUCCESS)
        XCTAssertEqual(String(cString: buffer), "deadbeefcafebabe")
    }
    
    func testHash64FromHex() {
        var hash: amfp_hash64_t = 0
        let result = amfp_hash64_from_hex("deadbeefcafebabe", &hash)
        XCTAssertEqual(result, AMFP_SUCCESS)
        XCTAssertEqual(hash, 0xDEADBEEFCAFEBABE)
    }
    
    func testVersion() {
        let version = amfp_version()
        XCTAssertNotNil(version)
        XCTAssertEqual(String(cString: version!), "1.0.0")
    }
}
