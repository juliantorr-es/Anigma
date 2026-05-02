// anigma_media_fingerprint.h
// MediaFingerprintNative - C ABI for perceptual hashing and media fingerprinting
// Part of the Anigma project

#ifndef ANIGMA_MEDIA_FINGERPRINT_H
#define ANIGMA_MEDIA_FINGERPRINT_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// =============================================================================
// MARK: - Error Codes
// =============================================================================

typedef enum {
    AMFP_SUCCESS = 0,
    AMFP_ERROR_NULL_POINTER = -1,
    AMFP_ERROR_INVALID_DIMENSIONS = -2,
    AMFP_ERROR_DECODE_FAILED = -3,
    AMFP_ERROR_MEMORY_ALLOCATION = -4,
    AMFP_ERROR_INVALID_FORMAT = -5,
    AMFP_ERROR_BUFFER_TOO_SMALL = -6,
    AMFP_ERROR_NOT_IMPLEMENTED = -7,
} amfp_error_t;

// =============================================================================
// MARK: - Hash Types
// =============================================================================

/// 64-bit perceptual hash (pHash or dHash)
typedef uint64_t amfp_hash64_t;

/// 256-bit extended hash for higher precision
typedef struct {
    uint64_t parts[4];
} amfp_hash256_t;

/// Audio fingerprint (variable length, up to 256 uint32 subfingerprints)
typedef struct {
    uint32_t subfingerprints[256];
    size_t count;
    float duration_seconds;
} amfp_audio_fingerprint_t;

// =============================================================================
// MARK: - Image Fingerprinting (pHash - DCT-based)
// =============================================================================

/// Compute 64-bit pHash from raw grayscale pixels.
amfp_error_t amfp_phash_from_grayscale(
    const uint8_t* grayscale_pixels,
    uint32_t width,
    uint32_t height,
    uint32_t stride,
    amfp_hash64_t* out_hash
);

/// Compute 64-bit pHash from encoded image data (JPEG, PNG, etc.)
amfp_error_t amfp_phash_from_encoded(
    const uint8_t* encoded_data,
    size_t encoded_length,
    amfp_hash64_t* out_hash
);

// =============================================================================
// MARK: - Image Fingerprinting (dHash - Gradient-based)
// =============================================================================

/// Compute 64-bit dHash from raw grayscale pixels.
amfp_error_t amfp_dhash_from_grayscale(
    const uint8_t* grayscale_pixels,
    uint32_t width,
    uint32_t height,
    uint32_t stride,
    amfp_hash64_t* out_hash
);

/// Compute 64-bit dHash from encoded image data
amfp_error_t amfp_dhash_from_encoded(
    const uint8_t* encoded_data,
    size_t encoded_length,
    amfp_hash64_t* out_hash
);

// =============================================================================
// MARK: - Extended 256-bit Hashes
// =============================================================================

/// Compute 256-bit extended pHash for higher precision matching
amfp_error_t amfp_phash256_from_grayscale(
    const uint8_t* grayscale_pixels,
    uint32_t width,
    uint32_t height,
    uint32_t stride,
    amfp_hash256_t* out_hash
);

// =============================================================================
// MARK: - Audio Fingerprinting (Spectral-based)
// =============================================================================

/// Compute audio fingerprint from PCM samples.
amfp_error_t amfp_audio_fingerprint_from_pcm(
    const float* pcm_samples,
    size_t sample_count,
    uint32_t sample_rate,
    amfp_audio_fingerprint_t* out_fingerprint
);

/// Compute similarity between two audio fingerprints
float amfp_audio_fingerprint_similarity(
    const amfp_audio_fingerprint_t* fp1,
    const amfp_audio_fingerprint_t* fp2
);

// =============================================================================
// MARK: - Hamming Distance / Similarity
// =============================================================================

/// Compute Hamming distance between two 64-bit hashes.
uint32_t amfp_hamming_distance_64(amfp_hash64_t hash1, amfp_hash64_t hash2);

/// Compute Hamming distance between two 256-bit hashes.
uint32_t amfp_hamming_distance_256(
    const amfp_hash256_t* hash1,
    const amfp_hash256_t* hash2
);

/// Compute similarity score from Hamming distance.
float amfp_similarity_from_distance(uint32_t distance, uint32_t max_bits);

/// Check if two hashes are similar within threshold.
bool amfp_hashes_similar_64(
    amfp_hash64_t hash1,
    amfp_hash64_t hash2,
    uint32_t max_distance
);

// =============================================================================
// MARK: - Batch Operations
// =============================================================================

/// Find similar hashes in a batch (brute-force search).
size_t amfp_find_similar_64(
    amfp_hash64_t query_hash,
    const amfp_hash64_t* candidate_hashes,
    size_t candidate_count,
    uint32_t max_distance,
    size_t* out_indices,
    uint32_t* out_distances,
    size_t max_results
);

// =============================================================================
// MARK: - Utility Functions
// =============================================================================

/// Convert hash to hex string representation.
amfp_error_t amfp_hash64_to_hex(
    amfp_hash64_t hash,
    char* out_buffer,
    size_t buffer_size
);

/// Parse hash from hex string.
amfp_error_t amfp_hash64_from_hex(
    const char* hex_string,
    amfp_hash64_t* out_hash
);

/// Get library version string.
const char* amfp_version(void);

#ifdef __cplusplus
}
#endif

#endif // ANIGMA_MEDIA_FINGERPRINT_H
