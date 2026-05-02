#include "anigma_text_pipeline_capsule.h"
#include <cstring>
#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <vector>
#include <string>
#include <stdexcept>

struct TextPipelineContext {
    anigma_text_pipeline_config_v2_t config;

    explicit TextPipelineContext(const anigma_text_pipeline_config_v2_t& cfg) : config(cfg) {}
};

static bool is_valid_utf8(const uint8_t* data, size_t length) {
    size_t i = 0;
    while (i < length) {
        uint8_t byte = data[i];
        size_t remaining = 0;

        if ((byte & 0x80) == 0x00) {
            i += 1;
            continue;
        } else if ((byte & 0xE0) == 0xC0) {
            remaining = 1;
            if (byte < 0xC2) {
                return false;
            }
        } else if ((byte & 0xF0) == 0xE0) {
            remaining = 2;
        } else if ((byte & 0xF8) == 0xF0) {
            remaining = 3;
            if (byte > 0xF4) {
                return false;
            }
        } else {
            return false;
        }

        if (i + remaining >= length) {
            return false;
        }

        for (size_t j = 1; j <= remaining; ++j) {
            if ((data[i + j] & 0xC0) != 0x80) {
                return false;
            }
        }

        i += remaining + 1;
    }

    return true;
}

static std::string copy_input(const uint8_t* input_text, size_t input_length) {
    return std::string(reinterpret_cast<const char*>(input_text), input_length);
}

static void apply_case_mode(std::string& text, anigma_case_mode_t case_mode) {
    switch (case_mode) {
        case ANIGMA_CASE_LOWER:
        case ANIGMA_CASE_FOLD:
            std::transform(text.begin(), text.end(), text.begin(), [](unsigned char c) {
                return static_cast<char>(std::tolower(c));
            });
            break;
        case ANIGMA_CASE_UPPER:
            std::transform(text.begin(), text.end(), text.begin(), [](unsigned char c) {
                return static_cast<char>(std::toupper(c));
            });
            break;
        case ANIGMA_CASE_TITLE: {
            bool capitalize_next = true;
            std::transform(text.begin(), text.end(), text.begin(), [&](unsigned char c) {
                if (std::isspace(c)) {
                    capitalize_next = true;
                    return static_cast<char>(c);
                }
                char out = capitalize_next ? static_cast<char>(std::toupper(c))
                                           : static_cast<char>(std::tolower(c));
                capitalize_next = false;
                return out;
            });
            break;
        }
        case ANIGMA_CASE_NONE:
        default:
            break;
    }
}

static std::vector<anigma_text_boundary_t> compute_boundaries(const std::string& text) {
    std::vector<anigma_text_boundary_t> boundaries;
    boundaries.reserve(text.size());

    for (size_t i = 0; i < text.size(); ) {
        uint8_t byte = static_cast<uint8_t>(text[i]);
        size_t char_len = 1;

        if ((byte & 0x80) == 0x00) {
            char_len = 1;
        } else if ((byte & 0xE0) == 0xC0) {
            char_len = 2;
        } else if ((byte & 0xF0) == 0xE0) {
            char_len = 3;
        } else if ((byte & 0xF8) == 0xF0) {
            char_len = 4;
        }

        if (i + char_len > text.size()) {
            char_len = 1;
        }

        anigma_text_boundary_t boundary;
        boundary.type = ANIGMA_BOUNDARY_GRAPHEME;
        boundary.offset = static_cast<uint64_t>(i);
        boundary.length = static_cast<uint64_t>(char_len);
        boundary.confidence = 60;
        boundaries.push_back(boundary);
        i += char_len;
    }

    return boundaries;
}

static anigma_status_t allocate_output_buffer(
    const std::string& text,
    anigma_capsule_buffer_t* output_buffer
) {
    auto* result_buf = static_cast<uint8_t*>(std::malloc(text.size() + 1));
    if (!result_buf) {
        return ANIGMA_ERR_INTERNAL;
    }

    std::memcpy(result_buf, text.data(), text.size());
    result_buf[text.size()] = '\0';
    output_buffer->ptr = result_buf;
    output_buffer->len = text.size();
    output_buffer->cap = text.size() + 1;
    return ANIGMA_OK;
}

