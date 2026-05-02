/**
 * DiffCapsule C++ Implementation
 */

#include "DiffCapsule/diff_capsule.h"
#include "anigma_capsule_core.h"
#include "anigma_status.h"
#include <vector>
#include <memory>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <unordered_map>

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

class DiffContext {
public:
    explicit DiffContext(const struct anigma_diff_config_t& config)
        : config_(config) {
        // Initialize context
    }

    ~DiffContext() {
        // Cleanup
    }

    struct anigma_diff_config_t config_;
    
    // Simple diff algorithm (Myers' diff algorithm)
    std::vector<struct anigma_diff_op_t> compute_diff(
        const std::string& original,
        const std::string& modified) {
        
        std::vector<struct anigma_diff_op_t> operations;
        
        if (original.empty() && modified.empty()) {
            return operations;
        }
        
        // Split into lines for line-based diff
        auto original_lines = split_into_lines(original);
        auto modified_lines = split_into_lines(modified);
        
        // Compute line-based diff using LCS (Longest Common Subsequence)
        auto lcs = compute_lcs(original_lines, modified_lines);
        
        // Generate diff operations from LCS
        generate_diff_operations(original_lines, modified_lines, lcs, operations);
        
        return operations;
    }
    
    // Split text into lines
    std::vector<std::string> split_into_lines(const std::string& text) {
        std::vector<std::string> lines;
        if (text.empty()) {
            return lines;
        }
        
        size_t start = 0;
        size_t end = text.find('\n');
        
        while (end != std::string::npos) {
            lines.push_back(text.substr(start, end - start));
            start = end + 1;
            end = text.find('\n', start);
        }
        
        // Add the last line
        if (start < text.length()) {
            lines.push_back(text.substr(start));
        }
        
        return lines;
    }
    
    // Compute Longest Common Subsequence
    std::vector<std::pair<size_t, size_t>> compute_lcs(
        const std::vector<std::string>& original,
        const std::vector<std::string>& modified) {
        
        std::vector<std::vector<size_t>> dp(original.size() + 1, 
                                           std::vector<size_t>(modified.size() + 1, 0));
        
        // Build DP table
        for (size_t i = 1; i <= original.size(); ++i) {
            for (size_t j = 1; j <= modified.size(); ++j) {
                if (original[i-1] == modified[j-1]) {
                    dp[i][j] = dp[i-1][j-1] + 1;
                } else {
                    dp[i][j] = std::max(dp[i-1][j], dp[i][j-1]);
                }
            }
        }
        
        // Backtrack to find LCS
        std::vector<std::pair<size_t, size_t>> lcs;
        size_t i = original.size();
        size_t j = modified.size();
        
        while (i > 0 && j > 0) {
            if (original[i-1] == modified[j-1]) {
                lcs.push_back({i-1, j-1});
                i--;
                j--;
            } else if (dp[i-1][j] > dp[i][j-1]) {
                i--;
            } else {
                j--;
            }
        }
        
        // Reverse to get correct order
        std::reverse(lcs.begin(), lcs.end());
        
        return lcs;
    }
    
