import Foundation
import SceneGraphCapsule
import RenderPlanCapsule
import AnigmaNativeShims // For ANIGMA_COORDINATE_SCALE if needed

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
        
        // 2. Create RenderRequest
        let request = RenderRequest(
            viewport: Rect(x: 0, y: 0, w: Float(viewportWidth), h: Float(viewportHeight)),
            scaleFactor: displayScale,
            flags: 0
        )
        
        // 3. Generate RenderPlan
        let plan = try RenderPlan.generate(from: sceneGraph, request: request)
        
        // 4. Compute hash (optional, just to verify it works)
        try plan.computeHash()
        
        // Return dummy data for now as the original stub did, 
        // or return serialized plan if we had serialization.
        return Data()
    }
}
