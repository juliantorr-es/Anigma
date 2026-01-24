import Foundation
import CapsuleCore

public final class TextChunkingCapsule: IdentifiableCapsule {
    private let wrapper: TextChunkingCapsuleWrapper
    
    public init(config: TextChunkingConfig) throws {
        self.wrapper = try TextChunkingCapsuleWrapper(config: config)
    }
}
