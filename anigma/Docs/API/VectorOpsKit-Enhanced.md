# VectorOpsKit Enhanced API Documentation

## Overview

The VectorOpsKit provides advanced geometric operations for vector paths with production-ready performance and determinism. This enhanced implementation includes path simplification, transformation matrices, geometric primitives, and comprehensive geometric predicates.

## Architecture

The enhanced VectorOpsKit follows the established "Swift governs, C++ computes" architecture:

- **Swift Layer**: Thread-safe API with actor-based concurrency, zero-copy marshalling, comprehensive error handling
- **C++ Layer**: SIMD-optimized computations using Clipper2 library, deterministic algorithms, memory-efficient operations
- **Capsule Pattern**: Managed resource lifecycle with automatic cleanup and error propagation

## New Features

### 1. Path Simplification Algorithms

#### Douglas-Peucker Simplification
```swift
let simplifiedPath = try vectorOps.douglasPeuckerSimplify(
    path: complexPath, 
    tolerance: 1.0
)
```
- Reduces path complexity while preserving geometric features
- O(n log n) time complexity with guaranteed error bounds
- Tier 1 deterministic (bitwise identical output)

#### Visvalingam Simplification
```swift
let simplifiedPath = try vectorOps.visvalingamSimplify(
    path: complexPath, 
    tolerance: 1.0
)
```
- Area-based simplification preserving topological features
- Better for geographic data and natural curves
- Currently uses Douglas-Peucker as fallback (production implementation planned)

### 2. Transformation Matrix Operations

#### Affine Transformations
```swift
let matrix = TransformationMatrix(a: 1.2, b: 0.1, c: -0.1, d: 1.1, e: 10, f: 5)
let transformedPath = try vectorOps.transform(path: originalPath, matrix: matrix)
```

#### Convenience Methods
```swift
// Translation
let translated = try vectorOps.translate(path: path, dx: 10, dy: 5)

// Rotation
let rotated = try vectorOps.rotate(path: path, angle: .pi/4, centerX: 50, centerY: 50)

// Scaling
let scaled = try vectorOps.scale(path: path, sx: 2.0, sy: 1.5)

// Skewing
let skewed = try vectorOps.skew(path: path, skewX: 0.2, skewY: 0.1)
```

### 3. Advanced Geometric Primitives

#### Bezier Curves
```swift
let bezierPath = try vectorOps.createBezierCurve(
    start: Point(x: 0, y: 0),
    control1: Point(x: 50, y: 100),
    control2: Point(x: 150, y: 100),
    end: Point(x: 200, y: 0)
)
```

#### Arcs and Circles
```swift
let arc = try vectorOps.createArc(
    center: Point(x: 50, y: 50),
    radius: 25,
    startAngle: 0,
    endAngle: .pi
)

let circle = try vectorOps.createCircle(
    center: Point(x: 50, y: 50),
    radius: 25
)
```

### 4. Geometric Predicates

#### Point-in-Polygon Test
```swift
let isInside = try vectorOps.pointInPolygon(
    point: Point(x: 50, y: 50),
    path: polygonPath
)
```

#### Line Intersection
```swift
let intersection = try vectorOps.lineIntersection(
    line1: LineSegment(start: Point(x: 0, y: 0), end: Point(x: 100, y: 100)),
    line2: LineSegment(start: Point(x: 0, y: 100), end: Point(x: 100, y: 0))
)
```

#### Distance Calculations
```swift
let pointDistance = vectorOps.distance(
    point1: Point(x: 0, y: 0),
    point2: Point(x: 3, y: 4)  // Returns 5.0
)

let lineDistance = try vectorOps.distanceToLine(
    point: Point(x: 5, y: 5),
    line: LineSegment(start: Point(x: 0, y: 0), end: Point(x: 10, y: 0))
)
```

### 5. Utility Operations

#### Bounding Box
```swift
let bounds = try vectorOps.getBounds(path: complexPath)
print("Width: \(bounds.width), Height: \(bounds.height)")
print("Center: \(bounds.center)")
```

#### Path Properties
```swift
let isEmpty = try vectorOps.isEmpty(path: path)
let length = try vectorOps.pathLength(path: path)
let smoothed = try vectorOps.smoothPath(path: path, factor: 0.5)
```

## Data Types

### TransformationMatrix
```swift
public struct TransformationMatrix: Sendable {
    public let a, b, c, d, e, f: Double  // [a c e; b d f; 0 0 1]
    
    public static let identity = TransformationMatrix()
    public static func translation(dx: Double, dy: Double) -> TransformationMatrix
    public static func rotation(angle: Double, centerX: Double, centerY: Double) -> TransformationMatrix
    public static func scaling(sx: Double, sy: Double) -> TransformationMatrix
    public static func skew(skewX: Double, skewY: Double) -> TransformationMatrix
}
```

### Geometric Primitives
```swift
public struct Point: Sendable {
    public let x, y: Double
}

public struct LineSegment: Sendable {
    public let start, end: Point
}

public struct BoundingBox: Sendable {
    public let minX, minY, maxX, maxY: Double
    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }
    public var center: Point { Point(x: (minX + maxX) / 2, y: (minY + maxY) / 2) }
}
```

## Performance Characteristics

### Time Complexity
- **Boolean Operations**: O(n log n) where n is total number of vertices
- **Simplification**: O(n log n) for Douglas-Peucker
- **Transformations**: O(n) with SIMD acceleration
- **Geometric Predicates**: O(1) for point tests, O(n) for path operations
- **Primitive Creation**: O(k) where k is subdivision resolution

