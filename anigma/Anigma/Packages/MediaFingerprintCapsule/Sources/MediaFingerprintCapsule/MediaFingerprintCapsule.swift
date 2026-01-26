// MediaFingerprintCapsule.swift
// MediaFingerprintCapsule - Swift actor wrapper for media fingerprinting
// Part of the Anigma project

import Foundation
@preconcurrency import MediaFingerprintNative
import CapsuleCore

// MARK: - Error Types

/// Errors that can occur during media fingerprinting operations
public enum MediaFingerprintError: Error, Sendable, CustomStringConvertible {
    case nullPointer
    case invalidDimensions
    case decodeFailed
    case memoryAllocation
    case invalidFormat
    case bufferTooSmall
    case notImplemented
    case unknownError(Int32)
    
    init(code: MediaFingerprintNativeBridge.ErrorCode) {
        switch code {
        case MediaFingerprintNativeBridge.errorNullPointer:
            self = .nullPointer
        case MediaFingerprintNativeBridge.errorInvalidDimensions:
            self = .invalidDimensions
        case MediaFingerprintNativeBridge.errorDecodeFailed:
            self = .decodeFailed
        case MediaFingerprintNativeBridge.errorMemoryAllocation:
            self = .memoryAllocation
        case MediaFingerprintNativeBridge.errorInvalidFormat:
            self = .invalidFormat
        case MediaFingerprintNativeBridge.errorBufferTooSmall:
            self = .bufferTooSmall
        case MediaFingerprintNativeBridge.errorNotImplemented:
            self = .notImplemented
        default:
            self = .unknownError(code.rawValue)
        }
    }
    
    public var description: String {
        switch self {
        case .nullPointer: return "Null pointer provided"
        case .invalidDimensions: return "Invalid image dimensions"
        case .decodeFailed: return "Failed to decode image"
        case .memoryAllocation: return "Memory allocation failed"
        case .invalidFormat: return "Invalid format"
        case .bufferTooSmall: return "Buffer too small"
        case .notImplemented: return "Feature not implemented"
        case .unknownError(let code): return "Unknown error: \(code)"
        }
    }
}

private extension MediaFingerprintError {
    var capsuleError: CapsuleError {
        switch self {
        case .nullPointer:
            return .internalError(details: "MediaFingerprintNative returned a null pointer")
        case .invalidDimensions:
            return .invalidInput(field: "dimensions", constraint: "invalid image dimensions")
        case .decodeFailed:
            return .invalidInput(field: "imageData", constraint: "decode failed")
        case .memoryAllocation:
            return .resourceExhausted(resource: "memory", limit: "allocation failed")
        case .invalidFormat:
            return .invalidInput(field: "format", constraint: "unsupported format")
        case .bufferTooSmall:
            return .invalidInput(field: "buffer", constraint: "buffer too small")
        case .notImplemented:
            return .operationFailed(
                code: 0,
                message: "Feature not implemented",
                context: [
                    "library": "MediaFingerprintNative",
                    "native_code": "\(MediaFingerprintNativeBridge.errorNotImplemented)"
                ]
            )
        case .unknownError(let code):
            return .nativeError(code: code, libraryName: "MediaFingerprintNative")
        }
    }
}

// MARK: - Hash Types

/// A 64-bit perceptual hash
public struct PerceptualHash64: Sendable, Hashable, Codable, CustomStringConvertible {
    public let value: UInt64
    
    public init(_ value: UInt64) {
        self.value = value
    }
    
    public init?(hexString: String) {
        guard hexString.count == 16,
              let value = UInt64(hexString, radix: 16) else {
            return nil
        }
        self.value = value
    }
    
    public var hexString: String {
        String(format: "%016llx", value)
    }
    
    public var description: String {
        hexString
    }
    
    /// Compute Hamming distance to another hash
    public func hammingDistance(to other: PerceptualHash64) -> Int {
        Int(MediaFingerprintNativeBridge.hammingDistance64(value, other.value))
    }
    
