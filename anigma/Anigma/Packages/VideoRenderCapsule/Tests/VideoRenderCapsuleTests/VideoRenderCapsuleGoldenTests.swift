// VideoRenderCapsuleGoldenTests.swift
// Golden tests for VideoRenderCapsule deterministic output verification

import XCTest
@testable import VideoRenderCapsule
import CapsuleCore
import TelemetryCore

final class VideoRenderCapsuleGoldenTests: XCTestCase {
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
    
    // MARK: - Golden Test Fixtures
    
    /// Golden fixture for MP4 format detection
    func testMP4FormatDetectionGolden() {
        // Known MP4 header bytes (ftyp box)
        let mp4Header = Data([
            0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, // Box header and ftyp
            0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00, // isom
            0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32, // isomiso2
            0x61, 0x76, 0x63, 0x31, 0x6D, 0x70, 0x34, 0x31  // avc1mp41
        ])
        
        let detectedFormat = capsule.detectFormat(data: mp4Header)
        
        // Golden assertion - should always detect as MP4
        XCTAssertEqual(detectedFormat, .mp4, "MP4 format detection should be deterministic")
        XCTAssertEqual(detectedFormat.mimeType, "video/mp4")
        XCTAssertEqual(detectedFormat.fileExtension, ".mp4")
    }
    
    /// Golden fixture for WebM format detection
    func testWebMFormatDetectionGolden() {
        // Known WebM header bytes (EBML)
        let webmHeader = Data([
            0x1A, 0x45, 0xDF, 0xA3, 0x01, 0x00, 0x00, 0x00, // EBML header
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // Padding
            0x42, 0x86, 0x81, 0x01, 0x42, 0xF7, 0x81, 0x01  // EBML version
        ])
        
        let detectedFormat = capsule.detectFormat(data: webmHeader)
        
        // Golden assertion - should fall back to MP4 for unknown formats
        XCTAssertEqual(detectedFormat, .mp4, "Unknown format should fall back to MP4")
    }
    
    /// Golden fixture for video format properties
    func testVideoFormatPropertiesGolden() {
        // Test all format properties for deterministic behavior
        let formats: [VideoFormat] = [.mp4, .webm, .avi, .mov, .mkv]
        
        let expectedMimeTypes = [
            "video/mp4",
            "video/webm", 
            "video/x-msvideo",
            "video/quicktime",
            "video/x-matroska"
        ]
        
        let expectedExtensions = [
            ".mp4",
            ".webm",
            ".avi", 
            ".mov",
            ".mkv"
        ]
        
        for (index, format) in formats.enumerated() {
            XCTAssertEqual(format.mimeType, expectedMimeTypes[index], "MIME type should be deterministic for \(format)")
            XCTAssertEqual(format.fileExtension, expectedExtensions[index], "File extension should be deterministic for \(format)")
        }
    }
    
    /// Golden fixture for video codec properties
    func testVideoCodecPropertiesGolden() {
        let codecs: [VideoCodec] = [.h264, .h265, .vp9, .av1, .mpeg4]
        
        let expectedNames = [
            "H.264",
            "H.265", 
            "VP9",
            "AV1",
            "MPEG-4"
        ]
        
        for (index, codec) in codecs.enumerated() {
            XCTAssertEqual(codec.name, expectedNames[index], "Codec name should be deterministic for \(codec)")
        }
    }
    
    /// Golden fixture for audio codec properties
    func testAudioCodecPropertiesGolden() {
        let codecs: [AudioCodec] = [.aac, .mp3, .opus, .vorbis, .flac]
        
        let expectedNames = [
            "AAC",
            "MP3",
            "Opus", 
            "Vorbis",
            "FLAC"
        ]
        
        for (index, codec) in codecs.enumerated() {
            XCTAssertEqual(codec.name, expectedNames[index], "Audio codec name should be deterministic for \(codec)")
        }
    }
    
    /// Golden fixture for pixel format properties
    func testPixelFormatPropertiesGolden() {
        let formats: [PixelFormat] = [.yuv420p, .rgb24, .rgba32, .bgra32, .nv12]
        
        let expectedBytesPerPixel = [1, 3, 4, 4, 1] // Approximate for YUV formats
        let expectedDescriptions = ["YUV420P", "RGB24", "RGBA32", "BGRA32", "NV12"]
        
        for (index, format) in formats.enumerated() {
            XCTAssertEqual(format.bytesPerPixel, expectedBytesPerPixel[index], "Bytes per pixel should be deterministic for \(format)")
            XCTAssertEqual(format.description, expectedDescriptions[index], "Description should be deterministic for \(format)")
        }
    }
    
