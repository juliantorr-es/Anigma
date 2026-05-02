import Foundation
import CanonicalTokenizer
import OSLog
import CryptoKit

public enum UnicodeForm: UInt32, Sendable, CaseIterable, Codable {
    case none = 0
    case nfc = 1
    case nfd = 2
    case nfkc = 3
    case nfkd = 4
    
    public static var `default`: UnicodeForm { .nfc }
}

public enum BoundaryType: UInt32, Sendable, CaseIterable, Codable {
    case character = 0
    case grapheme = 1
    case word = 2
    case sentence = 3
    case line = 4
    
    public static var `default`: BoundaryType { .word }
}

public struct TextBoundary: Sendable, Equatable, Codable {
    public var offset: Int
    public var length: Int
    public var type: BoundaryType
    
    public init(offset: Int, length: Int, type: BoundaryType) {
        self.offset = offset
        self.length = length
        self.type = type
    }
}

public struct TextStatistics: Sendable {
    public var byteCount: Int
    public var characterCount: Int
    public var graphemeCount: Int
    public var wordCount: Int
    public var sentenceCount: Int
    public var lineCount: Int
    
    public init(
        byteCount: Int = 0,
        characterCount: Int = 0,
        graphemeCount: Int = 0,
        wordCount: Int = 0,
        sentenceCount: Int = 0,
        lineCount: Int = 0
    ) {
        self.byteCount = byteCount
        self.characterCount = characterCount
        self.graphemeCount = graphemeCount
        self.wordCount = wordCount
        self.sentenceCount = sentenceCount
        self.lineCount = lineCount
    }
}

public struct PreprocessedText: Sendable {
    public var normalizedText: String
    public var boundaries: [TextBoundary]
    public var statistics: TextStatistics
    public var tokenCount: Int?
    public var sanitized: Bool
    public var originalLength: Int
    public var processedLength: Int
    
    public init(
        normalizedText: String,
        boundaries: [TextBoundary],
        statistics: TextStatistics,
        tokenCount: Int? = nil,
        sanitized: Bool = false,
        originalLength: Int,
        processedLength: Int
    ) {
        self.normalizedText = normalizedText
        self.boundaries = boundaries
        self.statistics = statistics
        self.tokenCount = tokenCount
        self.sanitized = sanitized
        self.originalLength = originalLength
        self.processedLength = processedLength
    }
}

public struct TextSanitizationRule: Sendable, Hashable, Codable {
    public let ruleID: String
    public let pattern: String
    public let replacement: String

    public init(ruleID: String, pattern: String, replacement: String) {
        self.ruleID = ruleID
        self.pattern = pattern
        self.replacement = replacement
    }
}

public struct TextPreprocessingConfiguration: Sendable, Hashable, Codable {
    public struct TokenizerPolicyConfiguration: Sendable, Hashable, Codable {
        public let tokenizationPolicy: TokenizationPolicy

        public init(tokenizationPolicy: TokenizationPolicy = TextPreprocessingConfiguration.defaultTokenizationPolicy) {
            self.tokenizationPolicy = tokenizationPolicy
        }

        public static var ingestDefault: TokenizerPolicyConfiguration {
            TokenizerPolicyConfiguration(tokenizationPolicy: TextPreprocessingConfiguration.defaultTokenizationPolicy)
        }
    }

    public struct SanitizerPolicyConfiguration: Sendable, Hashable, Codable {
        public let rules: [TextSanitizationRule]
        public let preserveParagraphBoundaries: Bool

        public init(
            rules: [TextSanitizationRule] = [],
            preserveParagraphBoundaries: Bool = true
        ) {
            self.rules = rules
            self.preserveParagraphBoundaries = preserveParagraphBoundaries
        }

        public static var ingestDefault: SanitizerPolicyConfiguration {
            SanitizerPolicyConfiguration(
                rules: [],
                preserveParagraphBoundaries: true
            )
        }
    }

    public let normalizationForm: UnicodeForm
    public let boundaryType: BoundaryType
    public let tokenizerPolicyConfiguration: TokenizerPolicyConfiguration
    public let sanitizerPolicyConfiguration: SanitizerPolicyConfiguration

