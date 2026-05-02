// AudioRenderCapsule.swift
// AudioRenderCapsule - Swift actor wrapper for audio processing and rendering
// Supports MP3, WAV, FLAC, AAC formats with effects and waveform visualization

import Foundation
import AnigmaNativeShims
import CapsuleCore
import TelemetryCore

// MARK: - Error Types

/// Errors that can occur during audio rendering operations
public enum AudioRenderError: Error, Sendable, CustomStringConvertible {
    case nullPointer
    case invalidData
    case unsupportedFormat
    case decodeFailed
    case memoryAllocation
    case invalidParameters
    case effectFailed
    case waveformFailed
    case unknownError(Int32)
    
    init(code: Int32) {
        switch code {
        case AudioRenderNativeBridge.errorNullPointer:
            self = .nullPointer
        case AudioRenderNativeBridge.errorInvalidData:
            self = .invalidData
        case AudioRenderNativeBridge.errorUnsupportedFormat:
            self = .unsupportedFormat
        case AudioRenderNativeBridge.errorDecodeFailed:
            self = .decodeFailed
        case AudioRenderNativeBridge.errorMemoryAllocation:
            self = .memoryAllocation
        case AudioRenderNativeBridge.errorInvalidParameters:
            self = .invalidParameters
        case AudioRenderNativeBridge.errorEffectFailed:
            self = .effectFailed
        case AudioRenderNativeBridge.errorWaveformFailed:
            self = .waveformFailed
        default:
            self = .unknownError(code)
        }
    }
    
    public var description: String {
        switch self {
        case .nullPointer: return "Null pointer provided"
        case .invalidData: return "Invalid or corrupted audio data"
        case .unsupportedFormat: return "Unsupported audio format"
        case .decodeFailed: return "Failed to decode audio"
        case .memoryAllocation: return "Memory allocation failed"
        case .invalidParameters: return "Invalid parameters provided"
        case .effectFailed: return "Audio effect processing failed"
        case .waveformFailed: return "Waveform generation failed"
        case .unknownError(let code): return "Unknown error: \(code)"
        }
    }
}

private extension AudioRenderError {
    var capsuleError: CapsuleError {
        switch self {
        case .nullPointer:
            return .internalError(details: "AudioRenderNative returned a null pointer")
        case .invalidData:
            return .invalidInput(field: "audioData", constraint: "invalid or corrupted data")
        case .unsupportedFormat:
            return .invalidInput(field: "format", constraint: "unsupported audio format")
        case .decodeFailed:
            return .operationFailed(
                code: UInt32(AudioRenderNativeBridge.errorDecodeFailed),
                message: "Failed to decode audio",
                context: ["library": "AudioRenderNative"]
            )
        case .memoryAllocation:
            return .resourceExhausted(resource: "memory", limit: "allocation failed")
        case .invalidParameters:
            return .invalidInput(field: "parameters", constraint: "invalid parameter values")
        case .effectFailed:
            return .operationFailed(
                code: UInt32(AudioRenderNativeBridge.errorEffectFailed),
                message: "Audio effect processing failed",
                context: ["library": "AudioRenderNative"]
            )
        case .waveformFailed:
            return .operationFailed(
                code: UInt32(AudioRenderNativeBridge.errorWaveformFailed),
                message: "Waveform generation failed",
                context: ["library": "AudioRenderNative"]
            )
        case .unknownError(let code):
            return .nativeError(code: code, libraryName: "AudioRenderNative")
        }
    }
}

// MARK: - Audio Format

/// Supported audio formats
public enum AudioFormat: UInt32, Sendable, Codable {
    case unknown = 0x00
    case mp3 = 0x01
    case wav = 0x02
    case flac = 0x03
    case aac = 0x04
    case ogg = 0x05
    
    public var mimeType: String {
        switch self {
        case .unknown: return "application/octet-stream"
        case .mp3: return "audio/mpeg"
        case .wav: return "audio/wav"
        case .flac: return "audio/flac"
        case .aac: return "audio/aac"
        case .ogg: return "audio/ogg"
        }
    }
    
