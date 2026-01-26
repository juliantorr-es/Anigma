#include "anigma_text_pipeline_capsule.h"
#include <cstring>
#include <algorithm>
#include <vector>
#include <string>
#include <stdexcept>

#include <unicode/utypes.h>
#include <unicode/unorm2.h>
#include <unicode/ustring.h>
#include <unicode/brkiter.h>
#include <unicode/casemap.h>
#include <unicode/utext.h>

struct TextPipelineContext {
    anigma_text_pipeline_config_v2_t config;
    const UNormalizer2* nfkc_normalizer;
    
    TextPipelineContext(const anigma_text_pipeline_config_v2_t& cfg) : config(cfg) {
        UErrorCode status = U_ZERO_ERROR;
        nfkc_normalizer = unorm2_getNFKCInstance(&status);
        if (U_FAILURE(status)) {
            throw std::runtime_error("Failed to get NFKC normalizer");
        }
    }
};

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
    
    UErrorCode status = U_ZERO_ERROR;
    const UNormalizer2* normalizer = nullptr;
    
    switch (form) {
        case ANIGMA_UNICODE_NFC: normalizer = unorm2_getNFCInstance(&status); break;
        case ANIGMA_UNICODE_NFD: normalizer = unorm2_getNFDInstance(&status); break;
        case ANIGMA_UNICODE_NFKC: normalizer = unorm2_getNFKCInstance(&status); break;
        case ANIGMA_UNICODE_NFKD: normalizer = unorm2_getNFKDInstance(&status); break;
        default: return ANIGMA_ERR_NOT_IMPLEMENTED;
    }
    
    if (U_FAILURE(status)) return ANIGMA_ERR_INTERNAL;

    std::vector<UChar> utf16_input(input_length + 1);
    int32_t utf16_len = 0;
    u_strFromUTF8(utf16_input.data(), (int32_t)utf16_input.size(), &utf16_len, (const char*)input_text, (int32_t)input_length, &status);
    if (U_FAILURE(status) && status != U_BUFFER_OVERFLOW_ERROR) return ANIGMA_ERR_INTERNAL;
    if (status == U_BUFFER_OVERFLOW_ERROR) {
        status = U_ZERO_ERROR;
        utf16_input.resize(utf16_len + 1);
        u_strFromUTF8(utf16_input.data(), (int32_t)utf16_input.size(), &utf16_len, (const char*)input_text, (int32_t)input_length, &status);
    }

    std::vector<UChar> utf16_output(utf16_len * 2 + 1);
    int32_t norm_len = unorm2_normalize(normalizer, utf16_input.data(), utf16_len, utf16_output.data(), (int32_t)utf16_output.size(), &status);
    if (status == U_BUFFER_OVERFLOW_ERROR) {
        status = U_ZERO_ERROR;
        utf16_output.resize(norm_len + 1);
        unorm2_normalize(normalizer, utf16_input.data(), utf16_len, utf16_output.data(), (int32_t)utf16_output.size(), &status);
    }
    
    if (U_FAILURE(status)) return ANIGMA_ERR_INTERNAL;

    int32_t utf8_len = 0;
    u_strToUTF8(nullptr, 0, &utf8_len, utf16_output.data(), norm_len, &status);
    status = U_ZERO_ERROR;
    
    uint8_t* result_buf = (uint8_t*)malloc(utf8_len + 1);
    u_strToUTF8((char*)result_buf, utf8_len + 1, &utf8_len, utf16_output.data(), norm_len, &status);
    
    if (U_FAILURE(status)) {
        free(result_buf);
        return ANIGMA_ERR_INTERNAL;
    }
    
    output_buffer->ptr = result_buf;
    output_buffer->len = (size_t)utf8_len;
    output_buffer->cap = (size_t)utf8_len + 1;
    return ANIGMA_OK;
}

