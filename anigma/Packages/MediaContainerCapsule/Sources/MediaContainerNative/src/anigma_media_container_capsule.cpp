#include "../../include/anigma_media_container_capsule.h"
#include "../../include/anigma_capsule_core.h"

#include <cstdint>
#include <cstring>
#include <cstdlib>
#include <vector>
#include <memory>
#include <string>
#include <unordered_map>
#include <mutex>
#include <chrono>

// FFmpeg includes (conditional compilation)
#ifdef HAVE_FFMPEG
extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>
#include <libswscale/swscale.h>
}

// Forward declarations to avoid incomplete type errors
typedef struct AVCodecID AVCodecID;
typedef struct AVCodecParameters AVCodecParameters;
typedef struct AVDictionary AVDictionary;

// Missing AVERROR constants for MediaContainerCapsule
#ifndef AVERROR
#define AVERROR(e) AVERROR_##e
#endif

// ============================================================================
// Internal Implementation Details
// ============================================================================

namespace {

// Media container internal state
struct MediaContainerState {
    anigma_capsule_identity_t identity;
    uint64_t instance_id;
    
#ifdef HAVE_FFMPEG
    AVFormatContext* format_ctx;
    AVCodecContext* video_codec_ctx;
    AVCodecContext* audio_codec_ctx;
    SwsContext* sws_ctx;
    std::vector<AVStream*> streams;
    bool is_open;
#endif
    
    MediaContainerState() : instance_id(0)
#ifdef HAVE_FFMPEG
        , format_ctx(nullptr), video_codec_ctx(nullptr), audio_codec_ctx(nullptr)
        , sws_ctx(nullptr), is_open(false)
#endif
    {
        // Generate a simple instance ID
        static uint64_t next_id = 1;
        instance_id = next_id++;
    }
    
    ~MediaContainerState() {
        cleanup();
    }
    
    void cleanup() {
#ifdef HAVE_FFMPEG
        if (sws_ctx) {
            sws_freeContext(sws_ctx);
            sws_ctx = nullptr;
        }
        
        if (video_codec_ctx) {
            avcodec_free_context(video_codec_ctx);
            video_codec_ctx = nullptr;
        }
        
        if (audio_codec_ctx) {
            avcodec_free_context(audio_codec_ctx);
            audio_codec_ctx = nullptr;
        }
        
        if (format_ctx) {
            if (is_open) {
                avformat_close_input(&format_ctx);
                is_open = false;
            }
            avformat_free_context(format_ctx);
            format_ctx = nullptr;
        }
        
        streams.clear();
#endif
    }
};

// Helper to convert FFmpeg error code to anigma_status_t
static anigma_status_t ffmpeg_error_to_anigma_status(int err) {
    if (err >= 0) return ANIGMA_OK;
    
    switch (err) {
        case AVERROR(ENOENT): return ANIGMA_ERR_NOT_FOUND;
        case AVERROR(EINVAL): return ANIGMA_ERR_INVALID_ARG;
        case AVERROR(ENOMEM): return ANIGMA_ERR_OUT_OF_MEMORY;
        case AVERROR(EIO): return ANIGMA_ERR_IO;
        default: return ANIGMA_ERR_PROCESSING_FAILED;
    }
}

// Convert FFmpeg codec ID to our enum
static anigma_video_codec_t ffmpeg_video_codec_to_anigma(AVCodecID codec_id) {
    switch (codec_id) {
        case AV_CODEC_ID_H264: return ANIGMA_VIDEO_CODEC_H264;
        case AV_CODEC_ID_H265: 
        case AV_CODEC_ID_HEVC: return ANIGMA_VIDEO_CODEC_H265;
        case AV_CODEC_ID_VP9: return ANIGMA_VIDEO_CODEC_VP9;
        case AV_CODEC_ID_AV1: return ANIGMA_VIDEO_CODEC_AV1;
        case AV_CODEC_ID_MPEG2VIDEO: return ANIGMA_VIDEO_CODEC_MPEG2;
        case AV_CODEC_ID_MPEG4: return ANIGMA_VIDEO_CODEC_MPEG4;
        case AV_CODEC_ID_VC1: return ANIGMA_VIDEO_CODEC_VC1;
        case AV_CODEC_ID_THEORA: return ANIGMA_VIDEO_CODEC_THEORA;
        default: return ANIGMA_VIDEO_CODEC_UNKNOWN;
    }
}

static anigma_audio_codec_t ffmpeg_audio_codec_to_anima(AVCodecID codec_id) {
    switch (codec_id) {
        case AV_CODEC_ID_AAC: return ANIGMA_AUDIO_CODEC_AAC;
        case AV_CODEC_ID_MP3: return ANIGMA_AUDIO_CODEC_MP3;
        case AV_CODEC_ID_OPUS: return ANIGMA_AUDIO_CODEC_OPUS;
        case AV_CODEC_ID_VORBIS: return ANIGMA_AUDIO_CODEC_VORBIS;
        case AV_CODEC_ID_FLAC: return ANIGMA_AUDIO_CODEC_FLAC;
        case AV_CODEC_ID_PCM_S16LE: return ANIGMA_AUDIO_CODEC_PCM_S16LE;
        case AV_CODEC_ID_PCM_F32LE: return ANIGMA_AUDIO_CODEC_PCM_F32LE;
        default: return ANIGMA_AUDIO_CODEC_UNKNOWN;
    }
}

} // anonymous namespace

