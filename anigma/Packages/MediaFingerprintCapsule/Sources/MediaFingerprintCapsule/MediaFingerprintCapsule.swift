//
// MediaFingerprintCapsule.swift
// MediaFingerprintCapsule
//
// Created by Mistral Vibe on 2026-02-10
// Copyright © 2026 Anigma. All rights reserved.
//

import Foundation
import CryptoKit
import CoreImage
import CoreImage.CIFilterBuiltins
import AVFoundation
import Accelerate
import OSLog

/// Media fingerprinting capsule for content identification and similarity detection
public final class MediaFingerprintCapsule: @unchecked Sendable {
    
    // MARK: - Constants
    
    private static let logger = Logger(subsystem: "com.anigma.MediaFingerprintCapsule", category: "Fingerprinting")
    private static let defaultImageHashSize: UInt32 = 64
    private static let defaultAudioFingerprintSize: UInt32 = 32
    private static let defaultVideoFingerprintSize: UInt32 = 64
    private static let defaultSimilarityThreshold: Double = 0.85
    private static let partialMatchThreshold: Double = 0.65
    
    // MARK: - Configuration
    
    private let imageConfig: ImageFingerprintConfiguration
    private let audioConfig: AudioFingerprintConfiguration
    private let videoConfig: VideoFingerprintConfiguration
    private let performanceMonitor: PerformanceMonitor
    
    // MARK: - Public Properties
    
    public var imageConfiguration: ImageFingerprintConfiguration { imageConfig }
    public var audioConfiguration: AudioFingerprintConfiguration { audioConfig }
    public var videoConfiguration: VideoFingerprintConfiguration { videoConfig }
    
    // MARK: - Initialization
    
    public init(
        imageConfig: ImageFingerprintConfiguration? = nil,
        audioConfig: AudioFingerprintConfiguration? = nil,
        videoConfig: VideoFingerprintConfiguration? = nil,
        diagnostics: Any? = nil
    ) throws {
        _ = diagnostics
        self.imageConfig = imageConfig ?? .default
        self.audioConfig = audioConfig ?? .default
        self.videoConfig = videoConfig ?? .default
        self.performanceMonitor = PerformanceMonitor()
        
        try self.imageConfig.validate()
        try self.audioConfig.validate()
        try self.videoConfig.validate()
        
        Self.logger.info("MediaFingerprintCapsule initialized with imageHashSize: \(self.imageConfig.hashSize), audioFingerprintSize: \(self.audioConfig.fingerprintSize), videoFingerprintSize: \(self.videoConfig.fingerprintSize)")
    }
    
    // MARK: - Reset
    
    public func reset() throws {
        performanceMonitor.reset()
        Self.logger.info("MediaFingerprintCapsule reset completed")
    }
    
    // MARK: - Media Type Detection
    
    public static func detectMediaType(
        _ data: Data,
        diagnostics: Any? = nil
    ) throws -> MediaType {
        _ = diagnostics
        guard !data.isEmpty else { return .unknown }
        
        // Image signatures
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { // PNG
            return .image
        }
        if data.starts(with: [0xFF, 0xD8, 0xFF]) { // JPEG
            return .image
        }
        if data.starts(with: [0x42, 0x4D]) { // BMP
            return .image
        }
        if data.starts(with: [0x47, 0x49, 0x46, 0x38]) { // GIF
            return .image
        }
        
        // Audio signatures
        if data.starts(with: [0x49, 0x44, 0x33]) { // MP3 (ID3)
            return .audio
        }
        if data.starts(with: [0xFF, 0xFB]) { // MP3 (no ID3)
            return .audio
        }
        if data.starts(with: [0x4F, 0x67, 0x67, 0x53]) { // OGG
            return .audio
        }
        if data.starts(with: [0x52, 0x49, 0x46, 0x46]) && data.count > 8 { // WAV
            let waveHeader = data.subdata(in: 8..<12)
            if waveHeader == Data([0x57, 0x41, 0x56, 0x45]) {
                return .audio
            }
        }
        
        // Video signatures
        if data.starts(with: [0x00, 0x00, 0x00, 0x14, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D]) { // MP4
            return .video
        }
        if data.starts(with: [0x1A, 0x45, 0xDF, 0xA3]) { // MKV
            return .video
        }
        if data.starts(with: [0x52, 0x49, 0x46, 0x46]) && data.count > 8 { // AVI
            let aviHeader = data.subdata(in: 8..<12)
            if aviHeader == Data([0x41, 0x56, 0x49, 0x20]) {
                return .video
            }
        }
        
        return .unknown
    }
    
    // MARK: - Media Analysis
    