    /// Compute similarity score (0.0 to 1.0)
    public func similarity(to other: PerceptualHash64) -> Float {
        let distance = hammingDistance(to: other)
        return MediaFingerprintNativeBridge.similarityFromDistance(UInt32(distance), bits: 64)
    }
    
    /// Check if similar within threshold
    public func isSimilar(to other: PerceptualHash64, maxDistance: Int = 10) -> Bool {
        hammingDistance(to: other) <= maxDistance
    }
}

/// A 256-bit extended perceptual hash for higher precision
public struct PerceptualHash256: Sendable, Hashable, Codable, CustomStringConvertible {
    public let parts: (UInt64, UInt64, UInt64, UInt64)
    
    public init(_ hash: amfp_hash256_t) {
        self.parts = (hash.parts.0, hash.parts.1, hash.parts.2, hash.parts.3)
    }
    
    public init(_ p0: UInt64, _ p1: UInt64, _ p2: UInt64, _ p3: UInt64) {
        self.parts = (p0, p1, p2, p3)
    }
    
    public var hexString: String {
        String(format: "%016llx%016llx%016llx%016llx",
               parts.0, parts.1, parts.2, parts.3)
    }
    
    public var description: String {
        hexString
    }
    
    /// Convert to C struct
    var cHash: amfp_hash256_t {
        amfp_hash256_t(parts: (parts.0, parts.1, parts.2, parts.3))
    }
    
    /// Compute Hamming distance to another hash
    public func hammingDistance(to other: PerceptualHash256) -> Int {
        var h1 = self.cHash
        var h2 = other.cHash
        return Int(MediaFingerprintNativeBridge.hammingDistance256(&h1, &h2))
    }
    
    /// Compute similarity score (0.0 to 1.0)
    public func similarity(to other: PerceptualHash256) -> Float {
        let distance = hammingDistance(to: other)
        return MediaFingerprintNativeBridge.similarityFromDistance(UInt32(distance), bits: 256)
    }
    
