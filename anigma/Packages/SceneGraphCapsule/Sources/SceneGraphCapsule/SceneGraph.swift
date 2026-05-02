import Foundation
import AnigmaNativeShims
import SceneGraphNative

/// Represents a node in the scene graph with transform and hierarchy info.
public struct NativeSceneNode: Sendable {
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
public struct NativeSceneGraphError: Error {
    public let message: String
    
    public init(_ message: String) {
        self.message = message
    }
}

/// Batched scene graph mutations applied against a single handle.
/// Use this to reduce FFI calls and intermediate allocations when mutating many nodes.
public enum SceneGraphMutation: Sendable {
    case attach(NativeSceneNode)
    case detach(entityId: UInt64)
    case updateTransform(entityId: UInt64, transform: Transform2D)

    internal func toCStruct() -> anigma_scene_graph_mutation_t {
        switch self {
        case .attach(let node):
            return anigma_scene_graph_mutation_t(
                kind: ANIGMA_SCENE_GRAPH_MUTATION_ATTACH,
                entity_id: node.entityId,
                node: node.toCStruct(),
                transform: anigma_transform_t()
            )
        case .detach(let entityId):
            return anigma_scene_graph_mutation_t(
                kind: ANIGMA_SCENE_GRAPH_MUTATION_DETACH,
                entity_id: entityId,
                node: anigma_scene_node_t(),
                transform: anigma_transform_t()
            )
        case .updateTransform(let entityId, let transform):
            return anigma_scene_graph_mutation_t(
                kind: ANIGMA_SCENE_GRAPH_MUTATION_UPDATE_TRANSFORM,
                entity_id: entityId,
                node: anigma_scene_node_t(),
                transform: transform.toCStruct()
            )
        }
    }
}

/// A high-performance scene graph for managing spatial hierarchy and transforms.
/// Wrapper around native C++ implementation.
public final class NativeSceneGraph: @unchecked Sendable {
    private var handle: anigma_scene_graph_t?
    
    public init() throws {
        var newHandle: anigma_scene_graph_t?
        var error = anigma_capsule_error_t()
        let status = anigma_scene_graph_create(&newHandle, &error)
        guard status == ANIGMA_OK, let h = newHandle else {
            throw NativeSceneGraphError("Failed to create scene graph: \(status)")
        }
        self.handle = h
    }
    
    deinit {
        if let h = handle {
            anigma_scene_graph_destroy(h, nil)
        }
    }
    
    /// Attach a node to the scene graph.
    public func attach(node: NativeSceneNode) throws {
        guard let h = handle else { throw NativeSceneGraphError("Invalid handle") }
        var cNode = node.toCStruct()
        var error = anigma_capsule_error_t()
        let status = anigma_scene_graph_attach(h, &cNode, &error)
        if status != ANIGMA_OK { throw NativeSceneGraphError("Attach failed: \(status)") }
    }
    
    /// Detach a node from the scene graph.
    public func detach(entityId: UInt64) throws {
        guard let h = handle else { throw NativeSceneGraphError("Invalid handle") }
        var error = anigma_capsule_error_t()
        let status = anigma_scene_graph_detach(h, entityId, &error)
        if status != ANIGMA_OK { throw NativeSceneGraphError("Detach failed: \(status)") }
    }
    
    /// Update the local transform of a node.
    public func updateTransform(entityId: UInt64, transform: Transform2D) throws {
        guard let h = handle else { throw NativeSceneGraphError("Invalid handle") }
        var cTransform = transform.toCStruct()
        var error = anigma_capsule_error_t()
        let status = anigma_scene_graph_update_transform(h, entityId, &cTransform, &error)
        if status != ANIGMA_OK { throw NativeSceneGraphError("Update transform failed: \(status)") }
    }

