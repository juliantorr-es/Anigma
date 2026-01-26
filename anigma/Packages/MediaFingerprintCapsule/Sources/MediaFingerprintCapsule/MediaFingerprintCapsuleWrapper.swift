import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore
import MediaFingerprintNative

// Static error message constants to ensure proper lifetime management
private let invalidHandleMsg = "Invalid capsule handle"
private let invalidBufferMsg = "Invalid input buffer"
private let invalidConfigMsg = "Invalid configuration"
private let unsupportedFormatMsg = "Unsupported media format"
private let processingFailedMsg = "Media processing failed"

// Helper to create error messages with static string pointers
private func createError(
    code: anigma_status_t,
    message: UnsafePointer<CChar>?,
    detail: UnsafePointer<CChar>? = nil,
    aux: UInt64 = 0
) -> anigma_capsule_error_t {
    return anigma_capsule_error_t(
        code: code,
        message: message,
        detail: detail,
        aux: aux
    )
}

// Helper with string parameter that converts to static pointer
private func createError(
    code: anigma_status_t,
    message: String,
    detail: String? = nil,
    aux: UInt64 = 0
) -> anigma_capsule_error_t {
    // Use static C string literals that persist for program lifetime
    switch message {
    case "Invalid capsule handle":
        return createError(code: code, message: invalidHandleMsg, detail: detail, aux: aux)
    case "Invalid input buffer":
        return createError(code: code, message: invalidBufferMsg, detail: detail, aux: aux)
    case "Invalid configuration":
        return createError(code: code, message: invalidConfigMsg, detail: detail, aux: aux)
    case "Unsupported media format":
        return createError(code: code, message: unsupportedFormatMsg, detail: detail, aux: aux)
    case "Media processing failed":
        return createError(code: code, message: processingFailedMsg, detail: detail, aux: aux)
    default:
        // For any other messages, create a static copy
        return message.withCString { messagePtr in
            let staticPtr = UnsafePointer<CChar>(messagePtr)
            if let detail = detail {
                return detail.withCString { detailPtr in
                    let staticDetail = UnsafePointer<CChar>(detailPtr)
                    return createError(code: code, message: staticPtr, detail: staticDetail, aux: aux)
                }
            } else {
                return createError(code: code, message: staticPtr, detail: nil, aux: aux)
            }
        }
    }
}

/// Swift wrapper for the Media Fingerprint capsule with support for images, audio, and video.
/// Provides comprehensive media analysis and fingerprinting capabilities.
public final class MediaFingerprintCapsuleWrapper: @unchecked Sendable {
    /// Capsule identity information.
    public static var identity: anigma_capsule_identity_t {
        anigma_media_fingerprint_capsule_get_identity()
    }
    
    private var handle: CapsuleHandle<AnyObject>?
    private let imageConfig: ImageFingerprintConfiguration
    private let audioConfig: AudioFingerprintConfiguration
    private let videoConfig: VideoFingerprintConfiguration
    private let lock = NSLock()
    
    /// Configuration used for this capsule.
    public var imageConfiguration: ImageFingerprintConfiguration { imageConfig }
    public var audioConfiguration: AudioFingerprintConfiguration { audioConfig }
    public var videoConfiguration: VideoFingerprintConfiguration { videoConfig }
    
    /// Create a media fingerprint capsule with the given configurations.
    /// - Parameters:
    ///   - imageConfig: Configuration for image fingerprinting.
    ///   - audioConfig: Configuration for audio fingerprinting.
    ///   - videoConfig: Configuration for video fingerprinting.
    public init(
        imageConfig: ImageFingerprintConfiguration? = nil,
        audioConfig: AudioFingerprintConfiguration? = nil,
        videoConfig: VideoFingerprintConfiguration? = nil
    ) throws {
        let imageConfig = imageConfig ?? .default
        let audioConfig = audioConfig ?? .default
        let videoConfig = videoConfig ?? .default
        
        var rawHandle: anigma_media_fingerprint_capsule_t?
        var error = anigma_capsule_error_t()
        
        var cImageConfig = imageConfig.toCStruct()
        var cAudioConfig = audioConfig.toCStruct()
        var cVideoConfig = videoConfig.toCStruct()
        
        let status = anigma_media_fingerprint_capsule_create(
            &cImageConfig,
            &cAudioConfig,
            &cVideoConfig,
            &rawHandle,
            &error
        )
        
        guard status == ANIGMA_OK, let rawHandle = rawHandle else {
            throw capsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: { ptr in
                var mutablePtr: anigma_media_fingerprint_capsule_t? = ptr
                var err = anigma_capsule_error_t()
                _ = anigma_media_fingerprint_capsule_destroy(&mutablePtr, &err)
            }
        )
        
        self.imageConfig = imageConfig
        self.audioConfig = audioConfig
        self.videoConfig = videoConfig
    }
    
