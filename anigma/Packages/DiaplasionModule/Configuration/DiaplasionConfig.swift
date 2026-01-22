//
//  DiaplasionConfig.swift
//  DiaplasionModule
//
//  Centralized configuration for the Diaplasion alt-media pipeline.
//  Uses environment variables for production deployment with sensible defaults.
//

import Foundation
import AnigmaCore

/// Central configuration for the Diaplasion pipeline.
public struct DiaplasionConfig: Sendable {
    
    // MARK: - OCR Configuration
    
    /// OCR recognition level (fast or accurate)
    public let ocrLevel: RecognitionLevel
    
    /// Languages to use for OCR processing
    public let ocrLanguages: [String]
    
    /// OCR processing timeout in seconds
    public let ocrTimeout: TimeInterval
    
    /// DPI for rendering PDF pages to images
    public let ocrRenderDPI: CGFloat
    
    // MARK: - Document Processing
    
    /// Large document threshold in MB
    public let largeDocumentThreshold: Int
    
    /// Batch size for processing large documents
    public let largeDocumentBatchSize: Int
    
    /// Enable progress tracking for long jobs
    public let enableProgressTracking: Bool
    
    /// Checkpoint directory for resume capability
    public let checkpointDirectory: URL?
    
    // MARK: - EPUB Configuration
    
    /// Include images in EPUB output
    public let epubIncludeImages: Bool
    
    /// EPUB styling level
    public let epubStylingLevel: EPUBStylingLevel
    
    /// Include accessibility metadata in EPUB
    public let epubAccessibilityMetadata: Bool
    
    /// Maximum image size in pixels for EPUB
    public let epubMaxImageSize: Int
    
    // MARK: - Braille Configuration
    
    /// Default Braille grade
    public let brailleGrade: Int
    
    /// Cells per line for Braille output
    public let brailleCellsPerLine: Int
    
    /// Lines per page for Braille output
    public let brailleLinesPerPage: Int
    
    /// Enable Nemeth math translation
    public let brailleEnableNemeth: Bool
    
    /// Braille formatting mode
    public let brailleFormattingMode: BrailleFormattingMode
    
    // MARK: - Audio Configuration
    
    /// Default TTS voice name
    public let audioVoice: String?
    
    /// Speech rate multiplier
    public let audioSpeechRate: Double
    
    /// Speech pitch multiplier
    public let audioSpeechPitch: Double
    
    /// Generate audio files (not just SSML)
    public let audioGenerateFiles: Bool
    
    /// Audio format for output files
    public let audioFormat: AudioFormat
    
    /// Include pronunciation dictionary
    public let audioIncludePronunciation: Bool
    
    // MARK: - Quality Assurance
    
    /// Minimum OCR confidence threshold
    public let qaOCRConfidenceThreshold: Double
    
    /// Enable content validation checks
    public let qaEnableContentValidation: Bool
    
    /// Enable format compliance checks
    public let qaEnableFormatCompliance: Bool
    
    /// Review threshold for QA system
    public let qaReviewThreshold: Double
    
    // MARK: - Performance & Reliability
    
    /// Maximum memory usage in MB
    public let performanceMaxMemoryMB: Int
    
    /// Number of concurrent processing jobs
    public let performanceConcurrentJobs: Int
    
    /// Enable retry mechanisms
    public let reliabilityEnableRetries: Bool
    
    /// Maximum retry attempts
    public let reliabilityMaxRetries: Int
    
    /// Retry delay in seconds
    public let reliabilityRetryDelay: TimeInterval
    
    // MARK: - Logging & Monitoring
    
    /// Log level
    public let loggingLevel: LoggingLevel
    
    /// Enable performance metrics
    public let monitoringEnableMetrics: Bool
    
    /// Metrics output format
    public let monitoringMetricsFormat: MetricsFormat
    
    /// Cache directory for temporary files
    public let cacheDirectory: URL?
    
    // MARK: - Multi-language Support
    
    /// Default document language
    public let defaultLanguage: String
    
    /// Enable automatic language detection
    public let enableAutoLanguageDetection: Bool
    
    /// Supported languages
    public let supportedLanguages: [String]
    
    // MARK: - Advanced Features
    
    /// Enable table detection and processing
    public let enableTableDetection: Bool
    
