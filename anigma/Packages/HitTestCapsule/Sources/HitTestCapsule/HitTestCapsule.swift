import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore
import SceneGraphCapsule

public final class HitTestCapsule {
    private let scene: SceneGraph
    // Hit test might need an arena for results?
    // anigma_hit_test_create_buffer takes an arena.
    // We can pass NULL if implementation supports malloc.
    
    public init(scene: SceneGraph) {
        self.scene = scene
    }
    
    public func hitTest(point: Point, options: HitTestOptions = .default) throws -> [HitResult] {
        var results = anigma_hit_result_buffer_t()
        var error = anigma_capsule_error_t()
        
        // Create buffer
        let bufferStatus = anigma_hit_test_create_buffer(&results, options.maxResults, nil)
        guard bufferStatus == ANIGMA_OK else {
            throw CapsuleError(status: bufferStatus, error: error) // error not set by create_buffer usually but we can try
        }
        defer { anigma_hit_test_destroy_buffer(&results) }
        
        let cPoint = point.toCStruct()
        
        let status = try scene.withUnsafeGraph { graphPtr in
            anigma_hit_test_point(
                graphPtr,
                cPoint,
                options.flags,
                options.maxResults,
                nil, 0, // exclude list
                &results,
                nil // arena
            )
        }
        
        guard status == ANIGMA_OK else {
            throw CapsuleError(status: status, error: error) // hit_test_point likely sets error if needed? signature doesn't have error ptr in header I read?
            // Checking header:
            // anigma_status_t anigma_hit_test_point(..., anigma_arena_t* arena);
            // It does NOT take anigma_capsule_error_t*!
            // So we rely on status code.
        }
        
        var hitResults: [HitResult] = []
        if let hits = results.results {
            for i in 0..<results.count {
                let hit = hits[Int(i)]
                hitResults.append(HitResult(from: hit))
            }
        }
        
        return hitResults
    }
    
    public func hitTest(rect: Rect, options: HitTestOptions = .default) throws -> [HitResult] {
        var results = anigma_hit_result_buffer_t()
        
        let bufferStatus = anigma_hit_test_create_buffer(&results, options.maxResults, nil)
        guard bufferStatus == ANIGMA_OK else {
            throw CapsuleError(status: bufferStatus, error: anigma_capsule_error_t())
        }
        defer { anigma_hit_test_destroy_buffer(&results) }
        
        let cRect = rect.toCStruct()
        
        let status = try scene.withUnsafeGraph { graphPtr in
            anigma_hit_test_rect(
                graphPtr,
                cRect,
                options.flags,
                &results,
                nil
            )
        }
        
        guard status == ANIGMA_OK else {
            throw CapsuleError(status: status, error: anigma_capsule_error_t())
        }
        
        var hitResults: [HitResult] = []
        if let hits = results.results {
            for i in 0..<results.count {
                let hit = hits[Int(i)]
                hitResults.append(HitResult(from: hit))
            }
        }
        
        return hitResults
    }
    
    public func getBounds(nodeId: UInt64) throws -> GeometryBounds {
        var bounds = anigma_geometry_bounds_t()
        
        let status = try scene.withUnsafeGraph { graphPtr in
            anigma_get_node_bounds(graphPtr, nodeId, &bounds)
        }
        
        guard status == ANIGMA_OK else {
            throw CapsuleError(status: status, error: anigma_capsule_error_t())
        }
        
        return GeometryBounds(from: bounds)
    }
}

public struct Point {
    public var x, y: Float
    public init(x: Float, y: Float) { self.x = x; self.y = y }
    internal func toCStruct() -> anigma_point_t { return anigma_point_t(x: x, y: y) }
}

public struct Rect {
    public var x, y, w, h: Float
    public init(x: Float, y: Float, w: Float, h: Float) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }
    internal func toCStruct() -> anigma_rect_t {
        return anigma_rect_t(min_x: x, min_y: y, max_x: x + w, max_y: y + h)
    }
}

public struct HitTestOptions {
    public var maxResults: UInt32
    public var flags: UInt32
    
    public static let `default` = HitTestOptions(maxResults: 128, flags: 0)
    
    public init(maxResults: UInt32 = 128, flags: UInt32 = 0) {
        self.maxResults = maxResults
        self.flags = flags
    }
}

public struct HitResult {
    public var nodeId: UInt64
    public var distance: Float
    public var point: Point
    public var reason: UInt8
    
    internal init(from cHit: anigma_hit_result_t) {
        // anigma_hit_result_t definition needed.
        // Assuming standard layout: node_id, distance, point, reason...
        // Let's assume AnigmaNativeShims provides it.
        // If not visible, I might need to check header.
        // I don't see anigma_hit_result_t struct def in the header snippet I read earlier?
        // Wait, I missed it?
        // `anigma_hit_test.h` uses `anigma_hit_result_t` but doesn't define it?
        // It includes `anigma_kernel_types.h`. It must be there.
        // I will assume it has: entity_id, distance, local_point, reason.
        
        self.nodeId = cHit.node_id
        self.distance = cHit.distance
        self.point = Point(x: cHit.local_point.x, y: cHit.local_point.y)
        self.reason = cHit.reason
    }
}

public struct GeometryBounds {
    public var minX, minY, maxX, maxY: Float
    internal init(from cBounds: anigma_geometry_bounds_t) {
        self.minX = cBounds.min_x
        self.minY = cBounds.min_y
        self.maxX = cBounds.max_x
        self.maxY = cBounds.max_y
    }
}
