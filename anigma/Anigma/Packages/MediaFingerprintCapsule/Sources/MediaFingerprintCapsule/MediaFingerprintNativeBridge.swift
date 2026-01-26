// MediaFingerprintNativeBridge.swift
// MediaFingerprintCapsule - C API wrapper for strict concurrency

@preconcurrency import MediaFingerprintNative

enum MediaFingerprintNativeBridge {
    typealias ErrorCode = amfp_error_t
    typealias Hash64 = amfp_hash64_t
    typealias Hash256 = amfp_hash256_t
    typealias AudioFingerprint = amfp_audio_fingerprint_t

    static let success = AMFP_SUCCESS
    static let errorNullPointer = AMFP_ERROR_NULL_POINTER
    static let errorInvalidDimensions = AMFP_ERROR_INVALID_DIMENSIONS
    static let errorDecodeFailed = AMFP_ERROR_DECODE_FAILED
    static let errorMemoryAllocation = AMFP_ERROR_MEMORY_ALLOCATION
    static let errorInvalidFormat = AMFP_ERROR_INVALID_FORMAT
    static let errorBufferTooSmall = AMFP_ERROR_BUFFER_TOO_SMALL
    static let errorNotImplemented = AMFP_ERROR_NOT_IMPLEMENTED

    static func version() -> UnsafePointer<CChar> {
        amfp_version()
    }

    static func hammingDistance64(_ lhs: UInt64, _ rhs: UInt64) -> UInt32 {
        amfp_hamming_distance_64(lhs, rhs)
    }

    static func similarityFromDistance(_ distance: UInt32, bits: UInt32) -> Float {
        amfp_similarity_from_distance(distance, bits)
    }

    static func hammingDistance256(_ lhs: inout Hash256, _ rhs: inout Hash256) -> UInt32 {
        amfp_hamming_distance_256(&lhs, &rhs)
    }

    static func phashFromEncoded(
        _ ptr: UnsafePointer<UInt8>,
        _ count: Int,
        _ hash: inout Hash64
    ) -> ErrorCode {
        amfp_phash_from_encoded(ptr, count, &hash)
    }

    static func dhashFromEncoded(
        _ ptr: UnsafePointer<UInt8>,
        _ count: Int,
        _ hash: inout Hash64
    ) -> ErrorCode {
        amfp_dhash_from_encoded(ptr, count, &hash)
    }

    static func phashFromGrayscale(
        _ ptr: UnsafePointer<UInt8>,
        width: UInt32,
        height: UInt32,
        stride: UInt32,
        hash: inout Hash64
    ) -> ErrorCode {
        amfp_phash_from_grayscale(ptr, width, height, stride, &hash)
    }

    static func dhashFromGrayscale(
        _ ptr: UnsafePointer<UInt8>,
        width: UInt32,
        height: UInt32,
        stride: UInt32,
        hash: inout Hash64
    ) -> ErrorCode {
        amfp_dhash_from_grayscale(ptr, width, height, stride, &hash)
    }

    static func phash256FromGrayscale(
        _ ptr: UnsafePointer<UInt8>,
        width: UInt32,
        height: UInt32,
        stride: UInt32,
        hash: inout Hash256
    ) -> ErrorCode {
        amfp_phash256_from_grayscale(ptr, width, height, stride, &hash)
    }

    static func audioFingerprintFromPCM(
        _ ptr: UnsafePointer<Float>,
        _ count: Int,
        _ sampleRate: UInt32,
        _ fingerprint: inout AudioFingerprint
    ) -> ErrorCode {
        amfp_audio_fingerprint_from_pcm(ptr, count, sampleRate, &fingerprint)
    }

    static func audioFingerprintSimilarity(
        _ lhs: inout AudioFingerprint,
        _ rhs: inout AudioFingerprint
    ) -> Float {
        amfp_audio_fingerprint_similarity(&lhs, &rhs)
    }

    static func findSimilar64(
        query: UInt64,
        candidates: UnsafePointer<UInt64>?,
        candidateCount: Int,
        maxDistance: UInt32,
        indices: UnsafeMutablePointer<Int>?,
        distances: UnsafeMutablePointer<UInt32>?,
        maxResults: Int
    ) -> Int {
        Int(
            amfp_find_similar_64(
                query,
                candidates,
                candidateCount,
                maxDistance,
                indices,
                distances,
                maxResults
            )
        )
    }
}
