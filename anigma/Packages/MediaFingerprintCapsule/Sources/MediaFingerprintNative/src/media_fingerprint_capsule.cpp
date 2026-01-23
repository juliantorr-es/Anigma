#include "MediaFingerprintCapsule/media_fingerprint_capsule.h"
#include "../../include/anigma_capsule_core.h"
#include <cstring>
#include <cstdlib>
#include <new>

// Internal capsule structure
typedef struct {
    anigma_image_fingerprint_config_t image_config;
    anigma_audio_fingerprint_config_t audio_config;
    anigma_video_fingerprint_config_t video_config;
    bool initialized;
} media_fingerprint_capsule_impl_t;

// Helper function to set error
static void set_error(anigma_capsule_error_t* err, anigma_status_t code, const char* message) {
    if (err) {
        err->code = code;
        err->message = message;
        err->detail = nullptr;
        err->aux = 0;
    }
}

// External function declarations for the specific fingerprint functions
extern "C" {
    anigma_status_t anigma_media_fingerprint_analyze_image_buffer(
        const anigma_capsule_buffer_t* input_buffer,
        const anigma_image_fingerprint_config_t* config,
        anigma_fingerprint_result_t* result,
        anigma_capsule_error_t* error
    );
    
    anigma_status_t anigma_media_fingerprint_analyze_audio_buffer(
        const anigma_capsule_buffer_t* input_buffer,
        const anigma_audio_fingerprint_config_t* config,
        anigma_fingerprint_result_t* result,
        anigma_capsule_error_t* error
    );
    
    anigma_status_t anigma_media_fingerprint_analyze_video_buffer(
        const anigma_capsule_buffer_t* input_buffer,
        const anigma_video_fingerprint_config_t* config,
        anigma_fingerprint_result_t* result,
        anigma_capsule_error_t* error
    );
    
    anigma_status_t anigma_media_fingerprint_generate_image_hash(
        const anigma_fingerprint_result_t* fingerprint1,
        const anigma_fingerprint_result_t* fingerprint2,
        anigma_similarity_result_t* result,
        anigma_capsule_error_t* error
    );
    
    anigma_status_t anigma_media_fingerprint_generate_audio_hash(
        const anigma_fingerprint_result_t* fingerprint1,
        const anigma_fingerprint_result_t* fingerprint2,
        anigma_similarity_result_t* result,
        anigma_capsule_error_t* error
    );
    
    anigma_status_t anigma_media_fingerprint_generate_video_hash(
        const anigma_fingerprint_result_t* fingerprint1,
        const anigma_fingerprint_result_t* fingerprint2,
        anigma_similarity_result_t* result,
        anigma_capsule_error_t* error
    );
}

// Default configuration functions
anigma_image_fingerprint_config_t anigma_media_fingerprint_get_default_image_config(void) {
    return anigma_image_fingerprint_config_t{
        .hash_size = 8,
        .resize_width = 64,
        .resize_height = 64,
        .high_frequency_boost = false,
        .determinism_tier = ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
    };
}

anigma_audio_fingerprint_config_t anigma_media_fingerprint_get_default_audio_config(void) {
    return anigma_audio_fingerprint_config_t{
        .sample_rate = 44100,
        .window_size = 1024,
        .hop_size = 512,
        .num_coefficients = 13,
        .fingerprint_size = 32,
        .determinism_tier = ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
    };
}

anigma_video_fingerprint_config_t anigma_media_fingerprint_get_default_video_config(void) {
    return anigma_video_fingerprint_config_t{
        .frame_sample_rate = 1,
        .keyframe_interval = 30,
        .motion_threshold = 10,
        .fingerprint_size = 64,
        .determinism_tier = ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
    };
}

anigma_similarity_config_t anigma_media_fingerprint_get_default_similarity_config(void) {
    return anigma_similarity_config_t{
        .similarity_threshold = 0.85,
        .use_hamming_distance = true,
        .enable_partial_matching = false,
        .partial_match_threshold = 0.7
    };
}

// Capsule identity
anigma_capsule_identity_t anigma_media_fingerprint_capsule_get_identity(void) {
    static const char* build_hash = "media_fingerprint_v1_0_0";
    static const char* algo_version = "1.0.0";
    
    return anigma_capsule_identity_t{
        .capsule_id = "media_fingerprint_capsule",
        .build_hash = build_hash,
        .algo_version = algo_version,
        .determinism_tier = ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE
    };
}

