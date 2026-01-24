//
//  DiaplasionStateContracts.swift
//  ContractsCore
//
//  Canonical state schemas for Diaplasion domain.
//  This provides structured state representation for document processing workflows.
//

import Foundation

// MARK: - Diaplasion State Types

/// Canonical state for Diaplasion document processing
public struct DiaplasionState: Sendable, Codable {
    public let projectId: String
    public let documents: [DocumentEntity]
    public let processing: [ProcessingEntity]
    public let exports: [ExportEntity]
    public let metadata: DiaplasionMetadata

    public init(
        projectId: String,
        documents: [DocumentEntity] = [],
        processing: [ProcessingEntity] = [],
        exports: [ExportEntity] = [],
        metadata: DiaplasionMetadata = DiaplasionMetadata()
    ) {
        self.projectId = projectId
        self.documents = documents
        self.processing = processing
        self.exports = exports
        self.metadata = metadata
    }
}

/// Document entity in Diaplasion state
public struct DocumentEntity: Sendable, Codable {
    public let id: String
    public let type: DocumentType
    public let source: DocumentSource
    public let content: DocumentContent
    public let structure: DocumentStructure
    public let accessibility: AccessibilityInfo
    public let metadata: DocumentMetadata

    public init(
        id: String,
        type: DocumentType,
        source: DocumentSource,
        content: DocumentContent,
        structure: DocumentStructure,
        accessibility: AccessibilityInfo = AccessibilityInfo(),
        metadata: DocumentMetadata = DocumentMetadata()
    ) {
        self.id = id
        self.type = type
        self.source = source
        self.content = content
        self.structure = structure
        self.accessibility = accessibility
        self.metadata = metadata
    }
}

/// Processing entity in Diaplasion state
public struct ProcessingEntity: Sendable, Codable {
    public let id: String
    public let documentId: String
    public let stage: ProcessingStage
    public let operation: ProcessingOperation
    public let status: ProcessingStatus
    public let progress: ProcessingProgress
    public let artifacts: [ProcessingArtifact]
    public let errors: [ProcessingError]
    public let metadata: ProcessingMetadata

    public init(
        id: String,
        documentId: String,
        stage: ProcessingStage,
        operation: ProcessingOperation,
        status: ProcessingStatus,
        progress: ProcessingProgress = ProcessingProgress(),
        artifacts: [ProcessingArtifact] = [],
        errors: [ProcessingError] = [],
        metadata: ProcessingMetadata = ProcessingMetadata()
    ) {
        self.id = id
        self.documentId = documentId
        self.stage = stage
        self.operation = operation
        self.status = status
        self.progress = progress
        self.artifacts = artifacts
        self.errors = errors
        self.metadata = metadata
    }
}

/// Export entity in Diaplasion state
public struct ExportEntity: Sendable, Codable {
    public let id: String
    public let documentId: String
    public let format: ExportFormat
    public let destination: ExportDestination
    public let settings: ExportSettings
    public let status: ExportStatus
    public let result: ExportResult?
    public let metadata: ExportMetadata

    public init(
        id: String,
        documentId: String,
        format: ExportFormat,
        destination: ExportDestination,
        settings: ExportSettings = ExportSettings(),
        status: ExportStatus = .pending,
        result: ExportResult? = nil,
        metadata: ExportMetadata = ExportMetadata()
    ) {
        self.id = id
        self.documentId = documentId
        self.format = format
        self.destination = destination
        self.settings = settings
        self.status = status
        self.result = result
        self.metadata = metadata
    }
}

// MARK: - Document Types

/// Type of document
public enum DocumentType: String, Sendable, Codable, CaseIterable {
    case pdf = "pdf"
    case image = "image"
    case text = "text"
    case audio = "audio"
    case video = "video"
    case braille = "braille"
    case structured = "structured"