    // Generate diff operations from LCS
    void generate_diff_operations(
        const std::vector<std::string>& original,
        const std::vector<std::string>& modified,
        const std::vector<std::pair<size_t, size_t>>& lcs,
        std::vector<struct anigma_diff_op_t>& operations) {
        
        size_t orig_idx = 0;
        size_t mod_idx = 0;
        size_t lcs_idx = 0;
        
        while (orig_idx < original.size() && mod_idx < modified.size()) {
            if (lcs_idx < lcs.size() && 
                orig_idx == lcs[lcs_idx].first && 
                mod_idx == lcs[lcs_idx].second) {
                // Match
                size_t match_end_orig = lcs[lcs_idx].first;
                size_t match_end_mod = lcs[lcs_idx].second;
                
                // Find consecutive matches
                while (lcs_idx + 1 < lcs.size() &&
                       lcs[lcs_idx + 1].first == match_end_orig + 1 &&
                       lcs[lcs_idx + 1].second == match_end_mod + 1) {
                    lcs_idx++;
                    match_end_orig = lcs[lcs_idx].first;
                    match_end_mod = lcs[lcs_idx].second;
                }
                
                // Add match operation
                if (match_end_orig >= orig_idx) {
                    struct anigma_diff_op_t op;
                    op.type = ANIGMA_DIFF_OP_MATCH;
                    op.start_original = static_cast<int32_t>(orig_idx);
                    op.end_original = static_cast<int32_t>(match_end_orig);
                    op.start_modified = static_cast<int32_t>(mod_idx);
                    op.end_modified = static_cast<int32_t>(match_end_mod);
                    operations.push_back(op);
                }
                
                orig_idx = match_end_orig + 1;
                mod_idx = match_end_mod + 1;
                lcs_idx++;
            } else {
                // Check for deletion
                if (mod_idx >= modified.size() || 
                    (lcs_idx < lcs.size() && orig_idx < lcs[lcs_idx].first)) {
                    // Deletion
                    size_t del_start = orig_idx;
                    size_t del_end = (lcs_idx < lcs.size()) ? lcs[lcs_idx].first - 1 : original.size() - 1;
                    
                    struct anigma_diff_op_t op;
                    op.type = ANIGMA_DIFF_OP_DELETE;
                    op.start_original = static_cast<int32_t>(del_start);
                    op.end_original = static_cast<int32_t>(del_end);
                    op.start_modified = -1; // Not applicable
                    op.end_modified = -1;
                    operations.push_back(op);
                    
                    orig_idx = del_end + 1;
                }
                // Check for insertion
                else if (orig_idx >= original.size() || 
                         (lcs_idx < lcs.size() && mod_idx < lcs[lcs_idx].second)) {
                    // Insertion
                    size_t ins_start = mod_idx;
                    size_t ins_end = (lcs_idx < lcs.size()) ? lcs[lcs_idx].second - 1 : modified.size() - 1;
                    
                    struct anigma_diff_op_t op;
                    op.type = ANIGMA_DIFF_OP_INSERT;
                    op.start_original = -1; // Not applicable
                    op.end_original = -1;
                    op.start_modified = static_cast<int32_t>(ins_start);
                    op.end_modified = static_cast<int32_t>(ins_end);
                    operations.push_back(op);
                    
                    mod_idx = ins_end + 1;
                } else {
                    // Both deletion and insertion (replacement)
                    size_t del_start = orig_idx;
                    size_t del_end = (lcs_idx < lcs.size()) ? lcs[lcs_idx].first - 1 : original.size() - 1;
                    size_t ins_start = mod_idx;
                    size_t ins_end = (lcs_idx < lcs.size()) ? lcs[lcs_idx].second - 1 : modified.size() - 1;
                    
                    struct anigma_diff_op_t op;
                    op.type = ANIGMA_DIFF_OP_REPLACE;
                    op.start_original = static_cast<int32_t>(del_start);
                    op.end_original = static_cast<int32_t>(del_end);
                    op.start_modified = static_cast<int32_t>(ins_start);
                    op.end_modified = static_cast<int32_t>(ins_end);
                    operations.push_back(op);
                    
                    orig_idx = del_end + 1;
                    mod_idx = ins_end + 1;
                }
            }
        }
        
        // Handle remaining lines
        while (orig_idx < original.size()) {
            struct anigma_diff_op_t op;
            op.type = ANIGMA_DIFF_OP_DELETE;
            op.start_original = static_cast<int32_t>(orig_idx);
            op.end_original = static_cast<int32_t>(original.size() - 1);
            op.start_modified = -1;
            op.end_modified = -1;
            operations.push_back(op);
            break;
        }
        
        while (mod_idx < modified.size()) {
            struct anigma_diff_op_t op;
            op.type = ANIGMA_DIFF_OP_INSERT;
            op.start_original = -1;
            op.end_original = -1;
            op.start_modified = static_cast<int32_t>(mod_idx);
            op.end_modified = static_cast<int32_t>(modified.size() - 1);
            operations.push_back(op);
            break;
        }
    }
    
    // Calculate similarity score using Levenshtein distance
    float calculate_similarity(const std::string& original, 
                              const std::string& modified) {
        if (original.empty() && modified.empty()) {
            return 1.0f;
        }
        if (original.empty() || modified.empty()) {
            return 0.0f;
        }
        
        // Use line-based similarity
        auto original_lines = split_into_lines(original);
        auto modified_lines = split_into_lines(modified);
        
        if (original_lines.empty() && modified_lines.empty()) {
            return 1.0f;
        }
        if (original_lines.empty() || modified_lines.empty()) {
            return 0.0f;
        }
        
        // Compute LCS length
        auto lcs = compute_lcs(original_lines, modified_lines);
        size_t lcs_length = lcs.size();
        
        // Calculate similarity as ratio of common lines to total lines
        size_t total_lines = (original_lines.size() + modified_lines.size()) / 2;
        if (total_lines == 0) {
            return 0.0f;
        }
        
        float similarity = static_cast<float>(lcs_length) / total_lines;
        return similarity;
    }
};

} // namespace

// C API Implementation

