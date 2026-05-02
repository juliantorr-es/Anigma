// AudioRenderCapsule.cpp
// C++ implementation for audio processing and rendering with FFmpeg integration

#include "include/audiorendercapsule.h"
#include <cstring>
#include <cmath>
#include <algorithm>
#include <memory>
#include <vector>

#ifdef USE_FFMPEG
extern "C" {
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libswresample/swresample.h>
#include <libavutil/opt.h>
#include <libavutil/channel_layout.h>
#include <libavutil/samplefmt.h>
}
#endif

// MARK: - Constants
static const uint32_t kMaxMetadataLength = 256;
static const uint32_t kEqualizerBands = 10;
static const float kPi = 3.14159265358979323846f;

// MARK: - Global State
static bool g_initialized = false;
static std::string g_last_error;

// MARK: - Utility Functions

static void set_last_error(const std::string& error) {
    g_last_error = error;
}

static AudioRenderErrorCode ffmpeg_error_to_audio_render(int ffmpeg_error) {
    switch (ffmpeg_error) {
        case AVERROR_INVALIDDATA:
            return AudioRenderErrorInvalidData;
        case AVERROR_DECODER_NOT_FOUND:
        case AVERROR_DEMUXER_NOT_FOUND:
            return AudioRenderErrorUnsupportedFormat;
        case AVERROR(ENOMEM):
            return AudioRenderErrorMemoryAllocation;
        case AVERROR_EOF:
            return AudioRenderErrorDecodeFailed;
        default:
            return AudioRenderErrorDecodeFailed;
    }
}

// MARK: - Core Functions

const char* audio_render_get_version(void) {
    return "1.0.0";
}

AudioRenderErrorCode audio_render_initialize(void) {
    if (g_initialized) {
        return AudioRenderErrorNone;
    }
    
#ifdef USE_FFMPEG
    // Initialize FFmpeg
    av_register_all();
    avformat_network_init();
#endif
    
    g_initialized = true;
    g_last_error.clear();
    return AudioRenderErrorNone;
}

void audio_render_cleanup(void) {
    if (!g_initialized) {
        return;
    }
    
#ifdef USE_FFMPEG
    avformat_network_deinit();
#endif
    
    g_initialized = false;
    g_last_error.clear();
}

// MARK: - Format Detection

AudioRenderFormat audio_render_detect_format(const uint8_t* data, uint64_t size) {
    if (!data || size < 12) {
        return AudioRenderFormatUnknown;
    }
    
    // MP3 detection (ID3v2 tag or MP3 sync)
    if (size >= 10 && 
        (memcmp(data, "ID3", 3) == 0 ||
         (data[0] == 0xFF && (data[1] & 0xE0) == 0xE0))) {
        return AudioRenderFormatMP3;
    }
    
    // WAV detection (RIFF header)
    if (size >= 12 && memcmp(data, "RIFF", 4) == 0 && memcmp(data + 8, "WAVE", 4) == 0) {
        return AudioRenderFormatWAV;
    }
    
    // FLAC detection
    if (size >= 4 && memcmp(data, "fLaC", 4) == 0) {
        return AudioRenderFormatFLAC;
    }
    
    // AAC detection (ADTS)
    if (size >= 2 && (data[0] == 0xFF && (data[1] & 0xF0) == 0xF0)) {
        return AudioRenderFormatAAC;
    }
    
    return AudioRenderFormatUnknown;
}

// MARK: - Decoding Implementation

