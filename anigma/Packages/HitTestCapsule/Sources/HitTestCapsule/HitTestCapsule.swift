import Foundation
import AnigmaNativeShims
import SceneGraphCapsule
import HitTestNative

public struct HitTestNativeError: Error, Sendable {
    public let status: anigma_status_t
    public let message: String
}

private func hitTestError(_ status: anigma_status_t, _ message: String) -> HitTestNativeError {
    HitTestNativeError(status: status, message: message)
}

public final class HitTestCapsule {
    private let scene: NativeSceneGraph
    // Hit test might need an arena for results?
    // anigma_hit_test_create_buffer takes an arena.
    // We can pass NULL if implementation supports malloc.
    
    public init(scene: NativeSceneGraph) {
        self.scene = scene
    }
    
    public func hitTest(point: Point, options: HitTestOptions = .default) throws -> [HitResult] {
        var results = anigma_hit_result_buffer_t()
        
        // Create buffer
        let bufferStatus = anigma_hit_test_create_buffer(&results, Int(options.maxResults), nil)
        guard bufferStatus == ANIGMA_OK else {
            throw hitTestError(bufferStatus, "failed to create hit-test buffer")
        }
        defer { anigma_hit_test_destroy_buffer(&results) }
        
        // Convert Point (Float) to anigma_point_t (Int32 scaled)
        let scale: Float = 256.0
        let cPoint = anigma_point_t(x: Int32(point.x * scale), y: Int32(point.y * scale))
        
        let status = scene.withUnsafeGraph { graphPtr in
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
            throw hitTestError(status, "point hit-test failed")
        }
        
        // Convert results
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
        
        let bufferStatus = anigma_hit_test_create_buffer(&results, Int(options.maxResults), nil)
        guard bufferStatus == ANIGMA_OK else {
            throw hitTestError(bufferStatus, "failed to create hit-test buffer")
        }
        defer { anigma_hit_test_destroy_buffer(&results) }
        
        let cRect = rect.toCStruct()
        
        let status = scene.withUnsafeGraph { graphPtr in
            anigma_hit_test_rect(
                graphPtr,
                cRect,
                options.flags,
                &results,
                nil
            )
        }
        
        guard status == ANIGMA_OK else {
            throw hitTestError(status, "rect hit-test failed")
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
        
        let status = scene.withUnsafeGraph { graphPtr in
            anigma_get_node_bounds(graphPtr, nodeId, &bounds)
        }
        
        guard status == ANIGMA_OK else {
            throw hitTestError(status, "failed to get node bounds")
        }
        
        return GeometryBounds(from: bounds)
    }
}

public struct Point {
    public var x, y: Float
    public init(x: Float, y: Float) { self.x = x; self.y = y }
    internal func toCStruct() -> anigma_point_t {
        // anigma_point_t uses Int32 scaled coordinates
        let scale: Float = 256.0
        return anigma_point_t(x: Int32(x * scale), y: Int32(y * scale))
    }
}

public struct Rect {
    public var x, y, w, h: Float
    public init(x: Float, y: Float, w: Float, h: Float) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }
    internal func toCStruct() -> anigma_rect_t {
        let scale: Float = 256.0
        return anigma_rect_t(
            x: Int32(x * scale),
            y: Int32(y * scale),
            width: Int32(w * scale),
            height: Int32(h * scale)
        )
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
    public var reason: UInt32
    
    internal init(from cHit: anigma_hit_test_result_t) {
        self.nodeId = cHit.node_id
        self.distance = cHit.distance
        let scale: Float = 1.0 / 256.0
        self.point = Point(x: Float(cHit.local_point.x) * scale, y: Float(cHit.local_point.y) * scale)
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
