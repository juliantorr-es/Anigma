// CitationExtractionCapsule - Swift wrapper for citation extraction
//
// This capsule provides high-performance citation extraction from PDF documents
// using the "Swift governs, C++ computes" architecture pattern.

import Foundation
import CapsuleCore
import TelemetryCore
import LayoutEngineCapsule

/// Citation bounding box representation
public struct CitationBoundingBox: Codable, Hashable, Sendable {
    /// Left coordinate
    public let left: Double
    
    /// Top coordinate
    public let top: Double
    
    /// Right coordinate
    public let right: Double
    
    /// Bottom coordinate
    public let bottom: Double
    
    /// Initialize a new bounding box
    ///
    /// - Parameters:
    ///   - left: Left coordinate
    ///   - top: Top coordinate
    ///   - right: Right coordinate
    ///   - bottom: Bottom coordinate
    public init(left: Double, top: Double, right: Double, bottom: Double) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }
}

/// Citation reference representation
public struct CitationReference: Codable, Hashable, Sendable {
    /// Reference ID
    public let referenceID: String
    
    /// Author names
    public let authors: String
    
    /// Publication year
    public let year: String?
    
    /// Title
    public let title: String
    
    /// Journal/conference name
    public let venue: String?
    
    /// Pages
    public let pages: String?
    
    /// DOI
    public let doi: String?
    
    /// Bounding box
    public let bbox: CitationBoundingBox
    
    /// Confidence score (0-1)
    public let confidence: Double
    
    /// Initialize a new citation reference
    ///
    /// - Parameters:
    ///   - referenceID: Reference ID
    ///   - authors: Author names
    ///   - year: Publication year
    ///   - title: Title
    ///   - venue: Journal/conference name
    ///   - pages: Pages
    ///   - doi: DOI
    ///   - bbox: Bounding box
    ///   - confidence: Confidence score
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

/// Inline citation representation
public struct InlineCitation: Codable, Hashable, Sendable {
    /// Citation text
    public let text: String
    
    /// Reference ID
    public let referenceID: String?
    
    /// Bounding box
    public let bbox: CitationBoundingBox
    
    /// Confidence score (0-1)
    public let confidence: Double
    
    /// Initialize a new inline citation
    ///
    /// - Parameters:
    ///   - text: Citation text
    ///   - referenceID: Reference ID
    ///   - bbox: Bounding box
    ///   - confidence: Confidence score
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

/// Citation extraction result
public struct CitationExtractionResult: Codable, Hashable, Sendable {
    /// Extracted references
    public let references: [CitationReference]
    
    /// Inline citations
    public let inlineCitations: [InlineCitation]
    
    /// Total processing time in microseconds
    public let processingTimeUs: UInt64
    
    /// Initialize a new citation extraction result
    ///
    /// - Parameters:
    ///   - references: Extracted references
    ///   - inlineCitations: Inline citations
    ///   - processingTimeUs: Processing time in microseconds
    public init(
        references: [CitationReference],
        inlineCitations: [InlineCitation],
        processingTimeUs: UInt64 = 0
    ) {
        self.references = references
        self.inlineCitations = inlineCitations
        self.processingTimeUs = processingTimeUs
    }
}

/// Citation extraction configuration
public struct CitationExtractionConfig: Codable, Hashable, Sendable {
    /// Enable ML-based extraction (requires ONNX Runtime)
    public let enableMLExtraction: Bool
    
    /// Enable regex-based extraction
    public let enableRegexExtraction: Bool
    
    /// Enable reference section detection
    public let enableReferenceSectionDetection: Bool
    
    /// Enable inline citation detection
    public let enableInlineCitationDetection: Bool
    
    /// ONNX model path (optional)
    public let onnxModelPath: String?
    
    /// Custom regex patterns path (optional)
    public let regexPatternsPath: String?
    
    /// Default configuration
    public static var `default`: CitationExtractionConfig {
        CitationExtractionConfig(
            enableMLExtraction: false,
            enableRegexExtraction: true,
            enableReferenceSectionDetection: true,
            enableInlineCitationDetection: true,
            onnxModelPath: nil,
            regexPatternsPath: nil
        )
    }
    
