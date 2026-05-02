// VideoRenderCapsule.swift
// VideoRenderCapsule - Swift actor wrapper for video processing and rendering
// Supports MP4, WebM, AVI, MOV formats with FFmpeg-based decoding/encoding and frame manipulation

import Foundation
import AnigmaNativeShims
import CapsuleCore
import TelemetryCore

// MARK: - Error Types

/// Errors that can occur during video processing operations
public enum VideoRenderError: Error, Sendable, CustomStringConvertible {
    case nullPointer
    case invalidData
    case unsupportedFormat
    case decodeFailed
    case encodeFailed
    case memoryAllocation
    case invalidDimensions
    case invalidFrameRate
    case invalidBitrate
    case codecNotFound
    case invalidParameters
    case audioProcessingFailed
    case effectFailed
    case thumbnailGenerationFailed
    case unknownError(Int32)
    
    init(code: Int32) {
        switch code {
        case VideoRenderNativeBridge.errorNullPointer:
            self = .nullPointer
        case VideoRenderNativeBridge.errorInvalidData:
            self = .invalidData
        case VideoRenderNativeBridge.errorUnsupportedFormat:
            self = .unsupportedFormat
        case VideoRenderNativeBridge.errorDecodeFailed:
            self = .decodeFailed
        case VideoRenderNativeBridge.errorEncodeFailed:
            self = .encodeFailed
        case VideoRenderNativeBridge.errorMemoryAllocation:
            self = .memoryAllocation
        case VideoRenderNativeBridge.errorInvalidDimensions:
            self = .invalidDimensions
        case VideoRenderNativeBridge.errorInvalidFrameRate:
            self = .invalidFrameRate
        case VideoRenderNativeBridge.errorInvalidBitrate:
            self = .invalidBitrate
        case VideoRenderNativeBridge.errorCodecNotFound:
            self = .codecNotFound
        case VideoRenderNativeBridge.errorInvalidParameters:
            self = .invalidParameters
        default:
            self = .unknownError(code)
        }
    }
    
    public var description: String {
        switch self {
        case .nullPointer: return "Null pointer provided"
        case .invalidData: return "Invalid or corrupted video data"
        case .unsupportedFormat: return "Unsupported video format"
        case .decodeFailed: return "Failed to decode video"
        case .encodeFailed: return "Failed to encode video"
        case .memoryAllocation: return "Memory allocation failed"
        case .invalidDimensions: return "Invalid video dimensions"
        case .invalidFrameRate: return "Invalid frame rate"
        case .invalidBitrate: return "Invalid bitrate"
        case .codecNotFound: return "Codec not found"
        case .invalidParameters: return "Invalid parameters"
        case .audioProcessingFailed: return "Audio processing failed"
        case .effectFailed: return "Frame effect failed"
        case .thumbnailGenerationFailed: return "Thumbnail generation failed"
        case .unknownError(let code): return "Unknown error: \(code)"
        }
    }
}

private extension VideoRenderError {
    var capsuleError: CapsuleError {
        switch self {
        case .nullPointer:
            return .internalError(details: "VideoRenderNative returned a null pointer")
        case .invalidData:
            return .invalidInput(field: "videoData", constraint: "invalid or corrupted data")
        case .unsupportedFormat:
            return .invalidInput(field: "format", constraint: "unsupported video format")
        case .decodeFailed:
            return .operationFailed(
                code: UInt32(VideoRenderNativeBridge.errorDecodeFailed),
                message: "Failed to decode video",
                context: ["library": "VideoRenderNative"]
            )
        case .encodeFailed:
            return .operationFailed(
                code: UInt32(VideoRenderNativeBridge.errorEncodeFailed),
                message: "Failed to encode video",
                context: ["library": "VideoRenderNative"]
            )
        case .memoryAllocation:
            return .resourceExhausted(resource: "memory", limit: "allocation failed")
        case .invalidDimensions:
            return .invalidInput(field: "dimensions", constraint: "invalid video dimensions")
        case .invalidFrameRate:
            return .invalidInput(field: "frameRate", constraint: "invalid frame rate")
        case .invalidBitrate:
            return .invalidInput(field: "bitrate", constraint: "invalid bitrate")
        case .codecNotFound:
            return .operationFailed(
                code: UInt32(VideoRenderNativeBridge.errorCodecNotFound),
                message: "Codec not found",
                context: ["library": "VideoRenderNative"]
            )
        case .invalidParameters:
            return .invalidInput(field: "parameters", constraint: "invalid parameters")
        case .audioProcessingFailed:
            return .operationFailed(
                code: 1001,
                message: "Audio processing failed",
                context: ["library": "VideoRenderNative"]
            )
        case .effectFailed:
            return .operationFailed(
                code: 1002,
                message: "Frame effect failed",
                context: ["library": "VideoRenderNative"]
            )
        case .thumbnailGenerationFailed:
            return .operationFailed(
                code: 1003,
                message: "Thumbnail generation failed",
                context: ["library": "VideoRenderNative"]
            )
        case .unknownError(let code):
            return .nativeError(code: code, libraryName: "VideoRenderNative")
        }
    }
}

