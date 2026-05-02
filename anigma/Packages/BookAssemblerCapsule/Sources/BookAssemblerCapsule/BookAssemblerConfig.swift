import Foundation
import CapsuleCore

/// Configuration for the BookAssemblerCapsule
public struct BookAssemblerConfig: Sendable, Codable, Equatable {
    /// Node ID generation strategy
    public let nodeIDStrategy: NodeIDStrategy
    
    /// Structure validation settings
    public let validation: ValidationSettings
    
    /// Metadata handling settings
    public let metadata: MetadataSettings
    
    /// Performance settings
    public let performance: PerformanceSettings
    
    /// Error handling settings
    public let errorHandling: ErrorHandlingSettings
    
    public init(
        nodeIDStrategy: NodeIDStrategy = NodeIDStrategy(),
        validation: ValidationSettings = ValidationSettings(),
        metadata: MetadataSettings = MetadataSettings(),
        performance: PerformanceSettings = PerformanceSettings(),
        errorHandling: ErrorHandlingSettings = ErrorHandlingSettings()
    ) {
        self.nodeIDStrategy = nodeIDStrategy
        self.validation = validation
        self.metadata = metadata
        self.performance = performance
        self.errorHandling = errorHandling
    }
}

// MARK: - Node ID Strategy

public struct NodeIDStrategy: Codable, Sendable, Equatable {
    /// Hash algorithm for node IDs
    public let hashAlgorithm: HashAlgorithm
    
    /// Include chunk ID in node ID
    public let includeChunkID: Bool
    
    /// Include local path in node ID
    public let includeLocalPath: Bool
    
    /// Include node type in node ID
    public let includeNodeType: Bool
    
    /// Include content hash in node ID
    public let includeContentHash: Bool
    
    /// Separator for ID components
    public let separator: String
    
    public enum HashAlgorithm: String, Codable, CaseIterable, Sendable {
        case blake3 = "blake3"
        case sha256 = "sha256"
        case sha1 = "sha1"
        case md5 = "md5"
        case custom = "custom"
    }
    
    public init(
        hashAlgorithm: HashAlgorithm = .blake3,
        includeChunkID: Bool = true,
        includeLocalPath: Bool = true,
        includeNodeType: Bool = true,
        includeContentHash: Bool = false,
        separator: String = "-"
    ) {
        self.hashAlgorithm = hashAlgorithm
        self.includeChunkID = includeChunkID
        self.includeLocalPath = includeLocalPath
        self.includeNodeType = includeNodeType
        self.includeContentHash = includeContentHash
        self.separator = separator
    }
}

// MARK: - Validation Settings

public struct ValidationSettings: Codable, Sendable, Equatable {
    /// Validate chunk ordering
    public let validateOrdering: Bool
    
    /// Validate chapter numbering
    public let validateChapterNumbers: Bool
    
    /// Validate section hierarchy
    public let validateSectionHierarchy: Bool
    
    /// Validate metadata completeness
    public let validateMetadata: Bool
    
    /// Validate cross-references
    public let validateCrossReferences: Bool
    
    /// Validate asset references
    public let validateAssetReferences: Bool
    
    /// Maximum nesting depth
    public let maxNestingDepth: Int
    
    /// Maximum nodes per document
    public let maxNodesPerDocument: Int?
    
    public init(
        validateOrdering: Bool = true,
        validateChapterNumbers: Bool = true,
        validateSectionHierarchy: Bool = true,
        validateMetadata: Bool = true,
        validateCrossReferences: Bool = true,
        validateAssetReferences: Bool = true,
        maxNestingDepth: Int = 10,
        maxNodesPerDocument: Int? = 10000
    ) {
        self.validateOrdering = validateOrdering
        self.validateChapterNumbers = validateChapterNumbers
        self.validateSectionHierarchy = validateSectionHierarchy
        self.validateMetadata = validateMetadata
        self.validateCrossReferences = validateCrossReferences
        self.validateAssetReferences = validateAssetReferences
        self.maxNestingDepth = maxNestingDepth
        self.maxNodesPerDocument = maxNodesPerDocument
    }
}

