# Anigma Runtime Determinism Envelope

## Overview

This document defines the determinism envelope for the Anigma three-layer runtime. All code that touches the kernel boundary must conform to these rules. Violations constitute a governance failure, not a performance optimization.

## Core Principle

**Identical inputs must produce identical outputs, regardless of:**
- CPU microarchitecture
- Compiler version and flags
- Number of threads
- Scheduling decisions
- Wall-clock time
- System load

## Time Representation

### Integer Ticks Only

The kernel **never** uses floating-point time. All time values are represented as integer ticks.

```c
typedef int64_t anigma_time_tick_t;

// Fixed tick resolution: 1 microsecond = 1 tick
static const anigma_time_tick_t ANIGMA_TICKS_PER_SECOND = 1000000LL;

// Conversion from seconds (for API boundaries)
static inline anigma_time_tick_t anigma_time_from_seconds(double seconds) {
    return (anigma_time_tick_t)llround(seconds * (double)ANIGMA_TICKS_PER_SECOND);
}

static inline double anigma_time_to_seconds(anigma_time_tick_t ticks) {
    return (double)ticks / (double)ANIGMA_TICKS_PER_SECOND;
}
```

### Time Rules

1. **No `std::chrono`, `gettimeofday`, or wall-clock access in kernel**
2. **All time inputs come from the orchestrator as integer ticks**
3. **Timeline evaluation uses fixed-step accumulation**
4. **Animation interpolation uses fixed-point arithmetic**

## Coordinate System

### Fixed-Point Coordinates

All coordinates that affect visible output are quantized to a grid.

```c
// Coordinate resolution: 1/256 of a point
typedef int32_t anigma_coordinate_t;
static const int32_t ANIGMA_COORDINATE_SCALE = 256;

static inline anigma_coordinate_t anigma_coord_from_float(float f) {
    return (anigma_coordinate_t)llround(f * (float)ANIGMA_COORDINATE_SCALE);
}

static inline float anigma_coord_to_float(anigma_coordinate_t c) {
    return (float)c / (float)ANIGMA_COORDINATE_SCALE;
}
```

### Coordinate Rules

1. **All output coordinates are snapped to the grid before emission**
2. **Transform matrices operate on fixed-point values**
3. **Hit testing uses the same quantized coordinates as rendering**
4. **No floating-point epsilon comparisons on visible geometry**

## Entity Identity

### Stable Binary IDs Only

Entity IDs are stable 128-bit values derived deterministically in Swift. The kernel receives pre-computed IDs.

```c
typedef struct anigma_entity_id_t {
    uint64_t high;    // Namespace component
    uint64_t low;     // Local component
} anigma_entity_id_t;
```

### ID Generation Rules

1. **Swift orchestrator owns all ID derivation logic**
2. **Kernel receives stable binary IDs, never string hashes**
3. **ID comparison is bitwise equality, never name-based**
4. **New entities use monotonic local counters, never UUIDs**
5. **Generation numbers prevent ID reuse after detach/reattach**

### ID Derivation (Swift, not C++)

```swift
extension EntityId {
    public static func derive(
        from documentNodeId: String,
        namespace: String,
        localCounter: UInt64
    ) -> EntityId {
        // Pre-normalized: document_node_id + namespace + counter
        let input = "\(documentNodeId):\(namespace):\(localCounter)"
        let hash = blake3_128(input.utf8)
        return EntityId(high: hash.prefix(8), low: hash.suffix(8))
    }
}
```

## Ordering and Traversal

### Explicit Traversal Order

All traversal operations must declare and follow explicit ordering rules.

```c
typedef enum anigma_traversal_order {
    ANIGMA_TRAVERSAL_PRE_ORDER = 0,      // Parent before children
    ANIGMA_TRAVERSAL_POST_ORDER = 1,     // Children before parent
    ANIGMA_TRAVERSAL_DEPTH_FIRST = 2,    // Explicit depth tracking
    ANIGMA_TRAVERSAL_LAYER_ORDER = 3,    // Layer-index then render-order
} anigma_traversal_order_t;

// Comparator with explicit tie-breaking
typedef int (*anigma_compare_fn)(
    const void* a,
    const void* b,
    void* context
);
```

### Ordering Rules

1. **Array ordering is stable and explicit**
2. **Sorting always uses explicit tie-breakers**
3. **Tie-breaking order: layer_index, render_order, stable_id**
4. **No iteration over unordered containers for semantic output**
5. **Hash map iteration order never influences output**

## Float Usage Policy

