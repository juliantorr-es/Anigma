# CClipper2

A C wrapper system library for Clipper2 polygon clipping, offsetting and triangulation operations.

## Overview

CClipper2 provides a clean C ABI wrapping the Clipper2 C++ library, enabling Swift integration for polygon boolean operations (union, difference, intersection, XOR), offsetting, and triangulation.

## Features

- **Boolean Operations**: Union, Intersection, Difference, XOR
- **Polygon Offsetting**: Inflate/deflate polygons with configurable join types
- **Double Precision Support**: Both 64-bit integer and double precision operations
- **Memory Management**: Proper RAII wrapper with destroy functions
- **Thread Safety**: Thread-local storage for safe concurrent access

## API

### Core Types

```c
// Point types
typedef struct {
    int64_t x;
    int64_t y;
} clipper2_point64_t;

typedef struct {
    double x;
    double y;
} clipper2_point_d_t;

// Opaque path containers
typedef struct clipper2_paths64 clipper2_paths64_t;
typedef struct clipper2_path64 clipper2_path64_t;
typedef struct clipper2_paths_d clipper2_paths_d_t;
typedef struct clipper2_path_d clipper2_path_d_t;
```

### Boolean Operations

```c
// 64-bit integer operations
clipper2_paths64_t* clipper2_intersect_64(
    const clipper2_paths64_t* subjects,
    const clipper2_paths64_t* clips,
    clipper2_fillrule_t fillrule
);

clipper2_paths64_t* clipper2_union_64(
    const clipper2_paths64_t* subjects,
    const clipper2_paths64_t* clips,
    clipper2_fillrule_t fillrule
);

// Double precision operations
clipper2_paths_d_t* clipper2_intersect_d(
    const clipper2_paths_d_t* subjects,
    const clipper2_paths_d_t* clips,
    clipper2_fillrule_t fillrule,
    int precision
);
```

### Offsetting Operations

```c
clipper2_paths64_t* clipper2_inflate_paths_64(
    const clipper2_paths64_t* paths,
    double delta,
    clipper2_jointype_t jointype,
    clipper2_endtype_t endtype,
    double miter_limit,
    double arc_tolerance
);
```

## Integration Notes

This wrapper follows Anigma's system library patterns:
- Located in `Packages/CClipper2/`
- Uses `module.modulemap` for Swift integration
- Proper pkg-config integration for system dependencies
- Memory management through destroy functions

### Dependencies

- **Clipper2**: Integrated as git submodule in `Packages/CClipper2/Clipper2/`
- **System packages**: 
  - Ubuntu: `libclipper2-dev`
  - macOS: `clipper2` (via Homebrew)

## Usage Example

```swift
import CClipper2

// Create paths
let subjectPaths = clipper2_paths64_create()
let subjectPath = clipper2_path64_create()
clipper2_path64_add_point(subjectPath, 0, 0)
clipper2_path64_add_point(subjectPath, 100, 0)
clipper2_path64_add_point(subjectPath, 100, 100)
clipper2_path64_add_point(subjectPath, 0, 100)
clipper2_paths64_add_path(subjectPaths, subjectPath)

// Perform union operation
let result = clipper2_union_64(subjectPaths, nil, CLIPPER2_FILLRULE_EVEN_ODD)

// Use result...
defer { clipper2_paths64_destroy(result) }
```

## Implementation Status

- ✅ Basic C wrapper structure
- ✅ Memory management functions
- ✅ Enum conversions
- ✅ Module map and Swift integration
- ✅ Clipper2 integration (full implementation)
- ✅ Boolean operations (intersect, union, difference, xor)
- ✅ Inflate (offset) operations
- ✅ SVG import/export
- 📋 Testing (basic compilation passes)

## Future Enhancements

1. Add triangulation operations
2. Add rect clipping operations
3. Performance optimizations
4. Comprehensive error handling with CapsuleCore error structures
5. Support for SVG path strings (currently file-based)

## License

This wrapper follows Clipper2's Boost Software License 1.0.