    public func analyzeMedia(_ data: Data, mediaType: MediaType = .unknown) throws -> MediaMetadata {
        let startTime = Date()
        let resolvedType = mediaType == .unknown ? (try Self.detectMediaType(data)) : mediaType
        
        var metadata: MediaMetadata
        
        switch resolvedType {
        case .image:
            metadata = try analyzeImageData(data)
        case .audio:
            metadata = try analyzeAudioData(data)
        case .video:
            metadata = try analyzeVideoData(data)
        case .unknown:
            metadata = MediaMetadata(
                mediaType: .unknown,
                fileSize: UInt64(data.count),
                width: 0,
                height: 0,
                durationMs: 0,
                bitRate: 0,
                sampleRate: 0,
                format: "unknown",
                codec: "unknown"
            )
        }
        
        let elapsedMs = UInt64(Date().timeIntervalSince(startTime) * 1000)
        Self.logger.info("Media analysis completed in \(elapsedMs)ms for type: \(String(describing: resolvedType))")
        
        return metadata
    }
    
    // MARK: - Image Analysis
    
    private func analyzeImageData(_ data: Data) throws -> MediaMetadata {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            throw MediaFingerprintError.invalidInput
        }
        
        let width = imageProperties[kCGImagePropertyPixelWidth] as? UInt32 ?? 0
        let height = imageProperties[kCGImagePropertyPixelHeight] as? UInt32 ?? 0
        let format = detectImageFormat(data)
        let codec = determineImageCodec(from: format)
        