    /// Enable image extraction from PDFs
    public let enableImageExtraction: Bool
    
    /// Enable layout analysis for complex documents
    public let enableLayoutAnalysis: Bool
    
    // MARK: - Initialization
    
    /// Load configuration from environment variables with sensible defaults.
    public init() {
        self.ocrLevel = RecognitionLevel(
            rawValue: EnvironmentVariableHelper.getString(
                key: .ocrLevel,
                defaultValue: "accurate"
            )
        ) ?? .accurate
        
        self.ocrLanguages = EnvironmentVariableHelper.getStringArray(
            key: .ocrLanguages,
            defaultValue: ["en-US"]
        )
        
        self.ocrTimeout = EnvironmentVariableHelper.getDouble(
            key: .ocrTimeout,
            defaultValue: 300.0
        )
        
        self.ocrRenderDPI = EnvironmentVariableHelper.getDouble(
            key: .ocrRenderDPI,
            defaultValue: 150.0
        )
        
        // Document Processing
        self.largeDocumentThreshold = EnvironmentVariableHelper.getInt(
            key: .largeDocumentThreshold,
            defaultValue: 50
        )
        
        self.largeDocumentBatchSize = EnvironmentVariableHelper.getInt(
            key: .largeDocumentBatchSize,
            defaultValue: 10
        )
        
        self.enableProgressTracking = EnvironmentVariableHelper.getBool(
            key: .enableProgressTracking,
            defaultValue: true
        )
        
        let checkpointPath = EnvironmentVariableHelper.getString(
            key: .checkpointDirectory,
            defaultValue: ""
        )
        self.checkpointDirectory = checkpointPath.isEmpty ? nil : URL(fileURLWithPath: checkpointPath)
        
        // EPUB Configuration
        self.epubIncludeImages = EnvironmentVariableHelper.getBool(
            key: .epubIncludeImages,
            defaultValue: true
        )
        
        self.epubStylingLevel = EPUBStylingLevel(
            rawValue: EnvironmentVariableHelper.getString(
                key: .epubStylingLevel,
                defaultValue: "enhanced"
            )
        ) ?? .enhanced
        
        self.epubAccessibilityMetadata = EnvironmentVariableHelper.getBool(
            key: .epubAccessibilityMetadata,
            defaultValue: true
        )
        
        self.epubMaxImageSize = EnvironmentVariableHelper.getInt(
            key: .epubMaxImageSize,
            defaultValue: 2048
        )
        
        // Braille Configuration
        self.brailleGrade = EnvironmentVariableHelper.getInt(
            key: .brailleGrade,
            defaultValue: 2
        )
        self.brailleCellsPerLine = EnvironmentVariableHelper.getInt(
            key: .brailleCellsPerLine,
            defaultValue: 40
        )
        self.brailleLinesPerPage = EnvironmentVariableHelper.getInt(
            key: .brailleLinesPerPage,
            defaultValue: 25
        )
        self.brailleEnableNemeth = EnvironmentVariableHelper.getBool(
            key: .brailleEnableNemeth,
            defaultValue: true
        )
        self.brailleFormattingMode = BrailleFormattingMode(
            rawValue: EnvironmentVariableHelper.getString(
                key: .brailleFormattingMode,
                defaultValue: "textbook"
            )
        ) ?? .textbook
        
        // Audio Configuration
        self.audioVoice = EnvironmentVariableHelper.getString(
            key: .audioVoice,
            defaultValue: ""
        ).isEmpty ? nil : EnvironmentVariableHelper.getString(key: .audioVoice, defaultValue: "")
        
        self.audioSpeechRate = EnvironmentVariableHelper.getDouble(
            key: .audioSpeechRate,
            defaultValue: 1.0
        )
        
        self.audioSpeechPitch = EnvironmentVariableHelper.getDouble(
            key: .audioSpeechPitch,
            defaultValue: 1.0
        )
        
        self.audioGenerateFiles = EnvironmentVariableHelper.getBool(
            key: .audioGenerateFiles,
            defaultValue: false
        )
        
        self.audioFormat = AudioFormat(
            rawValue: EnvironmentVariableHelper.getString(
                key: .audioFormat,
                defaultValue: "m4a"
            )
        ) ?? .m4a
        
        self.audioIncludePronunciation = EnvironmentVariableHelper.getBool(
            key: .audioIncludePronunciation,
            defaultValue: true
        )
        
        // Quality Assurance
        self.qaOCRConfidenceThreshold = EnvironmentVariableHelper.getDouble(
            key: .qaOCRConfidenceThreshold,
            defaultValue: 0.85
        )
        
        self.qaEnableContentValidation = EnvironmentVariableHelper.getBool(
            key: .qaEnableContentValidation,
            defaultValue: true
        )
        
        self.qaEnableFormatCompliance = EnvironmentVariableHelper.getBool(
            key: .qaEnableFormatCompliance,
            defaultValue: true
        )
        
        self.qaReviewThreshold = EnvironmentVariableHelper.getDouble(
            key: .qaReviewThreshold,
            defaultValue: 0.8
        )
        
        // Performance & Reliability
        self.performanceMaxMemoryMB = EnvironmentVariableHelper.getInt(
            key: .performanceMaxMemoryMB,
            defaultValue: 2048
        )
        
        self.performanceConcurrentJobs = EnvironmentVariableHelper.getInt(
            key: .performanceConcurrentJobs,
            defaultValue: 2
        )
        
        self.reliabilityEnableRetries = EnvironmentVariableHelper.getBool(
            key: .reliabilityEnableRetries,
            defaultValue: true
        )
        
        self.reliabilityMaxRetries = EnvironmentVariableHelper.getInt(
            key: .reliabilityMaxRetries,
            defaultValue: 3
        )
        
        self.reliabilityRetryDelay = EnvironmentVariableHelper.getDouble(
            key: .reliabilityRetryDelay,
            defaultValue: 5.0
        )
        
        // Logging & Monitoring
        self.loggingLevel = LoggingLevel(
            rawValue: EnvironmentVariableHelper.getString(
                key: .loggingLevel,
                defaultValue: "info"
            )
        ) ?? .info
        
        self.monitoringEnableMetrics = EnvironmentVariableHelper.getBool(
            key: .monitoringEnableMetrics,
            defaultValue: false
        )
        
        self.monitoringMetricsFormat = MetricsFormat(
            rawValue: EnvironmentVariableHelper.getString(
                key: .monitoringMetricsFormat,
                defaultValue: "json"
            )
        ) ?? .json
        
        let cachePath = EnvironmentVariableHelper.getString(
            key: .cacheDirectory,
            defaultValue: ""
        )
        self.cacheDirectory = cachePath.isEmpty ? nil : URL(fileURLWithPath: cachePath)
        
        // Multi-language Support
        self.defaultLanguage = EnvironmentVariableHelper.getString(
            key: .defaultLanguage,
            defaultValue: "en-US"
        )
        
        self.enableAutoLanguageDetection = EnvironmentVariableHelper.getBool(
            key: .enableAutoLanguageDetection,
            defaultValue: false
        )
        
        self.supportedLanguages = EnvironmentVariableHelper.getStringArray(
            key: .supportedLanguages,
            defaultValue: ["en-US", "es-ES", "fr-FR", "de-DE"]
        )
        
        // Advanced Features
        self.enableTableDetection = EnvironmentVariableHelper.getBool(
            key: .enableTableDetection,
            defaultValue: false
        )
        
        self.enableImageExtraction = EnvironmentVariableHelper.getBool(
            key: .enableImageExtraction,
            defaultValue: true
        )
        
        self.enableLayoutAnalysis = EnvironmentVariableHelper.getBool(
            key: .enableLayoutAnalysis,
            defaultValue: false
        )
    }
    
