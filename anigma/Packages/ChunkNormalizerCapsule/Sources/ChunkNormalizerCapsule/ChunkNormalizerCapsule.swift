import Foundation
import CapsuleCore
import TelemetryCore
import PDFExporterKit
import TextChunkingCapsule

/// A capsule that normalizes chunk content for deterministic book export.
/// Extends the patterns from TextChunkingCapsule with book-specific normalization rules.
public actor ChunkNormalizerCapsule: IdentifiableCapsule {
    /// Unique capsule identifier
    public nonisolated let id: CapsuleID
    
    /// Capsule configuration
    private let config: ChunkNormalizerConfig
    
    /// Diagnostics collector
    private let diagnostics: DiagnosticsCollector
    
    /// Telemetry service
    private let telemetry: TelemetryService
    
    /// Cache for normalized chunks (content hash -> normalized content)
    private var cache: [String: NormalizedChunk]
    
    /// Statistics
    private var stats: ProcessingStats
    
    /// Initializes the chunk normalizer capsule
    public init(
        id: CapsuleID = CapsuleID(domain: "pdf.export", name: "chunk-normalizer"),
        config: ChunkNormalizerConfig = .default,
        diagnostics: DiagnosticsCollector = .init(),
        telemetry: TelemetryService = .shared
    ) {
        self.id = id
        self.config = config
        self.diagnostics = diagnostics
        self.telemetry = telemetry
        self.cache = [:]
        self.stats = ProcessingStats()
    }
    
    /// Normalizes raw chunk content for deterministic book export
    public func normalize(
        chunks: [RawChunk],
        strictMode: Bool = true
    ) async throws -> (ChunkSet, CapsuleReceipt) {
        let span = telemetry.startSpan(
            name: "chunk_normalizer.normalize",
            attributes: [
                "chunk_count": chunks.count,
                "strict_mode": strictMode,
                "config_hash": configHash()
            ]
        )
        
        defer {
            span.end(attributes: [
                "processed_chunks": stats.processedChunks,
                "cached_chunks": stats.cachedChunks,
                "failed_chunks": stats.failedChunks
            ])
        }
        
        do {
            // Process chunks in batches for performance
            let batchSize = config.performance.batchSize
            var normalizedChunks: [NormalizedChunk] = []
            var processingErrors: [ChunkProcessingError] = []
            
            for batchStart in stride(from: 0, to: chunks.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, chunks.count)
                let batch = Array(chunks[batchStart..<batchEnd])
                
                let (batchResults, batchErrors) = await processBatch(
                    chunks: batch,
                    strictMode: strictMode
                )
                
                normalizedChunks.append(contentsOf: batchResults)
                processingErrors.append(contentsOf: batchErrors)
            }
            
            // Check for processing errors
            if !processingErrors.isEmpty {
                if strictMode {
                    throw CapsuleError.operationFailed(
                        "Failed to normalize \(processingErrors.count) chunks",
                        underlyingErrors: processingErrors.map { $0.asCapsuleError() }
                    )
                } else {
                    diagnostics.record(
                        .warning,
                        message: "\(processingErrors.count) chunks failed normalization",
                        metadata: ["errors": processingErrors.map { $0.description }]
                    )
                }
            }
            
            // Create ChunkSet
            let chunkSet = ChunkSet(
                chunks: normalizedChunks,
                createdAt: Date()
            )
            
            // Generate receipt
            let receipt = try generateReceipt(
                inputChunks: chunks,
                outputChunks: normalizedChunks,
                errors: processingErrors,
                strictMode: strictMode
            )
            
            diagnostics.record(
                .info,
                message: "Normalized \(chunks.count) chunks",
                metadata: [
                    "successful": normalizedChunks.count,
                    "failed": processingErrors.count,
                    "cached": stats.cachedChunks
                ]
            )
            
            return (chunkSet, receipt)
            
        } catch {
            span.recordError(error)
            diagnostics.record(.error, message: "Chunk normalization failed", error: error)
            throw error
        }
    }
    
    /// Processes a batch of chunks
    private func processBatch(
        chunks: [RawChunk],
        strictMode: Bool
    ) async -> ([NormalizedChunk], [ChunkProcessingError]) {
        if config.performance.useParallelProcessing {
            return await withTaskGroup(
                of: (NormalizedChunk?, ChunkProcessingError?).self
            ) { group in
                for chunk in chunks {
                    group.addTask {
                        await self.processChunk(chunk, strictMode: strictMode)
                    }
                }
                
                var normalizedChunks: [NormalizedChunk] = []
                var errors: [ChunkProcessingError] = []
                
                for await (chunk, error) in group {
                    if let chunk = chunk {
                        normalizedChunks.append(chunk)
                    }
                    if let error = error {
                        errors.append(error)
                    }
                }
                
                return (normalizedChunks, errors)
            }
        } else {
            // Sequential processing
            var normalizedChunks: [NormalizedChunk] = []
            var errors: [ChunkProcessingError] = []
            
            for chunk in chunks {
                let (normalizedChunk, error) = await processChunk(chunk, strictMode: strictMode)
                if let normalizedChunk = normalizedChunk {
                    normalizedChunks.append(normalizedChunk)
                }
                if let error = error {
                    errors.append(error)
                }
            }
            
            return (normalizedChunks, errors)
        }
    }
    
    /// Processes a single chunk
    private func processChunk(
        _ chunk: RawChunk,
        strictMode: Bool
    ) async -> (NormalizedChunk?, ChunkProcessingError?) {
        // Check cache first
        if config.performance.cacheResults,
           let cached = cache[chunk.contentHash] {
            stats.cachedChunks += 1
            return (cached, nil)
        }
        
        do {
            let normalized = try normalizeChunkContent(chunk, strictMode: strictMode)
            
            // Update cache
            if config.performance.cacheResults,
               cache.count < config.performance.maxCacheSize {
                cache[chunk.contentHash] = normalized
            }
            
            stats.processedChunks += 1
            return (normalized, nil)
            
        } catch let error as ChunkProcessingError {
            stats.failedChunks += 1
            return (nil, error)
        } catch {
            stats.failedChunks += 1
            return (nil, ChunkProcessingError(
                chunkID: chunk.id,
                errorType: .internalError,
                message: "Unexpected error: \(error)",
                recoverable: !strictMode
            ))
        }
    }
    
    /// Normalizes the content of a single chunk
    private func normalizeChunkContent(
        _ chunk: RawChunk,
        strictMode: Bool
    ) throws -> NormalizedChunk {
        var content = chunk.content
        
        // 1. Unicode normalization
        content = try applyUnicodeNormalization(content, strictMode: strictMode)
        
        // 2. Line ending normalization
        content = try normalizeLineEndings(content, strictMode: strictMode)
        
        // 3. Whitespace normalization
        content = try normalizeWhitespace(content, strictMode: strictMode)
        
        // 4. Character validation
        try validateCharacters(content, strictMode: strictMode)
        
        // 5. Paragraph detection and normalization
        let paragraphs = try detectParagraphs(content, strictMode: strictMode)
        
        // Create normalized chunk
        return NormalizedChunk(
            id: chunk.id,
            originalHash: chunk.contentHash,
            normalizedHash: computeContentHash(content),
            content: content,
            paragraphs: paragraphs,
            metadata: chunk.metadata.merging([
                "normalized_at": Date().ISO8601Format(),
                "normalization_form": config.unicodeNormalizationForm.rawValue,
                "line_ending_policy": config.lineEndingPolicy.rawValue
            ]) { original, _ in original },
            createdAt: Date()
        )
    }
    
    /// Applies Unicode normalization to content
    private func applyUnicodeNormalization(
        _ content: String,
        strictMode: Bool
    ) throws -> String {
        let normalized: String
        
        switch config.unicodeNormalizationForm {
        case .nfc:
            normalized = content.precomposedStringWithCanonicalMapping
        case .nfd:
            normalized = content.decomposedStringWithCanonicalMapping
        case .nfkc:
            normalized = content.precomposedStringWithCompatibilityMapping
        case .nfkd:
            normalized = content.decomposedStringWithCompatibilityMapping
        }
        
        // Check if normalization changed the content
        if normalized != content {
            if config.strictMode.failOnMissingNormalization && strictMode {
                throw ChunkProcessingError(
                    chunkID: "unknown", // We don't have chunk ID here
                    errorType: .normalizationError,
                    message: "Content requires Unicode normalization",
                    recoverable: false
                )
            }
        }
        
        return normalized
    }
    
    /// Normalizes line endings
    private func normalizeLineEndings(
        _ content: String,
        strictMode: Bool
    ) throws -> String {
        let targetEnding: String
        
        switch config.lineEndingPolicy {
        case .lf:
            targetEnding = "\n"
        case .crlf:
            targetEnding = "\r\n"
        case .cr:
            targetEnding = "\r"
        case .preserve:
            return content  // No normalization
        }
        
        // Detect mixed line endings
        let hasCR = content.contains("\r")
        let hasLF = content.contains("\n")
        let hasCRLF = content.contains("\r\n")
        
        let lineEndingCount = [hasCR, hasLF, hasCRLF].filter { $0 }.count
        
        if lineEndingCount > 1 {
            if config.strictMode.failOnMixedLineEndings && strictMode {
                throw ChunkProcessingError(
                    chunkID: "unknown",
                    errorType: .lineEndingError,
                    message: "Mixed line endings detected",
                    recoverable: false
                )
            }
        }
        
        // Normalize line endings
        var normalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        
        if config.lineEndingPolicy != .lf {
            normalized = normalized.replacingOccurrences(of: "\n", with: targetEnding)
        }
        
        return normalized
    }
    
    /// Normalizes whitespace
    private func normalizeWhitespace(
        _ content: String,
        strictMode: Bool
    ) throws -> String {
        var normalized = content
        
        // Normalize various space characters to regular space
        if config.whitespaceRules.normalizeSpaceCharacters {
            let spaceCharacters: [Character] = [
                "\u{00A0}", // NO-BREAK SPACE
                "\u{2000}", // EN QUAD
                "\u{2001}", // EM QUAD
                "\u{2002}", // EN SPACE
                "\u{2003}", // EM SPACE
                "\u{2004}", // THREE-PER-EM SPACE
                "\u{2005}", // FOUR-PER-EM SPACE
                "\u{2006}", // SIX-PER-EM SPACE
                "\u{2007}", // FIGURE SPACE
                "\u{2008}", // PUNCTUATION SPACE
                "\u{2009}", // THIN SPACE
                "\u{200A}", // HAIR SPACE
                "\u{202F}", // NARROW NO-BREAK SPACE
                "\u{205F}", // MEDIUM MATHEMATICAL SPACE
                "\u{3000}", // IDEOGRAPHIC SPACE
            ]
            
            for spaceChar in spaceCharacters {
                normalized = normalized.replacingOccurrences(of: String(spaceChar), with: " ")
            }
        }
        
        // Normalize non-breaking spaces
        if config.whitespaceRules.normalizeNonBreakingSpaces {
            normalized = normalized.replacingOccurrences(of: "\u{00A0}", with: " ")
        }
        
        // Collapse multiple spaces
        if config.whitespaceRules.collapseMultipleSpaces {
            while normalized.contains("  ") {
                normalized = normalized.replacingOccurrences(of: "  ", with: " ")
            }
        }
        
        // Trim whitespace
        if config.whitespaceRules.trimWhitespace {
            normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return normalized
    }
    
    /// Validates characters in content
    private func validateCharacters(
        _ content: String,
        strictMode: Bool
    ) throws {
        for char in content {
            // Check control characters
            if char.isASCII && char.isControl {
                if !config.characterValidation.allowControlCharacters ||
                   !config.characterValidation.allowedControlCharacters.contains(char) {
                    if config.strictMode.failOnInvalidCharacters && strictMode {
                        throw ChunkProcessingError(
                            chunkID: "unknown",
                            errorType: .invalidCharacter,
                            message: "Invalid control character: U+\(String(format: "%04X", char.unicodeScalars.first!.value))",
                            recoverable: false
                        )
                    }
                }
            }
            
            // Check non-printable characters
            if !char.isPrintable && !config.characterValidation.allowNonPrintable {
                if config.strictMode.failOnInvalidCharacters && strictMode {
                    throw ChunkProcessingError(
                        chunkID: "unknown",
                        errorType: .invalidCharacter,
                        message: "Non-printable character: U+\(String(format: "%04X", char.unicodeScalars.first!.value))",
                        recoverable: false
                    )
                }
            }
            
            // Check code point limit
            if let maxCodePoint = config.characterValidation.maximumCodePoint,
               let scalar = char.unicodeScalars.first,
               scalar.value > maxCodePoint {
                if config.strictMode.failOnInvalidCharacters && strictMode {
                    throw ChunkProcessingError(
                        chunkID: "unknown",
                        errorType: .invalidCharacter,
                        message: "Code point exceeds maximum: U+\(String(format: "%04X", scalar.value)) > U+\(String(format: "%04X", maxCodePoint))",
                        recoverable: false
                    )
                }
            }
        }
    }
    
    /// Detects and normalizes paragraphs
    private func detectParagraphs(
        _ content: String,
        strictMode: Bool
    ) throws -> [Paragraph] {
        var paragraphs: [Paragraph] = []
        var currentParagraph = ""
        var lineNumber = 1
        var inParagraph = false
        
        let lines = content.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let isBlank = line.trimmingCharacters(in: .whitespaces).isEmpty
            
            if config.paragraphDetection.blankLinesAsBreaks && isBlank {
                // Blank line ends current paragraph
                if !currentParagraph.isEmpty {
                    let paragraph = try createParagraph(
                        content: currentParagraph,
                        lineNumber: lineNumber,
                        strictMode: strictMode
                    )
                    paragraphs.append(paragraph)
                    currentParagraph = ""
                    inParagraph = false
                }
                lineNumber = index + 2 // Next line after blank
            } else if config.paragraphDetection.paragraphSeparators.contains(where: { line.contains($0) }) {
                // Explicit paragraph separator
                if !currentParagraph.isEmpty {
                    let paragraph = try createParagraph(
                        content: currentParagraph,
                        lineNumber: lineNumber,
                        strictMode: strictMode
                    )
                    paragraphs.append(paragraph)
                }
                currentParagraph = line
                inParagraph = true
                lineNumber = index + 1
            } else {
                // Continue current paragraph
                if inParagraph {
                    currentParagraph += "\n" + line
                } else {
                    currentParagraph = line
                    inParagraph = true
                    lineNumber = index + 1
                }
            }
        }
        
        // Add final paragraph
        if !currentParagraph.isEmpty {
            let paragraph = try createParagraph(
                content: currentParagraph,
                lineNumber: lineNumber,
                strictMode: strictMode
            )
            paragraphs.append(paragraph)
        }
        
        return paragraphs
    }
    
    /// Creates a paragraph from content
    private func createParagraph(
        content: String,
        lineNumber: Int,
        strictMode: Bool
    ) throws -> Paragraph {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check minimum length
        if trimmed.count < config.paragraphDetection.minimumParagraphLength {
            if config.strictMode.failOnParagraphIssues && strictMode {
                throw ChunkProcessingError(
                    chunkID: "unknown",
                    errorType: .paragraphError,
                    message: "Paragraph too short: \(trimmed.count) characters (minimum: \(config.paragraphDetection.minimumParagraphLength))",
                    recoverable: false
                )
            }
        }
        
        // Check maximum length
        if let maxLength = config.paragraphDetection.maximumParagraphLength,
           trimmed.count > maxLength {
            if config.strictMode.failOnParagraphIssues && strictMode {
                throw ChunkProcessingError(
                    chunkID: "unknown",
                    errorType: .paragraphError,
                    message: "Paragraph too long: \(trimmed.count) characters (maximum: \(maxLength))",
                    recoverable: false
                )
            }
        }
        
        return Paragraph(
            content: trimmed,
            lineNumber: lineNumber,
            characterCount: trimmed.count,
            wordCount: trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count
        )
    }
    
    /// Generates a capsule receipt
    private func generateReceipt(
        inputChunks: [RawChunk],
        outputChunks: [NormalizedChunk],
        errors: [ChunkProcessingError],
        strictMode: Bool
    ) throws -> CapsuleReceipt {
        let inputHashes = inputChunks.map { $0.contentHash }
        let outputHashes = outputChunks.map { $0.normalizedHash }
        
        return CapsuleReceipt(
            capsuleID: id,
            operation: "normalize",
            inputHashes: inputHashes,
            outputHashes: outputHashes,
            metadata: [
                "chunk_count": inputChunks.count,
                "normalized_count": outputChunks.count,
                "error_count": errors.count,
                "strict_mode": strictMode,
                "config_hash": configHash(),
                "unicode_normalization": config.unicodeNormalizationForm.rawValue,
                "line_ending_policy": config.lineEndingPolicy.rawValue,
                "cache_hits": stats.cachedChunks,
                "cache_size": cache.count
            ],
            createdAt: Date()
        )
    }
    
    /// Computes a hash of the configuration
    private func configHash() -> String {
        let configData = try? JSONEncoder().encode(config)
        return configData?.base64EncodedString() ?? "unknown"
    }
    
    /// Computes a content hash
    private func computeContentHash(_ content: String) -> String {
        let data = Data(content.utf8)
        var hash = 5381
        for byte in data {
            hash = ((hash << 5) &+ hash) &+ Int(byte)
        }
        return String(format: "%016x", hash)
    }
}

