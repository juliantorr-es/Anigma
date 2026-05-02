#include "anigma_cosine_similarity_capsule.h"
#include "anigma_capsule_core.h"

#include <cmath>
#include <cstring>
#include <cstdint>

#if defined(__x86_64__) || defined(_M_X64)
#include <immintrin.h>
#endif

// ============================================================================
// Internal Implementation Details
// ============================================================================

namespace {

// SIMD detection
enum anigma_cosine_simd_t detectBestSIMD() {
#if defined(__x86_64__) || defined(_M_X64)
    // Check CPUID for SIMD features
    uint32_t eax, ebx, ecx, edx;
    
    // Get standard feature flags
    #if defined(_MSC_VER)
        int cpuInfo[4] = {};
        __cpuid(cpuInfo, 1);
        eax = cpuInfo[0];
        ebx = cpuInfo[1];
        ecx = cpuInfo[2];
        edx = cpuInfo[3];
    #else
        asm volatile("cpuid"
            : "=a"(eax), "=b"(ebx), "=c"(ecx), "=d"(edx)
            : "a"(1));
    #endif
    
    // Check for AVX512
    #if defined(_MSC_VER)
        __cpuidex(cpuInfo, 7, 0);
        ebx = cpuInfo[1];
    #else
        asm volatile("cpuid"
            : "=a"(eax), "=b"(ebx), "=c"(ecx), "=d"(edx)
            : "a"(7), "c"(0));
    #endif
    
    if (ebx & (1 << 16)) {  // AVX512F
        return ANIGMA_COSINE_SIMD_AVX512;
    }
    
    // Check for AVX2
    if (ebx & (1 << 5)) {  // AVX2
        return ANIGMA_COSINE_SIMD_AVX2;
    }
    
    // Check for SSE4.2
    if (ecx & (1 << 20)) {  // SSE4.2
        return ANIGMA_COSINE_SIMD_SSE;
    }
    