extern "C" {

anigma_status_t anigma_diff_get_default_config(
    struct anigma_diff_config_t* out_config) {
    if (!out_config) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    *out_config = {
        .enable_line_diff = true,
        .enable_word_diff = false,
        .enable_char_diff = false,
        .ignore_whitespace = false,
        .ignore_case = false,
        .context_lines = 3
    };
    
    return ANIGMA_STATUS_OK;
}

anigma_status_t anigma_diff_capsule_create(
    const struct anigma_diff_config_t* config,
    anigma_capsule_handle_t* out_handle) {
    if (!config || !out_handle) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    try {
        // Create context
        auto ctx = std::make_unique<DiffContext>(*config);
        
        // Store context in capsule handle
        *out_handle = reinterpret_cast<anigma_capsule_handle_t>(ctx.release());
        
        return ANIGMA_STATUS_OK;
    } catch (...) {
        return ANIGMA_STATUS_ALLOCATION_FAILED;
    }
}

anigma_status_t anigma_diff_capsule_destroy(
    anigma_capsule_handle_t handle) {
    if (!handle) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    try {
        auto ctx = reinterpret_cast<DiffContext*>(handle);
        delete ctx;
        return ANIGMA_STATUS_OK;
    } catch (...) {
        return ANIGMA_STATUS_INTERNAL_ERROR;
    }
}

anigma_status_t anigma_diff_compute(
    anigma_capsule_handle_t handle,
    const char* original_doc,
    size_t original_doc_len,
    const char* modified_doc,
    size_t modified_doc_len,
    struct anigma_document_diff_result_t* out_result) {
    if (!handle || !original_doc || !modified_doc || !out_result) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    try {
        auto ctx = reinterpret_cast<DiffContext*>(handle);
        
        // Convert documents to strings
        std::string original_str(original_doc, original_doc_len);
        std::string modified_str(modified_doc, modified_doc_len);
        
        // Compute diff
        auto operations = ctx->compute_diff(original_str, modified_str);
        
        // Calculate similarity
        float similarity = ctx->calculate_similarity(original_str, modified_str);
        
        // Populate result with allocated memory for arrays
        out_result->op_count = operations.size();
        
        if (out_result->op_count > 0) {
            out_result->operations = (struct anigma_diff_op_t*)malloc(
                sizeof(struct anigma_diff_op_t) * out_result->op_count);
            
            if (out_result->operations) {
                for (size_t i = 0; i < out_result->op_count; ++i) {
                    out_result->operations[i] = operations[i];
                }
            } else {
                return ANIGMA_STATUS_ALLOCATION_FAILED;
            }
        } else {
            out_result->operations = nullptr;
        }

        // Duplicate document version info (using nulls for metadata since we only have content)
        out_result->original = {
            .doc_id = nullptr,
            .doc_id_len = 0,
            .content = safe_strndup(original_doc, original_doc_len),
            .content_len = original_doc_len,
            .timestamp = 0,
            .author = nullptr,
            .author_len = 0,
            .message = nullptr,
            .message_len = 0
        };
        out_result->modified = {
            .doc_id = nullptr,
            .doc_id_len = 0,
            .content = safe_strndup(modified_doc, modified_doc_len),
            .content_len = modified_doc_len,
            .timestamp = 0,
            .author = nullptr,
            .author_len = 0,
            .message = nullptr,
            .message_len = 0
        };
        out_result->similarity = similarity;
        out_result->processing_time_us = 0; // TODO: Measure actual time
        
        return ANIGMA_STATUS_OK;
    } catch (...) {
        return ANIGMA_STATUS_INTERNAL_ERROR;
    }
}

anigma_status_t anigma_diff_compute_from_versions(
    anigma_capsule_handle_t handle,
    const struct anigma_document_version_t* original,
    const struct anigma_document_version_t* modified,
    struct anigma_document_diff_result_t* out_result) {
    if (!handle || !original || !modified || !out_result) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    // TODO: Implement version-based diff
    // This would use version metadata in addition to content
    
    out_result->operations = nullptr;
    out_result->op_count = 0;
    out_result->original = *original;
    out_result->modified = *modified;
    out_result->similarity = 0.0f;
    out_result->processing_time_us = 0;
    
    return ANIGMA_STATUS_NOT_IMPLEMENTED;
}

anigma_status_t anigma_diff_free_result(
    struct anigma_document_diff_result_t* result) {
    if (!result) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    // Free allocated memory
    if (result->operations) {
        free(result->operations);
        result->operations = nullptr;
    }
    
    // Free string data in versions
    free((void*)result->original.doc_id);
    free((void*)result->original.content);
    free((void*)result->original.author);
    free((void*)result->original.message);
    
    free((void*)result->modified.doc_id);
    free((void*)result->modified.content);
    free((void*)result->modified.author);
    free((void*)result->modified.message);
    
    result->op_count = 0;
    result->similarity = 0.0f;
    result->processing_time_us = 0;
    
    return ANIGMA_STATUS_OK;
}

anigma_status_t anigma_diff_export_to_unified(
    const struct anigma_document_diff_result_t* result,
    const char** out_unified,
    size_t* out_unified_len) {
    if (!result || !out_unified || !out_unified_len) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    // TODO: Implement unified diff export
    *out_unified = nullptr;
    *out_unified_len = 0;
    
    return ANIGMA_STATUS_NOT_IMPLEMENTED;
}

anigma_status_t anigma_diff_export_to_json(
    const struct anigma_document_diff_result_t* result,
    const char** out_json,
    size_t* out_json_len) {
    if (!result || !out_json || !out_json_len) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    // TODO: Implement JSON export
    *out_json = nullptr;
    *out_json_len = 0;
    
    return ANIGMA_STATUS_NOT_IMPLEMENTED;
}

anigma_status_t anigma_diff_free_export(
    const char* data) {
    if (!data) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    // TODO: Free exported data
    return ANIGMA_STATUS_OK;
}

} // extern "C"