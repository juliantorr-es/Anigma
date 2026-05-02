import Foundation
import CapsuleCore

public final class MediaContainerCapsule: IdentifiableCapsule {
    public typealias VideoCodec = MediaContainerCapsuleWrapper.VideoCodec
    public typealias AudioCodec = MediaContainerCapsuleWrapper.AudioCodec
    
    private let wrapper: MediaContainerCapsuleWrapper
    
    public init(config: MediaContainerConfig) throws {
        self.wrapper = try MediaContainerCapsuleWrapper(config: config)
    }
}
