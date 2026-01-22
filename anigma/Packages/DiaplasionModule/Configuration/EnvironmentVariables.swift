//
//  EnvironmentVariables.swift
//  DiaplasionModule
//
//  Environment variable definitions for Diaplasion configuration.
//

import Foundation

/// Environment variable keys used throughout the Diaplasion pipeline.
public enum DiaplasionEnvironmentKey: String, CaseIterable {
    
    // MARK: - OCR Configuration
    
    /// OCR recognition level: "fast" or "accurate"
    case ocrLevel = "DIAPLASION_OCR_LEVEL"
    
    /// OCR languages as comma-separated codes: "en-US,es-ES,fr-FR"
    case ocrLanguages = "DIAPLASION_OCR_LANGUAGES"
    
    /// OCR processing timeout in seconds
    case ocrTimeout = "DIAPLASION_OCR_TIMEOUT"
    
    /// DPI for rendering PDF pages to images
    case ocrRenderDPI = "DIAPLASION_OCR_RENDER_DPI"
    
    // MARK: - Document Processing
    
    /// Large document threshold in MB
    case largeDocumentThreshold = "DIAPLASION_LARGE_DOC_THRESHOLD_MB"
    
    /// Batch size for processing large documents
    case largeDocumentBatchSize = "DIAPLASION_LARGE_DOC_BATCH_SIZE"
    
    /// Enable progress tracking for long jobs
    case enableProgressTracking = "DIAPLASION_ENABLE_PROGRESS_TRACKING"
    
    /// Checkpoint directory for resume capability
    case checkpointDirectory = "DIAPLASION_CHECKPOINT_DIRECTORY"
    
    // MARK: - EPUB Configuration
    
    /// Include images in EPUB output
    case epubIncludeImages = "DIAPLASION_EPUB_INCLUDE_IMAGES"
    
    /// EPUB CSS styling level: "basic", "enhanced", "accessible"
    case epubStylingLevel = "DIAPLASION_EPUB_STYLING_LEVEL"
    
    /// Include accessibility metadata in EPUB
    case epubAccessibilityMetadata = "DIAPLASION_EPUB_ACCESSIBILITY_METADATA"
    
    /// Maximum image size in pixels for EPUB
    case epubMaxImageSize = "DIAPLASION_EPUB_MAX_IMAGE_SIZE"
    
    // MARK: - Braille Configuration
    
    /// Default Braille grade: "1" or "2"
    case brailleGrade = "DIAPLASION_BRAILLE_GRADE"
    
    /// Cells per line for Braille output
    case brailleCellsPerLine = "DIAPLASION_BRAILLE_CELLS_PER_LINE"
    
    /// Lines per page for Braille output
    case brailleLinesPerPage = "DIAPLASION_BRAILLE_LINES_PER_PAGE"
    
    /// Enable Nemeth math translation
    case brailleEnableNemeth = "DIAPLASION_BRAILLE_ENABLE_NEMETH"
    
    /// Braille formatting mode: "literary", "textbook", "technical"
    case brailleFormattingMode = "DIAPLASION_BRAILLE_FORMATTING_MODE"
    
    // MARK: - Audio Configuration
    
    /// Default TTS voice name
    case audioVoice = "DIAPLASION_AUDIO_VOICE"
    
    /// Speech rate multiplier (0.5 to 2.0)
    case audioSpeechRate = "DIAPLASION_AUDIO_SPEECH_RATE"
    
    /// Speech pitch multiplier (0.5 to 2.0)
    case audioSpeechPitch = "DIAPLASION_AUDIO_SPEECH_PITCH"
    
    /// Generate audio files (not just SSML)
    case audioGenerateFiles = "DIAPLASION_AUDIO_GENERATE_FILES"
    
    /// Audio format: "m4a", "wav", "mp3"
    case audioFormat = "DIAPLASION_AUDIO_FORMAT"
    
    /// Include pronunciation dictionary
    case audioIncludePronunciation = "DIAPLASION_AUDIO_INCLUDE_PRONUNCIATION"
    
    // MARK: - Quality Assurance
    
    /// Minimum OCR confidence threshold
    case qaOCRConfidenceThreshold = "DIAPLASION_QA_OCR_CONFIDENCE_THRESHOLD"
    
    /// Enable content validation checks
    case qaEnableContentValidation = "DIAPLASION_QA_ENABLE_CONTENT_VALIDATION"
    
    /// Enable format compliance checks
    case qaEnableFormatCompliance = "DIAPLASION_QA_ENABLE_FORMAT_COMPLIANCE"
    
    /// Review threshold for QA system
    case qaReviewThreshold = "DIAPLASION_QA_REVIEW_THRESHOLD"
    
    // MARK: - Performance & Reliability
    
    /// Maximum memory usage in MB
    case performanceMaxMemoryMB = "DIAPLASION_PERFORMANCE_MAX_MEMORY_MB"
    
