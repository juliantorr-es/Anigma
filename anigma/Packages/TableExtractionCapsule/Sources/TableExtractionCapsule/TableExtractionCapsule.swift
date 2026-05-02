// TableExtractionCapsule - Swift wrapper for table extraction
//
// This capsule provides high-performance table extraction from PDF documents
// using the "Swift governs, C++ computes" architecture pattern.

import Foundation
import CapsuleCore
import TelemetryCore
import LayoutEngineCapsule

/// Table cell representation
public struct TableCell: Codable, Hashable, Sendable {
    /// Cell text content
    public let text: String
    
    /// Bounding box (left, top, right, bottom)
    public let bbox: BoundingBox
    
    /// Column index
    public let colIndex: Int
    
    /// Row index
    public let rowIndex: Int
    
    /// Column span
    public let colSpan: Int
    
    /// Row span
    public let rowSpan: Int
    
    /// Cell type
    public let cellType: CellType
    
    /// Initialize a new table cell
    ///
    /// - Parameters:
    ///   - text: Cell text content
    ///   - bbox: Bounding box
    ///   - colIndex: Column index
    ///   - rowIndex: Row index
    ///   - colSpan: Column span
    ///   - rowSpan: Row span
    ///   - cellType: Cell type
    public init(
        text: String,
        bbox: BoundingBox,
        colIndex: Int,
        rowIndex: Int,
        colSpan: Int = 1,
        rowSpan: Int = 1,
        cellType: CellType = .data
    ) {
        self.text = text
        self.bbox = bbox
        self.colIndex = colIndex
        self.rowIndex = rowIndex
        self.colSpan = colSpan
        self.rowSpan = rowSpan
        self.cellType = cellType
    }
}

/// Table cell type
public enum CellType: String, Codable, Hashable, Sendable {
    /// Header cell
    case header
    /// Data cell
    case data
    /// Footer cell
    case footer
}

/// Table representation
public struct Table: Codable, Hashable, Sendable {
    /// Table cells
    public let cells: [TableCell]
    
    /// Number of columns
    public let colCount: Int
    
    /// Number of rows
    public let rowCount: Int
    
    /// Table bounding box
    public let bbox: BoundingBox
    
    /// Page index
    public let pageIndex: Int
    
    /// Table confidence score (0-1)
    public let confidence: Double
    
    /// Initialize a new table
    ///
    /// - Parameters:
    ///   - cells: Table cells
    ///   - colCount: Number of columns
    ///   - rowCount: Number of rows
    ///   - bbox: Table bounding box
    ///   - pageIndex: Page index
    ///   - confidence: Confidence score
    public init(
        cells: [TableCell],
        colCount: Int,
        rowCount: Int,
        bbox: BoundingBox,
        pageIndex: Int,
        confidence: Double = 1.0
    ) {
        self.cells = cells
        self.colCount = colCount
        self.rowCount = rowCount
        self.bbox = bbox
        self.pageIndex = pageIndex
        self.confidence = confidence
    }
}

/// Table extraction result
public struct TableExtractionResult: Codable, Hashable, Sendable {
    /// Extracted tables
    public let tables: [Table]
    
    /// Total processing time in microseconds
    public let processingTimeUs: UInt64
    
    /// Initialize a new table extraction result
    ///
    /// - Parameters:
    ///   - tables: Extracted tables
    ///   - processingTimeUs: Processing time in microseconds
    public init(
        tables: [Table],
        processingTimeUs: UInt64 = 0
    ) {
        self.tables = tables
        self.processingTimeUs = processingTimeUs
    }
}

/// Table extraction configuration
public struct TableExtractionConfig: Codable, Hashable, Sendable {
    /// Enable ML-based table detection (requires ONNX Runtime)
    public let enableMLDetection: Bool
    
    /// Minimum table area (in points²)
    public let minTableArea: Double
    
    /// Maximum table aspect ratio
    public let maxAspectRatio: Double
    
    /// Enable cell merging
    public let enableCellMerging: Bool
    
    /// Enable header detection
    public let enableHeaderDetection: Bool
    
    /// Enable footer detection
    public let enableFooterDetection: Bool
    
    /// ONNX model path (optional)
    public let onnxModelPath: String?
    
    /// Default configuration
    public static var `default`: TableExtractionConfig {
        TableExtractionConfig(
            enableMLDetection: false,
            minTableArea: 1000.0,
            maxAspectRatio: 5.0,
            enableCellMerging: true,
            enableHeaderDetection: true,
            enableFooterDetection: true,
            onnxModelPath: nil
        )
    }
    
