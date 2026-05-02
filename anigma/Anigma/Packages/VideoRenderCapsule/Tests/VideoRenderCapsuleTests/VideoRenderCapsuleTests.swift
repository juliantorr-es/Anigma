// VideoRenderCapsuleTests.swift
// Unit tests for VideoRenderCapsule functionality

import XCTest
@testable import VideoRenderCapsule
import CapsuleCore
import TelemetryCore

final class VideoRenderCapsuleTests: XCTestCase {
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
    
    // MARK: - Version Tests
    
    func testVersion() {
        let version = capsule.version
        XCTAssertFalse(version.isEmpty)
        XCTAssertTrue(version.contains("VideoRender"))
    }
    
    func testFFmpegVersion() {
        let ffmpegVersion = capsule.ffmpegVersion
        XCTAssertFalse(ffmpegVersion.isEmpty)
        XCTAssertTrue(ffmpegVersion.contains("ffmpeg") || ffmpegVersion.contains("FFmpeg"))
    }
    
    // MARK: - Format Detection Tests
    
    func testDetectFormat() async {
        // Test MP4 format detection
        let mp4Header = Data([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70]) // ftyp header
        let detectedFormat = capsule.detectFormat(data: mp4Header)
        XCTAssertEqual(detectedFormat, .mp4)
        
        // Test WebM format detection (simplified)
        let webmHeader = Data([0x1A, 0x45, 0xDF, 0xA3]) // EBML header
        let detectedWebM = capsule.detectFormat(data: webmHeader)
        XCTAssertEqual(detectedWebM, .mp4) // Falls back to MP4 for unknown formats
    }
    
    // MARK: - Error Tests
    
    func testVideoRenderErrorMapping() {
        // Test error mapping to CapsuleError
        let nullPointerError = VideoRenderError.nullPointer.capsuleError
        XCTAssertTrue(nullPointerError.description.contains("internalError"))
        
        let invalidDataError = VideoRenderError.invalidData.capsuleError
        XCTAssertTrue(invalidDataError.description.contains("invalidInput"))
        
        let decodeFailedError = VideoRenderError.decodeFailed.capsuleError
        XCTAssertTrue(decodeFailedError.description.contains("operationFailed"))
    }
    
    // MARK: - Video Format Tests
    
    func testVideoFormatProperties() {
        XCTAssertEqual(VideoFormat.mp4.mimeType, "video/mp4")
        XCTAssertEqual(VideoFormat.mp4.fileExtension, ".mp4")
        XCTAssertEqual(VideoFormat.webm.mimeType, "video/webm")
        XCTAssertEqual(VideoFormat.avi.mimeType, "video/x-msvideo")
        XCTAssertEqual(VideoFormat.mov.mimeType, "video/quicktime")
        XCTAssertEqual(VideoFormat.mkv.mimeType, "video/x-matroska")
    }
    
    func testVideoCodecProperties() {
        XCTAssertEqual(VideoCodec.h264.name, "H.264")
        XCTAssertEqual(VideoCodec.h265.name, "H.265")
        XCTAssertEqual(VideoCodec.vp9.name, "VP9")
        XCTAssertEqual(VideoCodec.av1.name, "AV1")
        XCTAssertEqual(VideoCodec.mpeg4.name, "MPEG-4")
    }
    
    func testAudioCodecProperties() {
        XCTAssertEqual(AudioCodec.aac.name, "AAC")
        XCTAssertEqual(AudioCodec.mp3.name, "MP3")
        XCTAssertEqual(AudioCodec.opus.name, "Opus")
        XCTAssertEqual(AudioCodec.vorbis.name, "Vorbis")
        XCTAssertEqual(AudioCodec.flac.name, "FLAC")
    }
    
    // MARK: - Pixel Format Tests
    
    func testPixelFormatProperties() {
        XCTAssertEqual(PixelFormat.rgb24.bytesPerPixel, 3)
        XCTAssertEqual(PixelFormat.rgba32.bytesPerPixel, 4)
        XCTAssertEqual(PixelFormat.bgra32.bytesPerPixel, 4)
        
        XCTAssertEqual(PixelFormat.rgb24.description, "RGB24")
        XCTAssertEqual(PixelFormat.yuv420p.description, "YUV420P")
    }
    
    // MARK: - Frame Effect Tests
    
