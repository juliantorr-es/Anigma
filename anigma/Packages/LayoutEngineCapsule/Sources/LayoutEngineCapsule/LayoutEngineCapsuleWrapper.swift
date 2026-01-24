import Foundation
import AnigmaNativeShims
import CapsuleCore

internal final class LayoutEngineCapsuleWrapper {
    private let handle: CapsuleHandle<AnyObject>
    
    init(config: LayoutEngineConfig) throws {
        var rawHandle: anigma_layout_engine_capsule_t?
        var error = anigma_capsule_error_t()
        
        let status = anigma_layout_engine_capsule_create(&rawHandle, &error)
        guard status == ANIGMA_OK, let finalHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: finalHandle,
            destroyFunction: { ptr, err in
                anigma_layout_engine_capsule_destroy(ptr, err)
            }
        )
    }
}

public struct LayoutEngineConfig: Sendable, Codable {
    public init() {}
}

public struct BoundingBox: Sendable, Codable {
    public var left: Double
    public var top: Double
    public var right: Double
    public var bottom: Double
    
    public init(left: Double, top: Double, right: Double, bottom: Double) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }
}

public struct TextSegment: Sendable, Codable {
    public let bbox: BoundingBox
    public let text: String
}

public struct ImageData: Sendable, Codable {
    public let bbox: BoundingBox
}

public struct PageLayout: Sendable, Codable {
    public let pageIndex: UInt32
    public let segments: [TextSegment]
    public let images: [ImageData]
}

public struct LayoutProfilingStats: Sendable, Codable {
    public init() {}
}

public struct OCRResult: Sendable, Codable {
    public let bbox: BoundingBox
    public let text: String
}

public struct FontAnalysis: Sendable, Codable {
    public let family: String
}

public enum LayoutElementType: UInt32, Sendable, Codable {
    case unknown = 0
}

public struct LayoutElement: Sendable, Codable {
    public let bbox: BoundingBox
    public let type: LayoutElementType
}

public struct DocumentStructure: Sendable, Codable {
    public let totalPages: UInt32
}

public struct ReadingOrder: Sendable, Codable {
    public let elementIds: [UInt32]
}
