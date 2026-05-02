import Foundation

// Compatibility types for missing Capsule dependencies
public struct SceneNode {
    public let id: UInt64
    public var transform: [Float] // Placeholder transform
}

public enum SceneGraphMutation: Sendable {
    case attach(SceneNode)
    case detach(entityId: UInt64)
    case updateTransform(entityId: UInt64, transform: [Float])
}

public class SceneGraph {
    public init() throws {}
    public func attach(node: SceneNode) throws {}
    public func detach(entityId: UInt64) throws {}
    public func evaluateTransforms() throws {}
    public func apply(_ mutations: [SceneGraphMutation]) throws {}
    public func attach(nodes: [SceneNode]) throws {}
    public func detach(entityIds: [UInt64]) throws {}
    public func updateTransforms(_ updates: [(entityId: UInt64, transform: [Float])]) throws {}
    public func getAllNodes() throws -> [SceneNode] {
        return [] // Return empty for now
    }
}