#ifdef USE_FFMPEG
static AudioRenderErrorCode decode_with_ffmpeg(
    const uint8_t* data,
    uint64_t size,
    audio_metadata_t* metadata,
    uint8_t** output_data,
    uint64_t* output_size
) {
    AVFormatContext* format_ctx = nullptr;
    AVCodecContext* codec_ctx = nullptr;
    AVCodec* codec = nullptr;
    AVFrame* frame = nullptr;
    AVPacket* packet = nullptr;
    SwrContext* swr_ctx = nullptr;
    uint8_t* audio_buffer = nullptr;
    int audio_buffer_size = 0;
    
    AudioRenderErrorCode result = AudioRenderErrorNone;
    
    // Open input
    if (avformat_open_input(&format_ctx, nullptr, nullptr, nullptr) != 0) {
        set_last_error("Failed to open input");
        return AudioRenderErrorInvalidData;
    }
    
    // Create custom IO context
    AVIOContext* avio_ctx = avio_alloc_context(
        nullptr, 0, 0, const_cast<uint8_t*>(data),
        nullptr, 
        [](void* opaque, uint8_t* buf, int buf_size) -> int {
            const uint8_t** data_ptr = reinterpret_cast<const uint8_t**>(opaque);
            // Simple read implementation - would need proper buffer management
            return 0;
        },
        nullptr
    );
    
    if (!avio_ctx) {
        set_last_error("Failed to allocate AVIO context");
        result = AudioRenderErrorMemoryAllocation;
        goto cleanup;
    }
    
    format_ctx->pb = avio_ctx;
    
    // Find stream info
    if (avformat_find_stream_info(format_ctx, nullptr) < 0) {
        set_last_error("Failed to find stream info");
        result = AudioRenderErrorDecodeFailed;
        goto cleanup;
    }
    
    // Find audio stream
    int audio_stream_index = av_find_best_stream(format_ctx, AVMEDIA_TYPE_AUDIO, -1, -1, &codec, 0);
    if (audio_stream_index < 0) {
        set_last_error("No audio stream found");
        result = AudioRenderErrorUnsupportedFormat;
        goto cleanup;
    }
    
    // Create codec context
    codec_ctx = avcodec_alloc_context3(codec);
    if (!codec_ctx) {
        set_last_error("Failed to allocate codec context");
        result = AudioRenderErrorMemoryAllocation;
        goto cleanup;
    }
    
    if (avcodec_parameters_to_context(codec_ctx, format_ctx->streams[audio_stream_index]->codecpar) < 0) {
        set_last_error("Failed to copy codec parameters");
        result = AudioRenderErrorDecodeFailed;
        goto cleanup;
    }
    
    // Open codec
    if (avcodec_open2(codec_ctx, codec, nullptr) < 0) {
        set_last_error("Failed to open codec");
        result = AudioRenderErrorDecodeFailed;
        goto cleanup;
    }
    
    // Setup resampler to convert to float32
    swr_ctx = swr_alloc();
    if (!swr_ctx) {
        set_last_error("Failed to allocate resampler");
        result = AudioRenderErrorMemoryAllocation;
        goto cleanup;
    }
    
    av_opt_set_int(swr_ctx, "in_channel_layout", codec_ctx->channel_layout, 0);
    av_opt_set_int(swr_ctx, "out_channel_layout", codec_ctx->channel_layout, 0);
    av_opt_set_int(swr_ctx, "in_sample_rate", codec_ctx->sample_rate, 0);
    av_opt_set_int(swr_ctx, "out_sample_rate", codec_ctx->sample_rate, 0);
    av_opt_set_sample_fmt(swr_ctx, "in_sample_fmt", codec_ctx->sample_fmt, 0);
    av_opt_set_sample_fmt(swr_ctx, "out_sample_fmt", AV_SAMPLE_FMT_FLT, 0);
    
    if (swr_init(swr_ctx) < 0) {
        set_last_error("Failed to initialize resampler");
        result = AudioRenderErrorDecodeFailed;
        goto cleanup;
    }
    
    // Fill metadata
    metadata->sample_rate = codec_ctx->sample_rate;
    metadata->channels = codec_ctx->channels;
    metadata->duration_ms = static_cast<uint32_t>(
        (format_ctx->duration * 1000) / AV_TIME_BASE
    );
    metadata->bit_rate = static_cast<uint32_t>(format_ctx->bit_rate);
    metadata->sample_format = AudioRenderSampleFormatF32;
    metadata->frame_count = 0;
    
    // Detect format
    metadata->format = audio_render_detect_format(data, size);
    
    // Copy metadata tags
    AVDictionaryEntry* tag = nullptr;
    while ((tag = av_dict_get(format_ctx->metadata, "", tag, AV_DICT_IGNORE_SUFFIX))) {
        if (strcmp(tag->key, "title") == 0) {
            strncpy(metadata->title, tag->value, kMaxMetadataLength - 1);
        } else if (strcmp(tag->key, "artist") == 0) {
            strncpy(metadata->artist, tag->value, kMaxMetadataLength - 1);
        } else if (strcmp(tag->key, "album") == 0) {
            strncpy(metadata->album, tag->value, kMaxMetadataLength - 1);
        }
    }
    
    // Allocate output buffer
    audio_buffer_size = codec_ctx->sample_rate * codec_ctx->channels * sizeof(float);
    audio_buffer = static_cast<uint8_t*>(malloc(audio_buffer_size));
    if (!audio_buffer) {
        set_last_error("Failed to allocate audio buffer");
        result = AudioRenderErrorMemoryAllocation;
        goto cleanup;
    }
    
    // Decode frames
    frame = av_frame_alloc();
    packet = av_packet_alloc();
    
    uint8_t* current_pos = audio_buffer;
    uint64_t total_samples = 0;
    
    while (av_read_frame(format_ctx, packet) >= 0) {
        if (packet->stream_index == audio_stream_index) {
            int ret = avcodec_send_packet(codec_ctx, packet);
            if (ret < 0) {
                continue;
            }
            
            while (ret >= 0) {
                ret = avcodec_receive_frame(codec_ctx, frame);
                if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
                    break;
                }
                
                if (ret < 0) {
                    continue;
                }
                
                // Resample frame
                int out_samples = swr_convert(
                    swr_ctx,
                    reinterpret_cast<uint8_t**>(&current_pos),
                    frame->nb_samples,
                    const_cast<const uint8_t**>(frame->data),
                    frame->nb_samples
                );
                
                if (out_samples > 0) {
                    current_pos += out_samples * codec_ctx->channels * sizeof(float);
                    total_samples += out_samples;
                    
                    // Resize buffer if needed
                    size_t current_size = current_pos - audio_buffer;
                    if (current_size + audio_buffer_size > static_cast<size_t>(audio_buffer_size)) {
                        audio_buffer_size *= 2;
                        audio_buffer = static_cast<uint8_t*>(realloc(audio_buffer, audio_buffer_size));
                        if (!audio_buffer) {
                            set_last_error("Failed to reallocate audio buffer");
                            result = AudioRenderErrorMemoryAllocation;
                            goto cleanup;
                        }
                        current_pos = audio_buffer + current_size;
                    }
                }
                
                av_frame_unref(frame);
            }
        }
        av_packet_unref(packet);
    }
    
    metadata->frame_count = total_samples;
    *output_data = audio_buffer;
    *output_size = total_samples * codec_ctx->channels * sizeof(float);
    audio_buffer = nullptr; // Don't free in cleanup
    
