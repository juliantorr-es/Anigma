import Foundation
import CapsuleCore
import LayoutEngineCapsule
import TelemetryCore

public struct TableExtractionBoundingBox: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct TableExtractionCell: Codable, Hashable, Sendable {
    public var text: String
    public var row: Int
    public var column: Int
    public var bounding_box: TableExtractionBoundingBox

    public init(
        text: String,
        row: Int,
        column: Int,
        bounding_box: TableExtractionBoundingBox
    ) {
        self.text = text
        self.row = row
        self.column = column
        self.bounding_box = bounding_box
    }
}

public struct TableExtractionTable: Codable, Hashable, Sendable {
    public var bbox: TableExtractionBoundingBox
    public var numRows: Int
    public var numColumns: Int
    public var cells: [TableExtractionCell]

    public init(
        bbox: TableExtractionBoundingBox,
        numRows: Int,
        numColumns: Int,
        cells: [TableExtractionCell]
    ) {
        self.bbox = bbox
        self.numRows = numRows
        self.numColumns = numColumns
        self.cells = cells
    }
}

public struct TableExtractionResult: Codable, Hashable, Sendable {
    public var tables: [TableExtractionTable]
    public var processingTimeUs: UInt64

    public init(tables: [TableExtractionTable] = [], processingTimeUs: UInt64 = 0) {
        self.tables = tables
        self.processingTimeUs = processingTimeUs
    }
}

public struct TableExtractionConfig: Codable, Hashable, Sendable {
    public var minTableArea: Double = 1000.0
    public var maxAspectRatio: Double = 5.0
    public var enableCellMerging: Bool = true
    public var enableHeaderDetection: Bool = true
    public var enableFooterDetection: Bool = true

    public init() {}
}

public actor TableExtractionCapsule: IdentifiableCapsule {
    private let diagnostics: CapsuleDiagnostics
    private static let algorithmVersion = "table-extraction-stub-v1"

    public init(
        config: TableExtractionConfig = TableExtractionConfig(),
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        self.diagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        _ = config
    }

    public func extractTables(
        from segments: [TextSegment],
        pageIndex: Int,
        pageWidth: Double,
        pageHeight: Double
    ) throws -> TableExtractionResult {
        diagnostics.event(
            level: .debug,
            category: "tableextraction.stub.extract",
            message: "Table extraction stub returned no tables",
            correlationID: nil,
            metadata: [
                "segments": "\(segments.count)",
                "page_index": "\(pageIndex)",
                "page_width": "\(pageWidth)",
                "page_height": "\(pageHeight)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        return TableExtractionResult()
    }
}