// MARK: - Supporting Types

/// Raw chunk input
public struct RawChunk: Sendable, Codable {
    public let id: String
    public let content: String
    public let contentHash: String
    public let metadata: [String: String]
    
    public init(
        id: String,
        content: String,
        contentHash: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.content = content
        self.contentHash = contentHash ?? Self.computeHash(content)
        self.metadata = metadata
    }
    
    private static func computeHash(_ content: String) -> String {
        let data = Data(content.utf8)
        var hash = 5381
        for byte in data {
            hash = ((hash << 5) &+ hash) &+ Int(byte)
        }
        return String(format: "%016x", hash)
    }
}

/// Normalized chunk output
public struct NormalizedChunk: Sendable, Codable {
    public let id: String
    public let originalHash: String
    public let normalizedHash: String
    public let content: String
    public let paragraphs: [Paragraph]
    public let metadata: [String: String]
    public let createdAt: Date
    
    public init(
        id: String,
        originalHash: String,
        normalizedHash: String,
        content: String,
        paragraphs: [Paragraph] = [],
        metadata: [String: String] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.originalHash = originalHash
        self.normalizedHash = normalizedHash
        self.content = content
        self.paragraphs = paragraphs
        self.metadata = metadata
        self.createdAt = createdAt
    }
}

/// Paragraph within a chunk
public struct Paragraph: Sendable, Codable {
    public let content: String
    public let lineNumber: Int
    public let characterCount: Int
    public let wordCount: Int
    