    public var description: String {
        switch self {
        case .pdf: return "PDF document"
        case .image: return "Image file"
        case .text: return "Plain text document"
        case .audio: return "Audio file"
        case .video: return "Video file"
        case .braille: return "Braille document"
        case .structured: return "Structured document (JSON, XML, etc.)"
        }
    }

    public var supportedFormats: [String] {
        switch self {
        case .pdf: return ["pdf"]
        case .image: return ["jpg", "jpeg", "png", "gif", "bmp", "tiff"]
        case .text: return ["txt", "md", "rtf"]
        case .audio: return ["mp3", "wav", "flac", "aac", "ogg"]
        case .video: return ["mp4", "avi", "mov", "mkv", "webm"]
        case .braille: return ["brf", "brl", "pef"]
        case .structured: return ["json", "xml", "yaml", "csv"]
        }
    }
}

/// Source of document
public struct DocumentSource: Sendable, Codable {
    public let type: SourceType
    public let location: String
    public let timestamp: Date
    public let checksum: String
    public let size: Int64
    public let metadata: [String: String]

    public init(
        type: SourceType,
        location: String,
        timestamp: Date = Date(),
        checksum: String = "",
        size: Int64 = 0,
        metadata: [String: String] = [:]
    ) {
        self.type = type
        self.location = location
        self.timestamp = timestamp
        self.checksum = checksum
        self.size = size
        self.metadata = metadata
    }
}

/// Type of document source
public enum SourceType: String, Sendable, Codable {
    case file = "file"
    case url = "url"
    case upload = "upload"
    case generated = "generated"
    case `import` = "imported"

    public var description: String {
        switch self {
        case .file: return "Local file system"
        case .url: return "Remote URL"
        case .upload: return "User upload"
        case .generated: return "Generated by processing"
        case .import: return "Imported from external system"
        }
    }
}

/// Content of document
public struct DocumentContent: Sendable, Codable {
    public let format: ContentFormat
    public let text: String?
    public let binary: Data?
    public let encoding: String?
    public let language: String?
    public let extracted: ExtractedContent

    public init(
        format: ContentFormat,
        text: String? = nil,
        binary: Data? = nil,
        encoding: String? = nil,
        language: String? = nil,
        extracted: ExtractedContent = ExtractedContent()
    ) {
        self.format = format
        self.text = text
        self.binary = binary
        self.encoding = encoding
        self.language = language
        self.extracted = extracted
    }
}

/// Format of content
public enum ContentFormat: String, Sendable, Codable {
    case plainText = "plain_text"
    case richText = "rich_text"
    case markdown = "markdown"
    case html = "html"
    case pdf = "pdf"
    case image = "image"
    case audio = "audio"
    case video = "video"
    case structured = "structured"

    public var description: String {
        switch self {
        case .plainText: return "Plain text"
        case .richText: return "Rich text"
        case .markdown: return "Markdown"
        case .html: return "HTML"
        case .pdf: return "PDF"
        case .image: return "Image"
        case .audio: return "Audio"
        case .video: return "Video"
        case .structured: return "Structured data"
        }
    }
}

/// Extracted content from document
public struct ExtractedContent: Sendable, Codable {
    public let text: String?
    public let images: [ExtractedImage]
    public let tables: [ExtractedTable]
    public let metadata: [String: String]

    public init(
        text: String? = nil,
        images: [ExtractedImage] = [],
        tables: [ExtractedTable] = [],
        metadata: [String: String] = [:]
    ) {
        self.text = text
        self.images = images
        self.tables = tables
        self.metadata = metadata
    }
}

/// Extracted image from document
public struct ExtractedImage: Sendable, Codable {
    public let id: String
    public let location: String
    public let format: String
    public let size: ImageSize
    public let altText: String?
    public let metadata: [String: String]

    public init(
        id: String,
        location: String,
        format: String,
        size: ImageSize,
        altText: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.location = location
        self.format = format
        self.size = size
        self.altText = altText
        self.metadata = metadata
    }
}

/// Size of image
public struct ImageSize: Sendable, Codable {
    public let width: Int
    public let height: Int
    public let unit: String

