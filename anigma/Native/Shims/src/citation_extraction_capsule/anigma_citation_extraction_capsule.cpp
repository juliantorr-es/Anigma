/**
 * CitationExtractionCapsule C++ Implementation
 */

#include "CitationExtractionCapsule/citation_extraction_capsule.h"
#include "anigma_capsule_core.h"
#include "anigma_status.h"
#include <vector>
#include <memory>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <regex>
#include <set>

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

// Helper to duplicate std::string to char*
char* safe_string_dup(const std::string& s) {
    return safe_strndup(s.c_str(), s.length());
}

class CitationExtractionContext {
public:
    explicit CitationExtractionContext(const struct anigma_citation_extraction_config_t& config)
        : config_(config) {
        // Initialize context
        if (config.enable_ml_extraction) {
            // TODO: Initialize ONNX Runtime if needed
        }
        
        // Load regex patterns
        if (config.regex_patterns_path) {
            // TODO: Load custom regex patterns
        } else {
            // Use default patterns
            init_default_patterns();
        }
    }

    ~CitationExtractionContext() {
        // Cleanup
        if (config_.enable_ml_extraction) {
            // TODO: Cleanup ONNX Runtime
        }
    }

    struct anigma_citation_extraction_config_t config_;
    // TODO: Add ML model and ONNX Runtime state
    // TODO: Add regex pattern storage
    
    // Default regex patterns
    std::vector<std::regex> reference_patterns_;
    std::vector<std::regex> inline_citation_patterns_;
    
    void init_default_patterns() {
        // Reference section patterns
        reference_patterns_.push_back(std::regex("References", std::regex::icase));
        reference_patterns_.push_back(std::regex("Bibliography", std::regex::icase));
        reference_patterns_.push_back(std::regex("Works Cited", std::regex::icase));
        
        // Inline citation patterns (APA, MLA, Chicago, etc.)
        inline_citation_patterns_.push_back(std::regex("\\[[^\\]]+\\]", std::regex::icase));
        inline_citation_patterns_.push_back(std::regex("\\([0-9]+(?:,[0-9]+)*\\)"));
        inline_citation_patterns_.push_back(std::regex("([A-Z][a-z]+ [A-Z][a-z]+,? [0-9]{4})"));
    }
};

// Internal structures for processing
struct InternalReference {
    std::string text;
    anigma_citation_bbox_t bbox;
    std::string title;
    std::string author;
    std::string year;
    std::string journal;
    std::string volume;
    std::string pages;
    std::string doi;
};

struct InternalInlineCitation {
    std::string text;
    anigma_citation_bbox_t bbox;
    std::string key;
    int32_t pattern_index;
};

// Helper functions
inline double calculate_bbox_area(const struct anigma_citation_bbox_t& bbox) {
    double width = bbox.right - bbox.left;
    double height = bbox.bottom - bbox.top;
    return width * height;
}

inline bool is_reference_section(const std::string& text, 
                                 const std::vector<std::regex>& patterns) {
    for (const auto& pattern : patterns) {
        if (std::regex_search(text, pattern)) {
            return true;
        }
    }
    return false;
}

