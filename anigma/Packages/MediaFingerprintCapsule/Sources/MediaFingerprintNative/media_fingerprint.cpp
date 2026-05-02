// media_fingerprint.cpp
// MediaFingerprintNative - Implementation of perceptual hashing algorithms
// Part of the Anigma project

#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_RESIZE_IMPLEMENTATION
#define STBI_NO_HDR
#define STBI_NO_LINEAR

#include "stb_image.h"
#include "stb_image_resize2.h"
#include "anigma_media_fingerprint.h"

#include <cmath>
#include <cstring>
#include <algorithm>
#include <vector>
#include <cstdio>

// =============================================================================
// MARK: - Constants
// =============================================================================

static const char* VERSION_STRING = "1.0.0";

// Hash sizes
static constexpr int PHASH_SIZE = 32;  // 32x32 for DCT
static constexpr int DHASH_SIZE = 9;   // 9x8 for dHash (produces 8x8 = 64 bits)
static constexpr int PHASH256_SIZE = 64; // 16x16 = 256 bits

// DCT coefficient selection for pHash
static constexpr int DCT_LOW_FREQ = 8;  // Use top-left 8x8 of DCT

// =============================================================================
// MARK: - Internal Helpers
// =============================================================================

namespace {

/// Resize grayscale image to target size using bilinear interpolation
bool resize_grayscale(const uint8_t* src, uint32_t src_w, uint32_t src_h, uint32_t src_stride,
                      uint8_t* dst, uint32_t dst_w, uint32_t dst_h) {
    // Use stb_image_resize
    return stbir_resize_uint8_linear(
        src, static_cast<int>(src_w), static_cast<int>(src_h), static_cast<int>(src_stride),
        dst, static_cast<int>(dst_w), static_cast<int>(dst_h), static_cast<int>(dst_w),
        STBIR_1CHANNEL
    ) != nullptr;
}

/// Compute 2D DCT-II of an NxN block
void compute_dct_2d(const float* input, float* output, int n) {
    std::vector<float> temp(n * n);
    
    // Row-wise DCT
    for (int i = 0; i < n; i++) {
        for (int k = 0; k < n; k++) {
            float sum = 0.0f;
            for (int j = 0; j < n; j++) {
                sum += input[i * n + j] * std::cos(M_PI * k * (2 * j + 1) / (2 * n));
            }
            float alpha = (k == 0) ? std::sqrt(1.0f / n) : std::sqrt(2.0f / n);
            temp[i * n + k] = alpha * sum;
        }
    }
    
    // Column-wise DCT
    for (int k = 0; k < n; k++) {
        for (int i = 0; i < n; i++) {
            float sum = 0.0f;
            for (int j = 0; j < n; j++) {
                sum += temp[j * n + k] * std::cos(M_PI * i * (2 * j + 1) / (2 * n));
            }
            float alpha = (i == 0) ? std::sqrt(1.0f / n) : std::sqrt(2.0f / n);
            output[i * n + k] = alpha * sum;
        }
    }
}

/// Convert RGB to grayscale
void rgb_to_grayscale(const uint8_t* rgb, uint8_t* gray, int width, int height, int channels) {
    for (int i = 0; i < width * height; i++) {
        if (channels >= 3) {
            // Standard luminance formula
            gray[i] = static_cast<uint8_t>(
                0.299f * rgb[i * channels + 0] +
                0.587f * rgb[i * channels + 1] +
                0.114f * rgb[i * channels + 2]
            );
        } else {
            gray[i] = rgb[i * channels];
        }
    }
}

/// Compute median of float array
float median(float* arr, size_t count) {
    std::sort(arr, arr + count);
    if (count % 2 == 0) {
        return (arr[count / 2 - 1] + arr[count / 2]) / 2.0f;
    }
    return arr[count / 2];
}

/// Compute mean of float array
float mean(const float* arr, size_t count) {
    float sum = 0.0f;
    for (size_t i = 0; i < count; i++) {
        sum += arr[i];
    }
    return sum / count;
}

/// Count set bits (popcount)
inline uint32_t popcount64(uint64_t x) {
#if defined(__GNUC__) || defined(__clang__)
    return __builtin_popcountll(x);
#else
    uint32_t count = 0;
    while (x) {
        count += x & 1;
        x >>= 1;
    }
    return count;
#endif
}

} // anonymous namespace

