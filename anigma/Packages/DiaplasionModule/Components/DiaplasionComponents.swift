//
//  DiaplasionComponents.swift
//  DiaplasionModule
//
//  Components for Diaplasion alt-media transformation pipelines.
//

import AnigmaCore
import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Document Source

/// Represents the source document for transformation.
/// Format detection is performed by DocumentIngestSystem using magic bytes.
public struct DocumentSourceComponent: Component, Codable, Sendable {
    /// Original file path or URI
    public let sourceURI: String

    /// Detected or declared source format
    public var format: DocumentFormat

    /// Page count (for paginated documents)
    public var pageCount: Int?

    /// File size in bytes
    public var fileSize: Int64?

    /// Hash for deduplication/caching
    public var contentHash: String?

    public init(
        sourceURI: String,
        format: DocumentFormat = .unknown,
        pageCount: Int? = nil,
        fileSize: Int64? = nil,
        contentHash: String? = nil
    ) {
        self.sourceURI = sourceURI
        self.format = format
        self.pageCount = pageCount
        self.fileSize = fileSize
        self.contentHash = contentHash
    }
}

/// Supported document formats for Diaplasion processing.
public enum DocumentFormat: String, Codable, Sendable {
    case pdf
    case docx
    case epub
    case html
    case plainText = "txt"
    case rtf
    case jpeg
    case png
    case tiff
    case gif
    case bmp
    case heic
    case unknown

    /// Whether this format is a raster image type.
    public var isImage: Bool {
        switch self {
        case .jpeg, .png, .tiff, .gif, .bmp, .heic:
            return true
        default:
            return false
        }
    }

    /// Whether this format requires OCR to extract text.
    public var requiresOCR: Bool {
        switch self {
        case .pdf, .jpeg, .png, .tiff, .gif, .bmp, .heic:
            return true
        default:
            return false
        }
    }
}

// MARK: - Ingested Document

/// Holds the ingested document data ready for OCR processing.
/// This is an internal representation produced by DocumentIngestSystem.
/// Note: CGImage is not Codable, so we store serializable references.
public struct IngestedDocumentComponent: Component, Sendable {
    /// Per-page image data references (file paths to temp cache).
    /// Each entry is the path to a PNG file containing the page image.
    public var pageImagePaths: [String]

    /// Original dimensions per page (width, height in pixels).
    public var pageDimensions: [(width: Int, height: Int)]

    /// Text extracted directly from the source document when OCR is not required.
    public var textContent: String?

    /// Whether ingestion completed successfully.
    public var isComplete: Bool

    /// Any errors encountered during ingestion.
    public var errors: [String]

    public init(
        pageImagePaths: [String] = [],
        pageDimensions: [(width: Int, height: Int)] = [],
        textContent: String? = nil,
        isComplete: Bool = false,
        errors: [String] = []
    ) {
        self.pageImagePaths = pageImagePaths
        self.pageDimensions = pageDimensions
        self.textContent = textContent
        self.isComplete = isComplete
        self.errors = errors
    }
}

// MARK: - Document Assets

/// References assets embedded in the source document (e.g., images in DOCX).
public struct DocumentAssetComponent: Component, Codable, Sendable {
    /// Embedded or linked assets extracted during ingest.
    public var assets: [DocumentAsset]

    public init(assets: [DocumentAsset] = []) {
        self.assets = assets
    }
}

/// Represents a single extracted asset.
public struct DocumentAsset: Codable, Sendable, Identifiable {
    /// Unique asset identifier.
    public let id: UUID

    /// Original asset path inside the source container (e.g., word/media/image1.png).
    public var sourcePath: String

    /// Local filesystem path where the asset is stored.
    public var assetPath: String

    /// Asset media classification.
    public var mediaType: DocumentAssetType

    /// Role of the asset within the document.
    public var role: DocumentAssetRole

    /// SHA-256 hash of the asset contents, if available.
    public var contentHash: String?

    /// Additional metadata about the asset.
    public var metadata: [String: String]

    public init(
        id: UUID = UUID(),
        sourcePath: String,
        assetPath: String,
        mediaType: DocumentAssetType = .unknown,
        role: DocumentAssetRole = .embedded,
        contentHash: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.sourcePath = sourcePath
        self.assetPath = assetPath
        self.mediaType = mediaType
        self.role = role
        self.contentHash = contentHash
        self.metadata = metadata
    }
}

/// Classification for extracted assets.
public enum DocumentAssetType: String, Codable, Sendable {
    case image
    case attachment
    case unknown
}