cleanup:
    if (audio_buffer) free(audio_buffer);
    if (frame) av_frame_free(&frame);
    if (packet) av_packet_free(&packet);
    if (swr_ctx) swr_free(&swr_ctx);
    if (codec_ctx) avcodec_free_context(&codec_ctx);
    if (avio_ctx) avio_context_free(&avio_ctx);
    if (format_ctx) avformat_close_input(&format_ctx);
    
    return result;
}
#endif

// MARK: - Decoding Functions

uint8_t* audio_render_decode(const uint8_t* data, uint64_t size, audio_metadata_t* metadata) {
    if (!data || !metadata || size == 0) {
        set_last_error("Invalid parameters");
        return nullptr;
    }
    
    if (!g_initialized) {
        set_last_error("Audio renderer not initialized");
        return nullptr;
    }
    
    AudioRenderFormat format = audio_render_detect_format(data, size);
    
    switch (format) {
        case AudioRenderFormatMP3:
            return audio_render_decode_mp3(data, size, metadata);
        case AudioRenderFormatWAV:
            return audio_render_decode_wav(data, size, metadata);
        case AudioRenderFormatFLAC:
            return audio_render_decode_flac(data, size, metadata);
        case AudioRenderFormatAAC:
            return audio_render_decode_aac(data, size, metadata);
        default:
            set_last_error("Unsupported audio format");
            return nullptr;
    }
}