// =============================================================================
// MARK: - pHash Implementation (DCT-based)
// =============================================================================

extern "C" amfp_error_t amfp_phash_from_grayscale(
    const uint8_t* grayscale_pixels,
    uint32_t width,
    uint32_t height,
    uint32_t stride,
    amfp_hash64_t* out_hash
) {
    if (!grayscale_pixels || !out_hash) {
        return AMFP_ERROR_NULL_POINTER;
    }
    if (width == 0 || height == 0) {
        return AMFP_ERROR_INVALID_DIMENSIONS;
    }

    // Step 1: Resize to 32x32
    std::vector<uint8_t> resized(PHASH_SIZE * PHASH_SIZE);
    if (!resize_grayscale(grayscale_pixels, width, height, stride,
                          resized.data(), PHASH_SIZE, PHASH_SIZE)) {
        return AMFP_ERROR_MEMORY_ALLOCATION;
    }

    // Step 2: Convert to float
    std::vector<float> pixels_f(PHASH_SIZE * PHASH_SIZE);
    for (int i = 0; i < PHASH_SIZE * PHASH_SIZE; i++) {
        pixels_f[i] = static_cast<float>(resized[i]);
    }

    // Step 3: Compute 2D DCT
    std::vector<float> dct(PHASH_SIZE * PHASH_SIZE);
    compute_dct_2d(pixels_f.data(), dct.data(), PHASH_SIZE);

    // Step 4: Extract low-frequency 8x8 coefficients (excluding DC)
    std::vector<float> low_freq;
    low_freq.reserve(DCT_LOW_FREQ * DCT_LOW_FREQ - 1);
    for (int i = 0; i < DCT_LOW_FREQ; i++) {
        for (int j = 0; j < DCT_LOW_FREQ; j++) {
            if (i == 0 && j == 0) continue; // Skip DC component
            low_freq.push_back(dct[i * PHASH_SIZE + j]);
        }
    }

    // Step 5: Compute median
    std::vector<float> sorted_freq = low_freq;
    float med = median(sorted_freq.data(), sorted_freq.size());

    // Step 6: Generate hash (first 64 coefficients compared to median)
    uint64_t hash = 0;
    for (int i = 0; i < 64 && i < static_cast<int>(low_freq.size()); i++) {
        if (low_freq[i] > med) {
            hash |= (1ULL << (63 - i));
        }
    }

    *out_hash = hash;
    return AMFP_SUCCESS;
}

extern "C" amfp_error_t amfp_phash_from_encoded(
    const uint8_t* encoded_data,
    size_t encoded_length,
    amfp_hash64_t* out_hash
) {
    if (!encoded_data || !out_hash) {
        return AMFP_ERROR_NULL_POINTER;
    }
    if (encoded_length == 0) {
        return AMFP_ERROR_INVALID_FORMAT;
    }

    // Decode image using stb_image
    int width, height, channels;
    uint8_t* decoded = stbi_load_from_memory(
        encoded_data,
        static_cast<int>(encoded_length),
        &width, &height, &channels,
        0  // Keep original channels
    );

    if (!decoded) {
        return AMFP_ERROR_DECODE_FAILED;
    }

    // Convert to grayscale if needed
    std::vector<uint8_t> grayscale(width * height);
    rgb_to_grayscale(decoded, grayscale.data(), width, height, channels);
    stbi_image_free(decoded);

    // Compute hash
    return amfp_phash_from_grayscale(
        grayscale.data(),
        static_cast<uint32_t>(width),
        static_cast<uint32_t>(height),
        static_cast<uint32_t>(width),
        out_hash
    );
}

