import Foundation
import AnigmaNativeShims
import CapsuleCore

/// Thread-safe vector capsule wrapper using the capsule architecture.
public final class VectorCapsuleWrapper: VectorOps {
    private let lock = NSLock()
    private var handle: CapsuleHandle<AnyObject>?
    
    public init() {}
    
    deinit {
        lock.withLock {
            handle?.invalidate()
        }
    }
    
    // MARK: - VectorOps Protocol
    
    public func union(pathA: String, pathB: String) throws -> String {
        return try performBooleanOperation(pathA: pathA, pathB: pathB, op: ANIGMA_VECTOR_OP_UNION)
    }
    
    // MARK: - Private Helpers
    
    private func performBooleanOperation(pathA: String, pathB: String, op: anigma_vector_op_t) throws -> String {
        let handleA = try createCapsuleFromSVG(pathA)
        let handleB = try createCapsuleFromSVG(pathB)
        
        defer {
            handleA.invalidate()
            handleB.invalidate()
        }
        
        let resultHandle = try performBooleanOperation(handleA: handleA, handleB: handleB, op: op)
        defer { resultHandle.invalidate() }
        
        return try exportToSVG(resultHandle)
    }
    
    private func createCapsuleFromSVG(_ svgPath: String) throws -> CapsuleHandle<AnyObject> {
        var rawHandle: anigma_vector_capsule_t?
        var error = anigma_capsule_error_t()
        
        let status = anigma_vector_capsule_create_from_svg(svgPath, &rawHandle, &error)
        guard status == ANIGMA_OK, let rawHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        return CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: anigma_vector_capsule_destroy
        )
    }
    
    private func performBooleanOperation(
        handleA: CapsuleHandle<AnyObject>,
        handleB: CapsuleHandle<AnyObject>,
        op: anigma_vector_op_t
    ) throws -> CapsuleHandle<AnyObject> {
        var resultHandle: anigma_vector_capsule_t?
        var error = anigma_capsule_error_t()
        
        return try handleA.withHandle { rawA in
            try handleB.withHandle { rawB in
                let status = anigma_vector_capsule_boolean_op(
                    rawA,
                    rawB,
                    op,
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
    
    private func exportToSVG(_ handle: CapsuleHandle<AnyObject>) throws -> String {
        var svgString: UnsafeMutablePointer<CChar>?
        var error = anigma_capsule_error_t()
        
        return try handle.withHandle { rawHandle in
            let status = anigma_vector_capsule_export_to_svg(rawHandle, &svgString, &error)
            guard status == ANIGMA_OK, let svg = svgString else {
                throw CapsuleError(status: status, error: error)
            }
            defer { anigma_capsule_free_buffer(svg, &error) }
            return String(cString: svg)
        }
    }
    
    // MARK: - VectorOps Protocol Implementation
    
    public func intersection(pathA: String, pathB: String) throws -> String {
        return try performBooleanOperation(pathA: pathA, pathB: pathB, op: ANIGMA_VECTOR_OP_INTERSECTION)
    }
    
    public func difference(pathA: String, pathB: String) throws -> String {
        return try performBooleanOperation(pathA: pathA, pathB: pathB, op: ANIGMA_VECTOR_OP_DIFFERENCE)
    }
    
    public func xor(pathA: String, pathB: String) throws -> String {
        return try performBooleanOperation(pathA: pathA, pathB: pathB, op: ANIGMA_VECTOR_OP_XOR)
    }
    
    // MARK: - Path Simplification Algorithms
    
    public func douglasPeuckerSimplify(path: String, tolerance: Double) throws -> String {
        let handle = try createCapsuleFromSVG(path)
        defer { handle.invalidate() }
        
        return try handle.withHandle { rawHandle in
            var resultHandle: anigma_vector_capsule_t?
            var error = anigma_capsule_error_t()
            
            let status = anigma_vector_capsule_simplify_douglas_peucker(
                rawHandle, tolerance, &resultHandle, &error
            )
            guard status == ANIGMA_OK, let result = resultHandle else {
                throw CapsuleError(status: status, error: error)
            }
            
            defer { anigma_vector_capsule_destroy(result, &error) }
            return try exportHandleToSVG(result)
        }
    }
    
    public func visvalingamSimplify(path: String, tolerance: Double) throws -> String {
        let handle = try createCapsuleFromSVG(path)
        defer { handle.invalidate() }
        
        return try handle.withHandle { rawHandle in
            var resultHandle: anigma_vector_capsule_t?
            var error = anigma_capsule_error_t()
            
            let status = anigma_vector_capsule_simplify_visvalingam(
                rawHandle, tolerance, &resultHandle, &error
            )
            guard status == ANIGMA_OK, let result = resultHandle else {
                throw CapsuleError(status: status, error: error)
            }
            
            defer { anigma_vector_capsule_destroy(result, &error) }
            return try exportHandleToSVG(result)
        }
    }
    
    // MARK: - Transformation Matrix Operations
    
    public func transform(path: String, matrix: TransformationMatrix) throws -> String {
        let handle = try createCapsuleFromSVG(path)
        defer { handle.invalidate() }
        
        return try handle.withHandle { rawHandle in
            var resultHandle: anigma_vector_capsule_t?
            var error = anigma_capsule_error_t()
            
            let status = anigma_vector_capsule_transform(
                rawHandle,
                matrix.a, matrix.b, matrix.c, matrix.d, matrix.e, matrix.f,
                &resultHandle, &error
            )
            guard status == ANIGMA_OK, let result = resultHandle else {
                throw CapsuleError(status: status, error: error)
            }
            
            defer { anigma_vector_capsule_destroy(result, &error) }
            return try exportHandleToSVG(result)
        }
    }
    
    public func translate(path: String, dx: Double, dy: Double) throws -> String {
        return try transform(path: path, matrix: .translation(dx: dx, dy: dy))
    }
    
    public func rotate(path: String, angle: Double, centerX: Double, centerY: Double) throws -> String {
        return try transform(path: path, matrix: .rotation(angle: angle, centerX: centerX, centerY: centerY))
    }
    
    public func scale(path: String, sx: Double, sy: Double) throws -> String {
        return try transform(path: path, matrix: .scaling(sx: sx, sy: sy))
    }
    
    public func skew(path: String, skewX: Double, skewY: Double) throws -> String {
        return try transform(path: path, matrix: .skew(skewX: skewX, skewY: skewY))
    }
    
    // MARK: - Advanced Geometric Primitives
    
    public func createBezierCurve(start: Point, control1: Point, control2: Point, end: Point) throws -> String {
        var error = anigma_capsule_error_t()
        var resultHandle: anigma_vector_capsule_t?
        
        let status = anigma_vector_capsule_create_bezier(
            start.x, start.y,
            control1.x, control1.y,
            control2.x, control2.y,
            end.x, end.y,
            &resultHandle, &error
        )
        guard status == ANIGMA_OK, let result = resultHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        defer { anigma_vector_capsule_destroy(result, &error) }
        return try exportHandleToSVG(result)
    }
    
    public func createArc(center: Point, radius: Double, startAngle: Double, endAngle: Double) throws -> String {
        var error = anigma_capsule_error_t()
        var resultHandle: anigma_vector_capsule_t?
        
        let status = anigma_vector_capsule_create_arc(
            center.x, center.y, radius, startAngle, endAngle,
            &resultHandle, &error
        )
        guard status == ANIGMA_OK, let result = resultHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        defer { anigma_vector_capsule_destroy(result, &error) }
        return try exportHandleToSVG(result)
    }
    
    public func createCircle(center: Point, radius: Double) throws -> String {
        return try createArc(center: center, radius: radius, startAngle: 0, endAngle: 2 * .pi)
    }
    
    // MARK: - Geometric Predicates
    
    public func pointInPolygon(point: Point, path: String) throws -> Bool {
        let handle = try createCapsuleFromSVG(path)
        defer { handle.invalidate() }
        
        return try handle.withHandle { rawHandle in
            var result: Bool = false
            var error = anigma_capsule_error_t()
            
            let status = anigma_vector_capsule_point_in_polygon(
                rawHandle, point.x, point.y, &result, &error
            )
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
            
            return result
        }
    }
    
    public func lineIntersection(line1: LineSegment, line2: LineSegment) throws -> Point? {
        var resultX: Double = 0, resultY: Double = 0
        var hasIntersection: Bool = false
        var error = anigma_capsule_error_t()
        
        let status = anigma_vector_capsule_line_intersection(
            line1.start.x, line1.start.y, line1.end.x, line1.end.y,
            line2.start.x, line2.start.y, line2.end.x, line2.end.y,
            &hasIntersection, &resultX, &resultY, &error
        )
        guard status == ANIGMA_OK else {
            throw CapsuleError(status: status, error: error)
        }
        
        return hasIntersection ? Point(x: resultX, y: resultY) : nil
    }
    
    public func distance(point1: Point, point2: Point) -> Double {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        return sqrt(dx * dx + dy * dy)
    }
    
    public func distanceToLine(point: Point, line: LineSegment) throws -> Double {
        var distance: Double = 0
        var error = anigma_capsule_error_t()
        
        let status = anigma_vector_capsule_point_to_line_distance(
            point.x, point.y,
            line.start.x, line.start.y, line.end.x, line.end.y,
            &distance, &error
        )
        guard status == ANIGMA_OK else {
            throw CapsuleError(status: status, error: error)
        }
        
        return distance
    }
    
    // MARK: - Utility Operations
    
    public func getBounds(path: String) throws -> BoundingBox {
        let handle = try createCapsuleFromSVG(path)
        defer { handle.invalidate() }
        
        return try handle.withHandle { rawHandle in
            var minX: Double = 0, minY: Double = 0, maxX: Double = 0, maxY: Double = 0
            var error = anigma_capsule_error_t()
            
            let status = anigma_vector_capsule_get_bounds(
                rawHandle, &minX, &minY, &maxX, &maxY, &error
            )
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
            
            return BoundingBox(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
        }
    }
    
    public func isEmpty(path: String) throws -> Bool {
        let handle = try createCapsuleFromSVG(path)
        defer { handle.invalidate() }
        
        return try handle.withHandle { rawHandle in
            var empty: Bool = false
            var error = anigma_capsule_error_t()
            
            let status = anigma_vector_capsule_is_empty(rawHandle, &empty, &error)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
            
            return empty
        }
    }
    
    public func pathLength(path: String) throws -> Double {
        let handle = try createCapsuleFromSVG(path)
        defer { handle.invalidate() }
        
        return try handle.withHandle { rawHandle in
            var length: Double = 0
            var error = anigma_capsule_error_t()
            
            let status = anigma_vector_capsule_get_length(rawHandle, &length, &error)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
            
            return length
        }
    }
    
    public func smoothPath(path: String, factor: Double) throws -> String {
        let handle = try createCapsuleFromSVG(path)
        defer { handle.invalidate() }
        
        return try handle.withHandle { rawHandle in
            var resultHandle: anigma_vector_capsule_t?
            var error = anigma_capsule_error_t()
            
            let status = anigma_vector_capsule_smooth_path(
                rawHandle, factor, &resultHandle, &error
            )
            guard status == ANIGMA_OK, let result = resultHandle else {
                throw CapsuleError(status: status, error: error)
            }
            
            defer { anigma_vector_capsule_destroy(result, &error) }
            return try exportHandleToSVG(result)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func exportHandleToSVG(_ handle: anigma_vector_capsule_t) throws -> String {
        var svgString: UnsafeMutablePointer<CChar>?
        var error = anigma_capsule_error_t()
        
        let status = anigma_vector_capsule_export_to_svg(handle, &svgString, &error)
        guard status == ANIGMA_OK, let svg = svgString else {
            throw CapsuleError(status: status, error: error)
        }
        defer { anigma_capsule_free_buffer(svg, &error) }
        return String(cString: svg)
    }
}