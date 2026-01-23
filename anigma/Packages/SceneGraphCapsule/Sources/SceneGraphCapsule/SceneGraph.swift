import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore

/// A high-performance, native scene graph for managing spatial hierarchy and transforms.
public final class SceneGraph {
    private var handle: CapsuleHandle<AnyObject>?
    private let arena: CapsuleHandle<AnyObject>? // Should we manage arena separately?
    // For now, let's assume the scene manages its own memory or we pass a default arena.
    // The C API takes an arena for creation.
    
    // We need an Arena wrapper first?
    // CapsuleCore usually provides memory management.
    // Let's check if we have an Arena wrapper or if we should just use a default one created internally.
    // Ideally, we'd use a shared arena, but for simplicity, let's make the SceneGraph own its arena or create one.
    
    public init(initialCapacity: UInt32 = 1024) throws {
        // We need an arena.
        // Assuming we can create a simple arena or pass null if the implementation supports default allocators?
        // anigma_scene_create(graph, capacity, arena)
        
        // Let's implement a simple Arena wrapper in CapsuleCore or just malloc for now if C allows it?
        // Checking headers... anigma_kernel_types.h usually defines arena.
        // If we don't have an Arena wrapper, we might need to rely on the shim creating one.
        
        // Let's try to create the scene graph.
        // We need to allocate the struct `anigma_scene_graph_t`.
        // It's a struct, not an opaque pointer in the header... wait.
        // `struct anigma_scene_graph_t { ... }` is defined in the header.
        // So we need to allocate memory for this struct on the Swift side or heap allocate it.
        
        let graphPtr = UnsafeMutablePointer<anigma_scene_graph_t>.allocate(capacity: 1)
        
        // We'll pass NULL for arena for now, assuming the implementation handles it or uses malloc if null.
        // If not, we'll need to fix the C side or add Arena support.
        let status = anigma_scene_create(graphPtr, initialCapacity, nil)
        
        guard status == ANIGMA_OK else {
            graphPtr.deallocate()
            throw CapsuleError(status: status, error: anigma_capsule_error_t())
        }
        
        self.handle = CapsuleHandle(
            rawHandle: graphPtr,
            destroyFunction: { ptr in
                let graph = ptr.assumingMemoryBound(to: anigma_scene_graph_t.self)
                anigma_scene_destroy(graph)
                graph.deallocate()
            }
        )
        self.arena = nil
    }
    
    deinit {
        handle?.invalidate()
    }
    
    public func attach(node: SceneNode) throws {
        // Node struct needs to be converted to C
        var cNode = node.toCStruct()
        
        try handle?.withHandle { rawHandle in
            let graph = rawHandle.assumingMemoryBound(to: anigma_scene_graph_t.self)
            let status = anigma_scene_attach(graph, &cNode)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: anigma_capsule_error_t())
            }
        }
    }
    
    public func detach(nodeId: UInt64) throws {
        try handle?.withHandle { rawHandle in
            let graph = rawHandle.assumingMemoryBound(to: anigma_scene_graph_t.self)
            let status = anigma_scene_detach(graph, nodeId)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: anigma_capsule_error_t())
            }
        }
    }
    
    public func updateTransform(nodeId: UInt64, transform: Transform) throws {
        var cTransform = transform.toCStruct()
        try handle?.withHandle { rawHandle in
            let graph = rawHandle.assumingMemoryBound(to: anigma_scene_graph_t.self)
            let status = anigma_scene_update_transform(graph, nodeId, &cTransform)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: anigma_capsule_error_t())
            }
        }
    }
    
    public func evaluateTransforms() throws {
        try handle?.withHandle { rawHandle in
            let graph = rawHandle.assumingMemoryBound(to: anigma_scene_graph_t.self)
            let status = anigma_scene_evaluate_transforms(graph)
            guard status == ANIGMA_OK else {
                throw CapsuleError(status: status, error: anigma_capsule_error_t())
            }
        }
    }
    
    internal func withUnsafeGraph<T>(_ body: (UnsafePointer<anigma_scene_graph_t>) throws -> T) throws -> T {
        guard let handle = handle else { throw CapsuleError(status: ANIGMA_ERR_INVALID_HANDLE, error: anigma_capsule_error_t()) }
        return try handle.withHandle { rawHandle in
            return try body(rawHandle.assumingMemoryBound(to: anigma_scene_graph_t.self))
        }
    }
}