// MARK: - Video Format

/// Supported video formats
public enum VideoFormat: UInt32, Sendable, Codable {
    case mp4 = 0x01
    case webm = 0x02
    case avi = 0x03
    case mov = 0x04
    case mkv = 0x05
    
    public var mimeType: String {
        switch self {
        case .mp4: return "video/mp4"
        case .webm: return "video/webm"
        case .avi: return "video/x-msvideo"
        case .mov: return "video/quicktime"
        case .mkv: return "video/x-matroska"
        }
    }
    
    public var fileExtension: String {
        switch self {
        case .mp4: return ".mp4"
        case .webm: return ".webm"
        case .avi: return ".avi"
        case .mov: return ".mov"
        case .mkv: return ".mkv"
        }
    }
    
    public var nativeFormat: UInt32 {
        switch self {
        case .mp4: return VideoRenderNativeBridge.formatMP4
        case .webm: return VideoRenderNativeBridge.formatWebM
        case .avi: return VideoRenderNativeBridge.formatAVI
        case .mov: return VideoRenderNativeBridge.formatMOV
        case .mkv: return VideoRenderNativeBridge.formatMKV
        }
    }
}

// MARK: - Video Codec

/// Supported video codecs
public enum VideoCodec: UInt32, Sendable, Codable {
    case h264 = 0x01
    case h265 = 0x02
    case vp9 = 0x03
    case av1 = 0x04
    case mpeg4 = 0x05
    
    public var name: String {
        switch self {
        case .h264: return "H.264"
        case .h265: return "H.265"
        case .vp9: return "VP9"
        case .av1: return "AV1"
        case .mpeg4: return "MPEG-4"
        }
    }
    
    public var nativeCodec: UInt32 {
        switch self {
        case .h264: return VideoRenderNativeBridge.codecH264
        case .h265: return VideoRenderNativeBridge.codecH265
        case .vp9: return VideoRenderNativeBridge.codecVP9
        case .av1: return VideoRenderNativeBridge.codecAV1
        case .mpeg4: return VideoRenderNativeBridge.codecMPEG4
        }
    }
}

// MARK: - Audio Codec

/// Supported audio codecs
public enum AudioCodec: UInt32, Sendable, Codable {
    case aac = 0x01
    case mp3 = 0x02
    case opus = 0x03
    case vorbis = 0x04
    case flac = 0x05
    
    public var name: String {
        switch self {
        case .aac: return "AAC"
        case .mp3: return "MP3"
        case .opus: return "Opus"
        case .vorbis: return "Vorbis"
        case .flac: return "FLAC"
        }
    }
    
    public var nativeCodec: UInt32 {
        switch self {
        case .aac: return VideoRenderNativeBridge.audioCodecAAC
        case .mp3: return VideoRenderNativeBridge.audioCodecMP3
        case .opus: return VideoRenderNativeBridge.audioCodecOpus
        case .vorbis: return VideoRenderNativeBridge.audioCodecVorbis
        case .flac: return VideoRenderNativeBridge.audioCodecFLAC
        }
    }
}

// MARK: - Pixel Format

/// Pixel format of video frames
public enum PixelFormat: Sendable, Codable {
    case yuv420p
    case rgb24
    case rgba32
    case bgra32
    case nv12
    
    var bytesPerPixel: Int {
        switch self {
        case .yuv420p: return 1 // Approximate, YUV420 is 1.5 bytes per pixel
        case .rgb24: return 3
        case .rgba32, .bgra32: return 4
        case .nv12: return 1 // Approximate, NV12 is 1.5 bytes per pixel
        }
    }
    
    public var description: String {
        switch self {
        case .yuv420p: return "YUV420P"
        case .rgb24: return "RGB24"
        case .rgba32: return "RGBA32"
        case .bgra32: return "BGRA32"
        case .nv12: return "NV12"
        }
    }
    
    public var nativeFormat: UInt32 {
        switch self {
        case .yuv420p: return VideoRenderNativeBridge.pixelFormatYUV420P
        case .rgb24: return VideoRenderNativeBridge.pixelFormatRGB24
        case .rgba32: return VideoRenderNativeBridge.pixelFormatRGBA32
        case .bgra32: return VideoRenderNativeBridge.pixelFormatBGRA32
        case .nv12: return VideoRenderNativeBridge.pixelFormatNV12
        }
    }
}

// MARK: - Frame Effect

/// Frame manipulation effects
public enum FrameEffect: Sendable, Codable {
    case resize(width: Int, height: Int)
    case crop(x: Int, y: Int, width: Int, height: Int)
    case rotate(degrees: Double)
    case flip(horizontal: Bool, vertical: Bool)
    case brightness(value: Double) // -1.0 to 1.0
    case contrast(value: Double)    // 0.0 to 2.0
    case saturation(value: Double)  // 0.0 to 2.0
    
