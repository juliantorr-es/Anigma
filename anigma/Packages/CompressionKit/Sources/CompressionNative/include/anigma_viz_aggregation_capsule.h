#ifndef ANIGMA_VIZ_AGGREGATION_CAPSULE_H
#define ANIGMA_VIZ_AGGREGATION_CAPSULE_H

#include "anigma_capsule_core.h"

#if defined(__cplusplus)
extern "C" {
#endif

// ============================================================================
// Viz Aggregation Capsule Types
// ============================================================================

// Opaque handle for viz aggregation capsule context
typedef anigma_capsule_handle_t anigma_viz_aggregation_capsule_t;

// Dataset handle (borrowed abstraction)
typedef anigma_capsule_handle_t anigma_viz_dataset_t;

// Scalar types
enum anigma_viz_scalar_type_t {
    ANIGMA_VIZ_SCALAR_I64 = 1,
    ANIGMA_VIZ_SCALAR_U64 = 2,
    ANIGMA_VIZ_SCALAR_F64 = 3,
    ANIGMA_VIZ_SCALAR_F32 = 4,
    ANIGMA_VIZ_SCALAR_BOOL = 5,
    ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC = 6,
    ANIGMA_VIZ_SCALAR_STRING_UTF8 = 7
};

// Null semantics
enum anigma_viz_null_policy_t {
    ANIGMA_VIZ_NULL_DISALLOW = 0,   // error if any null present in referenced columns
    ANIGMA_VIZ_NULL_DROP_ROWS = 1,  // drop rows with nulls in referenced columns
    ANIGMA_VIZ_NULL_PROPAGATE = 2   // propagate nulls to output where applicable
};

// Determinism mode
enum anigma_viz_aggregation_mode_t {
    ANIGMA_VIZ_AGG_MODE_DETERMINISTIC = 1, // Tier 1: stable sorting, stable rounding, canonical tie‑breakers
    ANIGMA_VIZ_AGG_MODE_FAST = 2           // Tier 2: may use sketches/approximations if enabled
};

// Aggregation functions
enum anigma_viz_agg_fn_t {
    ANIGMA_VIZ_AGG_COUNT = 1,
    ANIGMA_VIZ_AGG_COUNT_DISTINCT = 2,
    ANIGMA_VIZ_AGG_SUM = 3,
    ANIGMA_VIZ_AGG_MEAN = 4,
    ANIGMA_VIZ_AGG_MIN = 5,
    ANIGMA_VIZ_AGG_MAX = 6,
    ANIGMA_VIZ_AGG_MEDIAN = 7,      // deterministic selection rules defined for even counts
    ANIGMA_VIZ_AGG_QUANTILE = 8,    // p provided in spec
    ANIGMA_VIZ_AGG_STDDEV = 9,      // population stddev with deterministic rounding policy
    ANIGMA_VIZ_AGG_VARIANCE = 10
};

// Time resampling
enum anigma_viz_time_bucket_t {
    ANIGMA_VIZ_TIME_BUCKET_SECOND = 1,
    ANIGMA_VIZ_TIME_BUCKET_MINUTE = 2,
    ANIGMA_VIZ_TIME_BUCKET_HOUR = 3,
    ANIGMA_VIZ_TIME_BUCKET_DAY = 4,
    ANIGMA_VIZ_TIME_BUCKET_WEEK = 5,
    ANIGMA_VIZ_TIME_BUCKET_MONTH = 6
};

// Filter predicate
enum anigma_viz_predicate_op_t {
    ANIGMA_VIZ_PRED_EQ = 1,
    ANIGMA_VIZ_PRED_NEQ = 2,
    ANIGMA_VIZ_PRED_LT = 3,
    ANIGMA_VIZ_PRED_LTE = 4,
    ANIGMA_VIZ_PRED_GT = 5,
    ANIGMA_VIZ_PRED_GTE = 6,
    ANIGMA_VIZ_PRED_IN_SET = 7,
    ANIGMA_VIZ_PRED_BETWEEN = 8,
    ANIGMA_VIZ_PRED_IS_NULL = 9,
    ANIGMA_VIZ_PRED_IS_NOT_NULL = 10
};

// Column reference
typedef struct anigma_viz_column_ref_t {
    const char* name;                 // UTF‑8, stable
    enum anigma_viz_scalar_type_t type;
} anigma_viz_column_ref_t;

// Plan specification
typedef struct anigma_viz_aggregation_plan_t {
    enum anigma_viz_aggregation_mode_t mode;
    enum anigma_viz_null_policy_t null_policy;

    const anigma_viz_column_ref_t* select_columns;
    size_t select_columns_count;

    // Optional filter predicate list (AND semantics)
    const void* predicates;          // opaque predicate AST, built via builder API
    size_t predicates_bytes;

    // Optional group‑by
    const anigma_viz_column_ref_t* group_by;
    size_t group_by_count;

    // Aggregations over groups
    const void* aggregations;        // opaque agg specs, built via builder API
    size_t aggregations_bytes;

    // Optional sort keys
    const void* sort_keys;           // opaque sort specs
    size_t sort_keys_bytes;

    // Optional limit
    uint32_t limit_rows;

    // Determinism knobs
    uint64_t stable_seed;            // must be honored even in FAST mode if nonzero
    uint32_t float_rounding_ulps;    // Tier 1 rounding policy for F32/F64 ops
} anigma_viz_aggregation_plan_t;

// Result metadata
typedef struct anigma_viz_aggregation_meta_t {
    // Per numeric column: min/max
    const void* domains;        // opaque typed table
    size_t domains_bytes;

    // Optional quantile table
    const void* quantiles;      // opaque typed table
    size_t quantiles_bytes;

    // Suggested tick step (deterministic algorithm)
    const void* ticks;          // opaque typed table
    size_t ticks_bytes;
} anigma_viz_aggregation_meta_t;

// ============================================================================
// Dataset Management Types
// ============================================================================

// Column view for raw columnar data input
typedef struct anigma_viz_column_view_t {
    const char* name;                 // UTF‑8 column name
    enum anigma_viz_scalar_type_t type;
    const void* data;                 // Pointer to column data
    size_t element_count;             // Number of elements in column
    size_t element_size;              // Size of each element in bytes (0 for variable-length strings)
    const void* null_bitmap;          // Optional null bitmap (1 bit per element, 1 = null)
    size_t null_bitmap_size;          // Size of null bitmap in bytes
} anigma_viz_column_view_t;

// ============================================================================
// Core Functions
// ============================================================================

/**
 * Returns capsule identity information.
 */
anigma_capsule_identity_t anigma_viz_aggregation_capsule_get_identity(void);

/**
 * Creates a viz aggregation capsule handle.
 *
 * @param out_capsule Output handle for the created capsule
 * @param err Error output
 * @return ANIGMA_OK on success, error code on failure
 */
anigma_status_t anigma_viz_aggregation_capsule_create(
    anigma_viz_aggregation_capsule_t* out_capsule,
    anigma_capsule_error_t* err
);

/**
 * Destroys a viz aggregation capsule handle and releases associated resources.
 *
 * @param capsule Capsule handle to destroy
 * @param err Error output
 * @return ANIGMA_OK on success
 */
anigma_status_t anigma_viz_aggregation_capsule_destroy(
    anigma_viz_aggregation_capsule_t capsule,
    anigma_capsule_error_t* err
);

/**
 * Creates a dataset from column views.
 *
 * @param columns Array of column views
 * @param column_count Number of columns
 * @param out_dataset Output dataset handle (caller must destroy)
 * @param err Error output
 * @return ANIGMA_OK on success, error code on failure
 */
anigma_status_t anigma_viz_dataset_create_from_columns(
    const anigma_viz_column_view_t* columns,
    size_t column_count,
    anigma_viz_dataset_t* out_dataset,
    anigma_capsule_error_t* err
);

/**
 * Destroys a dataset handle and releases associated resources.
 *
 * @param dataset Dataset handle to destroy
 * @param err Error output
 * @return ANIGMA_OK on success
 */
anigma_status_t anigma_viz_dataset_destroy(
    anigma_viz_dataset_t dataset,
    anigma_capsule_error_t* err
);

/**
 * Gets the number of columns in a dataset.
 *
 * @param dataset Dataset handle
 * @param out_column_count Output column count
 * @param err Error output
 * @return ANIGMA_OK on success
 */
anigma_status_t anigma_viz_dataset_get_column_count(
    anigma_viz_dataset_t dataset,
    size_t* out_column_count,
    anigma_capsule_error_t* err
);

/**
 * Gets information about a column in a dataset.
 *
 * @param dataset Dataset handle
 * @param column_index Column index (0-based)
 * @param out_info Output column information
 * @param err Error output
 * @return ANIGMA_OK on success
 */
anigma_status_t anigma_viz_dataset_get_column_info(
    anigma_viz_dataset_t dataset,
    size_t column_index,
    anigma_viz_column_ref_t* out_info,
    anigma_capsule_error_t* err
);

/**
 * Gets pointer to column data.
 * The returned pointer is valid until the dataset is destroyed.
 *
 * @param dataset Dataset handle
 * @param column_index Column index (0-based)
 * @param out_data Output data pointer
 * @param out_element_count Output element count
 * @param err Error output
 * @return ANIGMA_OK on success
 */
anigma_status_t anigma_viz_dataset_get_column_data(
    anigma_viz_dataset_t dataset,
    size_t column_index,
    const void** out_data,
    size_t* out_element_count,
    anigma_capsule_error_t* err
);

/**
 * Executes a plan over an input dataset and produces a derived dataset plus optional metadata.
 *
 * @param capsule Capsule handle
 * @param input Input dataset handle
 * @param plan Aggregation plan specification
 * @param out_derived Output derived dataset handle (caller must destroy)
 * @param out_meta Optional output metadata (caller must free with anigma_viz_aggregation_capsule_free_meta)
 * @param err Error output
 * @return ANIGMA_OK on success, error code on failure
 */
anigma_status_t anigma_viz_aggregation_capsule_execute(
    anigma_viz_aggregation_capsule_t capsule,
    anigma_viz_dataset_t input,
    const anigma_viz_aggregation_plan_t* plan,
    anigma_viz_dataset_t* out_derived,
    anigma_viz_aggregation_meta_t* out_meta,
    anigma_capsule_error_t* err
);

/**
 * Frees metadata allocated by anigma_viz_aggregation_capsule_execute.
 *
 * @param meta Metadata to free
 */
void anigma_viz_aggregation_capsule_free_meta(
    anigma_viz_aggregation_meta_t* meta
);

// ============================================================================
// Extended Error Codes
// ============================================================================

// Base error codes are defined in anigma_native_common.h
// Additional viz aggregation specific error codes
enum anigma_viz_aggregation_error_t {
    ANIGMA_VIZ_ERR_DATASET_SCHEMA_MISMATCH = 1001,
    ANIGMA_VIZ_ERR_NULL_POLICY_VIOLATION = 1002,
    ANIGMA_VIZ_ERR_DETERMINISM_VIOLATION = 1003
};

#if defined(__cplusplus)
}
#endif

#endif // ANIGMA_VIZ_AGGREGATION_CAPSULE_H