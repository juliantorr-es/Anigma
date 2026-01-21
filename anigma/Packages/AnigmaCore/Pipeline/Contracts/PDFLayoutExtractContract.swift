//
//  PDFLayoutExtractContract.swift
//  AnigmaCore
//
//  Contract definition for PDFLayoutExtractContract in AnigmaCore.
//

import ContractsCore
import Foundation
import LayoutEngineCapsule

/// Layout segment with text and styling information.
public struct PDFLayoutSegment: Codable, Sendable, Hashable {
    public let boundingBox: BoundingBoxRef
    public let text: String
    public let fontName: String?
    public let fontSize: Double
    public let fontFlags: UInt32
    public let colorRGB: UInt32
    
    public init(
        boundingBox: BoundingBoxRef,
        text: String,
        fontName: String?,
        fontSize: Double,
        fontFlags: UInt32,
        colorRGB: UInt32
    ) {
        self.boundingBox = boundingBox
        self.text = text
        self.fontName = fontName
        self.fontSize = fontSize
        self.fontFlags = fontFlags
        self.colorRGB = colorRGB
    }
    
    internal init(from segment: TextSegment) {
        self.boundingBox = BoundingBoxRef(
            x: segment.bbox.left,
            y: segment.bbox.top,
            width: segment.bbox.right - segment.bbox.left,
            height: segment.bbox.bottom - segment.bbox.top
        )
        self.text = segment.text
        self.fontName = segment.fontName
        self.fontSize = segment.fontSize
        self.fontFlags = segment.fontFlags
        self.colorRGB = segment.colorRGB
    }
}

/// Table region bounding box.
public struct PDFLayoutTable: Codable, Sendable, Hashable {
    public let boundingBox: BoundingBoxRef
    
    public init(boundingBox: BoundingBoxRef) {
        self.boundingBox = boundingBox
    }
    
    internal init(from bbox: BoundingBox) {
        self.boundingBox = BoundingBoxRef(
            x: bbox.left,
            y: bbox.top,
            width: bbox.right - bbox.left,
            height: bbox.bottom - bbox.top
        )
    }
}

/// Figure region bounding box.
public struct PDFLayoutFigure: Codable, Sendable, Hashable {
    public let boundingBox: BoundingBoxRef
    
    public init(boundingBox: BoundingBoxRef) {
        self.boundingBox = boundingBox
    }
    
    internal init(from bbox: BoundingBox) {
        self.boundingBox = BoundingBoxRef(
            x: bbox.left,
            y: bbox.top,
            width: bbox.right - bbox.left,
            height: bbox.bottom - bbox.top
        )
    }
}

/// Image data with metadata.
public struct PDFLayoutImage: Codable, Sendable, Hashable {
    public let boundingBox: BoundingBoxRef
    public let rawData: Data?
    public let width: UInt32
    public let height: UInt32
    public let horizontalDPI: Float
    public let verticalDPI: Float
    public let bitsPerPixel: UInt32
    public let colorspace: Int32
    public let filter: String?
    
    public init(
        boundingBox: BoundingBoxRef,
        rawData: Data?,
        width: UInt32,
        height: UInt32,
        horizontalDPI: Float,
        verticalDPI: Float,
        bitsPerPixel: UInt32,
        colorspace: Int32,
        filter: String?
    ) {
        self.boundingBox = boundingBox
        self.rawData = rawData
        self.width = width
        self.height = height
        self.horizontalDPI = horizontalDPI
        self.verticalDPI = verticalDPI
        self.bitsPerPixel = bitsPerPixel
        self.colorspace = colorspace
        self.filter = filter
    }
    
    internal init(from image: ImageData) {
        self.boundingBox = BoundingBoxRef(
            x: image.bbox.left,
            y: image.bbox.top,
            width: image.bbox.right - image.bbox.left,
            height: image.bbox.bottom - image.bbox.top
        )
        self.rawData = image.rawData
        self.width = image.width
        self.height = image.height
        self.horizontalDPI = image.horizontalDPI
        self.verticalDPI = image.verticalDPI
        self.bitsPerPixel = image.bitsPerPixel
        self.colorspace = image.colorspace
        self.filter = image.filter
    }
}

/// Page layout analysis result.
public struct PDFPageLayout: Codable, Sendable, Hashable {
    public let pageIndex: UInt32
    public let segments: [PDFLayoutSegment]
    public let tables: [PDFLayoutTable]
    public let figures: [PDFLayoutFigure]
    public let images: [PDFLayoutImage]
    
    public init(
        pageIndex: UInt32,
        segments: [PDFLayoutSegment],
        tables: [PDFLayoutTable],
        figures: [PDFLayoutFigure],
        images: [PDFLayoutImage]
    ) {
        self.pageIndex = pageIndex
        self.segments = segments
        self.tables = tables
        self.figures = figures
        self.images = images
    }
    
