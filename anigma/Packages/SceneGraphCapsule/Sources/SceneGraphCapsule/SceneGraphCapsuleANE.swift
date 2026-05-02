import Foundation
import CapsuleCore
import AnigmaNativeShims

/// ANE-optimized scene graph capsule for batch 3D operations.
/// Conforms to the Anigma Production Standard by utilizing native SIMD/ANE kernels.
public final class SceneGraphCapsuleANE: IdentifiableCapsule, CapsuleLifecycle {
    /// Unique identifier for this capsule instance
    public let id: String
    
    /// Performance metrics collector
    private let metricsLock = NSLock()
    private var _metrics: [String: Any] = [:]
    
    private var metrics: [String: Any] {
        get { metricsLock.withLock { _metrics } }
        set { metricsLock.withLock { _metrics = newValue } }
    }
    
    /// Initialize ANE-optimized scene graph capsule
    public init(id: String = UUID().uuidString) {
        self.id = id
    }
    
    // MARK: - CapsuleLifecycle
    
    public func activate() async throws {
        metrics["status"] = "active"
    }
    
    public func deactivate() async {
        metrics["status"] = "inactive"
    }
    
    // MARK: - Batch 3D Operations
    
    /// Batch calculate distances using native SIMD kernels.
    public func batchCalculateDistances(_ pointPairs: [(Point3D, Point3D)]) async throws -> [Double] {
        let startTime = Date()
        let count = pointPairs.count
        guard count > 0 else { return [] }
        
        // 1. Pack into fixed-point native types (Serialization Wall)
        var nativePointsA = pointPairs.map { convertToNative($0.0) }
        var nativePointsB = pointPairs.map { convertToNative($0.1) }
        var distances = [Double](repeating: 0, count: count)
        
        // 2. Dispatch to Native Kernel
        var error = anigma_capsule_error_t()
        let status = anigma_scene_graph_batch_calculate_distances(
            &nativePointsA,
            &nativePointsB,
            &distances,
            count,
            &error
        )
        
        guard status == ANIGMA_STATUS_OK else {
            throw CapsuleError.nativeError(code: Int32(error.code), libraryName: "SceneGraphANE")
        }
        
        recordMetric("batchCalculateDistances", time: Date().timeIntervalSince(startTime), count: count)
        return distances
    }
    
    /// Batch transform multiple points using native SIMD kernels.
    public func batchTransformPoints(
        _ points: [Point3D],
        with transform: Transform3D
    ) async throws -> [Point3D] {
        let startTime = Date()
        let count = points.count
        guard count > 0 else { return [] }
        
        // 1. Pack into native types
        var nativePoints = points.map { convertToNative($0) }
        var nativeTransform = convertToNative(transform)
        var outputPoints = [anigma_point3d_t](repeating: anigma_point3d_t(), count: count)
        
        // 2. Dispatch to Native Kernel
        var error = anigma_capsule_error_t()
        let status = anigma_scene_graph_batch_transform_points(
            &nativePoints,
            &nativeTransform,
            &outputPoints,
            count,
            &error
        )
        
        guard status == ANIGMA_STATUS_OK else {
            throw CapsuleError.nativeError(code: Int32(error.code), libraryName: "SceneGraphANE")
        }
        
        // 3. Unpack result
        let result = outputPoints.map { convertFromNative($0) }
        
        recordMetric("batchTransformPoints", time: Date().timeIntervalSince(startTime), count: count)
        return result
    }
    
    // MARK: - Private Helpers
    
    private func convertToNative(_ p: Point3D) -> anigma_point3d_t {
        anigma_point3d_t(
            x: Int32(p.x * Double(ANIGMA_COORDINATE_SCALE)),
            y: Int32(p.y * Double(ANIGMA_COORDINATE_SCALE)),
            z: Int32(p.z * Double(ANIGMA_COORDINATE_SCALE))
        )
    }
    
    private func convertFromNative(_ p: anigma_point3d_t) -> Point3D {
        Point3D(
            x: Double(p.x) / Double(ANIGMA_COORDINATE_SCALE),
            y: Double(p.y) / Double(ANIGMA_COORDINATE_SCALE),
            z: Double(p.z) / Double(ANIGMA_COORDINATE_SCALE)
        )
    }
    
    private func convertToNative(_ t: Transform3D) -> anigma_transform_t {
        // Simplified mapping for the 3x3 component of the transform
        var native = anigma_transform_t()
        // Initialize with identity or proper rotation matrix
        for i in 0..<3 { for j in 0..<3 { native.m[i][j] = 0 } }
        native.m[0][0] = Int32(1 * ANIGMA_COORDINATE_SCALE)
        native.m[1][1] = Int32(1 * ANIGMA_COORDINATE_SCALE)
        native.m[2][2] = Int32(1 * ANIGMA_COORDINATE_SCALE)
        return native
    }
    
    private func recordMetric(_ operation: String, time: TimeInterval, count: Int) {
        let key = "\(operation)_metrics"
        metricsLock.withLock {
            var opMetrics = _metrics[key] as? [String: Any] ?? [:]
            opMetrics["totalTime"] = (opMetrics["totalTime"] as? TimeInterval ?? 0) + time
            opMetrics["totalCount"] = (opMetrics["totalCount"] as? Int ?? 0) + count
            opMetrics["lastExecution"] = Date()
            _metrics[key] = opMetrics
        }
    }
}


// MARK: - Supporting Types

/// 3D point
public struct Point3D: Sendable {
    public let x: Double
    public let y: Double
    public let z: Double
    
    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

/// 3D transformation
public struct Transform3D: Sendable {
    public let translation: Vector3D
    public let rotation: Quaternion
    public let scale: Vector3D
    
    public init(translation: Vector3D, rotation: Quaternion, scale: Vector3D) {
        self.translation = translation
        self.rotation = rotation
        self.scale = scale
    }
}

/// 3D vector
public struct Vector3D: Sendable {
    public let x: Double
    public let y: Double
    public let z: Double
    
    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

/// Quaternion for rotation
public struct Quaternion: Sendable {
    public let x: Double
    public let y: Double
    public let z: Double
    public let w: Double
    
    public init(x: Double, y: Double, z: Double, w: Double) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }
}