    public init(
        content: String,
        lineNumber: Int,
        characterCount: Int,
        wordCount: Int
    ) {
        self.content = content
        self.lineNumber = lineNumber
        self.characterCount = characterCount
        self.wordCount = wordCount
    }
}

/// Chunk set (collection of normalized chunks)
public struct ChunkSet: Sendable, Codable {
    public let chunks: [NormalizedChunk]
    public let createdAt: Date
    
    public init(
        chunks: [NormalizedChunk],
        createdAt: Date = Date()
    ) {
        self.chunks = chunks
        self.createdAt = createdAt
    }
    
    /// Content hash of the entire set
    public var contentHash: String {
        let chunkHashes = chunks.map { $0.normalizedHash }.sorted()
        let combined = chunkHashes.joined(separator: "|")
        var hash = 5381
        for char in combined.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(char)
        }
        return String(format: "%016x", hash)
    }
}

/// Chunk processing error
public struct ChunkProcessingError: Error, Sendable, CustomStringConvertible {
    public enum ErrorType: String, Sendable, Codable {
        case normalizationError = "normalization_error"
        case lineEndingError = "line_ending_error"
        case invalidCharacter = "invalid_character"
        case paragraphError = "paragraph_error"
        case internalError = "internal_error"
    }
    
    public let chunkID: String
    public let errorType: ErrorType
    public let message: String
    public let recoverable: Bool
    
