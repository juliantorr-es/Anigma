import Foundation
import AnigmaPrimitives
import CapsuleCore
import TextPipelineCapsule

public enum UnicodeForm: UInt32, Sendable, CaseIterable {
    case none = 0
    case nfc = 1
    case nfd = 2
    case nfkc = 3
    case nfkd = 4
    
    public static var `default`: UnicodeForm { .nfc }
}

public enum BoundaryType: UInt32, Sendable, CaseIterable {
    case character = 0
    case grapheme = 1
    case word = 2
    case sentence = 3
    case line = 4
    
    public static var `default`: BoundaryType { .word }
}

public struct TextBoundary: Sendable, Equatable {
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
    public var sanitized: Bool
    public var originalLength: Int
    public var processedLength: Int
    
    public init(
        normalizedText: String,
        boundaries: [TextBoundary],
        statistics: TextStatistics,
        sanitized: Bool = false,
        originalLength: Int,
        processedLength: Int
    ) {
        self.normalizedText = normalizedText
        self.boundaries = boundaries
        self.statistics = statistics
        self.sanitized = sanitized
        self.originalLength = originalLength
        self.processedLength = processedLength
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
    private var textPipelineCapsule: TextPipelineCapsuleWrapper?
    private let useCapsuleFallback: Bool
    private var initializationError: TextPreprocessingError?
    
    public var isCapsuleAvailable: Bool {
        textPipelineCapsule != nil
    }
    
    public init(useCapsuleFallback: Bool = true) {
        self.useCapsuleFallback = useCapsuleFallback
        
        do {
            self.textPipelineCapsule = try TextPipelineCapsuleWrapper()
        } catch {
            self.initializationError = .capsuleNotAvailable(reason: "Failed to initialize TextPipelineCapsule: \(error.localizedDescription)")
            self.textPipelineCapsule = nil
        }
    }
    
    private func ensureCapsule() throws -> TextPipelineCapsuleWrapper {
        guard let capsule = textPipelineCapsule else {
            throw initializationError ?? TextPreprocessingError.capsuleNotAvailable(reason: "TextPipelineCapsule not initialized")
        }
        return capsule
    }
    
    public func normalizeText(_ text: String, form: UnicodeForm = .default) -> String {
        guard !text.isEmpty else { return text }
        
        guard let capsule = textPipelineCapsule else {
            return fallbackNormalize(text, form: form)
        }
        
        do {
            switch form {
            case .nfc:
                return try capsule.normalizeNFC(text)
            case .nfd:
                return try capsule.normalizeNFC(text).decomposedStringWithCanonicalMapping
            case .nfkc:
                return try capsule.normalizeNFC(text).precomposedStringWithCompatibilityMapping
            case .nfkd:
                return try capsule.normalizeNFC(text).decomposedStringWithCompatibilityMapping
            case .none:
                return text
            }
        } catch {
            return fallbackNormalize(text, form: form)
        }
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
            let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            var boundaries: [TextBoundary] = []
            var currentOffset = 0
            
            for word in words {
                let wordLength = word.utf8.count
                boundaries.append(TextBoundary(offset: currentOffset, length: wordLength, type: type))
                currentOffset += wordLength + 1
            }
            return boundaries
            
        case .sentence:
            let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n")).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            var boundaries: [TextBoundary] = []
            var currentOffset = 0
            
            for sentence in sentences {
                let sentenceLength = sentence.utf8.count
                boundaries.append(TextBoundary(offset: currentOffset, length: sentenceLength, type: type))
                currentOffset += sentenceLength + 1
            }
            return boundaries
            
        case .line:
            let lines = text.components(separatedBy: .newlines)
            var boundaries: [TextBoundary] = []
            var currentOffset = 0
            
            for line in lines {
                let lineLength = line.utf8.count
                boundaries.append(TextBoundary(offset: currentOffset, length: lineLength, type: type))
                currentOffset += lineLength + 1
            }
            return boundaries
        }
    }
    
    public func foldCase(_ text: String, locale: String? = nil) -> String {
        guard !text.isEmpty else { return text }
        
        if let capsule = textPipelineCapsule {
            do {
                return try capsule.toLowercase(text)
            } catch {
                // Fall through to Swift fallback
            }
        }
        
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
        
        if let capsule = textPipelineCapsule {
            do {
                return try capsule.stripDiacritics(text)
            } catch {
                // Fall through to Swift fallback
            }
        }
        
        return fallbackStripDiacritics(text)
    }
    
    private func fallbackStripDiacritics(_ text: String) -> String {
        return text.applyingTransform(.stripCombiningMarks, reverse: false) ?? text
    }
    
    public func preprocessForStorage(_ text: String) -> PreprocessedText {
        let originalLength = text.utf8.count
        
        let normalizedText = normalizeText(text, form: .nfc)
        let wordBoundaries = detectBoundaries(text, type: .word)
        let statistics = generateStatistics(text)
        
        let sanitizedText = sanitizeForStorage(text)
        let sanitized = sanitizedText != text
        let finalText = sanitized ? normalizeText(sanitizedText, form: .nfc) : normalizedText
        
        return PreprocessedText(
            normalizedText: finalText,
            boundaries: wordBoundaries,
            statistics: statistics,
            sanitized: sanitized,
            originalLength: originalLength,
            processedLength: finalText.utf8.count
        )
    }
    
    private func sanitizeForStorage(_ text: String) -> String {
        var result = text
        
        result = result.replacingOccurrences(of: "\0", with: "")
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")
        result = result.replacingOccurrences(of: "\t", with: " ")
        
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
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
        guard let capsule = textPipelineCapsule else {
            return text.data(using: .utf8) != nil
        }
        
        do {
            return try capsule.validateUTF8(text)
        } catch {
            return text.data(using: .utf8) != nil
        }
    }
    
    public func getTextStats(_ text: String) -> TextStatistics {
        return generateStatistics(text)
    }
    
    public func foldToASCII(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        
        if let capsule = textPipelineCapsule {
            do {
                return try capsule.foldToASCII(text)
            } catch {
                // Fall through to Swift fallback
            }
        }
        
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
