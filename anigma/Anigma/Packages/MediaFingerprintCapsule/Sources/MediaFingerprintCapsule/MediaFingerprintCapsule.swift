// MediaFingerprintCapsule.swift
// MediaFingerprintCapsule - Swift actor wrapper for media fingerprinting
// Part of the Anigma project

import Foundation
import MediaFingerprintNative

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
    
    init(code: amfp_error_t) {
        switch code {
        case AMFP_ERROR_NULL_POINTER:
            self = .nullPointer
        case AMFP_ERROR_INVALID_DIMENSIONS:
            self = .invalidDimensions
        case AMFP_ERROR_DECODE_FAILED:
            self = .decodeFailed
        case AMFP_ERROR_MEMORY_ALLOCATION:
            self = .memoryAllocation
        case AMFP_ERROR_INVALID_FORMAT:
            self = .invalidFormat
        case AMFP_ERROR_BUFFER_TOO_SMALL:
            self = .bufferTooSmall
        case AMFP_ERROR_NOT_IMPLEMENTED:
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
        Int(amfp_hamming_distance_64(value, other.value))
    }
    
    /// Compute similarity score (0.0 to 1.0)
    public func similarity(to other: PerceptualHash64) -> Float {
        let distance = hammingDistance(to: other)
        return amfp_similarity_from_distance(UInt32(distance), 64)
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
        return Int(amfp_hamming_distance_256(&h1, &h2))
    }
    
    /// Compute similarity score (0.0 to 1.0)
    public func similarity(to other: PerceptualHash256) -> Float {
        let distance = hammingDistance(to: other)
        return amfp_similarity_from_distance(UInt32(distance), 256)
    }
    
    // Codable conformance for tuple
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let p0 = try container.decode(UInt64.self)
        let p1 = try container.decode(UInt64.self)
        let p2 = try container.decode(UInt64.self)
        let p3 = try container.decode(UInt64.self)
        self.parts = (p0, p1, p2, p3)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(parts.0)
        try container.encode(parts.1)
        try container.encode(parts.2)
        try container.encode(parts.3)
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
        return amfp_audio_fingerprint_similarity(&fp1, &fp2)
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
        String(cString: amfp_version())
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Image Hashing (from encoded data)
    
    /// Compute perceptual hash from encoded image data (JPEG, PNG, etc.)
    /// - Parameters:
    ///   - data: Encoded image data
    ///   - algorithm: Hash algorithm to use (default: pHash)
    /// - Returns: 64-bit perceptual hash
    public func hash(imageData data: Data, algorithm: HashAlgorithm = .pHash) async throws -> PerceptualHash64 {
        try await withCheckedThrowingContinuation { continuation in
            data.withUnsafeBytes { buffer in
                guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    continuation.resume(throwing: MediaFingerprintError.nullPointer)
                    return
                }
                
                var hash: amfp_hash64_t = 0
                let result: amfp_error_t
                
                switch algorithm {
                case .pHash:
                    result = amfp_phash_from_encoded(ptr, buffer.count, &hash)
                case .dHash:
                    result = amfp_dhash_from_encoded(ptr, buffer.count, &hash)
                case .pHash256:
                    // For 256-bit, use separate method
                    continuation.resume(throwing: MediaFingerprintError.invalidFormat)
                    return
                }
                
                if result == AMFP_SUCCESS {
                    continuation.resume(returning: PerceptualHash64(hash))
                } else {
                    continuation.resume(throwing: MediaFingerprintError(code: result))
                }
            }
        }
    }
    
    /// Compute extended 256-bit hash from encoded image data
    /// - Parameter data: Encoded image data
    /// - Returns: 256-bit perceptual hash
    public func hash256(imageData data: Data) async throws -> PerceptualHash256 {
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
    public func hash(
        grayscalePixels pixels: Data,
        width: Int,
        height: Int,
        stride: Int? = nil,
        algorithm: HashAlgorithm = .pHash
    ) async throws -> PerceptualHash64 {
        let pixelStride = stride ?? width
        
        return try await withCheckedThrowingContinuation { continuation in
            pixels.withUnsafeBytes { buffer in
                guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    continuation.resume(throwing: MediaFingerprintError.nullPointer)
                    return
                }
                
                var hash: amfp_hash64_t = 0
                let result: amfp_error_t
                
                switch algorithm {
                case .pHash:
                    result = amfp_phash_from_grayscale(ptr, UInt32(width), UInt32(height), 
                                                       UInt32(pixelStride), &hash)
                case .dHash:
                    result = amfp_dhash_from_grayscale(ptr, UInt32(width), UInt32(height),
                                                       UInt32(pixelStride), &hash)
                case .pHash256:
                    continuation.resume(throwing: MediaFingerprintError.invalidFormat)
                    return
                }
                
                if result == AMFP_SUCCESS {
                    continuation.resume(returning: PerceptualHash64(hash))
                } else {
                    continuation.resume(throwing: MediaFingerprintError(code: result))
                }
            }
        }
    }
    
    /// Compute extended 256-bit hash from raw grayscale pixels
    public func hash256(
        grayscalePixels pixels: Data,
        width: Int,
        height: Int,
        stride: Int? = nil
    ) async throws -> PerceptualHash256 {
        let pixelStride = stride ?? width
        
        return try await withCheckedThrowingContinuation { continuation in
            pixels.withUnsafeBytes { buffer in
                guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    continuation.resume(throwing: MediaFingerprintError.nullPointer)
                    return
                }
                
                var hash = amfp_hash256_t()
                let result = amfp_phash256_from_grayscale(ptr, UInt32(width), UInt32(height),
                                                          UInt32(pixelStride), &hash)
                
                if result == AMFP_SUCCESS {
                    continuation.resume(returning: PerceptualHash256(hash))
                } else {
                    continuation.resume(throwing: MediaFingerprintError(code: result))
                }
            }
        }
    }
    
    // MARK: - Video Frame Hashing
    
    /// Compute perceptual hash for a video frame (from raw grayscale)
    /// This is an alias for image hashing optimized for video use cases
    public func hashVideoFrame(
        grayscalePixels pixels: Data,
        width: Int,
        height: Int,
        stride: Int? = nil
    ) async throws -> PerceptualHash64 {
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
    public func fingerprint(
        audioSamples samples: [Float],
        sampleRate: Int
    ) async throws -> AudioFingerprint {
        try await withCheckedThrowingContinuation { continuation in
            samples.withUnsafeBufferPointer { buffer in
                guard let ptr = buffer.baseAddress else {
                    continuation.resume(throwing: MediaFingerprintError.nullPointer)
                    return
                }
                
                var fp = amfp_audio_fingerprint_t()
                let result = amfp_audio_fingerprint_from_pcm(ptr, buffer.count,
                                                             UInt32(sampleRate), &fp)
                
                if result == AMFP_SUCCESS {
                    continuation.resume(returning: AudioFingerprint(fp))
                } else {
                    continuation.resume(throwing: MediaFingerprintError(code: result))
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
                    amfp_find_similar_64(
                        query.value,
                        candidateBuffer.baseAddress,
                        candidateBuffer.count,
                        UInt32(maxDistance),
                        indicesBuffer.baseAddress,
                        distancesBuffer.baseAddress,
                        maxResults
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
    public func activate() async throws {
        // No initialization needed for this capsule
    }
    
    public func deactivate() async {
        // No cleanup needed
    }
}