    /// Apply a batch of mutations against the same handle.
    /// This collapses many FFI calls into one and invalidates native caches once.
    public func apply(_ mutations: [SceneGraphMutation]) throws {
        guard let h = handle else { throw NativeSceneGraphError("Invalid handle") }
        guard !mutations.isEmpty else { return }

        var cMutations: [anigma_scene_graph_mutation_t] = []
        cMutations.reserveCapacity(mutations.count)
        for mutation in mutations {
            cMutations.append(mutation.toCStruct())
        }
        var error = anigma_capsule_error_t()
        let status = cMutations.withUnsafeBufferPointer { buffer in
            anigma_scene_graph_apply_mutations(h, buffer.baseAddress, buffer.count, &error)
        }
        if status != ANIGMA_OK { throw NativeSceneGraphError("Batch mutation failed: \(status)") }
    }

    /// Attach a batch of nodes in one call.
    public func attach(nodes: [NativeSceneNode]) throws {
        guard !nodes.isEmpty else { return }
        try apply(nodes.map { SceneGraphMutation.attach($0) })
    }

    /// Detach a batch of entity IDs in one call.
    public func detach(entityIds: [UInt64]) throws {
        guard !entityIds.isEmpty else { return }
        try apply(entityIds.map { SceneGraphMutation.detach(entityId: $0) })
    }

    /// Update a batch of transforms in one call.
    public func updateTransforms(_ updates: [(entityId: UInt64, transform: Transform2D)]) throws {
        guard !updates.isEmpty else { return }
        try apply(updates.map { .updateTransform(entityId: $0.entityId, transform: $0.transform) })
    }
    
    /// Get a node by entity ID.
    public func getNode(entityId: UInt64) throws -> NativeSceneNode {
        guard let h = handle else { throw NativeSceneGraphError("Invalid handle") }
        var cNode = anigma_scene_node_t()
        var error = anigma_capsule_error_t()
        let status = anigma_scene_graph_get_node(h, entityId, &cNode, &error)
        if status != ANIGMA_OK { throw NativeSceneGraphError("Node not found") }
        return NativeSceneNode(from: cNode)
    }
    
    /// Get the number of nodes in the scene graph.
    public func nodeCount() -> Int {
        guard let h = handle else { return 0 }
        var count: Int = 0
        anigma_scene_graph_get_node_count(h, &count, nil)
        return count
    }
    
    /// Get all nodes in the scene graph for serialization.
    public func getAllNodes() throws -> [anigma_scene_node_t] {
        return try withNodesBuffer { buffer in
            return Array(buffer)
        }
    }

    /// Borrow a shared nodes buffer for read-only access.
    /// - Note: The buffer is invalidated by the next scene graph mutation.
    public func withNodesBuffer<T>(
        _ body: (UnsafeBufferPointer<anigma_scene_node_t>) throws -> T
    ) throws -> T {
        guard let h = handle else { throw NativeSceneGraphError("Invalid handle") }
        var bufferPtr: UnsafePointer<anigma_scene_node_t>?
        var count: Int = 0
        var error = anigma_capsule_error_t()
        let status = anigma_scene_graph_get_nodes_buffer(h, &bufferPtr, &count, &error)
        guard status == ANIGMA_OK else {
            throw NativeSceneGraphError("Failed to get nodes buffer: \(status)")
        }
        let buffer = UnsafeBufferPointer(start: bufferPtr, count: count)
        return try body(buffer)
    }
    
    /// Evaluate all world transforms based on parent-child hierarchy.
    public func evaluateTransforms() throws {
        guard let h = handle else { throw NativeSceneGraphError("Invalid handle") }
        var error = anigma_capsule_error_t()
        let status = anigma_scene_graph_evaluate_transforms(h, &error)
        if status != ANIGMA_OK { throw NativeSceneGraphError("Evaluate transforms failed: \(status)") }
    }
    
    /// Provide unsafe access to the underlying graph handle for interoperability.
    public func withUnsafeGraph<T>(_ body: (anigma_scene_graph_t) throws -> T) rethrows -> T {
        guard let h = handle else { fatalError("SceneGraph handle is nil") }
        return try body(h)
    }
}