    public init(width: Int, height: Int, unit: String = "px") {
        self.width = width
        self.height = height
        self.unit = unit
    }
}

/// Extracted table from document
public struct ExtractedTable: Sendable, Codable {
    public let id: String
    public let rows: [[String]]
    public let headers: [String]?
    public let caption: String?
    public let metadata: [String: String]

    public init(
        id: String,
        rows: [[String]],
        headers: [String]? = nil,
        caption: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.rows = rows
        self.headers = headers
        self.caption = caption
        self.metadata = metadata
    }
}

/// Structure of document
public struct DocumentStructure: Sendable, Codable {
    public let sections: [DocumentSection]
    public let hierarchy: DocumentHierarchy
    public let navigation: NavigationStructure
    public let metadata: StructureMetadata

    public init(
        sections: [DocumentSection] = [],
        hierarchy: DocumentHierarchy = DocumentHierarchy(),
        navigation: NavigationStructure = NavigationStructure(),
        metadata: StructureMetadata = StructureMetadata()
    ) {
        self.sections = sections
        self.hierarchy = hierarchy
        self.navigation = navigation
        self.metadata = metadata
    }
}

/// Section in document
public struct DocumentSection: Sendable, Codable {
    public let id: String
    public let title: String
    public let level: Int
    public let start: ContentPosition
    public let end: ContentPosition
    public let content: String?
    public let children: [String]  // Section IDs
    public let metadata: [String: String]

    public init(
        id: String,
        title: String,
        level: Int,
        start: ContentPosition,
        end: ContentPosition,
        content: String? = nil,
        children: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.level = level
        self.start = start
        self.end = end
        self.content = content
        self.children = children
        self.metadata = metadata
    }
}

/// Position in content
public struct ContentPosition: Sendable, Codable {
    public let page: Int?
    public let offset: Int?
    public let line: Int?
    public let column: Int?
    public let marker: String?

    public init(
        page: Int? = nil,
        offset: Int? = nil,
        line: Int? = nil,
        column: Int? = nil,
        marker: String? = nil
    ) {
        self.page = page
        self.offset = offset
        self.line = line
        self.column = column
        self.marker = marker
    }
}

/// Hierarchy of document
public struct DocumentHierarchy: Sendable, Codable {
    public let tree: HierarchyNode
    public let depth: Int
    public let nodeCount: Int

    public init(tree: HierarchyNode = HierarchyNode(), depth: Int = 0, nodeCount: Int = 0) {
        self.tree = tree
        self.depth = depth
        self.nodeCount = nodeCount
    }
}

/// Node in hierarchy
public struct HierarchyNode: Sendable, Codable {
    public let id: String
    public let type: String
    public let title: String?
    public let children: [HierarchyNode]
    public let metadata: [String: String]

    public init(
        id: String = "",
        type: String = "",
        title: String? = nil,
        children: [HierarchyNode] = [],
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.children = children
        self.metadata = metadata
    }
}

/// Navigation structure
public struct NavigationStructure: Sendable, Codable {
    public let tableOfContents: [NavigationItem]
    public let bookmarks: [NavigationItem]
    public let links: [NavigationLink]
    public let metadata: [String: String]

    public init(
        tableOfContents: [NavigationItem] = [],
        bookmarks: [NavigationItem] = [],
        links: [NavigationLink] = [],
        metadata: [String: String] = [:]
    ) {
        self.tableOfContents = tableOfContents
        self.bookmarks = bookmarks
        self.links = links
        self.metadata = metadata
    }
}

/// Navigation item
public struct NavigationItem: Sendable, Codable {
    public let id: String
    public let title: String
    public let target: ContentPosition
    public let level: Int
    public let metadata: [String: String]

    public init(
        id: String,
        title: String,
        target: ContentPosition,
        level: Int,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.target = target
        self.level = level
        self.metadata = metadata
    }
}