/// Semantic role of an extracted asset.
public enum DocumentAssetRole: String, Codable, Sendable {
    case embedded
    case linked
    case attachment
}

// MARK: - Transform Request

/// Represents a request to transform a document into accessible formats.
public struct TransformRequestComponent: Component, Codable, Sendable {
    /// Unique request identifier
    public let requestId: String

    /// Target output formats
    public var targetFormats: Set<OutputFormat>

    /// Processing priority (higher = more urgent)
    public var priority: Int

    /// Requester information (for DSPS tracking)
    public var requesterId: String?

    /// Due date for the request
    public var dueDate: Date?

    /// Current processing status
    public var status: TransformStatus

    /// Timestamp when request was submitted
    public let submittedAt: Date

    /// Timestamp when processing completed
    public var completedAt: Date?

    public init(
        requestId: String = UUID().uuidString,
        targetFormats: Set<OutputFormat>,
        priority: Int = 0,
        requesterId: String? = nil,
        dueDate: Date? = nil,
        status: TransformStatus = .pending,
        submittedAt: Date = Date()
    ) {
        self.requestId = requestId
        self.targetFormats = targetFormats
        self.priority = priority
        self.requesterId = requesterId
        self.dueDate = dueDate
        self.status = status
        self.submittedAt = submittedAt
    }
}

/// Target output formats for accessibility.
public enum OutputFormat: String, Codable, Sendable, Hashable {
    case epub           // Reflowable EPUB
    case epubFixedLayout // Fixed-layout EPUB
    case brailleReady   // BRF or similar braille format
    case largePrint     // Large-print PDF
    case audioReady     // Text prepared for TTS
    case structuredHTML // Semantic HTML
    case plainText      // Clean plain text
    case taggedPDF      // Accessible tagged PDF
}

/// Processing status for transform requests.
public enum TransformStatus: String, Codable, Sendable {
    case pending
    case queued
    case processing
    case awaitingQA
    case completed
    case failed
    case cancelled
}

// MARK: - OCR Result

/// Stores OCR extraction results.
/// Produced by OCRExtractionSystem using Apple Vision framework.
public struct OCRResultComponent: Component, Codable, Sendable {
    /// Extracted text content
    public var text: String

    /// Overall confidence score (0.0–1.0)
    public var confidence: Double?

    /// Detected language
    public var language: String?

    /// Per-page results for paginated documents
    public var pageResults: [PageOCRResult]?

    /// OCR engine used
    public var engine: String?

    /// Processing time in seconds
    public var processingTime: TimeInterval?

    public init(
        text: String,
        confidence: Double? = nil,
        language: String? = nil,
        pageResults: [PageOCRResult]? = nil,
        engine: String? = nil,
        processingTime: TimeInterval? = nil
    ) {
        self.text = text
        self.confidence = confidence
        self.language = language
        self.pageResults = pageResults
        self.engine = engine
        self.processingTime = processingTime
    }
}

/// OCR result for a single page.
public struct PageOCRResult: Codable, Sendable {
    public let pageNumber: Int
    public let text: String
    public let confidence: Double?
    public let boundingBoxes: [TextBoundingBox]?

    public init(
        pageNumber: Int,
        text: String,
        confidence: Double? = nil,
        boundingBoxes: [TextBoundingBox]? = nil
    ) {
        self.pageNumber = pageNumber
        self.text = text
        self.confidence = confidence
        self.boundingBoxes = boundingBoxes
    }
}

/// Bounding box for text region (for correction UI).
public struct TextBoundingBox: Codable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public let text: String
    public let confidence: Double?

    public init(x: Double, y: Double, width: Double, height: Double, text: String, confidence: Double? = nil) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.text = text
        self.confidence = confidence
    }
}

// MARK: - Chunked Text

/// Stores semantically chunked text for downstream processing.
/// Produced by TextChunkingSystem with paragraph and heading detection.
public struct ChunkedTextComponent: Component, Codable, Sendable {
    /// Text chunks with semantic boundaries
    public var chunks: [TextChunk]

    /// Chunking strategy used
    public var strategy: ChunkingStrategy

    /// Total token count (if computed)
    public var totalTokens: Int?

    public init(
        chunks: [TextChunk],
        strategy: ChunkingStrategy = .paragraph,
        totalTokens: Int? = nil
    ) {
        self.chunks = chunks
        self.strategy = strategy
        self.totalTokens = totalTokens
    }
}

