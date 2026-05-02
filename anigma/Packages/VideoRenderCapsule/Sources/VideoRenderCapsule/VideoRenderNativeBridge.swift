/// VideoRenderNativeBridge.swift
/// Swift interface to the native C++ video processing library (FFmpeg-based)
/// Supports video decoding, encoding, frame manipulation, and audio processing

import Foundation
import AnigmaNativeShims

@_implementationOnly import VideoRenderNative

// MARK: - Error Codes

enum VideoRenderNativeBridge {
    // Success and error codes
    static let success: Int32 = 0
    static let errorNullPointer: Int32 = 1
    static let errorInvalidData: Int32 = 2
    static let errorUnsupportedFormat: Int32 = 3
    static let errorDecodeFailed: Int32 = 4
    static let errorEncodeFailed: Int32 = 5
    static let errorMemoryAllocation: Int32 = 6
    static let errorInvalidDimensions: Int32 = 7
    static let errorInvalidFrameRate: Int32 = 8
    static let errorInvalidBitrate: Int32 = 9
    static let errorCodecNotFound: Int32 = 10
    static let errorInvalidParameters: Int32 = 11
    
    // Video formats
    static let formatMP4: UInt32 = 0
    static let formatWebM: UInt32 = 1
    static let formatAVI: UInt32 = 2
    static let formatMOV: UInt32 = 3
    static let formatMKV: UInt32 = 4
    
    // Video codecs
    static let codecH264: UInt32 = 0
    static let codecH265: UInt32 = 1
    static let codecVP9: UInt32 = 2
    static let codecAV1: UInt32 = 3
    static let codecMPEG4: UInt32 = 4
    
    // Audio codecs
    static let audioCodecAAC: UInt32 = 0
    static let audioCodecMP3: UInt32 = 1
    static let audioCodecOpus: UInt32 = 2
    static let audioCodecVorbis: UInt32 = 3
    static let audioCodecFLAC: UInt32 = 4
    
    // Pixel formats
    static let pixelFormatYUV420P: UInt32 = 0
    static let pixelFormatRGB24: UInt32 = 1
    static let pixelFormatRGBA32: UInt32 = 2
    static let pixelFormatBGRA32: UInt32 = 3
    static let pixelFormatNV12: UInt32 = 4
    
    // Frame effects
    static let effectResize: UInt32 = 0
    static let effectCrop: UInt32 = 1
    static let effectRotate: UInt32 = 2
    static let effectFlip: UInt32 = 3
    static let effectBrightness: UInt32 = 4
    static let effectContrast: UInt32 = 5
    static let effectSaturation: UInt32 = 6
    
    // MARK: - C Bridge Types
    
    public struct video_info_t {
        public var width: UInt32
        public var height: UInt32
        public var frame_rate: Double
        public var duration: Double
        public var bitrate: UInt64
        public var format: UInt32
        public var video_codec: UInt32
        public var audio_codec: UInt32
        public var pixel_format: UInt32
        public var audio_sample_rate: UInt32
        public var audio_channels: UInt32
        public var has_audio: Bool
        public var frame_count: UInt64
    }
    
    public struct frame_info_t {
        public var width: UInt32
        public var height: UInt32
        public var pixel_format: UInt32
        public var data_size: UInt64
        public var timestamp: Double
    }
    
    public struct effect_params_t {
        public var effect_type: UInt32
        public var param1: Double
        public var param2: Double
        public var param3: Double
        public var param4: Double
    }
    
    // MARK: - Version and Library Info
    
    static func version() -> String {
        let versionPtr = video_render_version()
        return String(cString: versionPtr!)
    }
    
    static func ffmpegVersion() -> String {
        let versionPtr = video_render_ffmpeg_version()
        return String(cString: versionPtr!)
    }
    
    // MARK: - Video Decoding
    
    static func openVideoDecoder(
        data: UnsafePointer<UInt8>,
        size: UInt64,
        info: UnsafeMutablePointer<video_info_t>
    ) -> UnsafeMutableRawPointer? {
        var decoderPtr: UnsafeMutableRawPointer?
        let result = video_render_decoder_open(data, size, &decoderPtr, info)
        guard result == success else { return nil }
        return decoderPtr
    }
    
    static func decodeNextFrame(
        decoder: UnsafeMutableRawPointer,
        frameData: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
        frameInfo: UnsafeMutablePointer<frame_info_t>
    ) -> Int32 {
        return video_render_decoder_read_frame(decoder, frameData, frameInfo)
    }
    
    static func closeVideoDecoder(_ decoder: UnsafeMutableRawPointer) {
        video_render_decoder_close(decoder)
    }
    
    static func freeFrameData(_ data: UnsafeMutablePointer<UInt8>) {
        video_render_frame_free(data)
    }
    