    deinit {
        handle?.invalidate()
    }
    
    /// Reset the capsule state for new operations.
    public func reset() throws {
        var error = anigma_capsule_error_t()
        try handle?.withHandle { rawHandle in
            let status = anigma_media_fingerprint_capsule_reset(rawHandle, &error)
            guard status == ANIGMA_OK else {
                throw capsuleError(status: status, error: error)
            }
        }
    }
    
    // MARK: - Media Analysis
    
    /// Detect the media type from raw data.
    /// - Parameter data: Raw media data.
    /// - Returns: Detected media type.
    public static func detectMediaType(_ data: Data) throws -> MediaType {
        guard !data.isEmpty else {
            throw capsuleError(
                status: ANIGMA_ERR_INVALID_ARG,
                error: createError(code: ANIGMA_ERR_INVALID_ARG, message: "Invalid input buffer")
            )
        }
        
        var mediaType = ANIGMA_MEDIA_TYPE_UNKNOWN
        var error = anigma_capsule_error_t()
        
        var buffer = anigma_capsule_buffer_t(
            ptr: UnsafeMutablePointer<UInt8>(mutating: data.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }),
            len: data.count,
            cap: data.count
        )
        
        let status = anigma_media_fingerprint_detect_media_type(&buffer, &mediaType, &error)
        guard status == ANIGMA_OK else {
            throw capsuleError(status: status, error: error)
        }
        
