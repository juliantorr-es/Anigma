/**
 * DiffCapsule - C++ compute capsule for document diffing
 *
 * This capsule provides high-performance document diffing and version comparison
 * using advanced algorithms (difflib, libdiff, etc.).
 *
 * Architecture: "Swift governs, C++ computes"
 * Determinism Tier: Tier 1 (bitwise identical)
 */

#ifndef ANIGMA_DIFF_CAPSULE_H
#define ANIGMA_DIFF_CAPSULE_H

#include "anigma_capsule_core.h"
#include "anigma_status.h"
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Diff operation types
 */
enum anigma_diff_op_type_t {
    /** No change */
    ANIGMA_DIFF_OP_EQUAL = 0,
    /** Deletion */
    ANIGMA_DIFF_OP_DELETE = 1,
    /** Insertion */
    ANIGMA_DIFF_OP_INSERT = 2,
    /** Replacement */
    ANIGMA_DIFF_OP_REPLACE = 3
};

/**
 * Diff operation representation
 */
struct anigma_diff_op_t {
    /** Operation type */
    enum anigma_diff_op_type_t op_type;
    /** Text for this operation */
    const char* text;
    /** Text length */
    size_t text_len;
    /** Line number in original document */
    int32_t original_line;
    /** Line number in modified document */
    int32_t modified_line;
};

/**
 * Document version representation
 */
struct anigma_document_version_t {
    /** Document ID */
    const char* doc_id;
    /** Document ID length */
    size_t doc_id_len;
    /** Document content */
    const char* content;
    /** Content length */
    size_t content_len;
    /** Version timestamp */
    uint64_t timestamp;
    /** Author */
    const char* author;
    /** Author length */
    size_t author_len;
    /** Version message */
    const char* message;
    /** Message length */
    size_t message_len;
};

/**
 * Document diff result
 */
struct anigma_document_diff_result_t {
    /** Diff operations */
    struct anigma_diff_op_t* operations;
    /** Number of operations */
    size_t op_count;
    /** Original document version */
    struct anigma_document_version_t original;
    /** Modified document version */
    struct anigma_document_version_t modified;
    /** Similarity score (0-1) */
    float similarity;
    /** Total processing time in microseconds */
    uint64_t processing_time_us;
};

/**
 * Diff configuration
 */
struct anigma_diff_config_t {
    /** Enable line-based diff */
    bool enable_line_diff;
    /** Enable word-based diff */
    bool enable_word_diff;
    /** Enable character-based diff */
    bool enable_char_diff;
    /** Ignore whitespace */
    bool ignore_whitespace;
    /** Ignore case */
    bool ignore_case;
    /** Context lines around changes */
    int32_t context_lines;
};

/**
 * Default diff configuration
 */
anigma_status_t anigma_diff_get_default_config(
    struct anigma_diff_config_t* out_config
);

/**
 * Create diff capsule context
 *
 * @param config Diff configuration
 * @param out_handle Output capsule handle
 * @return Status code
 */
anigma_status_t anigma_diff_capsule_create(
    const struct anigma_diff_config_t* config,
    anigma_capsule_handle_t* out_handle
);

/**
 * Destroy diff capsule context
 *
 * @param handle Capsule handle
 * @return Status code
 */
anigma_status_t anigma_diff_capsule_destroy(
    anigma_capsule_handle_t handle
);

/**
 * Compute diff between two documents
 *
 * @param handle Capsule handle
 * @param original_doc Original document content
 * @param original_doc_len Original document length
 * @param modified_doc Modified document content
 * @param modified_doc_len Modified document length
 * @param out_result Output diff result
 * @return Status code
 */
anigma_status_t anigma_diff_compute(
    anigma_capsule_handle_t handle,
    const char* original_doc,
    size_t original_doc_len,
    const char* modified_doc,
    size_t modified_doc_len,
    struct anigma_document_diff_result_t* out_result
);

/**
 * Compute diff between two document versions
 *
 * @param handle Capsule handle
 * @param original Original document version
 * @param modified Modified document version
 * @param out_result Output diff result
 * @return Status code
 */
anigma_status_t anigma_diff_compute_from_versions(
    anigma_capsule_handle_t handle,
    const struct anigma_document_version_t* original,
    const struct anigma_document_version_t* modified,
    struct anigma_document_diff_result_t* out_result
);

/**
 * Free diff result
 *
 * @param result Diff result to free
 * @return Status code
 */
anigma_status_t anigma_diff_free_result(
    struct anigma_document_diff_result_t* result
);

/**
 * Export diff to unified format
 *
 * @param result Diff result
 * @param out_unified Output unified diff string
 * @param out_unified_len Output unified diff length
 * @return Status code
 */
anigma_status_t anigma_diff_export_to_unified(
    const struct anigma_document_diff_result_t* result,
    const char** out_unified,
    size_t* out_unified_len
);

/**
 * Export diff to JSON
 *
 * @param result Diff result
 * @param out_json Output JSON string
 * @param out_json_len Output JSON length
 * @return Status code
 */
anigma_status_t anigma_diff_export_to_json(
    const struct anigma_document_diff_result_t* result,
    const char** out_json,
    size_t* out_json_len
);

/**
 * Free exported data
 *
 * @param data Data to free
 * @return Status code
 */
anigma_status_t anigma_diff_free_export(
    const char* data
);

#ifdef __cplusplus
}
#endif

#endif // ANIGMA_DIFF_CAPSULE_H
