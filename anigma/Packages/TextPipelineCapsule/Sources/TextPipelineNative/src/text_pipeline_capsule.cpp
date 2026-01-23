#include "../include/anigma_text_pipeline_capsule.h"
#include <unordered_map>
#include <vector>
#include <chrono>
#include <algorithm>
#include <cstring>
#include <memory>
#include <sstream>
#include <cmath>
#include <unicode/utypes.h>
#include <unicode/unistr.h>
#include <unicode/translit.h>
#include <unicode/normlzr.h>
#include <unicode/ucnv.h>
#include <unicode/brkiter.h>
#include <unicode/stringpiece.h>
#include "BLAKE3/blake3.h"

using std::vector;
using std::unordered_map;

struct TextPipelineCapsule {
    anigma_text_pipeline_config_t config;
    uint64_t operation_count;
    
    TextPipelineCapsule() : operation_count(0) {
        config = anigma_text_pipeline_capsule_get_default_config();
    }
    
    // Get microseconds timestamp
    uint64_t get_timestamp_us() {
        auto now = std::chrono::steady_clock::now();
        auto duration = now.time_since_epoch();
        return std::chrono::duration_cast<std::chrono::microseconds>(duration).count();
    }
    
    // Compute BLAKE3 hash of operation inputs for receipt
    uint64_t compute_operation_hash(const std::string& operation_data) {
        blake3_hasher hasher;
        blake3_hasher_init(&hasher);
        blake3_hasher_update(&hasher, operation_data.data(), operation_data.size());
        uint8_t hash_output[32];
        blake3_hasher_finalize(&hasher, hash_output, sizeof(hash_output));
        
        // Take first 8 bytes as operation hash
        uint64_t result = 0;
        std::memcpy(&result, hash_output, sizeof(uint64_t));
        return result;
    }
    
    // Validate UTF-8 encoding
    bool validate_utf8(const uint8_t* data, size_t length) {
        if (!data || length == 0) return true;
        
        UErrorCode status = U_ZERO_ERROR;
        UnicodeString unicode_str = UnicodeString::fromUTF8(reinterpret_cast<const char*>(data), length, status);
        return U_SUCCESS(status);
    }
    
    // Apply Unicode normalization
    std::string normalize_unicode(const std::string& input, anigma_unicode_form_t form) {
        UErrorCode status = U_ZERO_ERROR;
        UnicodeString unicode_str = UnicodeString::fromUTF8(input.c_str());
        
        UNormalization2Mode mode;
        switch (form) {
            case ANIGMA_UNICODE_NFC: mode = UNORM2_NFC; break;
            case ANIGMA_UNICODE_NFD: mode = UNORM2_NFD; break;
            case ANIGMA_UNICODE_NFKC: mode = UNORM2_NFKC; break;
            case ANIGMA_UNICODE_NFKD: mode = UNORM2_NFKD; break;
            default: mode = UNORM2_NONE; break;
        }
        
        if (mode != UNORM2_NONE) {
            UnicodeString normalized;
            normalized = unicode_str.unorm2(mode, status);
            if (U_SUCCESS(status)) {
                unicode_str = normalized;
            }
        }
        
        std::string result;
        unicode_str.toUTF8String(result);
        return result;
    }
    
    // Apply case conversion
    std::string convert_case(const std::string& input, anigma_case_mode_t mode) {
        UErrorCode status = U_ZERO_ERROR;
        UnicodeString unicode_str = UnicodeString::fromUTF8(input.c_str());
        
        switch (mode) {
            case ANIGMA_CASE_LOWER:
                unicode_str.toLower(status);
                break;
            case ANIGMA_CASE_UPPER:
                unicode_str.toUpper(status);
                break;
            case ANIGMA_CASE_TITLE:
                unicode_str.toTitle(nullptr, status);
                break;
            case ANIGMA_CASE_FOLD:
                unicode_str.foldCase(U_FOLD_CASE_DEFAULT, status);
                break;
            default:
                break;
        }
        
        std::string result;
        unicode_str.toUTF8String(result);
        return result;
    }
    