// MARK: - Metadata Settings

public struct MetadataSettings: Codable, Sendable, Equatable {
    /// Preserve original chunk metadata
    public let preserveChunkMetadata: Bool
    
    /// Merge metadata from chunks
    public let mergeMetadata: Bool
    
    /// Default metadata values
    public let defaultMetadata: [String: String]
    
    /// Required metadata fields
    public let requiredMetadata: [String]
    
    /// Metadata validation rules
    public let validationRules: [String: MetadataValidationRule]
    
    public struct MetadataValidationRule: Codable, Sendable, Equatable {
        public let type: ValidationType
        public let required: Bool
        public let pattern: String?
        public let minLength: Int?
        public let maxLength: Int?
        public let allowedValues: [String]?
        
        public enum ValidationType: String, Codable, CaseIterable, Sendable {
            case string = "string"
            case integer = "integer"
            case date = "date"
            case boolean = "boolean"
            case url = "url"
            case email = "email"
        }
        
        public init(
            type: ValidationType = .string,
            required: Bool = false,
            pattern: String? = nil,
            minLength: Int? = nil,
            maxLength: Int? = nil,
            allowedValues: [String]? = nil
        ) {
            self.type = type
            self.required = required
            self.pattern = pattern
            self.minLength = minLength
            self.maxLength = maxLength
            self.allowedValues = allowedValues
        }
    }
    
    public init(
        preserveChunkMetadata: Bool = true,
        mergeMetadata: Bool = true,
        defaultMetadata: [String: String] = [:],
        requiredMetadata: [String] = [],
        validationRules: [String: MetadataValidationRule] = [:]
    ) {
        self.preserveChunkMetadata = preserveChunkMetadata
        self.mergeMetadata = mergeMetadata
        self.defaultMetadata = defaultMetadata
        self.requiredMetadata = requiredMetadata
        self.validationRules = validationRules
    }
}

// MARK: - Performance Settings

public struct PerformanceSettings: Codable, Sendable, Equatable {
    /// Batch size for processing
    public let batchSize: Int
    
    /// Use parallel processing
    public let useParallelProcessing: Bool
    
    /// Cache assembled documents
    public let cacheResults: Bool
    
    /// Maximum cache size
    public let maxCacheSize: Int
    
    /// Memory limit in bytes
    public let memoryLimit: Int?
    
    /// Timeout for assembly in seconds
    public let timeout: TimeInterval?
    
    public init(
        batchSize: Int = 50,
        useParallelProcessing: Bool = true,
        cacheResults: Bool = true,
        maxCacheSize: Int = 100,
        memoryLimit: Int? = 1024 * 1024 * 100,  // 100MB
        timeout: TimeInterval? = 30.0
    ) {
        self.batchSize = batchSize
        self.useParallelProcessing = useParallelProcessing
        self.cacheResults = cacheResults
        self.maxCacheSize = maxCacheSize
        self.memoryLimit = memoryLimit
        self.timeout = timeout
    }
}

// MARK: - Error Handling Settings

public struct ErrorHandlingSettings: Codable, Sendable, Equatable {
    /// Fail on validation errors
    public let failOnValidationErrors: Bool
    
    /// Fail on missing chunks
    public let failOnMissingChunks: Bool
    
    /// Fail on duplicate IDs
    public let failOnDuplicateIDs: Bool
    
    /// Fail on invalid metadata
    public let failOnInvalidMetadata: Bool
    
    /// Maximum allowed errors before failing
    public let maxAllowedErrors: Int
    
    /// Log level for errors
    public let errorLogLevel: LogLevel
    
    public enum LogLevel: String, Codable, CaseIterable, Sendable {
        case debug = "debug"
        case info = "info"
        case warning = "warning"
        case error = "error"
        case critical = "critical"
    }
    