// =============================================================================
// MARK: - dHash Implementation (Gradient-based)
// =============================================================================

extern "C" amfp_error_t amfp_dhash_from_grayscale(
    const uint8_t* grayscale_pixels,
    uint32_t width,
    uint32_t height,
    uint32_t stride,
    amfp_hash64_t* out_hash
) {
    if (!grayscale_pixels || !out_hash) {
        return AMFP_ERROR_NULL_POINTER;
    }
    if (width == 0 || height == 0) {
        return AMFP_ERROR_INVALID_DIMENSIONS;
    }

    // Step 1: Resize to 9x8 (9 columns for horizontal gradient, 8 rows)
    std::vector<uint8_t> resized(DHASH_SIZE * 8);
    if (!resize_grayscale(grayscale_pixels, width, height, stride,
                          resized.data(), DHASH_SIZE, 8)) {
        return AMFP_ERROR_MEMORY_ALLOCATION;
    }

    // Step 2: Compute horizontal gradient hash
    // Compare each pixel with its right neighbor
    uint64_t hash = 0;
    int bit = 63;
    for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
            uint8_t left = resized[y * DHASH_SIZE + x];
            uint8_t right = resized[y * DHASH_SIZE + x + 1];
            if (left > right) {
                hash |= (1ULL << bit);
            }
            bit--;
        }
    }

    *out_hash = hash;
    return AMFP_SUCCESS;
}

extern "C" amfp_error_t amfp_dhash_from_encoded(
    const uint8_t* encoded_data,
    size_t encoded_length,
    amfp_hash64_t* out_hash
) {
    if (!encoded_data || !out_hash) {
        return AMFP_ERROR_NULL_POINTER;
    }
    if (encoded_length == 0) {
        return AMFP_ERROR_INVALID_FORMAT;
    }

    // Decode image using stb_image
    int width, height, channels;
    uint8_t* decoded = stbi_load_from_memory(
        encoded_data,
        static_cast<int>(encoded_length),
        &width, &height, &channels,
        0
    );

    if (!decoded) {
        return AMFP_ERROR_DECODE_FAILED;
    }

    // Convert to grayscale if needed
    std::vector<uint8_t> grayscale(width * height);
    rgb_to_grayscale(decoded, grayscale.data(), width, height, channels);
    stbi_image_free(decoded);

    return amfp_dhash_from_grayscale(
        grayscale.data(),
        static_cast<uint32_t>(width),
        static_cast<uint32_t>(height),
        static_cast<uint32_t>(width),
        out_hash
    );
}

// =============================================================================
// MARK: - Extended 256-bit pHash
// =============================================================================

