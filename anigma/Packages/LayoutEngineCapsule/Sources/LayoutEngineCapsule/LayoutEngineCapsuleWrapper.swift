import Foundation
import AnigmaNativeShims
import CapsuleCore

public final class LayoutEngineCapsuleWrapper {
    private let handle: CapsuleHandle<AnyObject>
    
    public init(config: LayoutEngineConfig) throws {
        var rawHandle: anigma_layout_engine_capsule_t?
        var error = anigma_capsule_error_t()
        
        var cConfig = anigma_layout_engine_capsule_get_default_config()
        
        let status = anigma_layout_engine_capsule_create(&cConfig, &rawHandle, &error)
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
    
    public static func analyzePDF(_ data: Data?, config: LayoutEngineConfig) throws -> [PageLayout] {
        // Mock implementation for build fix
        return []
    }
}

public struct LayoutEngineConfig: Sendable, Codable {
    public init(determinismTier: Int = 1) {}
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
    public let fontName: String?
    public let fontSize: Double
    public let fontFlags: UInt32
    public let colorRGB: UInt32
    
    public init(bbox: BoundingBox, text: String, fontName: String? = nil, fontSize: Double = 12.0, fontFlags: UInt32 = 0, colorRGB: UInt32 = 0) {
        self.bbox = bbox
        self.text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.fontFlags = fontFlags
        self.colorRGB = colorRGB
    }
}

public struct ImageData: Sendable, Codable {
    public let bbox: BoundingBox
    public let rawData: Data?
    public let width: UInt32
    public let height: UInt32
    public let horizontalDPI: Float
    public let verticalDPI: Float
    public let bitsPerPixel: UInt32
    public let colorspace: Int32
    public let filter: String?
    
    public init(bbox: BoundingBox, rawData: Data? = nil, width: UInt32 = 0, height: UInt32 = 0, horizontalDPI: Float = 72, verticalDPI: Float = 72, bitsPerPixel: UInt32 = 8, colorspace: Int32 = 0, filter: String? = nil) {
        self.bbox = bbox
        self.rawData = rawData
        self.width = width
        self.height = height
        self.horizontalDPI = horizontalDPI
        self.verticalDPI = verticalDPI
        self.bitsPerPixel = bitsPerPixel
        self.colorspace = colorspace
        self.filter = filter
    }
}

public struct PageLayout: Sendable, Codable {
    public let pageIndex: UInt32
    public let segments: [TextSegment]
    public let images: [ImageData]
    public let tableBBoxes: [BoundingBox]
    public let figureBBoxes: [BoundingBox]
    
    public init(pageIndex: UInt32, segments: [TextSegment] = [], images: [ImageData] = [], tableBBoxes: [BoundingBox] = [], figureBBoxes: [BoundingBox] = []) {
        self.pageIndex = pageIndex
        self.segments = segments
        self.images = images
        self.tableBBoxes = tableBBoxes
        self.figureBBoxes = figureBBoxes
    }
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