    /// Number of concurrent processing jobs
    case performanceConcurrentJobs = "DIAPLASION_PERFORMANCE_CONCURRENT_JOBS"
    
    /// Enable retry mechanisms
    case reliabilityEnableRetries = "DIAPLASION_RELIABILITY_ENABLE_RETRIES"
    
    /// Maximum retry attempts
    case reliabilityMaxRetries = "DIAPLASION_RELIABILITY_MAX_RETRIES"
    
    /// Retry delay in seconds
    case reliabilityRetryDelay = "DIAPLASION_RELIABILITY_RETRY_DELAY"
    
    // MARK: - Logging & Monitoring
    
    /// Log level: "debug", "info", "warning", "error"
    case loggingLevel = "DIAPLASION_LOGGING_LEVEL"
    
    /// Enable performance metrics
    case monitoringEnableMetrics = "DIAPLASION_MONITORING_ENABLE_METRICS"
    
    /// Metrics output format: "json", "prometheus"
    case monitoringMetricsFormat = "DIAPLASION_MONITORING_METRICS_FORMAT"
    
    /// Cache directory for temporary files
    case cacheDirectory = "DIAPLASION_CACHE_DIRECTORY"
    
    // MARK: - Multi-language Support
    
    /// Default document language
    case defaultLanguage = "DIAPLASION_DEFAULT_LANGUAGE"
    
    /// Enable automatic language detection
    case enableAutoLanguageDetection = "DIAPLASION_ENABLE_AUTO_LANGUAGE_DETECTION"
    
    /// Supported languages as comma-separated codes
    case supportedLanguages = "DIAPLASION_SUPPORTED_LANGUAGES"
    
    // MARK: - Advanced Features
    
    /// Enable table detection and processing
    case enableTableDetection = "DIAPLASION_ENABLE_TABLE_DETECTION"
    
    /// Enable image extraction from PDFs
    case enableImageExtraction = "DIAPLASION_ENABLE_IMAGE_EXTRACTION"
    
    /// Enable layout analysis for complex documents
    case enableLayoutAnalysis = "DIAPLASION_ENABLE_LAYOUT_ANALYSIS"
}

/// Helper methods for working with environment variables.
public enum EnvironmentVariableHelper {
    
    /// Get environment variable value with optional default.
    public static func getString(
        key: DiaplasionEnvironmentKey,
        defaultValue: String
    ) -> String {
        return ProcessInfo.processInfo.environment[key.rawValue] ?? defaultValue
    }
    
    /// Get boolean environment variable value.
    public static func getBool(
        key: DiaplasionEnvironmentKey,
        defaultValue: Bool
    ) -> Bool {
        let value = getString(key: key, defaultValue: defaultValue ? "true" : "false")
        return value.lowercased() == "true" || value == "1"
    }
    
    /// Get integer environment variable value.
    public static func getInt(
        key: DiaplasionEnvironmentKey,
        defaultValue: Int
    ) -> Int {
        let value = getString(key: key, defaultValue: String(defaultValue))
        return Int(value) ?? defaultValue
    }
    
    /// Get double environment variable value.
    public static func getDouble(
        key: DiaplasionEnvironmentKey,
        defaultValue: Double
    ) -> Double {
        let value = getString(key: key, defaultValue: String(defaultValue))
        return Double(value) ?? defaultValue
    }
    
    /// Get array of strings from comma-separated environment variable.
    public static func getStringArray(
        key: DiaplasionEnvironmentKey,
        defaultValue: [String]
    ) -> [String] {
        let value = getString(key: key, defaultValue: defaultValue.joined(separator: ","))
        return value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
    
    /// Validate required environment variables.
    public static func validateRequired(_ keys: [DiaplasionEnvironmentKey]) -> [DiaplasionEnvironmentKey] {
        return keys.filter { ProcessInfo.processInfo.environment[$0.rawValue] == nil }
    }
    
    /// Get all Diaplasion environment variables currently set.
    public static func getAllDiaplasionEnvironmentVariables() -> [String: String] {
        return ProcessInfo.processInfo.environment.filter { key, _ in
            DiaplasionEnvironmentKey.allCases.contains { $0.rawValue == key }
        }
    }
    
    /// Export current configuration as JSON string.
    public static func exportConfiguration() throws -> String {
        let config = getAllDiaplasionEnvironmentVariables()
        let data = try JSONSerialization.data(withJSONObject: config, options: .prettyPrinted)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    
    /// Log all current Diaplasion environment variables (excluding sensitive values).
    public static func logCurrentConfiguration() {
        let config = getAllDiaplasionEnvironmentVariables()
        
        print("🔧 Diaplasion Configuration:")
        for (key, value) in config.sorted(by: { $0.key < $1.key }) {
            // Mask potential sensitive values
            let displayValue = key.contains("PASSWORD") || key.contains("SECRET") || key.contains("TOKEN")
                ? "***REDACTED***"
                : value
            print("  \(key)=\(displayValue)")
        }
        
        if config.isEmpty {
            print("  (Using default values)")
        }
    }
}