/// A semantic chunk of text.
public struct TextChunk: Codable, Sendable, Identifiable {
    public let id: String
    public let text: String
    public let chunkType: ChunkType
    public let pageNumber: Int?
    public let tokenCount: Int?

    public init(
        id: String = UUID().uuidString,
        text: String,
        chunkType: ChunkType = .paragraph,
        pageNumber: Int? = nil,
        tokenCount: Int? = nil
    ) {
        self.id = id
        self.text = text
        self.chunkType = chunkType
        self.pageNumber = pageNumber
        self.tokenCount = tokenCount
    }
}

/// Type of semantic chunk.
public enum ChunkType: String, Codable, Sendable {
    case heading
    case paragraph
    case listItem
    case table
    case figure
    case caption
    case footnote
    case quote
    case code
}

/// Strategy for chunking text.
public enum ChunkingStrategy: String, Codable, Sendable {
    case paragraph      // Split on paragraph boundaries
    case sentence       // Split on sentence boundaries
    case semantic       // Use semantic analysis
    case fixedToken     // Fixed token count
    case page           // Split by page
}

// MARK: - Accessible Output

/// References to generated accessible outputs.
public struct AccessibleOutputComponent: Component, Codable, Sendable {
    /// Generated output files by format
    public var outputs: [OutputFormat: OutputReference]

    /// Overall QA status
    public var qaStatus: QAStatus

    /// Validation results
    public var validationResults: [ValidationResult]?

    public init(
        outputs: [OutputFormat: OutputReference] = [:],
        qaStatus: QAStatus = .pending,
        validationResults: [ValidationResult]? = nil
    ) {
        self.outputs = outputs
        self.qaStatus = qaStatus
        self.validationResults = validationResults
    }
}

/// Reference to an output file.
public struct OutputReference: Codable, Sendable {
    public let format: OutputFormat
    public let uri: String
    public let fileSize: Int64?
    public let createdAt: Date
    public let checksum: String?
    /// Additional metadata about the output (pipelineVersion, requestId, etc.).
    public let metadata: [String: String]?

    public init(
        format: OutputFormat,
        uri: String,
        fileSize: Int64? = nil,
        createdAt: Date = Date(),
        checksum: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.format = format
        self.uri = uri
        self.fileSize = fileSize
        self.createdAt = createdAt
        self.checksum = checksum
        self.metadata = metadata
    }
}

/// QA status for outputs.
public enum QAStatus: String, Codable, Sendable {
    case pending
    case passed
    case failed
    case needsReview
}

/// Validation result entry.
public struct ValidationResult: Codable, Sendable {
    public let check: String
    public let passed: Bool
    public let message: String?

    public init(check: String, passed: Bool, message: String? = nil) {
        self.check = check
        self.passed = passed
        self.message = message
    }
}

// MARK: - Processing Errors

/// Processing stages for Diaplasion operations.
public enum DiaplasionProcessingStage: String, Codable, Sendable {
    case ingest
    case textExtraction
    case ocr
    case languageDetection
    case chunking
    case export
    case qa
}

/// Structured processing error with retry guidance.
public struct DiaplasionProcessingError: Codable, Sendable, Identifiable {
    /// Unique error identifier.
    public let id: UUID
    /// Processing stage where the error occurred.
    public let stage: DiaplasionProcessingStage
    /// Stable error code for programmatic handling.
    public let code: String
    /// Human-readable error message.
    public let message: String
    /// Whether the error is considered retryable.
    public let isRetryable: Bool
    /// Retry policy guidance for the failure.
    public let retryPolicy: RetryPolicy
    /// Timestamp for when the error was recorded.
    public let occurredAt: Date
    /// Contextual metadata for diagnostics.
    public var context: [String: String]

    public init(
        id: UUID = UUID(),
        stage: DiaplasionProcessingStage,
        code: String,
        message: String,
        isRetryable: Bool,
        retryPolicy: RetryPolicy,
        occurredAt: Date = Date(),
        context: [String: String] = [:]
    ) {
        self.id = id
        self.stage = stage
        self.code = code
        self.message = message
        self.isRetryable = isRetryable
        self.retryPolicy = retryPolicy
        self.occurredAt = occurredAt
        self.context = context
    }
}

/// Component that aggregates processing errors for a document entity.
public struct DiaplasionProcessingErrorComponent: Component, Codable, Sendable {
    /// Recorded processing errors in chronological order.
    public var errors: [DiaplasionProcessingError]

    public init(errors: [DiaplasionProcessingError] = []) {
        self.errors = errors
    }
}