/// Navigation link
public struct NavigationLink: Sendable, Codable {
    public let id: String
    public let source: ContentPosition
    public let target: ContentPosition
    public let type: LinkType
    public let metadata: [String: String]

    public init(
        id: String,
        source: ContentPosition,
        target: ContentPosition,
        type: LinkType,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.source = source
        self.target = target
        self.type = type
        self.metadata = metadata
    }
}

/// Type of link
public enum LinkType: String, Sendable, Codable {
    case `internal` = "internal"
    case external = "external"
    case reference = "reference"
    case citation = "citation"

    public var description: String {
        switch self {
        case .internal: return "Internal document link"
        case .external: return "External URL link"
        case .reference: return "Reference link"
        case .citation: return "Citation link"
        }
    }
}

/// Metadata for structure
public struct StructureMetadata: Sendable, Codable {
    public let sectionCount: Int
    public let maxDepth: Int
    public let hasNavigation: Bool
    public let lastModified: Date

    public init(
        sectionCount: Int = 0,
        maxDepth: Int = 0,
        hasNavigation: Bool = false,
        lastModified: Date = Date()
    ) {
        self.sectionCount = sectionCount
        self.maxDepth = maxDepth
        self.hasNavigation = hasNavigation
        self.lastModified = lastModified
    }
}

// MARK: - Processing Types

/// Stage of processing
public enum ProcessingStage: String, Sendable, Codable, CaseIterable {
    case started = "started"
    case ingestion = "ingestion"
    case ocr = "ocr"
    case analysis = "analysis"
    case transformation = "transformation"
    case processing = "processing"
    case accessibility = "accessibility"
    case validation = "validation"
    case finalizing = "finalizing"
    case export = "export"
    case completed = "completed"
    case error = "error"

    public var description: String {
        switch self {
        case .started: return "Processing started"
        case .ingestion: return "Document ingestion"
        case .ocr: return "OCR text extraction"
        case .analysis: return "Content analysis"
        case .transformation: return "Format transformation"
        case .processing: return "Processing content"
        case .accessibility: return "Accessibility processing"
        case .validation: return "Content validation"
        case .finalizing: return "Finalizing output"
        case .export: return "Export generation"
        case .completed: return "Processing completed"
        case .error: return "Processing error"
        }
    }
}

/// Processing operation
public struct ProcessingOperation: Sendable, Codable {
    public let type: OperationType
    public let parameters: [String: String]
    public let requirements: OperationRequirements

    public init(
        type: OperationType,
        parameters: [String: String] = [:],
        requirements: OperationRequirements = OperationRequirements()
    ) {
        self.type = type
        self.parameters = parameters
        self.requirements = requirements
    }
}

/// Type of operation
public enum OperationType: String, Sendable, Codable {
    case extractText = "extract_text"
    case extractImages = "extract_images"
    case extractTables = "extract_tables"
    case convertFormat = "convert_format"
    case generateBraille = "generate_braille"
    case generateAudio = "generate_audio"
    case optimizeAccessibility = "optimize_accessibility"
    case validateStructure = "validate_structure"
    case compressContent = "compress_content"

    public var description: String {
        switch self {
        case .extractText: return "Extract text content"
        case .extractImages: return "Extract images"
        case .extractTables: return "Extract tables"
        case .convertFormat: return "Convert format"
        case .generateBraille: return "Generate braille"
        case .generateAudio: return "Generate audio"
        case .optimizeAccessibility: return "Optimize for accessibility"
        case .validateStructure: return "Validate structure"
        case .compressContent: return "Compress content"
        }
    }
}

/// Requirements for operation
public struct OperationRequirements: Sendable, Codable {
    public let memoryMB: Int
    public let cpuCores: Int
    public let diskSpaceMB: Int
    public let networkAccess: Bool
    public let estimatedDuration: TimeInterval

