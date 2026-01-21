import Foundation
import AnigmaNativeShims
import AnigmaPrimitives
import CapsuleCore

/// Swift wrapper for the layout engine capsule with PDFium integration.
/// Provides PDF layout analysis including text extraction with bounding boxes,
/// font metrics, spatial indexing, and table/figure detection.
public final class LayoutEngineCapsuleWrapper {
    /// Capsule identity information.
    public static var identity: anigma_capsule_identity_t {
        anigma_layout_engine_capsule_get_identity()
    }
    
    private var handle: CapsuleHandle<AnyObject>?
    private let config: LayoutEngineConfig
    private var currentLayout: [PageLayout] = []
    private let lock = NSLock()
    
    /// Configuration used for this capsule.
    public var configuration: LayoutEngineConfig { config }
    
    /// Create a layout engine capsule with the given configuration.
    /// - Parameter config: Configuration for PDF layout analysis.
    ///   If nil, uses default configuration.
    public init(config: LayoutEngineConfig? = nil) throws {
        let config = config ?? LayoutEngineConfig.default
        var rawHandle: anigma_layout_engine_capsule_t?
        var error = anigma_capsule_error_t()
        
        var cConfig = config.toCStruct()
        let status = anigma_layout_engine_capsule_create(&cConfig, &rawHandle, &error)
        guard status == ANIGMA_OK, let rawHandle = rawHandle else {
            throw CapsuleError(status: status, error: error)
        }
        
        self.handle = CapsuleHandle<AnyObject>(
            rawHandle: rawHandle,
            destroyFunction: anigma_layout_engine_capsule_destroy
        )
        self.config = config
    }
    
    deinit {
        handle?.invalidate()
    }
    
    /// Analyze PDF data and extract layout information.
    /// - Parameter pdfData: PDF document data.
    /// - Returns: Array of page layouts.
    public func analyzePDF(_ pdfData: Data) throws -> [PageLayout] {
        var error = anigma_capsule_error_t()
        var actualPages: size_t = 0
        
        // Phase 1: Query required size
        let queryStatus = try handle?.withHandle { rawHandle in
            pdfData.withUnsafeBytes { bytes in
                anigma_layout_engine_capsule_analyze_pdf(
                    rawHandle,
                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    pdfData.count,
                    nil,
                    0,
                    &actualPages,
                    &error
                )
            }
        }
        
        guard let status = queryStatus, status == ANIGMA_OK else {
            throw CapsuleError(status: queryStatus ?? ANIGMA_ERR_INTERNAL, error: error)
        }
        
        guard actualPages > 0 else {
            return []
        }
        
        // Allocate buffer for page layouts
        var cLayouts = [anigma_page_layout_t](
            repeating: anigma_page_layout_t(
                page_index: 0,
                segment_count: 0,
                segments: nil,
                table_count: 0,
                table_bboxes: nil,
                figure_count: 0,
                figure_bboxes: nil,
                image_count: 0,
                images: nil
            ),
            count: Int(actualPages)
        )
        
        // Phase 2: Get actual layouts
        let fillStatus = try handle?.withHandle { rawHandle in
            pdfData.withUnsafeBytes { bytes in
                anigma_layout_engine_capsule_analyze_pdf(
                    rawHandle,
                    bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    pdfData.count,
                    &cLayouts,
                    actualPages,
                    &actualPages,
                    &error
                )
            }
        }
        
        guard let status = fillStatus, status == ANIGMA_OK else {
            throw CapsuleError(status: fillStatus ?? ANIGMA_ERR_INTERNAL, error: error)
        }
        
        // Convert C layouts to Swift structures
        var layouts: [PageLayout] = []
        for i in 0..<Int(actualPages) {
            layouts.append(PageLayout(from: cLayouts[i]))
        }
        
        // Free the C layouts (capsule-allocated memory)
        try handle?.withHandle { rawHandle in
            for i in 0..<Int(actualPages) {
                let _ = anigma_layout_engine_capsule_free_layout(rawHandle, &cLayouts[i], &error)
            }
        }
        
        currentLayout = layouts
        return layouts
    }
    
    /// Get spatial index for a page (for efficient region queries).
    /// - Parameter pageIndex: Page index (0-based).
    /// - Returns: Opaque handle to spatial index.
    public func getSpatialIndex(forPage pageIndex: UInt32) throws -> SpatialIndexHandle {
        var indexHandle: UnsafeMutableRawPointer?
        var error = anigma_capsule_error_t()
        
        let status = try handle?.withHandle { rawHandle in
            anigma_layout_engine_capsule_get_spatial_index(
                rawHandle,
                pageIndex,
                &indexHandle,
                &error
            )
        }
        
        guard let status = status, status == ANIGMA_OK, let indexHandle = indexHandle else {
            throw CapsuleError(status: status ?? ANIGMA_ERR_INTERNAL, error: error)
        }
        
        return SpatialIndexHandle(raw: indexHandle)
    }
    