    /// Initialize a new configuration
    ///
    /// - Parameters:
    ///   - enableMLExtraction: Enable ML-based extraction
    ///   - enableRegexExtraction: Enable regex-based extraction
    ///   - enableReferenceSectionDetection: Enable reference section detection
    ///   - enableInlineCitationDetection: Enable inline citation detection
    ///   - onnxModelPath: ONNX model path
    ///   - regexPatternsPath: Custom regex patterns path
    public init(
        enableMLExtraction: Bool = false,
        enableRegexExtraction: Bool = true,
        enableReferenceSectionDetection: Bool = true,
        enableInlineCitationDetection: Bool = true,
        onnxModelPath: String? = nil,
        regexPatternsPath: String? = nil
    ) {
        self.enableMLExtraction = enableMLExtraction
        self.enableRegexExtraction = enableRegexExtraction
        self.enableReferenceSectionDetection = enableReferenceSectionDetection
        self.enableInlineCitationDetection = enableInlineCitationDetection
        self.onnxModelPath = onnxModelPath
        self.regexPatternsPath = regexPatternsPath
    }
}

/// Citation extraction capsule
public actor CitationExtractionCapsule: IdentifiableCapsule {
    private let handle: CapsuleHandle<AnyObject>
    private let diagnostics: CapsuleDiagnostics
    private static let algorithmVersion = "citation-extraction-v1"
    
    /// Initialize the citation extraction capsule
    ///
    /// - Parameters:
    ///   - config: Citation extraction configuration
    ///   - diagnostics: Optional diagnostics provider
    /// - Throws: If initialization fails
    public init(
        config: CitationExtractionConfig = .default,
        diagnostics: CapsuleDiagnostics? = nil
    ) throws {
        let resolvedDiagnostics = diagnostics ?? DefaultCapsuleDiagnostics()
        let span = resolvedDiagnostics.beginSpan(
            name: "CitationExtractionCapsule.init",
            category: "citationextraction.init",
            correlationID: nil,
            tags: [
                "algorithm_version": Self.algorithmVersion,
                "enable_ml_extraction": "\(config.enableMLExtraction)",
                "enable_regex_extraction": "\(config.enableRegexExtraction)"
            ]
        )
        
        do {
            var cConfig = anigma_citation_extraction_config_t()
            cConfig.enable_ml_extraction = config.enableMLExtraction
            cConfig.enable_regex_extraction = config.enableRegexExtraction
            cConfig.enable_reference_section_detection = config.enableReferenceSectionDetection
            cConfig.enable_inline_citation_detection = config.enableInlineCitationDetection
            cConfig.onnx_model_path = config.onnxModelPath?.cString(using: .utf8)
            cConfig.regex_patterns_path = config.regexPatternsPath?.cString(using: .utf8)
            
            var cHandle = anigma_capsule_handle_t()
            let status = anigma_citation_extraction_capsule_create(&cConfig, &cHandle)
            
            if status != ANIGMA_STATUS_OK {
                let error = CapsuleError.nativeError(code: Int32(status), libraryName: "CitationExtraction")
                resolvedDiagnostics.event(
                    level: .error,
                    category: "citationextraction.init",
                    message: "Failed to initialize citation extraction capsule: \(error)",
                    correlationID: nil,
                    tags: [:]
                )
                span.end(status: .error)
                throw error
            }
            
            self.handle = CapsuleHandle<AnyObject>(rawValue: cHandle)
            self.diagnostics = resolvedDiagnostics
            span.end(status: .ok)
        } catch {
            resolvedDiagnostics.event(
                level: .error,
                category: "citationextraction.init",
                message: "Failed to initialize citation extraction capsule: \(error)",
                correlationID: nil,
                tags: [:]
            )
            span.end(status: .error)
            throw error
        }
    }
    
    deinit {
        anigma_citation_extraction_capsule_destroy(handle.rawValue)
    }
    
    /// Extract citations from PDF page layout
    ///
    /// - Parameters:
    ///   - pageIndex: Page index
    ///   - segments: Text segments from layout engine
    ///   - pageWidth: Page width in points
    ///   - pageHeight: Page height in points
    /// - Returns: Citation extraction result
    /// - Throws: If extraction fails
    public func extractFromSegments(
        pageIndex: Int,
        segments: [LayoutEngineCapsule.TextSegment],
        pageWidth: Double,
        pageHeight: Double
    ) throws -> CitationExtractionResult {
        let span = diagnostics.beginSpan(
            name: "CitationExtractionCapsule.extractFromSegments",
            category: "citationextraction.extract",
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
            
            var cResult = anigma_citation_extraction_result_t()
            let status = anigma_citation_extraction_extract_from_segments(
                handle.rawValue,
                Int32(pageIndex),
                cSegments,
                cSegments.count,
                pageWidth,
                pageHeight,
                &cResult
            )
            
            if status != ANIGMA_STATUS_OK {
                let error = CapsuleError.nativeError(code: Int32(status), libraryName: "CitationExtraction")
                span.end(status: .error)
                throw error
            }
            
            // Convert result to Swift
            let result = try convertResult(cResult)
            
            // Cleanup
            anigma_citation_extraction_free_result(&cResult)
            
            span.end(status: .ok)
            return result
        } catch {
            span.end(status: .error)
            throw error
        }
    }
    
    /// Extract citations from PDF document
    ///
    /// - Parameters:
    ///   - pdfData: PDF document data
    /// - Returns: Citation extraction result
    /// - Throws: If extraction fails
    public func extractFromPDF(pdfData: Data) throws -> CitationExtractionResult {
        let span = diagnostics.beginSpan(
            name: "CitationExtractionCapsule.extractFromPDF",
            category: "citationextraction.extract",
            correlationID: nil,
            tags: [
                "pdf_size": "\(pdfData.count)",
                "algorithm_version": Self.algorithmVersion
            ]
        )
        
        do {
            var cResult = anigma_citation_extraction_result_t()
            let status = pdfData.withUnsafeBytes { pdfBytes -> anigma_status_t in
                let pointer = pdfBytes.bindMemory(to: UInt8.self).baseAddress
                return anigma_citation_extraction_extract_from_pdf(
                    handle.rawValue,
                    pointer,
                    pdfData.count,
                    &cResult
                )
            }
            
            if status != ANIGMA_STATUS_OK {
                let error = CapsuleError.nativeError(code: Int32(status), libraryName: "CitationExtraction")
                span.end(status: .error)
                throw error
            }
            
            // Convert result to Swift
            let result = try convertResult(cResult)
            
            // Cleanup
            anigma_citation_extraction_free_result(&cResult)
            
            span.end(status: .ok)
            return result
        } catch {
            span.end(status: .error)
            throw error
        }
    }
    
    /// Export reference to BibTeX
    ///
    /// - Parameter reference: Reference to export
    /// - Returns: BibTeX string
    /// - Throws: If export fails
    public func exportToBibTeX(reference: CitationReference) throws -> String {
        var bibtexPtr: UnsafePointer<CChar>? = nil
        var bibtexLen: size_t = 0
        
        let status = anigma_reference_export_to_bibtex(
            reference.toCCitationReference(),
            &bibtexPtr,
            &bibtexLen
        )
        
        if status != ANIGMA_STATUS_OK {
            throw CapsuleError.nativeError(code: Int32(status), libraryName: "CitationExtraction")
        }
        
        guard let bibtexPtr = bibtexPtr else {
            throw CapsuleError.internalError
        }
        
        let bibtex = String(cString: bibtexPtr, encoding: .utf8) ?? ""
        anigma_citation_free_export(bibtexPtr)
        
        return bibtex
    }
    
    /// Export reference to JSON
    ///
    /// - Parameter reference: Reference to export
    /// - Returns: JSON string
    /// - Throws: If export fails
    public func exportToJSON(reference: CitationReference) throws -> String {
        var jsonPtr: UnsafePointer<CChar>? = nil
        var jsonLen: size_t = 0
        
        let status = anigma_reference_export_to_json(
            reference.toCCitationReference(),
            &jsonPtr,
            &jsonLen
        )
        
        if status != ANIGMA_STATUS_OK {
            throw CapsuleError.nativeError(code: Int32(status), libraryName: "CitationExtraction")
        }
        
        guard let jsonPtr = jsonPtr else {
            throw CapsuleError.internalError
        }
        
        let json = String(cString: jsonPtr, encoding: .utf8) ?? ""
        anigma_citation_free_export(jsonPtr)
        
        return json
    }
    
    /// Export inline citation to JSON
    ///
    /// - Parameter citation: Inline citation to export
    /// - Returns: JSON string
    /// - Throws: If export fails
    public func exportToJSON(citation: InlineCitation) throws -> String {
        var jsonPtr: UnsafePointer<CChar>? = nil
        var jsonLen: size_t = 0
        
        let status = anigma_inline_citation_export_to_json(
            citation.toCInlineCitation(),
            &jsonPtr,
            &jsonLen
        )
        
        if status != ANIGMA_STATUS_OK {
            throw CapsuleError.nativeError(code: Int32(status), libraryName: "CitationExtraction")
        }
        
        guard let jsonPtr = jsonPtr else {
            throw CapsuleError.internalError
        }
        
        let json = String(cString: jsonPtr, encoding: .utf8) ?? ""
        anigma_citation_free_export(jsonPtr)
        
        return json
    }
    
    // MARK: - Private Methods
    
    private func convertResult(_ cResult: anigma_citation_extraction_result_t) throws -> CitationExtractionResult {
        // TODO: Implement conversion from C result to Swift result
        // This would convert the C citation structures to Swift objects
        
        return CitationExtractionResult(
            references: [],
            inlineCitations: [],
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

// MARK: - Extension for CitationReference

extension CitationReference {
    func toCCitationReference() -> anigma_citation_reference_t {
        // TODO: Implement conversion
        return anigma_citation_reference_t()
    }
}

// MARK: - Extension for InlineCitation

extension InlineCitation {
    func toCInlineCitation() -> anigma_inline_citation_t {
        // TODO: Implement conversion
        return anigma_inline_citation_t()
    }
}

// MARK: - Extension for CitationBoundingBox

extension CitationBoundingBox {
    var cBBox: anigma_citation_bbox_t {
        return anigma_citation_bbox_t(
            left: left,
            top: top,
            right: right,
            bottom: bottom
        )
    }
}