// ============================================================================
// Public API Implementation
// ============================================================================

extern "C" {

anigma_capsule_identity_t anigma_media_container_capsule_get_identity(void) {
    return anigma_capsule_identity_t{
        "media_container_capsule",
        "1.0.0",
        1,  // Tier 1 deterministic
        __DATE__ " " __TIME__,
        "Production-ready media container handling with FFmpeg"
    };
}

anigma_status_t anigma_media_container_capsule_create(
    anigma_media_container_capsule_t* out_capsule,
    anigma_capsule_error_t* err) {
    
    if (!out_capsule) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Output capsule pointer is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        auto* state = new MediaContainerState();
        if (!state) {
            if (err) {
                err->code = ANIGMA_ERR_OUT_OF_MEMORY;
                err->message = "Failed to allocate media container state";
            }
            return ANIGMA_ERR_OUT_OF_MEMORY;
        }
        
        *out_capsule = static_cast<anigma_media_container_capsule_t>(state);
        return ANIGMA_OK;
        
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Exception during capsule creation";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_media_container_capsule_destroy(
    anigma_media_container_capsule_t capsule,
    anigma_capsule_error_t* err) {
    
    if (!capsule) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Capsule handle is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        auto* state = static_cast<MediaContainerState*>(capsule);
        delete state;
        return ANIGMA_OK;
        
    } catch (...) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Exception during capsule destruction";
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_media_container_capsule_open_file(
    anigma_media_container_capsule_t capsule,
    const char* filename,
    anigma_capsule_error_t* err) {
    
    if (!capsule || !filename) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
#ifdef HAVE_FFMPEG
    auto* state = static_cast<MediaContainerState*>(capsule);
    
    // Close existing file if open
    if (state->is_open && state->format_ctx) {
        avformat_close_input(&state->format_ctx);
        state->is_open = false;
    }
    
    // Open the input file
    int ret = avformat_open_input(&state->format_ctx, filename, nullptr, nullptr, 0);
    if (ret < 0) {
        anigma_status_t status = ffmpeg_error_to_anigma_status(ret);
        if (err) {
            err->code = status;
            err->message = "Failed to open media file";
            err->detail = av_err2str(ret);
        }
        return status;
    }
    
    // Retrieve stream information
    ret = avformat_find_stream_info(state->format_ctx, nullptr);
    if (ret < 0) {
        anigma_status_t status = ffmpeg_error_to_anigma_status(ret);
        if (err) {
            err->code = status;
            err->message = "Failed to get stream information";
            err->detail = av_err2str(ret);
        }
        avformat_close_input(&state->format_ctx);
        return status;
    }
    
    // Store stream information
    state->streams.clear();
    for (unsigned int i = 0; i < state->format_ctx->nb_streams; i++) {
        state->streams.push_back(state->format_ctx->streams[i]);
    }
    
    state->is_open = true;
    return ANIGMA_OK;
#else
    if (err) {
        err->code = ANIGMA_ERR_UNSUPPORTED_FORMAT;
        err->message = "FFmpeg support not compiled in";
    }
    return ANIGMA_ERR_UNSUPPORTED_FORMAT;
#endif
}

anigma_status_t anigma_media_container_capsule_get_stream_count(
    anigma_media_container_capsule_t capsule,
    uint32_t* out_count,
    anigma_capsule_error_t* err) {
    
    if (!capsule || !out_count) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* state = static_cast<MediaContainerState*>(capsule);
    
#ifdef HAVE_FFMPEG
    if (!state->format_ctx) {
        if (err) {
            err->code = ANIGMA_ERR_NOT_INITIALIZED;
            err->message = "No file is open";
        }
        return ANIGMA_ERR_NOT_INITIALIZED;
    }
    
    *out_count = static_cast<uint32_t>(state->format_ctx->nb_streams);
    return ANIGMA_OK;
#else
    if (err) {
        err->code = ANIGMA_ERR_UNSUPPORTED_FORMAT;
        err->message = "FFmpeg support not compiled in";
    }
    return ANIGMA_ERR_UNSUPPORTED_FORMAT;
#endif
}

anigma_status_t anigma_media_container_capsule_get_stream_info(
    anigma_media_container_capsule_t capsule,
    uint32_t stream_index,
    anigma_media_stream_info_t* out_info,
    anigma_capsule_error_t* err) {
    
    if (!capsule || !out_info) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* state = static_cast<MediaContainerState*>(capsule);
    
#ifdef HAVE_FFMPEG
    if (!state->format_ctx || stream_index >= state->format_ctx->nb_streams) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid stream index or no file open";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    AVStream* stream = state->format_ctx->streams[stream_index];
    AVCodecParameters* codecpar = stream->codecpar;
    
    // Initialize info structure
    memset(out_info, 0, sizeof(anigma_media_stream_info_t));
    
    // Set stream type
    switch (codecpar->codec_type) {
        case AVMEDIA_TYPE_VIDEO:
            out_info->type = ANIGMA_MEDIA_STREAM_VIDEO;
            out_info->video.width = codecpar->width;
            out_info->video.height = codecpar->height;
            out_info->video.frame_rate_num = stream->avg_frame_rate.num;
            out_info->video.frame_rate_den = stream->avg_frame_rate.den;
            out_info->video.bit_rate = codecpar->bit_rate;
            out_info->video.codec = ffmpeg_video_codec_to_anigma(codecpar->codec_id);
            break;
            
        case AVMEDIA_TYPE_AUDIO:
            out_info->type = ANIGMA_MEDIA_STREAM_AUDIO;
            out_info->audio.sample_rate = codecpar->sample_rate;
            out_info->audio.channels = codecpar->channels;
            out_info->audio.bit_rate = codecpar->bit_rate;
            out_info->audio.codec = ffmpeg_audio_codec_to_anima(codecpar->codec_id);
            break;
            
        case AVMEDIA_TYPE_SUBTITLE:
            out_info->type = ANIGMA_MEDIA_STREAM_SUBTITLE;
            break;
            
        case AVMEDIA_TYPE_DATA:
            out_info->type = ANIGMA_MEDIA_STREAM_DATA;
            break;
            
        case AVMEDIA_TYPE_ATTACHMENT:
            out_info->type = ANIGMA_MEDIA_STREAM_ATTACHMENT;
            break;
            
        default:
            out_info->type = ANIGMA_MEDIA_STREAM_UNKNOWN;
            break;
    }
    
    out_info->duration_sec = static_cast<double>(state->format_ctx->duration) / AV_TIME_BASE;
    out_info->start_time_sec = static_cast<double>(state->format_ctx->start_time) / AV_TIME_BASE;
    
    return ANIGMA_OK;
#else
    if (err) {
        err->code = ANIGMA_ERR_UNSUPPORTED_FORMAT;
        err->message = "FFmpeg support not compiled in";
    }
    return ANIGMA_ERR_UNSUPPORTED_FORMAT;
#endif
}

anigma_status_t anigma_media_container_capsule_get_metadata(
    anigma_media_container_capsule_t capsule,
    const char** out_metadata,
    size_t metadata_size,
    size_t* out_actual,
    anigma_capsule_error_t* err) {
    
    if (!capsule || !out_metadata || !out_actual) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* state = static_cast<MediaContainerState*>(capsule);
    
#ifdef HAVE_FFMPEG
    if (!state->format_ctx) {
        if (err) {
            err->code = ANIGMA_ERR_NOT_INITIALIZED;
            err->message = "No file is open";
        }
        return ANIGMA_ERR_NOT_INITIALIZED;
    }
    
    // Create a JSON string with metadata
    std::string metadata_json = "{";
    bool first = true;
    
    AVDictionaryEntry* tag = nullptr;
    while ((tag = av_dict_get(state->format_ctx->metadata, "", tag, AV_DICT_IGNORE_SUFFIX))) {
        if (!first) metadata_json += ",";
        metadata_json += "\"" + std::string(tag->key) + "\":\"" + std::string(tag->value) + "\"";
        first = false;
    }
    
    metadata_json += "}";
    
    // Copy to output buffer
    size_t needed = metadata_json.length() + 1;
    if (needed > metadata_size) {
        if (err) {
            err->code = ANIGMA_ERR_BUFFER_TOO_SMALL;
            err->message = "Metadata buffer too small";
            err->aux = needed;
        }
        return ANIGMA_ERR_BUFFER_TOO_SMALL;
    }
    
    strcpy(const_cast<char*>(out_metadata[0]), metadata_json.c_str());
    *out_actual = needed;
    
    return ANIGMA_OK;
#else
    if (err) {
        err->code = ANIGMA_ERR_UNSUPPORTED_FORMAT;
        err->message = "FFmpeg support not compiled in";
    }
    return ANIGMA_ERR_UNSUPPORTED_FORMAT;
#endif
}

anigma_status_t anigma_media_container_capsule_close(
    anigma_media_container_capsule_t capsule,
    anigma_capsule_error_t* err) {
    
    if (!capsule) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Capsule handle is null";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* state = static_cast<MediaContainerState*>(capsule);
    
#ifdef HAVE_FFMPEG
    if (state->format_ctx && state->is_open) {
        avformat_close_input(&state->format_ctx);
        state->is_open = false;
        
        // Clear stream information
        state->streams.clear();
    }
    
    return ANIGMA_OK;
#else
    if (err) {
        err->code = ANIGMA_ERR_UNSUPPORTED_FORMAT;
        err->message = "FFmpeg support not compiled in";
    }
    return ANIGMA_ERR_UNSUPPORTED_FORMAT;
#endif
}

anigma_status_t anigma_media_container_capsule_supports_format(
    const char* format,
    uint8_t* out_supported,
    anigma_capsule_error_t* err) {
    
    if (!format || !out_supported) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
#ifdef HAVE_FFMPEG
    // Check if format is supported by FFmpeg
    const AVInputFormat* input_format = av_find_input_format(format);
    *out_supported = (input_format != nullptr) ? 1 : 0;
    
    return ANIGMA_OK;
#else
    // Mock implementation - assume common formats are supported
    *out_supported = 0;
    if (strcmp(format, "mp4") == 0 || 
        strcmp(format, "avi") == 0 || 
        strcmp(format, "mkv") == 0 ||
        strcmp(format, "mov") == 0) {
        *out_supported = 1;
    }
    
    return ANIGMA_OK;
#endif
}

} // extern "C"