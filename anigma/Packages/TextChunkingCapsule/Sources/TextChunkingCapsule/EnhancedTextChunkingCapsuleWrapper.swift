import Foundation
import AnigmaNativeShims
import CapsuleCore

public final class EnhancedTextChunkingCapsuleWrapper {
    public init(config: TextChunkingConfig) throws {}
    public func chunk(_ data: Data, documentId: String) throws -> [EnhancedChunkBoundary] {
        return []
    }
}

public struct EnhancedChunkBoundary: Sendable, Codable {
    public let offset: Int
    public let length: Int
    public let stableId: String
}

public enum UnicodeForm: UInt32 {
    case none = 0
    case nfc = 1
}
