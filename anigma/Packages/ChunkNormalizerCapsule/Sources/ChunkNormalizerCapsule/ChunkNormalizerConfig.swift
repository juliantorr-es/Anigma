import Foundation
import CapsuleCore

/// Configuration for the ChunkNormalizerCapsule
public struct ChunkNormalizerConfig: Sendable, Codable, Equatable {
    /// Unicode normalization form to use
    public let unicodeNormalizationForm: UnicodeNormalizationForm
    
    /// Line ending policy
    public let lineEndingPolicy: LineEndingPolicy
    
    /// Whitespace normalization rules
    public let whitespaceRules: WhitespaceRules
    
    /// Paragraph boundary detection settings
    public let paragraphDetection: ParagraphDetectionSettings
    
    /// Character validation settings
    public let characterValidation: CharacterValidationSettings
    
    /// Strict mode settings
    public let strictMode: StrictModeSettings
    
    /// Performance settings
    public let performance: PerformanceSettings
    
    public init(
        unicodeNormalizationForm: UnicodeNormalizationForm = .nfc,
        lineEndingPolicy: LineEndingPolicy = .lf,
        whitespaceRules: WhitespaceRules = WhitespaceRules(),
        paragraphDetection: ParagraphDetectionSettings = ParagraphDetectionSettings(),
        characterValidation: CharacterValidationSettings = CharacterValidationSettings(),
        strictMode: StrictModeSettings = StrictModeSettings(),
        performance: PerformanceSettings = PerformanceSettings()
    ) {
        self.unicodeNormalizationForm = unicodeNormalizationForm
        self.lineEndingPolicy = lineEndingPolicy
        self.whitespaceRules = whitespaceRules
        self.paragraphDetection = paragraphDetection
        self.characterValidation = characterValidation
        self.strictMode = strictMode
        self.performance = performance
    }
}

// MARK: - Unicode Normalization

public enum UnicodeNormalizationForm: String, Codable, CaseIterable, Sendable {
    /// Normalization Form C (Canonical Composition)
    case nfc = "NFC"
    
    /// Normalization Form D (Canonical Decomposition)
    case nfd = "NFD"
    
    /// Normalization Form KC (Compatibility Composition)
    case nfkc = "NFKC"
    
    /// Normalization Form KD (Compatibility Decomposition)
    case nfkd = "NFKD"
}

// MARK: - Line Ending Policy

public enum LineEndingPolicy: String, Codable, CaseIterable, Sendable {
    /// Unix/Linux line endings (LF)
    case lf = "LF"
    
    /// Windows line endings (CRLF)
    case crlf = "CRLF"
    
    /// Classic Mac line endings (CR)
    case cr = "CR"
    
    /// Preserve original line endings
    case preserve = "preserve"
}

// MARK: - Whitespace Rules

public struct WhitespaceRules: Codable, Sendable, Equatable {
    /// Normalize multiple spaces to single space
    public let collapseMultipleSpaces: Bool
    
    /// Trim leading/trailing whitespace
    public let trimWhitespace: Bool
    
    /// Normalize non-breaking spaces to regular spaces
    public let normalizeNonBreakingSpaces: Bool
    
    /// Normalize various space characters to regular space
    public let normalizeSpaceCharacters: Bool
    
    /// Preserve indentation (tabs/spaces at line start)
    public let preserveIndentation: Bool
    
    public init(
        collapseMultipleSpaces: Bool = true,
        trimWhitespace: Bool = true,
        normalizeNonBreakingSpaces: Bool = true,
        normalizeSpaceCharacters: Bool = true,
        preserveIndentation: Bool = true
    ) {
        self.collapseMultipleSpaces = collapseMultipleSpaces
        self.trimWhitespace = trimWhitespace
        self.normalizeNonBreakingSpaces = normalizeNonBreakingSpaces
        self.normalizeSpaceCharacters = normalizeSpaceCharacters
        self.preserveIndentation = preserveIndentation
    }
}

