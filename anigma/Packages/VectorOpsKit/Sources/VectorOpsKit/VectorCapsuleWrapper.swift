import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
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
    
    // MARK: - Additional Operations (extend VectorOps protocol if needed)
    
    public func intersection(pathA: String, pathB: String) throws -> String {
        return try performBooleanOperation(pathA: pathA, pathB: pathB, op: ANIGMA_VECTOR_OP_INTERSECTION)
    }
    
    public func difference(pathA: String, pathB: String) throws -> String {
        return try performBooleanOperation(pathA: pathA, pathB: pathB, op: ANIGMA_VECTOR_OP_DIFFERENCE)
    }
    
    public func xor(pathA: String, pathB: String) throws -> String {
        return try performBooleanOperation(pathA: pathA, pathB: pathB, op: ANIGMA_VECTOR_OP_XOR)
    }
}