// Capsule management functions
anigma_status_t anigma_media_fingerprint_capsule_create(
    const anigma_image_fingerprint_config_t* image_config,
    const anigma_audio_fingerprint_config_t* audio_config,
    const anigma_video_fingerprint_config_t* video_config,
    anigma_media_fingerprint_capsule_t* capsule,
    anigma_capsule_error_t* error
) {
    if (!capsule) {
        set_error(error, ANIGMA_ERR_INVALID_ARG, "Capsule output pointer is null");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* impl = new(std::nothrow) media_fingerprint_capsule_impl_t();
    if (!impl) {
        set_error(error, ANIGMA_ERR_INTERNAL, "Failed to allocate capsule memory");
        return ANIGMA_ERR_INTERNAL;
    }
    
    // Use provided configs or defaults
    impl->image_config = image_config ? *image_config : anigma_media_fingerprint_get_default_image_config();
    impl->audio_config = audio_config ? *audio_config : anigma_media_fingerprint_get_default_audio_config();
    impl->video_config = video_config ? *video_config : anigma_media_fingerprint_get_default_video_config();
    impl->initialized = true;
    
    *capsule = impl;
    return ANIGMA_OK;
}

anigma_status_t anigma_media_fingerprint_capsule_destroy(
    anigma_media_fingerprint_capsule_t capsule,
    anigma_capsule_error_t* error
) {
    if (!capsule) {
        set_error(error, ANIGMA_ERR_INVALID_ARG, "Capsule handle is null");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* impl = static_cast<media_fingerprint_capsule_impl_t*>(capsule);
    delete impl;
    return ANIGMA_OK;
}

anigma_status_t anigma_media_fingerprint_capsule_reset(
    anigma_media_fingerprint_capsule_t capsule,
    anigma_capsule_error_t* error
) {
    if (!capsule) {
        set_error(error, ANIGMA_ERR_INVALID_ARG, "Capsule handle is null");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* impl = static_cast<media_fingerprint_capsule_impl_t*>(capsule);
    if (!impl->initialized) {
        set_error(error, ANIGMA_ERR_NOT_INITIALIZED, "Capsule not initialized");
        return ANIGMA_ERR_NOT_INITIALIZED;
    }
    
    // Reset to default configs
    impl->image_config = anigma_media_fingerprint_get_default_image_config();
    impl->audio_config = anigma_media_fingerprint_get_default_audio_config();
    impl->video_config = anigma_media_fingerprint_get_default_video_config();
    
    return ANIGMA_OK;
}

// Media analysis functions
anigma_status_t anigma_media_fingerprint_generate_image(
    anigma_media_fingerprint_capsule_t capsule,
    const anigma_capsule_buffer_t* input_buffer,
    anigma_fingerprint_algorithm_t algorithm,
    anigma_fingerprint_result_t* result,
    anigma_capsule_error_t* error
) {
    if (!capsule || !input_buffer || !result) {
        set_error(error, ANIGMA_ERR_INVALID_ARG, "Invalid arguments");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* impl = static_cast<media_fingerprint_capsule_impl_t*>(capsule);
    return anigma_media_fingerprint_analyze_image_buffer(input_buffer, &impl->image_config, result, error);
}

anigma_status_t anigma_media_fingerprint_generate_audio(
    anigma_media_fingerprint_capsule_t capsule,
    const anigma_capsule_buffer_t* input_buffer,
    anigma_fingerprint_algorithm_t algorithm,
    anigma_fingerprint_result_t* result,
    anigma_capsule_error_t* error
) {
    if (!capsule || !input_buffer || !result) {
        set_error(error, ANIGMA_ERR_INVALID_ARG, "Invalid arguments");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* impl = static_cast<media_fingerprint_capsule_impl_t*>(capsule);
    return anigma_media_fingerprint_analyze_audio_buffer(input_buffer, &impl->audio_config, result, error);
}

anigma_status_t anigma_media_fingerprint_generate_video(
    anigma_media_fingerprint_capsule_t capsule,
    const anigma_capsule_buffer_t* input_buffer,
    anigma_fingerprint_algorithm_t algorithm,
    anigma_fingerprint_result_t* result,
    anigma_capsule_error_t* error
) {
    if (!capsule || !input_buffer || !result) {
        set_error(error, ANIGMA_ERR_INVALID_ARG, "Invalid arguments");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    auto* impl = static_cast<media_fingerprint_capsule_impl_t*>(capsule);
    return anigma_media_fingerprint_analyze_video_buffer(input_buffer, &impl->video_config, result, error);
}

// Similarity computation functions
anigma_status_t anigma_media_fingerprint_compare(
    anigma_media_fingerprint_capsule_t capsule,
    const anigma_fingerprint_result_t* fingerprint1,
    const anigma_fingerprint_result_t* fingerprint2,
    const anigma_similarity_config_t* config,
    anigma_similarity_result_t* result,
    anigma_capsule_error_t* error
) {
    if (!capsule || !fingerprint1 || !fingerprint2 || !result) {
        set_error(error, ANIGMA_ERR_INVALID_ARG, "Invalid arguments");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    // Use default similarity config if none provided
    anigma_similarity_config_t default_config = anigma_media_fingerprint_get_default_similarity_config();
    const anigma_similarity_config_t* similarity_config = config ? config : &default_config;
    
    // Dispatch based on fingerprint type
    switch (fingerprint1->algorithm) {
        case ANIGMA_FINGERPRINT_AVERAGE_HASH:
        case ANIGMA_FINGERPRINT_DIFFERENCE_HASH:
        case ANIGMA_FINGERPRINT_WAVELET_HASH:
        case ANIGMA_FINGERPRINT_PERCEPTUAL_HASH:
            return anigma_media_fingerprint_generate_image_hash(fingerprint1, fingerprint2, result, error);
            
        case ANIGMA_FINGERPRINT_CHROMAPRINT:
            return anigma_media_fingerprint_generate_audio_hash(fingerprint1, fingerprint2, result, error);
            
        case ANIGMA_FINGERPRINT_MOTION_VECTOR:
            return anigma_media_fingerprint_generate_video_hash(fingerprint1, fingerprint2, result, error);
            
        default:
            set_error(error, ANIGMA_ERR_INVALID_ARG, "Unsupported fingerprint algorithm");
            return ANIGMA_ERR_INVALID_ARG;
    }
}

anigma_status_t anigma_media_fingerprint_batch_compare(
    anigma_media_fingerprint_capsule_t capsule,
    const anigma_fingerprint_result_t* query_fingerprint,
    const anigma_fingerprint_result_t* candidate_fingerprints,
    size_t candidate_count,
    const anigma_similarity_config_t* config,
    anigma_similarity_result_t* results,
    size_t* actual_count,
    anigma_capsule_error_t* error
) {
    if (!capsule || !query_fingerprint || !candidate_fingerprints || !results || !actual_count) {
        set_error(error, ANIGMA_ERR_INVALID_ARG, "Invalid arguments");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    // Use default similarity config if none provided
    anigma_similarity_config_t default_config = anigma_media_fingerprint_get_default_similarity_config();
    const anigma_similarity_config_t* similarity_config = config ? config : &default_config;
    
    size_t processed = 0;
    for (size_t i = 0; i < candidate_count; ++i) {
        anigma_status_t status = anigma_media_fingerprint_compare(
            capsule, query_fingerprint, &candidate_fingerprints[i], 
            similarity_config, &results[i], error
        );
        
        if (status != ANIGMA_OK) {
            break;
        }
        processed++;
    }
    
    *actual_count = processed;
    return ANIGMA_OK;
}

// Utility functions
anigma_status_t anigma_media_fingerprint_free_result(
    anigma_fingerprint_result_t* result,
    anigma_capsule_error_t* error
) {
    if (!result) {
        set_error(error, ANIGMA_ERR_INVALID_ARG, "Result pointer is null");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    if (result->hash_data) {
        delete[] result->hash_data;
        result->hash_data = nullptr;
    }
    
    return ANIGMA_OK;
}

anigma_status_t anigma_media_fingerprint_free_results(
    anigma_fingerprint_result_t* results,
    size_t count,
    anigma_capsule_error_t* error
) {
    if (!results && count > 0) {
        set_error(error, ANIGMA_ERR_INVALID_ARG, "Results pointer is null but count > 0");
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    for (size_t i = 0; i < count; ++i) {
        anigma_media_fingerprint_free_result(&results[i], error);
    }
    
    return ANIGMA_OK;
}