extern "C" amfp_error_t amfp_phash256_from_grayscale(
    const uint8_t* grayscale_pixels,
    uint32_t width,
    uint32_t height,
    uint32_t stride,
    amfp_hash256_t* out_hash
) {
    if (!grayscale_pixels || !out_hash) {
        return AMFP_ERROR_NULL_POINTER;
    }
    if (width == 0 || height == 0) {
        return AMFP_ERROR_INVALID_DIMENSIONS;
    }

    // Resize to larger size for more coefficients
    std::vector<uint8_t> resized(PHASH256_SIZE * PHASH256_SIZE);
    if (!resize_grayscale(grayscale_pixels, width, height, stride,
                          resized.data(), PHASH256_SIZE, PHASH256_SIZE)) {
        return AMFP_ERROR_MEMORY_ALLOCATION;
    }

    // Convert to float
    std::vector<float> pixels_f(PHASH256_SIZE * PHASH256_SIZE);
    for (int i = 0; i < PHASH256_SIZE * PHASH256_SIZE; i++) {
        pixels_f[i] = static_cast<float>(resized[i]);
    }

    // Compute 2D DCT
    std::vector<float> dct(PHASH256_SIZE * PHASH256_SIZE);
    compute_dct_2d(pixels_f.data(), dct.data(), PHASH256_SIZE);

    // Extract 16x16 low-frequency coefficients (excluding DC)
    std::vector<float> low_freq;
    low_freq.reserve(256);
    for (int i = 0; i < 16; i++) {
        for (int j = 0; j < 16; j++) {
            if (i == 0 && j == 0) continue;
            low_freq.push_back(dct[i * PHASH256_SIZE + j]);
        }
    }

    // Pad to 256 if needed
    while (low_freq.size() < 256) {
        low_freq.push_back(0.0f);
    }

    // Compute median
    std::vector<float> sorted_freq = low_freq;
    float med = median(sorted_freq.data(), sorted_freq.size());

    // Generate 256-bit hash
    for (int part = 0; part < 4; part++) {
        uint64_t hash = 0;
        for (int i = 0; i < 64; i++) {
            int idx = part * 64 + i;
            if (low_freq[idx] > med) {
                hash |= (1ULL << (63 - i));
            }
        }
        out_hash->parts[part] = hash;
    }

    return AMFP_SUCCESS;
}

// =============================================================================
// MARK: - Audio Fingerprinting (Simplified Spectral)
// =============================================================================

extern "C" amfp_error_t amfp_audio_fingerprint_from_pcm(
    const float* pcm_samples,
    size_t sample_count,
    uint32_t sample_rate,
    amfp_audio_fingerprint_t* out_fingerprint
) {
    if (!pcm_samples || !out_fingerprint) {
        return AMFP_ERROR_NULL_POINTER;
    }
    if (sample_count == 0 || sample_rate == 0) {
        return AMFP_ERROR_INVALID_DIMENSIONS;
    }

    // Simplified spectral fingerprint using energy bands
    // This is a basic implementation - production would use proper FFT
    
    const size_t window_size = sample_rate / 10;  // 100ms windows
    const size_t hop_size = window_size / 2;      // 50% overlap
    const size_t num_bands = 32;                  // Frequency bands
    
    std::memset(out_fingerprint, 0, sizeof(amfp_audio_fingerprint_t));
    out_fingerprint->duration_seconds = static_cast<float>(sample_count) / sample_rate;
    
    size_t subprint_idx = 0;
    for (size_t offset = 0; offset + window_size <= sample_count && subprint_idx < 256; 
         offset += hop_size, subprint_idx++) {
        
        // Compute energy in different "bands" (simplified - just amplitude regions)
        std::vector<float> band_energy(num_bands, 0.0f);
        size_t samples_per_band = window_size / num_bands;
        
        for (size_t b = 0; b < num_bands; b++) {
            float energy = 0.0f;
            for (size_t i = 0; i < samples_per_band; i++) {
                size_t idx = offset + b * samples_per_band + i;
                energy += pcm_samples[idx] * pcm_samples[idx];
            }
            band_energy[b] = std::sqrt(energy / samples_per_band);
        }
        
        // Generate 32-bit subfingerprint from band comparisons
        uint32_t subprint = 0;
        for (size_t b = 0; b < num_bands - 1; b++) {
            if (band_energy[b] > band_energy[b + 1]) {
                subprint |= (1U << b);
            }
        }
        
        out_fingerprint->subfingerprints[subprint_idx] = subprint;
    }
    
    out_fingerprint->count = subprint_idx;
    return AMFP_SUCCESS;
}

