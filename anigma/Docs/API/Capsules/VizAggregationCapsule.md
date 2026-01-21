# Viz Aggregation Capsule API Reference

**Header**: `anigma_viz_aggregation_capsule.h`  
**Determinism Tier**: Tier 1 (bitwise identical across runs) for deterministic mode; Tier 2 allowed for approximate sketches  
**Thread Safety**: Thread‑safe for concurrent operations with distinct handles

## Overview

The Viz Aggregation Capsule produces plot‑ready derived datasets from columnar inputs. It implements the "expensive prep" for charts: filtering, sorting, grouping, aggregation, binning, quantiles, histograms, window functions, and time‑series resampling. It is designed to emit deterministic, canonical outputs suitable for governance receipts and replay.

This capsule does not render. It produces derived columnar datasets, plus optional summary metadata (domains, tick suggestions, quantile tables) that the renderer can consume without guessing.

## Types

### Opaque Handle
```c
typedef anigma_capsule_handle_t anigma_viz_aggregation_capsule_t;
```

### Dataset Handle (borrowed abstraction)
If you already have a dataset/blob capsule, wire to it. If not, this capsule accepts raw columnar buffers via `anigma_viz_column_view_t`.
```c
typedef anigma_capsule_handle_t anigma_viz_dataset_t;
```

### Scalar Types
```c
enum anigma_viz_scalar_type_t {
    ANIGMA_VIZ_SCALAR_I64 = 1,
    ANIGMA_VIZ_SCALAR_U64 = 2,
    ANIGMA_VIZ_SCALAR_F64 = 3,
    ANIGMA_VIZ_SCALAR_F32 = 4,
    ANIGMA_VIZ_SCALAR_BOOL = 5,
    ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC = 6,
    ANIGMA_VIZ_SCALAR_STRING_UTF8 = 7
};
```

### Null Semantics
```c
enum anigma_viz_null_policy_t {
    ANIGMA_VIZ_NULL_DISALLOW = 0,   // error if any null present in referenced columns
    ANIGMA_VIZ_NULL_DROP_ROWS = 1,  // drop rows with nulls in referenced columns
    ANIGMA_VIZ_NULL_PROPAGATE = 2   // propagate nulls to output where applicable
};
```

### Determinism Mode
```c
enum anigma_viz_aggregation_mode_t {
    ANIGMA_VIZ_AGG_MODE_DETERMINISTIC = 1, // Tier 1: stable sorting, stable rounding, canonical tie‑breakers
    ANIGMA_VIZ_AGG_MODE_FAST = 2           // Tier 2: may use sketches/approximations if enabled
};
```

### Aggregation Functions
```c
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
```

### Time Resampling
```c
enum anigma_viz_time_bucket_t {
    ANIGMA_VIZ_TIME_BUCKET_SECOND = 1,
    ANIGMA_VIZ_TIME_BUCKET_MINUTE = 2,
    ANIGMA_VIZ_TIME_BUCKET_HOUR = 3,
    ANIGMA_VIZ_TIME_BUCKET_DAY = 4,
    ANIGMA_VIZ_TIME_BUCKET_WEEK = 5,
    ANIGMA_VIZ_TIME_BUCKET_MONTH = 6
};
```

### Filter Predicate
```c
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
```

### Column Reference
```c
typedef struct anigma_viz_column_ref_t {
    const char* name;                 // UTF‑8, stable
    enum anigma_viz_scalar_type_t type;
} anigma_viz_column_ref_t;
```

### Plan Specification
A plan is a canonical, serializable recipe. Swift can hash this for receipts.
```c
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
```

### Result Metadata
```c
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
```

## Core Functions

### `anigma_viz_aggregation_capsule_get_identity`
```c
anigma_capsule_identity_t anigma_viz_aggregation_capsule_get_identity(void);
```
Returns capsule identity information (capsule ID, build hash, algorithm version, determinism tier).

### `anigma_viz_aggregation_capsule_create`
```c
anigma_error_t anigma_viz_aggregation_capsule_create(
    anigma_viz_aggregation_capsule_t* out_capsule
);
```
Creates a viz aggregation capsule handle.

