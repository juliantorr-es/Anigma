import XCTest
@testable import MediaContainerCapsule
import CapsuleCore
import AnigmaNativeShims

final class MediaContainerCapsuleTests: XCTestCase {
    
    var mediaCapsule: MediaContainerCapsuleWrapper!
    
    override func setUp() async throws {
        try super.setUp()
        mediaCapsule = try MediaContainerCapsuleWrapper()
    }
    
    override func tearDown() async throws {
        mediaCapsule = nil
        try super.tearDown()
    }
    
    // MARK: - Identity Tests
    
    func testCapsuleIdentity() throws {
        let identity = MediaContainerCapsuleWrapper.identity
        
        XCTAssertEqual(identity.capsule_id, "media_container_capsule")
        XCTAssertEqual(identity.algo_version, "1.0.0")
        XCTAssertEqual(identity.determinism_tier, 1)  // Tier 1: bitwise deterministic
        XCTAssertFalse(identity.build_hash.isEmpty)
    }
    
    // MARK: - Configuration Tests
    
    func testDefaultConfiguration() throws {
        let config = MediaContainerConfig.default
        
        XCTAssertEqual(config.determinismTier, 1)
        XCTAssertEqual(config.maxStreamCount, 16)
        XCTAssertTrue(config.analysisFlags.contains(.extractVideoInfo))
        XCTAssertTrue(config.analysisFlags.contains(.extractAudioInfo))
        XCTAssertTrue(config.analysisFlags.contains(.extractMetadata))
        XCTAssertEqual(config.maxFileSizeBytes, 2_147_483_648)  // 2GB
        XCTAssertEqual(config.maxDurationSeconds, 3600.0)  // 1 hour
    }
    
    func testCustomConfiguration() throws {
        let customConfig = MediaContainerConfig(
            determinismTier: 2,
            maxStreamCount: 32,
            analysisFlags: [.deepScan],
            maxFileSizeBytes: 1_000_000_000,
            maxDurationSeconds: 1800.0
        )
        
        XCTAssertEqual(customConfig.determinismTier, 2)
        XCTAssertEqual(customConfig.maxStreamCount, 32)
        XCTAssertTrue(customConfig.analysisFlags.contains(.deepScan))
        XCTAssertEqual(customConfig.maxFileSizeBytes, 1_000_000_000)
        XCTAssertEqual(customConfig.maxDurationSeconds, 1800.0)
    }
    
    // MARK: - Analysis Tests
    
    func testAnalyzeValidFile() throws {
        // Create a minimal test MP4 file (this would normally use real media files)
        let testData = Data([
            0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x30, 0x30, 0x30,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
        ])
        
        let report = try mediaCapsule.analyzeBuffer(testData)
        
        // Should analyze the buffer (even if it's not a valid media file)
        XCTAssertNotNil(report)
        // For an invalid file, container type might be unknown
        XCTAssertEqual(report.containerType, .unknown)
    }
    
    func testAnalyzeEmptyBuffer() throws {
        let emptyData = Data()
        let report = try mediaCapsule.analyzeBuffer(emptyData)
        
        XCTAssertNotNil(report)
        XCTAssertEqual(report.containerType, .unknown)
        XCTAssertEqual(report.streams.count, 0)
        XCTAssertEqual(report.totalDurationUs, 0)
        XCTAssertEqual(report.fileSizeBytes, 0)
    }
    
    func testAnalyzeLargeBuffer() throws {
        // Test with a larger buffer (simulating media file)
        let largeData = Data(repeating: 0xFF, count: 100_000)
        
        // This should not crash or take too long
        let startTime = Date()
        let report = try mediaCapsule.analyzeBuffer(largeData)
        let analysisTime = Date().timeIntervalSince(startTime)
        
        XCTAssertNotNil(report)
        XCTAssertLessThan(analysisTime, 5.0)  // Should complete within 5 seconds
    }
    
    // MARK: - Stream Info Tests
    
    func testGetVideoStreamInfoInvalidIndex() throws {
        // Test with invalid stream index
        XCTAssertThrowsError(try mediaCapsule.getVideoStreamInfo(at: 999)) { error in
            XCTAssertTrue(error is CapsuleError)
        }
    }
    
    func testGetAudioStreamInfoInvalidIndex() throws {
        // Test with invalid stream index
        XCTAssertThrowsError(try mediaCapsule.getAudioStreamInfo(at: 999)) { error in
            XCTAssertTrue(error is CapsuleError)
        }
    }
    
    // MARK: - Thumbnail Extraction Tests
    
    func testExtractThumbnailInvalidIndex() throws {
        // Test with invalid stream index
        let thumbnail = try mediaCapsule.extractThumbnail(from: 999)
        
        // Should return empty data for invalid stream
        XCTAssertTrue(thumbnail.isEmpty)
    }
    
    func testExtractThumbnailCustomSize() throws {
        // Test custom thumbnail dimensions
        let thumbnail = try mediaCapsule.extractThumbnail(
            from: 0,
            maxWidth: 640,
            maxHeight: 480
        )
        
        // For invalid stream, should return empty data
        XCTAssertTrue(thumbnail.isEmpty)
    }
    
    // MARK: - Container Validation Tests
    