    public var nativeEffect: (type: UInt32, params: VideoRenderNativeBridge.effect_params_t) {
        var params = VideoRenderNativeBridge.effect_params_t(
            effect_type: 0,
            param1: 0.0,
            param2: 0.0,
            param3: 0.0,
            param4: 0.0
        )
        
        switch self {
        case .resize(let width, let height):
            params.effect_type = VideoRenderNativeBridge.effectResize
            params.param1 = Double(width)
            params.param2 = Double(height)
            
        case .crop(let x, let y, let width, let height):
            params.effect_type = VideoRenderNativeBridge.effectCrop
            params.param1 = Double(x)
            params.param2 = Double(y)
            params.param3 = Double(width)
            params.param4 = Double(height)
            
        case .rotate(let degrees):
            params.effect_type = VideoRenderNativeBridge.effectRotate
            params.param1 = degrees
            
        case .flip(let horizontal, let vertical):
            params.effect_type = VideoRenderNativeBridge.effectFlip
            params.param1 = horizontal ? 1.0 : 0.0
            params.param2 = vertical ? 1.0 : 0.0
            
        case .brightness(let value):
            params.effect_type = VideoRenderNativeBridge.effectBrightness
            params.param1 = value
            
        case .contrast(let value):
            params.effect_type = VideoRenderNativeBridge.effectContrast
            params.param1 = value
            
        case .saturation(let value):
            params.effect_type = VideoRenderNativeBridge.effectSaturation
            params.param1 = value
        }
        
        return (params.effect_type, params)
    }
}

// MARK: - Video Info

/// Video metadata and information
public struct VideoInfo: Sendable, Codable {
    /// Video width in pixels
    public let width: Int
    
    /// Video height in pixels
    public let height: Int
    
    /// Frame rate (frames per second)
    public let frameRate: Double
    
    /// Duration in seconds
    public let duration: Double
    
    /// Bitrate in bits per second
    public let bitrate: Int
    
    /// Video format
    public let format: VideoFormat
    
    /// Video codec
    public let videoCodec: VideoCodec
    
    /// Audio codec (if present)
    public let audioCodec: AudioCodec?
    
    /// Pixel format
    public let pixelFormat: PixelFormat
    
    /// Audio sample rate (if audio present)
    public let audioSampleRate: Int?
    
    /// Number of audio channels (if audio present)
    public let audioChannels: Int?
    
    /// Total frame count
    public let frameCount: Int
    
    /// Whether video has audio track
    public var hasAudio: Bool { audioCodec != nil }
    
    /// Aspect ratio
    public var aspectRatio: Double { Double(width) / Double(height) }
    
    public init(
        width: Int,
        height: Int,
        frameRate: Double,
        duration: Double,
        bitrate: Int,
        format: VideoFormat,
        videoCodec: VideoCodec,
        audioCodec: AudioCodec? = nil,
        pixelFormat: PixelFormat,
        audioSampleRate: Int? = nil,
        audioChannels: Int? = nil,
        frameCount: Int
    ) {
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.duration = duration
        self.bitrate = bitrate
        self.format = format
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.pixelFormat = pixelFormat
        self.audioSampleRate = audioSampleRate
        self.audioChannels = audioChannels
        self.frameCount = frameCount
    }
}

// MARK: - Video Frame

/// A single video frame with metadata
public struct VideoFrame: Sendable {
    /// Raw frame data
    public let pixelData: Data
    
    /// Frame width in pixels
    public let width: Int
    
    /// Frame height in pixels
    public let height: Int
    
    /// Pixel format
    public let pixelFormat: PixelFormat
    
    /// Frame timestamp in seconds
    public let timestamp: Double
    
    /// Frame index
    public let index: Int
    
    /// Bytes per row (stride)
    public var bytesPerRow: Int {
        width * pixelFormat.bytesPerPixel
    }
    
    /// Frame size in bytes
    public var dataSizeBytes: Int {
        pixelData.count
    }
    
    public init(
        pixelData: Data,
        width: Int,
        height: Int,
        pixelFormat: PixelFormat,
        timestamp: Double,
        index: Int
    ) {
        self.pixelData = pixelData
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        self.timestamp = timestamp
        self.index = index
    }
}

// MARK: - Encoding Parameters

/// Parameters for video encoding
public struct EncodingParameters: Sendable, Codable {
    /// Output video format
    public let format: VideoFormat
    
    /// Video codec
    public let videoCodec: VideoCodec
    
    /// Audio codec
    public let audioCodec: AudioCodec?
    
    /// Output width (optional, keeps original if nil)
    public let width: Int?
    
    /// Output height (optional, keeps original if nil)
    public let height: Int?
    
    /// Frame rate (optional, keeps original if nil)
    public let frameRate: Double?
    
    /// Video bitrate in bits per second
    public let videoBitrate: Int
    
    /// Audio bitrate in bits per second (if audio present)
    public let audioBitrate: Int?
    
    /// Audio sample rate (if audio present)
    public let audioSampleRate: Int?
    
