# Spatial Index Capsule API Reference

**Header**: `anigma_viz_spatial_index_capsule.h`  
**Determinism Tier**: Tier 1 (bitwise identical across runs)  
**Thread Safety**: Thread‑safe for concurrent read operations with distinct handles; writes require exclusive access

## Overview

The Spatial Index Capsule builds deterministic spatial indexes (R‑tree, quadtree) for geometric data. It enables fast spatial queries (range, nearest‑neighbor, ray‑casting) in visualizations while maintaining deterministic index construction for receipt generation.

This capsule provides the spatial acceleration structure needed for interactive visualizations with large geometric datasets, ensuring identical query results across runs.

## Types

### Opaque Handle
```c
typedef anigma_capsule_handle_t anigma_viz_spatial_index_capsule_t;
```

### Spatial Index Handle
An immutable spatial index that can be hashed for receipts.
```c
typedef anigma_capsule_handle_t anigma_viz_spatial_index_t;
```

### Index Type
```c
enum anigma_viz_index_type_t {
    ANIGMA_VIZ_INDEX_RTREE = 1,
    ANIGMA_VIZ_INDEX_QUADTREE = 2,
    ANIGMA_VIZ_INDEX_KD_TREE = 3
};
```

### Bounding Box
Axis‑aligned bounding box in normalized world space [0,1]×[0,1].
```c
typedef struct anigma_viz_bbox_t {
    double min_x;
    double min_y;
    double max_x;
    double max_y;
} anigma_viz_bbox_t;
```

### Geometry Reference
Reference to a geometric element with associated data.
```c
typedef struct anigma_viz_geometry_ref_t {
    uint64_t element_id;                // unique identifier
    anigma_viz_bbox_t bbox;             // tight bounding box
    const void* user_data;              // optional opaque data
    size_t user_data_size;
} anigma_viz_geometry_ref_t;
```

### Query Result
```c
typedef struct anigma_viz_query_result_t {
    uint64_t* element_ids;              // matching element IDs
    size_t count;                       // number of matches
    size_t capacity;                    // allocated capacity (for two‑phase fill)
} anigma_viz_query_result_t;
```

### Index Configuration
```c
typedef struct anigma_viz_index_config_t {
    enum anigma_viz_index_type_t type;
    
    // R‑tree parameters
    union {
        struct {
            uint32_t max_children;      // maximum children per node
            uint32_t min_children;      // minimum children per node
        } rtree;
        struct {
            uint32_t max_depth;         // maximum tree depth
            uint32_t max_elements_per_leaf; // elements per leaf node
        } quadtree;
        struct {
            uint32_t max_depth;
            uint32_t max_elements_per_leaf;
        } kdtree;
    } params;
    
    // Determinism knobs
    uint64_t stable_seed;               // for deterministic node splitting
    uint32_t float_rounding_ulps;       // Tier 1 rounding policy
    
    // Performance flags
    uint32_t store_element_data : 1;    // store element data in index
    uint32_t enable_bulk_load : 1;      // use bulk loading for initial build
} anigma_viz_index_config_t;
```

### Ray Definition
```c
typedef struct anigma_viz_ray_t {
    double origin_x;
    double origin_y;
    double direction_x;                 // normalized vector
    double direction_y;
    double max_t;                       // maximum distance along ray
} anigma_viz_ray_t;
```

### Nearest Neighbor Query
```c
typedef struct anigma_viz_nn_query_t {
    double query_x;
    double query_y;
    uint32_t k;                         // number of neighbors to return
    double max_distance;                // maximum search radius (≤0 for unlimited)
} anigma_viz_nn_query_t;
```

## Core Functions

### `anigma_viz_spatial_index_capsule_get_identity`
```c
anigma_capsule_identity_t anigma_viz_spatial_index_capsule_get_identity(void);
```
Returns capsule identity information (capsule ID, build hash, algorithm version, determinism tier).

### `anigma_viz_spatial_index_capsule_create`
```c
anigma_error_t anigma_viz_spatial_index_capsule_create(
    anigma_viz_spatial_index_capsule_t* out_capsule
);
```
Creates a spatial index capsule handle.

