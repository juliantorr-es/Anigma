/**
 * ReferenceResolutionCapsule C++ Implementation
 */

#include "ReferenceResolutionCapsule/reference_resolution_capsule.h"
#include "CitationExtractionCapsule/citation_extraction_capsule.h"
#include "anigma_capsule_core.h"
#include "anigma_status.h"
#include <vector>
#include <memory>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <unordered_map>
#include <regex>

// Forward declarations
namespace {

// Helper to duplicate strings safely
char* safe_strdup(const char* s) {
    if (!s) return nullptr;
    size_t len = strlen(s);
    char* d = (char*)malloc(len + 1);
    if (d) memcpy(d, s, len + 1);
    return d;
}

// Helper to duplicate strings with length
char* safe_strndup(const char* s, size_t len) {
    if (!s) return nullptr;
    char* d = (char*)malloc(len + 1);
    if (d) {
        memcpy(d, s, len);
        d[len] = '\0';
    }
    return d;
}

class ReferenceResolutionContext {
public:
    explicit ReferenceResolutionContext(const struct anigma_reference_resolution_config_t& config)
        : config_(config) {
        // Initialize context
        if (config.enable_caching) {
            // TODO: Initialize cache
        }
        
        // Load fuzzy matching patterns
        init_fuzzy_patterns();
    }

    ~ReferenceResolutionContext() {
        // Cleanup
        if (config_.enable_caching) {
            // TODO: Cleanup cache
        }
    }

    struct anigma_reference_resolution_config_t config_;
    // TODO: Add cache state
    // TODO: Add database connection state
    
    // Fuzzy matching patterns
    std::vector<std::regex> title_patterns_;
    std::vector<std::regex> author_patterns_;
    std::vector<std::regex> journal_patterns_;
    
    void init_fuzzy_patterns() {
        // Title patterns
        title_patterns_.push_back(std::regex("[Tt]itle.*:", std::regex::icase));
        title_patterns_.push_back(std::regex("[Tt]itle.*=", std::regex::icase));
        
        // Author patterns
        author_patterns_.push_back(std::regex("[Aa]uthor.*:", std::regex::icase));
        author_patterns_.push_back(std::regex("[Aa]uthor.*=", std::regex::icase));
        
        // Journal patterns
        journal_patterns_.push_back(std::regex("[Jj]ournal.*:", std::regex::icase));
        journal_patterns_.push_back(std::regex("[Jj]ournal.*=", std::regex::icase));
    }
    
    // Fuzzy matching algorithm using simplified Levenshtein distance
    float calculate_similarity(const std::string& str1, const std::string& str2) {
        if (str1.empty() && str2.empty()) {
            return 1.0f;
        }
        if (str1.empty() || str2.empty()) {
            return 0.0f;
        }
        
        // Convert to lowercase for case-insensitive comparison
        std::string s1 = str1;
        std::string s2 = str2;
        std::transform(s1.begin(), s1.end(), s1.begin(), ::tolower);
        std::transform(s2.begin(), s2.end(), s2.begin(), ::tolower);
        
        // Simple similarity: ratio of common characters
        int common = 0;
        for (char c : s1) {
            if (s2.find(c) != std::string::npos) {
                common++;
            }
        }
        
        float similarity = static_cast<float>(common) / std::max(s1.length(), s2.length());
        return similarity;
    }
    
    // Extract field from reference text using regex
    std::string extract_field(const std::string& text, const std::vector<std::regex>& patterns) {
        for (const auto& pattern : patterns) {
            std::smatch match;
            if (std::regex_search(text, match, pattern)) {
                // Extract the content after the pattern
                size_t pos = match[0].second - text.cbegin();
                if (pos < text.length()) {
                    // Skip whitespace
                    while (pos < text.length() && std::isspace(text[pos])) {
                        pos++;
                    }
                    if (pos < text.length()) {
                        return text.substr(pos);
                    }
                }
            }
        }
        return "";
    }
    
