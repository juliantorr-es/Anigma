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
        var error = anigma_capsule_error_t()
        let status = try? handle?.withHandle { rawHandle in
            anigma_layout_engine_capsule_reset(rawHandle, config.preserveCaches ? 1 : 0, &error)
        }
        currentLayout.removeAll()
    }
    
    // MARK: - Advanced Features Methods
    
    /// Perform OCR analysis on a page to extract text from images.
    /// - Parameters:
    ///   - pageIndex: Page index (0-based).
    ///   - language: ISO 639-3 language code (e.g., "eng", "fra").
    /// - Throws: CapsuleError if OCR fails or is not available.
    public func performOCR(pageIndex: UInt32, language: String = "eng") throws {
        guard config.enableOCR else {
            throw CapsuleError.invalidState("OCR not enabled in configuration")
        }
        
        var error = anigma_capsule_error_t()
        let status = try handle?.withHandle { rawHandle in
            language.withCString { langPtr in
                anigma_layout_engine_capsule_perform_ocr(rawHandle, pageIndex, langPtr, &error)
            }
        }
        
        guard let status = status, status == ANIGMA_OK else {
            throw CapsuleError(status: status ?? ANIGMA_ERR_INTERNAL, error: error)
        }
    }
    
    /// Get OCR results for a page.
    /// - Parameter pageIndex: Page index (0-based).
    /// - Returns: Array of OCR results.
    public func getOCRResults(pageIndex: UInt32) throws -> [OCRResult] {
        var error = anigma_capsule_error_t()
        var actual: size_t = 0
        
        // Phase 1: Query required size
        let queryStatus = try handle?.withHandle { rawHandle in
            anigma_layout_engine_capsule_get_ocr_results(
                rawHandle, pageIndex, nil, 0, &actual, &error
            )
        }
        
        guard let status = queryStatus, status == ANIGMA_OK else {
            throw CapsuleError(status: status ?? ANIGMA_ERR_INTERNAL, error: error)
        }
        
        guard actual > 0 else {
            return []
        }
        
        // Phase 2: Get actual results
        var cResults = [anigma_ocr_result_t](repeating: anigma_ocr_result_t(), count: actual)
        let fillStatus = try handle?.withHandle { rawHandle in
            anigma_layout_engine_capsule_get_ocr_results(
                rawHandle, pageIndex, &cResults, actual, &actual, &error
            )
        }
        
        guard let status = fillStatus, status == ANIGMA_OK else {
            throw CapsuleError(status: status ?? ANIGMA_ERR_INTERNAL, error: error)
        }
        
        var results: [OCRResult] = []
        for i in 0..<actual {
            results.append(OCRResult(from: cResults[i]))
        }
        
        // Free C structures
        for i in 0..<actual {
            free(const_cast(char*, cResults[i].text))
            free(const_cast(char*, cResults[i].language))
        }
        
        return results
    }
    
    /// Perform advanced font analysis on text segments.
    /// - Parameter pageIndex: Page index (0-based).
    /// - Throws: CapsuleError if analysis fails.
    public func analyzeFonts(pageIndex: UInt32) throws {
        guard config.advancedFontAnalysis else {
            throw CapsuleError.invalidState("Advanced font analysis not enabled in configuration")
        }
        
        var error = anigma_capsule_error_t()
        let status = try handle?.withHandle { rawHandle in
            anigma_layout_engine_capsule_analyze_fonts(rawHandle, pageIndex, &error)
        }
        
        guard let status = status, status == ANIGMA_OK else {
            throw CapsuleError(status: status ?? ANIGMA_ERR_INTERNAL, error: error)
        }
    }
    
    /// Classify layout elements into semantic types.
    /// - Parameter pageIndex: Page index (0-based).
    /// - Throws: CapsuleError if classification fails.
    public func classifyLayout(pageIndex: UInt32) throws {
        guard config.layoutClassification else {
            throw CapsuleError.invalidState("Layout classification not enabled in configuration")
        }
        
        var error = anigma_capsule_error_t()
        let status = try handle?.withHandle { rawHandle in
            anigma_layout_engine_capsule_classify_layout(rawHandle, pageIndex, &error)
        }
        
        guard let status = status, status == ANIGMA_OK else {
            throw CapsuleError(status: status ?? ANIGMA_ERR_INTERNAL, error: error)
        }
    }
    
    /// Detect reading order for layout elements.
    /// - Parameter pageIndex: Page index (0-based).
    /// - Throws: CapsuleError if reading order detection fails.
    public func detectReadingOrder(pageIndex: UInt32) throws {
        guard config.readingOrderDetection else {
            throw CapsuleError.invalidState("Reading order detection not enabled in configuration")
        }
        
        var error = anigma_capsule_error_t()
        let status = try handle?.withHandle { rawHandle in
            anigma_layout_engine_capsule_detect_reading_order(rawHandle, pageIndex, &error)
        }
        
        guard let status = status, status == ANIGMA_OK else {
            throw CapsuleError(status: status ?? ANIGMA_ERR_INTERNAL, error: error)
        }
    }
    
    /// Analyze multi-page document structure.
    /// - Returns: Document structure information.
    /// - Throws: CapsuleError if analysis fails.
    public func analyzeDocumentStructure() throws -> DocumentStructure {
        guard config.multiPageAnalysis else {
            throw CapsuleError.invalidState("Multi-page analysis not enabled in configuration")
        }
        
        var error = anigma_capsule_error_t()
        var cStructure = anigma_document_structure_t()
        
        let status = try handle?.withHandle { rawHandle in
            anigma_layout_engine_capsule_analyze_document_structure(rawHandle, &cStructure, &error)
        }
        
        guard let status = status, status == ANIGMA_OK else {
            throw CapsuleError(status: status ?? ANIGMA_ERR_INTERNAL, error: error)
        }
        
        let structure = DocumentStructure(from: cStructure)
        
        // Free C structure memory
        if let titles = cStructure.section_titles {
            for i in 0..<cStructure.section_count {
                free(const_cast(char*, titles[Int(i)]))
            }
        }
        
        return structure
    }
    
    /// Get classified layout elements for a page.
    /// - Parameter pageIndex: Page index (0-based).
    /// - Returns: Array of layout elements.
    public func getLayoutElements(pageIndex: UInt32) throws -> [LayoutElement] {
        var error = anigma_capsule_error_t()
        var actual: size_t = 0
        
        // Phase 1: Query required size
        let queryStatus = try handle?.withHandle { rawHandle in
            anigma_layout_engine_capsule_get_layout_elements(
                rawHandle, pageIndex, nil, 0, &actual, &error
            )
        }
        
        guard let status = queryStatus, status == ANIGMA_OK else {
            throw CapsuleError(status: status ?? ANIGMA_ERR_INTERNAL, error: error)
        }
        
        guard actual > 0 else {
            return []
        }
        
        // Phase 2: Get actual elements
        var cElements = [anigma_layout_element_t](repeating: anigma_layout_element_t(), count: actual)
        let fillStatus = try handle?.withHandle { rawHandle in
            anigma_layout_engine_capsule_get_layout_elements(
                rawHandle, pageIndex, &cElements, actual, &actual, &error
            )
        }
        
        guard let status = fillStatus, status == ANIGMA_OK else {
            throw CapsuleError(status: status ?? ANIGMA_ERR_INTERNAL, error: error)
        }
        
        var elements: [LayoutElement] = []
        for i in 0..<actual {
            elements.append(LayoutElement(from: cElements[i]))
        }
        
        // Free C structures
        for i in 0..<actual {
            free(const_cast(char*, cElements[i].text))
            free(const_cast(char*, cElements[i].font.family))
            free(const_cast(char*, cElements[i].font.subfamily))
        }
        
        return elements
    }
    
    /// Get reading order information for a page.
    /// - Parameter pageIndex: Page index (0-based).
    /// - Returns: Reading order information.
    public func getReadingOrder(pageIndex: UInt32) throws -> ReadingOrder {
        var error = anigma_capsule_error_t()
        var cOrder = anigma_reading_order_t()
        
        let status = try handle?.withHandle { rawHandle in
            anigma_layout_engine_capsule_get_reading_order(rawHandle, pageIndex, &cOrder, &error)
        }
        
        guard let status = status, status == ANIGMA_OK else {
            throw CapsuleError(status: status ?? ANIGMA_ERR_INTERNAL, error: error)
        }
        
        let order = ReadingOrder(from: cOrder)
        
        // Free C structure memory
        if let elementIds = cOrder.element_ids {
            free(elementIds)
        }
        if let confidenceScores = cOrder.confidence_scores {
            free(confidenceScores)
        }
        
        return order
    }
    
    /// Validate OCR accuracy against ground truth text.
    /// - Parameters:
    ///   - pageIndex: Page index (0-based).
    ///   - groundTruthText: Reference text for comparison.
    /// - Returns: Tuple of (character accuracy, word accuracy).
    public func validateOCRAccuracy(pageIndex: UInt32, groundTruthText: String) throws -> (characterAccuracy: Double, wordAccuracy: Double) {
        var characterAccuracy: Double = 0.0
        var wordAccuracy: Double = 0.0
        var error = anigma_capsule_error_t()
        
        let status = try handle?.withHandle { rawHandle in
            groundTruthText.withCString { textPtr in
                anigma_layout_engine_capsule_validate_ocr_accuracy(
                    rawHandle, pageIndex, textPtr, &characterAccuracy, &wordAccuracy, &error
                )
            }
        }
        
        guard let status = status, status == ANIGMA_OK else {
            throw CapsuleError(status: status ?? ANIGMA_ERR_INTERNAL, error: error)
        }
        
        return (characterAccuracy: characterAccuracy, wordAccuracy: wordAccuracy)
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
    
    // Advanced feature flags
    public var extractFontMetrics: Bool {
        get { flags & 0x01 != 0 }
        set { flags = newValue ? (flags | 0x01) : (flags & ~0x01) }
    }
    
    public var detectTables: Bool {
        get { flags & 0x02 != 0 }
        set { flags = newValue ? (flags | 0x02) : (flags & ~0x02) }
    }
    
    public var detectFigures: Bool {
        get { flags & 0x04 != 0 }
        set { flags = newValue ? (flags | 0x04) : (flags & ~0x04) }
    }
    
    public var extractImages: Bool {
        get { flags & 0x08 != 0 }
        set { flags = newValue ? (flags | 0x08) : (flags & ~0x08) }
    }
    
    public var enableProfiling: Bool {
        get { flags & 0x10 != 0 }
        set { flags = newValue ? (flags | 0x10) : (flags & ~0x10) }
    }
    
    public var preserveCaches: Bool {
        get { flags & 0x20 != 0 }
        set { flags = newValue ? (flags | 0x20) : (flags & ~0x20) }
    }
    
    public var enableOCR: Bool {
        get { flags & 0x40 != 0 }
        set { flags = newValue ? (flags | 0x40) : (flags & ~0x40) }
    }
    
    public var advancedFontAnalysis: Bool {
        get { flags & 0x80 != 0 }
        set { flags = newValue ? (flags | 0x80) : (flags & ~0x80) }
    }
    
    public var layoutClassification: Bool {
        get { flags & 0x100 != 0 }
        set { flags = newValue ? (flags | 0x100) : (flags & ~0x100) }
    }
    
    public var readingOrderDetection: Bool {
        get { flags & 0x200 != 0 }
        set { flags = newValue ? (flags | 0x200) : (flags & ~0x200) }
    }
    
    public var multiPageAnalysis: Bool {
        get { flags & 0x400 != 0 }
        set { flags = newValue ? (flags | 0x400) : (flags & ~0x400) }
    }
    
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
    
    // Convenience initializer for advanced features
    public init(
        determinismTier: UInt32 = 1,
        maxElementsPerPage: Int = 10000,
        mergeTextThreshold: Double = 5.0,
        tableDetectionConfidence: Double = 0.8,
        extractFontMetrics: Bool = false,
        detectTables: Bool = true,
        detectFigures: Bool = true,
        extractImages: Bool = false,
        enableProfiling: Bool = false,
        preserveCaches: Bool = false,
        enableOCR: Bool = false,
        advancedFontAnalysis: Bool = false,
        layoutClassification: Bool = false,
        readingOrderDetection: Bool = false,
        multiPageAnalysis: Bool = false
    ) {
        self.determinismTier = determinismTier
        self.maxElementsPerPage = maxElementsPerPage
        self.mergeTextThreshold = mergeTextThreshold
        self.tableDetectionConfidence = tableDetectionConfidence
        
        var flags: UInt32 = 0
        if extractFontMetrics { flags |= 0x01 }
        if detectTables { flags |= 0x02 }
        if detectFigures { flags |= 0x04 }
        if extractImages { flags |= 0x08 }
        if enableProfiling { flags |= 0x10 }
        if preserveCaches { flags |= 0x20 }
        if enableOCR { flags |= 0x40 }
        if advancedFontAnalysis { flags |= 0x80 }
        if layoutClassification { flags |= 0x100 }
        if readingOrderDetection { flags |= 0x200 }
        if multiPageAnalysis { flags |= 0x400 }
        
        self.flags = flags
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
    
    // Advanced analysis timing
    public var ocrTimeMs: Double
    public var fontAnalysisTimeMs: Double
    public var layoutClassificationTimeMs: Double
    public var readingOrderTimeMs: Double
    
    internal init(from cStats: anigma_layout_engine_profiling_stats_t) {
        self.totalCharsProcessed = Int(cStats.total_chars_processed)
        self.totalSegmentsCreated = Int(cStats.total_segments_created)
        self.totalPagesProcessed = Int(cStats.total_pages_processed)
        self.pdfLoadTimeMs = cStats.pdf_load_time_ms
        self.textExtractionTimeMs = cStats.text_extraction_time_ms
        self.spatialIndexBuildTimeMs = cStats.spatial_index_build_time_ms
        self.totalAnalysisTimeMs = cStats.total_analysis_time_ms
        
        // Advanced analysis timing would be added to C struct
        self.ocrTimeMs = 0.0
        self.fontAnalysisTimeMs = 0.0
        self.layoutClassificationTimeMs = 0.0
        self.readingOrderTimeMs = 0.0
    }
}

// MARK: - Advanced Features Data Structures

/// OCR result containing extracted text with confidence and language detection.
public struct OCRResult: Sendable {
    public var bbox: BoundingBox
    public var text: String
    public var confidence: Double
    public var language: String
    public var wordCount: UInt32
    
    internal init(from cResult: anigma_ocr_result_t) {
        self.bbox = BoundingBox(from: cResult.bbox)
        self.text = cResult.text.map { String(cString: $0) } ?? ""
        self.confidence = cResult.confidence
        self.language = cResult.language.map { String(cString: $0) } ?? ""
        self.wordCount = cResult.word_count
    }
}

/// Advanced font analysis with family detection and style classification.
public struct FontAnalysis: Sendable {
    public var family: String
    public var subfamily: String
    public var size: Double
    public var weight: UInt32
    public var italic: Bool
    public var bold: Bool
    public var monospace: Bool
    public var serif: Bool
    public var styleFlags: UInt32
    public var xHeight: Double
    public var capHeight: Double
    public var colorRGB: UInt32
    public var contrastRatio: Double
    
    internal init(from cAnalysis: anigma_font_analysis_t) {
        self.family = cAnalysis.family.map { String(cString: $0) } ?? "Unknown"
        self.subfamily = cAnalysis.subfamily.map { String(cString: $0) } ?? ""
        self.size = cAnalysis.size
        self.weight = cAnalysis.weight
        self.italic = cAnalysis.italic != 0
        self.bold = cAnalysis.bold != 0
        self.monospace = cAnalysis.monospace != 0
        self.serif = cAnalysis.serif != 0
        self.styleFlags = cAnalysis.style_flags
        self.xHeight = cAnalysis.x_height
        self.capHeight = cAnalysis.cap_height
        self.colorRGB = cAnalysis.color_rgb
        self.contrastRatio = cAnalysis.contrast_ratio
    }
}

/// Layout element type classification.
public enum LayoutElementType: UInt32, Sendable, CaseIterable {
    case unknown = 0
    case header = 1
    case paragraph = 2
    case listItem = 3
    case tableCell = 4
    case caption = 5
    case footer = 6
    case sidebar = 7
    case quote = 8
    case codeBlock = 9
    
    public var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .header: return "Header"
        case .paragraph: return "Paragraph"
        case .listItem: return "List Item"
        case .tableCell: return "Table Cell"
        case .caption: return "Caption"
        case .footer: return "Footer"
        case .sidebar: return "Sidebar"
        case .quote: return "Quote"
        case .codeBlock: return "Code Block"
        }
    }
}

