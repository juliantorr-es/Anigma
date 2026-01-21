# Viz LOD Tiling Capsule API Reference

**Header**: `anigma_viz_lod_tiling_capsule.h`  
**Determinism Tier**: Tier 1 (bitwise identical across runs)  
**Thread Safety**: Thread‑safe for concurrent operations with distinct handles

## Overview

The Viz LOD Tiling Capsule creates level‑of‑detail (LOD) tile pyramids for interactive charts that must render at 60fps. Each tile contains aggregated statistics (min/max/mean/count) for geometric data (points, lines, rectangles) at a particular zoom level. The pyramid is computed once deterministically, then tiles can be streamed to the GPU as the user pans/zooms.

This capsule addresses the "interactive big data" problem: datasets too large to render directly, but where aggregation must be pixel‑perfect and deterministic for governance receipts.

## Types

### Opaque Handle
```c
typedef anigma_capsule_handle_t anigma_viz_lod_tiling_capsule_t;
```

### Tile Pyramid Handle
A tile pyramid is an immutable, deterministic structure that can be hashed for receipts.
```c
typedef anigma_capsule_handle_t anigma_viz_tile_pyramid_t;
```

### Geometry Type
```c
enum anigma_viz_geometry_type_t {
    ANIGMA_VIZ_GEOMETRY_POINT_2D = 1,
    ANIGMA_VIZ_GEOMETRY_LINE_2D = 2,
    ANIGMA_VIZ_GEOMETRY_RECT_2D = 3,
    ANIGMA_VIZ_GEOMETRY_POLYGON_2D = 4
};
```

### Coordinate System
All coordinates are in a normalized world space [0,1]×[0,1] with y‑up.
```c
typedef struct anigma_viz_coord_2d_t {
    double x;
    double y;
} anigma_viz_coord_2d_t;
```

### Tile Key
Identifies a tile in the pyramid.
```c
typedef struct anigma_viz_tile_key_t {
    int32_t zoom_level;          // 0 = full extent, higher = more detail
    int32_t tile_x;              // X coordinate in tile grid at this zoom
    int32_t tile_y;              // Y coordinate in tile grid at this zoom
} anigma_viz_tile_key_t;
```

### Tile Statistics
Precomputed statistics for a tile region.
```c
typedef struct anigma_viz_tile_stats_t {
    double min_value;
    double max_value;
    double mean_value;
    uint64_t element_count;
    uint64_t pixel_hit_count;    // approximate pixel coverage for hit‑testing
} anigma_viz_tile_stats_t;
```

### Geometry Element
A single geometric primitive with optional scalar value.
```c
typedef struct anigma_viz_geometry_element_t {
    enum anigma_viz_geometry_type_t type;
    anigma_viz_coord_2d_t vertices[8];  // points: 1, line: 2, rect: 4, polygon: up to 8
    uint32_t vertex_count;
    double scalar_value;          // optional value for aggregation
} anigma_viz_geometry_element_t;
```

### Tile Pyramid Configuration
```c
typedef struct anigma_viz_tile_pyramid_config_t {
    int32_t max_zoom_level;              // maximum LOD depth (0‑based)
    int32_t tile_width_pixels;           // typically 256 or 512
    int32_t tile_height_pixels;          // typically 256 or 512
    
    // Aggregation behavior
    uint32_t compute_min_max : 1;        // compute min/max per tile
    uint32_t compute_mean : 1;           // compute mean per tile
    uint32_t compute_hit_test : 1;       // compute pixel‑hit information
    
    // Determinism knobs
    uint64_t stable_seed;                // for stochastic sampling if enabled
    uint32_t float_rounding_ulps;        // Tier 1 rounding policy
} anigma_viz_tile_pyramid_config_t;
```

## Core Functions

### `anigma_viz_lod_tiling_capsule_get_identity`
```c
anigma_capsule_identity_t anigma_viz_lod_tiling_capsule_get_identity(void);
```
Returns capsule identity information (capsule ID, build hash, algorithm version, determinism tier).

### `anigma_viz_lod_tiling_capsule_create`
```c
anigma_error_t anigma_viz_lod_tiling_capsule_create(
    anigma_viz_lod_tiling_capsule_t* out_capsule
);
```
Creates a viz LOD tiling capsule handle.

**Parameters**:
- `out_capsule`: Output handle for the created capsule

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_lod_tiling_capsule_destroy`
```c
void anigma_viz_lod_tiling_capsule_destroy(anigma_viz_lod_tiling_capsule_t capsule);
```
Destroys a viz LOD tiling capsule handle and releases associated resources.

### `anigma_viz_lod_tiling_capsule_pyramid_create`
```c
anigma_error_t anigma_viz_lod_tiling_capsule_pyramid_create(
    anigma_viz_lod_tiling_capsule_t capsule,
    const anigma_viz_geometry_element_t* elements,
    size_t element_count,
    const anigma_viz_tile_pyramid_config_t* config,
    anigma_viz_tile_pyramid_t* out_pyramid
);
```
Builds a full LOD pyramid from geometric data.

**Parameters**:
- `capsule`: Capsule handle
- `elements`: Array of geometry elements
- `element_count`: Number of elements
- `config`: Pyramid configuration
- `out_pyramid`: Output tile pyramid handle (caller must destroy)

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_lod_tiling_capsule_pyramid_destroy`
```c
void anigma_viz_lod_tiling_capsule_pyramid_destroy(
    anigma_viz_tile_pyramid_t pyramid
);
```
Destroys a tile pyramid handle and releases its resources.