    // Reference matching algorithm
    struct anigma_resolved_reference_t match_reference(
        const struct anigma_citation_reference_t& input_ref,
        const std::unordered_map<std::string, struct anigma_resolved_reference_t>& database) {
        
        // Initialize result with safe copies of input data or null
        // We use safe_strndup to ensure the result owns its memory
        struct anigma_resolved_reference_t result;
        memset(&result, 0, sizeof(result));

        result.original_id = safe_strndup(input_ref.reference_id, input_ref.reference_id_len);
        result.original_id_len = input_ref.reference_id_len;
        
        // Extract fields from input reference if not already present, otherwise copy
        if (!input_ref.title || input_ref.title_len == 0) {
            std::string text(input_ref.text, input_ref.text_len);
            std::string title = extract_field(text, title_patterns_);
            if (!title.empty()) {
                result.title = safe_strdup(title.c_str());
                result.title_len = title.length();
            }
        } else {
            result.title = safe_strndup(input_ref.title, input_ref.title_len);
            result.title_len = input_ref.title_len;
        }
        
        if (!input_ref.authors || input_ref.authors_len == 0) {
            std::string text(input_ref.text, input_ref.text_len);
            std::string authors = extract_field(text, author_patterns_);
            if (!authors.empty()) {
                result.authors = safe_strdup(authors.c_str());
                result.authors_len = authors.length();
            }
        } else {
            result.authors = safe_strndup(input_ref.authors, input_ref.authors_len);
            result.authors_len = input_ref.authors_len;
        }
        
        if (!input_ref.venue || input_ref.venue_len == 0) {
            std::string text(input_ref.text, input_ref.text_len);
            std::string journal = extract_field(text, journal_patterns_);
            if (!journal.empty()) {
                result.journal = safe_strdup(journal.c_str());
                result.journal_len = journal.length();
            }
        } else {
            result.journal = safe_strndup(input_ref.venue, input_ref.venue_len);
            result.journal_len = input_ref.venue_len;
        }

        // Copy other available fields
        if (input_ref.year && input_ref.year_len > 0) {
            result.year = safe_strndup(input_ref.year, input_ref.year_len);
            result.year_len = input_ref.year_len;
        }
        
        if (input_ref.pages && input_ref.pages_len > 0) {
            result.pages = safe_strndup(input_ref.pages, input_ref.pages_len);
            result.pages_len = input_ref.pages_len;
        }

        // For now, since we don't have a real database, we'll simulate matching
        // by checking if we have enough information to create a resolved reference
        
        float confidence = 0.0f;
        
        // Check if we have title
        if (result.title && result.title_len > 0) {
            confidence += 0.3f;
        }
        
        // Check if we have authors
        if (result.authors && result.authors_len > 0) {
            confidence += 0.3f;
        }
        
        // Check if we have year
        if (result.year && result.year_len > 0) {
            confidence += 0.2f;
        }
        
        // Check if we have journal
        if (result.journal && result.journal_len > 0) {
            confidence += 0.2f;
        }
        
        result.confidence = confidence;
        
        // Set match status based on confidence
        if (confidence >= config_.fuzzy_threshold) {
            result.match_status = 1; // Matched
        } else {
            result.match_status = 0; // Unmatched
        }
        
        return result;
    }
};

} // namespace

// C API Implementation

