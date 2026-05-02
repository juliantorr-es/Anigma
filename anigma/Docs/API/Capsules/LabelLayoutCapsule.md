# Label Layout Capsule API Reference

**Header**: `anigma_viz_label_layout_capsule.h`  
**Determinism Tier**: Tier 1 (bitwise identical across runs)  
**Thread Safety**: Thread‑safe for concurrent operations with distinct handles

## Overview

The Label Layout Capsule computes non‑overlapping label positions for data visualizations (point labels, line callouts, area annotations). It uses deterministic algorithms (simulated annealing with fixed seed) to ensure identical label placement across runs, outputting a canonical label assignment that can be hashed for receipts.

This capsule solves the NP‑hard label placement problem with deterministic guarantees, enabling reproducible visualizations suitable for governance and audit trails.

## Types

### Opaque Handle
```c
typedef anigma_capsule_handle_t anigma_viz_label_layout_capsule_t;
```

### Label Layout Handle
An immutable label layout that can be hashed for receipts.
```c
typedef anigma_capsule_handle_t anigma_viz_label_layout_t;
```

### Label Type
```c
enum anigma_viz_label_type_t {
    ANIGMA_VIZ_LABEL_POINT = 1,      // label attached to a point
    ANIGMA_VIZ_LABEL_LINE = 2,       // label along a line segment
    ANIGMA_VIZ_LABEL_AREA = 3,       // label inside a polygon
    ANIGMA_VIZ_LABEL_CALLOUT = 4     // label with leader line
};
```

### Anchor Point
Point where label is anchored (e.g., data point position).
```c
typedef struct anigma_viz_anchor_t {
    double x;
    double y;
} anigma_viz_anchor_t;
```

### Label Candidate
A potential position for a label.
```c
typedef struct anigma_viz_label_candidate_t {
    anigma_viz_anchor_t anchor;      // anchor point
    double x;                        // label rectangle top‑left x
    double y;                        // label rectangle top‑left y
    double width;                    // label width (normalized)
    double height;                   // label height (normalized)
    double priority;                 // placement priority (0‑1, higher = more important)
    uint32_t allowed_positions;      // bitmask of allowed positions (see below)
} anigma_viz_label_candidate_t;
```

### Allowed Positions Bitmask
```c
#define ANIGMA_VIZ_LABEL_POS_TOP        (1 << 0)
#define ANIGMA_VIZ_LABEL_POS_BOTTOM     (1 << 1)
#define ANIGMA_VIZ_LABEL_POS_LEFT       (1 << 2)
#define ANIGMA_VIZ_LABEL_POS_RIGHT      (1 << 3)
#define ANIGMA_VIZ_LABEL_POS_TOP_LEFT   (1 << 4)
#define ANIGMA_VIZ_LABEL_POS_TOP_RIGHT  (1 << 5)
#define ANIGMA_VIZ_LABEL_POS_BOTTOM_LEFT  (1 << 6)
#define ANIGMA_VIZ_LABEL_POS_BOTTOM_RIGHT (1 << 7)
#define ANIGMA_VIZ_LABEL_POS_CENTER     (1 << 8)
```

### Layout Configuration
```c
typedef struct anigma_viz_label_layout_config_t {
    // Algorithm selection
    enum anigma_viz_label_algorithm_t {
        ANIGMA_VIZ_LABEL_ALGO_SIMULATED_ANNEALING = 1,
        ANIGMA_VIZ_LABEL_ALGO_GREEDY = 2,
        ANIGMA_VIZ_LABEL_ALGO_EXACT = 3
    } algorithm;
    
    // Algorithm parameters
    union {
        struct {
            double initial_temperature;
            double cooling_rate;
            int32_t iterations_per_temperature;
            int32_t max_iterations;
        } simulated_annealing;
        struct {
            int32_t max_candidates_per_label;
        } greedy;
    } params;
    
    // Constraints
    double min_label_spacing;          // minimum distance between labels
    double max_label_offset;           // maximum distance from anchor
    uint32_t allow_overlap : 1;        // allow some overlap (penalized)
    uint32_t allow_rotation : 1;       // allow rotated labels
    uint32_t require_all_labels : 1;   // must place all labels (vs. best subset)
    
    // Determinism knobs
    uint64_t stable_seed;              // for stochastic algorithms
    uint32_t float_rounding_ulps;      // Tier 1 rounding policy
} anigma_viz_label_layout_config_t;
```

### Label Placement Result
```c
typedef struct anigma_viz_label_placement_t {
    uint64_t label_id;                 // identifier from input
    double x;                          // placed position x
    double y;                          // placed position y
    double rotation;                   // rotation in radians (0 if not rotated)
    uint32_t placed : 1;               // whether label was successfully placed
    uint32_t overlaps : 1;             // whether this placement overlaps others
} anigma_viz_label_placement_t;
```

### Conflict Pair
```c
typedef struct anigma_viz_label_conflict_t {
    uint64_t label_id_a;
    uint64_t label_id_b;
    double overlap_area;               // normalized overlap area
} anigma_viz_label_conflict_t;
```

