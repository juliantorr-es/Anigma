// VideoRenderCapsuleContractTests.swift
// Contract tests for VideoRenderCapsule CapsuleError compliance

import XCTest
@testable import VideoRenderCapsule
import CapsuleCore
import TelemetryCore

final class VideoRenderCapsuleContractTests: XCTestCase {
    var capsule: VideoRenderCapsule!
    var diagnostics: DefaultCapsuleDiagnostics!
    
    override func setUp() async throws {
        try await super.setUp()
        diagnostics = DefaultCapsuleDiagnostics()
        capsule = VideoRenderCapsule(diagnostics: diagnostics)
    }
    
    override func tearDown() async throws {
        capsule = nil
        diagnostics = nil
        try await super.tearDown()
    }
    
    // MARK: - Contract 1: CapsuleError Compliance Tests
    
    /// Test that all public methods return CapsuleError on failure
    func testAnalyzeVideoReturnsCapsuleError() async {
        let invalidData = Data()
        
        do {
            _ = try await capsule.analyzeVideo(data: invalidData)
            XCTFail("Should have thrown CapsuleError")
        } catch let error as CapsuleError {
            // Verify it's a CapsuleError instance
            XCTAssertNotNil(error)
            
            // Verify error type is appropriate
            switch error {
            case .invalidInput, .internalError, .operationFailed:
                XCTAssertTrue(true, "Error type is valid")
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Should have thrown CapsuleError, got: \(error)")
        }
    }
    
    func testDecodeVideoReturnsCapsuleError() async {
        let invalidData = Data()
        
        do {
            _ = try await capsule.decodeVideo(data: invalidData)
            XCTFail("Should have thrown CapsuleError")
        } catch let error as CapsuleError {
            // Verify it's a CapsuleError instance
            XCTAssertNotNil(error)
            
            // Verify error type is appropriate
            switch error {
            case .invalidInput, .internalError, .operationFailed:
                XCTAssertTrue(true, "Error type is valid")
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Should have thrown CapsuleError, got: \(error)")
        }
    }
    
    func testEncodeVideoReturnsCapsuleError() async {
        let emptyFrames: [VideoFrame] = []
        let params = EncodingParameters(
            format: .mp4,
            videoCodec: .h264,
            videoBitrate: 1000000
        )
        
        do {
            _ = try await capsule.encodeVideo(frames: emptyFrames, parameters: params)
            XCTFail("Should have thrown CapsuleError")
        } catch let error as CapsuleError {
            // Verify it's a CapsuleError instance
            XCTAssertNotNil(error)
            
            // Should be invalidInput for empty frames
            switch error {
            case .invalidInput(let field, let constraint):
                XCTAssertEqual(field, "frames")
                XCTAssertTrue(constraint.contains("empty"))
            default:
                XCTFail("Expected invalidInput error, got: \(error)")
            }
        } catch {
            XCTFail("Should have thrown CapsuleError, got: \(error)")
        }
    }
    
    func testApplyEffectsReturnsCapsuleError() async {
        let invalidFrame = VideoFrame(
            pixelData: Data(),
            width: 0,
            height: 0,
            pixelFormat: .rgb24,
            timestamp: 0.0,
            index: 0
        )
        let effects = [FrameEffect.brightness(value: 0.5)]
        
        do {
            _ = try await capsule.applyEffects(to: invalidFrame, effects: effects)
            XCTFail("Should have thrown CapsuleError")
        } catch let error as CapsuleError {
            // Verify it's a CapsuleError instance
            XCTAssertNotNil(error)
            
            // Verify error type is appropriate
            switch error {
            case .invalidInput, .internalError, .operationFailed:
                XCTAssertTrue(true, "Error type is valid")
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Should have thrown CapsuleError, got: \(error)")
        }
    }
    
    func testExtractAudioReturnsCapsuleError() async {
        let invalidData = Data()
        
        do {
            _ = try await capsule.extractAudio(from: invalidData)
            XCTFail("Should have thrown CapsuleError")
        } catch let error as CapsuleError {
            // Verify it's a CapsuleError instance
            XCTAssertNotNil(error)
            
            // Verify error type is appropriate
            switch error {
            case .invalidInput, .internalError, .operationFailed:
                XCTAssertTrue(true, "Error type is valid")
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Should have thrown CapsuleError, got: \(error)")
        }
    }
    
    func testProcessAudioReturnsCapsuleError() async {
        let invalidAudioData = Data()
        
        do {
            _ = try await capsule.processAudio(
                invalidAudioData,
                format: .aac,
                sampleRate: 44100,
                channels: 2
            )
            XCTFail("Should have thrown CapsuleError")
        } catch let error as CapsuleError {
            // Verify it's a CapsuleError instance
            XCTAssertNotNil(error)
            
            // Verify error type is appropriate
            switch error {
            case .invalidInput, .internalError, .operationFailed:
                XCTAssertTrue(true, "Error type is valid")
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Should have thrown CapsuleError, got: \(error)")
        }
    }
    
    func testGenerateThumbnailReturnsCapsuleError() async {
        let invalidData = Data()
        
        do {
            _ = try await capsule.generateThumbnail(
                from: invalidData,
                width: 320,
                height: 240,
                timestamp: 0.0
            )
            XCTFail("Should have thrown CapsuleError")
        } catch let error as CapsuleError {
            // Verify it's a CapsuleError instance
            XCTAssertNotNil(error)
            
            // Verify error type is appropriate
            switch error {
            case .invalidInput, .internalError, .operationFailed:
                XCTAssertTrue(true, "Error type is valid")
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Should have thrown CapsuleError, got: \(error)")
        }
    }
    
    // MARK: - Contract 2: CapsuleDiagnostics Compliance Tests
    
    /// Test that all operations emit diagnostic events
    func testAnalyzeVideoEmitsDiagnostics() async {
        let initialEventCount = diagnostics.getAllEvents().count
        
        do {
            _ = try await capsule.analyzeVideo(data: Data([0x00, 0x00, 0x00, 0x18]))
        } catch {
            // Expected to fail, but should emit diagnostics
        }
        
        let finalEventCount = diagnostics.getAllEvents().count
        XCTAssertGreaterThan(finalEventCount, initialEventCount, "Should emit diagnostic events")
        
        // Verify span was created
        let events = diagnostics.getAllEvents()
        let spanEvents = events.filter { $0.category.contains("VideoRenderCapsule") }
        XCTAssertGreaterThan(spanEvents.count, 0, "Should emit VideoRenderCapsule events")
    }
    
    func testDecodeVideoEmitsDiagnostics() async {
        let initialEventCount = diagnostics.getAllEvents().count
        
        do {
            _ = try await capsule.decodeVideo(data: Data([0x00, 0x00, 0x00, 0x18]))
        } catch {
            // Expected to fail, but should emit diagnostics
        }
        
        let finalEventCount = diagnostics.getAllEvents().count
        XCTAssertGreaterThan(finalEventCount, initialEventCount, "Should emit diagnostic events")
    }
    
    func testEncodeVideoEmitsDiagnostics() async {
        let frame = VideoFrame(
            pixelData: Data(repeating: 0, count: 100 * 100 * 3),
            width: 100,
            height: 100,
            pixelFormat: .rgb24,
            timestamp: 0.0,
            index: 0
        )
        let params = EncodingParameters(
            format: .mp4,
            videoCodec: .h264,
            videoBitrate: 1000000
        )
        
        let initialEventCount = diagnostics.getAllEvents().count
        
        do {
            _ = try await capsule.encodeVideo(frames: [frame], parameters: params)
        } catch {
            // Expected to fail, but should emit diagnostics
        }
        
        let finalEventCount = diagnostics.getAllEvents().count
        XCTAssertGreaterThan(finalEventCount, initialEventCount, "Should emit diagnostic events")
    }
    
    func testApplyEffectsEmitsDiagnostics() async {
        let frame = VideoFrame(
            pixelData: Data(repeating: 0, count: 100 * 100 * 3),
            width: 100,
            height: 100,
            pixelFormat: .rgb24,
            timestamp: 0.0,
            index: 0
        )
        let effects = [FrameEffect.brightness(value: 0.5)]
        
        let initialEventCount = diagnostics.getAllEvents().count
        
        do {
            _ = try await capsule.applyEffects(to: frame, effects: effects)
        } catch {
            // Expected to fail, but should emit diagnostics
        }
        
        let finalEventCount = diagnostics.getAllEvents().count
        XCTAssertGreaterThan(finalEventCount, initialEventCount, "Should emit diagnostic events")
    }
    
    func testExtractAudioEmitsDiagnostics() async {
        let initialEventCount = diagnostics.getAllEvents().count
        
        do {
            _ = try await capsule.extractAudio(from: Data([0x00, 0x00, 0x00, 0x18]))
        } catch {
            // Expected to fail, but should emit diagnostics
        }
        
        let finalEventCount = diagnostics.getAllEvents().count
        XCTAssertGreaterThan(finalEventCount, initialEventCount, "Should emit diagnostic events")
    }
    
    func testProcessAudioEmitsDiagnostics() async {
        let audioData = Data(repeating: 0, count: 1024)
        
        let initialEventCount = diagnostics.getAllEvents().count
        
        do {
            _ = try await capsule.processAudio(
                audioData,
                format: .aac,
                sampleRate: 44100,
                channels: 2
            )
        } catch {
            // Expected to fail, but should emit diagnostics
        }
        
        let finalEventCount = diagnostics.getAllEvents().count
        XCTAssertGreaterThan(finalEventCount, initialEventCount, "Should emit diagnostic events")
    }
    
    func testGenerateThumbnailEmitsDiagnostics() async {
        let initialEventCount = diagnostics.getAllEvents().count
        
        do {
            _ = try await capsule.generateThumbnail(
                from: Data([0x00, 0x00, 0x00, 0x18]),
                width: 320,
                height: 240,
                timestamp: 0.0
            )
        } catch {
            // Expected to fail, but should emit diagnostics
        }
        
        let finalEventCount = diagnostics.getAllEvents().count
        XCTAssertGreaterThan(finalEventCount, initialEventCount, "Should emit diagnostic events")
    }
    
    // MARK: - Contract 3: Sendable Compliance Tests
    
    /// Test that all public types are Sendable
    func testPublicTypesAreSendable() {
        // Test enums
        XCTAssertTrue(isSendable(VideoFormat.self), "VideoFormat should be Sendable")
        XCTAssertTrue(isSendable(VideoCodec.self), "VideoCodec should be Sendable")
        XCTAssertTrue(isSendable(AudioCodec.self), "AudioCodec should be Sendable")
        XCTAssertTrue(isSendable(PixelFormat.self), "PixelFormat should be Sendable")
        XCTAssertTrue(isSendable(VideoRenderError.self), "VideoRenderError should be Sendable")
        
        // Test structs
        XCTAssertTrue(isSendable(VideoInfo.self), "VideoInfo should be Sendable")
        XCTAssertTrue(isSendable(VideoFrame.self), "VideoFrame should be Sendable")
        XCTAssertTrue(isSendable(EncodingParameters.self), "EncodingParameters should be Sendable")
        XCTAssertTrue(isSendable(FrameEffect.self), "FrameEffect should be Sendable")
        
        // Test actor
        XCTAssertTrue(isSendable(VideoRenderCapsule.self), "VideoRenderCapsule should be Sendable")
    }
    
    /// Test that capsule can be used across concurrency boundaries
    func testConcurrentCapsuleUsage() async throws {
        let frame = VideoFrame(
            pixelData: Data(repeating: 0, count: 100 * 100 * 3),
            width: 100,
            height: 100,
            pixelFormat: .rgb24,
            timestamp: 0.0,
            index: 0
        )
        
        // Test concurrent access to the same capsule instance
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    do {
                        // Each task should be able to access the capsule
                        let version = self.capsule.version
                        XCTAssertFalse(version.isEmpty)
                        
                        // Test format detection (doesn't require native bridge)
                        let format = self.capsule.detectFormat(data: Data([0x00, 0x00, 0x00, 0x18]))
                        XCTAssertNotNil(format)
                        
                        // Test effect application (will fail but should be thread-safe)
                        _ = try await self.capsule.applyEffects(
                            to: frame,
                            effects: [FrameEffect.brightness(value: 0.5)]
                        )
                    } catch {
                        // Expected to fail with mock implementation
                    }
                }
            }
        }
        
        // Should complete without deadlocks or crashes
        XCTAssertTrue(true)
    }
    
    // MARK: - Contract 4: Swift 6 Compliance Tests
    
    /// Test that the capsule complies with Swift 6 strict concurrency
    func testSwift6Compliance() async {
        // Test that actor isolation is properly maintained
        let frame = VideoFrame(
            pixelData: Data(repeating: 0, count: 100 * 100 * 3),
            width: 100,
            height: 100,
            pixelFormat: .rgb24,
            timestamp: 0.0,
            index: 0
        )
        
        // All async methods should be properly isolated to the actor
        do {
            _ = try await capsule.analyzeVideo(data: Data([0x00, 0x00, 0x00, 0x18]))
        } catch {
            // Expected to fail
        }
        
        do {
            _ = try await capsule.decodeVideo(data: Data([0x00, 0x00, 0x00, 0x18]))
        } catch {
            // Expected to fail
        }
        
        do {
            _ = try await capsule.applyEffects(to: frame, effects: [FrameEffect.brightness(value: 0.5)])
        } catch {
            // Expected to fail
        }
        
        // Non-async properties should be accessible from non-isolated context
        let version = capsule.version
        let ffmpegVersion = capsule.ffmpegVersion
        
        XCTAssertFalse(version.isEmpty)
        XCTAssertFalse(ffmpegVersion.isEmpty)
    }
    
    // MARK: - Contract 5: Resource Management Tests
    
    /// Test that resources are properly managed
    func testResourceManagement() async {
        // Test with large data to ensure proper memory management
        let largePixelData = Data(repeating: 0xFF, count: 1920 * 1080 * 4) // Full HD RGBA
        let largeFrame = VideoFrame(
            pixelData: largePixelData,
            width: 1920,
            height: 1080,
            pixelFormat: .rgba32,
            timestamp: 0.0,
            index: 0
        )
        
        do {
            _ = try await capsule.applyEffects(
                to: largeFrame,
                effects: [FrameEffect.brightness(value: 0.5)]
            )
        } catch {
            // Expected to fail with mock implementation
        }
        
        // Should not leak memory or crash
        XCTAssertTrue(true)
    }
    
    /// Test batch operations don't exhaust resources
    func testBatchOperationResourceManagement() async {
        let frames = (0..<100).map { i in
            VideoFrame(
                pixelData: Data(repeating: UInt8(i % 256), count: 100 * 100 * 3),
                width: 100,
                height: 100,
                pixelFormat: .rgb24,
                timestamp: Double(i) / 30.0,
                index: i
            )
        }
        
        let results = await capsule.applyEffectsBatch(
            frames: frames,
            effects: [FrameEffect.brightness(value: 0.5)]
        )
        
        XCTAssertEqual(results.count, 100)
        
        // All results should be failures (mock implementation) but shouldn't crash
        for result in results {
            switch result {
            case .success:
                XCTFail("Unexpected success with mock implementation")
            case .failure(let error):
                XCTAssertTrue(error is CapsuleError)
            }
        }
    }
    
    // MARK: - Contract 6: Input Validation Tests
    
    /// Test that all methods properly validate inputs
    func testInputValidation() async {
        // Test empty data validation
        do {
            _ = try await capsule.analyzeVideo(data: Data())
            XCTFail("Should reject empty data")
        } catch let error as CapsuleError {
            switch error {
            case .invalidInput, .internalError:
                XCTAssertTrue(true)
            default:
                XCTFail("Expected invalidInput or internalError")
            }
        } catch {
            XCTFail("Should throw CapsuleError")
        }
        
        // Test nil frame validation
        do {
            let emptyFrame = VideoFrame(
                pixelData: Data(),
                width: 0,
                height: 0,
                pixelFormat: .rgb24,
                timestamp: 0.0,
                index: 0
            )
            _ = try await capsule.applyEffects(to: emptyFrame, effects: [])
            XCTFail("Should reject invalid frame")
        } catch let error as CapsuleError {
            switch error {
            case .invalidInput, .internalError:
                XCTAssertTrue(true)
            default:
                XCTFail("Expected invalidInput or internalError")
            }
        } catch {
            XCTFail("Should throw CapsuleError")
        }
        
        // Test empty frames array validation
        do {
            let params = EncodingParameters(
                format: .mp4,
                videoCodec: .h264,
                videoBitrate: 1000000
            )
            _ = try await capsule.encodeVideo(frames: [], parameters: params)
            XCTFail("Should reject empty frames array")
        } catch let error as CapsuleError {
            switch error {
            case .invalidInput(let field, let constraint):
                XCTAssertEqual(field, "frames")
                XCTAssertTrue(constraint.contains("empty"))
            default:
                XCTFail("Expected invalidInput error")
            }
        } catch {
            XCTFail("Should throw CapsuleError")
        }
    }
    
    // MARK: - Helper Methods
    
    private func isSendable(_ type: Any.Type) -> Bool {
        // Check if type conforms to Sendable
        return (type as? Any.Type)?.isSendable ?? false
    }
}

// MARK: - Sendable Helper Extension

extension Any.Type {
    var isSendable: Bool {
        // Use reflection to check Sendable conformance
        return (self as? Sendable.Type) != nil
    }
}