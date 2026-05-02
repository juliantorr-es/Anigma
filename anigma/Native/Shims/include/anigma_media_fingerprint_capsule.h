#ifndef ANIGMA_MEDIA_FINGERPRINT_CAPSULE_H
#define ANIGMA_MEDIA_FINGERPRINT_CAPSULE_H

#include "anigma_capsule_core.h"
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

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
    uint32_t prototype_id;
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

anigma_capsule_identity_t anigma_media_fingerprint_capsule_get_identity(void);

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

anigma_status_t anigma_media_fingerprint_analyze_video_buffer(
    const anigma_capsule_buffer_t* input_buffer,
    anigma_media_metadata_t* metadata,
    anigma_capsule_error_t* error
);

anigma_status_t anigma_media_fingerprint_generate_video_hash(
    const anigma_capsule_buffer_t* input_buffer,
    const anigma_video_fingerprint_config_t* config,
    anigma_fingerprint_algorithm_t algorithm,
    anigma_fingerprint_result_t* result,
    anigma_capsule_error_t* error
);

anigma_status_t anigma_media_fingerprint_compare_video_hashes(
    const anigma_fingerprint_result_t* hash1,
    const anigma_fingerprint_result_t* hash2,
    const anigma_similarity_config_t* config,
    anigma_similarity_result_t* result,
    anigma_capsule_error_t* error
);

anigma_image_fingerprint_config_t anigma_media_fingerprint_get_default_image_config(void);
anigma_audio_fingerprint_config_t anigma_media_fingerprint_get_default_audio_config(void);
anigma_video_fingerprint_config_t anigma_media_fingerprint_get_default_video_config(void);
anigma_similarity_config_t anigma_media_fingerprint_get_default_similarity_config(void);

#ifdef __cplusplus
}
#endif

#endif