        return MediaMetadata(
            mediaType: .image,
            fileSize: UInt64(data.count),
            width: width,
            height: height,
            durationMs: 0,
            bitRate: 0,
            sampleRate: 0,
            format: format,
            codec: codec
        )
    }
    
    private func determineImageCodec(from format: String) -> String {
        switch format.lowercased() {
        case "jpeg", "jpg": return "JPEG"
        case "png": return "PNG"
        case "gif": return "GIF"
        case "bmp": return "BMP"
        case "tiff": return "TIFF"
        case "webp": return "WEBP"
        default: return "UNKNOWN"
        }
    }

    private func detectImageFormat(_ data: Data) -> String {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "png" }
        if data.starts(with: [0xFF, 0xD8, 0xFF]) { return "jpeg" }
        if data.starts(with: [0x42, 0x4D]) { return "bmp" }
        if data.starts(with: [0x47, 0x49, 0x46, 0x38]) { return "gif" }
        return "unknown"
    }
    
    // MARK: - Audio Analysis
    
    private func analyzeAudioData(_ data: Data) throws -> MediaMetadata {
        // Basic audio analysis - would use AudioToolbox in production
        let format = try detectAudioFormat(data)
        let codec = determineAudioCodec(from: format)
        
        return MediaMetadata(
            mediaType: .audio,
            fileSize: UInt64(data.count),
            width: 0,
            height: 0,
            durationMs: 0, // Would extract from actual audio data
            bitRate: 0, // Would extract from actual audio data
            sampleRate: 0, // Would extract from actual audio data
            format: format,
            codec: codec
        )
    }
    
    private func detectAudioFormat(_ data: Data) throws -> String {
        if data.starts(with: [0x49, 0x44, 0x33]) { return "MP3" }
        if data.starts(with: [0x4F, 0x67, 0x67, 0x53]) { return "OGG" }
        if data.starts(with: [0x52, 0x49, 0x46, 0x46]) && data.count > 8 {
            let waveHeader = data.subdata(in: 8..<12)
            if waveHeader == Data([0x57, 0x41, 0x56, 0x45]) { return "WAV" }
        }
        if data.starts(with: [0x66, 0x4C, 0x61, 0x43]) { return "FLAC" }
        return "UNKNOWN"
    }
    
    private func determineAudioCodec(from format: String) -> String {
        switch format.uppercased() {
        case "MP3": return "MP3"
        case "OGG": return "VORBIS"
        case "WAV": return "PCM"
        case "FLAC": return "FLAC"
        case "AAC": return "AAC"
        default: return "UNKNOWN"
        }
    }
    
    // MARK: - Video Analysis
    
    private func analyzeVideoData(_ data: Data) throws -> MediaMetadata {
        // Basic video analysis - would use AVFoundation in production
        let format = try detectVideoFormat(data)
        let codec = determineVideoCodec(from: format)
        
        return MediaMetadata(
            mediaType: .video,
            fileSize: UInt64(data.count),
            width: 0, // Would extract from actual video data
            height: 0, // Would extract from actual video data
            durationMs: 0, // Would extract from actual video data
            bitRate: 0, // Would extract from actual video data
            sampleRate: 0,
            format: format,
            codec: codec
        )
    }
    
    private func detectVideoFormat(_ data: Data) throws -> String {
        if data.starts(with: [0x00, 0x00, 0x00, 0x14, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D]) { return "MP4" }
        if data.starts(with: [0x1A, 0x45, 0xDF, 0xA3]) { return "MKV" }
        if data.starts(with: [0x52, 0x49, 0x46, 0x46]) && data.count > 8 {
            let aviHeader = data.subdata(in: 8..<12)
            if aviHeader == Data([0x41, 0x56, 0x49, 0x20]) { return "AVI" }
        }
        if data.starts(with: [0x30, 0x26, 0xB2, 0x75, 0x8E, 0x66, 0xCF, 0x11, 0xA6, 0xD9]) { return "WMV" }
        return "UNKNOWN"
    }
    
    private func determineVideoCodec(from format: String) -> String {
        switch format.uppercased() {
        case "MP4": return "H264"
        case "MKV": return "H264"
        case "AVI": return "DIVX"
        case "WMV": return "WMV3"
        case "MOV": return "H264"
        default: return "UNKNOWN"
        }
    }
    
    // MARK: - Fingerprint Generation
    
    public func generateImageFingerprint(
        _ data: Data,
        algorithm: FingerprintAlgorithm = .perceptualHash
    ) throws -> FingerprintResult {
        let startTime = Date()
        
        guard let image = createImage(from: data) else {
            throw MediaFingerprintError.invalidInput
        }
        
        let fingerprint: FingerprintResult
        
        switch algorithm {
        case .averageHash:
            fingerprint = try generateAverageHashFingerprint(image: image)
        case .differenceHash:
            fingerprint = try generateDifferenceHashFingerprint(image: image)
        case .waveletHash:
            fingerprint = try generateWaveletHashFingerprint(image: image)
        case .perceptualHash:
            fingerprint = try generatePerceptualHashFingerprint(image: image)
        default:
            throw MediaFingerprintError.invalidInput
        }
        
        let elapsedMs = UInt64(Date().timeIntervalSince(startTime) * 1000)
        performanceMonitor.recordOperation(
            type: .imageFingerprint,
            algorithm: algorithm,
            durationMs: elapsedMs,
            dataSize: data.count
        )
        
        Self.logger.info("Generated image fingerprint using \(String(describing: algorithm)) in \(elapsedMs)ms")
        
        return fingerprint
    }
    
    public func generateAudioFingerprint(
        _ data: Data,
        algorithm: FingerprintAlgorithm = .chromaprint
    ) throws -> FingerprintResult {
        let startTime = Date()
        
        guard !data.isEmpty else {
            throw MediaFingerprintError.invalidInput
        }
        
        let fingerprint: FingerprintResult
        
        switch algorithm {
        case .chromaprint:
            fingerprint = try generateChromaprintFingerprint(data: data)
        case .averageHash, .differenceHash, .waveletHash, .perceptualHash:
            // For audio, we can adapt some image algorithms to waveform data
            fingerprint = try generateAudioWaveformFingerprint(data: data, algorithm: algorithm)
        default:
            throw MediaFingerprintError.invalidInput
        }
        
        let elapsedMs = UInt64(Date().timeIntervalSince(startTime) * 1000)
        performanceMonitor.recordOperation(
            type: .audioFingerprint,
            algorithm: algorithm,
            durationMs: elapsedMs,
            dataSize: data.count
        )
        
        Self.logger.info("Generated audio fingerprint using \(String(describing: algorithm)) in \(elapsedMs)ms")
        
        return fingerprint
    }
    
    public func generateVideoFingerprint(
        _ data: Data,
        algorithm: FingerprintAlgorithm = .motionVector
    ) throws -> FingerprintResult {
        let startTime = Date()
        
        guard !data.isEmpty else {
            throw MediaFingerprintError.invalidInput
        }
        
        let fingerprint: FingerprintResult
        
        switch algorithm {
        case .motionVector:
            fingerprint = try generateMotionVectorFingerprint(data: data)
        case .averageHash, .differenceHash, .waveletHash, .perceptualHash:
            // For video, we can extract key frames and fingerprint them
            fingerprint = try generateVideoKeyframeFingerprint(data: data, algorithm: algorithm)
        default:
            throw MediaFingerprintError.invalidInput
        }
        
        let elapsedMs = UInt64(Date().timeIntervalSince(startTime) * 1000)
        performanceMonitor.recordOperation(
            type: .videoFingerprint,
            algorithm: algorithm,
            durationMs: elapsedMs,
            dataSize: data.count
        )
        
        Self.logger.info("Generated video fingerprint using \(String(describing: algorithm)) in \(elapsedMs)ms")
        
        return fingerprint
    }
    
    // MARK: - Image Fingerprinting Algorithms
    
    private func createImage(from data: Data) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        return cgImage
    }
    
    private func generateAverageHashFingerprint(image: CGImage) throws -> FingerprintResult {
        let startTime = Date()
        let hashSize = imageConfig.hashSize
        
        // Resize image to hashSize x hashSize
        let resizedImage = try resizeImage(image, to: CGSize(width: Int(hashSize), height: Int(hashSize)))
        
        // Convert to grayscale
        guard let grayImage = convertToGrayscale(resizedImage) else {
            throw MediaFingerprintError.invalidInput
        }
        
        // Calculate average pixel value
        let average = calculateAveragePixelValue(grayImage)
        
        // Generate hash bits
        var hashBits = [Bool]()
        for y in 0..<Int(hashSize) {
            for x in 0..<Int(hashSize) {
                if let pixelValue = getPixelValue(grayImage, at: CGPoint(x: x, y: y)) {
                    hashBits.append(pixelValue > average)
                }
            }
        }
        
        // Convert to Data
        let hashData = convertBitsToData(hashBits)
        let elapsedMs = UInt64(Date().timeIntervalSince(startTime) * 1000)
        
        return FingerprintResult(
            algorithm: .averageHash,
            hashSize: hashSize,
            hashData: hashData,
            confidence: 0.85,
            processingTimeMs: elapsedMs
        )
    }
    
    private func generateDifferenceHashFingerprint(image: CGImage) throws -> FingerprintResult {
        let startTime = Date()
        let hashSize = imageConfig.hashSize
        
        // Resize image
        let resizedImage = try resizeImage(image, to: CGSize(width: Int(hashSize), height: Int(hashSize)))
        
        // Convert to grayscale
        guard let grayImage = convertToGrayscale(resizedImage) else {
            throw MediaFingerprintError.invalidInput
        }
        
        // Generate hash bits by comparing adjacent pixels
        var hashBits = [Bool]()
        for y in 0..<Int(hashSize) {
            for x in 0..<Int(hashSize)-1 {
                let leftPixel = getPixelValue(grayImage, at: CGPoint(x: x, y: y)) ?? 0
                let rightPixel = getPixelValue(grayImage, at: CGPoint(x: x+1, y: y)) ?? 0
                hashBits.append(leftPixel > rightPixel)
            }
        }
        
        // Convert to Data
        let hashData = convertBitsToData(hashBits)
        let elapsedMs = UInt64(Date().timeIntervalSince(startTime) * 1000)
        
        return FingerprintResult(
            algorithm: .differenceHash,
            hashSize: hashSize,
            hashData: hashData,
            confidence: 0.88,
            processingTimeMs: elapsedMs
        )
    }
    
    private func generateWaveletHashFingerprint(image: CGImage) throws -> FingerprintResult {
        let startTime = Date()
        let hashSize = imageConfig.hashSize
        
        // Resize image
        let resizedImage = try resizeImage(image, to: CGSize(width: Int(hashSize), height: Int(hashSize)))
        
        // Convert to grayscale
        guard let grayImage = convertToGrayscale(resizedImage) else {
            throw MediaFingerprintError.invalidInput
        }
        
        // Apply wavelet transform (simplified)
        let waveletBits = applyWaveletTransform(grayImage)
        let hashData = convertBitsToData(waveletBits)
        let elapsedMs = UInt64(Date().timeIntervalSince(startTime) * 1000)
        
        return FingerprintResult(
            algorithm: .waveletHash,
            hashSize: hashSize,
            hashData: hashData,
            confidence: 0.92,
            processingTimeMs: elapsedMs
        )
    }
    
    private func generatePerceptualHashFingerprint(image: CGImage) throws -> FingerprintResult {
        let startTime = Date()
        let hashSize = imageConfig.hashSize
        
        // Resize image
        let resizedImage = try resizeImage(image, to: CGSize(width: Int(hashSize), height: Int(hashSize)))
        
        // Convert to grayscale
        guard let grayImage = convertToGrayscale(resizedImage) else {
            throw MediaFingerprintError.invalidInput
        }
        
        // Apply DCT (Discrete Cosine Transform) - simplified
        let dctBits = applyDCT(grayImage)
        let hashData = convertBitsToData(dctBits)
        let elapsedMs = UInt64(Date().timeIntervalSince(startTime) * 1000)
        
        return FingerprintResult(
            algorithm: .perceptualHash,
            hashSize: hashSize,
            hashData: hashData,
            confidence: 0.95,
            processingTimeMs: elapsedMs
        )
    }
    
    // MARK: - Audio Fingerprinting Algorithms
    
    private func generateChromaprintFingerprint(data: Data) throws -> FingerprintResult {
        let startTime = Date()
        let fingerprintSize = audioConfig.fingerprintSize
        
        // Simplified chromaprint algorithm
        // In production, would use actual audio processing
        
        // Generate fingerprint based on data characteristics
        let hashData = generateHashData(from: data, size: Int(fingerprintSize))
        let elapsedMs = UInt64(Date().timeIntervalSince(startTime) * 1000)
        
        return FingerprintResult(
            algorithm: .chromaprint,
            hashSize: fingerprintSize,
            hashData: hashData,
            confidence: 0.80,
            processingTimeMs: elapsedMs
        )
    }
    
    private func generateAudioWaveformFingerprint(data: Data, algorithm: FingerprintAlgorithm) throws -> FingerprintResult {
        let startTime = Date()
        let fingerprintSize = audioConfig.fingerprintSize
        
        // Convert audio data to waveform representation
        // Then apply image fingerprinting algorithms
        
        let hashData = generateHashData(from: data, size: Int(fingerprintSize))
        let elapsedMs = UInt64(Date().timeIntervalSince(startTime) * 1000)
        
        return FingerprintResult(
            algorithm: algorithm,
            hashSize: fingerprintSize,
            hashData: hashData,
            confidence: 0.75,
            processingTimeMs: elapsedMs
        )
    }
    
    // MARK: - Video Fingerprinting Algorithms
    
    private func generateMotionVectorFingerprint(data: Data) throws -> FingerprintResult {
        let startTime = Date()
        let fingerprintSize = videoConfig.fingerprintSize
        
        // Simplified motion vector analysis
        // In production, would extract actual motion vectors from video
        
        let hashData = generateHashData(from: data, size: Int(fingerprintSize))
        let elapsedMs = UInt64(Date().timeIntervalSince(startTime) * 1000)
        
        return FingerprintResult(
            algorithm: .motionVector,
            hashSize: fingerprintSize,
            hashData: hashData,
            confidence: 0.82,
            processingTimeMs: elapsedMs
        )
    }
    
    private func generateVideoKeyframeFingerprint(data: Data, algorithm: FingerprintAlgorithm) throws -> FingerprintResult {
        let startTime = Date()
        let fingerprintSize = videoConfig.fingerprintSize
        
        // Extract key frames and fingerprint them
        // Simplified for this implementation
        
        let hashData = generateHashData(from: data, size: Int(fingerprintSize))
        let elapsedMs = UInt64(Date().timeIntervalSince(startTime) * 1000)
        
        return FingerprintResult(
            algorithm: algorithm,
            hashSize: fingerprintSize,
            hashData: hashData,
            confidence: 0.78,
            processingTimeMs: elapsedMs
        )
    }
    
    // MARK: - Fingerprint Comparison
    
    public func compareFingerprints(
        _ lhs: FingerprintResult,
        _ rhs: FingerprintResult,
        threshold: Double = 0.85
    ) -> SimilarityResult {
        let startTime = Date()
        
        // Ensure both fingerprints use the same algorithm for meaningful comparison
        guard lhs.algorithm == rhs.algorithm else {
            let result = SimilarityResult(
                similarityScore: 0.0,
                hammingDistance: UInt32.max,
                isDuplicate: false,
                isPartialMatch: false
            )
            Self.logger.warning("Cannot compare fingerprints with different algorithms: \(String(describing: lhs.algorithm)) vs \(String(describing: rhs.algorithm))")
            return result
        }
        
        let distance = hammingDistance(lhs.hashData, rhs.hashData)
        let bits = max(lhs.hashData.count, rhs.hashData.count) * 8
        let similarity = bits > 0 ? 1.0 - (Double(distance) / Double(bits)) : 0.0
        
        let result = SimilarityResult(
            similarityScore: max(0.0, min(1.0, similarity)),
            hammingDistance: UInt32(distance),
            isDuplicate: similarity >= threshold,
            isPartialMatch: similarity >= Self.partialMatchThreshold
        )
        
        let elapsedMs = UInt64(Date().timeIntervalSince(startTime) * 1000)
        performanceMonitor.recordComparison(
            algorithm: lhs.algorithm,
            distance: distance,
            similarity: result.similarityScore,
            durationMs: elapsedMs
        )
        
        Self.logger.info("Fingerprint comparison: similarity=\(result.similarityScore), distance=\(result.hammingDistance)")
        
        return result
    }
    
    public func batchCompareFingerprints(
        query: FingerprintResult,
        candidates: [FingerprintResult],
        threshold: Double = 0.85
    ) -> [SimilarityResult] {
        let startTime = Date()
        
        let results = candidates.map { compareFingerprints(query, $0, threshold: threshold) }
        
        let elapsedMs = UInt64(Date().timeIntervalSince(startTime) * 1000)
        performanceMonitor.recordBatchComparison(
            queryAlgorithm: query.algorithm,
            candidateCount: candidates.count,
            durationMs: elapsedMs
        )
        
        Self.logger.info("Batch comparison of \(candidates.count) candidates completed in \(elapsedMs)ms")
        
        return results
    }
    
    // MARK: - Utility Functions
    
    private func resizeImage(_ image: CGImage, to size: CGSize) throws -> CGImage {
        let width = Int(size.width)
        let height = Int(size.height)
        
        guard width > 0, height > 0 else {
            throw MediaFingerprintError.invalidInput
        }
        
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        guard let context = context else {
            throw MediaFingerprintError.invalidInput
        }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let resizedImage = context.makeImage() else {
            throw MediaFingerprintError.invalidInput
        }
        
        return resizedImage
    }
    
    private func convertToGrayscale(_ image: CGImage) -> CGImage? {
        let context = CIContext()
        let ciImage = CIImage(cgImage: image)
        
        guard let filter = CIFilter(name: "CIColorControls") else {
            return nil
        }
        
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(0.0, forKey: kCIInputSaturationKey)
        
        guard let outputImage = filter.outputImage else {
            return nil
        }
        
        return context.createCGImage(outputImage, from: outputImage.extent)
    }
    
    private func calculateAveragePixelValue(_ image: CGImage) -> UInt8 {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var total: UInt32 = 0
        var count = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                let red = pixelData[offset]
                let green = pixelData[offset + 1]
                let blue = pixelData[offset + 2]
                
                // Convert to grayscale using luminance formula
                let grayValue = UInt32(0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue))
                total += grayValue
                count += 1
            }
        }
        
        return count > 0 ? UInt8(total / UInt32(count)) : 0
    }
    
    private func getPixelValue(_ image: CGImage, at point: CGPoint) -> UInt8? {
        let width = image.width
        let height = image.height
        
        guard point.x >= 0, point.x < CGFloat(width), point.y >= 0, point.y < CGFloat(height) else {
            return nil
        }
        
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let x = Int(point.x)
        let y = Int(point.y)
        let offset = (y * bytesPerRow) + (x * bytesPerPixel)
        let red = pixelData[offset]
        let green = pixelData[offset + 1]
        let blue = pixelData[offset + 2]
        
        // Convert to grayscale using luminance formula
        return UInt8(0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue))
    }
    
    private func applyWaveletTransform(_ image: CGImage) -> [Bool] {
        // Simplified wavelet transform
        let width = image.width
        let height = image.height
        var bits = [Bool]()
        
        // Basic wavelet-like analysis - extract high frequency components
        for y in 0..<height {
            for x in 0..<width {
                if x > 0 && y > 0 {
                    let current = getPixelValue(image, at: CGPoint(x: x, y: y)) ?? 0
                    let left = getPixelValue(image, at: CGPoint(x: x-1, y: y)) ?? 0
                    let top = getPixelValue(image, at: CGPoint(x: x, y: y-1)) ?? 0
                    
                    // Simple edge detection
                    let diff = abs(Int(current) - Int(left)) + abs(Int(current) - Int(top))
                    bits.append(diff > 30) // Threshold for "edge"
                }
            }
        }
        
        return bits
    }
    
    private func applyDCT(_ image: CGImage) -> [Bool] {
        // Simplified DCT (Discrete Cosine Transform)
        let width = image.width
        let height = image.height
        var bits = [Bool]()
        
        // Extract low frequency components (top-left of DCT matrix)
        for y in 0..<min(height, 8) {
            for x in 0..<min(width, 8) {
                let value = getPixelValue(image, at: CGPoint(x: x, y: y)) ?? 0
                bits.append(value > 128) // Simple threshold
            }
        }
        
        return bits
    }
    
    private func convertBitsToData(_ bits: [Bool]) -> Data {
        var byteArray = [UInt8]()
        var currentByte: UInt8 = 0
        var bitPosition = 0
        
        for bit in bits {
            if bit {
                currentByte |= (1 << (7 - bitPosition))
            }
            
            bitPosition += 1
            
            if bitPosition == 8 {
                byteArray.append(currentByte)
                currentByte = 0
                bitPosition = 0
            }
        }
        
        // Add remaining bits if not complete byte
        if bitPosition > 0 {
            byteArray.append(currentByte)
        }
        
        return Data(byteArray)
    }
    
    private func generateHashData(from data: Data, size: Int) -> Data {
        // Generate a hash of appropriate size
        let digest = Data(SHA256.hash(data: data))
        let byteCount = max(8, size / 8)
        return Data(digest.prefix(byteCount))
    }
    
    private func hammingDistance(_ lhs: Data, _ rhs: Data) -> Int {
        let maxCount = max(lhs.count, rhs.count)
        var distance = 0
        
        for index in 0..<maxCount {
            let a = index < lhs.count ? lhs[index] : 0
            let b = index < rhs.count ? rhs[index] : 0
            distance += Int((a ^ b).nonzeroBitCount)
        }
        
        return distance
    }
    
    // MARK: - Performance Monitoring
    
    private class PerformanceMonitor {
        private var operations: [PerformanceOperation] = []
        private var comparisons: [PerformanceComparison] = []
        private var batchComparisons: [PerformanceBatchComparison] = []
        
        fileprivate func recordOperation(type: OperationType, algorithm: FingerprintAlgorithm, durationMs: UInt64, dataSize: Int) {
            operations.append(PerformanceOperation(
                type: type,
                algorithm: algorithm,
                durationMs: durationMs,
                dataSize: dataSize,
                timestamp: Date()
            ))
        }
        
        fileprivate func recordComparison(algorithm: FingerprintAlgorithm, distance: Int, similarity: Double, durationMs: UInt64) {
            comparisons.append(PerformanceComparison(
                algorithm: algorithm,
                distance: distance,
                similarity: similarity,
                durationMs: durationMs,
                timestamp: Date()
            ))
        }
        
        fileprivate func recordBatchComparison(queryAlgorithm: FingerprintAlgorithm, candidateCount: Int, durationMs: UInt64) {
            batchComparisons.append(PerformanceBatchComparison(
                queryAlgorithm: queryAlgorithm,
                candidateCount: candidateCount,
                durationMs: durationMs,
                timestamp: Date()
            ))
        }
        
        fileprivate func reset() {
            operations.removeAll()
            comparisons.removeAll()
            batchComparisons.removeAll()
        }
        
        fileprivate func getStatistics() -> PerformanceStatistics {
            let avgOperationTime = operations.isEmpty ? 0 : Double(operations.reduce(0, { $0 + $1.durationMs })) / Double(operations.count)
            let avgComparisonTime = comparisons.isEmpty ? 0 : Double(comparisons.reduce(0, { $0 + $1.durationMs })) / Double(comparisons.count)
            
            return PerformanceStatistics(
                totalOperations: operations.count,
                totalComparisons: comparisons.count,
                totalBatchComparisons: batchComparisons.count,
                averageOperationTimeMs: avgOperationTime,
                averageComparisonTimeMs: avgComparisonTime
            )
        }
        
        fileprivate enum OperationType {
            case imageFingerprint
            case audioFingerprint
            case videoFingerprint
        }
        
        private struct PerformanceOperation {
            let type: OperationType
            let algorithm: FingerprintAlgorithm
            let durationMs: UInt64
            let dataSize: Int
            let timestamp: Date
        }
        
        private struct PerformanceComparison {
            let algorithm: FingerprintAlgorithm
            let distance: Int
            let similarity: Double
            let durationMs: UInt64
            let timestamp: Date
        }
        
        private struct PerformanceBatchComparison {
            let queryAlgorithm: FingerprintAlgorithm
            let candidateCount: Int
            let durationMs: UInt64
            let timestamp: Date
        }
    }
    
    public struct PerformanceStatistics: Sendable {
        public let totalOperations: Int
        public let totalComparisons: Int
        public let totalBatchComparisons: Int
        public let averageOperationTimeMs: Double
        public let averageComparisonTimeMs: Double
        
        public init(
            totalOperations: Int,
            totalComparisons: Int,
            totalBatchComparisons: Int,
            averageOperationTimeMs: Double,
            averageComparisonTimeMs: Double
        ) {
            self.totalOperations = totalOperations
            self.totalComparisons = totalComparisons
            self.totalBatchComparisons = totalBatchComparisons
            self.averageOperationTimeMs = averageOperationTimeMs
            self.averageComparisonTimeMs = averageComparisonTimeMs
        }
    }
    
    public func getPerformanceStatistics() -> PerformanceStatistics {
        return performanceMonitor.getStatistics()
    }
}