        return MediaType(rawValue: UInt8(mediaType.rawValue)) ?? .unknown
    }
    
    /// Analyze media data and extract metadata.
    /// - Parameters:
    ///   - data: Raw media data.
    ///   - mediaType: Known media type (optional, will auto-detect if unknown).
    /// - Returns: Media metadata.
    public func analyzeMedia(_ data: Data, mediaType: MediaType = .unknown) throws -> MediaMetadata {
        guard !data.isEmpty else {
            throw capsuleError(
                status: ANIGMA_ERR_INVALID_ARG,
                error: createError(code: ANIGMA_ERR_INVALID_ARG, message: "Invalid input buffer")
            )
        }
        
        var metadata = anigma_media_metadata_t()
        var error = anigma_capsule_error_t()
        
        var buffer = anigma_capsule_buffer_t(
            ptr: UnsafeMutablePointer<UInt8>(mutating: data.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }),
            len: data.count,
            cap: data.count
        )
        
        let status = try handle?.withHandle { rawHandle in
            anigma_media_fingerprint_analyze_buffer(
                rawHandle,
                &buffer,
                anigma_media_type_t(UInt32(mediaType.rawValue)),
                &metadata,
                &error
            )
        } ?? ANIGMA_ERR_NOT_INITIALIZED
        
        guard status == ANIGMA_OK else {
            throw capsuleError(status: status, error: error)
        }
        
        return MediaMetadata(
            mediaType: MediaType(rawValue: UInt8(metadata.media_type.rawValue)) ?? .unknown,
            fileSize: metadata.file_size,
            width: metadata.width,
            height: metadata.height,
            durationMs: metadata.duration_ms,
            bitRate: metadata.bit_rate,
            sampleRate: metadata.sample_rate,
            format: withUnsafePointer(to: metadata.format) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: 16) { String(cString: $0) }
            },
            codec: withUnsafePointer(to: metadata.codec) { ptr in
                ptr.withMemoryRebound(to: CChar.self, capacity: 16) { String(cString: $0) }
            }
        )
    }
    
    // MARK: - Fingerprint Generation
    
    /// Generate fingerprint for image data.
    /// - Parameters:
    ///   - data: Raw image data.
    ///   - algorithm: Fingerprint algorithm to use.
    /// - Returns: Fingerprint result.
    public func generateImageFingerprint(
        _ data: Data,
        algorithm: FingerprintAlgorithm
    ) throws -> FingerprintResult {
        return try generateFingerprint(
            data: data,
            algorithm: algorithm,
            generator: anigma_media_fingerprint_generate_image
        )
    }
    
    /// Generate fingerprint for audio data.
    /// - Parameters:
    ///   - data: Raw audio data.
    ///   - algorithm: Fingerprint algorithm to use.
    /// - Returns: Fingerprint result.
    public func generateAudioFingerprint(
        _ data: Data,
        algorithm: FingerprintAlgorithm
    ) throws -> FingerprintResult {
        return try generateFingerprint(
            data: data,
            algorithm: algorithm,
            generator: anigma_media_fingerprint_generate_audio
        )
    }
    
    /// Generate fingerprint for video data.
    /// - Parameters:
    ///   - data: Raw video data.
    ///   - algorithm: Fingerprint algorithm to use.
    /// - Returns: Fingerprint result.
    public func generateVideoFingerprint(
        _ data: Data,
        algorithm: FingerprintAlgorithm
    ) throws -> FingerprintResult {
        return try generateFingerprint(
            data: data,
            algorithm: algorithm,
            generator: anigma_media_fingerprint_generate_video
        )
    }
    
    private func generateFingerprint(
        data: Data,
        algorithm: FingerprintAlgorithm,
        generator: (
            anigma_media_fingerprint_capsule_t,
            UnsafePointer<anigma_capsule_buffer_t>,
            anigma_fingerprint_algorithm_t,
            UnsafeMutablePointer<anigma_fingerprint_result_t>,
            UnsafeMutablePointer<anigma_capsule_error_t>
        ) -> anigma_status_t
    ) throws -> FingerprintResult {
        guard !data.isEmpty else {
            throw capsuleError(
                status: ANIGMA_ERR_INVALID_ARG,
                error: createError(code: ANIGMA_ERR_INVALID_ARG, message: "Invalid input buffer")
            )
        }
        
        var result = anigma_fingerprint_result_t()
        var error = anigma_capsule_error_t()
        
        var buffer = anigma_capsule_buffer_t(
            ptr: UnsafeMutablePointer<UInt8>(mutating: data.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }),
            len: data.count,
            cap: data.count
        )
        
        let status = try handle?.withHandle { rawHandle in
            generator(
                rawHandle,
                &buffer,
                anigma_fingerprint_algorithm_t(UInt32(algorithm.rawValue)),
                &result,
                &error
            )
        } ?? ANIGMA_ERR_NOT_INITIALIZED
        
        guard status == ANIGMA_OK else {
            throw capsuleError(status: status, error: error)
        }
        
        defer {
            anigma_media_fingerprint_free_result(&result, nil)
        }
        
        let hashData = Data(
            bytes: result.hash_data,
            count: Int((result.hash_size + 7) / 8)
        )
        
        let swiftResult = FingerprintResult(
            algorithm: FingerprintAlgorithm(rawValue: UInt8(result.algorithm.rawValue)) ?? .averageHash,
            hashSize: result.hash_size,
            hashData: hashData,
            confidence: result.confidence,
            processingTimeMs: result.processing_time_ms
        )
        
        // Free the C-side result but keep the hash data
        if let hashPtr = result.hash_data {
            result.hash_data = nil // Prevent double-free
            hashPtr.deallocate()
        }
        
        return swiftResult
    }
    
    // MARK: - Similarity Comparison
    
    /// Compare two fingerprint results.
    /// - Parameters:
    ///   - fingerprint1: First fingerprint.
    ///   - fingerprint2: Second fingerprint.
    ///   - config: Similarity configuration.
    /// - Returns: Similarity result.
    public func compareFingerprints(
        _ fingerprint1: FingerprintResult,
        _ fingerprint2: FingerprintResult,
        config: SimilarityConfiguration = .default
    ) throws -> SimilarityResult {
        var result = anigma_similarity_result_t()
        var error = anigma_capsule_error_t()
        
        // Create C structs for comparison
        var cFingerprint1 = anigma_fingerprint_result_t(
            algorithm: anigma_fingerprint_algorithm_t(UInt32(fingerprint1.algorithm.rawValue)),
            hash_size: fingerprint1.hashSize,
            hash_data: UnsafeMutablePointer<UInt8>(mutating: fingerprint1.hashData.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }),
            confidence: fingerprint1.confidence,
            processing_time_ms: fingerprint1.processingTimeMs
        )
        
        var cFingerprint2 = anigma_fingerprint_result_t(
            algorithm: anigma_fingerprint_algorithm_t(UInt32(fingerprint2.algorithm.rawValue)),
            hash_size: fingerprint2.hashSize,
            hash_data: UnsafeMutablePointer<UInt8>(mutating: fingerprint2.hashData.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }),
            confidence: fingerprint2.confidence,
            processing_time_ms: fingerprint2.processingTimeMs
        )
        
        var cConfig = config.toCStruct()
        
        let status = try handle?.withHandle { rawHandle in
            anigma_media_fingerprint_compare(
                rawHandle,
                &cFingerprint1,
                &cFingerprint2,
                &cConfig,
                &result,
                &error
            )
        } ?? ANIGMA_ERR_NOT_INITIALIZED
        
        guard status == ANIGMA_OK else {
            throw capsuleError(status: status, error: error)
        }
        
        return SimilarityResult(
            similarityScore: result.similarity_score,
            hammingDistance: result.hamming_distance,
            isDuplicate: result.is_duplicate,
            isPartialMatch: result.is_partial_match
        )
    }
    
    /// Batch compare a query fingerprint against multiple candidates.
    /// - Parameters:
    ///   - queryFingerprint: Query fingerprint.
    ///   - candidateFingerprints: Array of candidate fingerprints.
    ///   - config: Similarity configuration.
    /// - Returns: Array of similarity results.
    public func batchCompareFingerprints(
        queryFingerprint: FingerprintResult,
        candidateFingerprints: [FingerprintResult],
        config: SimilarityConfiguration = .default
    ) throws -> [SimilarityResult] {
        guard !candidateFingerprints.isEmpty else { return [] }
        
        // Create C array of candidate fingerprints
        var cCandidates = candidateFingerprints.map { fingerprint in
            anigma_fingerprint_result_t(
                algorithm: anigma_fingerprint_algorithm_t(UInt32(fingerprint.algorithm.rawValue)),
                hash_size: fingerprint.hashSize,
                hash_data: UnsafeMutablePointer<UInt8>(mutating: fingerprint.hashData.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }),
                confidence: fingerprint.confidence,
                processing_time_ms: fingerprint.processingTimeMs
            )
        }
        
        var cQuery = anigma_fingerprint_result_t(
            algorithm: anigma_fingerprint_algorithm_t(UInt32(queryFingerprint.algorithm.rawValue)),
            hash_size: queryFingerprint.hashSize,
            hash_data: UnsafeMutablePointer<UInt8>(mutating: queryFingerprint.hashData.withUnsafeBytes { $0.baseAddress?.assumingMemoryBound(to: UInt8.self) }),
            confidence: queryFingerprint.confidence,
            processing_time_ms: queryFingerprint.processingTimeMs
        )
        
        var results = [anigma_similarity_result_t](repeating: anigma_similarity_result_t(), count: candidateFingerprints.count)
        var actualCount: size_t = 0
        var error = anigma_capsule_error_t()
        
        var cConfig = config.toCStruct()
        
        let status = try handle?.withHandle { rawHandle in
            anigma_media_fingerprint_batch_compare(
                rawHandle,
                &cQuery,
                &cCandidates,
                candidateFingerprints.count,
                &cConfig,
                &results,
                &actualCount,
                &error
            )
        } ?? ANIGMA_ERR_NOT_INITIALIZED
        
        guard status == ANIGMA_OK else {
            throw capsuleError(status: status, error: error)
        }
        
        return Array(results.prefix(Int(actualCount))).map { result in
            SimilarityResult(
                similarityScore: result.similarity_score,
                hammingDistance: result.hamming_distance,
                isDuplicate: result.is_duplicate,
                isPartialMatch: result.is_partial_match
            )
        }
    }
}

// MARK: - Configuration Validation

extension ImageFingerprintConfiguration {
    /// Validate the configuration.
    public func validate() throws {
        // Validation logic not available in native shim
    }
}

extension AudioFingerprintConfiguration {
    /// Validate the configuration.
    public func validate() throws {
        // Validation logic not available in native shim
    }
}

extension VideoFingerprintConfiguration {
    /// Validate the configuration.
    public func validate() throws {
        // Validation logic not available in native shim
    }
}

private func capsuleError(status: anigma_status_t, error: anigma_capsule_error_t) -> CapsuleError {
    let message = error.message.map { String(cString: $0) } ?? "Capsule error"
    return CapsuleError(status: status, code: error.code, message: message)
}
