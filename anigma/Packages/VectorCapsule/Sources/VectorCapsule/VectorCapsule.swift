import Foundation
import CapsuleCore

public final class VectorCapsule: IdentifiableCapsule {
    private let wrapper: VectorCapsuleWrapper
    
    public init() throws {
        self.wrapper = VectorCapsuleWrapper()
    }
}

public final class VectorPath {
    private let handle: CapsuleHandle<AnyObject>
    
    init(handle: CapsuleHandle<AnyObject>) {
        self.handle = handle
    }
    
    public func toSVG() throws -> String {
        return try VectorCapsuleWrapper.exportToSVG(capsule: handle)
    }
    
    public func simplify(tolerance: Double) throws -> VectorPath {
        let h = try VectorCapsuleWrapper.simplifyDouglasPeucker(capsule: handle, tolerance: tolerance)
        return VectorPath(handle: h)
    }
}
