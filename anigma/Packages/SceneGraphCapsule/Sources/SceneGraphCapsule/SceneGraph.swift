import Foundation
import SceneGraphNative
import AnigmaNativeShims

/// Represents a node in the scene graph with transform and hierarchy info.
public struct SceneNode: Sendable {
    public let entityId: UInt64
    public let parentId: UInt64
    public var localTransform: Transform2D
    public var worldTransform: Transform2D
    public var flags: UInt32
    public var layerMask: UInt32
    
    public init(
        entityId: UInt64,
        parentId: UInt64 = 0,
        localTransform: Transform2D = .identity,
        flags: UInt32 = 0,
        layerMask: UInt32 = 0xFFFFFFFF
    ) {
        self.entityId = entityId
        self.parentId = parentId
        self.localTransform = localTransform
        self.worldTransform = .identity
        self.flags = flags
        self.layerMask = layerMask
    }
    
    internal init(from cNode: anigma_scene_node_t) {
        self.entityId = cNode.entity_id
        self.parentId = cNode.parent_id
        self.localTransform = Transform2D(from: cNode.local_transform)
        self.worldTransform = Transform2D(from: cNode.world_transform)
        self.flags = cNode.flags
        self.layerMask = cNode.layer_mask
    }
    
    internal func toCStruct() -> anigma_scene_node_t {
        return anigma_scene_node_t(
            entity_id: entityId,
            parent_id: parentId,
            local_transform: localTransform.toCStruct(),
            world_transform: worldTransform.toCStruct(),
            flags: flags,
            layer_mask: layerMask
        )
    }
}

/// 2D affine transform - stored as 3x3 matrix
/// Matrix layout: [[m00, m01, m02], [m10, m11, m12], [m20, m21, m22]]
/// Where m02 = tx, m12 = ty for translation
public struct Transform2D: Sendable {
    public var m: ((Int32, Int32, Int32), (Int32, Int32, Int32), (Int32, Int32, Int32))
    
    public static let identity = Transform2D(
        m: ((256, 0, 0), (0, 256, 0), (0, 0, 256))  // ANIGMA_COORDINATE_SCALE = 256
    )
    
    public init(m: ((Int32, Int32, Int32), (Int32, Int32, Int32), (Int32, Int32, Int32))) {
        self.m = m
    }
    
    internal init(from cTransform: anigma_transform_t) {
        self.m = (
            (cTransform.m.0.0, cTransform.m.0.1, cTransform.m.0.2),
            (cTransform.m.1.0, cTransform.m.1.1, cTransform.m.1.2),
            (cTransform.m.2.0, cTransform.m.2.1, cTransform.m.2.2)
        )
    }
    
    internal func toCStruct() -> anigma_transform_t {
        // Swift imports C arrays in structs as tuples
        var t = anigma_transform_t()
        t.m.0 = (m.0.0, m.0.1, m.0.2)
        t.m.1 = (m.1.0, m.1.1, m.1.2)
        t.m.2 = (m.2.0, m.2.1, m.2.2)
        return t
    }
    
    /// Create a translation transform
    public static func translation(x: Float, y: Float) -> Transform2D {
        let scale: Float = 256.0  // ANIGMA_COORDINATE_SCALE
        return Transform2D(m: (
            (256, 0, Int32(x * scale)),
            (0, 256, Int32(y * scale)),
            (0, 0, 256)
        ))
    }
}

/// Simple error type for SceneGraph operations
public struct SceneGraphError: Error {
    public let message: String
    
    public init(_ message: String) {
        self.message = message
    }
}

/// A high-performance scene graph for managing spatial hierarchy and transforms.
/// Wrapper around native C++ implementation.
public final class SceneGraph: @unchecked Sendable {
    private var handle: anigma_scene_graph_t?
    
    public init() throws {
        var newHandle: anigma_scene_graph_t?
        var error = anigma_capsule_error_t()
        let status = anigma_scene_graph_create(&newHandle, &error)
        guard status == ANIGMA_OK, let h = newHandle else {
            throw SceneGraphError("Failed to create scene graph: \(status)")
        }
        self.handle = h
    }
    
    deinit {
        if let h = handle {
            anigma_scene_graph_destroy(h, nil)
        }
    }
    
    /// Attach a node to the scene graph.
    public func attach(node: SceneNode) throws {
        guard let h = handle else { throw SceneGraphError("Invalid handle") }
        var cNode = node.toCStruct()
        var error = anigma_capsule_error_t()
        let status = anigma_scene_graph_attach(h, &cNode, &error)
        if status != ANIGMA_OK { throw SceneGraphError("Attach failed: \(status)") }
    }
    
    /// Detach a node from the scene graph.
    public func detach(entityId: UInt64) throws {
        guard let h = handle else { throw SceneGraphError("Invalid handle") }
        var error = anigma_capsule_error_t()
        let status = anigma_scene_graph_detach(h, entityId, &error)
        if status != ANIGMA_OK { throw SceneGraphError("Detach failed: \(status)") }
    }
    
    /// Update the local transform of a node.
    public func updateTransform(entityId: UInt64, transform: Transform2D) throws {
        guard let h = handle else { throw SceneGraphError("Invalid handle") }
        var cTransform = transform.toCStruct()
        var error = anigma_capsule_error_t()
        let status = anigma_scene_graph_update_transform(h, entityId, &cTransform, &error)
        if status != ANIGMA_OK { throw SceneGraphError("Update transform failed: \(status)") }
    }
    
    /// Get a node by entity ID.
    public func getNode(entityId: UInt64) throws -> SceneNode {
        guard let h = handle else { throw SceneGraphError("Invalid handle") }
        var cNode = anigma_scene_node_t()
        var error = anigma_capsule_error_t()
        let status = anigma_scene_graph_get_node(h, entityId, &cNode, &error)
        if status != ANIGMA_OK { throw SceneGraphError("Node not found") }
        return SceneNode(from: cNode)
    }
    
    /// Get the number of nodes in the scene graph.
    public func nodeCount() -> Int {
        guard let h = handle else { return 0 }
        var count: Int = 0
        anigma_scene_graph_get_node_count(h, &count, nil)
        return count
    }
    
    /// Evaluate all world transforms based on parent-child hierarchy.
    public func evaluateTransforms() throws {
        guard let h = handle else { throw SceneGraphError("Invalid handle") }
        var error = anigma_capsule_error_t()
        let status = anigma_scene_graph_evaluate_transforms(h, &error)
        if status != ANIGMA_OK { throw SceneGraphError("Evaluate transforms failed: \(status)") }
    }
    
    /// Provide unsafe access to the underlying graph handle for interoperability.
    public func withUnsafeGraph<T>(_ body: (anigma_scene_graph_t) throws -> T) rethrows -> T {
        guard let h = handle else { fatalError("SceneGraph handle is nil") }
        return try body(h)
    }
}
