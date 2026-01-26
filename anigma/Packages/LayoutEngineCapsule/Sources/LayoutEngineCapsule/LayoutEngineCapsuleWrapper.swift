import Foundation
import AnigmaNativeShims
import CapsuleCore

public final class LayoutEngineCapsuleWrapper {
    private let handle: CapsuleHandle<AnyObject>
    
    public init(config: LayoutEngineConfig) throws {
        var rawHandle: anigma_layout_engine_capsule_t?
        var error = anigma_capsule_error_t()
        
        var cConfig = anigma_layout_engine_capsule_get_default_config()
        cConfig.determinism_tier = UInt32(config.determinismTier)
        cConfig.flags = config.flags
        
        let status = anigma_layout_engine_capsule_create(&cConfig, &rawHandle, &error)
        guard status == ANIGMA_OK, let finalHandle = rawHandle else {
            throw capsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: finalHandle,
            destroyFunction: capsuleDestroyer(anigma_layout_engine_capsule_destroy)
        )
    }
    
    public func analyzePDF(_ data: Data) throws -> [PageLayout] {
        var error = anigma_capsule_error_t()
        var actualCount: Int = 0
        
        let status = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> anigma_status_t in
            guard let baseAddress = bytes.baseAddress else { return ANIGMA_ERR_INVALID_ARG }
            return anigma_layout_engine_capsule_analyze_pdf(
                handle.rawHandle,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                0,
                &actualCount,
                &error
            )
        }
        
        guard status == ANIGMA_OK else {
            throw capsuleError(status: status, error: error)
        }
        
        var cLayouts = [anigma_page_layout_t](repeating: anigma_page_layout_t(), count: actualCount)
        let finalStatus = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> anigma_status_t in
            guard let baseAddress = bytes.baseAddress else { return ANIGMA_ERR_INVALID_ARG }
            return anigma_layout_engine_capsule_analyze_pdf(
                handle.rawHandle,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                &cLayouts,
                actualCount,
                &actualCount,
                &error
            )
        }
        
        guard finalStatus == ANIGMA_OK else {
            throw capsuleError(status: finalStatus, error: error)
        }
        
        defer {
            for i in 0..<actualCount {
                var layout = cLayouts[i]
                _ = anigma_layout_engine_capsule_free_layout(handle.rawHandle, &layout, &error)
            }
        }
        
        return cLayouts.map { PageLayout(from: $0) }
    }
    
    public static func analyzePDF(_ data: Data?, config: LayoutEngineConfig) throws -> [PageLayout] {
        guard let data = data else { return [] }
        let wrapper = try LayoutEngineCapsuleWrapper(config: config)
        return try wrapper.analyzePDF(data)
    }
}

public struct LayoutEngineConfig: Sendable, Codable {
    public var determinismTier: Int
    public var flags: UInt32
    
    public init(determinismTier: Int = 1, flags: UInt32 = 0) {
        self.determinismTier = determinismTier
        self.flags = flags
    }
    
    public static let extractFontMetrics: UInt32 = 1 << 0
    public static let detectTables: UInt32 = 1 << 1
    public static let detectFigures: UInt32 = 1 << 2
    public static let extractImages: UInt32 = 1 << 3
    public static let enableProfiling: UInt32 = 1 << 4
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
    
    init(from cBbox: anigma_bounding_box_t) {
        self.left = cBbox.left
        self.top = cBbox.top
        self.right = cBbox.right
        self.bottom = cBbox.bottom
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
    
    init(from cSeg: anigma_text_segment_t) {
        self.bbox = BoundingBox(from: cSeg.bbox)
        self.text = String(cString: cSeg.text)
        self.fontName = cSeg.font_name != nil ? String(cString: cSeg.font_name!) : nil
        self.fontSize = cSeg.font_size
        self.fontFlags = cSeg.font_flags
        self.colorRGB = cSeg.color_rgb
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
    
    init(from cImg: anigma_image_data_t) {
        self.bbox = BoundingBox(from: cImg.bbox)
        if let dataPtr = cImg.raw_data {
            self.rawData = Data(bytes: dataPtr, count: cImg.raw_data_len)
        } else {
            self.rawData = nil
        }
        self.width = UInt32(cImg.width)
        self.height = UInt32(cImg.height)
        self.horizontalDPI = cImg.horizontal_dpi
        self.verticalDPI = cImg.vertical_dpi
        self.bitsPerPixel = UInt32(cImg.bits_per_pixel)
        self.colorspace = Int32(cImg.colorspace)
        self.filter = cImg.filter != nil ? String(cString: cImg.filter!) : nil
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
    
    init(from cLayout: anigma_page_layout_t) {
        self.pageIndex = cLayout.page_index
        
        var segments = [TextSegment]()
        if let cSegments = cLayout.segments {
            for i in 0..<Int(cLayout.segment_count) {
                segments.append(TextSegment(from: cSegments[i]))
            }
        }
        self.segments = segments
        
        var images = [ImageData]()
        if let cImages = cLayout.images {
            for i in 0..<Int(cLayout.image_count) {
                images.append(ImageData(from: cImages[i]))
            }
        }
        self.images = images
        
        var tableBBoxes = [BoundingBox]()
        if let cTables = cLayout.table_bboxes {
            for i in 0..<Int(cLayout.table_count) {
                tableBBoxes.append(BoundingBox(from: cTables[i]))
            }
        }
        self.tableBBoxes = tableBBoxes
        
        var figureBBoxes = [BoundingBox]()
        if let cFigures = cLayout.figure_bboxes {
            for i in 0..<Int(cLayout.figure_count) {
                figureBBoxes.append(BoundingBox(from: cFigures[i]))
            }
        }
        self.figureBBoxes = figureBBoxes
    }
}

public struct LayoutProfilingStats: Sendable, Codable {
    public var totalCharsProcessed: Int
    public var totalSegmentsCreated: Int
    public var totalPagesProcessed: Int
    public var pdfLoadTimeMs: Double
    public var textExtractionTimeMs: Double
    public var spatialIndexBuildTimeMs: Double
    public var totalAnalysisTimeMs: Double
    
    init(from cStats: anigma_layout_engine_profiling_stats_t) {
        self.totalCharsProcessed = Int(cStats.total_chars_processed)
        self.totalSegmentsCreated = Int(cStats.total_segments_created)
        self.totalPagesProcessed = Int(cStats.total_pages_processed)
        self.pdfLoadTimeMs = cStats.pdf_load_time_ms
        self.textExtractionTimeMs = cStats.text_extraction_time_ms
        self.spatialIndexBuildTimeMs = cStats.spatial_index_build_time_ms
        self.totalAnalysisTimeMs = cStats.total_analysis_time_ms
    }
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

private func capsuleError(status: anigma_status_t, error: anigma_capsule_error_t) -> CapsuleError {
    let message = error.message.map { String(cString: $0) } ?? "Capsule error"
    return CapsuleError(status: status, code: error.code, message: message)
}

private func capsuleDestroyer(
    _ destroy: @escaping (UnsafeMutableRawPointer, UnsafeMutablePointer<anigma_capsule_error_t>) -> anigma_status_t
) -> (UnsafeMutableRawPointer) -> Void {
    { ptr in
        var err = anigma_capsule_error_t()
        _ = destroy(ptr, &err)
    }
}
