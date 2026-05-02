# Embedding Layout Capsule API Reference

**Header**: `anigma_viz_embedding_layout_capsule.h`  
**Determinism Tier**: Tier 1 (bitwise identical across runs)  
**Thread Safety**: Thread‑safe for concurrent operations with distinct handles

## Overview

The Embedding Layout Capsule projects high‑dimensional embeddings into 2D/3D for visualization (t‑SNE, UMAP, PCA). It produces identical layouts across runs for governance receipts, exposing deterministic seeding and step‑wise iteration for progressive rendering.

This capsule enables deterministic dimensionality reduction for embedding visualizations where reproducibility is required for audit trails and receipt generation.

## Types

### Opaque Handle
```c
typedef anigma_capsule_handle_t anigma_viz_embedding_layout_capsule_t;
```

### Layout Handle
An immutable layout that can be hashed for receipts after completion.
```c
typedef anigma_capsule_handle_t anigma_viz_layout_t;
```

### Layout Algorithm
```c
enum anigma_viz_layout_algorithm_t {
    ANIGMA_VIZ_LAYOUT_TSNE = 1,
    ANIGMA_VIZ_LAYOUT_UMAP = 2,
    ANIGMA_VIZ_LAYOUT_PCA = 3,
    ANIGMA_VIZ_LAYOUT_MDS = 4
};
```

### Dimensionality
```c
enum anigma_viz_output_dim_t {
    ANIGMA_VIZ_OUTPUT_2D = 2,
    ANIGMA_VIZ_OUTPUT_3D = 3
};
```

### Distance Metric
```c
enum anigma_viz_distance_metric_t {
    ANIGMA_VIZ_DISTANCE_EUCLIDEAN = 1,
    ANIGMA_VIZ_DISTANCE_COSINE = 2,
    ANIGMA_VIZ_DISTANCE_MANHATTAN = 3
};
```

### Layout Configuration
```c
typedef struct anigma_viz_layout_config_t {
    enum anigma_viz_layout_algorithm_t algorithm;
    enum anigma_viz_output_dim_t output_dim;
    enum anigma_viz_distance_metric_t metric;
    
    // Algorithm‑specific parameters
    union {
        struct {
            double perplexity;
            double learning_rate;
            int32_t max_iterations;
        } tsne;
        struct {
            double min_dist;
            double spread;
            int32_t n_neighbors;
        } umap;
        struct {
            int32_t n_components;
        } pca;
    } params;
    
    // Determinism knobs
    uint64_t stable_seed;                // must produce identical results across runs
    uint32_t float_rounding_ulps;        // Tier 1 rounding policy
    
    // Progressive rendering
    uint32_t enable_stepwise : 1;        // allow incremental iteration
    uint32_t store_intermediate : 1;     // store coordinates at each iteration
} anigma_viz_layout_config_t;
```

### Layout State
```c
typedef struct anigma_viz_layout_state_t {
    int32_t current_iteration;
    int32_t total_iterations;
    double current_stress;               // layout quality metric
    double current_trustworthiness;      // neighborhood preservation
} anigma_viz_layout_state_t;
```

### Embedding Matrix
Input embeddings as a row‑major matrix.
```c
typedef struct anigma_viz_embedding_matrix_t {
    const double* data;                  // row‑major: [n_points × n_dims]
    size_t n_points;
    size_t n_dims;
} anigma_viz_embedding_matrix_t;
```

### Layout Coordinates
Output coordinates as a row‑major matrix.
```c
typedef struct anigma_viz_layout_coords_t {
    double* data;                        // row‑major: [n_points × output_dim]
    size_t n_points;
    size_t output_dim;
} anigma_viz_layout_coords_t;
```

## Core Functions

### `anigma_viz_embedding_layout_capsule_get_identity`
```c
anigma_capsule_identity_t anigma_viz_embedding_layout_capsule_get_identity(void);
```
Returns capsule identity information (capsule ID, build hash, algorithm version, determinism tier).

### `anigma_viz_embedding_layout_capsule_create`
```c
anigma_error_t anigma_viz_embedding_layout_capsule_create(
    anigma_viz_embedding_layout_capsule_t* out_capsule
);
```
Creates an embedding layout capsule handle.

**Parameters**:
- `out_capsule`: Output handle for the created capsule

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_embedding_layout_capsule_destroy`
```c
void anigma_viz_embedding_layout_capsule_destroy(
    anigma_viz_embedding_layout_capsule_t capsule
);
```
Destroys an embedding layout capsule handle and releases associated resources.

### `anigma_viz_embedding_layout_capsule_layout_compute`
```c
anigma_error_t anigma_viz_embedding_layout_capsule_layout_compute(
    anigma_viz_embedding_layout_capsule_t capsule,
    const anigma_viz_embedding_matrix_t* embeddings,
    const anigma_viz_layout_config_t* config,
    anigma_viz_layout_t* out_layout
);
```
Runs the full layout algorithm to completion.

**Parameters**:
- `capsule`: Capsule handle
- `embeddings`: Input embedding matrix
- `config`: Layout configuration
- `out_layout`: Output layout handle (caller must destroy)

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_embedding_layout_capsule_layout_destroy`
```c
void anigma_viz_embedding_layout_capsule_layout_destroy(
    anigma_viz_layout_t layout
);
```
Destroys a layout handle and releases its resources.

### `anigma_viz_embedding_layout_capsule_layout_step`
```c
anigma_error_t anigma_viz_embedding_layout_capsule_layout_step(
    anigma_viz_layout_t layout,
    int32_t n_steps,
    anigma_viz_layout_state_t* out_state
);
```
Performs a single iteration (or multiple steps) for progressive rendering.