    /// Number of audio channels (if audio present)
    public let audioChannels: Int?
    
    public init(
        format: VideoFormat,
        videoCodec: VideoCodec,
        audioCodec: AudioCodec? = nil,
        width: Int? = nil,
        height: Int? = nil,
        frameRate: Double? = nil,
        videoBitrate: Int,
        audioBitrate: Int? = nil,
        audioSampleRate: Int? = nil,
        audioChannels: Int? = nil
    ) {
        self.format = format
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.videoBitrate = videoBitrate
        self.audioBitrate = audioBitrate
        self.audioSampleRate = audioSampleRate
        self.audioChannels = audioChannels
    }
}

// MARK: - VideoRenderCapsule Actor

/// Thread-safe actor for video processing and rendering
public actor VideoRenderCapsule {
    
    // MARK: - Properties
    
    /// Library version
    public nonisolated var version: String {
        VideoRenderNativeBridge.version()
    }
    
    /// FFmpeg version
    public nonisolated var ffmpegVersion: String {
        VideoRenderNativeBridge.ffmpegVersion()
    }
    
    /// Optional diagnostics collector
    private let diagnostics: CapsuleDiagnostics?
    
    // MARK: - Initialization
    
    /// Initialize the capsule
    /// - Parameter diagnostics: Optional diagnostics collector for span tracking
    public init(diagnostics: CapsuleDiagnostics? = nil) {
        self.diagnostics = diagnostics
    }
    
    // MARK: - Video Analysis
    
    /// Analyze video and extract metadata
    /// - Parameter data: Video data to analyze
    /// - Returns: Video information
    /// - Throws: CapsuleError on analysis failure
    public func analyzeVideo(data: Data) async throws -> VideoInfo {
        let span = diagnostics?.beginSpan(
            name: "video.analyze",
            category: "VideoRenderCapsule",
            correlationID: nil,
            tags: ["data_size": "\(data.count)"]
        )
        defer { span?.end(status: .ok) }
        
        return try await withCheckedThrowingContinuation { continuation in
            data.withUnsafeBytes { buffer in
                guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    span?.end(status: .error)
                    continuation.resume(throwing: VideoRenderError.nullPointer.capsuleError)
                    return
                }
                
                var info = VideoRenderNativeBridge.video_info_t()
                
                guard let decoder = VideoRenderNativeBridge.openVideoDecoder(
                    data: ptr,
                    size: UInt64(buffer.count),
                    info: &info
                ) else {
                    span?.end(status: .error)
                    continuation.resume(throwing: VideoRenderError.decodeFailed.capsuleError)
                    return
                }
                
                VideoRenderNativeBridge.closeVideoDecoder(decoder)
                
                let format = VideoFormat(rawValue: info.format) ?? .mp4
                let videoCodec = VideoCodec(rawValue: info.video_codec) ?? .h264
                let audioCodec = info.has_audio ? AudioCodec(rawValue: info.audioCodec) : nil
                let pixelFormat = PixelFormat(rawValue: info.pixelFormat) ?? .yuv420p
                
                let videoInfo = VideoInfo(
                    width: Int(info.width),
                    height: Int(info.height),
                    frameRate: info.frame_rate,
                    duration: info.duration,
                    bitrate: Int(info.bitrate),
                    format: format,
                    videoCodec: videoCodec,
                    audioCodec: audioCodec,
                    pixelFormat: pixelFormat,
                    audioSampleRate: info.has_audio ? Int(info.audio_sample_rate) : nil,
                    audioChannels: info.has_audio ? Int(info.audio_channels) : nil,
                    frameCount: Int(info.frame_count)
                )
                
                span?.addTag(key: "width", value: String(info.width))
                span?.addTag(key: "height", value: String(info.height))
                span?.addTag(key: "duration", value: String(info.duration))
                span?.addTag(key: "format", value: format.mimeType)
                
                continuation.resume(returning: videoInfo)
            }
        }
    }
    
    // MARK: - Video Decoding
    
    /// Decode video frames
    /// - Parameters:
    ///   - data: Video data to decode
    ///   - maxFrames: Maximum number of frames to decode (nil for all)
    ///   - progress: Progress callback (0.0 to 1.0)
    /// - Returns: Array of video frames
    /// - Throws: CapsuleError on decode failure
    public func decodeVideo(
        data: Data,
        maxFrames: Int? = nil,
        progress: ((Double) -> Void)? = nil
    ) async throws -> [VideoFrame] {
        let span = diagnostics?.beginSpan(
            name: "video.decode",
            category: "VideoRenderCapsule",
            correlationID: nil,
            tags: [
                "data_size": "\(data.count)",
                "max_frames": maxFrames != nil ? "\(maxFrames!)" : "all"
            ]
        )
        defer { span?.end(status: .ok) }
        
        return try await withCheckedThrowingContinuation { continuation in
            data.withUnsafeBytes { buffer in
                guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    span?.end(status: .error)
                    continuation.resume(throwing: VideoRenderError.nullPointer.capsuleError)
                    return
                }
                
                var info = VideoRenderNativeBridge.video_info_t()
                
                guard let decoder = VideoRenderNativeBridge.openVideoDecoder(
                    data: ptr,
                    size: UInt64(buffer.count),
                    info: &info
                ) else {
                    span?.end(status: .error)
                    continuation.resume(throwing: VideoRenderError.decodeFailed.capsuleError)
                    return
                }
                
                defer { VideoRenderNativeBridge.closeVideoDecoder(decoder) }
                
                var frames: [VideoFrame] = []
                var frameIndex = 0
                let totalFrames = maxFrames ?? Int(info.frame_count)
                
                while frameIndex < totalFrames {
                    var frameData: UnsafeMutablePointer<UInt8>?
                    var frameInfo = VideoRenderNativeBridge.frame_info_t()
                    
                    let result = VideoRenderNativeBridge.decodeNextFrame(
                        decoder: decoder,
                        frameData: &frameData,
                        frameInfo: &frameInfo
                    )
                    
                    if result != VideoRenderNativeBridge.success {
                        if result == -1 { // End of stream
                            break
                        } else {
                            span?.end(status: .error)
                            continuation.resume(throwing: VideoRenderError.decodeFailed.capsuleError)
                            return
                        }
                    }
                    
                    guard let framePtr = frameData else {
                        span?.end(status: .error)
                        continuation.resume(throwing: VideoRenderError.nullPointer.capsuleError)
                        return
                    }
                    
                    // Create Data from frame buffer
                    let pixelData = Data(
                        bytesNoCopy: framePtr,
                        count: Int(frameInfo.data_size),
                        deallocator: .custom { _, _ in
                            VideoRenderNativeBridge.freeFrameData(framePtr)
                        }
                    )
                    
                    let pixelFormat = PixelFormat(rawValue: frameInfo.pixel_format) ?? .yuv420p
                    
                    let frame = VideoFrame(
                        pixelData: pixelData,
                        width: Int(frameInfo.width),
                        height: Int(frameInfo.height),
                        pixelFormat: pixelFormat,
                        timestamp: frameInfo.timestamp,
                        index: frameIndex
                    )
                    
                    frames.append(frame)
                    
                    // Report progress
                    let progressValue = Double(frameIndex + 1) / Double(totalFrames)
                    progress?(progressValue)
                    
                    frameIndex += 1
                }
                
                span?.addTag(key: "frames_decoded", value: String(frames.count))
                
                continuation.resume(returning: frames)
            }
        }
    }
    
    // MARK: - Video Encoding
    
    /// Encode video frames to a video file
    /// - Parameters:
    ///   - frames: Array of video frames to encode
    ///   - parameters: Encoding parameters
    ///   - progress: Progress callback (0.0 to 1.0)
    /// - Returns: Encoded video data
    /// - Throws: CapsuleError on encode failure
    public func encodeVideo(
        frames: [VideoFrame],
        parameters: EncodingParameters,
        progress: ((Double) -> Void)? = nil
    ) async throws -> Data {
        let span = diagnostics?.beginSpan(
            name: "video.encode",
            category: "VideoRenderCapsule",
            correlationID: nil,
            tags: [
                "frame_count": "\(frames.count)",
                "format": parameters.format.mimeType,
                "video_codec": parameters.videoCodec.name
            ]
        )
        defer { span?.end(status: .ok) }
        
        guard !frames.isEmpty else {
            span?.end(status: .error)
            throw CapsuleError.invalidInput(field: "frames", constraint: "cannot be empty")
        }
        
        let firstFrame = frames[0]
        let width = parameters.width ?? firstFrame.width
        let height = parameters.height ?? firstFrame.height
        let frameRate = parameters.frameRate ?? 30.0 // Default if not specified
        
        guard let encoder = VideoRenderNativeBridge.openVideoEncoder(
            format: parameters.format.nativeFormat,
            videoCodec: parameters.videoCodec.nativeCodec,
            audioCodec: parameters.audioCodec?.nativeCodec ?? 0,
            width: UInt32(width),
            height: UInt32(height),
            frameRate: frameRate,
            bitrate: UInt64(parameters.videoBitrate),
            audioSampleRate: UInt32(parameters.audioSampleRate ?? 44100),
            audioChannels: UInt32(parameters.audioChannels ?? 2)
        ) else {
            span?.end(status: .error)
            throw VideoRenderError.encodeFailed.capsuleError
        }
        
        defer { VideoRenderNativeBridge.closeVideoEncoder(encoder) }
        
        var encodedChunks: [Data] = []
        
        for (index, frame) in frames.enumerated() {
            let result = frame.pixelData.withUnsafeBytes { buffer in
                guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return VideoRenderNativeBridge.errorNullPointer
                }
                
                guard let outputData = VideoRenderNativeBridge.encodeFrame(
                    encoder: encoder,
                    frameData: ptr,
                    dataSize: UInt64(buffer.count),
                    timestamp: frame.timestamp
                ) else {
                    return VideoRenderNativeBridge.errorEncodeFailed
                }
                
                let chunk = Data(
                    bytesNoCopy: outputData,
                    count: 0, // Size will be determined by finalize step
                    deallocator: .custom { _, _ in
                        VideoRenderNativeBridge.freeEncodedData(outputData)
                    }
                )
                
                encodedChunks.append(chunk)
                return VideoRenderNativeBridge.success
            }
            
            if result != VideoRenderNativeBridge.success {
                span?.end(status: .error)
                throw VideoRenderError.encodeFailed.capsuleError
            }
            
            // Report progress
            let progressValue = Double(index + 1) / Double(frames.count)
            progress?(progressValue)
        }
        
        // Finalize encoding
        var finalOutputData: UnsafeMutablePointer<UInt8>?
        var finalOutputSize: UInt64 = 0
        
        let result = VideoRenderNativeBridge.finalizeEncoding(
            encoder: encoder,
            outputData: &finalOutputData,
            outputSize: &finalOutputSize
        )
        
        guard result == VideoRenderNativeBridge.success,
              let outputPtr = finalOutputData else {
            span?.end(status: .error)
            throw VideoRenderError.encodeFailed.capsuleError
        }
        
        let finalData = Data(
            bytesNoCopy: outputPtr,
            count: Int(finalOutputSize),
            deallocator: .custom { _, _ in
                VideoRenderNativeBridge.freeEncodedData(outputPtr)
            }
        )
        
        span?.addTag(key: "output_size", value: String(finalData.count))
        
        return finalData
    }
    
    // MARK: - Frame Manipulation
    
    /// Apply effects to a video frame
    /// - Parameters:
    ///   - frame: Input frame
    ///   - effects: Array of effects to apply
    /// - Returns: Processed frame
    /// - Throws: CapsuleError on effect failure
    public func applyEffects(
        to frame: VideoFrame,
        effects: [FrameEffect]
    ) async throws -> VideoFrame {
        let span = diagnostics?.beginSpan(
            name: "frame.apply_effects",
            category: "VideoRenderCapsule",
            correlationID: nil,
            tags: [
                "effect_count": "\(effects.count)",
                "frame_index": "\(frame.index)"
            ]
        )
        defer { span?.end(status: .ok) }
        
        var currentFrame = frame
        
        for effect in effects {
            currentFrame = try await applySingleEffect(to: currentFrame, effect: effect)
        }
        
        span?.addTag(key: "effects_applied", value: String(effects.count))
        
        return currentFrame
    }
    
    private func applySingleEffect(
        to frame: VideoFrame,
        effect: FrameEffect
    ) async throws -> VideoFrame {
        let (effectType, params) = effect.nativeEffect
        
        return try await withCheckedThrowingContinuation { continuation in
            frame.pixelData.withUnsafeBytes { buffer in
                guard let inputPtr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    continuation.resume(throwing: VideoRenderError.nullPointer.capsuleError)
                    return
                }
                
                var outputData: UnsafeMutablePointer<UInt8>?
                var outputSize: UInt64 = 0
                
                let result = VideoRenderNativeBridge.applyEffect(
                    inputData: inputPtr,
                    inputSize: UInt64(buffer.count),
                    outputData: &outputData,
                    outputSize: &outputSize,
                    inputWidth: UInt32(frame.width),
                    inputHeight: UInt32(frame.height),
                    inputFormat: frame.pixelFormat.nativeFormat,
                    params: &params
                )
                
                guard result == VideoRenderNativeBridge.success,
                      let outputPtr = outputData else {
                    continuation.resume(throwing: VideoRenderError.effectFailed.capsuleError)
                    return
                }
                
                let processedData = Data(
                    bytesNoCopy: outputPtr,
                    count: Int(outputSize),
                    deallocator: .custom { _, _ in
                        VideoRenderNativeBridge.freeProcessedData(outputPtr)
                    }
                )
                
                // Calculate new dimensions based on effect type
                var newWidth = frame.width
                var newHeight = frame.height
                
                switch effect {
                case .resize(let width, let height):
                    newWidth = width
                    newHeight = height
                case .crop(_, _, let width, let height):
                    newWidth = width
                    newHeight = height
                default:
                    break // Other effects don't change dimensions
                }
                
                let processedFrame = VideoFrame(
                    pixelData: processedData,
                    width: newWidth,
                    height: newHeight,
                    pixelFormat: frame.pixelFormat,
                    timestamp: frame.timestamp,
                    index: frame.index
                )
                
                continuation.resume(returning: processedFrame)
            }
        }
    }
    
    // MARK: - Audio Processing
    
    /// Extract audio from video
    /// - Parameter data: Video data
    /// - Returns: Audio data and metadata
    /// - Throws: CapsuleError on extraction failure
    public func extractAudio(from data: Data) async throws -> (audioData: Data, format: AudioCodec, sampleRate: Int, channels: Int) {
        let span = diagnostics?.beginSpan(
            name: "audio.extract",
            category: "VideoRenderCapsule",
            correlationID: nil,
            tags: ["data_size": "\(data.count)"]
        )
        defer { span?.end(status: .ok) }
        
        return try await withCheckedThrowingContinuation { continuation in
            data.withUnsafeBytes { buffer in
                guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    span?.end(status: .error)
                    continuation.resume(throwing: VideoRenderError.nullPointer.capsuleError)
                    return
                }
                
                var audioData: UnsafeMutablePointer<UInt8>?
                var audioSize: UInt64 = 0
                var audioFormat: UInt32 = 0
                var sampleRate: UInt32 = 0
                var channels: UInt32 = 0
                
                let result = VideoRenderNativeBridge.extractAudio(
                    videoData: ptr,
                    videoSize: UInt64(buffer.count),
                    audioData: &audioData,
                    audioSize: &audioSize,
                    audioFormat: &audioFormat,
                    sampleRate: &sampleRate,
                    channels: &channels
                )
                
                guard result == VideoRenderNativeBridge.success,
                      let audioPtr = audioData else {
                    span?.end(status: .error)
                    continuation.resume(throwing: VideoRenderError.audioProcessingFailed.capsuleError)
                    return
                }
                
                let extractedAudio = Data(
                    bytesNoCopy: audioPtr,
                    count: Int(audioSize),
                    deallocator: .custom { _, _ in
                        VideoRenderNativeBridge.freeAudioData(audioPtr)
                    }
                )
                
                let codec = AudioCodec(rawValue: audioFormat) ?? .aac
                
                span?.addTag(key: "audio_format", value: codec.name)
                span?.addTag(key: "sample_rate", value: String(sampleRate))
                span?.addTag(key: "channels", value: String(channels))
                
                continuation.resume(returning: (
                    audioData: extractedAudio,
                    format: codec,
                    sampleRate: Int(sampleRate),
                    channels: Int(channels)
                ))
            }
        }
    }
    
    /// Process audio with volume adjustment and fades
    /// - Parameters:
    ///   - audioData: Raw audio data
    ///   - format: Audio codec format
    ///   - sampleRate: Sample rate
    ///   - channels: Number of channels
    ///   - volume: Volume multiplier (1.0 = original)
    ///   - fadeInDuration: Fade in duration in seconds
    ///   - fadeOutDuration: Fade out duration in seconds
    /// - Returns: Processed audio data
    /// - Throws: CapsuleError on processing failure
    public func processAudio(
        _ audioData: Data,
        format: AudioCodec,
        sampleRate: Int,
        channels: Int,
        volume: Double = 1.0,
        fadeInDuration: Double = 0.0,
        fadeOutDuration: Double = 0.0
    ) async throws -> Data {
        let span = diagnostics?.beginSpan(
            name: "audio.process",
            category: "VideoRenderCapsule",
            correlationID: nil,
            tags: [
                "format": format.name,
                "sample_rate": "\(sampleRate)",
                "channels": "\(channels)",
                "volume": "\(volume)"
            ]
        )
        defer { span?.end(status: .ok) }
        
        return try await withCheckedThrowingContinuation { continuation in
            audioData.withUnsafeBytes { buffer in
                guard let inputPtr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    span?.end(status: .error)
                    continuation.resume(throwing: VideoRenderError.nullPointer.capsuleError)
                    return
                }
                
                var outputData: UnsafeMutablePointer<UInt8>?
                var outputSize: UInt64 = 0
                
                let result = VideoRenderNativeBridge.processAudio(
                    inputData: inputPtr,
                    inputSize: UInt64(buffer.count),
                    outputData: &outputData,
                    outputSize: &outputSize,
                    sampleRate: UInt32(sampleRate),
                    channels: UInt32(channels),
                    volume: volume,
                    fadeInDuration: fadeInDuration,
                    fadeOutDuration: fadeOutDuration
                )
                
                guard result == VideoRenderNativeBridge.success,
                      let outputPtr = outputData else {
                    span?.end(status: .error)
                    continuation.resume(throwing: VideoRenderError.audioProcessingFailed.capsuleError)
                    return
                }
                
                let processedAudio = Data(
                    bytesNoCopy: outputPtr,
                    count: Int(outputSize),
                    deallocator: .custom { _, _ in
                        VideoRenderNativeBridge.freeAudioData(outputPtr)
                    }
                )
                
                span?.addTag(key: "output_size", value: String(outputSize))
                
                continuation.resume(returning: processedAudio)
            }
        }
    }
    
    // MARK: - Thumbnail Generation
    
    /// Generate thumbnail from video
    /// - Parameters:
    ///   - data: Video data
    ///   - width: Thumbnail width
    ///   - height: Thumbnail height
    ///   - timestamp: Timestamp in seconds for thumbnail extraction
    /// - Returns: Thumbnail image data (JPEG format)
    /// - Throws: CapsuleError on generation failure
    public func generateThumbnail(
        from data: Data,
        width: Int,
        height: Int,
        timestamp: Double = 0.0
    ) async throws -> Data {
        let span = diagnostics?.beginSpan(
            name: "video.generate_thumbnail",
            category: "VideoRenderCapsule",
            correlationID: nil,
            tags: [
                "width": "\(width)",
                "height": "\(height)",
                "timestamp": "\(timestamp)"
            ]
        )
        defer { span?.end(status: .ok) }
        
        return try await withCheckedThrowingContinuation { continuation in
            data.withUnsafeBytes { buffer in
                guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    span?.end(status: .error)
                    continuation.resume(throwing: VideoRenderError.nullPointer.capsuleError)
                    return
                }
                
                var thumbnailData: UnsafeMutablePointer<UInt8>?
                var thumbnailSize: UInt64 = 0
                
                let result = VideoRenderNativeBridge.generateThumbnail(
                    videoData: ptr,
                    videoSize: UInt64(buffer.count),
                    thumbnailData: &thumbnailData,
                    thumbnailSize: &thumbnailSize,
                    thumbnailWidth: UInt32(width),
                    thumbnailHeight: UInt32(height),
                    timestamp: timestamp
                )
                
                guard result == VideoRenderNativeBridge.success,
                      let thumbnailPtr = thumbnailData else {
                    span?.end(status: .error)
                    continuation.resume(throwing: VideoRenderError.thumbnailGenerationFailed.capsuleError)
                    return
                }
                
                let thumbnail = Data(
                    bytesNoCopy: thumbnailPtr,
                    count: Int(thumbnailSize),
                    deallocator: .custom { _, _ in
                        VideoRenderNativeBridge.freeThumbnailData(thumbnailPtr)
                    }
                )
                
                span?.addTag(key: "thumbnail_size", value: String(thumbnailSize))
                
                continuation.resume(returning: thumbnail)
            }
        }
    }
    
    // MARK: - Format Detection
    
    /// Detect video format from data
    /// - Parameter data: Video data
    /// - Returns: Detected video format
    public func detectFormat(data: Data) -> VideoFormat {
        let format = data.withUnsafeBytes { buffer in
            guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return VideoRenderNativeBridge.formatMP4
            }
            return VideoRenderNativeBridge.detectVideoFormat(data: ptr, size: UInt64(buffer.count))
        }
        
        return VideoFormat(rawValue: format) ?? .mp4
    }
    
    // MARK: - Batch Operations
    
    /// Batch decode multiple videos
    /// - Parameters:
    ///   - videos: Array of video data
    ///   - maxFramesPerVideo: Maximum frames per video
    /// - Returns: Array of frame arrays (nil for failed videos)
    public func decodeBatch(
        videos: [Data],
        maxFramesPerVideo: Int? = nil
    ) async -> [Result<[VideoFrame], CapsuleError>] {
        await withTaskGroup(of: (Int, Result<[VideoFrame], CapsuleError>).self) { group in
            for (index, videoData) in videos.enumerated() {
                group.addTask {
                    do {
                        let frames = try await self.decodeVideo(
                            data: videoData,
                            maxFrames: maxFramesPerVideo
                        )
                        return (index, .success(frames))
                    } catch {
                        let capsuleError = (error as? CapsuleError) ?? .internalError(details: "\(error)")
                        return (index, .failure(capsuleError))
                    }
                }
            }
            
            var results = [Result<[VideoFrame], CapsuleError>](repeating: .failure(.internalError(details: "Not processed")), count: videos.count)
            for await (index, result) in group {
                results[index] = result
            }
            return results
        }
    }
    
    /// Batch apply effects to multiple frames
    /// - Parameters:
    ///   - frames: Array of frames
    ///   - effects: Effects to apply to all frames
    /// - Returns: Array of processed frames (nil for failed frames)
    public func applyEffectsBatch(
        frames: [VideoFrame],
        effects: [FrameEffect]
    ) async -> [Result<VideoFrame, CapsuleError>] {
        await withTaskGroup(of: (Int, Result<VideoFrame, CapsuleError>).self) { group in
            for (index, frame) in frames.enumerated() {
                group.addTask {
                    do {
                        let processedFrame = try await self.applyEffects(to: frame, effects: effects)
                        return (index, .success(processedFrame))
                    } catch {
                        let capsuleError = (error as? CapsuleError) ?? .internalError(details: "\(error)")
                        return (index, .failure(capsuleError))
                    }
                }
            }
            
            var results = [Result<VideoFrame, CapsuleError>](repeating: .failure(.internalError(details: "Not processed")), count: frames.count)
            for await (index, result) in group {
                results[index] = result
            }
            return results
        }
    }
}

// MARK: - CapsuleCore Integration

/// Protocol for capsule lifecycle management
public protocol CapsuleLifecycle: Actor {
    func activate() async throws
    func deactivate() async
}

extension VideoRenderCapsule: CapsuleLifecycle {
    public func activate() async throws {
        // No initialization needed
    }
    
    public func deactivate() async {
        // No cleanup needed
    }
}