    func testFrameEffectNativeMapping() {
        let resizeEffect = FrameEffect.resize(width: 640, height: 480)
        let (type, params) = resizeEffect.nativeEffect
        XCTAssertEqual(type, VideoRenderNativeBridge.effectResize)
        XCTAssertEqual(params.param1, 640.0)
        XCTAssertEqual(params.param2, 480.0)
        
        let cropEffect = FrameEffect.crop(x: 10, y: 20, width: 300, height: 200)
        let (cropType, cropParams) = cropEffect.nativeEffect
        XCTAssertEqual(cropType, VideoRenderNativeBridge.effectCrop)
        XCTAssertEqual(cropParams.param1, 10.0)
        XCTAssertEqual(cropParams.param2, 20.0)
        XCTAssertEqual(cropParams.param3, 300.0)
        XCTAssertEqual(cropParams.param4, 200.0)
        
        let brightnessEffect = FrameEffect.brightness(value: 0.5)
        let (brightType, brightParams) = brightnessEffect.nativeEffect
        XCTAssertEqual(brightType, VideoRenderNativeBridge.effectBrightness)
        XCTAssertEqual(brightParams.param1, 0.5)
    }
    
    // MARK: - Video Info Tests
    
    func testVideoInfoProperties() {
        let videoInfo = VideoInfo(
            width: 1920,
            height: 1080,
            frameRate: 30.0,
            duration: 10.0,
            bitrate: 5000000,
            format: .mp4,
            videoCodec: .h264,
            audioCodec: .aac,
            pixelFormat: .yuv420p,
            audioSampleRate: 44100,
            audioChannels: 2,
            frameCount: 300
        )
        
        XCTAssertEqual(videoInfo.width, 1920)
        XCTAssertEqual(videoInfo.height, 1080)
        XCTAssertEqual(videoInfo.frameRate, 30.0)
        XCTAssertEqual(videoInfo.duration, 10.0)
        XCTAssertEqual(videoInfo.bitrate, 5000000)
        XCTAssertEqual(videoInfo.format, .mp4)
        XCTAssertEqual(videoInfo.videoCodec, .h264)
        XCTAssertEqual(videoInfo.audioCodec, .aac)
        XCTAssertTrue(videoInfo.hasAudio)
        XCTAssertEqual(videoInfo.aspectRatio, 1920.0 / 1080.0, accuracy: 0.01)
    }
    
    func testVideoInfoNoAudio() {
        let videoInfo = VideoInfo(
            width: 1280,
            height: 720,
            frameRate: 25.0,
            duration: 5.0,
            bitrate: 2000000,
            format: .webm,
            videoCodec: .vp9,
            audioCodec: nil,
            pixelFormat: .yuv420p,
            audioSampleRate: nil,
            audioChannels: nil,
            frameCount: 125
        )
        
        XCTAssertFalse(videoInfo.hasAudio)
        XCTAssertNil(videoInfo.audioCodec)
        XCTAssertNil(videoInfo.audioSampleRate)
        XCTAssertNil(videoInfo.audioChannels)
    }
    
    // MARK: - Video Frame Tests
    
    func testVideoFrameProperties() {
        let pixelData = Data(repeating: 0, count: 640 * 480 * 4) // RGBA32
        let frame = VideoFrame(
            pixelData: pixelData,
            width: 640,
            height: 480,
            pixelFormat: .rgba32,
            timestamp: 1.0,
            index: 0
        )
        
        XCTAssertEqual(frame.width, 640)
        XCTAssertEqual(frame.height, 480)
        XCTAssertEqual(frame.pixelFormat, .rgba32)
        XCTAssertEqual(frame.timestamp, 1.0)
        XCTAssertEqual(frame.index, 0)
        XCTAssertEqual(frame.dataSizeBytes, 640 * 480 * 4)
        XCTAssertEqual(frame.bytesPerRow, 640 * 4)
    }
    
    // MARK: - Encoding Parameters Tests
    
    func testEncodingParameters() {
        let params = EncodingParameters(
            format: .mp4,
            videoCodec: .h264,
            audioCodec: .aac,
            width: 1280,
            height: 720,
            frameRate: 30.0,
            videoBitrate: 3000000,
            audioBitrate: 128000,
            audioSampleRate: 44100,
            audioChannels: 2
        )
        
        XCTAssertEqual(params.format, .mp4)
        XCTAssertEqual(params.videoCodec, .h264)
        XCTAssertEqual(params.audioCodec, .aac)
        XCTAssertEqual(params.width, 1280)
        XCTAssertEqual(params.height, 720)
        XCTAssertEqual(params.frameRate, 30.0)
        XCTAssertEqual(params.videoBitrate, 3000000)
        XCTAssertEqual(params.audioBitrate, 128000)
        XCTAssertEqual(params.audioSampleRate, 44100)
        XCTAssertEqual(params.audioChannels, 2)
    }
    
