import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore
import SceneGraphCapsule
import RenderPlanNative

public final class RenderPlanBuilder {
    private var builderPtr: UnsafeMutablePointer<anigma_render_plan_builder_t?>
    
    public init(opCapacity: UInt32 = 1024, resourceCapacity: UInt32 = 256) throws {
        self.builderPtr = UnsafeMutablePointer<anigma_render_plan_builder_t?>.allocate(capacity: 1)
        
        let status = anigma_render_plan_builder_create(builderPtr, opCapacity, resourceCapacity, nil)
        
        guard status == ANIGMA_OK else {
            builderPtr.deallocate()
            throw CapsuleError(status: status, error: anigma_capsule_error_t())
        }
    }
    
    deinit {
        if let ptr = builderPtr.pointee {
            anigma_render_plan_builder_destroy(ptr)
        }
        builderPtr.deallocate()
    }
    
    public func addClear(layerId: UInt32, color: ResourceRef) throws {
        guard let builder = builderPtr.pointee else { throw CapsuleError(status: ANIGMA_ERR_INVALID_ARG, error: anigma_capsule_error_t()) }
        let status = anigma_render_plan_builder_add_clear(builder, layerId, color.toCStruct())
        guard status == ANIGMA_OK else {
            throw CapsuleError(status: status, error: anigma_capsule_error_t())
        }
    }
    
    public func addRect(layerId: UInt32, rect: Rect, transform: Transform2D, material: ResourceRef) throws {
        guard let builder = builderPtr.pointee else { throw CapsuleError(status: ANIGMA_ERR_INVALID_ARG, error: anigma_capsule_error_t()) }
        var cRect = rect.toCStruct()
        
        var cTransform = anigma_affine_i32_t()
        
        // Convert 3x3 int to 2x3 affine int (a, b, c, d, tx, ty)
        // anigma_affine_i32_t is m[6]
        cTransform.m.0 = transform.m.0.0
        cTransform.m.1 = transform.m.1.0
        cTransform.m.2 = transform.m.0.1
        cTransform.m.3 = transform.m.1.1
        cTransform.m.4 = transform.m.0.2
        cTransform.m.5 = transform.m.1.2
        
        var cMaterial = material.toCStruct()
        
        let status = anigma_render_plan_builder_add_rect(builder, layerId, &cRect, &cTransform, &cMaterial)
        guard status == ANIGMA_OK else {
            throw CapsuleError(status: status, error: anigma_capsule_error_t())
        }
    }
    
    public func build() throws -> RenderPlan {
        guard let builder = builderPtr.pointee else { throw CapsuleError(status: ANIGMA_ERR_INVALID_ARG, error: anigma_capsule_error_t()) }
        var planPtr: anigma_render_plan_t? = nil
        
        let status = anigma_render_plan_build(builder, &planPtr)
        
        guard status == ANIGMA_OK, let plan = planPtr else {
            throw CapsuleError(status: status, error: anigma_capsule_error_t())
        }
        
        return RenderPlan(handle: plan)
    }
}

public final class RenderPlan {
    internal let handle: anigma_render_plan_t
    
    internal init(handle: anigma_render_plan_t) {
        self.handle = handle
    }
    
    deinit {
        anigma_render_plan_destroy(handle, nil)
    }
    
    public func computeHash() throws {
        let status = anigma_render_plan_compute_hash(handle)
        guard status == ANIGMA_OK else {
            throw CapsuleError(status: status, error: anigma_capsule_error_t())
        }
    }
    
    public static func generate(from scene: SceneGraph, request: RenderRequest) throws -> RenderPlan {
        var planPtr: anigma_render_plan_t? = nil
        var cRequest = request.toCStruct()
        
        let status = scene.withUnsafeGraph { graphPtr in
            anigma_generate_render_plan(graphPtr, &cRequest, &planPtr, nil)
        }
        
        guard status == ANIGMA_OK, let plan = planPtr else {
            throw CapsuleError(status: status, error: anigma_capsule_error_t())
        }
        
        return RenderPlan(handle: plan)
    }
}

public struct RenderRequest {
    public var viewport: Rect
    public var scaleFactor: Float
    public var flags: UInt32
    
    public init(viewport: Rect, scaleFactor: Float, flags: UInt32) {
        self.viewport = viewport
        self.scaleFactor = scaleFactor
        self.flags = flags
    }
    
    internal func toCStruct() -> anigma_render_plan_request_t {
        return anigma_render_plan_request_t(
            viewport: viewport.toCStruct(),
            render_flags: flags
        )
    }
}

public struct Rect {
    public var x, y, w, h: Float
    public init(x: Float, y: Float, w: Float, h: Float) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }
    internal func toCStruct() -> anigma_rect_t {
        // Convert float to fixed point/int coordinate
        let scale: Float = 256.0
        return anigma_rect_t(
            x: Int32(x * scale),
            y: Int32(y * scale),
            width: Int32(w * scale),
            height: Int32(h * scale)
        )
    }
}

public struct ResourceRef {
    public var type: UInt32
    public var id: UInt64
    public init(type: UInt32, id: UInt64) { self.type = type; self.id = id }
    internal func toCStruct() -> anigma_resource_ref_t {
        return anigma_resource_ref_t(resource_id: id, resource_type: type)
    }
}