anigma_status_t anigma_text_pipeline_capsule_transform(anigma_text_pipeline_capsule_t capsule, const uint8_t* input_text, size_t input_length, anigma_text_result_v2_t* result, anigma_capsule_error_t* err) {
    if (!capsule || !input_text || !result) return ANIGMA_ERR_INVALID_ARG;
    TextPipelineContext* ctx = (TextPipelineContext*)capsule;
    UErrorCode status = U_ZERO_ERROR;

    int32_t utf16_len = 0;
    u_strFromUTF8(nullptr, 0, &utf16_len, (const char*)input_text, (int32_t)input_length, &status);
    status = U_ZERO_ERROR;
    std::vector<UChar> utf16_buf(utf16_len + 1);
    u_strFromUTF8(utf16_buf.data(), (int32_t)utf16_buf.size(), &utf16_len, (const char*)input_text, (int32_t)input_length, &status);

    if (ctx->config.case_mode == ANIGMA_CASE_FOLD) {
        int32_t folded_len = u_strFoldCase(nullptr, 0, utf16_buf.data(), utf16_len, U_FOLD_CASE_DEFAULT, &status);
        status = U_ZERO_ERROR;
        std::vector<UChar> folded_buf(folded_len + 1);
        u_strFoldCase(folded_buf.data(), (int32_t)folded_buf.size(), utf16_buf.data(), utf16_len, U_FOLD_CASE_DEFAULT, &status);
        utf16_buf = std::move(folded_buf);
        utf16_len = folded_len;
    }

    int32_t norm_len = unorm2_normalize(ctx->nfkc_normalizer, utf16_buf.data(), utf16_len, nullptr, 0, &status);
    status = U_ZERO_ERROR;
    std::vector<UChar> norm_buf(norm_len + 1);
    unorm2_normalize(ctx->nfkc_normalizer, utf16_buf.data(), utf16_len, norm_buf.data(), (int32_t)norm_buf.size(), &status);
    utf16_buf = std::move(norm_buf);
    utf16_len = norm_len;

    icu::BreakIterator* boundary_iter = icu::BreakIterator::createCharacterInstance(icu::Locale::getDefault(), status);
    if (U_FAILURE(status)) return ANIGMA_ERR_INTERNAL;
    
    UText ut = UTEXT_INITIALIZER;
    utext_openUChars(&ut, utf16_buf.data(), utf16_len, &status);
    boundary_iter->setText(&ut, status);

    std::vector<anigma_text_boundary_t> boundaries;
    int32_t start = boundary_iter->first();
    for (int32_t end = boundary_iter->next(); end != icu::BreakIterator::DONE; start = end, end = boundary_iter->next()) {
        anigma_text_boundary_t b;
        b.type = ANIGMA_BOUNDARY_GRAPHEME;
        b.offset = (uint64_t)start;
        b.length = (uint64_t)(end - start);
        b.confidence = 100;
        boundaries.push_back(b);
    }
    utext_close(&ut);
    delete boundary_iter;

    int32_t utf8_len = 0;
    u_strToUTF8(nullptr, 0, &utf8_len, utf16_buf.data(), utf16_len, &status);
    status = U_ZERO_ERROR;
    uint8_t* final_utf8 = (uint8_t*)malloc(utf8_len + 1);
    u_strToUTF8((char*)final_utf8, utf8_len + 1, &utf8_len, utf16_buf.data(), utf16_len, &status);

    result->transformed_text = final_utf8;
    result->transformed_length = (size_t)utf8_len;
    result->boundary_count = boundaries.size();
    result->boundaries = (anigma_text_boundary_t*)malloc(boundaries.size() * sizeof(anigma_text_boundary_t));
    memcpy(result->boundaries, boundaries.data(), boundaries.size() * sizeof(anigma_text_boundary_t));
    
    return ANIGMA_OK;
}

anigma_status_t anigma_text_pipeline_capsule_validate_utf8(anigma_text_pipeline_capsule_t capsule, const uint8_t* input_text, size_t input_length, uint8_t* is_valid, anigma_capsule_error_t* err) {
    if (!input_text || !is_valid) return ANIGMA_ERR_INVALID_ARG;
    UErrorCode status = U_ZERO_ERROR;
    u_strFromUTF8(nullptr, 0, nullptr, (const char*)input_text, (int32_t)input_length, &status);
    *is_valid = U_SUCCESS(status) || status == U_BUFFER_OVERFLOW_ERROR;
    return ANIGMA_OK;
}

} // extern "C"