### Restricted Float Operations

Floats are allowed for intermediate calculations only. All outputs that affect visible or semantic results must be snapped.

```c
// Float allowed for: internal math, temporary values
// Float NEVER directly emitted to: render plan, hit test results, state hashes

typedef struct anigma_transform_matrix_t {
    // Internal representation can use float
    float m[3][3];
} anigma_transform_matrix_t;

typedef struct anigma_quantized_transform_t {
    // Output representation uses fixed-point
    anigma_coordinate_t m[3][3];
} anigma_quantized_transform_t;
```

### Float Rules

1. **Output values are always quantized to defined grids**
2. **Rendering uses quantized transforms, not floats**
3. **Hit testing uses quantized coordinates, not floats**
4. **Hash computation uses quantized values, not floats**

## Serialization Contract

### Stable Binary Format

All serialized data must use stable, portable formats.

```c
typedef enum anigma_schema_version {
    ANIGMA_SCHEMA_V1 = 1,
    ANIGMA_SCHEMA_CURRENT = ANIGMA_SCHEMA_V1,
} anigma_schema_version_t;

typedef struct anigma_snapshot_header_t {
    anigma_schema_version_t schema_version;
    uint64_t kernel_build_id;
    uint64_t config_hash;
    uint64_t entity_count;
    uint64_t component_table_size;
    uint8_t header_hash[32];
} anigma_snapshot_header_t;
```

### Serialization Rules

1. **No pointers or addresses in serialized data**
2. **Arrays stored in explicit order, not hash table order**
3. **Field ordering is fixed, never alphabetical**
4. **Strings are UTF-8 with explicit length prefix**
5. **All numeric fields use fixed-width types (uint64_t, not size_t)**

## Diff Application

### Deterministic Diff Rules

```c
typedef enum anigma_diff_op {
    ANIGMA_DIFF_ATTACH = 0,
    ANIGMA_DIFF_DETACH = 1,
    ANIGMA_DIFF_UPDATE = 2,
    ANIGMA_DIFF_TRANSFORM = 3,
    ANIGMA_DIFF_PROPERTY = 4,
} anigma_diff_op_t;

// Diff application is always sequential and ordered
// The orchestrator provides a single batch with explicit ordering
anigma_status_t anigma_diff_apply_batch(
    anigma_soa_storage_t* storage,
    const anigma_diff_batch_t* batch
);
```

### Diff Rules

1. **Diffs are applied in the order provided by orchestrator**
2. **No reordering or parallel application**
3. **All diffs include stable entity IDs**
4. **Diff batches are hashed for verification**

## Hashing and Verification

### Stable Hash Inputs

All hash inputs must be deterministic.

```c
typedef struct anigma_hash_input_t {
    anigma_entity_id_t* entities;     // Sorted by ID
    anigma_property_value_t* values;  // Sorted by property path
    anigma_transform_state_t* transforms;  // Sorted by entity ID
} anigma_hash_input_t;
```

### Hash Rules

1. **Hash inputs are sorted by stable criteria before hashing**
2. **Hashes include schema version and config hash**
3. **Hash computation uses blake3 or similar, not CRC32**
4. **Every boundary produces hashes: event batches, snapshots, plans**

## Determinism Profile

Every kernel operation includes a determinism profile that specifies the rules in effect.

```c
typedef struct anigma_determinism_profile_t {
    uint64_t profile_id;
    anigma_time_tick_t tick_resolution;
    int32_t coordinate_scale;
    uint32_t sort_tie_break_mode;
    uint64_t flags;
} anigma_determinism_profile_t;

static const anigma_determinism_profile_t ANIGMA_PROFILE_DEFAULT = {
    .profile_id = 0x414E49474D410001ULL,  // "ANIGA\0\1"
    .tick_resolution = ANIGMA_TICKS_PER_SECOND,
    .coordinate_scale = ANIGMA_COORDINATE_SCALE,
    .sort_tie_break_mode = 0,  // layer, render_order, entity_id
    .flags = 0,
};
```

## Testing Requirements

### Golden Tests

Every kernel operation must have golden tests:
1. **Same inputs produce same outputs** (run twice, compare hashes)
2. **Commutative operations can be reordered** (test allowed reorderings)
3. **Non-commutative operations maintain order** (test canonicalization)
4. **Integer time produces consistent results** (test fixed-step vs variable)

### Replay Verification

1. **Full session replay matches original hashes**
2. **Checkpoint hashes match between runs**
3. **Divergence reports include minimal reproduction case**