// MARK: - Paragraph Detection

public struct ParagraphDetectionSettings: Codable, Sendable, Equatable {
    /// Paragraph separator characters/sequences
    public let paragraphSeparators: [String]
    
    /// Treat blank lines as paragraph breaks
    public let blankLinesAsBreaks: Bool
    
    /// Minimum characters for a paragraph
    public let minimumParagraphLength: Int
    
    /// Maximum characters for a paragraph
    public let maximumParagraphLength: Int?
    
    /// Preserve paragraph numbering
    public let preserveNumbering: Bool
    
    public init(
        paragraphSeparators: [String] = ["\n\n", "\r\n\r\n"],
        blankLinesAsBreaks: Bool = true,
        minimumParagraphLength: Int = 1,
        maximumParagraphLength: Int? = 10000,
        preserveNumbering: Bool = true
    ) {
        self.paragraphSeparators = paragraphSeparators
        self.blankLinesAsBreaks = blankLinesAsBreaks
        self.minimumParagraphLength = minimumParagraphLength
        self.maximumParagraphLength = maximumParagraphLength
        self.preserveNumbering = preserveNumbering
    }
}

// MARK: - Character Validation

public struct CharacterValidationSettings: Codable, Sendable, Equatable {
    /// Allow control characters
    public let allowControlCharacters: Bool
    
    /// Specific control characters to allow
    public let allowedControlCharacters: Set<Character>
    
    /// Allow non-printable characters
    public let allowNonPrintable: Bool
    
    /// Allow private use area characters
    public let allowPrivateUseArea: Bool
    
    /// Allow surrogate pairs
    public let allowSurrogates: Bool
    
    /// Maximum code point value
    public let maximumCodePoint: UInt32?
    
    /// Character replacement mapping
    public let replacementMap: [Character: Character]
    
    public init(
        allowControlCharacters: Bool = false,
        allowedControlCharacters: Set<Character> = ["\t", "\n", "\r"],
        allowNonPrintable: Bool = false,
        allowPrivateUseArea: Bool = false,
        allowSurrogates: Bool = true,
        maximumCodePoint: UInt32? = 0x10FFFF,  // Unicode maximum
        replacementMap: [Character: Character] = [:]
    ) {
        self.allowControlCharacters = allowControlCharacters
        self.allowedControlCharacters = allowedControlCharacters
        self.allowNonPrintable = allowNonPrintable
        self.allowPrivateUseArea = allowPrivateUseArea
        self.allowSurrogates = allowSurrogates
        self.maximumCodePoint = maximumCodePoint
        self.replacementMap = replacementMap
    }
}

// MARK: - Strict Mode Settings

public struct StrictModeSettings: Codable, Sendable, Equatable {
    /// Fail on invalid characters
    public let failOnInvalidCharacters: Bool
    
    /// Fail on missing unicode normalization
    public let failOnMissingNormalization: Bool
    
    /// Fail on mixed line endings
    public let failOnMixedLineEndings: Bool
    
    /// Fail on inconsistent whitespace
    public let failOnInconsistentWhitespace: Bool
    
    /// Fail on paragraph detection issues
    public let failOnParagraphIssues: Bool
    
    public init(
        failOnInvalidCharacters: Bool = true,
        failOnMissingNormalization: Bool = true,
        failOnMixedLineEndings: Bool = true,
        failOnInconsistentWhitespace: Bool = true,
        failOnParagraphIssues: Bool = true
    ) {
        self.failOnInvalidCharacters = failOnInvalidCharacters
        self.failOnMissingNormalization = failOnMissingNormalization
        self.failOnMixedLineEndings = failOnMixedLineEndings
        self.failOnInconsistentWhitespace = failOnInconsistentWhitespace
        self.failOnParagraphIssues = failOnParagraphIssues
    }
}

// MARK: - Performance Settings