    public init(
        failOnValidationErrors: Bool = true,
        failOnMissingChunks: Bool = true,
        failOnDuplicateIDs: Bool = true,
        failOnInvalidMetadata: Bool = true,
        maxAllowedErrors: Int = 10,
        errorLogLevel: LogLevel = .error
    ) {
        self.failOnValidationErrors = failOnValidationErrors
        self.failOnMissingChunks = failOnMissingChunks
        self.failOnDuplicateIDs = failOnDuplicateIDs
        self.failOnInvalidMetadata = failOnInvalidMetadata
        self.maxAllowedErrors = maxAllowedErrors
        self.errorLogLevel = errorLogLevel
    }
}

// MARK: - Default Configurations

extension BookAssemblerConfig {
    /// Default configuration for general use
    public static let `default` = BookAssemblerConfig()
    
    /// Strict configuration for print-ready export
    public static let strict = BookAssemblerConfig(
        nodeIDStrategy: NodeIDStrategy(
            hashAlgorithm: .blake3,
            includeChunkID: true,
            includeLocalPath: true,
            includeNodeType: true,
            includeContentHash: true,
            separator: "-"
        ),
        validation: ValidationSettings(
            validateOrdering: true,
            validateChapterNumbers: true,
            validateSectionHierarchy: true,
            validateMetadata: true,
            validateCrossReferences: true,
            validateAssetReferences: true,
            maxNestingDepth: 8,
            maxNodesPerDocument: 5000
        ),
        metadata: MetadataSettings(
            preserveChunkMetadata: true,
            mergeMetadata: true,
            defaultMetadata: [
                "language": "en",
                "created_at": Date().ISO8601Format()
            ],
            requiredMetadata: ["title", "author"],
            validationRules: [
                "title": MetadataValidationRule(
                    type: .string,
                    required: true,
                    minLength: 1,
                    maxLength: 200
                ),
                "author": MetadataValidationRule(
                    type: .string,
                    required: true,
                    minLength: 1,
                    maxLength: 100
                ),
                "date": MetadataValidationRule(
                    type: .date,
                    required: false
                ),
                "language": MetadataValidationRule(
                    type: .string,
                    required: false,
                    allowedValues: ["en", "fr", "de", "es", "it", "pt", "ru", "zh", "ja", "ko"]
                )
            ]
        ),
        performance: PerformanceSettings(
            batchSize: 25,
            useParallelProcessing: true,
            cacheResults: true,
            maxCacheSize: 50,
            memoryLimit: 1024 * 1024 * 50,  // 50MB
            timeout: 60.0
        ),
        errorHandling: ErrorHandlingSettings(
            failOnValidationErrors: true,
            failOnMissingChunks: true,
            failOnDuplicateIDs: true,
            failOnInvalidMetadata: true,
            maxAllowedErrors: 0,  // No errors allowed in strict mode
            errorLogLevel: .error
        )
    )
    
    /// Lenient configuration for quick processing
    public static let lenient = BookAssemblerConfig(
        nodeIDStrategy: NodeIDStrategy(
            hashAlgorithm: .sha1,
            includeChunkID: true,
            includeLocalPath: false,
            includeNodeType: false,
            includeContentHash: false,
            separator: "_"
        ),
        validation: ValidationSettings(
            validateOrdering: false,
            validateChapterNumbers: false,
            validateSectionHierarchy: false,
            validateMetadata: false,
            validateCrossReferences: false,
            validateAssetReferences: false,
            maxNestingDepth: 20,
            maxNodesPerDocument: nil
        ),
        metadata: MetadataSettings(
            preserveChunkMetadata: false,
            mergeMetadata: false,
            defaultMetadata: [:],
            requiredMetadata: [],
            validationRules: [:]
        ),
        performance: PerformanceSettings(
            batchSize: 100,
            useParallelProcessing: true,
            cacheResults: false,
            maxCacheSize: 0,
            memoryLimit: nil,
            timeout: nil
        ),
        errorHandling: ErrorHandlingSettings(
            failOnValidationErrors: false,
            failOnMissingChunks: false,
            failOnDuplicateIDs: false,
            failOnInvalidMetadata: false,
            maxAllowedErrors: 100,
            errorLogLevel: .warning
        )
    )
}