    /// Validate the configuration and report any issues.
    public func validate() -> [ConfigurationIssue] {
        var issues: [ConfigurationIssue] = []
        
        // OCR validation
        if ocrLanguages.isEmpty {
            issues.append(.missingRequiredValue(.ocrLanguages))
        }
        
        // Document processing validation
        if largeDocumentThreshold < 1 {
            issues.append(.invalidValue(.largeDocumentThreshold, "Must be >= 1"))
        }
        
        // Braille validation
        if brailleGrade != 1 && brailleGrade != 2 {
            issues.append(.invalidValue(.brailleGrade, "Must be 1 or 2"))
        }
        
        // Audio validation
        if audioSpeechRate < 0.5 || audioSpeechRate > 2.0 {
            issues.append(.invalidValue(.audioSpeechRate, "Must be between 0.5 and 2.0"))
        }
        
        if audioSpeechPitch < 0.5 || audioSpeechPitch > 2.0 {
            issues.append(.invalidValue(.audioSpeechPitch, "Must be between 0.5 and 2.0"))
        }
        
        // QA validation
        if qaOCRConfidenceThreshold < 0.0 || qaOCRConfidenceThreshold > 1.0 {
            issues.append(.invalidValue(.qaOCRConfidenceThreshold, "Must be between 0.0 and 1.0"))
        }
        
        if qaReviewThreshold < 0.0 || qaReviewThreshold > 1.0 {
            issues.append(.invalidValue(.qaReviewThreshold, "Must be between 0.0 and 1.0"))
        }
        
        // Performance validation
        if performanceConcurrentJobs < 1 {
            issues.append(.invalidValue(.performanceConcurrentJobs, "Must be >= 1"))
        }
        
        if reliabilityMaxRetries < 0 {
            issues.append(.invalidValue(.reliabilityMaxRetries, "Must be >= 0"))
        }
        
        return issues
    }
    