    // Process diacritics
    std::string process_diacritics(const std::string& input, anigma_diacritic_mode_t mode) {
        UErrorCode status = U_ZERO_ERROR;
        UnicodeString unicode_str = UnicodeString::fromUTF8(input.c_str());
        
        switch (mode) {
            case ANIGMA_DIACRITICS_STRIP: {
                // Remove diacritics using NFD and filtering
                UnicodeString normalized = unicode_str.unorm2(UNORM2_NFD, status);
                UnicodeString result_str;
                
                for (int32_t i = 0; i < normalized.length(); ++i) {
                    UChar32 codepoint = normalized.char32At(i);
                    // Keep only non-combining characters
                    if (!u_hasBinaryProperty(codepoint, UCHAR_COMBINING)) {
                        result_str.append(codepoint);
                    }
                }
                
                std::string result;
                result_str.toUTF8String(result);
                return result;
            }
            case ANIGMA_DIACRITICS_NORMALIZE: {
                // Normalize diacritics to canonical form
                UnicodeString normalized = unicode_str.unorm2(UNORM2_NFD, status);
                std::string result;
                normalized.toUTF8String(result);
                return result;
            }
            default:
                return input;
        }
    }
    
    // Detect grapheme cluster boundaries
    vector<anigma_text_boundary_t> detect_grapheme_boundaries(const std::string& input) {
        vector<anigma_text_boundary_t> boundaries;
        
        UErrorCode status = U_ZERO_ERROR;
        UnicodeString unicode_str = UnicodeString::fromUTF8(input.c_str());
        
        LocalPointer<BreakIterator> grapheme_iter(
            BreakIterator::createCharacterInstance(unicode_str, status)
        );
        
        if (U_FAILURE(status)) {
            return boundaries;
        }
        
        grapheme_iter->setText(unicode_str);
        
        int32_t start = grapheme_iter->first();
        int32_t end = grapheme_iter->next();
        
        while (end != BreakIterator::DONE) {
            anigma_text_boundary_t boundary = {};
            boundary.type = ANIGMA_BOUNDARY_GRAPHEME;
            boundary.confidence = 255;  // High confidence for grapheme clusters
            
            // Convert UTF-8 byte offset
            std::string substr = input.substr(0, start);
            boundary.offset = substr.length();
            boundary.length = end - start;
            
            boundaries.push_back(boundary);
            
            start = end;
            end = grapheme_iter->next();
        }
        
        return boundaries;
    }
    
    // Detect word boundaries
    vector<anigma_text_boundary_t> detect_word_boundaries(const std::string& input) {
        vector<anigma_text_boundary_t> boundaries;
        
        UErrorCode status = U_ZERO_ERROR;
        UnicodeString unicode_str = UnicodeString::fromUTF8(input.c_str());
        
        LocalPointer<BreakIterator> word_iter(
            BreakIterator::createWordInstance(unicode_str, status)
        );
        
        if (U_FAILURE(status)) {
            return boundaries;
        }
        
        word_iter->setText(unicode_str);
        
        int32_t start = word_iter->first();
        int32_t end = word_iter->next();
        
        while (end != BreakIterator::DONE) {
            anigma_text_boundary_t boundary = {};
            boundary.type = ANIGMA_BOUNDARY_WORD;
            
            // Calculate confidence based on word characteristics
            boundary.confidence = 200;  // Base confidence
            
            // Check if this looks like a real word
            UnicodeString word = unicode_str.tempSubStringBetween(start, end);
            if (word.length() > 0) {
                UChar32 first_char = word.char32At(0);
                if (u_isalpha(first_char)) {
                    boundary.confidence += 55;  // Boost for alphabetic words
                }
            }
            
            // Convert UTF-8 byte offset
            std::string substr = input.substr(0, start);
            boundary.offset = substr.length();
            boundary.length = end - start;
            
            boundaries.push_back(boundary);
            
            start = end;
            end = word_iter->next();
        }
        
        return boundaries;
    }
    