uint8_t* audio_render_decode_mp3(const uint8_t* data, uint64_t size, audio_metadata_t* metadata) {
#ifdef USE_FFMPEG
    uint8_t* output_data = nullptr;
    uint64_t output_size = 0;
    
    AudioRenderErrorCode result = decode_with_ffmpeg(data, size, metadata, &output_data, &output_size);
    if (result != AudioRenderErrorNone) {
        return nullptr;
    }
    
    return output_data;
#else
    set_last_error("FFmpeg support not enabled");
    return nullptr;
#endif
}

uint8_t* audio_render_decode_wav(const uint8_t* data, uint64_t size, audio_metadata_t* metadata) {
#ifdef USE_FFMPEG
    uint8_t* output_data = nullptr;
    uint64_t output_size = 0;
    
    AudioRenderErrorCode result = decode_with_ffmpeg(data, size, metadata, &output_data, &output_size);
    if (result != AudioRenderErrorNone) {
        return nullptr;
    }
    
    return output_data;
#else
    set_last_error("FFmpeg support not enabled");
    return nullptr;
#endif
}

uint8_t* audio_render_decode_flac(const uint8_t* data, uint64_t size, audio_metadata_t* metadata) {
#ifdef USE_FFMPEG
    uint8_t* output_data = nullptr;
    uint64_t output_size = 0;
    
    AudioRenderErrorCode result = decode_with_ffmpeg(data, size, metadata, &output_data, &output_size);
    if (result != AudioRenderErrorNone) {
        return nullptr;
    }
    
    return output_data;
#else
    set_last_error("FFmpeg support not enabled");
    return nullptr;
#endif
}

uint8_t* audio_render_decode_aac(const uint8_t* data, uint64_t size, audio_metadata_t* metadata) {
#ifdef USE_FFMPEG
    uint8_t* output_data = nullptr;
    uint64_t output_size = 0;
    
    AudioRenderErrorCode result = decode_with_ffmpeg(data, size, metadata, &output_data, &output_size);
    if (result != AudioRenderErrorNone) {
        return nullptr;
    }
    
    return output_data;
#else
    set_last_error("FFmpeg support not enabled");
    return nullptr;
#endif
}

void audio_render_free_data(uint8_t* data) {
    if (data) {
        free(data);
    }
}

// MARK: - Audio Effects

AudioRenderErrorCode audio_render_apply_effect(
    uint8_t* data,
    uint64_t frame_count,
    const audio_metadata_t* metadata,
    const audio_effect_params_t* effect
) {
    if (!data || !metadata || !effect || frame_count == 0) {
        return AudioRenderErrorInvalidParameters;
    }
    
    switch (effect->type) {
        case AudioRenderEffectReverb:
            return audio_render_apply_reverb(data, frame_count, metadata, effect);
        case AudioRenderEffectEqualizer:
            return audio_render_apply_equalizer(data, frame_count, metadata, effect);
        case AudioRenderEffectCompressor:
            return audio_render_apply_compressor(data, frame_count, metadata, effect);
        case AudioRenderEffectDelay:
            return audio_render_apply_delay(data, frame_count, metadata, effect);
        default:
            return AudioRenderErrorInvalidParameters;
    }
}

// MARK: - Reverb Effect

AudioRenderErrorCode audio_render_apply_reverb(
    uint8_t* data,
    uint64_t frame_count,
    const audio_metadata_t* metadata,
    const audio_effect_params_t* effect
) {
    if (metadata->sample_format != AudioRenderSampleFormatF32) {
        return AudioRenderErrorInvalidParameters;
    }
    
    float* samples = reinterpret_cast<float*>(data);
    uint32_t channels = metadata->channels;
    uint64_t total_samples = frame_count * channels;
    
    // Simple reverb implementation using delay lines
    std::vector<std::vector<float>> delay_lines(channels);
    std::vector<uint32_t> delay_indices(channels, 0);
    
    // Initialize delay lines (different delays for each channel)
    for (uint32_t ch = 0; ch < channels; ++ch) {
        uint32_t delay_samples = static_cast<uint32_t>(
            (effect->room_size * 0.1f + 0.02f) * metadata->sample_rate
        );
        delay_lines[ch].resize(delay_samples, 0.0f);
    }
    
    // Apply reverb
    for (uint64_t i = 0; i < total_samples; ++i) {
        uint32_t ch = i % channels;
        float& sample = samples[i];
        
        // Read from delay line
        float delayed = delay_lines[ch][delay_indices[ch]];
        
        // Write to delay line
        delay_lines[ch][delay_indices[ch]] = sample;
        
        // Mix dry and wet signals
        sample = sample * effect->dry_level + delayed * effect->wet_level * effect->gain;
        
        // Apply damping
        delay_lines[ch][delay_indices[ch]] *= (1.0f - effect->damping * 0.1f);
        
        // Advance delay index
        delay_indices[ch] = (delay_indices[ch] + 1) % delay_lines[ch].size();
    }
    
    return AudioRenderErrorNone;
}