// Helper function to extract reference fields using regex
void extract_reference_fields(const std::string& text, 
                              InternalReference& reference) {
    // Common patterns for different reference types
    
    // Author pattern: Lastname, Firstname
    std::regex author_pattern("([A-Z][a-z]+), ([A-Z][a-z]+)");
    std::smatch author_match;
    if (std::regex_search(text, author_match, author_pattern)) {
        reference.author = author_match[0].str();
    }
    
    // Year pattern: (1999), 1999, 1999.
    std::regex year_pattern("\\(?([0-9]{4})\\)?[.,]?");
    std::smatch year_match;
    if (std::regex_search(text, year_match, year_pattern)) {
        reference.year = year_match[1].str();
    }
    
    // Title pattern: often in quotes or italics
    std::regex title_pattern("\".*?\"");
    std::smatch title_match;
    if (std::regex_search(text, title_match, title_pattern)) {
        reference.title = title_match[0].str();
    }
    
    // Journal pattern: often in italics or after year
    std::regex journal_pattern("([A-Z][a-z]+ [A-Z][a-z]+)");
    std::smatch journal_match;
    if (std::regex_search(text, journal_match, journal_pattern)) {
        reference.journal = journal_match[0].str();
    }
    
    // Volume pattern: vol. 12 or Volume 12
    std::regex volume_pattern("(?:vol\\.?|Volume)[.:]? ([0-9]+)");
    std::smatch volume_match;
    if (std::regex_search(text, volume_match, volume_pattern)) {
        reference.volume = volume_match[1].str();
    }
    
    // Pages pattern: pp. 12-34 or pages 12-34
    std::regex pages_pattern("(?:pp\\.?|pages?)[.:]? ([0-9]+-[0-9]+)");
    std::smatch pages_match;
    if (std::regex_search(text, pages_match, pages_pattern)) {
        reference.pages = pages_match[1].str();
    }
    
    // DOI pattern
    std::regex doi_pattern("doi:? ([0-9.]+/[0-9a-zA-Z]+)");
    std::smatch doi_match;
    if (std::regex_search(text, doi_match, doi_pattern)) {
        reference.doi = doi_match[1].str();
    }
}

// Reference extraction algorithm
std::vector<InternalReference> extract_references(
    const std::vector<struct anigma_layout_segment_t>& segments,
    const std::vector<size_t>& reference_section_indices) {
    std::vector<InternalReference> references;
    
    if (segments.empty() || reference_section_indices.empty()) {
        return references;
    }
    
    // Extract segments that are part of reference sections
    std::vector<struct anigma_layout_segment_t> reference_segments;
    std::set<size_t> reference_set(reference_section_indices.begin(), reference_section_indices.end());
    
    for (size_t idx : reference_section_indices) {
        if (idx < segments.size()) {
            reference_segments.push_back(segments[idx]);
        }
    }
    
    // Sort reference segments by position
    std::sort(reference_segments.begin(), reference_segments.end(),
        [](const auto& a, const auto& b) {
            return a.bbox.top < b.bbox.top ||
                   (a.bbox.top == b.bbox.top && a.bbox.left < b.bbox.left);
        });
    
    // Group consecutive segments into individual references
    std::vector<std::vector<struct anigma_layout_segment_t>> reference_groups;
    
    if (!reference_segments.empty()) {
        std::vector<struct anigma_layout_segment_t> current_group;
        current_group.push_back(reference_segments[0]);
        
        for (size_t i = 1; i < reference_segments.size(); ++i) {
            const auto& seg = reference_segments[i];
            const auto& last_seg = current_group.back();
            
            // Check if segment belongs to the same reference
            // References are typically separated by blank lines or significant vertical space
            if (std::abs(seg.bbox.top - last_seg.bbox.bottom) < 20.0) {
                // Same reference
                current_group.push_back(seg);
            } else {
                // New reference
                reference_groups.push_back(current_group);
                current_group.clear();
                current_group.push_back(seg);
            }
        }
        
        if (!current_group.empty()) {
            reference_groups.push_back(current_group);
        }
    }
    
    // Parse each reference group
    for (const auto& group : reference_groups) {
        InternalReference reference;
        
        // Combine all text from the group
        std::string full_text;
        for (const auto& seg : group) {
            if (!full_text.empty()) {
                full_text += " ";
            }
            full_text.append(seg.text, seg.text_len);
        }
        
        reference.text = full_text;
        
        // Calculate bounding box
        if (!group.empty()) {
            reference.bbox.left = group[0].bbox.left;
            reference.bbox.top = group[0].bbox.top;
            reference.bbox.right = group[0].bbox.right;
            reference.bbox.bottom = group[0].bbox.bottom;
            
            for (const auto& seg : group) {
                reference.bbox.left = std::min(reference.bbox.left, seg.bbox.left);
                reference.bbox.top = std::min(reference.bbox.top, seg.bbox.top);
                reference.bbox.right = std::max(reference.bbox.right, seg.bbox.right);
                reference.bbox.bottom = std::max(reference.bbox.bottom, seg.bbox.bottom);
            }
        }
        
        // Try to extract structured information using regex patterns
        extract_reference_fields(full_text, reference);
        
        references.push_back(reference);
    }
    
    return references;
}