**Parameters**:
- `layout`: Layout handle (must have been created with `enable_stepwise`)
- `n_steps`: Number of iterations to advance (≥1)
- `out_state`: Optional output layout state

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_embedding_layout_capsule_layout_query`
```c
anigma_error_t anigma_viz_embedding_layout_capsule_layout_query(
    anigma_viz_layout_t layout,
    anigma_viz_layout_coords_t* out_coords
);
```
Retrieves current coordinates from the layout.

**Parameters**:
- `layout`: Layout handle
- `out_coords`: Output coordinates (caller must allocate buffer with sufficient capacity)

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_embedding_layout_capsule_layout_metrics`
```c
anigma_error_t anigma_viz_embedding_layout_capsule_layout_metrics(
    anigma_viz_layout_t layout,
    anigma_viz_layout_state_t* out_state
);
```
Computes layout quality metrics (stress, trustworthiness).

**Parameters**:
- `layout`: Layout handle
- `out_state`: Output layout state with metrics

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_embedding_layout_capsule_layout_hash`
```c
anigma_error_t anigma_viz_embedding_layout_capsule_layout_hash(
    anigma_viz_layout_t layout,
    uint8_t out_hash[32]  // 256‑bit hash
);
```
Computes a deterministic hash of the layout state for receipt generation.

**Parameters**:
- `layout`: Layout handle
- `out_hash`: Output hash buffer (32 bytes)

**Returns**: `ANIGMA_OK` on success, error code on failure.

## Error Codes

```c
enum anigma_error_t {
    ANIGMA_OK = 0,
    ANIGMA_ERR_INVALID_ARGUMENT = 1,
    ANIGMA_ERR_UNSUPPORTED = 2,
    ANIGMA_ERR_OUT_OF_MEMORY = 3,
    ANIGMA_ERR_LAYOUT_NOT_READY = 3001,
    ANIGMA_ERR_LAYOUT_FINALIZED = 3002,
    ANIGMA_ERR_STEPWISE_DISABLED = 3003,
    ANIGMA_ERR_METRIC_COMPUTATION_FAILED = 3004
};
```

## Determinism Notes

**Tier 1 requirements**:
- Identical output coordinates across runs with same seed
- Identical iteration trajectory for step‑wise rendering
- Identical hash for identical inputs and configuration
- Stable floating‑point operations with defined rounding

**Implementation details**:
- Use deterministic random number generation with fixed seed
- Define canonical ordering for neighborhood graph construction
- Use fixed‑precision arithmetic for distance calculations
- Specify tie‑breaking rules for equal distances

## Swift Usage Example

```swift
import AnigmaNativeShims
import CapsuleCore

// Create deterministic t‑SNE layout for embeddings
func createTSNELayout(_ embeddings: [[Double]]) throws -> anigma_viz_layout_t {
    var capsule: anigma_viz_embedding_layout_capsule_t?
    var error = anigma_error_t()
    
    let createStatus = anigma_viz_embedding_layout_capsule_create(&capsule)
    guard createStatus == ANIGMA_OK, let capsule = capsule else {
        throw VizError(status: createStatus)
    }
    
    defer { anigma_viz_embedding_layout_capsule_destroy(capsule) }
    
    // Prepare embedding matrix
    let nPoints = embeddings.count
    let nDims = embeddings.first?.count ?? 0
    var flatData = embeddings.flatMap { $0 }
    
    var matrix = anigma_viz_embedding_matrix_t(
        data: &flatData,
        n_points: nPoints,
        n_dims: nDims
    )
    
    // Configure t‑SNE
    var config = anigma_viz_layout_config_t()
    config.algorithm = ANIGMA_VIZ_LAYOUT_TSNE
    config.output_dim = ANIGMA_VIZ_OUTPUT_2D
    config.metric = ANIGMA_VIZ_DISTANCE_EUCLIDEAN
    config.params.tsne.perplexity = 30.0
    config.params.tsne.learning_rate = 200.0
    config.params.tsne.max_iterations = 1000
    config.stable_seed = 12345
    config.float_rounding_ulps = 1
    config.enable_stepwise = 1  // Allow progressive rendering
    
    var layout: anigma_viz_layout_t?
    let computeStatus = anigma_viz_embedding_layout_capsule_layout_compute(
        capsule,
        &matrix,
        &config,
        &layout
    )
    
    guard computeStatus == ANIGMA_OK, let layout = layout else {
        throw VizError(status: computeStatus)
    }
    
    return layout
}

// Perform progressive rendering
func renderLayoutProgressive(_ layout: anigma_viz_layout_t, steps: Int32) throws -> [[Double]] {
    var state = anigma_viz_layout_state_t()
    
    let stepStatus = anigma_viz_embedding_layout_capsule_layout_step(
        layout,
        steps,
        &state
    )
    
    guard stepStatus == ANIGMA_OK else {
        throw VizError(status: stepStatus)
    }
    
    // Query current coordinates
    let nPoints = // ... get from layout metadata
    var coords = anigma_viz_layout_coords_t()
    coords.n_points = nPoints
    coords.output_dim = 2
    coords.data = UnsafeMutablePointer<Double>.allocate(capacity: nPoints * 2)
    
    defer { coords.data.deallocate() }
    
    let queryStatus = anigma_viz_embedding_layout_capsule_layout_query(
        layout,
        &coords
    )
    
    guard queryStatus == ANIGMA_OK else {
        throw VizError(status: queryStatus)
    }
    
    // Convert to Swift array
    var result = [[Double]]()
    for i in 0..<nPoints {
        let x = coords.data[i * 2]
        let y = coords.data[i * 2 + 1]
        result.append([x, y])
    }
    
    return result
}
```