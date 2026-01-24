import Foundation
import AnigmaNativeShims
import CapsuleCore

internal final class VectorCapsuleWrapper {
    static func exportToSVG(capsule: CapsuleHandle<AnyObject>) throws -> String {
        var svgString: UnsafeMutablePointer<CChar>?
        var error = anigma_capsule_error_t()
        
        return try capsule.withHandle { rawHandle in
            let status = anigma_vector_capsule_export_to_svg(rawHandle, &svgString, &error)
            guard status == ANIGMA_OK, let svg = svgString else {
                throw CapsuleError(status: status, error: error)
            }
            let result = String(cString: svg)
            // Note: In real implementation we'd need to free svgString using anigma_free_buffer
            return result
        }
    }
    
    static func simplifyDouglasPeucker(capsule: CapsuleHandle<AnyObject>, tolerance: Double) throws -> CapsuleHandle<AnyObject> {
        var resultHandle: anigma_vector_capsule_t?
        var error = anigma_capsule_error_t()
        
        return try capsule.withHandle { rawHandle in
            let status = anigma_vector_capsule_simplify_douglas_peucker(rawHandle, tolerance, &resultHandle, &error)
            guard status == ANIGMA_OK, let finalHandle = resultHandle else {
                throw CapsuleError(status: status, error: error)
            }
            return CapsuleHandle<AnyObject>(
                rawHandle: finalHandle,
                destroyFunction: { ptr, err in
                    anigma_vector_capsule_destroy(ptr, err)
                }
            )
        }
    }
}