// Helper function to extract citation key from inline citation
void extract_citation_key(const std::string& citation_text, 
                          InternalInlineCitation& citation) {
    // Remove parentheses and brackets
    std::string cleaned = citation_text;
    
    // Remove surrounding parentheses
    if (cleaned.length() >= 2 && cleaned.front() == '(' && cleaned.back() == ')') {
        cleaned = cleaned.substr(1, cleaned.length() - 2);
    }
    
    // Remove surrounding brackets
    if (cleaned.length() >= 2 && cleaned.front() == '[' && cleaned.back() == ']') {
        cleaned = cleaned.substr(1, cleaned.length() - 2);
    }
    
    // Extract numeric keys
    std::regex numeric_pattern("([0-9]+(?:-[0-9]+)?(?:,[0-9]+(?:-[0-9]+)?)?)");
    std::smatch match;
    if (std::regex_search(cleaned, match, numeric_pattern)) {
        citation.key = match[1].str();
        return;
    }
    
    // Extract author-year keys
    std::regex author_year_pattern("([A-Z][a-z]+ [0-9]{4})");
    if (std::regex_search(cleaned, match, author_year_pattern)) {
        citation.key = match[1].str();
        return;
    }
    
    // Use the cleaned text as key if no specific pattern matches
    if (!cleaned.empty()) {
        citation.key = cleaned;
    }
}

// Inline citation detection algorithm
std::vector<InternalInlineCitation> detect_inline_citations(
    const std::vector<struct anigma_layout_segment_t>& segments,
    const std::vector<std::regex>& patterns) {
    std::vector<InternalInlineCitation> citations;
    
    if (segments.empty()) {
        return citations;
    }
    
    // Process each segment
    for (const auto& seg : segments) {
        std::string text(seg.text, seg.text_len);
        
        // Check for each pattern
        for (size_t pattern_idx = 0; pattern_idx < patterns.size(); ++pattern_idx) {
            const auto& pattern = patterns[pattern_idx];
            std::smatch matches;
            std::string::const_iterator search_start(text.cbegin());
            
            while (std::regex_search(search_start, text.cend(), matches, pattern)) {
                if (matches.size() >= 1) {
                    InternalInlineCitation citation;
                    citation.text = matches[0].str();
                    citation.bbox = seg.bbox;
                    citation.pattern_index = static_cast<int32_t>(pattern_idx);
                    
                    // Try to extract citation key
                    extract_citation_key(citation.text, citation);
                    
                    citations.push_back(citation);
                }
                
                search_start = matches[0].second;
            }
        }
    }
    
    return citations;
}

} // namespace

// C API Implementation