    /// Check if a document is considered "large" based on file size.
    public func isLargeDocument(fileSizeBytes: Int64) -> Bool {
        let fileSizeMB = Double(fileSizeBytes) / (1024 * 1024)
        return fileSizeMB >= Double(largeDocumentThreshold)
    }
    
    /// Get the optimal cache directory for the current configuration.
    public func getEffectiveCacheDirectory() -> URL {
        if let cacheDirectory = cacheDirectory {
            return cacheDirectory
        }
        
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cachesDir = paths.first!
        return cachesDir.appendingPathComponent("Diaplasion")
    }
    
    /// Get the effective checkpoint directory.
    public func getEffectiveCheckpointDirectory() -> URL {
        if let checkpointDirectory = checkpointDirectory {
            return checkpointDirectory
        }
        
        return getEffectiveCacheDirectory().appendingPathComponent("Checkpoints")
    }
}

/// Supported OCR recognition levels.
public enum RecognitionLevel: String, CaseIterable, Sendable {
    case fast = "fast"
    case accurate = "accurate"
}

/// EPUB styling levels.
public enum EPUBStylingLevel: String, CaseIterable, Sendable {
    case basic = "basic"
    case enhanced = "enhanced"
    case accessible = "accessible"
}

/// Braille formatting modes.
public enum BrailleFormattingMode: String, CaseIterable, Sendable {
    case literary = "literary"
    case textbook = "textbook"
    case technical = "technical"
}

/// Audio output formats.
public enum AudioFormat: String, CaseIterable, Sendable {
    case m4a = "m4a"
    case wav = "wav"
    case mp3 = "mp3"
}

/// Logging levels.
public enum LoggingLevel: String, CaseIterable, Sendable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
}

/// Metrics output formats.
public enum MetricsFormat: String, CaseIterable, Sendable {
    case json = "json"
    case prometheus = "prometheus"
}

/// Configuration validation issues.
public enum ConfigurationIssue: Sendable {
    case missingRequiredValue(DiaplasionEnvironmentKey)
    case invalidValue(DiaplasionEnvironmentKey, String)
    case incompatibleValues(DiaplasionEnvironmentKey, DiaplasionEnvironmentKey)
    case deprecatedValue(DiaplasionEnvironmentKey, String)
    
    public var description: String {
        switch self {
        case .missingRequiredValue(let key):
            return "Missing required environment variable: \(key.rawValue)"
        case .invalidValue(let key, let reason):
            return "Invalid value for \(key.rawValue): \(reason)"
        case .incompatibleValues(let key1, let key2):
            return "Incompatible values: \(key1.rawValue) and \(key2.rawValue)"
        case .deprecatedValue(let key, let replacement):
            return "Deprecated environment variable \(key.rawValue). Use: \(replacement)"
        }
    }
}

/// Shared instance of the Diaplasion configuration.
public let DiaplasionConfiguration = DiaplasionConfig()

/// Extension to log configuration on startup.
extension DiaplasionConfig {
    /// Log current configuration if logging level permits.
    public func logConfiguration() {
        switch loggingLevel {
        case .debug, .info:
            EnvironmentVariableHelper.logCurrentConfiguration()
        case .warning, .error:
            break
        }
    }
}