import MediaFingerprintCapsule
import Foundation

/// Example demonstrating Media Fingerprint Capsule usage
@main
struct MediaFingerprintExample {
    
    static func main() async throws {
        print("🎵 Media Fingerprint Capsule Demo 🎵")
        print("=====================================")
        
        // Create capsule with default configuration
        let capsule = try MediaFingerprintCapsuleWrapper()
        print("✅ Created media fingerprint capsule")
        
        // Test media type detection
        await testMediaTypeDetection(capsule: capsule)
        
        // Test image fingerprinting
        await testImageFingerprinting(capsule: capsule)
        
        // Test audio fingerprinting
        await testAudioFingerprinting(capsule: capsule)
        
        // Test video fingerprinting
        await testVideoFingerprinting(capsule: capsule)
        
        // Test batch processing
        await testBatchProcessing(capsule: capsule)
        
        print("\n🎉 Demo completed successfully!")
    }
    
    static func testMediaTypeDetection(capsule: MediaFingerprintCapsuleWrapper) async {
        print("\n📸 Testing Media Type Detection")
        print("--------------------------------")
        
        // Test various file signatures
        let testCases = [
            ("JPEG Image", Data([0xFF, 0xD8, 0xFF, 0xE0]), MediaType.image),
            ("PNG Image", Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]), MediaType.image),
            ("MP3 Audio", Data([0x49, 0x44, 0x33]), MediaType.audio),
            ("WAV Audio", Data([0x52, 0x49, 0x46, 0x46, 0x57, 0x41, 0x56, 0x45]), MediaType.audio),
            ("MP4 Video", Data([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70]), MediaType.video),
            ("Unknown", Data([0x00, 0x01, 0x02, 0x03]), MediaType.unknown)
        ]
        
        for (name, data, expectedType) in testCases {
            do {
                let detectedType = try MediaFingerprintCapsuleWrapper.detectMediaType(data)
                let status = detectedType == expectedType ? "✅" : "❌"
                print("\(status) \(name): \(detectedType) (expected: \(expectedType))")
            } catch {
                print("❌ \(name): Error - \(error)")
            }
        }
    }
    
    static func testImageFingerprinting(capsule: MediaFingerprintCapsuleWrapper) async {
        print("\n🖼️ Testing Image Fingerprinting")
        print("--------------------------------")
        
        // Create test image data (simulated)
        let imageData = generateTestImageData()
        
        do {
            let metadata = try capsule.analyzeMedia(imageData, mediaType: .image)
            print("📊 Image Metadata:")
            print("   Format: \(metadata.format)")
            print("   Dimensions: \(metadata.width) x \(metadata.height)")
            print("   File size: \(metadata.fileSize) bytes")
            
            // Test different algorithms
            let algorithms: [FingerprintAlgorithm] = [.averageHash, .differenceHash, .waveletHash, .perceptualHash]
            
            for algorithm in algorithms {
                let fingerprint = try capsule.generateImageFingerprint(imageData, algorithm: algorithm)
                print("\n🔍 \(algorithm) Fingerprint:")
                print("   Hash size: \(fingerprint.hashSize) bits")
                print("   Confidence: \(String(format: "%.2f", fingerprint.confidence))")
                print("   Processing time: \(fingerprint.processingTimeMs)ms")
                print("   Hash data: \(fingerprint.hashData.prefix(16).map { String(format: "%02x", $0) }.joined())...")
            }
            
            // Test similarity comparison
            let similarImageData = generateSimilarImageData()
            let fp1 = try capsule.generateImageFingerprint(imageData, algorithm: .averageHash)
            let fp2 = try capsule.generateImageFingerprint(similarImageData, algorithm: .averageHash)
            
            let similarity = try capsule.compareFingerprints(fp1, fp2)
            print("\n🔗 Similarity Comparison:")
            print("   Similarity score: \(String(format: "%.3f", similarity.similarityScore))")
            print("   Hamming distance: \(similarity.hammingDistance)")
            print("   Is duplicate: \(similarity.isDuplicate)")
            print("   Is partial match: \(similarity.isPartialMatch)")
            
        } catch {
            print("❌ Image fingerprinting error: \(error)")
        }
    }
    
    static func testAudioFingerprinting(capsule: MediaFingerprintCapsuleWrapper) async {
        print("\n🎵 Testing Audio Fingerprinting")
        print("--------------------------------")
        
        let audioData = generateTestAudioData()
        
        do {
            let metadata = try capsule.analyzeMedia(audioData, mediaType: .audio)
            print("📊 Audio Metadata:")
            print("   Format: \(metadata.format)")
            print("   Sample rate: \(metadata.sampleRate) Hz")
            print("   Bitrate: \(metadata.bitRate) bps")
            print("   Duration: \(metadata.durationMs)ms")
            print("   Channels: \(metadata.sampleRate > 0 ? 2 : 0)") // Simplified
            
            let fingerprint = try capsule.generateAudioFingerprint(audioData, algorithm: .chromaprint)
            print("\n🔍 Chromaprint Fingerprint:")
            print("   Hash size: \(fingerprint.hashSize) bits")
            print("   Confidence: \(String(format: "%.2f", fingerprint.confidence))")
            print("   Processing time: \(fingerprint.processingTimeMs)ms")
            
        } catch {
            print("❌ Audio fingerprinting error: \(error)")
        }
    }
    
    static func testVideoFingerprinting(capsule: MediaFingerprintCapsuleWrapper) async {
        print("\n🎬 Testing Video Fingerprinting")
        print("--------------------------------")
        
        let videoData = generateTestVideoData()
        
        do {
            let metadata = try capsule.analyzeMedia(videoData, mediaType: .video)
            print("📊 Video Metadata:")
            print("   Format: \(metadata.format)")
            print("   Dimensions: \(metadata.width) x \(metadata.height)")
            print("   Duration: \(metadata.durationMs)ms")
            print("   Bitrate: \(metadata.bitRate) bps")
            
            let fingerprint = try capsule.generateVideoFingerprint(videoData, algorithm: .motionVector)
            print("\n🔍 Motion Vector Fingerprint:")
            print("   Hash size: \(fingerprint.hashSize) bits")
            print("   Confidence: \(String(format: "%.2f", fingerprint.confidence))")
            print("   Processing time: \(fingerprint.processingTimeMs)ms")
            
        } catch {
            print("❌ Video fingerprinting error: \(error)")
        }
    }
    
    static func testBatchProcessing(capsule: MediaFingerprintCapsuleWrapper) async {
        print("\n📦 Testing Batch Processing")
        print("--------------------------------")
        
        let imageProcessor = await ImageFingerprint(capsule: capsule)
        
        // Generate test images
        let testImages = [
            generateTestImageData(),
            generateTestImageData(),
            generateSimilarImageData(),
            generateDifferentImageData()
        ]
        
        do {
            // Generate fingerprints for all images
            let fingerprints = try await imageProcessor.generateFingerprints(
                testImages,
                algorithm: .averageHash
            )
            
            print("✅ Generated \(fingerprints.count) fingerprints")
            
            // Find duplicates
            let duplicates = try await imageProcessor.findDuplicates(
                testImages,
                algorithm: .averageHash,
                config: SimilarityConfiguration(similarityThreshold: 0.85)
            )
            
            print("🔍 Found \(duplicates.count) duplicate pairs:")
            for (idx, (dup1, dup2)) in duplicates.enumerated() {
                print("   \(idx + 1). Image \(dup1) ↔ Image \(dup2)")
            }
            
            // Batch comparison
            if let queryFingerprint = fingerprints.first {
                let results = try capsule.batchCompareFingerprints(
                    queryFingerprint: queryFingerprint,
                    candidateFingerprints: Array(fingerprints.dropFirst())
                )
                
                print("\n🎯 Batch Search Results:")
                for (idx, result) in results.enumerated() {
                    print("   \(idx + 1). Similarity: \(String(format: "%.3f", result.similarityScore))")
                }
            }
            
        } catch {
            print("❌ Batch processing error: \(error)")
        }
    }
    
    // MARK: - Test Data Generators
    
    static func generateTestImageData() -> Data {
        // Simulate a simple image with JPEG header
        let jpegHeader = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let imageData = Data(repeating: 0x80, count: 1024) // Simple gray pattern
        return jpegHeader + imageData
    }
    
    static func generateSimilarImageData() -> Data {
        // Slightly different image
        let jpegHeader = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let imageData = Data(repeating: 0x82, count: 1024) // Slightly brighter
        return jpegHeader + imageData
    }
    
    static func generateDifferentImageData() -> Data {
        // Very different image
        let jpegHeader = Data([0xFF, 0xD8, 0xFF, 0xE0])
        let imageData = Data(repeating: 0x20, count: 1024) // Much darker
        return jpegHeader + imageData
    }
    
    static func generateTestAudioData() -> Data {
        // Simulate WAV audio
        let wavHeader = Data([
            0x52, 0x49, 0x46, 0x46, // "RIFF"
            0x24, 0x08, 0x00, 0x00, // File size
            0x57, 0x41, 0x56, 0x45, // "WAVE"
            0x66, 0x6D, 0x74, 0x20, // "fmt "
            0x10, 0x00, 0x00, 0x00, // Chunk size
            0x01, 0x00,             // Audio format (PCM)
            0x02, 0x00,             // Channels (2)
            0x44, 0xAC, 0x00, 0x00, // Sample rate (44100)
            0x10, 0xB1, 0x02, 0x00, // Byte rate
            0x04, 0x00,             // Block align
            0x10, 0x00,             // Bits per sample
            0x64, 0x61, 0x74, 0x61, // "data"
            0x00, 0x08, 0x00, 0x00  // Data size
        ])
        let audioData = Data(repeating: 0x00, count: 2048) // Silence
        return wavHeader + audioData
    }
    
    static func generateTestVideoData() -> Data {
        // Simulate MP4 video
        let mp4Header = Data([
            0x00, 0x00, 0x00, 0x18, // Box size
            0x66, 0x74, 0x79, 0x70, // "ftyp"
            0x69, 0x73, 0x6F, 0x6D, // "isom"
            0x00, 0x00, 0x02, 0x00, // Minor version
            0x6D, 0x70, 0x34, 0x31  // "mp41"
        ])
        let videoData = Data(repeating: 0x00, count: 4096) // Simple frame data
        return mp4Header + videoData
    }
}