    return ANIGMA_COSINE_SIMD_NONE;
    
#elif defined(__aarch64__) || defined(_M_ARM64)
    // ARM - assume NEON is available on ARM64
    return ANIGMA_COSINE_SIMD_NEON;
    
#else
    return ANIGMA_COSINE_SIMD_NONE;
#endif
}

// Scalar implementation (fallback)
float computeCosineSimilarityScalar(
    const float* query,
    const float* candidate,
    size_t dimension
) {
    double dot = 0.0;
    double norm_query = 0.0;
    double norm_candidate = 0.0;
    
    for (size_t i = 0; i < dimension; ++i) {
        float q = query[i];
        float c = candidate[i];
        dot += static_cast<double>(q) * static_cast<double>(c);
        norm_query += static_cast<double>(q) * static_cast<double>(q);
        norm_candidate += static_cast<double>(c) * static_cast<double>(c);
    }
    
    double magnitude = sqrt(norm_query) * sqrt(norm_candidate);
    if (magnitude == 0.0) {
        return 0.0f;
    }
    
    return static_cast<float>(dot / magnitude);
}

#if defined(__SSE4_2__) || (defined(_MSC_VER) && defined(__AVX__))
float computeCosineSimilaritySSE(
    const float* query,
    const float* candidate,
    size_t dimension
) {
    __m128 dot_vec = _mm_setzero_ps();
    __m128 norm_query_vec = _mm_setzero_ps();
    __m128 norm_candidate_vec = _mm_setzero_ps();
    
    size_t i = 0;
    for (; i + 3 < dimension; i += 4) {
        __m128 q = _mm_loadu_ps(&query[i]);
        __m128 c = _mm_loadu_ps(&candidate[i]);
        
        dot_vec = _mm_add_ps(dot_vec, _mm_mul_ps(q, c));
        norm_query_vec = _mm_add_ps(norm_query_vec, _mm_mul_ps(q, q));
        norm_candidate_vec = _mm_add_ps(norm_candidate_vec, _mm_mul_ps(c, c));
    }
    
    // Horizontal sum
    __m128 shuf = _mm_movehdup_ps(dot_vec);
    __m128 sums = _mm_add_ps(dot_vec, shuf);
    shuf = _mm_movehl_ps(shuf, sums);
    sums = _mm_add_ss(sums, shuf);
    float dot = _mm_cvtss_f32(sums);
    
    shuf = _mm_movehdup_ps(norm_query_vec);
    sums = _mm_add_ps(norm_query_vec, shuf);
    shuf = _mm_movehl_ps(shuf, sums);
    sums = _mm_add_ss(sums, shuf);
    float norm_query = _mm_cvtss_f32(sums);
    
    shuf = _mm_movehdup_ps(norm_candidate_vec);
    sums = _mm_add_ps(norm_candidate_vec, shuf);
    shuf = _mm_movehl_ps(shuf, sums);
    sums = _mm_add_ss(sums, shuf);
    float norm_candidate = _mm_cvtss_f32(sums);
    
    // Handle remaining elements
    for (; i < dimension; ++i) {
        float q = query[i];
        float c = candidate[i];
        dot += q * c;
        norm_query += q * q;
        norm_candidate += c * c;
    }
    
    float magnitude = sqrtf(norm_query) * sqrtf(norm_candidate);
    if (magnitude == 0.0f) {
        return 0.0f;
    }
    
    return dot / magnitude;
}
#endif

#if defined(__AVX2__) || (defined(_MSC_VER) && defined(__AVX2__))
float computeCosineSimilarityAVX2(
    const float* query,
    const float* candidate,
    size_t dimension
) {
    __m256 dot_vec = _mm256_setzero_ps();
    __m256 norm_query_vec = _mm256_setzero_ps();
    __m256 norm_candidate_vec = _mm256_setzero_ps();
    
    size_t i = 0;
    for (; i + 7 < dimension; i += 8) {
        __m256 q = _mm256_loadu_ps(&query[i]);
        __m256 c = _mm256_loadu_ps(&candidate[i]);
        
        dot_vec = _mm256_add_ps(dot_vec, _mm256_mul_ps(q, c));
        norm_query_vec = _mm256_add_ps(norm_query_vec, _mm256_mul_ps(q, q));
        norm_candidate_vec = _mm256_add_ps(norm_candidate_vec, _mm256_mul_ps(c, c));
    }
    
    // Reduce 256-bit vector to 128-bit
    __m128 low_dot = _mm256_castps256_ps128(dot_vec);
    __m128 high_dot = _mm256_extractf128_ps(dot_vec, 1);
    low_dot = _mm_add_ps(low_dot, high_dot);
    
    __m128 low_norm_q = _mm256_castps256_ps128(norm_query_vec);
    __m128 high_norm_q = _mm256_extractf128_ps(norm_query_vec, 1);
    low_norm_q = _mm_add_ps(low_norm_q, high_norm_q);
    
    __m128 low_norm_c = _mm256_castps256_ps128(norm_candidate_vec);
    __m128 high_norm_c = _mm256_extractf128_ps(norm_candidate_vec, 1);
    low_norm_c = _mm_add_ps(low_norm_c, high_norm_c);
    
    // Horizontal sum for 128-bit vectors
    __m128 shuf = _mm_movehdup_ps(low_dot);
    __m128 sums = _mm_add_ps(low_dot, shuf);
    shuf = _mm_movehl_ps(shuf, sums);
    sums = _mm_add_ss(sums, shuf);
    float dot = _mm_cvtss_f32(sums);
    
    shuf = _mm_movehdup_ps(low_norm_q);
    sums = _mm_add_ps(low_norm_q, shuf);
    shuf = _mm_movehl_ps(shuf, sums);
    sums = _mm_add_ss(sums, shuf);
    float norm_query = _mm_cvtss_f32(sums);
    
    shuf = _mm_movehdup_ps(low_norm_c);
    sums = _mm_add_ps(low_norm_c, shuf);
    shuf = _mm_movehl_ps(shuf, sums);
    sums = _mm_add_ss(sums, shuf);
    float norm_candidate = _mm_cvtss_f32(sums);
    
    // Handle remaining elements
    for (; i < dimension; ++i) {
        float q = query[i];
        float c = candidate[i];
        dot += q * c;
        norm_query += q * q;
        norm_candidate += c * c;
    }
    
    float magnitude = sqrtf(norm_query) * sqrtf(norm_candidate);
    if (magnitude == 0.0f) {
        return 0.0f;
    }
    
    return dot / magnitude;
}
#endif

// Validate layout parameters
bool validateLayout(const struct anigma_cosine_vector_layout_t* layout, anigma_capsule_error_t* err) {
    if (layout->dimension == 0) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Vector dimension must be > 0";
        }
        return false;
    }
    
    if (layout->stride == 0) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Vector stride must be > 0";
        }
        return false;
    }
    
    if (layout->precision != ANIGMA_COSINE_PRECISION_SINGLE) {
        if (err) {
            err->code = ANIGMA_ERR_NOT_IMPLEMENTED;
            err->message = "Only single precision floats are currently supported";
        }
        return false;
    }
    
    return true;
}

} // anonymous namespace