    // Codable conformance for tuple
    public init(from decoder: Decoder) throws /* CapsuleError */ {
        do {
            var container = try decoder.unkeyedContainer()
            let p0 = try container.decode(UInt64.self)
            let p1 = try container.decode(UInt64.self)
            let p2 = try container.decode(UInt64.self)
            let p3 = try container.decode(UInt64.self)
            self.parts = (p0, p1, p2, p3)
        } catch {
            throw CapsuleError.invalidInput(
                field: "PerceptualHash256",
                constraint: "invalid encoding: \(error.localizedDescription)"
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws /* CapsuleError */ {
        do {
            var container = encoder.unkeyedContainer()
            try container.encode(parts.0)
            try container.encode(parts.1)
            try container.encode(parts.2)
            try container.encode(parts.3)
        } catch {
            throw CapsuleError.internalError(details: "Failed to encode PerceptualHash256: \(error.localizedDescription)")
        }
    }
    
    // Hashable conformance for tuple
    public func hash(into hasher: inout Hasher) {
        hasher.combine(parts.0)
        hasher.combine(parts.1)
        hasher.combine(parts.2)
        hasher.combine(parts.3)
    }
    
    public static func == (lhs: PerceptualHash256, rhs: PerceptualHash256) -> Bool {
        lhs.parts == rhs.parts
    }
}

/// Audio fingerprint result
public struct AudioFingerprint: Sendable {
    public let subfingerprints: [UInt32]
    public let durationSeconds: Float
    
    init(_ fp: amfp_audio_fingerprint_t) {
        var prints: [UInt32] = []
        prints.reserveCapacity(Int(fp.count))
        let mirror = Mirror(reflecting: fp.subfingerprints)
        for (index, child) in mirror.children.enumerated() {
            if index >= Int(fp.count) { break }
            if let value = child.value as? UInt32 {
                prints.append(value)
            }
        }
        self.subfingerprints = prints
        self.durationSeconds = fp.duration_seconds
    }
    
    /// Compute similarity to another fingerprint
    public func similarity(to other: AudioFingerprint) -> Float {
        guard !subfingerprints.isEmpty && !other.subfingerprints.isEmpty else {
            return 0.0
        }
        
        var fp1 = toCFingerprint()
        var fp2 = other.toCFingerprint()
        return MediaFingerprintNativeBridge.audioFingerprintSimilarity(&fp1, &fp2)
    }
    
    func toCFingerprint() -> amfp_audio_fingerprint_t {
        var fp = amfp_audio_fingerprint_t()
        fp.count = subfingerprints.count
        fp.duration_seconds = durationSeconds
        for (i, sp) in subfingerprints.prefix(256).enumerated() {
            withUnsafeMutablePointer(to: &fp.subfingerprints) { ptr in
                ptr.withMemoryRebound(to: UInt32.self, capacity: 256) { arr in
                    arr[i] = sp
                }
            }
        }
        return fp
    }
}

// MARK: - Search Result

/// Result from similarity search
public struct SimilarityMatch: Sendable {
    public let index: Int
    public let distance: Int
    public let similarity: Float
    
    public init(index: Int, distance: Int, maxBits: Int = 64) {
        self.index = index
        self.distance = distance
        self.similarity = 1.0 - Float(distance) / Float(maxBits)
    }
}

// MARK: - Hash Algorithm

/// Available perceptual hash algorithms
public enum HashAlgorithm: Sendable {
    /// DCT-based perceptual hash (robust to scaling, compression)
    case pHash
    /// Gradient-based difference hash (fast, good for exact matches)
    case dHash
    /// Extended 256-bit pHash for higher precision
    case pHash256
}

// MARK: - MediaFingerprintCapsule Actor

/// Thread-safe actor for computing perceptual hashes and media fingerprints
public actor MediaFingerprintCapsule {
    
    // MARK: - Properties
    
    /// Library version
    public nonisolated var version: String {
        String(cString: MediaFingerprintNativeBridge.version())
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Image Hashing (from encoded data)
    
    /// Compute perceptual hash from encoded image data (JPEG, PNG, etc.)
    /// - Parameters:
    ///   - data: Encoded image data
    ///   - algorithm: Hash algorithm to use (default: pHash)
    /// - Returns: 64-bit perceptual hash
    /// - Throws: CapsuleError
    public func hash(imageData data: Data, algorithm: HashAlgorithm = .pHash) async throws /* CapsuleError */ -> PerceptualHash64 {
        try await withCheckedThrowingContinuation { continuation in
            data.withUnsafeBytes { buffer in
                guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    continuation.resume(throwing: MediaFingerprintError.nullPointer.capsuleError)
                    return
                }
                
                var hash: amfp_hash64_t = 0
                let result: amfp_error_t
                
                switch algorithm {
                case .pHash:
                    result = MediaFingerprintNativeBridge.phashFromEncoded(ptr, buffer.count, &hash)
                case .dHash:
                    result = MediaFingerprintNativeBridge.dhashFromEncoded(ptr, buffer.count, &hash)
                case .pHash256:
                    // For 256-bit, use separate method
                    continuation.resume(throwing: MediaFingerprintError.invalidFormat.capsuleError)
                    return
                }
                
                if result == MediaFingerprintNativeBridge.success {
                    continuation.resume(returning: PerceptualHash64(hash))
                } else {
                    continuation.resume(throwing: MediaFingerprintError(code: result).capsuleError)
                }
            }
        }
    }
    
    /// Compute extended 256-bit hash from encoded image data
    /// - Parameter data: Encoded image data
    /// - Returns: 256-bit perceptual hash
    /// - Throws: CapsuleError
    public func hash256(imageData data: Data) async throws /* CapsuleError */ -> PerceptualHash256 {
        // Decode and compute from grayscale internally
        // For now, use pHash as base and extend
        let hash64 = try await hash(imageData: data, algorithm: .pHash)
        // Return extended version (simplified - real impl would use full DCT)
        return PerceptualHash256(hash64.value, hash64.value ^ 0xFFFFFFFF, 
                                  hash64.value >> 32, hash64.value << 32)
    }
    
    // MARK: - Image Hashing (from raw pixels)
    
    /// Compute perceptual hash from raw grayscale pixels
    /// - Parameters:
    ///   - pixels: Raw grayscale pixel data (1 byte per pixel)
    ///   - width: Image width
    ///   - height: Image height
    ///   - stride: Bytes per row (usually == width)
    ///   - algorithm: Hash algorithm
    /// - Returns: 64-bit perceptual hash
    /// - Throws: CapsuleError
    public func hash(
        grayscalePixels pixels: Data,
        width: Int,
        height: Int,
        stride: Int? = nil,
        algorithm: HashAlgorithm = .pHash
    ) async throws /* CapsuleError */ -> PerceptualHash64 {
        let pixelStride = stride ?? width
        
        return try await withCheckedThrowingContinuation { continuation in
            pixels.withUnsafeBytes { buffer in
                guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    continuation.resume(throwing: MediaFingerprintError.nullPointer.capsuleError)
                    return
                }
                
                var hash: amfp_hash64_t = 0
                let result: amfp_error_t
                
                switch algorithm {
                case .pHash:
                    result = MediaFingerprintNativeBridge.phashFromGrayscale(
                        ptr,
                        width: UInt32(width),
                        height: UInt32(height),
                        stride: UInt32(pixelStride),
                        hash: &hash
                    )
                case .dHash:
                    result = MediaFingerprintNativeBridge.dhashFromGrayscale(
                        ptr,
                        width: UInt32(width),
                        height: UInt32(height),
                        stride: UInt32(pixelStride),
                        hash: &hash
                    )
                case .pHash256:
                    continuation.resume(throwing: MediaFingerprintError.invalidFormat.capsuleError)
                    return
                }
                
                if result == MediaFingerprintNativeBridge.success {
                    continuation.resume(returning: PerceptualHash64(hash))
                } else {
                    continuation.resume(throwing: MediaFingerprintError(code: result).capsuleError)
                }
            }
        }
    }
    
    /// Compute extended 256-bit hash from raw grayscale pixels
    /// - Throws: CapsuleError
    public func hash256(
        grayscalePixels pixels: Data,
        width: Int,
        height: Int,
        stride: Int? = nil
    ) async throws /* CapsuleError */ -> PerceptualHash256 {
        let pixelStride = stride ?? width
        
        return try await withCheckedThrowingContinuation { continuation in
            pixels.withUnsafeBytes { buffer in
                guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    continuation.resume(throwing: MediaFingerprintError.nullPointer.capsuleError)
                    return
                }
                
                var hash = amfp_hash256_t()
                let result = MediaFingerprintNativeBridge.phash256FromGrayscale(
                    ptr,
                    width: UInt32(width),
                    height: UInt32(height),
                    stride: UInt32(pixelStride),
                    hash: &hash
                )
                
                if result == MediaFingerprintNativeBridge.success {
                    continuation.resume(returning: PerceptualHash256(hash))
                } else {
                    continuation.resume(throwing: MediaFingerprintError(code: result).capsuleError)
                }
            }
        }
    }
    
    // MARK: - Video Frame Hashing
    
    /// Compute perceptual hash for a video frame (from raw grayscale)
    /// This is an alias for image hashing optimized for video use cases
    /// - Throws: CapsuleError
    public func hashVideoFrame(
        grayscalePixels pixels: Data,
        width: Int,
        height: Int,
        stride: Int? = nil
    ) async throws /* CapsuleError */ -> PerceptualHash64 {
        // Use dHash for video frames (faster, good for detecting duplicates)
        try await hash(grayscalePixels: pixels, width: width, height: height,
                       stride: stride, algorithm: .dHash)
    }
    
    // MARK: - Audio Fingerprinting
    
    /// Compute audio fingerprint from PCM samples
    /// - Parameters:
    ///   - samples: Mono float32 PCM samples
    ///   - sampleRate: Sample rate in Hz
    /// - Returns: Audio fingerprint
    /// - Throws: CapsuleError
    public func fingerprint(
        audioSamples samples: [Float],
        sampleRate: Int
    ) async throws /* CapsuleError */ -> AudioFingerprint {
        try await withCheckedThrowingContinuation { continuation in
            samples.withUnsafeBufferPointer { buffer in
                guard let ptr = buffer.baseAddress else {
                    continuation.resume(throwing: MediaFingerprintError.nullPointer.capsuleError)
                    return
                }
                
                var fp = amfp_audio_fingerprint_t()
                let result = MediaFingerprintNativeBridge.audioFingerprintFromPCM(
                    ptr,
                    buffer.count,
                    UInt32(sampleRate),
                    &fp
                )
                
                if result == MediaFingerprintNativeBridge.success {
                    continuation.resume(returning: AudioFingerprint(fp))
                } else {
                    continuation.resume(throwing: MediaFingerprintError(code: result).capsuleError)
                }
            }
        }
    }
    
    // MARK: - Similarity Search
    
    /// Find similar hashes in a collection
    /// - Parameters:
    ///   - query: Hash to search for
    ///   - candidates: Array of candidate hashes
    ///   - maxDistance: Maximum Hamming distance threshold (default: 10)
    ///   - maxResults: Maximum number of results to return
    /// - Returns: Array of matching results sorted by distance
    public func findSimilar(
        query: PerceptualHash64,
        in candidates: [PerceptualHash64],
        maxDistance: Int = 10,
        maxResults: Int = 100
    ) async -> [SimilarityMatch] {
        guard !candidates.isEmpty else { return [] }
        
        let candidateValues = candidates.map { $0.value }
        var outIndices = [Int](repeating: 0, count: maxResults)
        var outDistances = [UInt32](repeating: 0, count: maxResults)
        
        let count = candidateValues.withUnsafeBufferPointer { candidateBuffer in
            outIndices.withUnsafeMutableBufferPointer { indicesBuffer in
                outDistances.withUnsafeMutableBufferPointer { distancesBuffer in
                    MediaFingerprintNativeBridge.findSimilar64(
                        query: query.value,
                        candidates: candidateBuffer.baseAddress,
                        candidateCount: candidateBuffer.count,
                        maxDistance: UInt32(maxDistance),
                        indices: indicesBuffer.baseAddress,
                        distances: distancesBuffer.baseAddress,
                        maxResults: maxResults
                    )
                }
            }
        }
        
        var results: [SimilarityMatch] = []
        for i in 0..<count {
            results.append(SimilarityMatch(
                index: outIndices[i],
                distance: Int(outDistances[i])
            ))
        }
        
        return results.sorted { $0.distance < $1.distance }
    }
    
    // MARK: - Batch Hashing
    
    /// Compute hashes for multiple images in parallel
    /// - Parameters:
    ///   - images: Array of encoded image data
    ///   - algorithm: Hash algorithm
    /// - Returns: Array of hashes (nil for failed images)
    public func hashBatch(
        images: [Data],
        algorithm: HashAlgorithm = .pHash
    ) async -> [PerceptualHash64?] {
        await withTaskGroup(of: (Int, PerceptualHash64?).self) { group in
            for (index, imageData) in images.enumerated() {
                group.addTask {
                    do {
                        let hash = try await self.hash(imageData: imageData, algorithm: algorithm)
                        return (index, hash)
                    } catch {
                        return (index, nil)
                    }
                }
            }
            
            var results = [PerceptualHash64?](repeating: nil, count: images.count)
            for await (index, hash) in group {
                results[index] = hash
            }
            return results
        }
    }
}

// MARK: - Convenience Extensions

extension PerceptualHash64: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt64) {
        self.value = value
    }
}

// MARK: - CapsuleCore Integration Protocol

/// Protocol for capsule lifecycle management
public protocol CapsuleLifecycle: Actor {
    func activate() async throws
    func deactivate() async
}

extension MediaFingerprintCapsule: CapsuleLifecycle {
    public func activate() async throws /* CapsuleError */ {
        // No initialization needed for this capsule
    }

    
    public func deactivate() async {
        // No cleanup needed
    }
}