extern "C" float amfp_audio_fingerprint_similarity(
    const amfp_audio_fingerprint_t* fp1,
    const amfp_audio_fingerprint_t* fp2
) {
    if (!fp1 || !fp2 || fp1->count == 0 || fp2->count == 0) {
        return 0.0f;
    }

    size_t min_count = std::min(fp1->count, fp2->count);
    uint32_t total_distance = 0;
    
    for (size_t i = 0; i < min_count; i++) {
        uint32_t xor_val = fp1->subfingerprints[i] ^ fp2->subfingerprints[i];
        total_distance += popcount64(xor_val);
    }
    
    // Normalize: max distance per subprint is 32 bits
    float max_distance = static_cast<float>(min_count * 32);
    return 1.0f - (static_cast<float>(total_distance) / max_distance);
}

// =============================================================================
// MARK: - Hamming Distance / Similarity
// =============================================================================

extern "C" uint32_t amfp_hamming_distance_64(amfp_hash64_t hash1, amfp_hash64_t hash2) {
    return popcount64(hash1 ^ hash2);
}

extern "C" uint32_t amfp_hamming_distance_256(
    const amfp_hash256_t* hash1,
    const amfp_hash256_t* hash2
) {
    if (!hash1 || !hash2) {
        return UINT32_MAX;
    }
    
    uint32_t distance = 0;
    for (int i = 0; i < 4; i++) {
        distance += popcount64(hash1->parts[i] ^ hash2->parts[i]);
    }
    return distance;
}

extern "C" float amfp_similarity_from_distance(uint32_t distance, uint32_t max_bits) {
    if (max_bits == 0) return 0.0f;
    return 1.0f - (static_cast<float>(distance) / static_cast<float>(max_bits));
}

extern "C" bool amfp_hashes_similar_64(
    amfp_hash64_t hash1,
    amfp_hash64_t hash2,
    uint32_t max_distance
) {
    return amfp_hamming_distance_64(hash1, hash2) <= max_distance;
}

// =============================================================================
// MARK: - Batch Operations
// =============================================================================

extern "C" size_t amfp_find_similar_64(
    amfp_hash64_t query_hash,
    const amfp_hash64_t* candidate_hashes,
    size_t candidate_count,
    uint32_t max_distance,
    size_t* out_indices,
    uint32_t* out_distances,
    size_t max_results
) {
    if (!candidate_hashes || !out_indices || candidate_count == 0 || max_results == 0) {
        return 0;
    }

    size_t result_count = 0;
    
    for (size_t i = 0; i < candidate_count && result_count < max_results; i++) {
        uint32_t distance = amfp_hamming_distance_64(query_hash, candidate_hashes[i]);
        if (distance <= max_distance) {
            out_indices[result_count] = i;
            if (out_distances) {
                out_distances[result_count] = distance;
            }
            result_count++;
        }
    }
    
    return result_count;
}

// =============================================================================
// MARK: - Utility Functions
// =============================================================================

extern "C" amfp_error_t amfp_hash64_to_hex(
    amfp_hash64_t hash,
    char* out_buffer,
    size_t buffer_size
) {
    if (!out_buffer) {
        return AMFP_ERROR_NULL_POINTER;
    }
    if (buffer_size < 17) {  // 16 hex chars + null terminator
        return AMFP_ERROR_BUFFER_TOO_SMALL;
    }
    
    std::snprintf(out_buffer, buffer_size, "%016llx", 
                  static_cast<unsigned long long>(hash));
    return AMFP_SUCCESS;
}

extern "C" amfp_error_t amfp_hash64_from_hex(
    const char* hex_string,
    amfp_hash64_t* out_hash
) {
    if (!hex_string || !out_hash) {
        return AMFP_ERROR_NULL_POINTER;
    }
    
    if (std::strlen(hex_string) != 16) {
        return AMFP_ERROR_INVALID_FORMAT;
    }
    
    unsigned long long value;
    if (std::sscanf(hex_string, "%llx", &value) != 1) {
        return AMFP_ERROR_INVALID_FORMAT;
    }
    
    *out_hash = static_cast<amfp_hash64_t>(value);
    return AMFP_SUCCESS;
}

extern "C" const char* amfp_version(void) {
    return VERSION_STRING;
}