    public init(
        chunkID: String,
        errorType: ErrorType,
        message: String,
        recoverable: Bool = true
    ) {
        self.chunkID = chunkID
        self.errorType = errorType
        self.message = message
        self.recoverable = recoverable
    }
    
    public var description: String {
        return "Chunk \(chunkID): \(errorType.rawValue) - \(message)"
    }
    
    public func asCapsuleError() -> CapsuleCore.Error {
        return CapsuleCore.Error(
            code: "CHUNK_NORMALIZER_\(errorType.rawValue.uppercased())",
            message: message,
            metadata: ["chunk_id": chunkID, "recoverable": recoverable]
        )
    }
}

/// Processing statistics
private struct ProcessingStats: Sendable {
    var processedChunks: Int = 0
    var cachedChunks: Int = 0
    var failedChunks: Int = 0
}

// MARK: - Character Extensions

extension Character {
    var isPrintable: Bool {
        guard let scalar = self.unicodeScalars.first else { return false }
        let category = scalar.properties.generalCategory
        return !category.isControl && !category.isFormat && !category.isPrivateUse
    }
    
    var isControl: Bool {
        guard let scalar = self.unicodeScalars.first else { return false }
        return scalar.properties.generalCategory.isControl
    }
}

extension Unicode.GeneralCategory {
    var isControl: Bool {
        return self == .control || self == .format || self == .privateUse || self == .surrogate
    }
    
    var isFormat: Bool {
        return self == .format
    }
    
    var isPrivateUse: Bool {
        return self == .privateUse
    }
}