    public init(
        normalizationForm: UnicodeForm = .nfc,
        boundaryType: BoundaryType = .word,
        tokenizerPolicyConfiguration: TokenizerPolicyConfiguration = .ingestDefault,
        sanitizerPolicyConfiguration: SanitizerPolicyConfiguration = .ingestDefault
    ) {
        self.normalizationForm = normalizationForm
        self.boundaryType = boundaryType
        self.tokenizerPolicyConfiguration = tokenizerPolicyConfiguration
        self.sanitizerPolicyConfiguration = sanitizerPolicyConfiguration
    }

    public init(
        normalizationForm: UnicodeForm = .nfc,
        boundaryType: BoundaryType = .word,
        tokenizationPolicy: TokenizationPolicy? = nil,
        sanitizationRules: [TextSanitizationRule] = [],
        preserveParagraphBoundaries: Bool = true
    ) {
        self.init(
            normalizationForm: normalizationForm,
            boundaryType: boundaryType,
            tokenizerPolicyConfiguration: TokenizerPolicyConfiguration(
                tokenizationPolicy: tokenizationPolicy ?? Self.defaultTokenizationPolicy
            ),
            sanitizerPolicyConfiguration: SanitizerPolicyConfiguration(
                rules: sanitizationRules,
                preserveParagraphBoundaries: preserveParagraphBoundaries
            )
        )
    }

    public static var defaultTokenizationPolicy: TokenizationPolicy {
        TokenizationPolicy(
            tokenizerHash: "canonical-simple-word",
            maxLength: 8192,
            padding: .none,
            truncation: .none
        )
    }

    public static var ingestDefault: TextPreprocessingConfiguration {
        TextPreprocessingConfiguration(
            normalizationForm: .nfc,
            boundaryType: .word,
            tokenizerPolicyConfiguration: .ingestDefault,
            sanitizerPolicyConfiguration: .ingestDefault
        )
    }

    public var tokenizationPolicy: TokenizationPolicy? {
        tokenizerPolicyConfiguration.tokenizationPolicy
    }

    public var sanitizationRules: [TextSanitizationRule] {
        sanitizerPolicyConfiguration.rules
    }

    public var preserveParagraphBoundaries: Bool {
        sanitizerPolicyConfiguration.preserveParagraphBoundaries
    }

    public func tokenizerPolicyFingerprint(sourceType: ContextSourceComponent.SourceType) -> String {
        let policy = tokenizerPolicyConfiguration.tokenizationPolicy
        return Self.stableDigest([
            "sourceType:\(sourceType.rawValue)",
            "tokenizerHash:\(policy.tokenizerHash)",
            "maxLength:\(policy.maxLength)",
            "padding:\(String(describing: policy.padding))",
            "truncation:\(String(describing: policy.truncation))"
        ])
    }

    public func sanitizerPolicyFingerprint(sourceType: ContextSourceComponent.SourceType) -> String {
        let canonicalRules = sanitizerPolicyConfiguration.rules
            .sorted {
                if $0.ruleID != $1.ruleID { return $0.ruleID < $1.ruleID }
                if $0.pattern != $1.pattern { return $0.pattern < $1.pattern }
                return $0.replacement < $1.replacement
            }
            .map { "\($0.ruleID):\($0.pattern):\($0.replacement)" }
            .joined(separator: "|")

        return Self.stableDigest([
            "sourceType:\(sourceType.rawValue)",
            "preserveParagraphBoundaries:\(sanitizerPolicyConfiguration.preserveParagraphBoundaries)",
            "rules:\(canonicalRules)"
        ])
    }

    public func preprocessingPolicyFingerprint(sourceType: ContextSourceComponent.SourceType) -> String {
        Self.stableDigest([
            "sourceType:\(sourceType.rawValue)",
            "normalizationForm:\(normalizationForm.rawValue)",
            "boundaryType:\(boundaryType.rawValue)",
            "tokenizerPolicy:\(tokenizerPolicyFingerprint(sourceType: sourceType))",
            "sanitizerPolicy:\(sanitizerPolicyFingerprint(sourceType: sourceType))"
        ])
    }

