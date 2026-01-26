import Foundation

// Mocks for missing Capsule dependencies
public struct SceneNode {
    public let id: UInt64
    public var transform: [Float] // Mock transform
}

public class SceneGraph {
    public init() throws {}
    public func attach(node: SceneNode) throws {}
    public func detach(entityId: UInt64) throws {}
    public func evaluateTransforms() throws {}
    public func getAllNodes() throws -> [SceneNode] {
        return [] // Return empty for now
    }
}