### Layout Quality Metrics
```c
typedef struct anigma_viz_label_quality_t {
    double total_overlap_area;         // sum of all overlap areas
    double average_label_offset;       // average distance from anchors
    uint32_t placed_count;             // number of successfully placed labels
    uint32_t total_count;              // total number of input labels
    double score;                      // overall quality score (0‑1, higher better)
} anigma_viz_label_quality_t;
```

## Core Functions

### `anigma_viz_label_layout_capsule_get_identity`
```c
anigma_capsule_identity_t anigma_viz_label_layout_capsule_get_identity(void);
```
Returns capsule identity information (capsule ID, build hash, algorithm version, determinism tier).

### `anigma_viz_label_layout_capsule_create`
```c
anigma_error_t anigma_viz_label_layout_capsule_create(
    anigma_viz_label_layout_capsule_t* out_capsule
);
```
Creates a label layout capsule handle.

**Parameters**:
- `out_capsule`: Output handle for the created capsule

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_label_layout_capsule_destroy`
```c
void anigma_viz_label_layout_capsule_destroy(
    anigma_viz_label_layout_capsule_t capsule
);
```
Destroys a label layout capsule handle and releases associated resources.

### `anigma_viz_label_layout_capsule_layout_compute`
```c
anigma_error_t anigma_viz_label_layout_capsule_layout_compute(
    anigma_viz_label_layout_capsule_t capsule,
    const anigma_viz_label_candidate_t* candidates,
    size_t candidate_count,
    const anigma_viz_label_layout_config_t* config,
    anigma_viz_label_layout_t* out_layout
);
```
Runs the full label placement algorithm.

**Parameters**:
- `capsule`: Capsule handle
- `candidates`: Array of label candidates
- `candidate_count`: Number of candidates
- `config`: Layout configuration
- `out_layout`: Output label layout handle (caller must destroy)

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_label_layout_capsule_layout_destroy`
```c
void anigma_viz_label_layout_capsule_layout_destroy(
    anigma_viz_label_layout_t layout
);
```
Destroys a label layout handle and releases its resources.

### `anigma_viz_label_layout_capsule_layout_query`
```c
anigma_error_t anigma_viz_label_layout_capsule_layout_query(
    anigma_viz_label_layout_t layout,
    anigma_viz_label_placement_t* out_placements,
    size_t max_placements,
    size_t* out_actual_count
);
```
Returns positioned label rectangles.

**Parameters**:
- `layout`: Label layout handle
- `out_placements`: Output array for placements (caller allocates)
- `max_placements`: Maximum number of placements to return
- `out_actual_count`: Actual number of placements written

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_label_layout_capsule_layout_conflicts`
```c
anigma_error_t anigma_viz_label_layout_capsule_layout_conflicts(
    anigma_viz_label_layout_t layout,
    anigma_viz_label_conflict_t* out_conflicts,
    size_t max_conflicts,
    size_t* out_actual_count
);
```
Returns overlapping label pairs (for manual resolution).

**Parameters**:
- `layout`: Label layout handle
- `out_conflicts`: Output array for conflicts (caller allocates)
- `max_conflicts`: Maximum number of conflicts to return
- `out_actual_count`: Actual number of conflicts written

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_label_layout_capsule_layout_quality`
```c
anigma_error_t anigma_viz_label_layout_capsule_layout_quality(
    anigma_viz_label_layout_t layout,
    anigma_viz_label_quality_t* out_quality
);
```
Returns placement quality metrics.

**Parameters**:
- `layout`: Label layout handle
- `out_quality`: Output quality metrics

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_label_layout_capsule_layout_hash`
```c
anigma_error_t anigma_viz_label_layout_capsule_layout_hash(
    anigma_viz_label_layout_t layout,
    uint8_t out_hash[32]  // 256‑bit hash
);
```
Computes a deterministic hash of the label layout for receipt generation.

**Parameters**:
- `layout`: Label layout handle
- `out_hash`: Output hash buffer (32 bytes)

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_viz_label_layout_capsule_layout_svg`
```c
anigma_error_t anigma_viz_label_layout_capsule_layout_svg(
    anigma_viz_label_layout_t layout,
    const char* label_texts[],        // array of UTF‑8 label texts
    anigma_capsule_buffer_t* out_svg
);
```
Generates an SVG visualization of the label layout (for debugging).

**Parameters**:
- `layout`: Label layout handle
- `label_texts`: Array of label text strings (optional, can be NULL)
- `out_svg`: Output SVG buffer (caller must free)

**Returns**: `ANIGMA_OK` on success, error code on failure.

## Error Codes

```c
enum anigma_error_t {
    ANIGMA_OK = 0,
    ANIGMA_ERR_INVALID_ARGUMENT = 1,
    ANIGMA_ERR_UNSUPPORTED = 2,
    ANIGMA_ERR_OUT_OF_MEMORY = 3,
    ANIGMA_ERR_LAYOUT_NOT_COMPUTED = 5001,
    ANIGMA_ERR_NO_VALID_PLACEMENTS = 5002,
    ANIGMA_ERR_CONSTRAINTS_UNSATISFIABLE = 5003,
    ANIGMA_ERR_SVG_GENERATION_FAILED = 5004
};
```