    public init(
        memoryMB: Int = 512,
        cpuCores: Int = 1,
        diskSpaceMB: Int = 100,
        networkAccess: Bool = false,
        estimatedDuration: TimeInterval = 60
    ) {
        self.memoryMB = memoryMB
        self.cpuCores = cpuCores
        self.diskSpaceMB = diskSpaceMB
        self.networkAccess = networkAccess
        self.estimatedDuration = estimatedDuration
    }
}

/// Status of processing
public enum ProcessingStatus: String, Sendable, Codable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    case paused = "paused"

    public var description: String {
        switch self {
        case .pending: return "Waiting to start"
        case .running: return "Currently processing"
        case .completed: return "Successfully completed"
        case .failed: return "Failed with errors"
        case .cancelled: return "Cancelled by user"
        case .paused: return "Temporarily paused"
        }
    }
}

/// Progress of processing
public struct ProcessingProgress: Sendable, Codable {
    public let percentage: Double
    public let currentStep: String
    public let totalSteps: Int
    public let completedSteps: Int
    public let estimatedTimeRemaining: TimeInterval?

    public init(
        percentage: Double = 0.0,
        currentStep: String = "",
        totalSteps: Int = 0,
        completedSteps: Int = 0,
        estimatedTimeRemaining: TimeInterval? = nil
    ) {
        self.percentage = percentage
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.completedSteps = completedSteps
        self.estimatedTimeRemaining = estimatedTimeRemaining
    }
}

/// Artifact from processing
public struct ProcessingArtifact: Sendable, Codable {
    public let id: String
    public let type: ArtifactType
    public let location: String
    public let format: String
    public let size: Int64
    public let checksum: String
    public let metadata: [String: String]

    public init(
        id: String,
        type: ArtifactType,
        location: String,
        format: String,
        size: Int64 = 0,
        checksum: String = "",
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.location = location
        self.format = format
        self.size = size
        self.checksum = checksum
        self.metadata = metadata
    }
}

/// Type of artifact
public enum ArtifactType: String, Sendable, Codable {
    case text = "text"
    case image = "image"
    case audio = "audio"
    case braille = "braille"
    case metadata = "metadata"
    case log = "log"
    case report = "report"

    public var description: String {
        switch self {
        case .text: return "Text content"
        case .image: return "Image file"
        case .audio: return "Audio file"
        case .braille: return "Braille file"
        case .metadata: return "Metadata file"
        case .log: return "Log file"
        case .report: return "Report file"
        }
    }
}

/// Error from processing
public struct ProcessingError: Sendable, Codable {
    public let id: String
    public let code: String
    public let message: String
    public let severity: ErrorSeverity
    public let stage: String
    public let recoverable: Bool
    public let metadata: [String: String]

    public init(
        id: String,
        code: String,
        message: String,
        severity: ErrorSeverity,
        stage: String,
        recoverable: Bool = false,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.code = code
        self.message = message
        self.severity = severity
        self.stage = stage
        self.recoverable = recoverable
        self.metadata = metadata
    }
}

/// Severity of error
public enum ErrorSeverity: String, Sendable, Codable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"

    public var description: String {
        switch self {
        case .info: return "Informational"
        case .warning: return "Warning"
        case .error: return "Error"
        case .critical: return "Critical"
        }
    }
}

/// Metadata for processing
public struct ProcessingMetadata: Sendable, Codable {
    public let startTime: Date
    public let endTime: Date?
    public let duration: TimeInterval?
    public let version: String
    public let configuration: [String: String]

    public init(
        startTime: Date = Date(),
        endTime: Date? = nil,
        duration: TimeInterval? = nil,
        version: String = "1.0",
        configuration: [String: String] = [:]
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.version = version
        self.configuration = configuration
    }
}

// MARK: - Export Types

/// Export format
public enum ExportFormat: String, Sendable, Codable, CaseIterable {
    case pdf = "pdf"
    case braille = "braille"
    case audio = "audio"
    case html = "html"
    case epub = "epub"
    case plainText = "plain_text"
    case structured = "structured"

