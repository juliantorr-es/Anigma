// AudioRenderCapsuleBridge.swift
// Swift bridge to native C++ audio rendering library

import Foundation

// MARK: - Native Bridge

/// Bridge to the native AudioRenderCapsule C++ library
public enum AudioRenderNativeBridge {
    
    // MARK: - Error Codes
    public static let errorNone: Int32 = 0
    public static let errorNullPointer: Int32 = -1
    public static let errorInvalidData: Int32 = -2
    public static let errorUnsupportedFormat: Int32 = -3
    public static let errorDecodeFailed: Int32 = -4
    public static let errorMemoryAllocation: Int32 = -5
    public static let errorInvalidParameters: Int32 = -6
    public static let errorEffectFailed: Int32 = -7
    public static let errorWaveformFailed: Int32 = -8
    
    // MARK: - Native Functions
    
    /// Get library version
    public static func getVersion() -> String {
        return String(cString: audio_render_get_version())
    }
    
    /// Initialize audio renderer
    public static func initialize() -> Int32 {
        return audio_render_initialize()
    }
    
    /// Cleanup audio renderer
    public static func cleanup() {
        audio_render_cleanup()
    }
    
    /// Decode audio data
    public static func decode(
        data: UnsafePointer<UInt8>,
        size: UInt64,
        metadata: UnsafeMutablePointer<audio_metadata_t>
    ) -> UnsafeMutablePointer<UInt8>? {
        return audio_render_decode(data, size, metadata)
    }
    
    /// Decode MP3 audio
    public static func decodeMP3(
        data: UnsafePointer<UInt8>,
        size: UInt64,
        metadata: UnsafeMutablePointer<audio_metadata_t>
    ) -> UnsafeMutablePointer<UInt8>? {
        return audio_render_decode_mp3(data, size, metadata)
    }
    
    /// Decode WAV audio
    public static func decodeWAV(
        data: UnsafePointer<UInt8>,
        size: UInt64,
        metadata: UnsafeMutablePointer<audio_metadata_t>
    ) -> UnsafeMutablePointer<UInt8>? {
        return audio_render_decode_wav(data, size, metadata)
    }
    
    /// Decode FLAC audio
    public static func decodeFLAC(
        data: UnsafePointer<UInt8>,
        size: UInt64,
        metadata: UnsafeMutablePointer<audio_metadata_t>
    ) -> UnsafeMutablePointer<UInt8>? {
        return audio_render_decode_flac(data, size, metadata)
    }
    
    /// Decode AAC audio
    public static func decodeAAC(
        data: UnsafePointer<UInt8>,
        size: UInt64,
        metadata: UnsafeMutablePointer<audio_metadata_t>
    ) -> UnsafeMutablePointer<UInt8>? {
        return audio_render_decode_aac(data, size, metadata)
    }
    
    /// Free decoded data
    public static func freeData(_ data: UnsafeMutablePointer<UInt8>?) {
        if let data = data {
            audio_render_free_data(data)
        }
    }
    
    /// Apply audio effect
    public static func applyEffect(
        data: UnsafeMutablePointer<UInt8>,
        frameCount: UInt64,
        metadata: audio_metadata_t,
        effect: audio_effect_params_t
    ) -> Int32 {
        return audio_render_apply_effect(data, frameCount, &metadata, &effect)
    }
    
    /// Generate waveform
    public static func generateWaveform(
        data: UnsafePointer<UInt8>,
        frameCount: UInt64,
        metadata: audio_metadata_t,
        width: UInt32,
        height: UInt32
    ) -> UnsafeMutablePointer<audio_waveform_t>? {
        return audio_render_generate_waveform(data, frameCount, &metadata, width, height)
    }
    
    /// Free waveform data
    public static func freeWaveform(_ waveform: UnsafeMutablePointer<audio_waveform_t>?) {
        if let waveform = waveform {
            audio_render_free_waveform(waveform)
        }
    }
    
    /// Detect audio format
    public static func detectFormat(data: UnsafePointer<UInt8>, size: UInt64) -> audio_format_t {
        return audio_render_detect_format(data, size)
    }
    
    /// Get last error message
    public static func getLastError() -> UnsafePointer<CChar> {
        return audio_render_get_last_error()
    }
}

// MARK: - Native Type Mappings

// Import C types from the header
public typealias audio_metadata_t = audio_metadata_t
public typealias audio_effect_params_t = audio_effect_params_t
public typealias audio_waveform_t = audio_waveform_t
public typealias audio_format_t = audio_render_format
public typealias audio_effect_type_t = audio_render_effect_type
public typealias audio_render_sample_format_t = audio_render_sample_format

// MARK: - Swift-friendly Extensions

extension audio_metadata_t {
    public init(
        sampleRate: UInt32,
        channels: UInt32,
        durationMs: UInt32,
        bitRate: UInt32,
        format: audio_format_t,
        sampleFormat: audio_render_sample_format_t,
        frameCount: UInt64,
        title: [CChar],
        artist: [CChar],
        album: [CChar]
    ) {
        self.init(
            sample_rate: sampleRate,
            channels: channels,
            duration_ms: durationMs,
            bit_rate: bitRate,
            format: format,
            sample_format: sampleFormat,
            frame_count: frameCount,
            title: title,
            artist: artist,
            album: album
        )
    }
}

extension audio_effect_params_t {
    public init(
        type: audio_effect_type_t,
        roomSize: Float,
        damping: Float,
        wetLevel: Float,
        dryLevel: Float,
        gain: Float,
        bands: [Float],
        threshold: Float,
        ratio: Float,
        attackTime: Float,
        releaseTime: Float,
        delayTime: Float,
        feedback: Float
    ) {
        var bandArray: [Float] = Array(repeating: 0.0, count: 10)
        for (index, value) in bands.enumerated() {
            if index < 10 {
                bandArray[index] = value
            }
        }
        
        self.init(
            type: type,
            room_size: roomSize,
            damping: damping,
            wet_level: wetLevel,
            dry_level: dryLevel,
            gain: gain,
            bands: bandArray,
            threshold: threshold,
            ratio: ratio,
            attack_time: attackTime,
            release_time: releaseTime,
            delay_time: delayTime,
            feedback: feedback
        )
    }
}