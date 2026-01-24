import Foundation
import CapsuleCore

public final class MediaContainerCapsule: IdentifiableCapsule {
    private let wrapper: MediaContainerCapsuleWrapper
    
    public init(config: MediaContainerConfig) throws {
        self.wrapper = try MediaContainerCapsuleWrapper(config: config)
    }
}
