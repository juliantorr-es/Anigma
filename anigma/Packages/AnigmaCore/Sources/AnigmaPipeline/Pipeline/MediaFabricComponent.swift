import Foundation
import AnigmaPrimitives
import ContractsCore

/// Component that maps an ECS entity to a hardware-accelerated media surface.
/// Managed within the Saturated Fabric for copy-minimized continuity.
public struct MediaFabricComponent: Component, Sendable {
    public let surface: MediaSurface
    public let lane: MediaLane
    public let createdAt: Date
    
    public init(surface: MediaSurface, lane: MediaLane) {
        self.surface = surface
        self.lane = lane
        self.createdAt = Date()
    }
}