public struct PerformanceSettings: Codable, Sendable, Equatable {
    /// Batch size for processing
    public let batchSize: Int
    
    /// Use parallel processing
    public let useParallelProcessing: Bool
    
    /// Cache normalized chunks
    public let cacheResults: Bool
    
    /// Maximum cache size
    public let maxCacheSize: Int
    
    /// Memory limit in bytes
    public let memoryLimit: Int?
    
    public init(
        batchSize: Int = 100,
        useParallelProcessing: Bool = true,
        cacheResults: Bool = true,
        maxCacheSize: Int = 1000,
        memoryLimit: Int? = 1024 * 1024 * 100  // 100MB
    ) {
        self.batchSize = batchSize
        self.useParallelProcessing = useParallelProcessing
        self.cacheResults = cacheResults
        self.maxCacheSize = maxCacheSize
        self.memoryLimit = memoryLimit
    }
}

// MARK: - Default Configurations

extension ChunkNormalizerConfig {
    /// Default configuration for general use
    public static let `default` = ChunkNormalizerConfig()
    
    /// Strict configuration for print-ready export
    public static let strict = ChunkNormalizerConfig(
        unicodeNormalizationForm: .nfc,
        lineEndingPolicy: .lf,
        whitespaceRules: WhitespaceRules(
            collapseMultipleSpaces: true,
            trimWhitespace: true,
            normalizeNonBreakingSpaces: true,
            normalizeSpaceCharacters: true,
            preserveIndentation: true
        ),
        paragraphDetection: ParagraphDetectionSettings(
            paragraphSeparators: ["\n\n"],
            blankLinesAsBreaks: true,
            minimumParagraphLength: 1,
            maximumParagraphLength: 5000,
            preserveNumbering: true
        ),
        characterValidation: CharacterValidationSettings(
            allowControlCharacters: false,
            allowedControlCharacters: ["\t", "\n"],
            allowNonPrintable: false,
            allowPrivateUseArea: false,
            allowSurrogates: true,
            maximumCodePoint: 0x10FFFF,
            replacementMap: [:]
        ),
        strictMode: StrictModeSettings(
            failOnInvalidCharacters: true,
            failOnMissingNormalization: true,
            failOnMixedLineEndings: true,
            failOnInconsistentWhitespace: true,
            failOnParagraphIssues: true
        ),
        performance: PerformanceSettings(
            batchSize: 50,
            useParallelProcessing: true,
            cacheResults: true,
            maxCacheSize: 500,
            memoryLimit: 1024 * 1024 * 50  // 50MB
        )
    )
    
    /// Lenient configuration for quick processing
    public static let lenient = ChunkNormalizerConfig(
        unicodeNormalizationForm: .nfc,
        lineEndingPolicy: .preserve,
        whitespaceRules: WhitespaceRules(
            collapseMultipleSpaces: false,
            trimWhitespace: false,
            normalizeNonBreakingSpaces: false,
            normalizeSpaceCharacters: false,
            preserveIndentation: true
        ),
        paragraphDetection: ParagraphDetectionSettings(
            paragraphSeparators: [],
            blankLinesAsBreaks: false,
            minimumParagraphLength: 1,
            maximumParagraphLength: nil,
            preserveNumbering: true
        ),
        characterValidation: CharacterValidationSettings(
            allowControlCharacters: true,
            allowedControlCharacters: [],
            allowNonPrintable: true,
            allowPrivateUseArea: true,
            allowSurrogates: true,
            maximumCodePoint: nil,
            replacementMap: [:]
        ),
        strictMode: StrictModeSettings(
            failOnInvalidCharacters: false,
            failOnMissingNormalization: false,
            failOnMixedLineEndings: false,
            failOnInconsistentWhitespace: false,
            failOnParagraphIssues: false
        ),
        performance: PerformanceSettings(
            batchSize: 200,
            useParallelProcessing: true,
            cacheResults: false,
            maxCacheSize: 0,
            memoryLimit: nil
        )
    )
}