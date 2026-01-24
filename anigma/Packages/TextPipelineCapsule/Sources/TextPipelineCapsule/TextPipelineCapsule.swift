import Foundation
import CapsuleCore

public final class TextPipelineCapsule: IdentifiableCapsule {
    private let wrapper: TextPipelineCapsuleWrapper
    
    public init(config: TextPipelineConfig) throws {
        self.wrapper = try TextPipelineCapsuleWrapper(config: config)
    }
}
