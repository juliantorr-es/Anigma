//
//  LayoutEngineContracts.swift
//  LayoutEngineContracts
//
//  Portable contract/value types for layout engine operations.
//  This module contains ONLY pure contract types with no native/implementation dependencies.
//  Tier: 1 (Contract/Constitutional Layer)

import EvidenceContracts
import FoundationContracts
import AnigmaPrimitives
import Foundation

/// Layout segment with text and styling information.
/// This is the contract-safe representation of a text segment from PDF layout analysis.
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

/// Table region bounding box from layout analysis.
public struct PDFLayoutTable: Codable, Sendable, Hashable {
    public let boundingBox: BoundingBoxRef
    
    public init(boundingBox: BoundingBoxRef) {
        self.boundingBox = boundingBox
    }
}

/// Figure region bounding box from layout analysis.
public struct PDFLayoutFigure: Codable, Sendable, Hashable {
    public let boundingBox: BoundingBoxRef
    
    public init(boundingBox: BoundingBoxRef) {
        self.boundingBox = boundingBox
    }
}

/// Image data with metadata from layout analysis.
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

/// Page layout analysis result.
/// Contains all layout elements extracted from a single PDF page.
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

/// Layout extraction output containing all pages.
public struct PDFLayoutOutput: Codable, Sendable {
    public let blobID: String
    public let pages: [PDFPageLayout]
    
    public init(blobID: String, pages: [PDFPageLayout]) {
        self.blobID = blobID
        self.pages = pages
    }
}

/// Represents a raw PDF blob artifact.
/// This is the input type for PDF layout extraction and other PDF processing contracts.
/// Moved from AnigmaPipeline/SharedPDFTypes.swift to LayoutEngineContracts to break dependency cycle.
public struct PDFBlobArtifact: Codable, Sendable {
    public let blobID: String // A unique identifier for the raw PDF blob
    public let pageCount: Int // Number of pages in the PDF
    public let rawData: Data // Raw PDF bytes ingested by the pipeline
    
    public init(blobID: String, pageCount: Int, rawData: Data) {
        self.blobID = blobID
        self.pageCount = pageCount
        self.rawData = rawData
    }
}