    public var fileExtension: String {
        switch self {
        case .unknown: return ".bin"
        case .mp3: return ".mp3"
        case .wav: return ".wav"
        case .flac: return ".flac"
        case .aac: return ".aac"
        case .ogg: return ".ogg"
        }
    }
}

// MARK: - Sample Format

/// Audio sample format
public enum SampleFormat: UInt32, Sendable, Codable {
    case u8 = 0
    case s16 = 1
    case s32 = 2
    case f32 = 3
    case f64 = 4
    
    var bytesPerSample: Int {
        switch self {
        case .u8: return 1
        case .s16: return 2
        case .s32: return 4
        case .f32: return 4
        case .f64: return 8
        }
    }
    
    public var description: String {
        switch self {
        case .u8: return "Unsigned 8-bit"
        case .s16: return "Signed 16-bit"
        case .s32: return "Signed 32-bit"
        case .f32: return "Float 32-bit"
        case .f64: return "Float 64-bit"
        }
    }
}

// MARK: - Audio Effect Type

/// Audio effect types
public enum AudioEffectType: UInt32, Sendable, Codable {
    case none = 0
    case reverb = 1
    case equalizer = 2
    case compressor = 3
    case delay = 4
    
    public var description: String {
        switch self {
        case .none: return "No effect"
        case .reverb: return "Reverb"
        case .equalizer: return "Equalizer"
        case .compressor: return "Compressor"
        case .delay: return "Delay"
        }
    }
}

// MARK: - Audio Metadata

/// Audio file metadata
public struct AudioMetadata: Sendable, Codable {
    /// Sample rate in Hz
    public let sampleRate: UInt32
    
    /// Number of audio channels
    public let channels: UInt32
    
    /// Duration in milliseconds
    public let durationMs: UInt32
    
    /// Bit rate in bits per second
    public let bitRate: UInt32
    
    /// Audio format
    public let format: AudioFormat
    
    /// Sample format
    public let sampleFormat: SampleFormat
    
    /// Total frame count
    public let frameCount: UInt64
    
    /// Track title
    public let title: String
    
    /// Artist name
    public let artist: String
    
    /// Album name
    public let album: String
    
    /// Duration in seconds (computed)
    public var durationSeconds: Double {
        Double(durationMs) / 1000.0
    }
    
    /// Total samples (computed)
    public var totalSamples: UInt64 {
        frameCount * UInt64(channels)
    }
    
    public init(
        sampleRate: UInt32,
        channels: UInt32,
        durationMs: UInt32,
        bitRate: UInt32,
        format: AudioFormat,
        sampleFormat: SampleFormat,
        frameCount: UInt64,
        title: String = "",
        artist: String = "",
        album: String = ""
    ) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.durationMs = durationMs
        self.bitRate = bitRate
        self.format = format
        self.sampleFormat = sampleFormat
        self.frameCount = frameCount
        self.title = title
        self.artist = artist
        self.album = album
    }
}

// MARK: - Audio Effect Parameters

/// Parameters for audio effects
public struct AudioEffectParameters: Sendable, Codable {
    /// Effect type
    public let type: AudioEffectType
    
    /// Reverb parameters
    public let roomSize: Float        // 0.0 to 1.0
    public let damping: Float         // 0.0 to 1.0
    public let wetLevel: Float        // 0.0 to 1.0
    public let dryLevel: Float        // 0.0 to 1.0
    
    /// General parameters
    public let gain: Float            // gain multiplier
    
    /// Equalizer parameters (10-band EQ in dB)
    public let bands: [Float]         // 10 frequency bands
    
    /// Compressor parameters
    public let threshold: Float       // threshold in dB
    public let ratio: Float          // compression ratio
    public let attackTime: Float     // attack time in ms
    public let releaseTime: Float    // release time in ms
    
    /// Delay parameters
    public let delayTime: Float      // delay time in ms
    public let feedback: Float       // feedback amount 0.0 to 1.0
    