### Memory Usage
- **Zero-copy marshalling** between Swift and C++ layers
- **Automatic resource management** with capsule pattern
- **SIMD-friendly data layouts** for cache efficiency
- **Deterministic memory usage** with bounded allocations

### Determinism
All operations guarantee **Tier 1 determinism**:
- Identical input produces bitwise identical output
- Platform-independent results
- Reproducible across different executions
- Compatible with receipt format and audit trails

## Error Handling

### Comprehensive Error Codes
```swift
public struct CapsuleError: Error {
    public let status: anigma_status_t
    public let error: anigma_capsule_error_t
}
```

### Common Error Scenarios
- **Invalid input paths**: Malformed SVG strings
- **Degenerate geometry**: Zero-area polygons, coincident points
- **Numerical limits**: Extremely large coordinates, NaN/Inf values
- **Resource constraints**: Memory allocation failures
- **Internal errors**: Algorithmic failures, invariant violations

## Usage Examples

### Complex Shape Composition
```swift
let vectorOps = VectorOps.default

// Create base shapes
let square = "M0,0 L100,0 L100,100 L0,100 Z"
let circle = try vectorOps.createCircle(center: Point(x: 150, y: 50), radius: 40)

// Combine shapes
let composite = try vectorOps.union(pathA: square, pathB: circle)

// Apply transformation
let transformed = try vectorOps.transform(
    path: composite,
    matrix: .rotation(angle: .pi/6, centerX: 75, centerY: 50)
)

// Optimize for rendering
let optimized = try vectorOps.douglasPeuckerSimplify(
    path: transformed,
    tolerance: 0.5
)
```

### Geometric Analysis
```swift
func analyzeComplexity(path: String) throws {
    let bounds = try vectorOps.getBounds(path: path)
    let length = try vectorOps.pathLength(path: path)
    let isEmpty = try vectorOps.isEmpty(path: path)
    
    print("Bounds: \(bounds)")
    print("Path length: \(length)")
    print("Is empty: \(isEmpty)")
    
    // Test random points
    let testPoint = Point(x: bounds.center.x, y: bounds.center.y)
    let containsCenter = try vectorOps.pointInPolygon(point: testPoint, path: path)
    print("Contains center: \(containsCenter)")
}
```

### Batch Processing
```swift
func processBatch(paths: [String]) throws -> [String] {
    return try paths.concurrentMap { path in
        // Simplify first to reduce complexity
        let simplified = try vectorOps.douglasPeuckerSimplify(path: path, tolerance: 1.0)
        
        // Normalize to unit scale
        let bounds = try vectorOps.getBounds(path: simplified)
        let scale = 1.0 / max(bounds.width, bounds.height)
        let scaled = try vectorOps.scale(path: simplified, sx: scale, sy: scale)
        
        // Center at origin
        let centered = try vectorOps.translate(
            path: scaled,
            dx: -bounds.center.x * scale,
            dy: -bounds.center.y * scale
        )
        
        return centered
    }
}
```

## Testing

### Unit Tests
Comprehensive test suite covering:
- All geometric operations with edge cases
- Error handling validation
- Determinism verification
- Performance regression testing

### Benchmarks
Performance metrics for:
- Boolean operations at various complexities
- Simplification algorithm efficiency
- Transformation throughput
- Concurrent operation scalability
- Memory usage patterns

### Validation
- SVG compliance for import/export
- Mathematical correctness verification
- Platform consistency testing
- Determinism audit trails

## Integration Guidelines

### Thread Safety
All operations are **thread-safe** and can be called concurrently:
```swift
let concurrentQueue = DispatchQueue(label: "vector.ops", attributes: .concurrent)
// Safe to call vectorOps methods from multiple threads
```

### Resource Management
Automatic cleanup with capsule pattern:
```swift
// Resources are automatically cleaned up when operations complete
// No manual memory management required
```

### Error Recovery
Graceful degradation for invalid inputs:
```swift
do {
    let result = try vectorOps.complexOperation(path: input)
    // Use result
} catch let error as CapsuleError {
    // Handle specific error cases
    logger.error("Vector operation failed: \(error)")
}
```

## Migration Guide

### From Basic VectorOps
Existing boolean operations remain unchanged:
```swift
// These still work exactly as before
let union = try vectorOps.union(pathA: path1, pathB: path2)
let intersection = try vectorOps.intersection(pathA: path1, pathB: path2)
```

### Adding New Features
Gradual adoption of new capabilities:
```swift
// Start with utility operations
let bounds = try vectorOps.getBounds(path: existingPath)

// Add transformations as needed
let optimized = try vectorOps.douglasPeuckerSimplify(path: existingPath, tolerance: 1.0)
```

## Performance Tips

### Optimization Strategies
1. **Simplify early**: Reduce complexity before expensive operations
2. **Batch transformations**: Chain transforms when possible
3. **Use appropriate tolerances**: Balance quality vs. performance
4. **Leverage concurrency**: Process independent paths in parallel
5. **Monitor memory usage**: Use bounds checking for very large paths

### Common Pitfalls
- **Over-simplification**: Can lose important geometric features
- **Extreme transformations**: May cause numerical instability
- **Concurrent resource sharing**: Each VectorOps instance is independent
- **Error propagation**: Always handle potential CapsuleError exceptions

## Future Enhancements

### Planned Features
- **Complete Visvalingam implementation** with optimized data structures
- **Curve fitting algorithms** for path smoothing
- **Advanced boolean operations** with winding number control
- **Spatial indexing** for large-scale geometric queries
- **GPU acceleration** for massive parallel computations

### Research Areas
- **Machine learning** for adaptive simplification thresholds
- **Progressive meshes** for multi-resolution geometry
- **Topological analysis** for geometric feature extraction
- **Real-time collision detection** for interactive applications