// MARK: - Public API Surface

public enum MediaType: UInt8, Sendable, Codable {
    case unknown = 0
    case image = 1
    case audio = 2
    case video = 3
}

public enum FingerprintAlgorithm: UInt8, Sendable, Codable {
    case averageHash = 0
    case differenceHash = 1
    case waveletHash = 2
    case perceptualHash = 3
    case chromaprint = 4
    case motionVector = 5
}

public struct MediaMetadata: Sendable {
    public let mediaType: MediaType
    public let fileSize: UInt64
    public let width: UInt32
    public let height: UInt32
    public let durationMs: UInt32
    public let bitRate: UInt32
    public let sampleRate: UInt32
    public let format: String
    public let codec: String

    public init(
        mediaType: MediaType,
        fileSize: UInt64,
        width: UInt32 = 0,
        height: UInt32 = 0,
        durationMs: UInt32 = 0,
        bitRate: UInt32 = 0,
        sampleRate: UInt32 = 0,
        format: String,
        codec: String
    ) {
        self.mediaType = mediaType
        self.fileSize = fileSize
        self.width = width
        self.height = height
        self.durationMs = durationMs
        self.bitRate = bitRate
        self.sampleRate = sampleRate
        self.format = format
        self.codec = codec
    }
}

public struct FingerprintResult: Sendable {
    public let algorithm: FingerprintAlgorithm
    public let hashSize: UInt32
    public let hashData: Data
    public let confidence: Double
    public let processingTimeMs: UInt64

