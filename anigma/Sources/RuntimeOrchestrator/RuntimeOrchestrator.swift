import Foundation
import SceneGraphCapsule
import AnigmaNativeShims

public actor RuntimeOrchestrator {
    private let kernelBridge: KernelBridge
    private let sceneGraph: SceneGraph
    private var viewportSize: CGSize = .zero
    private var displayScale: Float = 2.0
    
    public init() throws {
        // Initialize with default config
        let config = Data([0]) // Dummy config
        self.kernelBridge = try KernelBridge(config: config)
        self.sceneGraph = try SceneGraph()
    }
    
    public func attach(node: SceneNode) throws {
        try sceneGraph.attach(node: node)
    }
    
    public func evaluateTransforms() throws {
        try sceneGraph.evaluateTransforms()
    }
    
    public func updateViewport(size: CGSize, scale: Float) {
        self.viewportSize = size
        self.displayScale = scale
    }
    
    public func frameTick() throws -> Data {
        // 1. Process inputs (omitted)
        // 2. Step simulation
        try kernelBridge.stepFixed(ticks: 1)
        
        // 3. Request render plan
        let viewportRequest = Data() // Should be a valid struct blob
        return try kernelBridge.renderPlan(viewportRequest: viewportRequest)
    }
}