    public init(
        type: AudioEffectType,
        roomSize: Float = 0.5,
        damping: Float = 0.5,
        wetLevel: Float = 0.3,
        dryLevel: Float = 0.7,
        gain: Float = 1.0,
        bands: [Float] = Array(repeating: 0.0, count: 10),
        threshold: Float = -20.0,
        ratio: Float = 4.0,
        attackTime: Float = 10.0,
        releaseTime: Float = 100.0,
        delayTime: Float = 250.0,
        feedback: Float = 0.3
    ) {
        self.type = type
        self.roomSize = max(0.0, min(1.0, roomSize))
        self.damping = max(0.0, min(1.0, damping))
        self.wetLevel = max(0.0, min(1.0, wetLevel))
        self.dryLevel = max(0.0, min(1.0, dryLevel))
        self.gain = gain
        self.bands = Array(bands.prefix(10))
        self.threshold = threshold
        self.ratio = max(1.0, ratio)
        self.attackTime = max(0.0, attackTime)
        self.releaseTime = max(0.0, releaseTime)
        self.delayTime = max(0.0, delayTime)
        self.feedback = max(0.0, min(1.0, feedback))
    }
}

// MARK: - Waveform Data

/// Waveform visualization data
public struct AudioWaveform: Sendable {
    /// Waveform width in pixels
    public let width: UInt32
    
    /// Waveform height in pixels
    public let height: UInt32
    
    /// Number of audio channels
    public let channels: UInt32
    
    /// Peak values per channel per pixel
    public let peaks: [Float]
    
    /// RMS values per channel per pixel
    public let rms: [Float]
    
    /// Total number of data points
    public var dataPoints: Int {
        Int(width * channels)
    }
    
    public init(
        width: UInt32,
        height: UInt32,
        channels: UInt32,
        peaks: [Float],
        rms: [Float]
    ) {
        self.width = width
        self.height = height
        self.channels = channels
        self.peaks = peaks
        self.rms = rms
    }
}

// MARK: - Decoded Audio Data

/// Decoded audio with metadata
public struct DecodedAudio: Sendable {
    /// Raw audio sample data
    public let sampleData: Data
    
    /// Audio metadata
    public let metadata: AudioMetadata
    
    /// Total data size in bytes
    public var dataSizeBytes: Int {
        sampleData.count
    }
    
    /// Duration in seconds
    public var durationSeconds: Double {
        metadata.durationSeconds
    }
    
    public init(sampleData: Data, metadata: AudioMetadata) {
        self.sampleData = sampleData
        self.metadata = metadata
    }
}

// MARK: - AudioRenderCapsule Actor

