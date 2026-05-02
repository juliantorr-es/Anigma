//
//  TextChunkingSystem.swift
//  DiaplasionModule
//
//  Extracted from DiaplasionSystems.swift
//  System that chunks extracted text into semantic units.
//

import AnigmaCore
import Foundation
import AnigmaPrimitives
import TextChunkingCapsule

// MARK: - Text Chunking System

/// System that chunks extracted text into semantic units.
///
/// This system:
/// 1. Reads OCRResultComponent text
/// 2. Normalizes whitespace and removes obvious OCR artifacts
/// 3. Detects headings (ALL CAPS, short lines after blank lines)
/// 4. Splits into paragraphs
/// 5. Produces ChunkedTextComponent with typed chunks
///
/// **Input**: Entity with `OCRResultComponent`
/// **Output**: Adds `ChunkedTextComponent`
public struct TextChunkingSystem: System {
    public var name: String { "TextChunking" }

    /// Chunking strategy to use.
    public let strategy: ChunkingStrategy

    /// Maximum characters per chunk (for .fixedToken strategy).
    public let maxChunkSize: Int

    /// Minimum characters for a line to be considered a heading candidate.
    public let minHeadingLength: Int

    /// Maximum characters for a line to be considered a heading candidate.
    public let maxHeadingLength: Int

    public init(
        strategy: ChunkingStrategy = .paragraph,
        maxChunkSize: Int = 2000,
        minHeadingLength: Int = 3,
        maxHeadingLength: Int = 100
    ) {
        self.strategy = strategy
        self.maxChunkSize = maxChunkSize
        self.minHeadingLength = minHeadingLength
        self.maxHeadingLength = maxHeadingLength
    }

    public func update(world: World) async {
        // Query for entities with OCRResultComponent but no ChunkedTextComponent
        let documents = await world.query(OCRResultComponent.self)

        for (entity, ocrResult) in documents {
            // Skip if already chunked
            if await world.hasComponent(entity, ChunkedTextComponent.self) {
                continue
            }

            // Skip empty results
            guard !ocrResult.text.isEmpty else {
                logWarning("Skipping chunking for empty OCR result", category: "Diaplasion")
                continue
            }

            let chunks = await chunkText(ocrResult.text)

            let result = ChunkedTextComponent(
                chunks: chunks,
                strategy: strategy,
                totalTokens: nil // Could estimate: chunks.reduce(0) { $0 + ($1.tokenCount ?? 0) }
            )

            await world.addComponent(entity, result)
            logInfo("Chunked text into \(chunks.count) chunks", category: "Diaplasion")
        }
    }

    // MARK: - Private Implementation

    private func chunkText(_ text: String) async -> [TextChunk] {
        // Normalize text first
        let normalized = normalizeText(text)

        switch strategy {
        case .paragraph:
            return chunkByParagraph(normalized)
        case .sentence:
            return chunkBySentence(normalized)
        case .fixedToken:
            return await chunkUsingCapsule(normalized)
        case .page:
            // For page-based, we'd need page markers - fall back to paragraph
            return chunkByParagraph(normalized)
        case .semantic:
            // Semantic requires more advanced NLP - fall back to paragraph with heading detection
            return chunkByParagraph(normalized)
        }
    }

    /// Normalizes OCR text by cleaning up common artifacts.
    private func normalizeText(_ text: String) -> String {
        var result = text

        // Normalize line endings
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")

        // Remove excessive whitespace within lines (but preserve paragraph breaks)
        let lines = result.components(separatedBy: "\n")
        let cleanedLines = lines.map { line -> String in
            // Collapse multiple spaces to single space
            let collapsed = line.replacingOccurrences(
                of: "\\s+",
                with: " ",
                options: .regularExpression
            )
            return collapsed.trimmingCharacters(in: .whitespaces)
        }
        result = cleanedLines.joined(separator: "\n")

        // Collapse more than 2 consecutive newlines to 2
        result = result.replacingOccurrences(
            of: "\n{3,}",
            with: "\n\n",
            options: .regularExpression
        )

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Chunks text by paragraphs, detecting headings.
    private func chunkByParagraph(_ text: String) -> [TextChunk] {
        // Split on double newlines (paragraph boundaries)
        let paragraphs = text.components(separatedBy: "\n\n")

        var chunks: [TextChunk] = []

        for paragraph in paragraphs {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let chunkType = classifyParagraph(trimmed)
            let chunk = TextChunk(
                text: trimmed,
                chunkType: chunkType,
                pageNumber: nil,
                tokenCount: estimateTokenCount(trimmed)
            )
            chunks.append(chunk)
        }

        return chunks
    }

    /// Chunks text by sentences.
    private func chunkBySentence(_ text: String) -> [TextChunk] {
        // Simple sentence boundary detection
        // Split on sentence-ending punctuation followed by whitespace
        var chunks: [TextChunk] = []
        var currentSentence = ""
        var previousChar: Character = " "

        for char in text {
            currentSentence.append(char)

            // Check for sentence boundary: period/exclamation/question followed by space
            if (previousChar == "." || previousChar == "!" || previousChar == "?") && char.isWhitespace {
                let trimmed = currentSentence.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    let chunk = TextChunk(
                        text: trimmed,
                        chunkType: .paragraph,
                        pageNumber: nil,
                        tokenCount: estimateTokenCount(trimmed)
                    )
                    chunks.append(chunk)
                }
                currentSentence = ""
            }
            previousChar = char
        }

        // Don't forget the last sentence
        let trimmed = currentSentence.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let chunk = TextChunk(
                text: trimmed,
                chunkType: .paragraph,
                pageNumber: nil,
                tokenCount: estimateTokenCount(trimmed)
            )
            chunks.append(chunk)
        }