extern "C" {

anigma_capsule_identity_t anigma_text_pipeline_capsule_get_identity(void) {
    anigma_capsule_identity_t id;
    id.capsule_id = "text_pipeline_capsule";
    id.build_hash = "dev_hash";
    id.algo_version = "1.1.1";
    id.determinism_tier = ANIGMA_DETERMINISM_TIER_1_RECEIPT_GRADE;
    return id;
}

anigma_text_pipeline_config_v2_t anigma_text_pipeline_capsule_get_default_config(void) {
    anigma_text_pipeline_config_v2_t config;
    config.unicode_form = ANIGMA_UNICODE_NFKC;
    config.case_mode = ANIGMA_CASE_FOLD;
    config.diacritic_mode = ANIGMA_DIACRITICS_KEEP;
    config.preserve_whitespace = 1;
    config.preserve_line_breaks = 1;
    config.determinism_tier = 1;
    return config;
}

anigma_status_t anigma_text_pipeline_capsule_validate_config(const anigma_text_pipeline_config_v2_t* config, anigma_capsule_error_t* err) {
    if (!config) return ANIGMA_ERR_INVALID_ARG;
    return ANIGMA_OK;
}

anigma_status_t anigma_text_pipeline_capsule_create(const anigma_text_pipeline_config_v2_t* config, anigma_text_pipeline_capsule_t* capsule, anigma_capsule_error_t* err) {
    if (!capsule || !config) return ANIGMA_ERR_INVALID_ARG;
    try {
        TextPipelineContext* ctx = new TextPipelineContext(*config);
        *capsule = (anigma_text_pipeline_capsule_t)ctx;
        return ANIGMA_OK;
    } catch (const std::exception& e) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to create TextPipelineContext";
            err->detail = NULL;
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

anigma_status_t anigma_text_pipeline_capsule_destroy(anigma_text_pipeline_capsule_t capsule, anigma_capsule_error_t* err) {
    if (!capsule) return ANIGMA_ERR_INVALID_ARG;
    delete (TextPipelineContext*)capsule;
    return ANIGMA_OK;
}

anigma_status_t anigma_text_pipeline_capsule_normalize_unicode(anigma_text_pipeline_capsule_t capsule, const uint8_t* input_text, size_t input_length, anigma_unicode_form_t form, anigma_capsule_buffer_t* output_buffer, anigma_capsule_error_t* err) {
    if (!capsule || !input_text || !output_buffer) return ANIGMA_ERR_INVALID_ARG;

    switch (form) {
        case ANIGMA_UNICODE_NONE:
        case ANIGMA_UNICODE_NFC:
        case ANIGMA_UNICODE_NFD:
        case ANIGMA_UNICODE_NFKC:
        case ANIGMA_UNICODE_NFKD:
        case ANIGMA_UNICODE_UNC:
            break;
        default:
            return ANIGMA_ERR_NOT_IMPLEMENTED;
    }

    if (!is_valid_utf8(input_text, input_length)) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    std::string normalized = copy_input(input_text, input_length);
    return allocate_output_buffer(normalized, output_buffer);
}

anigma_status_t anigma_text_pipeline_capsule_transform(anigma_text_pipeline_capsule_t capsule, const uint8_t* input_text, size_t input_length, anigma_text_result_v2_t* result, anigma_capsule_error_t* err) {
    if (!capsule || !input_text || !result) return ANIGMA_ERR_INVALID_ARG;
    TextPipelineContext* ctx = (TextPipelineContext*)capsule;
    if (!is_valid_utf8(input_text, input_length)) {
        return ANIGMA_ERR_INVALID_ARG;
    }

    std::string transformed = copy_input(input_text, input_length);
    apply_case_mode(transformed, ctx->config.case_mode);
    auto boundaries = compute_boundaries(transformed);

    auto* final_utf8 = static_cast<uint8_t*>(std::malloc(transformed.size() + 1));
    if (!final_utf8) {
        return ANIGMA_ERR_INTERNAL;
    }
    std::memcpy(final_utf8, transformed.data(), transformed.size());
    final_utf8[transformed.size()] = '\0';

    auto* boundary_buffer = static_cast<anigma_text_boundary_t*>(
        std::malloc(boundaries.size() * sizeof(anigma_text_boundary_t))
    );
    if (!boundary_buffer && !boundaries.empty()) {
        std::free(final_utf8);
        return ANIGMA_ERR_INTERNAL;
    }

    if (!boundaries.empty()) {
        std::memcpy(
            boundary_buffer,
            boundaries.data(),
            boundaries.size() * sizeof(anigma_text_boundary_t)
        );
    }

    result->transformed_text = final_utf8;
    result->transformed_length = transformed.size();
    result->offset_map = nullptr;
    result->offset_map_length = 0;
    result->boundary_count = boundaries.size();
    result->boundaries = boundary_buffer;
    result->operation_hash = 0;
    result->processing_time_us = 0;

    return ANIGMA_OK;
}

anigma_status_t anigma_text_pipeline_capsule_validate_utf8(anigma_text_pipeline_capsule_t capsule, const uint8_t* input_text, size_t input_length, uint8_t* is_valid, anigma_capsule_error_t* err) {
    if (!input_text || !is_valid) return ANIGMA_ERR_INVALID_ARG;
    *is_valid = is_valid_utf8(input_text, input_length) ? 1 : 0;
    return ANIGMA_OK;
}

} // extern "C"