    /// Initialize a new configuration
    ///
    /// - Parameters:
    ///   - enableMLDetection: Enable ML-based detection
    ///   - minTableArea: Minimum table area
    ///   - maxAspectRatio: Maximum aspect ratio
    ///   - enableCellMerging: Enable cell merging
    ///   - enableHeaderDetection: Enable header detection
    ///   - enableFooterDetection: Enable footer detection
    ///   - onnxModelPath: ONNX model path
    public init(
        enableMLDetection: Bool = false,
        minTableArea: Double = 1000.0,
        maxAspectRatio: Double = 5.0,
        enableCellMerging: Bool = true,
        enableHeaderDetection: Bool = true,
        enableFooterDetection: Bool = true,
        onnxModelPath: String? = nil
    ) {
        self.enableMLDetection = enableMLDetection
        self.minTableArea = minTableArea
        self.maxAspectRatio = maxAspectRatio
        self.enableCellMerging = enableCellMerging
        self.enableHeaderDetection = enableHeaderDetection
        self.enableFooterDetection = enableFooterDetection
        self.onnxModelPath = onnxModelPath
    }
}

/// Table extraction capsule
public actor TableExtractionCapsule: IdentifiableCapsule {
    private let handle: CapsuleHandle
    private let diagnostics: CapsuleDiagnostics
    private static let algorithmVersion = "table-extraction-v1"
    
    /// Initialize the table extraction capsule
    ///
    /// - Parameters:
    ///   - config: Table extraction configuration
    ///   - diagnostics: Optional diagnostics provider
    /// - Throws: If initialization fails
    public init(
        config: TableExtractionConfig = .default,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        let resolvedDiagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        let span = resolvedDiagnostics.beginSpan(
            name: "TableExtractionCapsule.init",
            category: "tableextraction.init",
            correlationID: nil,
            tags: [
                "algorithm_version": Self.algorithmVersion,
                "enable_ml_detection": "\(config.enableMLDetection)",
                "min_table_area": "\(config.minTableArea)"
            ]
        )
        
        do {
            var cConfig = anigma_table_extraction_config_t()
            cConfig.enable_ml_detection = config.enableMLDetection
            cConfig.min_table_area = config.minTableArea
            cConfig.max_aspect_ratio = config.maxAspectRatio
            cConfig.enable_cell_merging = config.enableCellMerging
            cConfig.enable_header_detection = config.enableHeaderDetection
            cConfig.enable_footer_detection = config.enableFooterDetection
            cConfig.onnx_model_path = config.onnxModelPath?.cString(using: .utf8)
            
            var cHandle = anigma_capsule_handle_t()
            let status = anigma_table_extraction_capsule_create(&cConfig, &cHandle)
            
            if status != ANIGMA_STATUS_OK {
                let error = CapsuleError.from(status: status)
                resolvedDiagnostics.event(
                    level: .error,
                    category: "tableextraction.init",
                    message: "Failed to initialize table extraction capsule: \(error)",
                    correlationID: nil,
                    tags: [:]
                )
                span.end(status: .error)
                throw error
            }
            
            self.handle = CapsuleHandle(rawValue: cHandle)
            self.diagnostics = resolvedDiagnostics
            span.end(status: .ok)
        } catch {
            resolvedDiagnostics.event(
                level: .error,
                category: "tableextraction.init",
                message: "Failed to initialize table extraction capsule: \(error)",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    deinit {
        anigma_table_extraction_capsule_destroy(handle.rawValue)
    }
    
    /// Extract tables from PDF page layout
    ///
    /// - Parameters:
    ///   - pageIndex: Page index
    ///   - segments: Text segments from layout engine
    ///   - pageWidth: Page width in points
    ///   - pageHeight: Page height in points
    /// - Returns: Table extraction result
    /// - Throws: If extraction fails
    public func extractFromSegments(
        pageIndex: Int,
        segments: [LayoutEngineCapsule.TextSegment],
        pageWidth: Double,
        pageHeight: Double
    ) throws -> TableExtractionResult {
        let span = diagnostics.beginSpan(
            name: "TableExtractionCapsule.extractFromSegments",
            category: "tableextraction.extract",
            correlationID: nil,
            tags: [
                "page_index": "\(pageIndex)",
                "segment_count": "\(segments.count)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        
        do {
            // Convert segments to C array
            let cSegments = segments.map { $0.toCLayoutSegment() }
            
            var cResult = anigma_table_extraction_result_t()
            let status = anigma_table_extraction_extract_from_segments(
                handle.rawValue,
                Int32(pageIndex),
                cSegments,
                cSegments.count,
                pageWidth,
                pageHeight,
                &cResult
            )
            
            if status != ANIGMA_STATUS_OK {
                let error = CapsuleError.from(status: status)
                span.end(status: .error)
                throw error
            }
            
            // Convert result to Swift
            let result = try convertResult(cResult)
            
            // Cleanup
            anigma_table_extraction_free_result(&cResult)
            
            span.end(status: .ok)
            return result
        } catch {
            span.end(status: .error)
            throw error
        }
    }
    
    /// Extract tables from PDF document
    ///
    /// - Parameters:
    ///   - pdfData: PDF document data
    /// - Returns: Table extraction result
    /// - Throws: If extraction fails
    public func extractFromPDF(pdfData: Data) throws -> TableExtractionResult {
        let span = diagnostics.beginSpan(
            name: "TableExtractionCapsule.extractFromPDF",
            category: "tableextraction.extract",
            correlationID: nil,
            tags: [
                "pdf_size": "\(pdfData.count)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        
        do {
            var cResult = anigma_table_extraction_result_t()
            let status = anigma_table_extraction_extract_from_pdf(
                handle.rawValue,
                pdfData.bytes.assumingMemoryBound(to: UInt8.self),
                pdfData.count,
                &cResult
            )
            
            if status != ANIGMA_STATUS_OK {
                let error = CapsuleError.from(status: status)
                span.end(status: .error)
                throw error
            }
            
            // Convert result to Swift
            let result = try convertResult(cResult)
            
            // Cleanup
            anigma_table_extraction_free_result(&cResult)
            
            span.end(status: .ok)
            return result
        } catch {
            span.end(status: .error)
            throw error
        }
    }
    
    /// Export table to JSON
    ///
    /// - Parameter table: Table to export
    /// - Returns: JSON string
    /// - Throws: If export fails
    public func exportToJSON(table: Table) throws -> String {
        var jsonPtr: UnsafePointer<CChar>? = nil
        var jsonLen: size_t = 0
        
        let status = anigma_table_export_to_json(
            table.toCTable(),
            &jsonPtr,
            &jsonLen
        )
        
        if status != ANIGMA_STATUS_OK {
            throw CapsuleError.from(status: status)
        }
        
        guard let jsonPtr = jsonPtr else {
            throw CapsuleError.internalError
        }
        
        let json = String(cString: jsonPtr, encoding: .utf8) ?? ""
        anigma_table_free_export(jsonPtr)
        
        return json
    }
    
    /// Export table to CSV
    ///
    /// - Parameter table: Table to export
    /// - Returns: CSV string
    /// - Throws: If export fails
    public func exportToCSV(table: Table) throws -> String {
        var csvPtr: UnsafePointer<CChar>? = nil
        var csvLen: size_t = 0
        
        let status = anigma_table_export_to_csv(
            table.toCTable(),
            &csvPtr,
            &csvLen
        )
        
        if status != ANIGMA_STATUS_OK {
            throw CapsuleError.from(status: status)
        }
        
        guard let csvPtr = csvPtr else {
            throw CapsuleError.internalError
        }
        
        let csv = String(cString: csvPtr, encoding: .utf8) ?? ""
        anigma_table_free_export(csvPtr)
        
        return csv
    }
    
    // MARK: - Private Methods
    
    private func convertResult(_ cResult: anigma_table_extraction_result_t) throws -> TableExtractionResult {
        // TODO: Implement conversion from C result to Swift result
        // This would convert the C table structures to Swift Table objects
        
        return TableExtractionResult(
            tables: [],
            processingTimeUs: cResult.processing_time_us
        )
    }
}

// MARK: - Extension for LayoutEngineCapsule.TextSegment

extension LayoutEngineCapsule.TextSegment {
    func toCLayoutSegment() -> anigma_layout_segment_t {
        // TODO: Implement conversion
        return anigma_layout_segment_t()
    }
}

// MARK: - Extension for Table

extension Table {
    func toCTable() -> anigma_table_t {
        // TODO: Implement conversion
        return anigma_table_t()
    }
}

// MARK: - Extension for BoundingBox

extension BoundingBox {
    var cBBox: (left: Double, top: Double, right: Double, bottom: Double) {
        return (left: left, top: top, right: right, bottom: bottom)
    }
}