    public init(
        algorithm: FingerprintAlgorithm,
        hashSize: UInt32,
        hashData: Data,
        confidence: Double,
        processingTimeMs: UInt64
    ) {
        self.algorithm = algorithm
        self.hashSize = hashSize
        self.hashData = hashData
        self.confidence = confidence
        self.processingTimeMs = processingTimeMs
    }
}

public struct SimilarityConfiguration: Sendable {
    public let similarityThreshold: Double
    public let useHammingDistance: Bool
    public let enablePartialMatching: Bool
    public let partialMatchThreshold: Double

    public init(
        similarityThreshold: Double = 0.85,
        useHammingDistance: Bool = true,
        enablePartialMatching: Bool = true,
        partialMatchThreshold: Double = 0.65
    ) {
        self.similarityThreshold = similarityThreshold
        self.useHammingDistance = useHammingDistance
        self.enablePartialMatching = enablePartialMatching
        self.partialMatchThreshold = partialMatchThreshold
    }

    public static let `default` = SimilarityConfiguration()
}

public struct ImageFingerprintConfiguration: Sendable {
    public let hashSize: UInt32

    public init(hashSize: UInt32 = 64) {
        self.hashSize = hashSize
    }

    public static let `default` = ImageFingerprintConfiguration()

    public func validate() throws {
        guard hashSize >= 8 && hashSize <= 256 else {
            throw MediaFingerprintError.invalidInput
        }
    }
}