    /// Query elements within a bounding box using spatial index.
    /// - Parameters:
    ///   - index: Spatial index handle from `getSpatialIndex`.
    ///   - bbox: Bounding box to query.
    ///   - maxElements: Maximum number of elements to return.
    /// - Returns: Array of element indices within the bounding box.
    public func queryBoundingBox(
        _ index: SpatialIndexHandle,
        bbox: BoundingBox,
        maxElements: Int = 1000
    ) throws -> [UInt32] {
        var actual: size_t = 0
        var error = anigma_capsule_error_t()
        var indices = [UInt32](repeating: 0, count: maxElements)
        
        var cBbox = bbox.toCStruct()
        let status = try handle?.withHandle { rawHandle in
            anigma_layout_engine_capsule_query_bbox(
                rawHandle,
                index.raw,
                &cBbox,
                &indices,
                maxElements,
                &actual,
                &error
            )
        }

        guard let status = status, status == ANIGMA_OK else {
            throw CapsuleError(status: status ?? ANIGMA_ERR_INTERNAL, error: error)
        }

        
        return Array(indices.prefix(Int(actual)))
    }
    
    /// Get profiling statistics for the layout engine capsule.
    /// Statistics are cumulative across all PDF analyses performed with this handle.
    /// If profiling flag is not enabled, values may be zero.
    public func getProfilingStats() throws -> LayoutEngineProfilingStats {
        var error = anigma_capsule_error_t()
        var cStats = anigma_layout_engine_profiling_stats_t()
        let status = try handle?.withHandle { rawHandle in
            anigma_layout_engine_capsule_get_profiling_stats(rawHandle, &cStats, &error)
        }
        guard let status = status, status == ANIGMA_OK else {
            throw CapsuleError(status: status ?? ANIGMA_ERR_INTERNAL, error: error)
        }
        return LayoutEngineProfilingStats(from: cStats)
    }
    
    /// Reset the capsule state for new analysis.
    public func reset() {
        currentLayout.removeAll()
        // Note: The C capsule doesn't have a reset function yet
        // We'll need to destroy and recreate, or add reset function
    }
}

// MARK: - Configuration Types

/// Configuration for PDF layout analysis.
public struct LayoutEngineConfig: Sendable {
    public var determinismTier: UInt32
    public var flags: UInt32
    public var maxElementsPerPage: Int
    public var mergeTextThreshold: Double
    public var tableDetectionConfidence: Double
    
    public static var `default`: LayoutEngineConfig {
        let cConfig = anigma_layout_engine_capsule_get_default_config()
        return LayoutEngineConfig(from: cConfig)
    }
    
    public init(
        determinismTier: UInt32 = 1,
        flags: UInt32 = 0,
        maxElementsPerPage: Int = 10000,
        mergeTextThreshold: Double = 5.0,
        tableDetectionConfidence: Double = 0.8
    ) {
        self.determinismTier = determinismTier
        self.flags = flags
        self.maxElementsPerPage = maxElementsPerPage
        self.mergeTextThreshold = mergeTextThreshold
        self.tableDetectionConfidence = tableDetectionConfidence
    }
    
    public func validate() throws {
        var error = anigma_capsule_error_t()
        var cConfig = toCStruct()
        let status = anigma_layout_engine_capsule_validate_config(&cConfig, &error)
        guard status == ANIGMA_OK else {
            throw CapsuleError(status: status, error: error)
        }
    }
    
    internal func toCStruct() -> anigma_layout_engine_config_t {
        anigma_layout_engine_config_t(
            determinism_tier: determinismTier,
            flags: flags,
            max_elements_per_page: maxElementsPerPage,
            merge_text_threshold: mergeTextThreshold,
            table_detection_confidence: tableDetectionConfidence
        )
    }
    
    internal init(from cConfig: anigma_layout_engine_config_t) {
        self.determinismTier = cConfig.determinism_tier
        self.flags = cConfig.flags
        self.maxElementsPerPage = cConfig.max_elements_per_page
        self.mergeTextThreshold = cConfig.merge_text_threshold
        self.tableDetectionConfidence = cConfig.table_detection_confidence
    }
}

/// Bounding box in PDF coordinates (points).
public struct BoundingBox: Sendable {
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
    
    internal func toCStruct() -> anigma_bounding_box_t {
        anigma_bounding_box_t(left: left, top: top, right: right, bottom: bottom)
    }
    
    internal init(from cBox: anigma_bounding_box_t) {
        self.left = cBox.left
        self.top = cBox.top
        self.right = cBox.right
        self.bottom = cBox.bottom
    }
    
    /// Width of the bounding box.
    public var width: Double { right - left }
    
    /// Height of the bounding box.
    public var height: Double { bottom - top }
}

/// Text segment with styling information.
public struct TextSegment: Sendable {
    public var bbox: BoundingBox
    public var text: String
    public var fontName: String?
    public var fontSize: Double
    public var fontFlags: UInt32
    public var colorRGB: UInt32
    