    public var description: String {
        switch self {
        case .pdf: return "PDF document"
        case .braille: return "Braille file"
        case .audio: return "Audio file"
        case .html: return "HTML document"
        case .epub: return "EPUB e-book"
        case .plainText: return "Plain text"
        case .structured: return "Structured data"
        }
    }

    public var fileExtension: String {
        switch self {
        case .pdf: return ".pdf"
        case .braille: return ".brf"
        case .audio: return ".mp3"
        case .html: return ".html"
        case .epub: return ".epub"
        case .plainText: return ".txt"
        case .structured: return ".json"
        }
    }
}

/// Export destination
public struct ExportDestination: Sendable, Codable {
    public let type: DestinationType
    public let location: String
    public let credentials: ExportCredentials?
    public let settings: [String: String]

    public init(
        type: DestinationType,
        location: String,
        credentials: ExportCredentials? = nil,
        settings: [String: String] = [:]
    ) {
        self.type = type
        self.location = location
        self.credentials = credentials
        self.settings = settings
    }
}

/// Type of destination
public enum DestinationType: String, Sendable, Codable {
    case file = "file"
    case url = "url"
    case email = "email"
    case storage = "storage"
    case api = "api"

    public var description: String {
        switch self {
        case .file: return "Local file system"
        case .url: return "Remote URL"
        case .email: return "Email attachment"
        case .storage: return "Cloud storage"
        case .api: return "API endpoint"
        }
    }
}

/// Credentials for export
public struct ExportCredentials: Sendable, Codable {
    public let type: CredentialType
    public let identifier: String
    public let encrypted: Bool
    public let metadata: [String: String]

    public init(
        type: CredentialType,
        identifier: String,
        encrypted: Bool = true,
        metadata: [String: String] = [:]
    ) {
        self.type = type
        self.identifier = identifier
        self.encrypted = encrypted
        self.metadata = metadata
    }
}

/// Type of credential
public enum CredentialType: String, Sendable, Codable {
    case apiKey = "api_key"
    case token = "token"
    case certificate = "certificate"
    case usernamePassword = "username_password"

    public var description: String {
        switch self {
        case .apiKey: return "API key"
        case .token: return "Access token"
        case .certificate: return "Certificate"
        case .usernamePassword: return "Username and password"
        }
    }
}

/// Export settings
public struct ExportSettings: Sendable, Codable {
    public let quality: ExportQuality
    public let compression: CompressionSettings
    public let accessibility: AccessibilitySettings
    public let formatting: FormattingSettings
    public let metadata: [String: String]

    public init(
        quality: ExportQuality = ExportQuality(),
        compression: CompressionSettings = CompressionSettings(),
        accessibility: AccessibilitySettings = AccessibilitySettings(),
        formatting: FormattingSettings = FormattingSettings(),
        metadata: [String: String] = [:]
    ) {
        self.quality = quality
        self.compression = compression
        self.accessibility = accessibility
        self.formatting = formatting
        self.metadata = metadata
    }
}

/// Export quality settings
public struct ExportQuality: Sendable, Codable {
    public let level: QualityLevel
    public let resolution: Resolution?
    public let colorDepth: Int?
    public let sampleRate: Int?

    public init(
        level: QualityLevel = .standard,
        resolution: Resolution? = nil,
        colorDepth: Int? = nil,
        sampleRate: Int? = nil
    ) {
        self.level = level
        self.resolution = resolution
        self.colorDepth = colorDepth
        self.sampleRate = sampleRate
    }
}

/// Quality level
public enum QualityLevel: String, Sendable, Codable {
    case draft = "draft"
    case standard = "standard"
    case high = "high"
    case maximum = "maximum"

    public var description: String {
        switch self {
        case .draft: return "Draft quality"
        case .standard: return "Standard quality"
        case .high: return "High quality"
        case .maximum: return "Maximum quality"
        }
    }
}

/// Resolution settings
public struct Resolution: Sendable, Codable {
    public let width: Int
    public let height: Int
    public let unit: String

