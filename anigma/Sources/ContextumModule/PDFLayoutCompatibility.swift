import Foundation
import ContractsCore

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
}

public struct PDFLayoutTable: Codable, Sendable, Hashable {
    public let boundingBox: BoundingBoxRef

    public init(boundingBox: BoundingBoxRef) {
        self.boundingBox = boundingBox
    }
}

public struct PDFLayoutFigure: Codable, Sendable, Hashable {
    public let boundingBox: BoundingBoxRef

    public init(boundingBox: BoundingBoxRef) {
        self.boundingBox = boundingBox
    }
}

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
}

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
}

public struct PDFLayoutOutput: Codable, Sendable {
    public let blobID: String
    public let pages: [PDFPageLayout]

    public init(blobID: String, pages: [PDFPageLayout]) {
        self.blobID = blobID
        self.pages = pages
    }
}