// ============================================================================
// Public API Implementation
// ============================================================================

anigma_capsule_identity_t anigma_cosine_similarity_capsule_get_identity(void) {
    static const char* capsule_id = "cosine_similarity_capsule";
    static const char* build_hash = "1.0.0-dev";
    static const char* algo_version = "1.0";
    
    return anigma_capsule_identity_t{
        capsule_id,
        build_hash,
        algo_version,
        ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
    };
}

anigma_status_t anigma_cosine_similarity_capsule_create(
    anigma_cosine_similarity_capsule_t* out_handle,
    anigma_capsule_error_t* err
) {
    // For now, return a placeholder handle (future extensibility)
    if (out_handle) {
        *out_handle = nullptr;
    }
    return ANIGMA_OK;
}

anigma_status_t anigma_cosine_similarity_capsule_destroy(
    anigma_cosine_similarity_capsule_t handle,
    anigma_capsule_error_t* err
) {
    // No resources to free for now
    (void)handle;
    (void)err;
    return ANIGMA_OK;
}

enum anigma_cosine_simd_t anigma_cosine_similarity_query_best_simd(void) {
    static enum anigma_cosine_simd_t best_simd = detectBestSIMD();
    return best_simd;
}

anigma_status_t anigma_cosine_similarity_validate_layout(
    const struct anigma_cosine_vector_layout_t* layout,
    enum anigma_cosine_simd_t simd,
    anigma_capsule_error_t* err
) {
    (void)simd;  // Not used for basic validation
    
    if (!validateLayout(layout, err)) {
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    return ANIGMA_OK;
}

anigma_status_t anigma_cosine_similarity_compute_single(
    anigma_cosine_similarity_capsule_t handle,
    const void* query,
    const void* candidate,
    const struct anigma_cosine_vector_layout_t* layout,
    float* out_similarity,
    enum anigma_cosine_simd_t simd,
    anigma_capsule_error_t* err
) {
    (void)handle;  // Not used yet
    
    // Validate inputs
    if (!query || !candidate || !layout || !out_similarity) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Null pointer argument";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!validateLayout(layout, err)) {
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    // For now, only support single precision floats
    if (layout->precision != ANIGMA_COSINE_PRECISION_SINGLE) {
        if (err) {
            err->code = ANIGMA_ERR_NOT_IMPLEMENTED;
            err->message = "Only single precision floats are currently supported";
        }
        return ANIGMA_ERR_NOT_IMPLEMENTED;
    }
    
    const float* query_f32 = static_cast<const float*>(query);
    const float* candidate_f32 = static_cast<const float*>(candidate);
    
    // Choose implementation based on SIMD hint
    float similarity;
    
    if (simd == ANIGMA_COSINE_SIMD_AUTO) {
        simd = anigma_cosine_similarity_query_best_simd();
    }
    
    switch (simd) {
#if defined(__AVX512F__) || (defined(_MSC_VER) && defined(__AVX512F__))
        case ANIGMA_COSINE_SIMD_AVX512:
            // TODO: Implement AVX512
            similarity = computeCosineSimilarityScalar(query_f32, candidate_f32, layout->dimension);
            break;
#endif
            
#if defined(__AVX2__) || (defined(_MSC_VER) && defined(__AVX2__))
        case ANIGMA_COSINE_SIMD_AVX2:
            similarity = computeCosineSimilarityAVX2(query_f32, candidate_f32, layout->dimension);
            break;
#endif
            
#if defined(__SSE4_2__) || (defined(_MSC_VER) && defined(__AVX__))
        case ANIGMA_COSINE_SIMD_SSE:
            similarity = computeCosineSimilaritySSE(query_f32, candidate_f32, layout->dimension);
            break;
#endif
            
        case ANIGMA_COSINE_SIMD_NONE:
        default:
            similarity = computeCosineSimilarityScalar(query_f32, candidate_f32, layout->dimension);
            break;
    }
    
    *out_similarity = similarity;
    return ANIGMA_OK;
}

anigma_status_t anigma_cosine_similarity_compute_batch(
    anigma_cosine_similarity_capsule_t handle,
    const void* query,
    const struct anigma_cosine_batch_descriptor_t* candidates,
    float* out_similarities,
    enum anigma_cosine_simd_t simd,
    anigma_capsule_error_t* err
) {
    (void)handle;  // Not used yet
    
    // Validate inputs
    if (!query || !candidates || !out_similarities) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Null pointer argument";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!validateLayout(&candidates->layout, err)) {
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (candidates->count == 0) {
        return ANIGMA_OK;  // Nothing to do
    }
    
    if (!candidates->vectors) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Candidate vectors pointer is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    // For now, only support single precision floats
    if (candidates->layout.precision != ANIGMA_COSINE_PRECISION_SINGLE) {
        if (err) {
            err->code = ANIGMA_ERR_NOT_IMPLEMENTED;
            err->message = "Only single precision floats are currently supported";
        }
        return ANIGMA_ERR_NOT_IMPLEMENTED;
    }
    
    const float* query_f32 = static_cast<const float*>(query);
    const float* candidates_f32 = static_cast<const float*>(candidates->vectors);
    
    // Simple batch implementation - can be optimized further
    for (size_t i = 0; i < candidates->count; ++i) {
        const float* candidate = candidates_f32 + (i * candidates->layout.stride);
        anigma_status_t status = anigma_cosine_similarity_compute_single(
            handle,
            query_f32,
            candidate,
            &candidates->layout,
            &out_similarities[i],
            simd,
            err
        );
        
        if (status != ANIGMA_OK) {
            return status;
        }
    }
    
    return ANIGMA_OK;
}

// Stub implementations for other functions

anigma_status_t anigma_cosine_similarity_compute_batch_threshold(
    anigma_cosine_similarity_capsule_t handle,
    const void* query,
    const struct anigma_cosine_batch_descriptor_t* candidates,
    float min_similarity,
    float* out_similarities,
    size_t* out_passed_count,
    enum anigma_cosine_simd_t simd,
    anigma_capsule_error_t* err
) {
    // For now, use the basic batch implementation
    anigma_status_t status = anigma_cosine_similarity_compute_batch(
        handle,
        query,
        candidates,
        out_similarities,
        simd,
        err
    );
    
    if (status != ANIGMA_OK) {
        return status;
    }
    
    // Count candidates passing threshold
    size_t passed = 0;
    for (size_t i = 0; i < candidates->count; ++i) {
        if (out_similarities[i] >= min_similarity) {
            passed++;
        } else {
            out_similarities[i] = -2.0f;  // Mark as below threshold
        }
    }
    
    if (out_passed_count) {
        *out_passed_count = passed;
    }
    
    return ANIGMA_OK;
}

anigma_status_t anigma_cosine_similarity_precompute_query_norm(
    anigma_cosine_similarity_capsule_t handle,
    const void* query,
    const struct anigma_cosine_vector_layout_t* layout,
    float* out_query_norm,
    enum anigma_cosine_simd_t simd,
    anigma_capsule_error_t* err
) {
    (void)handle;
    (void)simd;
    
    if (!query || !layout || !out_query_norm) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Null pointer argument";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!validateLayout(layout, err)) {
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    const float* query_f32 = static_cast<const float*>(query);
    double norm = 0.0;
    
    for (size_t i = 0; i < layout->dimension; ++i) {
        float q = query_f32[i];
        norm += static_cast<double>(q) * static_cast<double>(q);
    }
    
    *out_query_norm = static_cast<float>(sqrt(norm));
    return ANIGMA_OK;
}

anigma_status_t anigma_cosine_similarity_compute_batch_with_norm(
    anigma_cosine_similarity_capsule_t handle,
    const void* query,
    float query_norm,
    const struct anigma_cosine_batch_descriptor_t* candidates,
    float* out_similarities,
    enum anigma_cosine_simd_t simd,
    anigma_capsule_error_t* err
) {
    // For now, fall back to standard batch computation
    // This can be optimized by reusing query norm
    return anigma_cosine_similarity_compute_batch(
        handle,
        query,
        candidates,
        out_similarities,
        simd,
        err
    );
}

anigma_status_t anigma_cosine_similarity_compute_matrix(
    anigma_cosine_similarity_capsule_t handle,
    const struct anigma_cosine_batch_descriptor_t* queries,
    const struct anigma_cosine_batch_descriptor_t* candidates,
    float* out_matrix,
    enum anigma_cosine_simd_t simd,
    anigma_capsule_error_t* err
) {
    (void)handle;
    
    if (!queries || !candidates || !out_matrix) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Null pointer argument";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (!validateLayout(&queries->layout, err) || !validateLayout(&candidates->layout, err)) {
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (queries->layout.dimension != candidates->layout.dimension) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Query and candidate dimensions must match";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    // Simple nested loop implementation - can be optimized with blocking
    const float* queries_f32 = static_cast<const float*>(queries->vectors);
    const float* candidates_f32 = static_cast<const float*>(candidates->vectors);
    
    for (size_t i = 0; i < queries->count; ++i) {
        const float* query = queries_f32 + (i * queries->layout.stride);
        
        for (size_t j = 0; j < candidates->count; ++j) {
            const float* candidate = candidates_f32 + (j * candidates->layout.stride);
            
            anigma_status_t status = anigma_cosine_similarity_compute_single(
                handle,
                query,
                candidate,
                &queries->layout,
                &out_matrix[i * candidates->count + j],
                simd,
                err
            );
            
            if (status != ANIGMA_OK) {
                return status;
            }
        }
    }
    
    return ANIGMA_OK;
}

anigma_status_t anigma_cosine_similarity_query_performance(
    size_t dimension,
    size_t batch_size,
    enum anigma_cosine_simd_t simd,
    double* out_estimated_ops,
    anigma_capsule_error_t* err
) {
    (void)dimension;
    (void)batch_size;
    (void)simd;
    (void)err;
    
    // Simple estimation for now
    if (out_estimated_ops) {
        // Very rough estimate: 2 flops per dimension per vector
        // Actual will depend on SIMD level and cache effects
        *out_estimated_ops = 1.0e9;  // 1 GFLOPS conservative estimate
    }
    
    return ANIGMA_OK;
}