import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore

// Static error message constants to ensure proper lifetime management
private let invalidHandleMsg = "Invalid capsule handle"
private let svgParseFailedMsg = "SVG parsing failed"
private let booleanOpFailedMsg = "Boolean operation failed"
private let exportFailedMsg = "SVG export failed"
private let simplificationFailedMsg = "Path simplification failed"

// Helper to create error messages with static string pointers
private func createError(code: anigma_status_t, message: UnsafePointer<CChar>?, detail: UnsafePointer<CChar>? = nil, aux: UInt64 = 0) -> anigma_capsule_error_t {
    return anigma_capsule_error_t(
        code: code,
        message: message,
        detail: detail,
        aux: aux
    )
}

// Helper with string parameter that converts to static pointer
private func createError(code: anigma_status_t, message: String, detail: String? = nil, aux: UInt64 = 0) -> anigma_capsule_error_t {
    // Use static C string literals that persist for program lifetime
    switch message {
    case "Invalid capsule handle":
        return createError(code: code, message: invalidHandleMsg, detail: detail, aux: aux)
    case "SVG parsing failed":
        return createError(code: code, message: svgParseFailedMsg, detail: detail, aux: aux)
    case "Boolean operation failed":
        return createError(code: code, message: booleanOpFailedMsg, detail: detail, aux: aux)
    case "SVG export failed":
        return createError(code: code, message: exportFailedMsg, detail: detail, aux: aux)
    case "Path simplification failed":
        return createError(code: code, message: simplificationFailedMsg, detail: detail, aux: aux)
    default:
        // For any other messages, create a static copy
        return message.withCString { messagePtr in
            let staticPtr = UnsafePointer<CChar>(messagePtr)
            if let detail = detail {
                return detail.withCString { detailPtr in
                    let staticDetail = UnsafePointer<CChar>(detailPtr)
                    return createError(code: code, message: staticPtr, detail: staticDetail, aux: aux)
                }
            } else {
                return createError(code: code, message: staticPtr, detail: nil, aux: aux)
            }
        }
    }
}

/// Swift wrapper for deterministic vector geometry capsule.
/// Provides boolean operations, simplification, and transformations with bitwise-deterministic output.
public final class VectorCapsuleWrapper {
    /// Capsule identity information.
    public static var identity: anigma_capsule_identity_t {
        anigma_vector_capsule_get_identity()
    }
    
    private var handle: CapsuleHandle<AnyObject>?
    private let lock = NSLock()
    