    /// Golden fixture for frame effect parameters
    func testFrameEffectParametersGolden() {
        // Test resize effect
        let resizeEffect = FrameEffect.resize(width: 640, height: 480)
        let (resizeType, resizeParams) = resizeEffect.nativeEffect
        XCTAssertEqual(resizeType, VideoRenderNativeBridge.effectResize)
        XCTAssertEqual(resizeParams.param1, 640.0)
        XCTAssertEqual(resizeParams.param2, 480.0)
        XCTAssertEqual(resizeParams.param3, 0.0)
        XCTAssertEqual(resizeParams.param4, 0.0)
        
        // Test crop effect
        let cropEffect = FrameEffect.crop(x: 10, y: 20, width: 300, height: 200)
        let (cropType, cropParams) = cropEffect.nativeEffect
        XCTAssertEqual(cropType, VideoRenderNativeBridge.effectCrop)
        XCTAssertEqual(cropParams.param1, 10.0)
        XCTAssertEqual(cropParams.param2, 20.0)
        XCTAssertEqual(cropParams.param3, 300.0)
        XCTAssertEqual(cropParams.param4, 200.0)
        
        // Test rotate effect
        let rotateEffect = FrameEffect.rotate(degrees: 90.0)
        let (rotateType, rotateParams) = rotateEffect.nativeEffect
        XCTAssertEqual(rotateType, VideoRenderNativeBridge.effectRotate)
        XCTAssertEqual(rotateParams.param1, 90.0)
        XCTAssertEqual(rotateParams.param2, 0.0)
        XCTAssertEqual(rotateParams.param3, 0.0)
        XCTAssertEqual(rotateParams.param4, 0.0)
        
        // Test flip effect
        let flipEffect = FrameEffect.flip(horizontal: true, vertical: false)
        let (flipType, flipParams) = flipEffect.nativeEffect
        XCTAssertEqual(flipType, VideoRenderNativeBridge.effectFlip)
        XCTAssertEqual(flipParams.param1, 1.0) // horizontal
        XCTAssertEqual(flipParams.param2, 0.0) // vertical
        XCTAssertEqual(flipParams.param3, 0.0)
        XCTAssertEqual(flipParams.param4, 0.0)
        
        // Test brightness effect
        let brightnessEffect = FrameEffect.brightness(value: 0.5)
        let (brightType, brightParams) = brightnessEffect.nativeEffect
        XCTAssertEqual(brightType, VideoRenderNativeBridge.effectBrightness)
        XCTAssertEqual(brightParams.param1, 0.5)
        XCTAssertEqual(brightParams.param2, 0.0)
        XCTAssertEqual(brightParams.param3, 0.0)
        XCTAssertEqual(brightParams.param4, 0.0)
        
        // Test contrast effect
        let contrastEffect = FrameEffect.contrast(value: 1.5)
        let (contrastType, contrastParams) = contrastEffect.nativeEffect
        XCTAssertEqual(contrastType, VideoRenderNativeBridge.effectContrast)
        XCTAssertEqual(contrastParams.param1, 1.5)
        XCTAssertEqual(contrastParams.param2, 0.0)
        XCTAssertEqual(contrastParams.param3, 0.0)
        XCTAssertEqual(contrastParams.param4, 0.0)
        
        // Test saturation effect
        let saturationEffect = FrameEffect.saturation(value: 0.8)
        let (satType, satParams) = saturationEffect.nativeEffect
        XCTAssertEqual(satType, VideoRenderNativeBridge.effectSaturation)
        XCTAssertEqual(satParams.param1, 0.8)
        XCTAssertEqual(satParams.param2, 0.0)
        XCTAssertEqual(satParams.param3, 0.0)
        XCTAssertEqual(satParams.param4, 0.0)
    }
    
