import Foundation
import CapsuleCore
import LayoutEngineCapsule
import TelemetryCore

public typealias LayoutSegment = TextSegment

public struct CitationBoundingBox: Codable, Hashable, Sendable {
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

public struct CitationReference: Codable, Hashable, Sendable {
    public var referenceID: String
    public var authors: String
    public var year: String?
    public var title: String
    public var venue: String?
    public var pages: String?
    public var doi: String?
    public var bbox: CitationBoundingBox
    public var confidence: Double

    public init(
        referenceID: String,
        authors: String,
        year: String? = nil,
        title: String,
        venue: String? = nil,
        pages: String? = nil,
        doi: String? = nil,
        bbox: CitationBoundingBox,
        confidence: Double = 1.0
    ) {
        self.referenceID = referenceID
        self.authors = authors
        self.year = year
        self.title = title
        self.venue = venue
        self.pages = pages
        self.doi = doi
        self.bbox = bbox
        self.confidence = confidence
    }
}

public struct InlineCitation: Codable, Hashable, Sendable {
    public var text: String
    public var referenceID: String?
    public var bbox: CitationBoundingBox
    public var confidence: Double

    public init(
        text: String,
        referenceID: String? = nil,
        bbox: CitationBoundingBox,
        confidence: Double = 1.0
    ) {
        self.text = text
        self.referenceID = referenceID
        self.bbox = bbox
        self.confidence = confidence
    }
}

public struct CitationExtractionResult: Codable, Hashable, Sendable {
    public var references: [CitationReference]
    public var inlineCitations: [InlineCitation]
    public var processingTime: UInt64

    public var processingTimeUs: UInt64 {
        processingTime
    }

    public init(
        references: [CitationReference],
        inlineCitations: [InlineCitation],
        processingTime: UInt64 = 0
    ) {
        self.references = references
        self.inlineCitations = inlineCitations
        self.processingTime = processingTime
    }

    public init(
        references: [CitationReference],
        inlineCitations: [InlineCitation],
        processingTimeUs: UInt64
    ) {
        self.init(
            references: references,
            inlineCitations: inlineCitations,
            processingTime: processingTimeUs
        )
    }
}

public struct CitationExtractionConfig: Codable, Hashable, Sendable {
    public var enableMLExtraction: Bool = false
    public var enableRegexExtraction: Bool = true
    public var enableReferenceSectionDetection: Bool = true
    public var enableInlineCitationDetection: Bool = true
    public var onnxModelPath: String? = nil
    public var regexPatternsPath: String? = nil

    public static var `default`: CitationExtractionConfig {
        CitationExtractionConfig()
    }

    public init() {}
}

public actor CitationExtractionCapsule: IdentifiableCapsule {
    private let diagnostics: CapsuleDiagnostics
    private static let algorithmVersion = "citation-extraction-stub-v1"

    public init(
        config: CitationExtractionConfig = .default,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        self.diagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        _ = config
    }

    public func extractCitations(
        from segments: [LayoutSegment],
        pageIndex: Int,
        pageWidth: Double,
        pageHeight: Double
    ) throws -> CitationExtractionResult {
        diagnostics.event(
            level: .debug,
            category: "citation.stub.extract",
            message: "Citation extraction stub returned no citations",
            correlationID: nil,
            metadata: [
                "segments": "\(segments.count)",
                "page_index": "\(pageIndex)",
                "page_width": "\(pageWidth)",
                "page_height": "\(pageHeight)",
                "algorithm_version": Self.algorithmVersion
            ]
        )

        return CitationExtractionResult(
            references: [],
            inlineCitations: [],
            processingTime: 0
        )
    }

    public func extractFromPDF(pdfData: Data) throws -> CitationExtractionResult {
        diagnostics.event(
            level: .debug,
            category: "citation.stub.extract_pdf",
            message: "Citation extraction PDF stub returned no citations",
            correlationID: nil,
            metadata: [
                "pdf_size": "\(pdfData.count)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        return CitationExtractionResult(references: [], inlineCitations: [], processingTime: 0)
    }

    public func exportToBibTeX(reference: CitationReference) throws -> String {
        "@misc{\(reference.referenceID), title={\(reference.title)}}"
    }

    public func exportToJSON(reference: CitationReference) throws -> String {
        let data = try JSONEncoder().encode(reference)
        return String(decoding: data, as: UTF8.self)
    }

    public func exportToJSON(citation: InlineCitation) throws -> String {
        let data = try JSONEncoder().encode(citation)
        return String(decoding: data, as: UTF8.self)
    }
}