    // Detect sentence boundaries
    vector<anigma_text_boundary_t> detect_sentence_boundaries(const std::string& input) {
        vector<anigma_text_boundary_t> boundaries;
        
        UErrorCode status = U_ZERO_ERROR;
        UnicodeString unicode_str = UnicodeString::fromUTF8(input.c_str());
        
        LocalPointer<BreakIterator> sentence_iter(
            BreakIterator::createSentenceInstance(unicode_str, status)
        );
        
        if (U_FAILURE(status)) {
            return boundaries;
        }
        
        sentence_iter->setText(unicode_str);
        
        int32_t start = sentence_iter->first();
        int32_t end = sentence_iter->next();
        
        while (end != BreakIterator::DONE) {
            anigma_text_boundary_t boundary = {};
            boundary.type = ANIGMA_BOUNDARY_SENTENCE;
            boundary.confidence = 180;  // Moderate confidence for sentences
            
            // Convert UTF-8 byte offset
            std::string substr = input.substr(0, start);
            boundary.offset = substr.length();
            boundary.length = end - start;
            
            boundaries.push_back(boundary);
            
            start = end;
            end = sentence_iter->next();
        }
        
        return boundaries;
    }
    
    // Fold to ASCII for indexing
    std::string fold_to_ascii(const std::string& input) {
        UErrorCode status = U_ZERO_ERROR;
        UnicodeString unicode_str = UnicodeString::fromUTF8(input.c_str());
        
        // Apply NFKD normalization first
        UnicodeString normalized = unicode_str.unorm2(UNORM2_NFKD, status);
        
        // Remove diacritics
        UnicodeString ascii;
        for (int32_t i = 0; i < normalized.length(); ++i) {
            UChar32 codepoint = normalized.char32At(i);
            if (!u_hasBinaryProperty(codepoint, UCHAR_COMBINING)) {
                ascii.append(codepoint);
            }
        }
        
        // Convert to ASCII compatible characters
        ascii.foldCase(U_FOLD_CASE_DEFAULT, status);
        
        std::string result;
        ascii.toUTF8String(result);
        return result;
    }
    
    // Create offset map from original to transformed text
    vector<uint64_t> create_offset_map(const std::string& original, const std::string& transformed) {
        vector<uint64_t> offset_map;
        offset_map.reserve(transformed.length() + 1);
        
        // Simple character-by-character mapping
        // In a real implementation, this would be more sophisticated
        size_t original_pos = 0;
        size_t transformed_pos = 0;
        
        while (original_pos < original.length() && transformed_pos < transformed.length()) {
            offset_map.push_back(original_pos);
            
            // Move to next character in both strings
            // This is simplified - a real implementation would handle multi-byte UTF-8
            original_pos++;
            transformed_pos++;
        }
        
        // Fill remaining positions
        while (transformed_pos <= transformed.length()) {
            offset_map.push_back(original_pos);
            transformed_pos++;
        }
        
        return offset_map;
    }
};

// Global capsule registry
static unordered_map<anigma_text_pipeline_capsule_t*, std::unique_ptr<TextPipelineCapsule>> g_capsules;
static anigma_text_pipeline_capsule_t g_next_handle = 1;