// MARK: - Equalizer Effect

AudioRenderErrorCode audio_render_apply_equalizer(
    uint8_t* data,
    uint64_t frame_count,
    const audio_metadata_t* metadata,
    const audio_effect_params_t* effect
) {
    if (metadata->sample_format != AudioRenderSampleFormatF32) {
        return AudioRenderErrorInvalidParameters;
    }
    
    float* samples = reinterpret_cast<float*>(data);
    uint32_t channels = metadata->channels;
    uint64_t total_samples = frame_count * channels;
    
    // Simple 10-band equalizer using biquad filters
    // This is a simplified implementation - a real EQ would use proper filter design
    
    for (uint32_t ch = 0; ch < channels; ++ch) {
        // Apply gain based on frequency bands
        for (uint64_t i = ch; i < total_samples; i += channels) {
            float& sample = samples[i];
            
            // Apply overall gain
            sample *= effect->gain;
            
            // Simple frequency-based gain (simplified)
            // In a real implementation, you'd use proper biquad filters
            float frequency = static_cast<float>(i % 1000) / 1000.0f;
            float band_gain = 1.0f;
            
            if (frequency < 0.1f) {
                band_gain = effect->bands[0]; // 32Hz
            } else if (frequency < 0.2f) {
                band_gain = effect->bands[1]; // 64Hz
            } else if (frequency < 0.3f) {
                band_gain = effect->bands[2]; // 125Hz
            } else if (frequency < 0.4f) {
                band_gain = effect->bands[3]; // 250Hz
            } else if (frequency < 0.5f) {
                band_gain = effect->bands[4]; // 500Hz
            } else if (frequency < 0.6f) {
                band_gain = effect->bands[5]; // 1kHz
            } else if (frequency < 0.7f) {
                band_gain = effect->bands[6]; // 2kHz
            } else if (frequency < 0.8f) {
                band_gain = effect->bands[7]; // 4kHz
            } else if (frequency < 0.9f) {
                band_gain = effect->bands[8]; // 8kHz
            } else {
                band_gain = effect->bands[9]; // 16kHz
            }
            
            sample *= powf(10.0f, band_gain / 20.0f);
        }
    }
    
    return AudioRenderErrorNone;
}

// MARK: - Compressor Effect

AudioRenderErrorCode audio_render_apply_compressor(
    uint8_t* data,
    uint64_t frame_count,
    const audio_metadata_t* metadata,
    const audio_effect_params_t* effect
) {
    if (metadata->sample_format != AudioRenderSampleFormatF32) {
        return AudioRenderErrorInvalidParameters;
    }
    
    float* samples = reinterpret_cast<float*>(data);
    uint32_t channels = metadata->channels;
    uint64_t total_samples = frame_count * channels;
    
    // Compressor state per channel
    std::vector<float> envelope(channels, 0.0f);
    std::vector<float> gain_reduction(channels, 0.0f);
    
    float sample_rate = static_cast<float>(metadata->sample_rate);
    float attack_coeff = expf(-1.0f / (effect->attack_time * 0.001f * sample_rate));
    float release_coeff = expf(-1.0f / (effect->release_time * 0.001f * sample_rate));
    
    for (uint64_t i = 0; i < total_samples; ++i) {
        uint32_t ch = i % channels;
        float& sample = samples[i];
        
        // Calculate input level in dB
        float input_level = 20.0f * log10f(fabsf(sample) + 1e-10f);
        
        // Update envelope
        float target_envelope = (input_level > effect->threshold) ? input_level : effect->threshold;
        envelope[ch] = envelope[ch] * attack_coeff + target_envelope * (1.0f - attack_coeff);
        
        // Calculate gain reduction
        if (envelope[ch] > effect->threshold) {
            float over_threshold = envelope[ch] - effect->threshold;
            gain_reduction[ch] = over_threshold * (1.0f - 1.0f / effect->ratio);
        } else {
            gain_reduction[ch] = gain_reduction[ch] * release_coeff;
        }
        
        // Apply gain reduction
        float gain_linear = powf(10.0f, -gain_reduction[ch] / 20.0f);
        sample *= gain_linear * effect->gain;
    }
    
    return AudioRenderErrorNone;
}