### `anigma_viz_lod_tiling_capsule_tile_fetch`
```c
anigma_error_t anigma_viz_lod_tiling_capsule_tile_fetch(
    anigma_viz_tile_pyramid_t pyramid,
    const anigma_viz_tile_key_t* tile_key,
    anigma_capsule_buffer_t* out_tile_data,
    anigma_viz_tile_stats_t* out_stats
);
```
Retrieves a specific tile (world coordinates + zoom).

**Parameters**:
- `pyramid`: Tile pyramid handle
- `tile_key`: Tile coordinates
- `out_tile_data`: Output buffer for tile data (caller must free)
- `out_stats`: Optional output tile statistics

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_lod_tiling_capsule_tile_statistics`
```c
anigma_error_t anigma_viz_lod_tiling_capsule_tile_statistics(
    anigma_viz_tile_pyramid_t pyramid,
    const anigma_viz_tile_key_t* tile_key,
    anigma_viz_tile_stats_t* out_stats
);
```
Returns precomputed statistics for a tile region without fetching the full tile data.

**Parameters**:
- `pyramid`: Tile pyramid handle
- `tile_key`: Tile coordinates
- `out_stats`: Output tile statistics

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_lod_tiling_capsule_tile_hit_test`
```c
anigma_error_t anigma_viz_lod_tiling_capsule_tile_hit_test(
    anigma_viz_tile_pyramid_t pyramid,
    const anigma_viz_tile_key_t* tile_key,
    anigma_viz_coord_2d_t pixel_coord,
    uint32_t* out_element_indices,
    size_t max_indices,
    size_t* out_found_count
);
```
Determines which data elements intersect a screen pixel within a tile.

**Parameters**:
- `pyramid`: Tile pyramid handle
- `tile_key`: Tile coordinates
- `pixel_coord`: Pixel coordinates within the tile (normalized 0‑1)
- `out_element_indices`: Output array for element indices
- `max_indices`: Maximum indices to return
- `out_found_count`: Number of elements found (may be larger than returned)

**Returns**: `ANIGMA_OK` on success, error code on failure.

## Error Codes

```c
enum anigma_error_t {
    ANIGMA_OK = 0,
    ANIGMA_ERR_INVALID_ARGUMENT = 1,
    ANIGMA_ERR_UNSUPPORTED = 2,
    ANIGMA_ERR_OUT_OF_MEMORY = 3,
    ANIGMA_ERR_PYRAMID_INVALID = 2001,
    ANIGMA_ERR_TILE_NOT_FOUND = 2002,
    ANIGMA_ERR_HIT_TEST_UNSUPPORTED = 2003
};
```

## Determinism Notes

**Tier 1 requirements**:
- Tile boundaries must be identical across runs
- Aggregated statistics (min/max/mean) must be bitwise identical
- Element ordering within tiles must be deterministic (stable spatial sorting)
- Hash of tile pyramid must be identical given identical input

**Implementation details**:
- Use fixed‑point arithmetic for tile coordinate calculations
- Define canonical ordering for elements that span tile boundaries
- Use deterministic rounding for statistics aggregation

## Swift Usage Example

```swift
import AnigmaNativeShims
import CapsuleCore

// Create tile pyramid for interactive point cloud
func createPointCloudPyramid(_ points: [CGPoint], values: [Double]) throws -> anigma_viz_tile_pyramid_t {
    var capsule: anigma_viz_lod_tiling_capsule_t?
    var error = anigma_error_t()
    
    let createStatus = anigma_viz_lod_tiling_capsule_create(&capsule)
    guard createStatus == ANIGMA_OK, let capsule = capsule else {
        throw VizError(status: createStatus)
    }
    
    defer { anigma_viz_lod_tiling_capsule_destroy(capsule) }
    
    // Convert points to geometry elements
    var elements = [anigma_viz_geometry_element_t]()
    for (index, point) in points.enumerated() {
        var element = anigma_viz_geometry_element_t()
        element.type = ANIGMA_VIZ_GEOMETRY_POINT_2D
        element.vertices[0] = anigma_viz_coord_2d_t(x: Double(point.x), y: Double(point.y))
        element.vertex_count = 1
        element.scalar_value = values[index]
        elements.append(element)
    }
    
    var config = anigma_viz_tile_pyramid_config_t()
    config.max_zoom_level = 8
    config.tile_width_pixels = 256
    config.tile_height_pixels = 256
    config.compute_min_max = 1
    config.compute_mean = 1
    config.stable_seed = 12345
    config.float_rounding_ulps = 1
    
    var pyramid: anigma_viz_tile_pyramid_t?
    let pyramidStatus = anigma_viz_lod_tiling_capsule_pyramid_create(
        capsule,
        elements,
        elements.count,
        &config,
        &pyramid
    )
    
    guard pyramidStatus == ANIGMA_OK, let pyramid = pyramid else {
        throw VizError(status: pyramidStatus)
    }
    
    return pyramid
}

// Fetch tile for rendering
func fetchTile(_ pyramid: anigma_viz_tile_pyramid_t, zoom: Int32, x: Int32, y: Int32) throws -> (Data, anigma_viz_tile_stats_t) {
    var tileKey = anigma_viz_tile_key_t(zoom_level: zoom, tile_x: x, tile_y: y)
    var tileBuffer = anigma_capsule_buffer_t(ptr: nil, len: 0, cap: 0)
    var stats = anigma_viz_tile_stats_t()
    
    let fetchStatus = anigma_viz_lod_tiling_capsule_tile_fetch(
        pyramid,
        &tileKey,
        &tileBuffer,
        &stats
    )
    
    guard fetchStatus == ANIGMA_OK else {
        throw VizError(status: fetchStatus)
    }
    
    // Convert buffer to Data
    let tileData = Data(bytes: tileBuffer.ptr!, count: tileBuffer.len)
    
    // Caller must free tileBuffer.ptr
    free(tileBuffer.ptr)
    
    return (tileData, stats)
}
```