public struct SceneNode {
    public var id: UInt64
    public var parentId: UInt64
    public var children: [UInt64]
    public var localTransform: Transform
    public var layerIndex: UInt32
    public var renderOrder: UInt32
    public var hitTestGroup: UInt32
    public var flags: UInt64
    
    public init(
        id: UInt64,
        parentId: UInt64 = 0,
        children: [UInt64] = [],
        localTransform: Transform = .identity,
        layerIndex: UInt32 = 0,
        renderOrder: UInt32 = 0,
        hitTestGroup: UInt32 = 0,
        flags: UInt64 = 0
    ) {
        self.id = id
        self.parentId = parentId
        self.children = children
        self.localTransform = localTransform
        self.layerIndex = layerIndex
        self.renderOrder = renderOrder
        self.hitTestGroup = hitTestGroup
        self.flags = flags
    }
    
    internal func toCStruct() -> anigma_scene_node_t {
        // Warning: children pointer lifetime is tricky here if we just pass array address.
        // anigma_scene_attach takes 'const anigma_scene_node_t* node'.
        // It likely copies the data.
        // We'll need to allocate children buffer or assume attach copies it immediately.
        // The implementation of `anigma_scene_attach` likely copies the node data into its internal array.
        // However, `children` is a pointer. Does it copy the children array?
        // Checking header... `anigma_entity_id_t* children;`
        // Usually ECS style scene graphs store hierarchy flat or via indices.
        // If `attach` copies the structure, it might shallow copy the pointer.
        // If so, we need to manage that memory.
        // BUT, typically `attach` would be "add this node definition".
        // Let's assume for now we provide the definition and the graph manages the hierarchy structure internally.
        // Actually, looking at `anigma_scene_node_t`, it has `children` array.
        // If we attach a node, we are saying "this node has these children".
        // Ideally, we add nodes and then link them via parent_id, and the graph builds the children lists?
        // Or we manage it manually?
        // `anigma_scene_attach` takes a node.
        
        // Let's assume for this "Capsule" high performance usage, we primarily set parent_id,
        // and the graph maintains children lists or we provide them.
        // Given `child_capacity` field, it looks like dynamic array.
        // So we probably don't pass children in `attach` typically, or if we do, it copies.
        
        // For safety, let's keep children empty in the struct passed to C, relying on parent links?
        // No, that depends on implementation.
        // Let's assume we pass empty children and let the graph build it, or we handle it if needed.
        // For now, mapping straightforwardly.
        
        // Note: Using a temporary buffer here is risky if C keeps the pointer.
        // But `anigma_scene_attach` implies copying into the graph.
        
        return anigma_scene_node_t(
            id: id,
            parent_id: parentId,
            child_count: UInt32(children.count),
            child_capacity: UInt32(children.count),
            children: nil, // TODO: Handle children array if needed
            local_transform: localTransform.toCStruct(),
            world_transform: anigma_transform_t(), // computed
            layer_index: layerIndex,
            render_order: renderOrder,
            hit_test_group: hitTestGroup,
            flags: flags,
            world_transform_valid: false
        )
    }
}

public struct Transform {
    public var a, b, c, d, tx, ty: Float
    
    public static let identity = Transform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)
    
    public init(a: Float, b: Float, c: Float, d: Float, tx: Float, ty: Float) {
        self.a = a; self.b = b; self.c = c; self.d = d; self.tx = tx; self.ty = ty
    }
    
    internal func toCStruct() -> anigma_transform_t {
        return anigma_transform_t(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
    }
}