**Parameters**:
- `out_capsule`: Output handle for the created capsule

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_spatial_index_capsule_destroy`
```c
void anigma_viz_spatial_index_capsule_destroy(
    anigma_viz_spatial_index_capsule_t capsule
);
```
Destroys a spatial index capsule handle and releases associated resources.

### `anigma_viz_spatial_index_capsule_index_build`
```c
anigma_error_t anigma_viz_spatial_index_capsule_index_build(
    anigma_viz_spatial_index_capsule_t capsule,
    const anigma_viz_geometry_ref_t* elements,
    size_t element_count,
    const anigma_viz_index_config_t* config,
    anigma_viz_spatial_index_t* out_index
);
```
Constructs a spatial index from geometric elements.

**Parameters**:
- `capsule`: Capsule handle
- `elements`: Array of geometry references
- `element_count`: Number of elements
- `config`: Index configuration
- `out_index`: Output spatial index handle (caller must destroy)

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_spatial_index_capsule_index_destroy`
```c
void anigma_viz_spatial_index_capsule_index_destroy(
    anigma_viz_spatial_index_t index
);
```
Destroys a spatial index handle and releases its resources.

### `anigma_viz_spatial_index_capsule_index_query_range`
```c
anigma_error_t anigma_viz_spatial_index_capsule_index_query_range(
    anigma_viz_spatial_index_t index,
    const anigma_viz_bbox_t* query_bbox,
    anigma_viz_query_result_t* out_result
);
```
Returns elements within a bounding box.

**Parameters**:
- `index`: Spatial index handle
- `query_bbox`: Query bounding box
- `out_result`: Output query result (caller must free element_ids)

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_spatial_index_capsule_index_query_nearest`
```c
anigma_error_t anigma_viz_spatial_index_capsule_index_query_nearest(
    anigma_viz_spatial_index_t index,
    const anigma_viz_nn_query_t* query,
    anigma_viz_query_result_t* out_result
);
```
Returns k‑nearest neighbors to a query point.

**Parameters**:
- `index`: Spatial index handle
- `query`: Nearest‑neighbor query specification
- `out_result`: Output query result (caller must free element_ids)

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_spatial_index_capsule_index_query_ray`
```c
anigma_error_t anigma_viz_spatial_index_capsule_index_query_ray(
    anigma_viz_spatial_index_t index,
    const anigma_viz_ray_t* ray,
    anigma_viz_query_result_t* out_result
);
```
Returns elements intersecting a ray.

**Parameters**:
- `index`: Spatial index handle
- `ray`: Ray definition
- `out_result`: Output query result (caller must free element_ids)

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_spatial_index_capsule_index_hash`
```c
anigma_error_t anigma_viz_spatial_index_capsule_index_hash(
    anigma_viz_spatial_index_t index,
    uint8_t out_hash[32]  // 256‑bit hash
);
```
Computes a deterministic hash of the spatial index for receipt generation.

**Parameters**:
- `index`: Spatial index handle
- `out_hash`: Output hash buffer (32 bytes)

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_spatial_index_capsule_index_statistics`
```c
anigma_error_t anigma_viz_spatial_index_capsule_index_statistics(
    anigma_viz_spatial_index_t index,
    uint32_t* out_node_count,
    uint32_t* out_depth,
    double* out_avg_fill_factor
);
```
Returns statistics about the spatial index.

**Parameters**:
- `index`: Spatial index handle
- `out_node_count`: Optional output node count
- `out_depth`: Optional output tree depth
- `out_avg_fill_factor`: Optional output average fill factor

**Returns**: `ANIGMA_OK` on success, error code on failure.

## Error Codes

```c
enum anigma_error_t {
    ANIGMA_OK = 0,
    ANIGMA_ERR_INVALID_ARGUMENT = 1,
    ANIGMA_ERR_UNSUPPORTED = 2,
    ANIGMA_ERR_OUT_OF_MEMORY = 3,
    ANIGMA_ERR_INDEX_NOT_BUILT = 4001,
    ANIGMA_ERR_QUERY_TOO_LARGE = 4002,
    ANIGMA_ERR_RAY_INVALID = 4003,
    ANIGMA_ERR_NEIGHBOR_NOT_FOUND = 4004
};
```