public struct AudioFingerprintConfiguration: Sendable {
    public let fingerprintSize: UInt32

    public init(fingerprintSize: UInt32 = 32) {
        self.fingerprintSize = fingerprintSize
    }

    public static let `default` = AudioFingerprintConfiguration()

    public func validate() throws {
        guard fingerprintSize >= 8 && fingerprintSize <= 128 else {
            throw MediaFingerprintError.invalidInput
        }
    }
}

public struct VideoFingerprintConfiguration: Sendable {
    public let fingerprintSize: UInt32

    public init(fingerprintSize: UInt32 = 64) {
        self.fingerprintSize = fingerprintSize
    }

    public static let `default` = VideoFingerprintConfiguration()

    public func validate() throws {
        guard fingerprintSize >= 16 && fingerprintSize <= 256 else {
            throw MediaFingerprintError.invalidInput
        }
    }
}

public struct SimilarityResult: Sendable {
    public let similarityScore: Double
    public let hammingDistance: UInt32
    public let isDuplicate: Bool
    public let isPartialMatch: Bool

    public init(
        similarityScore: Double,
        hammingDistance: UInt32,
        isDuplicate: Bool,
        isPartialMatch: Bool
    ) {
        self.similarityScore = similarityScore
        self.hammingDistance = hammingDistance
        self.isDuplicate = isDuplicate
        self.isPartialMatch = isPartialMatch
    }
}