        return chunks
    }

    /// Chunks text using TextChunkingCapsule with content-defined boundaries.
    private func chunkUsingCapsule(_ text: String) async -> [TextChunk] {
        guard !text.isEmpty else { return [] }
        
        // Convert to UTF-8 data for byte-level chunking
        let data = Data(text.utf8)
        
        // Compute average bytes per character for this specific text
        // This gives us a better estimate than assuming 4 bytes per character
        let avgBytesPerChar = max(1, data.count / text.count)
        
        // Convert character-based maxChunkSize to byte-based target size
        let targetBytes = maxChunkSize * avgBytesPerChar
        
        // Ensure reasonable bounds for chunk sizes
        // Minimum chunk size: at least 64 bytes, but no larger than target/2
        let minBytes = max(64, targetBytes / 4)
        // Maximum chunk size: cap at 16KB to avoid overly large chunks
        let maxBytes = min(targetBytes * 2, 16384)
        
        let config = TextChunkingConfig(
            targetChunkSize: targetBytes,
            minChunkSize: minBytes,
            maxChunkSize: maxBytes,
            windowSize: 48,
            determinismTier: 1
        )
        
        do {
            // Use one-shot chunking
            let wrapper = try TextChunkingCapsuleWrapper(config: config)
            try await wrapper.processBytes(data)
            try await wrapper.finalize()
            
            // Extract chunks as Data slices
            let chunkData = try await wrapper.extractChunks(from: data)
            
            // Convert Data back to String chunks
            var chunks: [TextChunk] = []
            for chunk in chunkData {
                if let chunkString = String(data: chunk, encoding: .utf8) {
                    let trimmed = chunkString.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        let chunkType = classifyParagraph(trimmed)
                        let chunk = TextChunk(
                            text: trimmed,
                            chunkType: chunkType,
                            pageNumber: nil,
                            tokenCount: estimateTokenCount(trimmed)
                        )
                        chunks.append(chunk)
                    }
                } else {
                    // UTF-8 conversion failed, fall back to original method
                    return fallbackChunkByFixedSize(text)
                }
            }
            
            return chunks.isEmpty ? [TextChunk(
                text: text,
                chunkType: .paragraph,
                pageNumber: nil,
                tokenCount: estimateTokenCount(text)
            )] : chunks
            
        } catch {
            // Capsule failed, fall back to original method
            return fallbackChunkByFixedSize(text)
        }
    }
    
    /// Original fixed-size chunking method kept as fallback
    private func fallbackChunkByFixedSize(_ text: String) -> [TextChunk] {
        var chunks: [TextChunk] = []
        var remaining = text

        while !remaining.isEmpty {
            let endIndex: String.Index
            if remaining.count <= maxChunkSize {
                endIndex = remaining.endIndex
            } else {
                // Try to break at a paragraph or sentence boundary
                let searchEnd = remaining.index(remaining.startIndex, offsetBy: maxChunkSize)
                let searchRange = remaining.startIndex..<searchEnd

                if let paragraphBreak = remaining.range(of: "\n\n", options: .backwards, range: searchRange)?.lowerBound {
                    endIndex = paragraphBreak
                } else if let sentenceBreak = remaining.range(of: ". ", options: .backwards, range: searchRange)?.upperBound {
                    endIndex = sentenceBreak
                } else {
                    endIndex = searchEnd
                }
            }

            let chunkText = String(remaining[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunkText.isEmpty {
                let chunk = TextChunk(
                    text: chunkText,
                    chunkType: .paragraph,
                    pageNumber: nil,
                    tokenCount: estimateTokenCount(chunkText)
                )
                chunks.append(chunk)
            }

            remaining = String(remaining[endIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return chunks
    }

    /// Classifies a paragraph as heading, body, etc.
    private func classifyParagraph(_ text: String) -> ChunkType {
        let lineCount = text.components(separatedBy: "\n").count
        let length = text.count

        // Heading heuristics:
        // 1. Single line
        // 2. Reasonable length (not too long)
        // 3. ALL CAPS or Title Case
        // 4. Doesn't end with typical sentence punctuation

        guard lineCount == 1 else { return .paragraph }
        guard length >= minHeadingLength && length <= maxHeadingLength else { return .paragraph }

        // Check for ALL CAPS
        let uppercased = text.uppercased()
        if text == uppercased && text.range(of: "[a-zA-Z]", options: .regularExpression) != nil {
            return .heading
        }

        // Check for Title Case (most words start with uppercase)
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if words.count >= 2 && words.count <= 10 {
            let capitalizedCount = words.filter { word in
                guard let first = word.first else { return false }
                return first.isUppercase
            }.count

            if Double(capitalizedCount) / Double(words.count) >= 0.7 {
                // Check it doesn't end with sentence punctuation
                if !text.hasSuffix(".") && !text.hasSuffix(",") {
                    return .heading
                }
            }
        }

        // Check for numbered headings (e.g., "1. Introduction", "Chapter 1")
        if text.range(of: "^(Chapter|Section|Part|\\d+\\.?)\\s", options: .regularExpression) != nil {
            return .heading
        }

        return .paragraph
    }

    /// Estimates token count (rough approximation: ~4 chars per token).
    private func estimateTokenCount(_ text: String) -> Int {
        // This is a rough estimate. GPT-style tokenizers average ~4 chars/token for English.
        max(1, text.count / 4)
    }
}