    public init(width: Int, height: Int, unit: String = "dpi") {
        self.width = width
        self.height = height
        self.unit = unit
    }
}

/// Compression settings
public struct CompressionSettings: Sendable, Codable {
    public let enabled: Bool
    public let algorithm: CompressionAlgorithm
    public let level: Int

    public init(
        enabled: Bool = false,
        algorithm: CompressionAlgorithm = .gzip,
        level: Int = 6
    ) {
        self.enabled = enabled
        self.algorithm = algorithm
        self.level = level
    }
}

/// Compression algorithm
public enum CompressionAlgorithm: String, Sendable, Codable {
    case none = "none"
    case gzip = "gzip"
    case zip = "zip"
    case brotli = "brotli"

    public var description: String {
        switch self {
        case .none: return "No compression"
        case .gzip: return "GZIP compression"
        case .zip: return "ZIP compression"
        case .brotli: return "Brotli compression"
        }
    }
}

/// Accessibility settings
public struct AccessibilitySettings: Sendable, Codable {
    public let enableAltText: Bool
    public let enableNavigation: Bool
    public let enableBraille: Bool
    public let enableAudio: Bool
    public let wcagLevel: WCAGLevel

    public init(
        enableAltText: Bool = true,
        enableNavigation: Bool = true,
        enableBraille: Bool = true,
        enableAudio: Bool = true,
        wcagLevel: WCAGLevel = .aa
    ) {
        self.enableAltText = enableAltText
        self.enableNavigation = enableNavigation
        self.enableBraille = enableBraille
        self.enableAudio = enableAudio
        self.wcagLevel = wcagLevel
    }
}

/// WCAG compliance level
public enum WCAGLevel: String, Sendable, Codable {
    case a = "A"
    case aa = "AA"
    case aaa = "AAA"

    public var description: String {
        switch self {
        case .a: return "WCAG 2.1 Level A"
        case .aa: return "WCAG 2.1 Level AA"
        case .aaa: return "WCAG 2.1 Level AAA"
        }
    }
}

/// Formatting settings
public struct FormattingSettings: Sendable, Codable {
    public let preserveStructure: Bool
    public let addMetadata: Bool
    public let includeTableOfContents: Bool
    public let customCSS: String?

    public init(
        preserveStructure: Bool = true,
        addMetadata: Bool = true,
        includeTableOfContents: Bool = false,
        customCSS: String? = nil
    ) {
        self.preserveStructure = preserveStructure
        self.addMetadata = addMetadata
        self.includeTableOfContents = includeTableOfContents
        self.customCSS = customCSS
    }
}

/// Export status
public enum ExportStatus: String, Sendable, Codable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"

    public var description: String {
        switch self {
        case .pending: return "Waiting to start"
        case .running: return "Currently exporting"
        case .completed: return "Successfully completed"
        case .failed: return "Failed with errors"
        case .cancelled: return "Cancelled by user"
        }
    }
}

/// Export result
public struct ExportResult: Sendable, Codable {
    public let location: String
    public let size: Int64
    public let checksum: String
    public let duration: TimeInterval
    public let warnings: [String]
    public let metadata: [String: String]

    public init(
        location: String,
        size: Int64 = 0,
        checksum: String = "",
        duration: TimeInterval = 0,
        warnings: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.location = location
        self.size = size
        self.checksum = checksum
        self.duration = duration
        self.warnings = warnings
        self.metadata = metadata
    }
}

/// Export metadata
public struct ExportMetadata: Sendable, Codable {
    public let format: String
    public let version: String
    public let timestamp: Date
    public let configuration: [String: String]

    public init(
        format: String = "1.0",
        version: String = "1.0",
        timestamp: Date = Date(),
        configuration: [String: String] = [:]
    ) {
        self.format = format
        self.version = version
        self.timestamp = timestamp
        self.configuration = configuration
    }
}

// MARK: - Supporting Types