## Determinism Notes

**Tier 1 requirements**:
- Identical index structure across runs with same input and seed
- Identical query results (element IDs and ordering)
- Identical hash for identical inputs
- Stable sorting of equal‑distance elements

**Implementation details**:
- Use deterministic node splitting algorithms
- Define canonical ordering for equal‑distance elements
- Use fixed‑precision arithmetic for spatial calculations
- Specify tie‑breaking rules for geometric comparisons

## Swift Usage Example

```swift
import AnigmaNativeShims
import CapsuleCore

// Build deterministic R‑tree for geometric elements
func buildSpatialIndex(_ elements: [(id: UInt64, bbox: CGRect)]) throws -> anigma_viz_spatial_index_t {
    var capsule: anigma_viz_spatial_index_capsule_t?
    var error = anigma_error_t()
    
    let createStatus = anigma_viz_spatial_index_capsule_create(&capsule)
    guard createStatus == ANIGMA_OK, let capsule = capsule else {
        throw VizError(status: createStatus)
    }
    
    defer { anigma_viz_spatial_index_capsule_destroy(capsule) }
    
    // Convert elements to geometry references
    var geometryRefs = elements.map { element -> anigma_viz_geometry_ref_t in
        var ref = anigma_viz_geometry_ref_t()
        ref.element_id = element.id
        ref.bbox = anigma_viz_bbox_t(
            min_x: Double(element.bbox.minX),
            min_y: Double(element.bbox.minY),
            max_x: Double(element.bbox.maxX),
            max_y: Double(element.bbox.maxY)
        )
        return ref
    }
    
    // Configure R‑tree
    var config = anigma_viz_index_config_t()
    config.type = ANIGMA_VIZ_INDEX_RTREE
    config.params.rtree.max_children = 16
    config.params.rtree.min_children = 8
    config.stable_seed = 12345
    config.float_rounding_ulps = 1
    config.enable_bulk_load = 1
    
    var index: anigma_viz_spatial_index_t?
    let buildStatus = anigma_viz_spatial_index_capsule_index_build(
        capsule,
        geometryRefs,
        geometryRefs.count,
        &config,
        &index
    )
    
    guard buildStatus == ANIGMA_OK, let index = index else {
        throw VizError(status: buildStatus)
    }
    
    return index
}

// Query elements within a viewport
func queryViewport(_ index: anigma_viz_spatial_index_t, viewport: CGRect) throws -> [UInt64] {
    var queryBox = anigma_viz_bbox_t(
        min_x: Double(viewport.minX),
        min_y: Double(viewport.minY),
        max_x: Double(viewport.maxX),
        max_y: Double(viewport.maxY)
    )
    
    // Two‑phase query: first get count, then allocate
    var result = anigma_viz_query_result_t()
    result.element_ids = nil
    result.count = 0
    result.capacity = 0
    
    let queryStatus = anigma_viz_spatial_index_capsule_index_query_range(
        index,
        &queryBox,
        &result
    )
    
    guard queryStatus == ANIGMA_OK else {
        throw VizError(status: queryStatus)
    }
    
    // Convert to Swift array
    let elementIds = Array(UnsafeBufferPointer(start: result.element_ids, count: result.count))
    
    // Free allocated memory
    free(result.element_ids)
    
    return elementIds
}

// Find nearest neighbors for tooltip positioning
func findNearestElements(_ index: anigma_viz_spatial_index_t, point: CGPoint, k: Int) throws -> [UInt64] {
    var query = anigma_viz_nn_query_t()
    query.query_x = Double(point.x)
    query.query_y = Double(point.y)
    query.k = UInt32(k)
    query.max_distance = 0.1  // Search within 10% of viewport
    
    var result = anigma_viz_query_result_t()
    result.element_ids = nil
    result.count = 0
    result.capacity = 0
    
    let queryStatus = anigma_viz_spatial_index_capsule_index_query_nearest(
        index,
        &query,
        &result
    )
    
    guard queryStatus == ANIGMA_OK else {
        throw VizError(status: queryStatus)
    }
    
    let elementIds = Array(UnsafeBufferPointer(start: result.element_ids, count: result.count))
    free(result.element_ids)
    
    return elementIds
}
```