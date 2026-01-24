#ifndef ANIGMA_MEDIA_FINGERPRINT_CAPSULE_H
#define ANIGMA_MEDIA_FINGERPRINT_CAPSULE_H

#include "anigma_capsule_core.h"

#ifdef __cplusplus
extern "C" {
#endif

// Media types
typedef enum {
    ANIGMA_MEDIA_TYPE_UNKNOWN = 0,
    ANIGMA_MEDIA_TYPE_IMAGE = 1,
    ANIGMA_MEDIA_TYPE_AUDIO = 2,
    ANIGMA_MEDIA_TYPE_VIDEO = 3
} anigma_media_type_t;

// Fingerprint algorithms
typedef enum {
    ANIGMA_FINGERPRINT_AVERAGE_HASH = 0,
    ANIGMA_FINGERPRINT_PERCEPTUAL_HASH = 1,
    ANIGMA_FINGERPRINT_DIFFERENCE_HASH = 2,
    ANIGMA_FINGERPRINT_WAVELET_HASH = 3,
    ANIGMA_FINGERPRINT_CHROMAPRINT = 4,
    ANIGMA_FINGERPRINT_MOTION_VECTOR = 5
} anigma_fingerprint_algorithm_t;

// Image fingerprint configuration
typedef struct {
    uint32_t hash_size;
    uint32_t resize_width;
    uint32_t resize_height;
    bool high_frequency_boost;
    uint32_t determinism_tier;
} anigma_image_fingerprint_config_t;

// Audio fingerprint configuration
typedef struct {
    uint32_t sample_rate;
    uint32_t window_size;
    uint32_t prototype_id; // Placeholder
    uint32_t hop_size;
    uint32_t num_coefficients;
    uint32_t fingerprint_size;
    uint32_t determinism_tier;
} anigma_audio_fingerprint_config_t;

// Video fingerprint configuration
typedef struct {
    uint32_t frame_sample_rate;
    uint32_t keyframe_interval;
    uint32_t motion_threshold;
    uint32_t fingerprint_size;
    uint32_t determinism_tier;
} anigma_video_fingerprint_config_t;

// Fingerprint result
typedef struct {
    anigma_fingerprint_algorithm_t algorithm;
    uint32_t hash_size;
    uint8_t* hash_data;
    double confidence;
    uint64_t processing_time_ms;
} anigma_fingerprint_result_t;

// Media metadata
typedef struct {
    anigma_media_type_t media_type;
    uint64_t file_size;
    uint32_t width;
    uint32_t height;
    uint32_t duration_ms;
    uint32_t bit_rate;
    uint32_t sample_rate;
    char format[16];
    char codec[16];
} anigma_media_metadata_t;

// Similarity configuration
typedef struct {
    double similarity_threshold;
    bool use_hamming_distance;
    bool enable_partial_matching;
    double partial_match_threshold;
} anigma_similarity_config_t;

// Similarity result
typedef struct {
    double similarity_score;
    uint32_t hamming_distance;
    bool is_duplicate;
    bool is_partial_match;
} anigma_similarity_result_t;

// Opaque handle for media fingerprint capsule
typedef anigma_capsule_handle_t anigma_media_fingerprint_capsule_t;

// Capsule management functions
anigma_status_t anigma_media_fingerprint_capsule_create(
    const anigma_image_fingerprint_config_t* image_config,
    const anigma_audio_fingerprint_config_t* audio_config,
    const anigma_video_fingerprint_config_t* video_config,
    anigma_media_fingerprint_capsule_t* capsule,
    anigma_capsule_error_t* error
);

anigma_status_t anigma_media_fingerprint_capsule_destroy(
    anigma_media_fingerprint_capsule_t* capsule,
    anigma_capsule_error_t* error
);

anigma_status_t anigma_media_fingerprint_capsule_reset(
    anigma_media_fingerprint_capsule_t capsule,
    anigma_capsule_error_t* error
);

// Media analysis functions
anigma_status_t anigma_media_fingerprint_detect_media_type(
    const anigma_capsule_buffer_t* input_buffer,
    anigma_media_type_t* media_type,
    anigma_capsule_error_t* error
);

anigma_status_t anigma_media_fingerprint_analyze_buffer(
    anigma_media_fingerprint_capsule_t capsule,
    const anigma_capsule_buffer_t* input_buffer,
    anigma_media_type_t media_type,
    anigma_media_metadata_t* metadata,
    anigma_capsule_error_t* error
);

// Fingerprint generation functions
anigma_status_t anigma_media_fingerprint_generate_image(
    anigma_media_fingerprint_capsule_t capsule,
    const anigma_capsule_buffer_t* input_buffer,
    anigma_fingerprint_algorithm_t algorithm,
    anigma_fingerprint_result_t* result,
    anigma_capsule_error_t* error
);

anigma_status_t anigma_media_fingerprint_generate_audio(
    anigma_media_fingerprint_capsule_t capsule,
    const anigma_capsule_buffer_t* input_buffer,
    anigma_fingerprint_algorithm_t algorithm,
    anigma_fingerprint_result_t* result,
    anigma_capsule_error_t* error
);

anigma_status_t anigma_media_fingerprint_generate_video(
    anigma_media_fingerprint_capsule_t capsule,
    const anigma_capsule_buffer_t* input_buffer,
    anigma_fingerprint_algorithm_t algorithm,
    anigma_fingerprint_result_t* result,
    anigma_capsule_error_t* error
);

// Similarity computation functions
anigma_status_t anigma_media_fingerprint_compare(
    anigma_media_fingerprint_capsule_t capsule,
    const anigma_fingerprint_result_t* fingerprint1,
    const anigma_fingerprint_result_t* fingerprint2,
    const anigma_similarity_config_t* config,
    anigma_similarity_result_t* result,
    anigma_capsule_error_t* error
);

anigma_status_t anigma_media_fingerprint_batch_compare(
    anigma_media_fingerprint_capsule_t capsule,
    const anigma_fingerprint_result_t* query_fingerprint,
    const anigma_fingerprint_result_t* candidate_fingerprints,
    size_t candidate_count,
    const anigma_similarity_config_t* config,
    anigma_similarity_result_t* results,
    size_t* actual_count,
    anigma_capsule_error_t* error
);

// Utility functions
anigma_status_t anigma_media_fingerprint_free_result(
    anigma_fingerprint_result_t* result,
    anigma_capsule_error_t* error
);

anigma_status_t anigma_media_fingerprint_free_results(
    anigma_fingerprint_result_t* results,
    size_t count,
    anigma_capsule_error_t* error
);

// Default configuration functions
anigma_image_fingerprint_config_t anigma_media_fingerprint_get_default_image_config(void);
anigma_audio_fingerprint_config_t anigma_media_fingerprint_get_default_audio_config(void);
anigma_video_fingerprint_config_t anigma_media_fingerprint_get_default_video_config(void);
anigma_similarity_config_t anigma_media_fingerprint_get_default_similarity_config(void);

// Identity and versioning
anigma_capsule_identity_t anigma_media_fingerprint_capsule_get_identity(void);

#ifdef __cplusplus
}
#endif

#endif // ANIGMA_MEDIA_FINGERPRINT_CAPSULE_H
