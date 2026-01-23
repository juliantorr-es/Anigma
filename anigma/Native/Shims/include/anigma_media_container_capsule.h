#ifndef ANIGMA_MEDIA_CONTAINER_CAPSULE_H
#define ANIGMA_MEDIA_CONTAINER_CAPSULE_H

#include "anigma_capsule_core.h"
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Media container capsule types
typedef anigma_capsule_handle_t anigma_media_container_capsule_t;

// Media stream types
typedef enum {
    ANIGMA_MEDIA_STREAM_UNKNOWN = 0,
    ANIGMA_MEDIA_STREAM_VIDEO = 1,
    ANIGMA_MEDIA_STREAM_AUDIO = 2,
    ANIGMA_MEDIA_STREAM_SUBTITLE = 3,
    ANIGMA_MEDIA_STREAM_DATA = 4,
    ANIGMA_MEDIA_STREAM_ATTACHMENT = 5
} anigma_media_stream_type_t;

// Video codec types
typedef enum {
    ANIGMA_VIDEO_CODEC_UNKNOWN = 0,
    ANIGMA_VIDEO_CODEC_H264 = 1,
    ANIGMA_VIDEO_CODEC_H265 = 2,
    ANIGMA_VIDEO_CODEC_VP9 = 3,
    ANIGMA_VIDEO_CODEC_AV1 = 4,
    ANIGMA_VIDEO_CODEC_MPEG2 = 5,
    ANIGMA_VIDEO_CODEC_MPEG4 = 6,
    ANIGMA_VIDEO_CODEC_VC1 = 7,
    ANIGMA_VIDEO_CODEC_THEORA = 8
} anigma_video_codec_t;

// Audio codec types
typedef enum {
    ANIGMA_AUDIO_CODEC_UNKNOWN = 0,
    ANIGMA_AUDIO_CODEC_AAC = 1,
    ANIGMA_AUDIO_CODEC_MP3 = 2,
    ANIGMA_AUDIO_CODEC_OPUS = 3,
    ANIGMA_AUDIO_CODEC_VORBIS = 4,
    ANIGMA_AUDIO_CODEC_FLAC = 5,
    ANIGMA_AUDIO_CODEC_PCM_S16LE = 6,
    ANIGMA_AUDIO_CODEC_PCM_F32LE = 7
} anigma_audio_codec_t;

// Container format types
typedef enum {
    ANIGMA_CONTAINER_UNKNOWN = 0,
    ANIGMA_CONTAINER_MP4 = 1,
    ANIGMA_CONTAINER_MATROSKA = 2,
    ANIGMA_CONTAINER_AVI = 3,
    ANIGMA_CONTAINER_MOV = 4,
    ANIGMA_CONTAINER_WEBM = 5,
    ANIGMA_CONTAINER_MPEG_TS = 6,
    ANIGMA_CONTAINER_FLV = 7,
    ANIGMA_CONTAINER_OGG = 8
} anigma_container_type_t;

// Rational number for timebases
typedef struct {
    uint32_t num;
    uint32_t den;
} anigma_rational_t;

// Video stream information
typedef struct {
    anigma_video_codec_t codec;
    uint32_t width;
    uint32_t height;
    anigma_rational_t frame_rate;
    anigma_rational_t time_base;
    uint64_t duration_us;        // Duration in microseconds
    uint32_t bit_rate;
    uint32_t frame_count;
    char codec_profile[16];      // e.g., "High", "Main", "Baseline"
    char codec_level[16];        // e.g., "4.0", "5.1"
} anigma_video_stream_info_t;

// Audio stream information
typedef struct {
    anigma_audio_codec_t codec;
    uint32_t sample_rate;
    uint32_t channels;
    uint32_t bits_per_sample;
    uint64_t duration_us;        // Duration in microseconds
    uint32_t bit_rate;
    char language[4];            // ISO 639-2 language code
    uint32_t block_align;
} anigma_audio_stream_info_t;

// General stream information
typedef struct {
    anigma_media_stream_type_t type;
    uint32_t index;
    char language[4];            // For audio/subtitle streams
    char title[256];             // Stream title
    uint64_t duration_us;        // Duration in microseconds
    uint32_t bit_rate;
} anigma_stream_info_t;

// Complete media container report
typedef struct {
    anigma_container_type_t container_type;
    uint32_t stream_count;
    anigma_stream_info_t* streams;
    uint64_t total_duration_us;   // Total duration in microseconds
    uint64_t file_size_bytes;
    char title[256];
    char artist[256];
    char album[256];
    char date[32];
    char encoder[128];
    uint64_t metadata_hash;      // BLAKE3 hash of metadata for determinism
} anigma_media_container_report_t;

// Media container configuration
typedef struct {
    uint32_t determinism_tier;         // 1 = bitwise, 2 = epsilon-stable
    uint32_t max_stream_count;         // Maximum number of streams to analyze
    uint32_t analysis_flags;           // Flags for analysis options
    uint64_t max_file_size_bytes;      // Maximum file size to process
    double max_duration_seconds;         // Maximum duration to process
} anigma_media_container_config_t;