    internal init(from cSegment: anigma_text_segment_t) {
        self.bbox = BoundingBox(from: cSegment.bbox)
        self.text = cSegment.text.map { String(cString: $0) } ?? ""
        self.fontName = cSegment.font_name.map { String(cString: $0) }
        self.fontSize = cSegment.font_size
        self.fontFlags = cSegment.font_flags
        self.colorRGB = cSegment.color_rgb
    }
}

/// Image data with metadata and raw bytes.
public struct ImageData: Sendable {
    public var bbox: BoundingBox
    public var rawData: Data?
    public var width: UInt32
    public var height: UInt32
    public var horizontalDPI: Float
    public var verticalDPI: Float
    public var bitsPerPixel: UInt32
    public var colorspace: Int32
    public var filter: String?
    
    internal init(from cImage: anigma_image_data_t) {
        self.bbox = BoundingBox(from: cImage.bbox)
        if let rawDataPtr = cImage.raw_data, cImage.raw_data_len > 0 {
            self.rawData = Data(bytes: rawDataPtr, count: cImage.raw_data_len)
        } else {
            self.rawData = nil
        }
        self.width = cImage.width
        self.height = cImage.height
        self.horizontalDPI = cImage.horizontal_dpi
        self.verticalDPI = cImage.vertical_dpi
        self.bitsPerPixel = cImage.bits_per_pixel
        self.colorspace = cImage.colorspace
        self.filter = cImage.filter.map { String(cString: $0) }
    }
}

/// Page layout analysis result.
public struct PageLayout: Sendable {
    public var pageIndex: UInt32
    public var segments: [TextSegment]
    public var tableBBoxes: [BoundingBox]
    public var figureBBoxes: [BoundingBox]
    public var images: [ImageData]
    
    internal init(from cLayout: anigma_page_layout_t) {
        self.pageIndex = cLayout.page_index
        
        // Convert segments
        var segments: [TextSegment] = []
        if let cSegments = cLayout.segments {
            for i in 0..<cLayout.segment_count {
                segments.append(TextSegment(from: cSegments[Int(i)]))
            }
        }
        self.segments = segments
        
        // Convert table bounding boxes
        var tableBBoxes: [BoundingBox] = []
        if let cTables = cLayout.table_bboxes {
            for i in 0..<cLayout.table_count {
                tableBBoxes.append(BoundingBox(from: cTables[Int(i)]))
            }
        }
        self.tableBBoxes = tableBBoxes
        
        // Convert figure bounding boxes
        var figureBBoxes: [BoundingBox] = []
        if let cFigures = cLayout.figure_bboxes {
            for i in 0..<cLayout.figure_count {
                figureBBoxes.append(BoundingBox(from: cFigures[Int(i)]))
            }
        }
        self.figureBBoxes = figureBBoxes
        
        // Convert images
        var images: [ImageData] = []
        if let cImages = cLayout.images {
            for i in 0..<cLayout.image_count {
                images.append(ImageData(from: cImages[Int(i)]))
            }
        }
        self.images = images
    }
}

/// Opaque handle to spatial index for region queries.
public struct SpatialIndexHandle {
    let raw: UnsafeMutableRawPointer
}

/// Profiling statistics for layout engine capsule.
public struct LayoutEngineProfilingStats: Sendable {
    public var totalCharsProcessed: Int
    public var totalSegmentsCreated: Int
    public var totalPagesProcessed: Int
    public var pdfLoadTimeMs: Double
    public var textExtractionTimeMs: Double
    public var spatialIndexBuildTimeMs: Double
    public var totalAnalysisTimeMs: Double
    
    internal init(from cStats: anigma_layout_engine_profiling_stats_t) {
        self.totalCharsProcessed = Int(cStats.total_chars_processed)
        self.totalSegmentsCreated = Int(cStats.total_segments_created)
        self.totalPagesProcessed = Int(cStats.total_pages_processed)
        self.pdfLoadTimeMs = cStats.pdf_load_time_ms
        self.textExtractionTimeMs = cStats.text_extraction_time_ms
        self.spatialIndexBuildTimeMs = cStats.spatial_index_build_time_ms
        self.totalAnalysisTimeMs = cStats.total_analysis_time_ms
    }
}

// MARK: - Convenience Methods

extension LayoutEngineCapsuleWrapper {
    /// One-shot PDF layout analysis.
    /// - Parameters:
    ///   - pdfData: PDF document data.
    ///   - config: Configuration (optional, defaults to default config).
    /// - Returns: Array of page layouts.
    public static func analyzePDF(_ pdfData: Data, config: LayoutEngineConfig? = nil) throws -> [PageLayout] {
        let wrapper = try LayoutEngineCapsuleWrapper(config: config)
        return try wrapper.analyzePDF(pdfData)
    }
}