    // MARK: - Video Encoding
    
    static func openVideoEncoder(
        format: UInt32,
        videoCodec: UInt32,
        audioCodec: UInt32,
        width: UInt32,
        height: UInt32,
        frameRate: Double,
        bitrate: UInt64,
        audioSampleRate: UInt32,
        audioChannels: UInt32
    ) -> UnsafeMutableRawPointer? {
        var encoderPtr: UnsafeMutableRawPointer?
        let result = video_render_encoder_open(
            format, videoCodec, audioCodec,
            width, height, frameRate, bitrate,
            audioSampleRate, audioChannels, &encoderPtr
        )
        guard result == success else { return nil }
        return encoderPtr
    }
    
    static func encodeFrame(
        encoder: UnsafeMutableRawPointer,
        frameData: UnsafePointer<UInt8>,
        dataSize: UInt64,
        timestamp: Double
    ) -> UnsafeMutablePointer<UInt8>? {
        var outputData: UnsafeMutablePointer<UInt8>?
        var outputSize: UInt64 = 0
        let result = video_render_encoder_write_frame(
            encoder, frameData, dataSize, timestamp, &outputData, &outputSize
        )
        guard result == success else { return nil }
        return outputData
    }
    
    static func finalizeEncoding(
        encoder: UnsafeMutableRawPointer,
        outputData: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
        outputSize: UnsafeMutablePointer<UInt64>
    ) -> Int32 {
        return video_render_encoder_finalize(encoder, outputData, outputSize)
    }
    
    static func closeVideoEncoder(_ encoder: UnsafeMutableRawPointer) {
        video_render_encoder_close(encoder)
    }
    
    static func freeEncodedData(_ data: UnsafeMutablePointer<UInt8>) {
        video_render_encoded_free(data)
    }
    
    // MARK: - Frame Manipulation
    
    static func applyEffect(
        inputData: UnsafePointer<UInt8>,
        inputSize: UInt64,
        outputData: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
        outputSize: UnsafeMutablePointer<UInt64>,
        inputWidth: UInt32,
        inputHeight: UInt32,
        inputFormat: UInt32,
        params: UnsafePointer<effect_params_t>
    ) -> Int32 {
        return video_render_apply_effect(
            inputData, inputSize, outputData, outputSize,
            inputWidth, inputHeight, inputFormat, params
        )
    }
    
    static func freeProcessedData(_ data: UnsafeMutablePointer<UInt8>) {
        video_render_processed_free(data)
    }
    
    // MARK: - Audio Processing
    
    static func extractAudio(
        videoData: UnsafePointer<UInt8>,
        videoSize: UInt64,
        audioData: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
        audioSize: UnsafeMutablePointer<UInt64>,
        audioFormat: UnsafeMutablePointer<UInt32>,
        sampleRate: UnsafeMutablePointer<UInt32>,
        channels: UnsafeMutablePointer<UInt32>
    ) -> Int32 {
        return video_render_extract_audio(
            videoData, videoSize, audioData, audioSize,
            audioFormat, sampleRate, channels
        )
    }
    
    static func processAudio(
        inputData: UnsafePointer<UInt8>,
        inputSize: UInt64,
        outputData: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
        outputSize: UnsafeMutablePointer<UInt64>,
        sampleRate: UInt32,
        channels: UInt32,
        volume: Double,
        fadeInDuration: Double,
        fadeOutDuration: Double
    ) -> Int32 {
        return video_render_process_audio(
            inputData, inputSize, outputData, outputSize,
            sampleRate, channels, volume, fadeInDuration, fadeOutDuration
        )
    }
    
    static func freeAudioData(_ data: UnsafeMutablePointer<UInt8>) {
        video_render_audio_free(data)
    }
    
    // MARK: - Format Detection
    
    static func detectVideoFormat(
        data: UnsafePointer<UInt8>,
        size: UInt64
    ) -> UInt32 {
        return video_render_detect_format(data, size)
    }
    
    // MARK: - Thumbnail Generation
    
    static func generateThumbnail(
        videoData: UnsafePointer<UInt8>,
        videoSize: UInt64,
        thumbnailData: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
        thumbnailSize: UnsafeMutablePointer<UInt64>,
        thumbnailWidth: UInt32,
        thumbnailHeight: UInt32,
        timestamp: Double
    ) -> Int32 {
        return video_render_generate_thumbnail(
            videoData, videoSize, thumbnailData, thumbnailSize,
            thumbnailWidth, thumbnailHeight, timestamp
        )
    }
    
    static func freeThumbnailData(_ data: UnsafeMutablePointer<UInt8>) {
        video_render_thumbnail_free(data)
    }
}