    private static func stableDigest(_ parts: [String]) -> String {
        let data = Data(parts.joined(separator: "|").utf8)
        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
}

public enum TextPreprocessingError: Error, Sendable, Equatable {
    case capsuleNotAvailable(reason: String)
    case normalizationFailed(String)
    case boundaryDetectionFailed(String)
    case caseFoldingFailed(String)
    case diacriticStrippingFailed(String)
    case sanitizationFailed(String)
    case statisticsGenerationFailed(String)
    case invalidInput(String)
    
    public var errorCode: String {
        switch self {
        case .capsuleNotAvailable: return "TXT_CAPSULE_UNAVAILABLE"
        case .normalizationFailed: return "TXT_NORMALIZATION_FAILED"
        case .boundaryDetectionFailed: return "TXT_BOUNDARY_FAILED"
        case .caseFoldingFailed: return "TXT_CASE_FOLD_FAILED"
        case .diacriticStrippingFailed: return "TXT_DIACRITIC_FAILED"
        case .sanitizationFailed: return "TXT_SANITIZATION_FAILED"
        case .statisticsGenerationFailed: return "TXT_STATS_FAILED"
        case .invalidInput: return "TXT_INVALID_INPUT"
        }
    }
}

public actor TextPreprocessingSystem {
    private static let logger = Logger(
        subsystem: "com.anigma.ContextumModule",
        category: "TextPreprocessingSystem"
    )
    private let useCapsuleFallback: Bool
    
    public var isCapsuleAvailable: Bool {
        false
    }
    
    public init(useCapsuleFallback: Bool = true) {
        self.useCapsuleFallback = useCapsuleFallback
        if useCapsuleFallback {
            Self.logger.warning(
                "Using Foundation fallback implementations for text preprocessing; capsule-backed preprocessing is unavailable"
            )
        }
    }
    
    public func normalizeText(_ text: String, form: UnicodeForm = .default) -> String {
        guard !text.isEmpty else { return text }
        
        return fallbackNormalize(text, form: form)
    }
    
    private func fallbackNormalize(_ text: String, form: UnicodeForm) -> String {
        switch form {
        case .nfc:
            return text.precomposedStringWithCanonicalMapping
        case .nfd:
            return text.decomposedStringWithCanonicalMapping
        case .nfkc:
            return text.precomposedStringWithCompatibilityMapping
        case .nfkd:
            return text.decomposedStringWithCompatibilityMapping
        case .none:
            return text
        }
    }
    
    public func detectBoundaries(_ text: String, type: BoundaryType = .default) -> [TextBoundary] {
        guard !text.isEmpty else { return [] }
        return fallbackDetectBoundaries(text, type: type)
    }
    
    private func fallbackDetectBoundaries(_ text: String, type: BoundaryType) -> [TextBoundary] {
        switch type {
        case .character:
            var boundaries: [TextBoundary] = []
            var offset = 0
            for char in text {
                let charLength = String(char).utf8.count
                boundaries.append(TextBoundary(offset: offset, length: charLength, type: type))
                offset += charLength
            }
            return boundaries
            
        case .grapheme:
            var boundaries: [TextBoundary] = []
            var offset = 0
            var currentIndex = text.startIndex
            
            while currentIndex < text.endIndex {
                let nextIndex = text.index(after: currentIndex)
                let length = text[currentIndex..<nextIndex].utf8.count
                boundaries.append(TextBoundary(offset: offset, length: length, type: type))
                offset += length
                currentIndex = nextIndex
            }
            return boundaries
            
        case .word:
            var boundaries: [TextBoundary] = []
            text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { _, range, _, _ in
                let offset = text[..<range.lowerBound].utf8.count
                let length = text[range].utf8.count
                boundaries.append(TextBoundary(offset: offset, length: length, type: type))
            }
            return boundaries
            
        case .sentence:
            var boundaries: [TextBoundary] = []
            text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .bySentences) { _, range, _, _ in
                let offset = text[..<range.lowerBound].utf8.count
                let length = text[range].utf8.count
                boundaries.append(TextBoundary(offset: offset, length: length, type: type))
            }
            return boundaries
            
        case .line:
            var boundaries: [TextBoundary] = []
            text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byLines) { _, range, _, _ in
                let offset = text[..<range.lowerBound].utf8.count
                let length = text[range].utf8.count
                boundaries.append(TextBoundary(offset: offset, length: length, type: type))
            }
            return boundaries
        }
    }
    
    public func foldCase(_ text: String, locale: String? = nil) -> String {
        guard !text.isEmpty else { return text }
        
        return fallbackFoldCase(text, locale: locale)
    }
    
    private func fallbackFoldCase(_ text: String, locale: String?) -> String {
        if let locale = locale {
            return text.lowercased(with: Locale(identifier: locale))
        }
        return text.lowercased()
    }
    
    public func stripDiacritics(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        return fallbackStripDiacritics(text)
    }
    
    private func fallbackStripDiacritics(_ text: String) -> String {
        return text.applyingTransform(.stripCombiningMarks, reverse: false) ?? text
    }
    
    public func preprocessForStorage(_ text: String, configuration: TextPreprocessingConfiguration = .ingestDefault) -> PreprocessedText {
        let originalLength = text.utf8.count
        
        let normalizedText = normalizeText(text, form: configuration.normalizationForm)
        let sanitizedText = sanitizeForStorage(normalizedText, configuration: configuration)
        let sanitized = sanitizedText != normalizedText
        let finalText = normalizeText(sanitizedText, form: configuration.normalizationForm)
        let boundaries = detectBoundaries(finalText, type: configuration.boundaryType)
        let statistics = generateStatistics(finalText)
        let tokenCount = tokenCount(
            for: finalText,
            policy: configuration.tokenizerPolicyConfiguration.tokenizationPolicy
        )
        
        return PreprocessedText(
            normalizedText: finalText,
            boundaries: boundaries,
            statistics: statistics,
            tokenCount: tokenCount,
            sanitized: sanitized,
            originalLength: originalLength,
            processedLength: finalText.utf8.count
        )
    }
    
    public func tokenCount(for text: String, policy: TokenizationPolicy? = nil) -> Int {
        guard !text.isEmpty else { return 0 }
        let effectivePolicy = policy ?? TextPreprocessingConfiguration.defaultTokenizationPolicy
        return ContextTokenizer.tokenCount(in: text, policy: effectivePolicy)
    }

    private func sanitizeForStorage(_ text: String, configuration: TextPreprocessingConfiguration) -> String {
        let rules = configuration.sanitizerPolicyConfiguration.rules.map {
            ContextSanitizer.Rule(
                ruleID: $0.ruleID,
                pattern: $0.pattern,
                replacement: $0.replacement
            )
        }
        let sanitizerConfiguration = ContextSanitizer.StorageConfiguration(
            rules: rules,
            preserveParagraphBoundaries: configuration.sanitizerPolicyConfiguration.preserveParagraphBoundaries
        )
        return ContextSanitizer.sanitizeForStorage(text, configuration: sanitizerConfiguration)
    }
    
    public func generateStatistics(_ text: String) -> TextStatistics {
        let byteCount = text.utf8.count
        let characterCount = text.count
        
        let graphemeBoundaries = detectBoundaries(text, type: .grapheme)
        let graphemeCount = graphemeBoundaries.count
        
        let wordBoundaries = detectBoundaries(text, type: .word)
        let wordCount = wordBoundaries.count
        
        let sentenceBoundaries = detectBoundaries(text, type: .sentence)
        let sentenceCount = sentenceBoundaries.count
        
        let lineBoundaries = detectBoundaries(text, type: .line)
        let lineCount = max(1, lineBoundaries.count)
        
        return TextStatistics(
            byteCount: byteCount,
            characterCount: characterCount,
            graphemeCount: graphemeCount,
            wordCount: wordCount,
            sentenceCount: sentenceCount,
            lineCount: lineCount
        )
    }
    
    public func validateUTF8(_ text: String) -> Bool {
        return text.data(using: .utf8) != nil
    }
    
    public func getTextStats(_ text: String) -> TextStatistics {
        return generateStatistics(text)
    }
    
    public func foldToASCII(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        return fallbackFoldToASCII(text)
    }
    
    private func fallbackFoldToASCII(_ text: String) -> String {
        var result = text
        result = result.folding(options: .diacriticInsensitive, locale: .current)
        result = result.lowercased()
        
        var asciiChars: [Character] = []
        for char in result {
            if char.isASCII {
                asciiChars.append(char)
            } else if char == " " || char == "-" || char == "_" {
                asciiChars.append(char)
            }
        }
        
        return String(asciiChars)
    }
}