    /// Create a new vector capsule instance.
    /// - Returns: Configured vector capsule ready for operations.
    public init() throws {
        var rawHandle: anigma_vector_capsule_t?
        var error = anigma_capsule_error_t()
        
        // Create a default capsule (no config needed for basic operations)
        let status = anigma_vector_capsule_create_from_svg(
            "M0,0 L1,0 L1,1 L0,1 Z",  // Default 1x1 square
            &rawHandle,
            &error
        )
        guard status == ANIGMA_OK, let rawHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: anigma_vector_capsule_destroy
        )
    }
    
    deinit {
        lock.withLock {
            handle?.invalidate()
        }
    }
    
    // MARK: - Path Creation
    
    /// Create a vector capsule from SVG path string.
    /// - Parameter svgPath: SVG path string (supports M, L, Z commands)
    /// - Returns: Handle to the created vector capsule
    public func createPath(fromSVG svgPath: String) throws -> CapsuleHandle<AnyObject> {
        var rawHandle: anigma_vector_capsule_t?
        var error = anigma_capsule_error_t()
        
        let status = svgPath.withCString { svgPtr in
            anigma_vector_capsule_create_from_svg(svgPtr, &rawHandle, &error)
        }
        
        guard status == ANIGMA_OK, let rawHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        return CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: anigma_vector_capsule_destroy
        )
    }
    
    /// Export a vector capsule to SVG path string.
    /// - Parameter capsule: Handle to vector capsule
    /// - Returns: SVG path string representation
    public func exportToSVG(_ capsule: CapsuleHandle<AnyObject>) throws -> String {
        var svgString: UnsafeMutablePointer<CChar>?
        var error = anigma_capsule_error_t()
        
        try capsule.withHandle { rawHandle in
            let status = anigma_vector_capsule_export_to_svg(rawHandle, &svgString, &error)
            guard status == ANIGMA_OK, let svg = svgString else {
                throw CapsuleError(status: status, error: error)
            }
            defer { anigma_capsule_free_buffer(svg, &error) }
            return String(cString: svg)
        }
    }
    
    // MARK: - Boolean Operations
    
    /// Perform union of two vector capsules.
    /// - Parameters:
    ///   - subject: First vector capsule
    ///   - clip: Second vector capsule
    ///   - fillRule: Fill rule for operation (even-odd or non-zero)
    /// - Returns: New capsule handle representing the union
    public func union(
        _ subject: CapsuleHandle<AnyObject>,
        _ clip: CapsuleHandle<AnyObject>,
        fillRule: anigma_vector_fillrule_t = ANIGMA_VECTOR_FILL_EVEN_ODD
    ) throws -> CapsuleHandle<AnyObject> {
        return try performBooleanOperation(
            subject: subject,
            clip: clip,
            operation: ANIGMA_VECTOR_OP_UNION,
            fillRule: fillRule
        )
    }
    
    /// Perform intersection of two vector capsules.
    /// - Parameters:
    ///   - subject: First vector capsule
    ///   - clip: Second vector capsule
    ///   - fillRule: Fill rule for operation (even-odd or non-zero)
    /// - Returns: New capsule handle representing the intersection
    public func intersection(
        _ subject: CapsuleHandle<AnyObject>,
        _ clip: CapsuleHandle<AnyObject>,
        fillRule: anigma_vector_fillrule_t = ANIGMA_VECTOR_FILL_EVEN_ODD
    ) throws -> CapsuleHandle<AnyObject> {
        return try performBooleanOperation(
            subject: subject,
            clip: clip,
            operation: ANIGMA_VECTOR_OP_INTERSECTION,
            fillRule: fillRule
        )
    }
    
    /// Perform difference of two vector capsules (subject - clip).
    /// - Parameters:
    ///   - subject: First vector capsule
    ///   - clip: Second vector capsule to subtract
    ///   - fillRule: Fill rule for operation (even-odd or non-zero)
    /// - Returns: New capsule handle representing the difference
    public func difference(
        _ subject: CapsuleHandle<AnyObject>,
        _ clip: CapsuleHandle<AnyObject>,
        fillRule: anigma_vector_fillrule_t = ANIGMA_VECTOR_FILL_EVEN_ODD
    ) throws -> CapsuleHandle<AnyObject> {
        return try performBooleanOperation(
            subject: subject,
            clip: clip,
            operation: ANIGMA_VECTOR_OP_DIFFERENCE,
            fillRule: fillRule
        )
    }
    
    /// Perform XOR (symmetric difference) of two vector capsules.
    /// - Parameters:
    ///   - subject: First vector capsule
    ///   - clip: Second vector capsule
    ///   - fillRule: Fill rule for operation (even-odd or non-zero)
    /// - Returns: New capsule handle representing the XOR
    public func xor(
        _ subject: CapsuleHandle<AnyObject>,
        _ clip: CapsuleHandle<AnyObject>,
        fillRule: anigma_vector_fillrule_t = ANIGMA_VECTOR_FILL_EVEN_ODD
    ) throws -> CapsuleHandle<AnyObject> {
        return try performBooleanOperation(
            subject: subject,
            clip: clip,
            operation: ANIGMA_VECTOR_OP_XOR,
            fillRule: fillRule
        )
    }
    
    // MARK: - Geometric Predicates
    
    /// Check if a vector capsule is empty.
    /// - Parameter capsule: Handle to vector capsule
    /// - Returns: True if the capsule contains no paths or empty paths
    public func isEmpty(_ capsule: CapsuleHandle<AnyObject>) throws -> Bool {
        var result: Bool = false
        var error = anigma_capsule_error_t()
        
        try capsule.withHandle { rawHandle in
            let status = anigma_vector_capsule_is_empty(rawHandle, &result, &error)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        
        return result
    }
    
    /// Get the bounding box of a vector capsule.
    /// - Parameter capsule: Handle to vector capsule
    /// - Returns: Bounding box as (minX, minY, maxX, maxY)
    public func getBounds(_ capsule: CapsuleHandle<AnyObject>) throws -> (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        var minX: Double = 0.0
        var minY: Double = 0.0
        var maxX: Double = 0.0
        var maxY: Double = 0.0
        var error = anigma_capsule_error_t()
        
        try capsule.withHandle { rawHandle in
            let status = anigma_vector_capsule_get_bounds(
                rawHandle, &minX, &minY, &maxX, &maxY, &error
            )
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: error)
            }
        }
        
        return (minX: minX, minY: minY, maxX: maxX, maxY: maxY)
    }
    
    // MARK: - Path Simplification
    
    /// Simplify a vector capsule using Douglas-Peucker algorithm.
    /// - Parameters:
    ///   - capsule: Handle to vector capsule
    ///   - tolerance: Simplification tolerance (higher = more aggressive simplification)
    /// - Returns: New capsule handle with simplified paths
    public func simplifyDouglasPeucker(
        _ capsule: CapsuleHandle<AnyObject>,
        tolerance: Double
    ) throws -> CapsuleHandle<AnyObject> {
        var resultHandle: anigma_vector_capsule_t?
        var error = anigma_capsule_error_t()
        
        try capsule.withHandle { rawHandle in
            let status = anigma_vector_capsule_simplify_douglas_peucker(
                rawHandle, tolerance, &resultHandle, &error
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
    
    // MARK: - Private Helper Methods
    
    private func performBooleanOperation(
        subject: CapsuleHandle<AnyObject>,
        clip: CapsuleHandle<AnyObject>,
        operation: anigma_vector_op_t,
        fillRule: anigma_vector_fillrule_t
    ) throws -> CapsuleHandle<AnyObject> {
        var resultHandle: anigma_vector_capsule_t?
        var error = anigma_capsule_error_t()
        
        return try subject.withHandle { subjectHandle in
            try clip.withHandle { clipHandle in
                let status = anigma_vector_capsule_boolean_op(
                    subjectHandle,
                    clipHandle,
                    operation,
                    fillRule,
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
}

// MARK: - Convenience Extensions

extension VectorCapsuleWrapper {
    
    /// Create a rectangular path.
    /// - Parameters:
    ///   - x: X coordinate of top-left corner
    ///   - y: Y coordinate of top-left corner
    ///   - width: Width of rectangle
    ///   - height: Height of rectangle
    /// - Returns: Handle to rectangle vector capsule
    public func createRectangle(x: Double, y: Double, width: Double, height: Double) throws -> CapsuleHandle<AnyObject> {
        let svgPath = "M\(x),\(y) L\(x + width),\(y) L\(x + width),\(y + height) L\(x),\(y + height) Z"
        return try createPath(fromSVG: svgPath)
    }
    
    /// Create a circular path.
    /// - Parameters:
    ///   - centerX: X coordinate of circle center
    ///   - centerY: Y coordinate of circle center
    ///   - radius: Radius of circle
    ///   - segments: Number of line segments to approximate circle (default: 32)
    /// - Returns: Handle to circle vector capsule
    public func createCircle(
        centerX: Double,
        centerY: Double,
        radius: Double,
        segments: Int = 32
    ) throws -> CapsuleHandle<AnyObject> {
        var svgPath = "M\(centerX + radius),\(centerY)"
        
        for i in 1...segments {
            let angle = Double(i) * 2.0 * Double.pi / Double(segments)
            let x = centerX + radius * cos(angle)
            let y = centerY + radius * sin(angle)
            svgPath += " L\(x),\(y)"
        }
        
        svgPath += " Z"
        return try createPath(fromSVG: svgPath)
    }
    
    /// Create a polygonal path from points.
    /// - Parameter points: Array of (x, y) coordinates
    /// - Returns: Handle to polygon vector capsule
    public func createPolygon(from points: [(Double, Double)]) throws -> CapsuleHandle<AnyObject> {
        guard points.count >= 3 else {
            throw CapsuleError(
                status: ANIGMA_ERR_INVALID_ARG,
                error: createError(code: ANIGMA_ERR_INVALID_ARG, message: "Polygon requires at least 3 points")
            )
        }
        
        var svgPath = "M\(points[0].0),\(points[0].1)"
        for i in 1..<points.count {
            svgPath += " L\(points[i].0),\(points[i].1)"
        }
        svgPath += " Z"
        
        return try createPath(fromSVG: svgPath)
    }
}

// MARK: - Protocol Conformance

/// Vector operations protocol for type-erased usage
public protocol VectorOps {
    func union(_ subject: CapsuleHandle<AnyObject>, _ clip: CapsuleHandle<AnyObject>, fillRule: anigma_vector_fillrule_t) throws -> CapsuleHandle<AnyObject>
    func intersection(_ subject: CapsuleHandle<AnyObject>, _ clip: CapsuleHandle<AnyObject>, fillRule: anigma_vector_fillrule_t) throws -> CapsuleHandle<AnyObject>
    func difference(_ subject: CapsuleHandle<AnyObject>, _ clip: CapsuleHandle<AnyObject>, fillRule: anigma_vector_fillrule_t) throws -> CapsuleHandle<AnyObject>
    func xor(_ subject: CapsuleHandle<AnyObject>, _ clip: CapsuleHandle<AnyObject>, fillRule: anigma_vector_fillrule_t) throws -> CapsuleHandle<AnyObject>
    func simplifyDouglasPeucker(_ capsule: CapsuleHandle<AnyObject>, tolerance: Double) throws -> CapsuleHandle<AnyObject>
    func exportToSVG(_ capsule: CapsuleHandle<AnyObject>) throws -> String
    func isEmpty(_ capsule: CapsuleHandle<AnyObject>) throws -> Bool
    func getBounds(_ capsule: CapsuleHandle<AnyObject>) throws -> (minX: Double, minY: Double, maxX: Double, maxY: Double)
}

extension VectorCapsuleWrapper: VectorOps {}