    internal init(from pageLayout: PageLayout) {
        self.pageIndex = pageLayout.pageIndex
        self.segments = pageLayout.segments.map(PDFLayoutSegment.init)
        self.tables = pageLayout.tableBBoxes.map(PDFLayoutTable.init)
        self.figures = pageLayout.figureBBoxes.map(PDFLayoutFigure.init)
        self.images = pageLayout.images.map(PDFLayoutImage.init)
    }
}

/// Layout extraction output containing pages.
public struct PDFLayoutOutput: Codable, Sendable {
    public let blobID: String
    public let pages: [PDFPageLayout]
    
    public init(blobID: String, pages: [PDFPageLayout]) {
        self.blobID = blobID
        self.pages = pages
    }
}

/// Deterministic layout extractor that uses LayoutEngineCapsule.
public enum PDFLayoutExtractContract: ContractSpec {
    public static let id = ContractID(name: "pipeline.pdf.layout_extract", major: 1, minor: 0, schemaHash: "v1.0")
    public static let inputSchemaVersion = 1
    public static let outputSchemaVersion = 1
    
    public static func validate(output: ArtifactEnvelope<PDFLayoutOutput>) throws {
        guard !output.payload.pages.isEmpty else {
            throw ContractValidationError.invalidSchema(
                code: "pdf.layout_extract.empty_pages",
                message: "Layout extractor produced no pages"
            )
        }
        
        for (idx, page) in output.payload.pages.enumerated() {
            if page.segments.isEmpty && page.tables.isEmpty && page.figures.isEmpty && page.images.isEmpty {
                throw ContractValidationError.invalidSchema(
                    code: "pdf.layout_extract.empty_page",
                    message: "Page \(idx) contains no segments, tables, figures, or images"
                )
            }
        }
    }
    
    public static func execute(
        input: ArtifactEnvelope<PDFBlobArtifact>,
        ctx: ContractContext
    ) async throws -> ArtifactEnvelope<PDFLayoutOutput> {
        let startTime = Date()
        let config = LayoutEngineConfig(determinismTier: 1)
        let pageLayouts: [PageLayout]
        do {
            pageLayouts = try LayoutEngineCapsuleWrapper.analyzePDF(input.payload.rawData, config: config)
        } catch {
            throw ContractExecutionError.underlying(
                code: "pdf.layout_extract.capsule_error",
                message: "Layout engine capsule failed: \(error.localizedDescription)"
            )
        }
        
        let pages = pageLayouts.map(PDFPageLayout.init)
        let output = PDFLayoutOutput(blobID: input.payload.blobID, pages: pages)
        
        // Generate evidence references for each segment, table, figure, and image
        var evidenceRefs: [EvidenceRef] = []
        for page in pages {
            let pageIndex = Int(page.pageIndex)
            for segment in page.segments {
                evidenceRefs.append(
                    EvidenceRef(
                        kind: .span,
                        contentHash: nil,
                        sourceArtifactID: input.payload.blobID,
                        page: pageIndex,
                        boundingBox: segment.boundingBox,
                        note: "layout-segment-\(segment.text.prefix(20))"
                    )
                )
            }
            for table in page.tables {
                evidenceRefs.append(
                    EvidenceRef(
                        kind: .span,
                        contentHash: nil,
                        sourceArtifactID: input.payload.blobID,
                        page: pageIndex,
                        boundingBox: table.boundingBox,
                        note: "layout-table"
                    )
                )
            }
            for figure in page.figures {
                evidenceRefs.append(
                    EvidenceRef(
                        kind: .span,
                        contentHash: nil,
                        sourceArtifactID: input.payload.blobID,
                        page: pageIndex,
                        boundingBox: figure.boundingBox,
                        note: "layout-figure"
                    )
                )
            }
            for image in page.images {
                evidenceRefs.append(
                    EvidenceRef(
                        kind: .blob,
                        contentHash: nil,
                        sourceArtifactID: input.payload.blobID,
                        page: pageIndex,
                        boundingBox: image.boundingBox,
                        note: "layout-image"
                    )
                )
            }
        }
        
        let endTime = Date()
        let wallTimeMs = Int64(endTime.timeIntervalSince(startTime) * 1000)
        let metrics = ExecutionMetrics(
            wallTimeMs: wallTimeMs,
            cpuTimeMs: nil,
            promptTokens: nil,
            completionTokens: nil,
            totalTokens: nil,
            toolCallCount: 0,
            retryCount: 0,
            executor: ctx.executorIdentity,
            cacheHit: false
        )
        
        let receipt = ContractReceipt.placeholder(
            contractID: Self.id,
            runID: ctx.runID,
            sessionID: ctx.sessionID,
            status: .satisfied,
            startedAt: startTime,
            endedAt: endTime,
            inputRefs: [],
            outputRefs: [],
            evidenceRefs: evidenceRefs,
            metrics: metrics
        )
        
        return ArtifactEnvelope(
            schemaVersion: outputSchemaVersion,
            payload: output,
            evidenceRefs: evidenceRefs,
            metrics: metrics,
            receipt: receipt
        )
    }
}