extern "C" {

anigma_status_t anigma_reference_resolution_get_default_config(
    struct anigma_reference_resolution_config_t* out_config) {
    if (!out_config) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    *out_config = {
        .enable_online_lookup = false,  // Default to offline for determinism
        .enable_fuzzy_matching = true,
        .fuzzy_threshold = 0.8f,        // 80% similarity threshold
        .enable_caching = true,
        .cache_dir = nullptr,
        .crossref_endpoint = nullptr,
        .pubmed_endpoint = nullptr
    };
    
    return ANIGMA_STATUS_OK;
}

anigma_status_t anigma_reference_resolution_capsule_create(
    const struct anigma_reference_resolution_config_t* config,
    anigma_capsule_handle_t* out_handle) {
    if (!config || !out_handle) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    try {
        // Create context
        auto ctx = std::make_unique<ReferenceResolutionContext>(*config);
        
        // Store context in capsule handle
        *out_handle = reinterpret_cast<anigma_capsule_handle_t>(ctx.release());
        
        return ANIGMA_STATUS_OK;
    } catch (...) {
        return ANIGMA_STATUS_ALLOCATION_FAILED;
    }
}

anigma_status_t anigma_reference_resolution_capsule_destroy(
    anigma_capsule_handle_t handle) {
    if (!handle) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    try {
        auto ctx = reinterpret_cast<ReferenceResolutionContext*>(handle);
        delete ctx;
        return ANIGMA_STATUS_OK;
    } catch (...) {
        return ANIGMA_STATUS_INTERNAL_ERROR;
    }
}

anigma_status_t anigma_reference_resolution_resolve(
    anigma_capsule_handle_t handle,
    const struct anigma_citation_reference_t* references,
    size_t reference_count,
    struct anigma_reference_resolution_result_t* out_result) {
    if (!handle || !references || !out_result) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    try {
        auto ctx = reinterpret_cast<ReferenceResolutionContext*>(handle);
        
        // Convert references to vector for processing
        std::vector<struct anigma_citation_reference_t> ref_vec;
        ref_vec.reserve(reference_count);
        for (size_t i = 0; i < reference_count; ++i) {
            ref_vec.push_back(references[i]);
        }
        
        // Resolve each reference
        std::vector<struct anigma_resolved_reference_t> resolved;
        std::vector<struct anigma_resolved_reference_t> unresolved;
        resolved.reserve(reference_count);
        unresolved.reserve(reference_count);
        
        for (const auto& ref : ref_vec) {
            auto resolved_ref = ctx->match_reference(ref, {}); // Empty database for now
            
            if (resolved_ref.confidence >= ctx->config_.fuzzy_threshold) {
                resolved.push_back(resolved_ref);
            } else {
                unresolved.push_back(resolved_ref);
            }
        }
        
        // Populate result
        out_result->resolved_count = resolved.size();
        out_result->unresolved_count = unresolved.size();
        
        if (out_result->resolved_count > 0) {
            size_t size = sizeof(struct anigma_resolved_reference_t) * out_result->resolved_count;
            out_result->resolved_references = (struct anigma_resolved_reference_t*)malloc(size);
            if (out_result->resolved_references) {
                for (size_t i = 0; i < out_result->resolved_count; ++i) {
                    out_result->resolved_references[i] = resolved[i];
                }
            } else {
                // Allocation failed, cleanup everything
                for (auto& r : resolved) {
                    free((void*)r.original_id);
                    free((void*)r.title);
                    free((void*)r.authors);
                    free((void*)r.journal);
                    free((void*)r.year);
                    free((void*)r.pages);
                    // Free other fields as added
                }
                for (auto& r : unresolved) {
                    free((void*)r.original_id);
                    free((void*)r.title);
                    free((void*)r.authors);
                    free((void*)r.journal);
                    free((void*)r.year);
                    free((void*)r.pages);
                }
                return ANIGMA_STATUS_ALLOCATION_FAILED;
            }
        } else {
            out_result->resolved_references = nullptr;
        }
        
        if (out_result->unresolved_count > 0) {
            size_t size = sizeof(struct anigma_resolved_reference_t) * out_result->unresolved_count;
            out_result->unresolved_references = (struct anigma_resolved_reference_t*)malloc(size);
            if (out_result->unresolved_references) {
                for (size_t i = 0; i < out_result->unresolved_count; ++i) {
                    out_result->unresolved_references[i] = unresolved[i];
                }
            } else {
                // Allocation failed
                if (out_result->resolved_references) free(out_result->resolved_references);
                // Free strings logic (duplicated from above)
                 for (auto& r : resolved) {
                    free((void*)r.original_id);
                    free((void*)r.title);
                    free((void*)r.authors);
                    free((void*)r.journal);
                    free((void*)r.year);
                    free((void*)r.pages);
                }
                for (auto& r : unresolved) {
                    free((void*)r.original_id);
                    free((void*)r.title);
                    free((void*)r.authors);
                    free((void*)r.journal);
                    free((void*)r.year);
                    free((void*)r.pages);
                }
                return ANIGMA_STATUS_ALLOCATION_FAILED;
            }
        } else {
            out_result->unresolved_references = nullptr;
        }

        out_result->processing_time_us = 0; // TODO: Measure actual time
        
        return ANIGMA_STATUS_OK;
    } catch (...) {
        return ANIGMA_STATUS_INTERNAL_ERROR;
    }
}

anigma_status_t anigma_reference_resolution_free_result(
    struct anigma_reference_resolution_result_t* result) {
    if (!result) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    // Free resolved references
    if (result->resolved_references) {
        for (size_t i = 0; i < result->resolved_count; ++i) {
            auto& ref = result->resolved_references[i];
            free((void*)ref.original_id);
            free((void*)ref.doi);
            free((void*)ref.pubmed_id);
            free((void*)ref.crossref_id);
            free((void*)ref.title);
            free((void*)ref.authors);
            free((void*)ref.year);
            free((void*)ref.journal);
            free((void*)ref.volume);
            free((void*)ref.issue);
            free((void*)ref.pages);
        }
        free(result->resolved_references);
        result->resolved_references = nullptr;
    }
    
    // Free unresolved references
    if (result->unresolved_references) {
        for (size_t i = 0; i < result->unresolved_count; ++i) {
            auto& ref = result->unresolved_references[i];
            free((void*)ref.original_id);
            free((void*)ref.doi);
            free((void*)ref.pubmed_id);
            free((void*)ref.crossref_id);
            free((void*)ref.title);
            free((void*)ref.authors);
            free((void*)ref.year);
            free((void*)ref.journal);
            free((void*)ref.volume);
            free((void*)ref.issue);
            free((void*)ref.pages);
        }
        free(result->unresolved_references);
        result->unresolved_references = nullptr;
    }
    
    result->resolved_count = 0;
    result->unresolved_count = 0;
    result->processing_time_us = 0;
    
    return ANIGMA_STATUS_OK;
}

anigma_status_t anigma_resolved_reference_export_to_bibtex(
    const struct anigma_resolved_reference_t* reference,
    const char** out_bibtex,
    size_t* out_bibtex_len) {
    if (!reference || !out_bibtex || !out_bibtex_len) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    // TODO: Implement BibTeX export
    *out_bibtex = nullptr;
    *out_bibtex_len = 0;
    
    return ANIGMA_STATUS_NOT_IMPLEMENTED;
}

anigma_status_t anigma_resolved_reference_export_to_json(
    const struct anigma_resolved_reference_t* reference,
    const char** out_json,
    size_t* out_json_len) {
    if (!reference || !out_json || !out_json_len) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    // TODO: Implement JSON export
    *out_json = nullptr;
    *out_json_len = 0;
    
    return ANIGMA_STATUS_NOT_IMPLEMENTED;
}

anigma_status_t anigma_reference_resolution_free_export(
    const char* data) {
    if (!data) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    // TODO: Free exported data
    // When we implement export, we should malloc and then free here
    
    return ANIGMA_STATUS_OK;
}

} // extern "C"