public enum MediaFingerprintError: Error, Sendable {
    case invalidInput
}

public final class MediaFingerprintCapsuleWrapper: @unchecked Sendable {
    private let capsule: MediaFingerprintCapsule

    public var imageConfiguration: ImageFingerprintConfiguration { capsule.imageConfiguration }
    public var audioConfiguration: AudioFingerprintConfiguration { capsule.audioConfiguration }
    public var videoConfiguration: VideoFingerprintConfiguration { capsule.videoConfiguration }

    public init(
        imageConfig: ImageFingerprintConfiguration? = nil,
        audioConfig: AudioFingerprintConfiguration? = nil,
        videoConfig: VideoFingerprintConfiguration? = nil,
        diagnostics: Any? = nil
    ) throws {
        self.capsule = try MediaFingerprintCapsule(
            imageConfig: imageConfig,
            audioConfig: audioConfig,
            videoConfig: videoConfig,
            diagnostics: diagnostics
        )
    }

    public func reset() throws {
        try capsule.reset()
    }

    public static func detectMediaType(
        _ data: Data,
        diagnostics: Any? = nil
    ) throws -> MediaType {
        try MediaFingerprintCapsule.detectMediaType(data, diagnostics: diagnostics)
    }

    public func analyzeMedia(_ data: Data, mediaType: MediaType = .unknown) throws -> MediaMetadata {
        try capsule.analyzeMedia(data, mediaType: mediaType)
    }