**Parameters**:
- `out_capsule`: Output handle for the created capsule

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_aggregation_capsule_destroy`
```c
void anigma_viz_aggregation_capsule_destroy(anigma_viz_aggregation_capsule_t capsule);
```
Destroys a viz aggregation capsule handle and releases associated resources.

### `anigma_viz_aggregation_capsule_execute`
```c
anigma_error_t anigma_viz_aggregation_capsule_execute(
    anigma_viz_aggregation_capsule_t capsule,
    anigma_viz_dataset_t input,
    const anigma_viz_aggregation_plan_t* plan,
    anigma_viz_dataset_t* out_derived,
    anigma_viz_aggregation_meta_t* out_meta
);
```
Executes a plan over an input dataset and produces a derived dataset plus optional metadata.

**Parameters**:
- `capsule`: Capsule handle
- `input`: Input dataset handle
- `plan`: Aggregation plan specification
- `out_derived`: Output derived dataset handle (caller must destroy)
- `out_meta`: Optional output metadata (caller must free with `anigma_viz_aggregation_capsule_free_meta`)

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_aggregation_capsule_free_meta`
```c
void anigma_viz_aggregation_capsule_free_meta(
    anigma_viz_aggregation_meta_t* meta
);
```
Frees metadata allocated by `anigma_viz_aggregation_capsule_execute`.

## Error Codes

```c
enum anigma_error_t {
    ANIGMA_OK = 0,
    ANIGMA_ERR_INVALID_ARGUMENT = 1,
    ANIGMA_ERR_UNSUPPORTED = 2,
    ANIGMA_ERR_OUT_OF_MEMORY = 3,
    ANIGMA_ERR_DATASET_SCHEMA_MISMATCH = 1001,
    ANIGMA_ERR_NULL_POLICY_VIOLATION = 1002,
    ANIGMA_ERR_DETERMINISM_VIOLATION = 1003
};
```

## Determinism Notes

**Tier 1 requirements**:
- Stable sorting with canonical tie‑breakers
- Stable hash for group keys
- Defined floating‑point rounding policy (via `float_rounding_ulps`)
- Defined quantile selection rules for even‑count medians
- Month/week bucketing must be explicitly UTC‑based unless plan specifies timezone semantics at the dataset level

**Tier 2 allowances**:
- May use sketches or approximations when `mode` is `ANIGMA_VIZ_AGG_MODE_FAST`
- Must still honor `stable_seed` if nonzero

## Swift Usage Example

```swift
import AnigmaNativeShims
import CapsuleCore

// Create aggregation plan for a simple chart
func createChartAggregationPlan() -> anigma_viz_aggregation_plan_t {
    var plan = anigma_viz_aggregation_plan_t()
    plan.mode = ANIGMA_VIZ_AGG_MODE_DETERMINISTIC
    plan.null_policy = ANIGMA_VIZ_NULL_DROP_ROWS
    
    // Select columns: time and value
    var columns = [
        anigma_viz_column_ref_t(name: "timestamp", type: ANIGMA_VIZ_SCALAR_TIMESTAMP_MS_UTC),
        anigma_viz_column_ref_t(name: "value", type: ANIGMA_VIZ_SCALAR_F64)
    ]
    plan.select_columns = &columns
    plan.select_columns_count = 2
    
    // Group by day
    plan.group_by = &columns[0] // timestamp column
    plan.group_by_count = 1
    
    // Aggregations: mean value per day
    var aggSpecs = buildAggregationSpecs()
    plan.aggregations = aggSpecs
    plan.aggregations_bytes = MemoryLayout.size(ofValue: aggSpecs)
    
    plan.stable_seed = 12345
    plan.float_rounding_ulps = 1
    
    return plan
}

// Execute aggregation
func prepareChartData(_ dataset: anigma_viz_dataset_t) throws -> (anigma_viz_dataset_t, anigma_viz_aggregation_meta_t) {
    var capsule: anigma_viz_aggregation_capsule_t?
    var error = anigma_error_t()
    
    let createStatus = anigma_viz_aggregation_capsule_create(&capsule)
    guard createStatus == ANIGMA_OK, let capsule = capsule else {
        throw VizError(status: createStatus)
    }
    
    defer { anigma_viz_aggregation_capsule_destroy(capsule) }
    
    let plan = createChartAggregationPlan()
    var derived: anigma_viz_dataset_t?
    var meta = anigma_viz_aggregation_meta_t()
    
    let execStatus = anigma_viz_aggregation_capsule_execute(
        capsule,
        dataset,
        &plan,
        &derived,
        &meta
    )
    
    guard execStatus == ANIGMA_OK, let derived = derived else {
        throw VizError(status: execStatus)
    }
    
    // Caller is responsible for destroying derived dataset and freeing meta
    return (derived, meta)
}
```