extern "C" {

anigma_status_t anigma_citation_extraction_get_default_config(
    struct anigma_citation_extraction_config_t* out_config) {
    if (!out_config) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    *out_config = {
        .enable_ml_extraction = false,      // Default to regex for determinism
        .enable_regex_extraction = true,
        .enable_reference_section_detection = true,
        .enable_inline_citation_detection = true,
        .onnx_model_path = nullptr,
        .regex_patterns_path = nullptr
    };
    
    return ANIGMA_STATUS_OK;
}

anigma_status_t anigma_citation_extraction_capsule_create(
    const struct anigma_citation_extraction_config_t* config,
    anigma_capsule_handle_t* out_handle) {
    if (!config || !out_handle) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    try {
        // Create context
        auto ctx = std::make_unique<CitationExtractionContext>(*config);
        
        // Store context in capsule handle
        *out_handle = reinterpret_cast<anigma_capsule_handle_t>(ctx.release());
        
        return ANIGMA_STATUS_OK;
    } catch (...) {
        return ANIGMA_STATUS_ALLOCATION_FAILED;
    }
}

anigma_status_t anigma_citation_extraction_capsule_destroy(
    anigma_capsule_handle_t handle) {
    if (!handle) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    try {
        auto ctx = reinterpret_cast<CitationExtractionContext*>(handle);
        delete ctx;
        return ANIGMA_STATUS_OK;
    } catch (...) {
        return ANIGMA_STATUS_INTERNAL_ERROR;
    }
}

anigma_status_t anigma_citation_extraction_extract_from_segments(
    anigma_capsule_handle_t handle,
    int32_t page_index,
    const struct anigma_layout_segment_t* segments,
    size_t segment_count,
    double page_width,
    double page_height,
    struct anigma_citation_extraction_result_t* out_result) {
    if (!handle || !segments || !out_result) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    try {
        auto ctx = reinterpret_cast<CitationExtractionContext*>(handle);
        
        // Convert segments to vector for processing
        std::vector<struct anigma_layout_segment_t> seg_vec;
        seg_vec.reserve(segment_count);
        for (size_t i = 0; i < segment_count; ++i) {
            seg_vec.push_back(segments[i]);
        }
        
        // Detect reference sections
        std::vector<size_t> reference_sections;
        for (size_t i = 0; i < seg_vec.size(); ++i) {
            std::string text(seg_vec[i].text, seg_vec[i].text_len);
            if (is_reference_section(text, ctx->reference_patterns_)) {
                reference_sections.push_back(i);
            }
        }
        
        // Extract references
        auto references = extract_references(seg_vec, reference_sections);
        
        // Detect inline citations
        auto inline_citations = detect_inline_citations(seg_vec, 
                                                       ctx->inline_citation_patterns_);
        
        // Populate result with deep copies
        out_result->reference_count = references.size();
        out_result->inline_citation_count = inline_citations.size();
        out_result->processing_time_us = 0; // TODO: Measure actual time
        
        // Allocate references array
        if (out_result->reference_count > 0) {
            out_result->references = (struct anigma_citation_reference_t*)malloc(
                sizeof(struct anigma_citation_reference_t) * out_result->reference_count);
            
            if (out_result->references) {
                for (size_t i = 0; i < out_result->reference_count; ++i) {
                    auto& src = references[i];
                    auto& dst = out_result->references[i];
                    
                    dst.reference_id = nullptr; // Optional ID
                    dst.reference_id_len = 0;
                    
                    dst.text = safe_string_dup(src.text);
                    dst.text_len = src.text.length();
                    
                    dst.bounding_box = src.bbox;
                    
                    dst.title = src.title.empty() ? nullptr : safe_string_dup(src.title);
                    dst.title_len = src.title.length();
                    
                    dst.authors = src.author.empty() ? nullptr : safe_string_dup(src.author);
                    dst.authors_len = src.author.length();
                    
                    dst.venue = src.journal.empty() ? nullptr : safe_string_dup(src.journal);
                    dst.venue_len = src.journal.length();
                    
                    dst.year = src.year.empty() ? nullptr : safe_string_dup(src.year);
                    dst.year_len = src.year.length();
                    
                    dst.volume = src.volume.empty() ? nullptr : safe_string_dup(src.volume);
                    dst.volume_len = src.volume.length();
                    
                    dst.issue = nullptr; // Not extracted yet
                    dst.issue_len = 0;
                    
                    dst.pages = src.pages.empty() ? nullptr : safe_string_dup(src.pages);
                    dst.pages_len = src.pages.length();
                    
                    dst.doi = src.doi.empty() ? nullptr : safe_string_dup(src.doi);
                    dst.doi_len = src.doi.length();
                    
                    dst.url = nullptr;
                    dst.url_len = 0;
                }
            } else {
                return ANIGMA_STATUS_ALLOCATION_FAILED;
            }
        } else {
            out_result->references = nullptr;
        }
        
        // Allocate inline citations array
        if (out_result->inline_citation_count > 0) {
            out_result->inline_citations = (struct anigma_inline_citation_t*)malloc(
                sizeof(struct anigma_inline_citation_t) * out_result->inline_citation_count);
            
            if (out_result->inline_citations) {
                for (size_t i = 0; i < out_result->inline_citation_count; ++i) {
                    auto& src = inline_citations[i];
                    auto& dst = out_result->inline_citations[i];
                    
                    dst.text = safe_string_dup(src.text);
                    dst.text_len = src.text.length();
                    
                    dst.bounding_box = src.bbox;
                    
                    dst.key = src.key.empty() ? nullptr : safe_string_dup(src.key);
                    dst.key_len = src.key.length();
                    
                    dst.reference_id = nullptr; // To be linked later
                    dst.reference_id_len = 0;
                    
                    dst.pattern_index = src.pattern_index;
                }
            } else {
                // Cleanup already allocated references
                anigma_citation_extraction_free_result(out_result);
                return ANIGMA_STATUS_ALLOCATION_FAILED;
            }
        } else {
            out_result->inline_citations = nullptr;
        }
        
        return ANIGMA_STATUS_OK;
    } catch (...) {
        return ANIGMA_STATUS_INTERNAL_ERROR;
    }
}

anigma_status_t anigma_citation_extraction_extract_from_pdf(
    anigma_capsule_handle_t handle,
    const uint8_t* pdf_data,
    size_t pdf_size,
    struct anigma_citation_extraction_result_t* out_result) {
    if (!handle || !pdf_data || !out_result) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    // TODO: Implement PDF-based extraction
    // This would use PDFium to extract text and layout information
    
    out_result->references = nullptr;
    out_result->reference_count = 0;
    out_result->inline_citations = nullptr;
    out_result->inline_citation_count = 0;
    out_result->processing_time_us = 0;
    
    return ANIGMA_STATUS_NOT_IMPLEMENTED;
}

anigma_status_t anigma_citation_extraction_free_result(
    struct anigma_citation_extraction_result_t* result) {
    if (!result) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    // Free reference data
    if (result->references) {
        for (size_t i = 0; i < result->reference_count; ++i) {
            auto& ref = result->references[i];
            free((void*)ref.reference_id);
            free((void*)ref.text);
            free((void*)ref.title);
            free((void*)ref.authors);
            free((void*)ref.venue);
            free((void*)ref.year);
            free((void*)ref.volume);
            free((void*)ref.issue);
            free((void*)ref.pages);
            free((void*)ref.doi);
            free((void*)ref.url);
        }
        free(result->references);
        result->references = nullptr;
    }
    
    // Free inline citation data
    if (result->inline_citations) {
        for (size_t i = 0; i < result->inline_citation_count; ++i) {
            auto& cit = result->inline_citations[i];
            free((void*)cit.text);
            free((void*)cit.key);
            free((void*)cit.reference_id);
        }
        free(result->inline_citations);
        result->inline_citations = nullptr;
    }
    
    result->reference_count = 0;
    result->inline_citation_count = 0;
    result->processing_time_us = 0;
    
    return ANIGMA_STATUS_OK;
}

anigma_status_t anigma_reference_export_to_bibtex(
    const struct anigma_citation_reference_t* reference,
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

anigma_status_t anigma_reference_export_to_json(
    const struct anigma_citation_reference_t* reference,
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

anigma_status_t anigma_inline_citation_export_to_json(
    const struct anigma_inline_citation_t* citation,
    const char** out_json,
    size_t* out_json_len) {
    if (!citation || !out_json || !out_json_len) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    // TODO: Implement JSON export
    *out_json = nullptr;
    *out_json_len = 0;
    
    return ANIGMA_STATUS_NOT_IMPLEMENTED;
}

anigma_status_t anigma_citation_free_export(
    const char* data) {
    if (!data) {
        return ANIGMA_STATUS_INVALID_ARGUMENT;
    }
    
    // TODO: Free exported data (when export is implemented with malloc)
    
    return ANIGMA_STATUS_OK;
}

} // extern "C"