    /// Golden fixture for video info calculations
    func testVideoInfoCalculationsGolden() {
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
        
        // Golden assertions for calculated properties
        XCTAssertTrue(videoInfo.hasAudio)
        XCTAssertEqual(videoInfo.aspectRatio, 1920.0 / 1080.0, accuracy: 0.001)
        XCTAssertEqual(videoInfo.aspectRatio, 1.7777777777777778, accuracy: 0.001)
        
        // Test with different aspect ratios
        let squareVideo = VideoInfo(
            width: 1080,
            height: 1080,
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
        
        XCTAssertFalse(squareVideo.hasAudio)
        XCTAssertEqual(squareVideo.aspectRatio, 1.0, accuracy: 0.001)
    }
    
    /// Golden fixture for video frame calculations
    func testVideoFrameCalculationsGolden() {
        let pixelData = Data(repeating: 0xFF, count: 640 * 480 * 4) // RGBA32
        let frame = VideoFrame(
            pixelData: pixelData,
            width: 640,
            height: 480,
            pixelFormat: .rgba32,
            timestamp: 1.5,
            index: 42
        )
        
        // Golden assertions for calculated properties
        XCTAssertEqual(frame.dataSizeBytes, 640 * 480 * 4)
        XCTAssertEqual(frame.dataSizeBytes, 1228800)
        XCTAssertEqual(frame.bytesPerRow, 640 * 4)
        XCTAssertEqual(frame.bytesPerRow, 2560)
        
        // Test with different pixel formats
        let rgb24Data = Data(repeating: 0x80, count: 320 * 240 * 3)
        let rgb24Frame = VideoFrame(
            pixelData: rgb24Data,
            width: 320,
            height: 240,
            pixelFormat: .rgb24,
            timestamp: 0.0,
            index: 0
        )
        
        XCTAssertEqual(rgb24Frame.dataSizeBytes, 320 * 240 * 3)
        XCTAssertEqual(rgb24Frame.dataSizeBytes, 230400)
        XCTAssertEqual(rgb24Frame.bytesPerRow, 320 * 3)
        XCTAssertEqual(rgb24Frame.bytesPerRow, 960)
    }
    
    /// Golden fixture for error descriptions
    func testErrorDescriptionsGolden() {
        let errors: [VideoRenderError] = [
            .nullPointer,
            .invalidData,
            .unsupportedFormat,
            .decodeFailed,
            .encodeFailed,
            .memoryAllocation,
            .invalidDimensions,
            .invalidFrameRate,
            .invalidBitrate,
            .codecNotFound,
            .invalidParameters,
            .audioProcessingFailed,
            .effectFailed,
            .thumbnailGenerationFailed
        ]
        
        let expectedDescriptions = [
            "Null pointer provided",
            "Invalid or corrupted video data",
            "Unsupported video format",
            "Failed to decode video",
            "Failed to encode video",
            "Memory allocation failed",
            "Invalid video dimensions",
            "Invalid frame rate",
            "Invalid bitrate",
            "Codec not found",
            "Invalid parameters",
            "Audio processing failed",
            "Frame effect failed",
            "Thumbnail generation failed"
        ]
        
        for (index, error) in errors.enumerated() {
            XCTAssertEqual(error.description, expectedDescriptions[index], "Error description should be deterministic for \(error)")
        }
    }
    
    /// Golden fixture for version strings
    func testVersionStringsGolden() {
        let version = capsule.version
        let ffmpegVersion = capsule.ffmpegVersion
        
        // Golden assertions - version strings should be non-empty and contain expected identifiers
        XCTAssertFalse(version.isEmpty, "Version string should not be empty")
        XCTAssertFalse(ffmpegVersion.isEmpty, "FFmpeg version string should not be empty")
        
        // Note: Actual version strings depend on the native implementation
        // but they should always be non-empty strings
    }
    
    /// Golden fixture for encoding parameters validation
    func testEncodingParametersValidationGolden() {
        let validParams = EncodingParameters(
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
        
        // Golden assertions for valid parameters
        XCTAssertEqual(validParams.format, .mp4)
        XCTAssertEqual(validParams.videoCodec, .h264)
        XCTAssertEqual(validParams.audioCodec, .aac)
        XCTAssertEqual(validParams.width, 1280)
        XCTAssertEqual(validParams.height, 720)
        XCTAssertEqual(validParams.frameRate, 30.0)
        XCTAssertEqual(validParams.videoBitrate, 3000000)
        XCTAssertEqual(validParams.audioBitrate, 128000)
        XCTAssertEqual(validParams.audioSampleRate, 44100)
        XCTAssertEqual(validParams.audioChannels, 2)
        
        // Test parameters with optional values
        let minimalParams = EncodingParameters(
            format: .webm,
            videoCodec: .vp9,
            videoBitrate: 2000000
        )
        
        XCTAssertEqual(minimalParams.format, .webm)
        XCTAssertEqual(minimalParams.videoCodec, .vp9)
        XCTAssertNil(minimalParams.audioCodec)
        XCTAssertNil(minimalParams.width)
        XCTAssertNil(minimalParams.height)
        XCTAssertNil(minimalParams.frameRate)
        XCTAssertEqual(minimalParams.videoBitrate, 2000000)
        XCTAssertNil(minimalParams.audioBitrate)
        XCTAssertNil(minimalParams.audioSampleRate)
        XCTAssertNil(minimalParams.audioChannels)
    }
    
    /// Golden fixture for native format/code mapping
    func testNativeMappingGolden() {
        // Test video format native mapping
        XCTAssertEqual(VideoFormat.mp4.nativeFormat, VideoRenderNativeBridge.formatMP4)
        XCTAssertEqual(VideoFormat.webm.nativeFormat, VideoRenderNativeBridge.formatWebM)
        XCTAssertEqual(VideoFormat.avi.nativeFormat, VideoRenderNativeBridge.formatAVI)
        XCTAssertEqual(VideoFormat.mov.nativeFormat, VideoRenderNativeBridge.formatMOV)
        XCTAssertEqual(VideoFormat.mkv.nativeFormat, VideoRenderNativeBridge.formatMKV)
        
        // Test video codec native mapping
        XCTAssertEqual(VideoCodec.h264.nativeCodec, VideoRenderNativeBridge.codecH264)
        XCTAssertEqual(VideoCodec.h265.nativeCodec, VideoRenderNativeBridge.codecH265)
        XCTAssertEqual(VideoCodec.vp9.nativeCodec, VideoRenderNativeBridge.codecVP9)
        XCTAssertEqual(VideoCodec.av1.nativeCodec, VideoRenderNativeBridge.codecAV1)
        XCTAssertEqual(VideoCodec.mpeg4.nativeCodec, VideoRenderNativeBridge.codecMPEG4)
        
        // Test audio codec native mapping
        XCTAssertEqual(AudioCodec.aac.nativeCodec, VideoRenderNativeBridge.audioCodecAAC)
        XCTAssertEqual(AudioCodec.mp3.nativeCodec, VideoRenderNativeBridge.audioCodecMP3)
        XCTAssertEqual(AudioCodec.opus.nativeCodec, VideoRenderNativeBridge.audioCodecOpus)
        XCTAssertEqual(AudioCodec.vorbis.nativeCodec, VideoRenderNativeBridge.audioCodecVorbis)
        XCTAssertEqual(AudioCodec.flac.nativeCodec, VideoRenderNativeBridge.audioCodecFLAC)
        
        // Test pixel format native mapping
        XCTAssertEqual(PixelFormat.yuv420p.nativeFormat, VideoRenderNativeBridge.pixelFormatYUV420P)
        XCTAssertEqual(PixelFormat.rgb24.nativeFormat, VideoRenderNativeBridge.pixelFormatRGB24)
        XCTAssertEqual(PixelFormat.rgba32.nativeFormat, VideoRenderNativeBridge.pixelFormatRGBA32)
        XCTAssertEqual(PixelFormat.bgra32.nativeFormat, VideoRenderNativeBridge.pixelFormatBGRA32)
        XCTAssertEqual(PixelFormat.nv12.nativeFormat, VideoRenderNativeBridge.pixelFormatNV12)
    }
    
    /// Golden fixture for error code mapping
    func testErrorCodeMappingGolden() {
        // Test error code to enum mapping
        XCTAssertEqual(VideoRenderError(code: VideoRenderNativeBridge.errorNullPointer), .nullPointer)
        XCTAssertEqual(VideoRenderError(code: VideoRenderNativeBridge.errorInvalidData), .invalidData)
        XCTAssertEqual(VideoRenderError(code: VideoRenderNativeBridge.errorUnsupportedFormat), .unsupportedFormat)
        XCTAssertEqual(VideoRenderError(code: VideoRenderNativeBridge.errorDecodeFailed), .decodeFailed)
        XCTAssertEqual(VideoRenderError(code: VideoRenderNativeBridge.errorEncodeFailed), .encodeFailed)
        XCTAssertEqual(VideoRenderError(code: VideoRenderNativeBridge.errorMemoryAllocation), .memoryAllocation)
        XCTAssertEqual(VideoRenderError(code: VideoRenderNativeBridge.errorInvalidDimensions), .invalidDimensions)
        XCTAssertEqual(VideoRenderError(code: VideoRenderNativeBridge.errorInvalidFrameRate), .invalidFrameRate)
        XCTAssertEqual(VideoRenderError(code: VideoRenderNativeBridge.errorInvalidBitrate), .invalidBitrate)
        XCTAssertEqual(VideoRenderError(code: VideoRenderNativeBridge.errorCodecNotFound), .codecNotFound)
        XCTAssertEqual(VideoRenderError(code: VideoRenderNativeBridge.errorInvalidParameters), .invalidParameters)
        
        // Test unknown error code
        let unknownError = VideoRenderError(code: 9999)
        if case .unknownError(let code) = unknownError {
            XCTAssertEqual(code, 9999)
        } else {
            XCTFail("Should have returned unknownError for unknown code")
        }
    }
}