// MARK: - Delay Effect

AudioRenderErrorCode audio_render_apply_delay(
    uint8_t* data,
    uint64_t frame_count,
    const audio_metadata_t* metadata,
    const audio_effect_params_t* effect
) {
    if (metadata->sample_format != AudioRenderSampleFormatF32) {
        return AudioRenderErrorInvalidParameters;
    }
    
    float* samples = reinterpret_cast<float*>(data);
    uint32_t channels = metadata->channels;
    uint64_t total_samples = frame_count * channels;
    
    // Delay lines per channel
    std::vector<std::vector<float>> delay_lines(channels);
    std::vector<uint32_t> delay_indices(channels, 0);
    
    // Initialize delay lines
    for (uint32_t ch = 0; ch < channels; ++ch) {
        uint32_t delay_samples = static_cast<uint32_t>(
            effect->delay_time * 0.001f * metadata->sample_rate
        );
        delay_lines[ch].resize(delay_samples, 0.0f);
    }
    
    // Apply delay
    for (uint64_t i = 0; i < total_samples; ++i) {
        uint32_t ch = i % channels;
        float& sample = samples[i];
        
        // Read from delay line
        float delayed = delay_lines[ch][delay_indices[ch]];
        
        // Write to delay line (with feedback)
        delay_lines[ch][delay_indices[ch]] = sample + delayed * effect->feedback;
        
        // Mix original and delayed signals
        sample = sample * effect->dry_level + delayed * effect->wet_level * effect->gain;
        
        // Advance delay index
        delay_indices[ch] = (delay_indices[ch] + 1) % delay_lines[ch].size();
    }
    
    return AudioRenderErrorNone;
}

// MARK: - Waveform Generation

audio_waveform_t* audio_render_generate_waveform(
    const uint8_t* data,
    uint64_t frame_count,
    const audio_metadata_t* metadata,
    uint32_t width,
    uint32_t height
) {
    if (!data || !metadata || frame_count == 0 || width == 0 || height == 0) {
        set_last_error("Invalid parameters");
        return nullptr;
    }
    
    if (metadata->sample_format != AudioRenderSampleFormatF32) {
        set_last_error("Only float32 samples supported");
        return nullptr;
    }
    
    // Allocate waveform structure
    audio_waveform_t* waveform = static_cast<audio_waveform_t*>(malloc(sizeof(audio_waveform_t)));
    if (!waveform) {
        set_last_error("Failed to allocate waveform structure");
        return nullptr;
    }
    
    waveform->width = width;
    waveform->height = height;
    waveform->channels = metadata->channels;
    
    // Allocate arrays for peaks and RMS
    size_t array_size = width * metadata->channels;
    waveform->peaks = static_cast<float*>(malloc(array_size * sizeof(float)));
    waveform->rms = static_cast<float*>(malloc(array_size * sizeof(float)));
    
    if (!waveform->peaks || !waveform->rms) {
        audio_render_free_waveform(waveform);
        set_last_error("Failed to allocate waveform arrays");
        return nullptr;
    }
    
    // Initialize arrays
    memset(waveform->peaks, 0, array_size * sizeof(float));
    memset(waveform->rms, 0, array_size * sizeof(float));
    
    const float* samples = reinterpret_cast<const float*>(data);
    uint64_t total_samples = frame_count * metadata->channels;
    
    // Calculate samples per pixel
    uint64_t samples_per_pixel = total_samples / (width * metadata->channels);
    if (samples_per_pixel == 0) samples_per_pixel = 1;
    
    // Generate waveform data
    for (uint32_t x = 0; x < width; ++x) {
        for (uint32_t ch = 0; ch < metadata->channels; ++ch) {
            uint64_t start_sample = (x * samples_per_pixel * metadata->channels) + ch;
            uint64_t end_sample = std::min(start_sample + samples_per_pixel * metadata->channels, total_samples);
            
            float peak = 0.0f;
            float sum_squares = 0.0f;
            uint64_t sample_count = 0;
            
            for (uint64_t i = start_sample; i < end_sample; i += metadata->channels) {
                float sample = fabsf(samples[i]);
                peak = std::max(peak, sample);
                sum_squares += sample * sample;
                sample_count++;
            }
            
            float rms = sample_count > 0 ? sqrtf(sum_squares / sample_count) : 0.0f;
            
            waveform->peaks[x * metadata->channels + ch] = peak;
            waveform->rms[x * metadata->channels + ch] = rms;
        }
    }
    
    return waveform;
}