// Media container analysis flags
#define ANIGMA_MEDIA_FLAG_EXTRACT_VIDEO_INFO      (1u << 0)
#define ANIGMA_MEDIA_FLAG_EXTRACT_AUDIO_INFO      (1u << 1)
#define ANIGMA_MEDIA_FLAG_EXTRACT_METADATA         (1u << 2)
#define ANIGMA_MEDIA_FLAG_VALIDATE_CONTAINERS    (1u << 3)
#define ANIGMA_MEDIA_FLAG_ENABLE_PROFILING       (1u << 4)
#define ANIGMA_MEDIA_FLAG_EXTRACT_SUBTITLES     (1u << 5)
#define ANIGMA_MEDIA_FLAG_EXTRACT_ATTACHMENTS     (1u << 6)
#define ANIGMA_MEDIA_FLAG_DEEP_SCAN             (1u << 7)

// Get capsule identity
anigma_capsule_identity_t anigma_media_container_capsule_get_identity(void);

// Get default configuration
anigma_media_container_config_t anigma_media_container_capsule_get_default_config(void);

// Validate configuration
anigma_status_t anigma_media_container_capsule_validate_config(
    const anigma_media_container_config_t* config,
    anigma_capsule_error_t* error
);

// Create capsule instance
anigma_status_t anigma_media_container_capsule_create(
    const anigma_media_container_config_t* config,
    anigma_media_container_capsule_t** capsule,
    anigma_capsule_error_t* error
);

// Destroy capsule instance
anigma_status_t anigma_media_container_capsule_destroy(
    anigma_media_container_capsule_t* capsule,
    anigma_capsule_error_t* error
);

// Analyze media container from file path
anigma_status_t anigma_media_container_capsule_analyze_file(
    anigma_media_container_capsule_t* capsule,
    const char* file_path,
    anigma_media_container_report_t* report,
    anigma_capsule_error_t* error
);

// Analyze media container from memory buffer
anigma_status_t anigma_media_container_capsule_analyze_buffer(
    anigma_media_container_capsule_t* capsule,
    const uint8_t* data,
    size_t data_size,
    anigma_media_container_report_t* report,
    anigma_capsule_error_t* error
);

// Extract specific stream information
anigma_status_t anigma_media_container_capsule_get_stream_info(
    anigma_media_container_capsule_t* capsule,
    uint32_t stream_index,
    anigma_stream_info_t* stream_info,
    anigma_capsule_error_t* error
);

// Get detailed video stream information
anigma_status_t anigma_media_container_capsule_get_video_stream_info(
    anigma_media_container_capsule_t* capsule,
    uint32_t stream_index,
    anigma_video_stream_info_t* video_info,
    anigma_capsule_error_t* error
);

// Get detailed audio stream information
anigma_status_t anigma_media_container_capsule_get_audio_stream_info(
    anigma_media_container_capsule_t* capsule,
    uint32_t stream_index,
    anigma_audio_stream_info_t* audio_info,
    anigma_capsule_error_t* error
);

// Validate container format
anigma_status_t anigma_media_container_capsule_validate_container(
    anigma_media_container_capsule_t* capsule,
    const char* file_path,
    uint8_t* is_valid,
    anigma_capsule_error_t* error
);

// Get frame count for video streams
anigma_status_t anigma_media_container_capsule_get_frame_count(
    anigma_media_container_capsule_t* capsule,
    uint32_t stream_index,
    uint64_t* frame_count,
    anigma_capsule_error_t* error
);

// Get chapter/marker information
anigma_status_t anigma_media_container_capsule_get_chapters(
    anigma_media_container_capsule_t* capsule,
    anigma_capsule_buffer_t* output_buffer,  // JSON formatted chapters
    anigma_capsule_error_t* error
);

// Get thumbnail information
anigma_status_t anigma_media_container_capsule_extract_thumbnail(
    anigma_media_container_capsule_t* capsule,
    uint32_t stream_index,
    uint32_t max_width,
    uint32_t max_height,
    anigma_capsule_buffer_t* output_buffer,  // JPEG image data
    anigma_capsule_error_t* error
);

// Get performance and memory usage statistics
anigma_status_t anigma_media_container_capsule_get_stats(
    anigma_media_container_capsule_t* capsule,
    anigma_capsule_buffer_t* output_buffer,  // JSON formatted stats
    anigma_capsule_error_t* error
);

// Reset internal cache and state
anigma_status_t anigma_media_container_capsule_reset_cache(
    anigma_media_container_capsule_t* capsule,
    anigma_capsule_error_t* error
);

// Set sandbox policy for file access
anigma_status_t anigma_media_container_capsule_set_sandbox_policy(
    anigma_media_container_capsule_t* capsule,
    uint32_t allowed_paths_count,
    const char** allowed_paths,
    anigma_capsule_error_t* error
);

// Free report structure
anigma_status_t anigma_media_container_capsule_free_report(
    anigma_media_container_capsule_t* capsule,
    anigma_media_container_report_t* report,
    anigma_capsule_error_t* error
);

#ifdef __cplusplus
}
#endif

#endif // ANIGMA_MEDIA_CONTAINER_CAPSULE_H