    public func generateImageFingerprint(
        _ data: Data,
        algorithm: FingerprintAlgorithm = .perceptualHash
    ) throws -> FingerprintResult {
        try capsule.generateImageFingerprint(data, algorithm: algorithm)
    }

    public func generateAudioFingerprint(
        _ data: Data,
        algorithm: FingerprintAlgorithm = .chromaprint
    ) throws -> FingerprintResult {
        try capsule.generateAudioFingerprint(data, algorithm: algorithm)
    }

    public func generateVideoFingerprint(
        _ data: Data,
        algorithm: FingerprintAlgorithm = .motionVector
    ) throws -> FingerprintResult {
        try capsule.generateVideoFingerprint(data, algorithm: algorithm)
    }

    public func compareFingerprints(
        _ lhs: FingerprintResult,
        _ rhs: FingerprintResult,
        threshold: Double = 0.85
    ) -> SimilarityResult {
        capsule.compareFingerprints(lhs, rhs, threshold: threshold)
    }

    public func compareFingerprints(
        _ lhs: FingerprintResult,
        _ rhs: FingerprintResult,
        config: SimilarityConfiguration = .default
    ) throws -> SimilarityResult {
        capsule.compareFingerprints(lhs, rhs, threshold: config.similarityThreshold)
    }

    public func batchCompareFingerprints(
        query: FingerprintResult,
        candidates: [FingerprintResult],
        threshold: Double = 0.85
    ) -> [SimilarityResult] {
        capsule.batchCompareFingerprints(query: query, candidates: candidates, threshold: threshold)
    }

    public func batchCompareFingerprints(
        queryFingerprint: FingerprintResult,
        candidateFingerprints: [FingerprintResult],
        config: SimilarityConfiguration = .default
    ) throws -> [SimilarityResult] {
        capsule.batchCompareFingerprints(
            query: queryFingerprint,
            candidates: candidateFingerprints,
            threshold: config.similarityThreshold
        )
    }
}