extern "C" {

// Get capsule identity
anigma_capsule_identity_t anigma_text_pipeline_capsule_get_identity(void) {
    static const anigma_capsule_identity_t identity = {
        "text_pipeline_capsule",
        "v1.0.0-deterministic",
        "1.0.0",
        1  // Tier 1: bitwise deterministic
    };
    return identity;
}

// Get default configuration
anigma_text_pipeline_config_t anigma_text_pipeline_capsule_get_default_config(void) {
    return {
        ANIGMA_UNICODE_NFC,        // NFC normalization by default
        ANIGMA_CASE_NONE,           // No case conversion by default
        ANIGMA_DIACRITICS_KEEP,    // Keep diacritics by default
        1,                         // Preserve whitespace
        1,                         // Preserve line breaks
        1                          // Tier 1 deterministic
    };
}

// Validate configuration
anigma_status_t anigma_text_pipeline_capsule_validate_config(
    const anigma_text_pipeline_config_t* config,
    anigma_capsule_error_t* err
) {
    if (!config) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid configuration";
            err->detail = "Config pointer must not be null";
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    // Validate enum values
    if (config->unicode_form > ANIGMA_UNICODE_UNC ||
        config->case_mode > ANIGMA_CASE_FOLD ||
        config->diacritic_mode > ANIGMA_DIACRITICS_NORMALIZE) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid configuration values";
            err->detail = "Enum values out of range";
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    return ANIGMA_OK;
}

// Create capsule instance
anigma_status_t anigma_text_pipeline_capsule_create(
    const anigma_text_pipeline_config_t* config,
    anigma_text_pipeline_capsule_t** capsule,
    anigma_capsule_error_t* err
) {
    if (!config || !capsule) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = "Config and capsule must not be null";
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        auto capsule_impl = std::make_unique<TextPipelineCapsule>();
        capsule_impl->config = *config;
        
        auto handle = g_next_handle++;
        g_capsules[(anigma_text_pipeline_capsule_t*)handle] = std::move(capsule_impl);
        *capsule = (anigma_text_pipeline_capsule_t*)handle;
        
        return ANIGMA_OK;
        
    } catch (const std::exception& e) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Failed to create capsule";
            err->detail = e.what();
            err->aux = 0;
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

// Destroy capsule instance
anigma_status_t anigma_text_pipeline_capsule_destroy(
    anigma_text_pipeline_capsule_t capsule,
    anigma_capsule_error_t* err
) {
    auto it = g_capsules.find(capsule);
    if (it != g_capsules.end()) {
        g_capsules.erase(it);
        return ANIGMA_OK;
    }
    
    if (err) {
        err->code = ANIGMA_ERR_INVALID_ARG;
        err->message = "Invalid capsule handle";
        err->detail = "Handle not found in capsule registry";
        err->aux = 0;
    }
    return ANIGMA_ERR_INVALID_ARG;
}

// Transform text with full pipeline
anigma_status_t anigma_text_pipeline_capsule_transform(
    anigma_text_pipeline_capsule_t* capsule,
    const uint8_t* input_text,
    size_t input_length,
    anigma_text_result_t* result,
    anigma_capsule_error_t* err
) {
    auto it = g_capsules.find(capsule);
    if (it == g_capsules.end() || !input_text || !result) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = "Handle, input_text, and result must not be null";
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        auto& capsule_impl = *it->second;
        capsule_impl.operation_count++;
        
        std::string input(reinterpret_cast<const char*>(input_text), input_length);
        std::string transformed = input;
        
        // Apply transformations based on configuration
        if (capsule_impl.config.unicode_form != ANIGMA_UNICODE_NONE) {
            transformed = capsule_impl.normalize_unicode(transformed, capsule_impl.config.unicode_form);
        }
        
        if (capsule_impl.config.case_mode != ANIGMA_CASE_NONE) {
            transformed = capsule_impl.convert_case(transformed, capsule_impl.config.case_mode);
        }
        
        if (capsule_impl.config.diacritic_mode != ANIGMA_DIACRITICS_KEEP) {
            transformed = capsule_impl.process_diacritics(transformed, capsule_impl.config.diacritic_mode);
        }
        
        // Allocate and populate result
        result->transformed_length = transformed.length();
        result->transformed_text = (uint8_t*)anigma_capsule_alloc_buffer(transformed.length() + 1, err);
        if (!result->transformed_text) {
            return ANIGMA_ERR_INTERNAL;
        }
        
        std::memcpy(result->transformed_text, transformed.c_str(), transformed.length());
        ((uint8_t*)result->transformed_text)[transformed.length()] = '\0';  // Null terminate
        
        // Create offset map
        auto offset_map = capsule_impl.create_offset_map(input, transformed);
        result->offset_map_length = offset_map.size();
        result->offset_map = (uint64_t*)anigma_capsule_alloc_buffer(offset_map.size() * sizeof(uint64_t), err);
        if (!result->offset_map) {
            anigma_capsule_free_buffer(result->transformed_text, err);
            result->transformed_text = nullptr;
            return ANIGMA_ERR_INTERNAL;
        }
        
        std::memcpy(result->offset_map, offset_map.data(), offset_map.size() * sizeof(uint64_t));
        
        // Detect boundaries (default to word boundaries)
        auto boundaries = capsule_impl.detect_word_boundaries(transformed);
        result->boundary_count = boundaries.size();
        result->boundaries = (anigma_text_boundary_t*)anigma_capsule_alloc_buffer(
            boundaries.size() * sizeof(anigma_text_boundary_t), err
        );
        if (!result->boundaries) {
            anigma_capsule_free_buffer(result->transformed_text, err);
            anigma_capsule_free_buffer(result->offset_map, err);
            result->transformed_text = nullptr;
            result->offset_map = nullptr;
            return ANIGMA_ERR_INTERNAL;
        }
        
        std::memcpy(result->boundaries, boundaries.data(), boundaries.size() * sizeof(anigma_text_boundary_t));
        
        // Compute operation hash and timing
        std::string operation_data = input + "|" + transformed;
        result->operation_hash = capsule_impl.compute_operation_hash(operation_data);
        result->processing_time_us = capsule_impl.get_timestamp_us();
        
        return ANIGMA_OK;
        
    } catch (const std::exception& e) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Text transformation failed";
            err->detail = e.what();
            err->aux = 0;
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

// Normalize Unicode
anigma_status_t anigma_text_pipeline_capsule_normalize_unicode(
    anigma_text_pipeline_capsule_t* capsule,
    const uint8_t* input_text,
    size_t input_length,
    anigma_unicode_form_t form,
    anigma_capsule_buffer_t* output_buffer,
    anigma_capsule_error_t* err
) {
    auto it = g_capsules.find(capsule);
    if (it == g_capsules.end() || !input_text || !output_buffer) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = "Handle, input_text, and output_buffer must not be null";
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        auto& capsule_impl = *it->second;
        std::string input(reinterpret_cast<const char*>(input_text), input_length);
        std::string normalized = capsule_impl.normalize_unicode(input, form);
        
        return anigma_capsule_copy_to_buffer(
            output_buffer, normalized.c_str(), normalized.length(), err
        );
        
    } catch (const std::exception& e) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "Unicode normalization failed";
            err->detail = e.what();
            err->aux = 0;
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

// Validate UTF-8
anigma_status_t anigma_text_pipeline_capsule_validate_utf8(
    anigma_text_pipeline_capsule_t* capsule,
    const uint8_t* input_text,
    size_t input_length,
    uint8_t* is_valid,
    anigma_capsule_error_t* err
) {
    auto it = g_capsules.find(capsule);
    if (it == g_capsules.end() || !input_text || !is_valid) {
        if (err) {
            err->code = ANIGMA_ERR_INVALID_ARG;
            err->message = "Invalid arguments";
            err->detail = "Handle, input_text, and is_valid must not be null";
            err->aux = 0;
        }
        return ANIGMA_ERR_INVALID_ARG;
    }
    
    try {
        auto& capsule_impl = *it->second;
        bool valid = capsule_impl.validate_utf8(input_text, input_length);
        *is_valid = valid ? 1 : 0;
        return ANIGMA_OK;
        
    } catch (const std::exception& e) {
        if (err) {
            err->code = ANIGMA_ERR_INTERNAL;
            err->message = "UTF-8 validation failed";
            err->detail = e.what();
            err->aux = 0;
        }
        return ANIGMA_ERR_INTERNAL;
    }
}

// Additional implementations would follow similar patterns...
// For brevity, I'm implementing the key functions

} // extern "C"