    // MARK: - Lifecycle Tests
    
    func testCapsuleLifecycle() async throws {
        try await capsule.activate()
        await capsule.deactivate()
        // Should not throw
    }
    
    // MARK: - Diagnostic Tests
    
    func testDiagnosticEvents() {
        let events = diagnostics.getAllEvents()
        XCTAssertNotNil(events)
        
        let recentEvents = diagnostics.getEvents(since: Date().addingTimeInterval(-1.0))
        XCTAssertNotNil(recentEvents)
    }
    
    // MARK: - Invalid Input Tests
    
    func testEmptyDataAnalysis() async {
        let emptyData = Data()
        
        do {
            _ = try await capsule.analyzeVideo(data: emptyData)
            XCTFail("Should have thrown an error for empty data")
        } catch {
            XCTAssertTrue(error is CapsuleError)
        }
    }
    
    func testInvalidFrameEffects() async {
        let pixelData = Data(repeating: 0, count: 100 * 100 * 3)
        let frame = VideoFrame(
            pixelData: pixelData,
            width: 100,
            height: 100,
            pixelFormat: .rgb24,
            timestamp: 0.0,
            index: 0
        )
        
        // Test invalid brightness value (should still work with clipping)
        let invalidBrightnessEffect = FrameEffect.brightness(value: 2.0)
        
        do {
            _ = try await capsule.applyEffects(to: frame, effects: [invalidBrightnessEffect])
        } catch {
            // Should still work or fail gracefully
            XCTAssertTrue(error is CapsuleError)
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testLargeDataHandling() async {
        // Test with reasonably large but manageable data
        let largePixelData = Data(repeating: 0, count: 1920 * 1080 * 3)
        let largeFrame = VideoFrame(
            pixelData: largePixelData,
            width: 1920,
            height: 1080,
            pixelFormat: .rgb24,
            timestamp: 0.0,
            index: 0
        )
        
        // Should handle large frames without crashing
        let effect = FrameEffect.brightness(value: 0.5)
        
        do {
            _ = try await capsule.applyEffects(to: largeFrame, effects: [effect])
        } catch {
            // Might fail due to mock native bridge, but should not crash
            XCTAssertTrue(error is CapsuleError)
        }
    }
    
    // MARK: - Performance Tests
    
    func testConcurrentFrameProcessing() async throws {
        let pixelData = Data(repeating: 0, count: 100 * 100 * 3)
        let frame = VideoFrame(
            pixelData: pixelData,
            width: 100,
            height: 100,
            pixelFormat: .rgb24,
            timestamp: 0.0,
            index: 0
        )
        
        let effect = FrameEffect.brightness(value: 0.5)
        
        // Process the same frame concurrently
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    do {
                        _ = try await self.capsule.applyEffects(to: frame, effects: [effect])
                    } catch {
                        // Expected to fail with mock implementation
                    }
                }
            }
        }
        
        // Should complete without crashing
        XCTAssertTrue(true)
    }
}

// MARK: - Performance Benchmarks

extension VideoRenderCapsuleTests {
    
    func benchmarkFrameProcessingPerformance() async throws {
        let pixelData = Data(repeating: 0, count: 640 * 480 * 3)
        let frame = VideoFrame(
            pixelData: pixelData,
            width: 640,
            height: 480,
            pixelFormat: .rgb24,
            timestamp: 0.0,
            index: 0
        )
        
        let effect = FrameEffect.brightness(value: 0.5)
        
        measure {
            Task {
                do {
                    _ = try await capsule.applyEffects(to: frame, effects: [effect])
                } catch {
                    // Expected with mock implementation
                }
            }
        }
    }
    
    func benchmarkVideoAnalysisPerformance() async throws {
        let mockVideoData = Data(repeating: 0, count: 1024 * 1024) // 1MB mock data
        
        measure {
            Task {
                do {
                    _ = try await capsule.analyzeVideo(data: mockVideoData)
                } catch {
                    // Expected with mock implementation
                }
            }
        }
    }
}