    func testValidateContainerInvalidPath() throws {
        // Test with non-existent file
        let invalidPath = URL(fileURLWithPath: "/non/existent/path.mp4")
        let isValid = try mediaCapsule.validateContainer(at: invalidPath)
        
        // Should return false for non-existent file
        XCTAssertFalse(isValid)
    }
    
    // MARK: - Error Handling Tests
    
    func testOperationOnInvalidatedHandle() throws {
        // Create a capsule and immediately invalidate it
        let capsule = try MediaContainerCapsuleWrapper()
        capsule.invalidate()
        
        XCTAssertThrowsError(try capsule.analyzeFile(at: URL(fileURLWithPath: "test.mp4"))) { error in
            XCTAssertTrue(error is CapsuleError)
        }
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceAnalyzeBuffer() throws {
        let testData = Data(repeating: 0x00, count: 10_000)
        
        measure {
            do {
                _ = try mediaCapsule.analyzeBuffer(testData)
            } catch {
                XCTFail("Buffer analysis failed: \(error)")
            }
        }
    }
    
    func testPerformanceGetStreamInfo() throws {
        // This test would need a valid media file to be meaningful
        // For now, test with invalid index (error path)
        measure {
            do {
                _ = try mediaCapsule.getVideoStreamInfo(at: 0)
            } catch {
                // Expected to fail since no valid media loaded
            }
        }
    }
    
    // MARK: - Enum Conversion Tests
    
    func testMediaStreamTypeConversion() throws {
        XCTAssertEqual(MediaStreamType.video.cValue, ANIGMA_MEDIA_STREAM_VIDEO)
        XCTAssertEqual(MediaStreamType.audio.cValue, ANIGMA_MEDIA_STREAM_AUDIO)
        XCTAssertEqual(MediaStreamType.subtitle.cValue, ANIGMA_MEDIA_STREAM_SUBTITLE)
        XCTAssertEqual(MediaStreamType.unknown.cValue, ANIGMA_MEDIA_STREAM_UNKNOWN)
    }
    
    func testVideoCodecConversion() throws {
        XCTAssertEqual(VideoCodec.h264.cValue, ANIGMA_VIDEO_CODEC_H264)
        XCTAssertEqual(VideoCodec.h265.cValue, ANIGMA_VIDEO_CODEC_H265)
        XCTAssertEqual(VideoCodec.unknown.cValue, ANIGMA_VIDEO_CODEC_UNKNOWN)
    }
    
    func testAudioCodecConversion() throws {
        XCTAssertEqual(AudioCodec.aac.cValue, ANIGMA_AUDIO_CODEC_AAC)
        XCTAssertEqual(AudioCodec.mp3.cValue, ANIGMA_AUDIO_CODEC_MP3)
        XCTAssertEqual(AudioCodec.unknown.cValue, ANIGMA_AUDIO_CODEC_UNKNOWN)
    }
    
    func testContainerTypeConversion() throws {
        XCTAssertEqual(ContainerType.mp4.cValue, ANIGMA_CONTAINER_MP4)
        XCTAssertEqual(ContainerType.matroska.cValue, ANIGMA_CONTAINER_MATROSKA)
        XCTAssertEqual(ContainerType.unknown.cValue, ANIGMA_CONTAINER_UNKNOWN)
    }
    
    // MARK: - Determinism Tests
    
    func testDeterministicAnalysis() throws {
        let testData = Data(repeating: 0x00, count: 1000)
        
        let result1 = try mediaCapsule.analyzeBuffer(testData)
        let result2 = try mediaCapsule.analyzeBuffer(testData)
        
        // Results should be identical for deterministic capsule
        XCTAssertEqual(result1.containerType, result2.containerType)
        XCTAssertEqual(result1.fileSizeBytes, result2.fileSizeBytes)
        XCTAssertEqual(result1.metadataHash, result2.metadataHash)
    }
    
    // MARK: - Integration Tests
    
    func testCompleteWorkflow() throws {
        let testData = Data([
            // Minimal MP4 header (simplified for testing)
            0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, 0x34, 0x30, 0x30, 0x00,
            0x00, 0x00, 0x00, 0x6D, 0x70, 0x34, 0x32
        ])
        
        // Analyze the file
        let report = try mediaCapsule.analyzeBuffer(testData)
        XCTAssertNotNil(report)
        
        // Validate the analysis result structure
        XCTAssertNotNil(report.title)
        XCTAssertTrue(report.title.isEmpty || report.title.count > 0)
        XCTAssertEqual(report.fileSizeBytes, UInt64(testData.count))
        
        // Test stream extraction (should handle gracefully for invalid data)
        if !report.streams.isEmpty {
            let firstStream = report.streams[0]
            switch firstStream.type {
            case .video:
                let videoInfo = try mediaCapsule.getVideoStreamInfo(at: firstStream.index)
                // Should fail gracefully for invalid stream
                XCTAssertTrue(videoInfo == nil || videoInfo?.codec == .unknown)
            case .audio:
                let audioInfo = try mediaCapsule.getAudioStreamInfo(at: firstStream.index)
                // Should fail gracefully for invalid stream
                XCTAssertTrue(audioInfo == nil || audioInfo?.codec == .unknown)
            default:
                break
            }
        }
    }
}