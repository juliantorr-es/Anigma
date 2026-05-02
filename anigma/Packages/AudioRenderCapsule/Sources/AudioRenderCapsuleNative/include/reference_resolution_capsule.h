/**
 * ReferenceResolutionCapsule - C++ compute capsule for reference resolution
 *
 * This capsule provides high-performance reference resolution and matching
 * against bibliographic databases (CrossRef, PubMed, etc.).
 *
 * Architecture: "Swift governs, C++ computes"
 * Determinism Tier: Tier 1 (bitwise identical)
 */

#ifndef ANIGMA_REFERENCE_RESOLUTION_CAPSULE_H
#define ANIGMA_REFERENCE_RESOLUTION_CAPSULE_H

#include "anigma_capsule_core.h"
#include "anigma_status.h"
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Resolved reference representation
 */
struct anigma_resolved_reference_t {
    /** Original reference ID */
    const char* original_id;
    /** Original reference ID length */
    size_t original_id_len;
    /** Resolved DOI */
    const char* doi;
    /** DOI length */
    size_t doi_len;
    /** Resolved PubMed ID */
    const char* pubmed_id;
    /** PubMed ID length */
    size_t pubmed_id_len;
    /** Resolved CrossRef ID */
    const char* crossref_id;
    /** CrossRef ID length */
    size_t crossref_id_len;
    /** Resolved title */
    const char* title;
    /** Title length */
    size_t title_len;
    /** Resolved authors */
    const char* authors;
    /** Authors length */
    size_t authors_len;
    /** Resolved year */
    const char* year;
    /** Year length */
    size_t year_len;
    /** Resolved journal */
    const char* journal;
    /** Journal length */
    size_t journal_len;
    /** Resolved volume */
    const char* volume;
    /** Volume length */
    size_t volume_len;
    /** Resolved issue */
    const char* issue;
    /** Issue length */
    size_t issue_len;
    /** Resolved pages */
    const char* pages;
    /** Pages length */
    size_t pages_len;
    /** Match confidence score (0-1) */
    float confidence;
    /** Match status */
    int32_t match_status;
};

/**
 * Reference resolution result
 */
struct anigma_reference_resolution_result_t {
    /** Resolved references */
    struct anigma_resolved_reference_t* resolved_references;
    /** Number of resolved references */
    size_t resolved_count;
    /** Unresolved references */
    struct anigma_resolved_reference_t* unresolved_references;
    /** Number of unresolved references */
    size_t unresolved_count;
    /** Total processing time in microseconds */
    uint64_t processing_time_us;
};

/**
 * Reference resolution configuration
 */
struct anigma_reference_resolution_config_t {
    /** Enable online database lookup */
    bool enable_online_lookup;
    /** Enable fuzzy matching */
    bool enable_fuzzy_matching;
    /** Fuzzy matching threshold (0-1) */
    float fuzzy_threshold;
    /** Enable caching */
    bool enable_caching;
    /** Cache directory path */
    const char* cache_dir;
    /** CrossRef API endpoint */
    const char* crossref_endpoint;
    /** PubMed API endpoint */
    const char* pubmed_endpoint;
};

/**
 * Default reference resolution configuration
 */
anigma_status_t anigma_reference_resolution_get_default_config(
    struct anigma_reference_resolution_config_t* out_config
);

/**
 * Create reference resolution capsule context
 *
 * @param config Reference resolution configuration
 * @param out_handle Output capsule handle
 * @return Status code
 */
anigma_status_t anigma_reference_resolution_capsule_create(
    const struct anigma_reference_resolution_config_t* config,
    anigma_capsule_handle_t* out_handle
);

/**
 * Destroy reference resolution capsule context
 *
 * @param handle Capsule handle
 * @return Status code
 */
anigma_status_t anigma_reference_resolution_capsule_destroy(
    anigma_capsule_handle_t handle
);

/**
 * Resolve references
 *
 * @param handle Capsule handle
 * @param references Input references to resolve
 * @param reference_count Number of references
 * @param out_result Output resolution result
 * @return Status code
 */
anigma_status_t anigma_reference_resolution_resolve(
    anigma_capsule_handle_t handle,
    const struct anigma_citation_reference_t* references,
    size_t reference_count,
    struct anigma_reference_resolution_result_t* out_result
);

/**
 * Free reference resolution result
 *
 * @param result Reference resolution result to free
 * @return Status code
 */
anigma_status_t anigma_reference_resolution_free_result(
    struct anigma_reference_resolution_result_t* result
);

/**
 * Export resolved reference to BibTeX
 *
 * @param reference Resolved reference to export
 * @param out_bibtex Output BibTeX string
 * @param out_bibtex_len Output BibTeX length
 * @return Status code
 */
anigma_status_t anigma_resolved_reference_export_to_bibtex(
    const struct anigma_resolved_reference_t* reference,
    const char** out_bibtex,
    size_t* out_bibtex_len
);

/**
 * Export resolved reference to JSON
 *
 * @param reference Resolved reference to export
 * @param out_json Output JSON string
 * @param out_json_len Output JSON length
 * @return Status code
 */
anigma_status_t anigma_resolved_reference_export_to_json(
    const struct anigma_resolved_reference_t* reference,
    const char** out_json,
    size_t* out_json_len
);

/**
 * Free exported data
 *
 * @param data Data to free
 * @return Status code
 */
anigma_status_t anigma_reference_resolution_free_export(
    const char* data
);

#ifdef __cplusplus
}
#endif

#endif // ANIGMA_REFERENCE_RESOLUTION_CAPSULE_H