## Determinism Notes

**Tier 1 requirements**:
- Identical label placements across runs with same seed
- Identical conflict detection
- Identical quality metrics
- Identical hash for identical inputs

**Implementation details**:
- Use deterministic simulated annealing with fixed random seed
- Define canonical ordering for equal‑score placements
- Use fixed‑precision arithmetic for geometric calculations
- Specify tie‑breaking rules for conflict resolution

## Swift Usage Example

```swift
import AnigmaNativeShims
import CapsuleCore

// Compute label placements for chart annotations
func computeLabelPlacements(_ dataPoints: [(id: UInt64, point: CGPoint, text: String)]) throws -> anigma_viz_label_layout_t {
    var capsule: anigma_viz_label_layout_capsule_t?
    var error = anigma_error_t()
    
    let createStatus = anigma_viz_label_layout_capsule_create(&capsule)
    guard createStatus == ANIGMA_OK, let capsule = capsule else {
        throw VizError(status: createStatus)
    }
    
    defer { anigma_viz_label_layout_capsule_destroy(capsule) }
    
    // Create label candidates
    var candidates = dataPoints.map { dataPoint -> anigma_viz_label_candidate_t in
        var candidate = anigma_viz_label_candidate_t()
        candidate.anchor = anigma_viz_anchor_t(
            x: Double(dataPoint.point.x),
            y: Double(dataPoint.point.y)
        )
        // Assume label size based on text length
        candidate.width = 0.05  // normalized width
        candidate.height = 0.02 // normalized height
        candidate.priority = 0.8
        candidate.allowed_positions = 
            ANIGMA_VIZ_LABEL_POS_TOP | 
            ANIGMA_VIZ_LABEL_POS_BOTTOM | 
            ANIGMA_VIZ_LABEL_POS_LEFT | 
            ANIGMA_VIZ_LABEL_POS_RIGHT
        return candidate
    }
    
    // Configure simulated annealing
    var config = anigma_viz_label_layout_config_t()
    config.algorithm = ANIGMA_VIZ_LABEL_ALGO_SIMULATED_ANNEALING
    config.params.simulated_annealing.initial_temperature = 1.0
    config.params.simulated_annealing.cooling_rate = 0.95
    config.params.simulated_annealing.iterations_per_temperature = 100
    config.params.simulated_annealing.max_iterations = 10000
    config.min_label_spacing = 0.01
    config.max_label_offset = 0.1
    config.allow_overlap = 0
    config.require_all_labels = 1
    config.stable_seed = 12345
    config.float_rounding_ulps = 1
    
    var layout: anigma_viz_label_layout_t?
    let computeStatus = anigma_viz_label_layout_capsule_layout_compute(
        capsule,
        candidates,
        candidates.count,
        &config,
        &layout
    )
    
    guard computeStatus == ANIGMA_OK, let layout = layout else {
        throw VizError(status: computeStatus)
    }
    
    return layout
}

// Retrieve placement results
func getLabelPlacements(_ layout: anigma_viz_label_layout_t) throws -> [LabelPlacement] {
    // First query to get count
    var actualCount: size_t = 0
    let queryCountStatus = anigma_viz_label_layout_capsule_layout_query(
        layout,
        nil,  // null buffer to get count
        0,
        &actualCount
    )
    
    guard queryCountStatus == ANIGMA_OK else {
        throw VizError(status: queryCountStatus)
    }
    
    // Allocate buffer and query placements
    var placements = [anigma_viz_label_placement_t](
        repeating: anigma_viz_label_placement_t(),
        count: actualCount
    )
    
    let queryStatus = anigma_viz_label_layout_capsule_layout_query(
        layout,
        &placements,
        actualCount,
        &actualCount
    )
    
    guard queryStatus == ANIGMA_OK else {
        throw VizError(status: queryStatus)
    }
    
    // Convert to Swift types
    return placements.map { placement in
        LabelPlacement(
            id: placement.label_id,
            position: CGPoint(x: placement.x, y: placement.y),
            rotation: placement.rotation,
            placed: placement.placed != 0,
            overlaps: placement.overlaps != 0
        )
    }
}

// Generate SVG for debugging
func generateLabelLayoutSVG(_ layout: anigma_viz_label_layout_t, texts: [String]) throws -> String {
    var svgBuffer = anigma_capsule_buffer_t(ptr: nil, len: 0, cap: 0)
    
    // Convert Swift strings to C strings
    var cStrings = texts.map { strdup($0) }
    defer { cStrings.forEach { free($0) } }
    
    let svgStatus = anigma_viz_label_layout_capsule_layout_svg(
        layout,
        cStrings,
        &svgBuffer
    )
    
    guard svgStatus == ANIGMA_OK else {
        throw VizError(status: svgStatus)
    }
    
    let svgString = String(cString: svgBuffer.ptr!)
    free(svgBuffer.ptr)
    
    return svgString
}
```