/// Thread-safe actor for audio processing and rendering
public actor AudioRenderCapsule {
    
    // MARK: - Properties
    
    /// Library version
    public nonisolated var version: String {
        AudioRenderNativeBridge.getVersion()
    }
    
    /// Optional diagnostics collector
    private let diagnostics: CapsuleDiagnostics?
    
    // MARK: - Initialization
    
    /// Initialize the capsule
    /// - Parameter diagnostics: Optional diagnostics collector for span tracking
    public init(diagnostics: CapsuleDiagnostics? = nil) {
        self.diagnostics = diagnostics
        
        // Initialize native library
        let result = AudioRenderNativeBridge.initialize()
        if result != AudioRenderNativeBridge.errorNone {
            // Log error but don't throw - capsule can still function
            diagnostics?.event(
                level: .warning,
                category: "AudioRenderCapsule",
                message: "Failed to initialize native library: \(result)",
                correlationID: nil,
                metadata: ["errorCode": String(result)]
            )
        }
    }
    
    deinit {
        // Cleanup native library
        AudioRenderNativeBridge.cleanup()
    }
    
    // MARK: - Decoding
    
    /// Decode audio from encoded data
    /// - Parameters:
    ///   - data: Encoded audio data
    ///   - format: Optional format hint (auto-detected if not provided)
    /// - Returns: Decoded audio with metadata
    /// - Throws: CapsuleError on decode failure
    public func decode(data: Data, format: AudioFormat? = nil) async throws -> DecodedAudio {
        let span = diagnostics?.beginSpan(
            name: "audio.decode",
            category: "AudioRenderCapsule",
            correlationID: nil,
            tags: ["format": format?.mimeType ?? "auto-detect"]
        )
        defer { span?.end(status: .ok) }
        
        return try await withCheckedThrowingContinuation { continuation in
            data.withUnsafeBytes { buffer in
                guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    span?.end(status: .error)
                    continuation.resume(throwing: AudioRenderError.nullPointer.capsuleError)
                    return
                }
                
                var metadata = audio_metadata_t()
                
                let outputPtr: UnsafeMutablePointer<UInt8>?
                if let format = format {
                    // Use format-specific decoder
                    switch format {
                    case .mp3:
                        outputPtr = AudioRenderNativeBridge.decodeMP3(
                            data: ptr,
                            size: UInt64(buffer.count),
                            metadata: &metadata
                        )
                    case .wav:
                        outputPtr = AudioRenderNativeBridge.decodeWAV(
                            data: ptr,
                            size: UInt64(buffer.count),
                            metadata: &metadata
                        )
                    case .flac:
                        outputPtr = AudioRenderNativeBridge.decodeFLAC(
                            data: ptr,
                            size: UInt64(buffer.count),
                            metadata: &metadata
                        )
                    case .aac:
                        outputPtr = AudioRenderNativeBridge.decodeAAC(
                            data: ptr,
                            size: UInt64(buffer.count),
                            metadata: &metadata
                        )
                    default:
                        outputPtr = AudioRenderNativeBridge.decode(
                            data: ptr,
                            size: UInt64(buffer.count),
                            metadata: &metadata
                        )
                    }
                } else {
                    // Auto-detect
                    outputPtr = AudioRenderNativeBridge.decode(
                        data: ptr,
                        size: UInt64(buffer.count),
                        metadata: &metadata
                    )
                }
                
                guard let outputPtr = outputPtr else {
                    span?.end(status: .error)
                    continuation.resume(throwing: AudioRenderError.decodeFailed.capsuleError)
                    return
                }
                
                // Create Data from output buffer
                let sampleData = Data(
                    bytesNoCopy: outputPtr,
                    count: Int(metadata.frame_count * UInt64(metadata.channels) * UInt64(SampleFormat(rawValue: metadata.sample_format)!.bytesPerSample)),
                    deallocator: .custom { _, _ in
                        AudioRenderNativeBridge.freeData(outputPtr)
                    }
                )
                
                let audioMetadata = AudioMetadata(
                    sampleRate: metadata.sample_rate,
                    channels: metadata.channels,
                    durationMs: metadata.duration_ms,
                    bitRate: metadata.bit_rate,
                    format: AudioFormat(rawValue: metadata.format) ?? .unknown,
                    sampleFormat: SampleFormat(rawValue: metadata.sample_format) ?? .f32,
                    frameCount: metadata.frame_count,
                    title: String(cString: metadata.title),
                    artist: String(cString: metadata.artist),
                    album: String(cString: metadata.album)
                )
                
                let decoded = DecodedAudio(sampleData: sampleData, metadata: audioMetadata)
                
                span?.addTag(key: "sampleRate", value: String(metadata.sample_rate))
                span?.addTag(key: "channels", value: String(metadata.channels))
                span?.addTag(key: "durationMs", value: String(metadata.duration_ms))
                span?.addTag(key: "format", value: audioMetadata.format.mimeType)
                
                continuation.resume(returning: decoded)
            }
        }
    }
    
    /// Decode MP3 audio
    /// - Parameter data: MP3 encoded data
    /// - Returns: Decoded audio
    /// - Throws: CapsuleError
    public func decodeMP3(_ data: Data) async throws -> DecodedAudio {
        try await decode(data: data, format: .mp3)
    }
    
    /// Decode WAV audio
    /// - Parameter data: WAV encoded data
    /// - Returns: Decoded audio
    /// - Throws: CapsuleError
    public func decodeWAV(_ data: Data) async throws -> DecodedAudio {
        try await decode(data: data, format: .wav)
    }
    
    /// Decode FLAC audio
    /// - Parameter data: FLAC encoded data
    /// - Returns: Decoded audio
    /// - Throws: CapsuleError
    public func decodeFLAC(_ data: Data) async throws -> DecodedAudio {
        try await decode(data: data, format: .flac)
    }
    
    /// Decode AAC audio
    /// - Parameter data: AAC encoded data
    /// - Returns: Decoded audio
    /// - Throws: CapsuleError
    public func decodeAAC(_ data: Data) async throws -> DecodedAudio {
        try await decode(data: data, format: .aac)
    }
    
    // MARK: - Audio Effects
    
    /// Apply audio effect to decoded audio
    /// - Parameters:
    ///   - audio: Decoded audio data
    ///   - effect: Effect parameters
    /// - Returns: Audio with effect applied
    /// - Throws: CapsuleError on effect failure
    public func applyEffect(to audio: DecodedAudio, effect: AudioEffectParameters) async throws -> DecodedAudio {
        let span = diagnostics?.beginSpan(
            name: "audio.effect",
            category: "AudioRenderCapsule",
            correlationID: nil,
            tags: ["effectType": effect.type.description]
        )
        defer { span?.end(status: .ok) }
        
        return try await withCheckedThrowingContinuation { continuation in
            var mutableAudio = audio
            mutableAudio.sampleData.withUnsafeMutableBytes { buffer in
                guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    span?.end(status: .error)
                    continuation.resume(throwing: AudioRenderError.nullPointer.capsuleError)
                    return
                }
                
                let nativeEffect = audio_effect_params_t(
                    type: audio_effect_type_t(rawValue: effect.type.rawValue)!,
                    room_size: effect.roomSize,
                    damping: effect.damping,
                    wet_level: effect.wetLevel,
                    dry_level: effect.dryLevel,
                    gain: effect.gain,
                    bands: effect.bands,
                    threshold: effect.threshold,
                    ratio: effect.ratio,
                    attack_time: effect.attackTime,
                    release_time: effect.releaseTime,
                    delay_time: effect.delayTime,
                    feedback: effect.feedback
                )
                
                let nativeMetadata = audio_metadata_t(
                    sample_rate: audio.metadata.sampleRate,
                    channels: audio.metadata.channels,
                    duration_ms: audio.metadata.durationMs,
                    bit_rate: audio.metadata.bitRate,
                    format: audio_format_t(rawValue: audio.metadata.format.rawValue)!,
                    sample_format: audio_render_sample_format_t(rawValue: audio.metadata.sampleFormat.rawValue)!,
                    frame_count: audio.metadata.frameCount,
                    title: Array(audio.metadata.title.utf8CString),
                    artist: Array(audio.metadata.artist.utf8CString),
                    album: Array(audio.metadata.album.utf8CString)
                )
                
                let result = AudioRenderNativeBridge.applyEffect(
                    data: ptr,
                    frameCount: audio.metadata.frameCount,
                    metadata: nativeMetadata,
                    effect: nativeEffect
                )
                
                if result != AudioRenderNativeBridge.errorNone {
                    span?.end(status: .error)
                    let error = AudioRenderError(code: result)
                    continuation.resume(throwing: error.capsuleError)
                    return
                }
                
                span?.addTag(key: "effectApplied", value: "true")
                continuation.resume(returning: mutableAudio)
            }
        }
    }
    
    // MARK: - Waveform Generation
    
    /// Generate waveform visualization data
    /// - Parameters:
    ///   - audio: Decoded audio data
    ///   - width: Waveform width in pixels
    ///   - height: Waveform height in pixels
    /// - Returns: Waveform data
    /// - Throws: CapsuleError on waveform generation failure
    public func generateWaveform(from audio: DecodedAudio, width: UInt32, height: UInt32) async throws -> AudioWaveform {
        let span = diagnostics?.beginSpan(
            name: "audio.waveform",
            category: "AudioRenderCapsule",
            correlationID: nil,
            tags: ["width": String(width), "height": String(height)]
        )
        defer { span?.end(status: .ok) }
        
        return try await withCheckedThrowingContinuation { continuation in
            audio.sampleData.withUnsafeBytes { buffer in
                guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    span?.end(status: .error)
                    continuation.resume(throwing: AudioRenderError.nullPointer.capsuleError)
                    return
                }
                
                let nativeMetadata = audio_metadata_t(
                    sample_rate: audio.metadata.sampleRate,
                    channels: audio.metadata.channels,
                    duration_ms: audio.metadata.durationMs,
                    bit_rate: audio.metadata.bitRate,
                    format: audio_format_t(rawValue: audio.metadata.format.rawValue)!,
                    sample_format: audio_render_sample_format_t(rawValue: audio.metadata.sampleFormat.rawValue)!,
                    frame_count: audio.metadata.frameCount,
                    title: Array(audio.metadata.title.utf8CString),
                    artist: Array(audio.metadata.artist.utf8CString),
                    album: Array(audio.metadata.album.utf8CString)
                )
                
                guard let waveformPtr = AudioRenderNativeBridge.generateWaveform(
                    data: ptr,
                    frameCount: audio.metadata.frameCount,
                    metadata: nativeMetadata,
                    width: width,
                    height: height
                ) else {
                    span?.end(status: .error)
                    continuation.resume(throwing: AudioRenderError.waveformFailed.capsuleError)
                    return
                }
                
                // Extract waveform data
                let waveform = waveformPtr.pointee
                let peaks = Array(
                    UnsafeBufferPointer(
                        start: waveform.peaks,
                        count: Int(waveform.width * waveform.channels)
                    )
                )
                let rms = Array(
                    UnsafeBufferPointer(
                        start: waveform.rms,
                        count: Int(waveform.width * waveform.channels)
                    )
                )
                
                let audioWaveform = AudioWaveform(
                    width: waveform.width,
                    height: waveform.height,
                    channels: waveform.channels,
                    peaks: peaks,
                    rms: rms
                )
                
                // Free native waveform
                AudioRenderNativeBridge.freeWaveform(waveformPtr)
                
                span?.addTag(key: "waveformGenerated", value: "true")
                continuation.resume(returning: audioWaveform)
            }
        }
    }
    
    // MARK: - Format Detection
    
    /// Detect audio format from data
    /// - Parameter data: Audio data to analyze
    /// - Returns: Detected audio format
    public func detectFormat(data: Data) -> AudioFormat {
        let result = data.withUnsafeBytes { buffer in
            guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return AudioFormat.unknown
            }
            return AudioFormat(rawValue: AudioRenderNativeBridge.detectFormat(data: ptr, size: UInt64(buffer.count)).rawValue) ?? .unknown
        }
        return result
    }
    
    // MARK: - Batch Processing
    
    /// Batch decode multiple audio files
    /// - Parameters:
    ///   - audioFiles: Array of encoded audio data
    ///   - format: Optional format hint for all files
    /// - Returns: Array of decoded audio (nil for failed files)
    public func decodeBatch(
        audioFiles: [Data],
        format: AudioFormat? = nil
    ) async -> [DecodedAudio?] {
        await withTaskGroup(of: (Int, DecodedAudio?).self) { group in
            for (index, audioData) in audioFiles.enumerated() {
                group.addTask {
                    do {
                        let decoded = try await self.decode(data: audioData, format: format)
                        return (index, decoded)
                    } catch {
                        return (index, nil)
                    }
                }
            }
            
            var results = [DecodedAudio?](repeating: nil, count: audioFiles.count)
            for await (index, decoded) in group {
                results[index] = decoded
            }
            return results
        }
    }
    
    // MARK: - Utility Functions
    
    /// Get last error message from native library
    public func getLastError() -> String {
        String(cString: AudioRenderNativeBridge.getLastError())
    }
}

// MARK: - CapsuleCore Integration

/// Protocol for capsule lifecycle management
public protocol CapsuleLifecycle: Actor {
    func activate() async throws
    func deactivate() async
}

extension AudioRenderCapsule: CapsuleLifecycle {
    public func activate() async throws {
        // Native library already initialized in init
    }
    
    public func deactivate() async {
        // Cleanup handled in deinit
    }
}