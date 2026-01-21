# Vector Capsule API Reference

**Header**: `anigma_vector_capsule.h`  
**Determinism Tier**: Tier 1 (bitwise identical across runs)  
**Thread Safety**: Thread-safe for concurrent operations with distinct handles

## Overview

The Vector Capsule provides 2D vector path operations for boolean geometry, SVG path import/export, and canonical binary representation. It supports operations like union, intersection, difference, and XOR between vector shapes, with deterministic Tier 1 guarantees for receipt generation.

## Types

### Opaque Handle
```c
typedef anigma_capsule_handle_t anigma_vector_capsule_t;
```

### Boolean Operation Types
```c
typedef enum {
    ANIGMA_VECTOR_OP_UNION = 0,
    ANIGMA_VECTOR_OP_DIFFERENCE = 1,
    ANIGMA_VECTOR_OP_INTERSECTION = 2,
    ANIGMA_VECTOR_OP_XOR = 3
} anigma_vector_op_t;
```

### Fill Rule Types
```c
typedef enum {
    ANIGMA_VECTOR_FILL_EVEN_ODD = 0,
    ANIGMA_VECTOR_FILL_NON_ZERO = 1,
    ANIGMA_VECTOR_FILL_POSITIVE = 2,
    ANIGMA_VECTOR_FILL_NEGATIVE = 3
} anigma_vector_fillrule_t;
```

## Core Functions

### `anigma_vector_capsule_get_identity`
```c
anigma_capsule_identity_t anigma_vector_capsule_get_identity(void);
```
Returns capsule identity information (capsule ID, build hash, algorithm version, determinism tier).

### `anigma_vector_capsule_create_from_svg`
```c
anigma_status_t anigma_vector_capsule_create_from_svg(
    const char* svg_path,
    anigma_vector_capsule_t* out_handle,
    anigma_capsule_error_t* err
);
```
Creates a vector capsule handle from an SVG path string (e.g., "M0,0 L100,0 L100,100 L0,100 Z").

**Parameters**:
- `svg_path`: Null-terminated SVG path string
- `out_handle`: Output handle for the created vector capsule
- `err`: Error output structure

**Returns**: `ANIGMA_OK` on success, error code on failure.

### `anigma_vector_capsule_destroy`
```c
anigma_status_t anigma_vector_capsule_destroy(
    anigma_vector_capsule_t handle,
    anigma_capsule_error_t* err
);
```
Destroys a vector capsule handle and releases associated resources.

## Boolean Operations

### `anigma_vector_capsule_boolean_op`
```c
anigma_status_t anigma_vector_capsule_boolean_op(
    anigma_vector_capsule_t subject,
    anigma_vector_capsule_t clip,
    anigma_vector_op_t op,
    anigma_vector_fillrule_t fillrule,
    anigma_vector_capsule_t* out_result,
    anigma_capsule_error_t* err
);
```
Performs boolean operation between two vector capsules and returns a new handle with the result.

**Parameters**:
- `subject`: Subject vector capsule
- `clip`: Clip vector capsule
- `op`: Boolean operation type (union, difference, intersection, XOR)
- `fillrule`: Fill rule for the operation
- `out_result`: Output handle for the result
- `err`: Error output structure

### `anigma_vector_capsule_boolean_op_in_place`
```c
anigma_status_t anigma_vector_capsule_boolean_op_in_place(
    anigma_vector_capsule_t subject,
    anigma_vector_capsule_t clip,
    anigma_vector_op_t op,
    anigma_vector_fillrule_t fillrule,
    anigma_capsule_error_t* err
);
```
Performs boolean operation in-place, modifying the subject capsule.

## Export Functions

### `anigma_vector_capsule_export_to_svg`
```c
anigma_status_t anigma_vector_capsule_export_to_svg(
    anigma_vector_capsule_t handle,
    char** out_svg_string,
    anigma_capsule_error_t* err
);
```
Exports vector capsule to SVG path string. The output string is capsule-allocated and must be freed with `anigma_capsule_free_buffer`.

### `anigma_vector_capsule_export_canonical`
```c
anigma_status_t anigma_vector_capsule_export_canonical(
    anigma_vector_capsule_t handle,
    anigma_capsule_buffer_t* out_buffer,
    anigma_capsule_error_t* err
);
```
Exports vector capsule to canonical binary format (receipt format). Uses caller-allocated buffer with two-phase filling pattern.