void audio_render_free_waveform(audio_waveform_t* waveform) {
    if (waveform) {
        if (waveform->peaks) free(waveform->peaks);
        if (waveform->rms) free(waveform->rms);
        free(waveform);
    }
}

// MARK: - Utility Functions

AudioRenderErrorCode audio_render_convert_sample_format(
    const uint8_t* input_data,
    uint8_t* output_data,
    uint64_t frame_count,
    uint32_t channels,
    AudioRenderSampleFormat input_format,
    AudioRenderSampleFormat output_format
) {
    if (!input_data || !output_data || frame_count == 0 || channels == 0) {
        return AudioRenderErrorInvalidParameters;
    }
    
    if (input_format == output_format) {
        // No conversion needed, just copy
        uint64_t total_samples = frame_count * channels;
        size_t sample_size = 0;
        
        switch (input_format) {
            case AudioRenderSampleFormatU8: sample_size = 1; break;
            case AudioRenderSampleFormatS16: sample_size = 2; break;
            case AudioRenderSampleFormatS32: sample_size = 4; break;
            case AudioRenderSampleFormatF32: sample_size = 4; break;
            case AudioRenderSampleFormatF64: sample_size = 8; break;
        }
        
        memcpy(output_data, input_data, total_samples * sample_size);
        return AudioRenderErrorNone;
    }
    
    // Sample format conversion would be implemented here
    // For now, return unsupported
    set_last_error("Sample format conversion not implemented");
    return AudioRenderErrorInvalidParameters;
}

AudioRenderErrorCode audio_render_resample(
    const uint8_t* input_data,
    uint8_t* output_data,
    uint64_t input_frame_count,
    uint32_t input_sample_rate,
    uint32_t output_sample_rate,
    uint32_t channels,
    AudioRenderSampleFormat format
) {
    if (!input_data || !output_data || input_frame_count == 0 || channels == 0) {
        return AudioRenderErrorInvalidParameters;
    }
    
    if (input_sample_rate == output_sample_rate) {
        // No resampling needed, just copy
        size_t sample_size = 0;
        switch (format) {
            case AudioRenderSampleFormatU8: sample_size = 1; break;
            case AudioRenderSampleFormatS16: sample_size = 2; break;
            case AudioRenderSampleFormatS32: sample_size = 4; break;
            case AudioRenderSampleFormatF32: sample_size = 4; break;
            case AudioRenderSampleFormatF64: sample_size = 8; break;
        }
        
        memcpy(output_data, input_data, input_frame_count * channels * sample_size);
        return AudioRenderErrorNone;
    }
    
    // Resampling would be implemented here using proper interpolation
    // For now, return unsupported
    set_last_error("Resampling not implemented");
    return AudioRenderErrorInvalidParameters;
}

const char* audio_render_get_last_error(void) {
    return g_last_error.c_str();
}