/// Classified layout element with semantic type and font analysis.
public struct LayoutElement: Sendable {
    public var bbox: BoundingBox
    public var type: LayoutElementType
    public var text: String
    public var confidence: Double
    public var readingOrder: UInt32
    public var font: FontAnalysis
    public var elementId: UInt32
    public var parentId: UInt32
    public var level: UInt32
    
    internal init(from cElement: anigma_layout_element_t) {
        self.bbox = BoundingBox(from: cElement.bbox)
        self.type = LayoutElementType(rawValue: cElement.type) ?? .unknown
        self.text = cElement.text.map { String(cString: $0) } ?? ""
        self.confidence = cElement.confidence
        self.readingOrder = cElement.reading_order
        self.font = FontAnalysis(from: cElement.font)
        self.elementId = cElement.element_id
        self.parentId = cElement.parent_id
        self.level = cElement.level
    }
}

/// Multi-page document structure analysis.
public struct DocumentStructure: Sendable {
    public var totalPages: UInt32
    public var sectionCount: UInt32
    public var sectionTitles: [String]
    public var sectionStartPages: [UInt32]
    public var elementCounts: [UInt32]
    public var hasTOC: Bool
    public var hasIndex: Bool
    public var hasBibliography: Bool
    
    internal init(from cStructure: anigma_document_structure_t) {
        self.totalPages = cStructure.total_pages
        self.sectionCount = cStructure.section_count
        
        var titles: [String] = []
        if let cTitles = cStructure.section_titles {
            for i in 0..<cStructure.section_count {
                if let title = cTitles[Int(i)] {
                    titles.append(String(cString: title))
                }
            }
        }
        self.sectionTitles = titles
        
        var startPages: [UInt32] = []
        if let cStartPages = cStructure.section_start_pages {
            for i in 0..<cStructure.section_count {
                startPages.append(cStartPages[Int(i)])
            }
        }
        self.sectionStartPages = startPages
        
        var counts: [UInt32] = []
        if let cCounts = cStructure.element_counts {
            for i in 0..<cStructure.section_count {
                counts.append(cCounts[Int(i)])
            }
        }
        self.elementCounts = counts
        
        self.hasTOC = cStructure.has_toc != 0
        self.hasIndex = cStructure.has_index != 0
        self.hasBibliography = cStructure.has_bibliography != 0
    }
}

/// Reading order information for layout elements.
public struct ReadingOrder: Sendable {
    public var elementIds: [UInt32]
    public var confidenceScores: [Double]
    public var columnBreaks: [UInt32]
    
    internal init(from cOrder: anigma_reading_order_t) {
        var ids: [UInt32] = []
        if let cIds = cOrder.element_ids {
            for i in 0..<cOrder.element_count {
                ids.append(cIds[Int(i)])
            }
        }
        self.elementIds = ids
        
        var scores: [Double] = []
        if let cScores = cOrder.confidence_scores {
            for i in 0..<cOrder.element_count {
                scores.append(cScores[Int(i)])
            }
        }
        self.confidenceScores = scores
        
        // Column breaks not implemented yet
        self.columnBreaks = []
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