/// Accessibility information
public struct AccessibilityInfo: Sendable, Codable {
    public let wcagLevel: WCAGLevel
    public let hasAltText: Bool
    public let hasNavigation: Bool
    public let hasBraille: Bool
    public let hasAudio: Bool
    public let metadata: [String: String]

    public init(
        wcagLevel: WCAGLevel = .aa,
        hasAltText: Bool = false,
        hasNavigation: Bool = false,
        hasBraille: Bool = false,
        hasAudio: Bool = false,
        metadata: [String: String] = [:]
    ) {
        self.wcagLevel = wcagLevel
        self.hasAltText = hasAltText
        self.hasNavigation = hasNavigation
        self.hasBraille = hasBraille
        self.hasAudio = hasAudio
        self.metadata = metadata
    }
}

/// Document metadata
public struct DocumentMetadata: Sendable, Codable {
    public let title: String?
    public let author: String?
    public let subject: String?
    public let keywords: [String]
    public let language: String?
    public let created: Date?
    public let modified: Date?
    public let version: String?
    public let custom: [String: String]

    public init(
        title: String? = nil,
        author: String? = nil,
        subject: String? = nil,
        keywords: [String] = [],
        language: String? = nil,
        created: Date? = nil,
        modified: Date? = nil,
        version: String? = nil,
        custom: [String: String] = [:]
    ) {
        self.title = title
        self.author = author
        self.subject = subject
        self.keywords = keywords
        self.language = language
        self.created = created
        self.modified = modified
        self.version = version
        self.custom = custom
    }
}

/// Diaplasion metadata
public struct DiaplasionMetadata: Sendable, Codable {
    public let version: String
    public let timestamp: Date
    public let configuration: DiaplasionConfiguration

    public init(
        version: String = "1.0",
        timestamp: Date = Date(),
        configuration: DiaplasionConfiguration = DiaplasionConfiguration()
    ) {
        self.version = version
        self.timestamp = timestamp
        self.configuration = configuration
    }
}

/// Diaplasion configuration
public struct DiaplasionConfiguration: Sendable, Codable {
    public let ocrEngine: String
    public let defaultExportFormat: ExportFormat
    public let enableAccessibility: Bool
    public let maxFileSize: Int64

    public init(
        ocrEngine: String = "tesseract",
        defaultExportFormat: ExportFormat = .pdf,
        enableAccessibility: Bool = true,
        maxFileSize: Int64 = 100 * 1024 * 1024  // 100MB
    ) {
        self.ocrEngine = ocrEngine
        self.defaultExportFormat = defaultExportFormat
        self.enableAccessibility = enableAccessibility
        self.maxFileSize = maxFileSize
    }
}

// MARK: - Contracts

/// Contract for Diaplasion state validation
public struct DiaplasionStateContract: WorkflowContract {
    public static let id = ContractID(name: "diaplasion.state", major: 1, minor: 0, schemaHash: "v1.0")

    public let payload: DiaplasionState

    public init(_ payload: DiaplasionState) {
        self.payload = payload
    }

    public static func validateInvariants(_ value: DiaplasionStateContract) throws {
        let state = value.payload

        // Validate project ID
        guard !state.projectId.isEmpty else {
            throw ValidationError.invalidRequest("Project ID cannot be empty")
        }

        // Validate document IDs are unique
        let documentIds = Set(state.documents.map { $0.id })
        guard documentIds.count == state.documents.count else {
            throw ValidationError.invalidRequest("Document IDs must be unique")
        }

        // Validate processing entities reference valid documents
        for processing in state.processing {
            guard state.documents.contains(where: { $0.id == processing.documentId }) else {
                throw ValidationError.invalidRequest("Processing entity references non-existent document: \(processing.documentId)")
            }
        }

        // Validate export entities reference valid documents
        for export in state.exports {
            guard state.documents.contains(where: { $0.id == export.documentId }) else {
                throw ValidationError.invalidRequest("Export entity references non-existent document: \(export.documentId)")
            }
        }
    }
}
