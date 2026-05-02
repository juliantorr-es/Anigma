#ifndef AudioRenderCapsule_h
#define AudioRenderCapsule_h

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// MARK: - Error Codes
typedef enum {
    AudioRenderErrorNone = 0,
    AudioRenderErrorNullPointer = -1,
    AudioRenderErrorInvalidData = -2,
    AudioRenderErrorUnsupportedFormat = -3,
    AudioRenderErrorDecodeFailed = -4,
    AudioRenderErrorMemoryAllocation = -5,
    AudioRenderErrorInvalidParameters = -6,
    AudioRenderErrorEffectFailed = -7,
    AudioRenderErrorWaveformFailed = -8
} AudioRenderErrorCode;

// MARK: - Audio Formats
typedef enum {
    AudioRenderFormatUnknown = 0,
    AudioRenderFormatMP3 = 1,
    AudioRenderFormatWAV = 2,
    AudioRenderFormatFLAC = 3,
    AudioRenderFormatAAC = 4,
    AudioRenderFormatOGG = 5
} AudioRenderFormat;

// MARK: - Sample Formats
typedef enum {
    AudioRenderSampleFormatU8 = 0,
    AudioRenderSampleFormatS16 = 1,
    AudioRenderSampleFormatS32 = 2,
    AudioRenderSampleFormatF32 = 3,
    AudioRenderSampleFormatF64 = 4
} AudioRenderSampleFormat;

// MARK: - Audio Effect Types
typedef enum {
    AudioRenderEffectNone = 0,
    AudioRenderEffectReverb = 1,
    AudioRenderEffectEqualizer = 2,
    AudioRenderEffectCompressor = 3,
    AudioRenderEffectDelay = 4
} AudioRenderEffectType;

// MARK: - Audio Metadata
typedef struct {
    uint32_t sample_rate;
    uint32_t channels;
    uint32_t duration_ms;
    uint32_t bit_rate;
    AudioRenderFormat format;
    AudioRenderSampleFormat sample_format;
    uint64_t frame_count;
    char title[256];
    char artist[256];
    char album[256];
} audio_metadata_t;

// MARK: - Effect Parameters
typedef struct {
    AudioRenderEffectType type;
    float room_size;        // Reverb: 0.0 to 1.0
    float damping;         // Reverb: 0.0 to 1.0
    float wet_level;        // Reverb: 0.0 to 1.0
    float dry_level;        // Reverb: 0.0 to 1.0
    float gain;            // General: gain multiplier
    float bands[10];       // Equalizer: 10-band EQ values in dB
    float threshold;       // Compressor: threshold in dB
    float ratio;          // Compressor: compression ratio
    float attack_time;    // Compressor: attack time in ms
    float release_time;   // Compressor: release time in ms
    float delay_time;     // Delay: delay time in ms
    float feedback;       // Delay: feedback amount 0.0 to 1.0
} audio_effect_params_t;

// MARK: - Waveform Data
typedef struct {
    uint32_t width;        // Waveform width in pixels
    uint32_t height;       // Waveform height in pixels
    uint32_t channels;     // Number of channels
    float* peaks;         // Peak values per channel per pixel
    float* rms;           // RMS values per channel per pixel
} audio_waveform_t;

// MARK: - Core Functions

/// Get library version
const char* audio_render_get_version(void);

/// Initialize audio renderer
AudioRenderErrorCode audio_render_initialize(void);

/// Cleanup audio renderer
void audio_render_cleanup(void);

// MARK: - Decoding Functions

/// Decode audio data from memory
/// @param data Input audio data
/// @param size Size of input data
/// @param metadata Output metadata (filled on success)
/// @return Pointer to decoded audio data, NULL on failure
uint8_t* audio_render_decode(const uint8_t* data, uint64_t size, audio_metadata_t* metadata);

/// Decode MP3 audio
uint8_t* audio_render_decode_mp3(const uint8_t* data, uint64_t size, audio_metadata_t* metadata);

/// Decode WAV audio
uint8_t* audio_render_decode_wav(const uint8_t* data, uint64_t size, audio_metadata_t* metadata);

/// Decode FLAC audio
uint8_t* audio_render_decode_flac(const uint8_t* data, uint64_t size, audio_metadata_t* metadata);

/// Decode AAC audio
uint8_t* audio_render_decode_aac(const uint8_t* data, uint64_t size, audio_metadata_t* metadata);

/// Free decoded audio data
void audio_render_free_data(uint8_t* data);

// MARK: - Audio Effects

/// Apply audio effect to decoded data
/// @param data Audio data (modified in-place)
/// @param frame_count Number of audio frames
/// @param metadata Audio metadata
/// @param effect Effect parameters
/// @return Error code
AudioRenderErrorCode audio_render_apply_effect(
    uint8_t* data,
    uint64_t frame_count,
    const audio_metadata_t* metadata,
    const audio_effect_params_t* effect
);

/// Apply reverb effect
AudioRenderErrorCode audio_render_apply_reverb(
    uint8_t* data,
    uint64_t frame_count,
    const audio_metadata_t* metadata,
    const audio_effect_params_t* effect
);

/// Apply equalizer effect
AudioRenderErrorCode audio_render_apply_equalizer(
    uint8_t* data,
    uint64_t frame_count,
    const audio_metadata_t* metadata,
    const audio_effect_params_t* effect
);

/// Apply compressor effect
AudioRenderErrorCode audio_render_apply_compressor(
    uint8_t* data,
    uint64_t frame_count,
    const audio_metadata_t* metadata,
    const audio_effect_params_t* effect
);

/// Apply delay effect
AudioRenderErrorCode audio_render_apply_delay(
    uint8_t* data,
    uint64_t frame_count,
    const audio_metadata_t* metadata,
    const audio_effect_params_t* effect
);

// MARK: - Waveform Generation

/// Generate waveform visualization data
/// @param data Audio data
/// @param frame_count Number of frames
/// @param metadata Audio metadata
/// @param width Waveform width in pixels
/// @param height Waveform height in pixels
/// @return Waveform data, NULL on failure
audio_waveform_t* audio_render_generate_waveform(
    const uint8_t* data,
    uint64_t frame_count,
    const audio_metadata_t* metadata,
    uint32_t width,
    uint32_t height
);

/// Free waveform data
void audio_render_free_waveform(audio_waveform_t* waveform);

// MARK: - Utility Functions

/// Detect audio format from data
AudioRenderFormat audio_render_detect_format(const uint8_t* data, uint64_t size);

/// Convert sample format
AudioRenderErrorCode audio_render_convert_sample_format(
    const uint8_t* input_data,
    uint8_t* output_data,
    uint64_t frame_count,
    uint32_t channels,
    AudioRenderSampleFormat input_format,
    AudioRenderSampleFormat output_format
);

/// Resample audio data
AudioRenderErrorCode audio_render_resample(
    const uint8_t* input_data,
    uint8_t* output_data,
    uint64_t input_frame_count,
    uint32_t input_sample_rate,
    uint32_t output_sample_rate,
    uint32_t channels,
    AudioRenderSampleFormat format
);

/// Get last error message
const char* audio_render_get_last_error(void);

#ifdef __cplusplus
}
#endif

#endif // AudioRenderCapsule_h