**Canonical Binary Format**:
```
[num_paths: uint32_t]
for each path:
    [point_count: uint32_t]
    [points: double[2 * point_count]]  // x1, y1, x2, y2, ...
```

All integers are little-endian. Doubles are IEEE 754 binary64 little-endian.

### `anigma_vector_capsule_create_from_canonical`
```c
anigma_status_t anigma_vector_capsule_create_from_canonical(
    const anigma_capsule_buffer_t* buffer,
    anigma_vector_capsule_t* out_handle,
    anigma_capsule_error_t* err
);
```
Creates vector capsule from canonical binary format.

## Utility Functions

### `anigma_vector_capsule_is_empty`
```c
anigma_status_t anigma_vector_capsule_is_empty(
    anigma_vector_capsule_t handle,
    bool* out_empty,
    anigma_capsule_error_t* err
);
```
Checks if a vector capsule is empty (contains no paths).

### `anigma_vector_capsule_get_bounds`
```c
anigma_status_t anigma_vector_capsule_get_bounds(
    anigma_vector_capsule_t handle,
    double* out_min_x,
    double* out_min_y,
    double* out_max_x,
    double* out_max_y,
    anigma_capsule_error_t* err
);
```
Gets bounding box of vector capsule.

## Error Handling

All functions return `anigma_status_t` with `ANIGMA_OK` (0) on success. On failure, the error structure `anigma_capsule_error_t` contains:
- `code`: Error code (e.g., `ANIGMA_ERR_INVALID_ARG`)
- `message`: Human-readable error message
- `detail`: Optional detailed error information
- `aux`: Optional auxiliary numeric data (e.g., required buffer size)

Common error codes:
- `ANIGMA_ERR_INVALID_ARG`: Invalid argument (e.g., null handle)
- `ANIGMA_ERR_BUFFER_TOO_SMALL`: Output buffer too small (required size in `aux`)
- `ANIGMA_ERR_INTERNAL`: Internal capsule error

## Swift Usage Example

```swift
import AnigmaNativeShims
import CapsuleCore

// Create a vector capsule from an SVG path string
func createSquare() throws -> CapsuleHandle<AnyObject> {
    var handle: anigma_vector_capsule_t?
    var error = anigma_capsule_error_t()
    let status = anigma_vector_capsule_create_from_svg(
        "M0,0 L100,0 L100,100 L0,100 Z",
        &handle,
        &error
    )
    guard status == ANIGMA_OK, let handle = handle else {
        throw CapsuleError(status: status, error: error)
    }
    return CapsuleHandle<AnyObject>(
        rawHandle: handle,
        destroyFunction: anigma_vector_capsule_destroy
    )
}

// Perform boolean union of two shapes
func unionShapes(_ shape1: CapsuleHandle<AnyObject>, _ shape2: CapsuleHandle<AnyObject>) throws -> CapsuleHandle<AnyObject> {
    var resultHandle: anigma_vector_capsule_t?
    var error = anigma_capsule_error_t()
    try shape1.withHandle { handle1 in
        try shape2.withHandle { handle2 in
            let status = anigma_vector_capsule_boolean_op(
                handle1,
                handle2,
                ANIGMA_VECTOR_OP_UNION,
                ANIGMA_VECTOR_FILL_EVEN_ODD,
                &resultHandle,
                &error
            )
            guard status == ANIGMA_OK, let result = resultHandle else {
                throw CapsuleError(status: status, error: error)
            }
            return CapsuleHandle<AnyObject>(
                rawHandle: result,
                destroyFunction: anigma_vector_capsule_destroy
            )
        }
    }
}

// Export to SVG path string
func exportToSVG(_ capsule: CapsuleHandle<AnyObject>) throws -> String {
    var svgString: UnsafeMutablePointer<CChar>?
    var error = anigma_capsule_error_t()
    try capsule.withHandle { handle in
        let status = anigma_vector_capsule_export_to_svg(handle, &svgString, &error)
        guard status == ANIGMA_OK, let svg = svgString else {
            throw CapsuleError(status: status, error: error)
        }
        defer { anigma_capsule_free_buffer(svg, &error) }
        return String(cString: svg)
    }
}
```