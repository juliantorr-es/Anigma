import Foundation

/// Runtime orchestrator - coordinates scene graph and render plan generation
public actor RuntimeOrchestrator {
    private let sceneGraph: SceneGraph
    private var viewportWidth: Double = 800
    private var viewportHeight: Double = 600
    private var displayScale: Float = 2.0
    
    public init() throws {
        self.sceneGraph = try SceneGraph()
    }
    
    public func attach(node: SceneNode) throws {
        try sceneGraph.attach(node: node)
    }
    
    public func detach(entityId: UInt64) throws {
        try sceneGraph.detach(entityId: entityId)
    }
    
    public func evaluateTransforms() throws {
        try sceneGraph.evaluateTransforms()
    }
    
    public func updateViewport(width: Double, height: Double, scale: Float) {
        self.viewportWidth = width
        self.viewportHeight = height
        self.displayScale = scale
    }
    
    public func frameTick() throws -> Data {
        // 1. Evaluate transforms
        try sceneGraph.evaluateTransforms()
        
        // 2. Iterate through the SceneGraph, extract node transforms/properties, and serialize
        let nodes = try sceneGraph.getAllNodes()
        if nodes.isEmpty {
            return Data()
        }
        
        // Serialize to binary format (simple C-struct array)
        return nodes.withUnsafeBytes { buffer in
            return Data(buffer)
        }
    }
}
