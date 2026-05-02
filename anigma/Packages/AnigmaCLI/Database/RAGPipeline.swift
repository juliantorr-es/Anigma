import Foundation
import AnigmaCLICore
import TextChunkingCapsule
import AnigmaNativeShims
import CanonicalTokenizer

/// RAG (Retrieval-Augmented Generation) Pipeline  
public actor RAGPipeline {
    private let vectorStore: CLIVectorStore
    private let embeddingProvider: any EmbeddingProvider
    private let chunkSize: Int
    private let chunkOverlap: Int
    private let promptCompressionPolicy = PromptCompressionPolicy.default

    public enum RAGError: Error {
        case embeddingFailed(String)
        case searchFailed(String)
        case invalidInput
    }

    public init(
        vectorStore: CLIVectorStore,
        embeddingProvider: any EmbeddingProvider,
        chunkSize: Int = 512,
        chunkOverlap: Int = 128
    ) {
        self.vectorStore = vectorStore
        self.embeddingProvider = embeddingProvider
        self.chunkSize = chunkSize
        self.chunkOverlap = chunkOverlap
    }

    public func ingest(
        text: String,
        sourceId: String,
        metadata: [String: String] = [:]
    ) async throws {
        let chunks = await chunkText(text, chunkSize: chunkSize, overlap: chunkOverlap)

        for (index, chunk) in chunks.enumerated() {
            let chunkId = "\(sourceId)_chunk_\(index)"
            let embedding = try await embeddingProvider.embed(text: chunk)

            var chunkMetadata = metadata
            chunkMetadata["source_id"] = sourceId
            chunkMetadata["chunk_index"] = "\(index)"
            chunkMetadata["total_chunks"] = "\(chunks.count)"

            let metadataJSON = try? JSONEncoder().encode(chunkMetadata)
            let metadataString = metadataJSON.flatMap { String(data: $0, encoding: .utf8) }

            try await vectorStore.store(
                chunkId: chunkId,
                content: chunk,
                vector: embedding,
                metadata: metadataString
            )
        }
    }

    public func retrieve(
        query: String,
        topK: Int = 5,
        useHybridSearch: Bool = true
    ) async throws -> [SearchResult] {
        if useHybridSearch {
            return try await hybridSearch(query: query, topK: topK)
        } else {
            return try await vectorSearch(query: query, topK: topK)
        }
    }

    private func vectorSearch(query: String, topK: Int) async throws -> [SearchResult] {
        let queryEmbedding = try await embeddingProvider.embed(text: query)
        return try await vectorStore.searchVector(queryEmbedding, limit: topK)
    }

    private func hybridSearch(query: String, topK: Int) async throws -> [SearchResult] {
        let vectorResults = try await vectorSearch(query: query, topK: topK)
        let textResults = try await vectorStore.searchText(query, limit: topK)

        var mergedResults: [String: SearchResult] = [:]

        for result in vectorResults {
            mergedResults[result.chunkId] = result
        }

        for result in textResults {
            if mergedResults[result.chunkId] == nil {
                mergedResults[result.chunkId] = result
            }
        }

        return orderedContext(Array(mergedResults.values))
            .prefix(topK)
            .map { $0 }
    }

    public func buildPrompt(
        query: String,
        context: [SearchResult],
        systemPrompt: String? = nil
    ) -> String {
        let orderedContext = orderedContext(context)
        var prompt = ""

        if let systemPrompt = systemPrompt {
            prompt += systemPrompt + "\n\n"
        }

        if !orderedContext.isEmpty {
            prompt += assembleContextSection(orderedContext)
            prompt += "---\n\n"
        }

        prompt += "Query: \(query)\n\n"
        prompt += "Please provide a response based on the context above."

        return prompt
    }

    private func orderedContext(_ context: [SearchResult]) -> [SearchResult] {
        context.sorted { lhs, rhs in
            let lhsSimilarity = normalizedSimilarity(lhs.similarity)
            let rhsSimilarity = normalizedSimilarity(rhs.similarity)
            if lhsSimilarity != rhsSimilarity {
                return lhsSimilarity > rhsSimilarity
            }

            let lhsChunkID = sanitizeProvenanceField(
                lhs.chunkId,
                fallback: "unknown-chunk",
                maxLength: promptCompressionPolicy.maxProvenanceFieldChars
            )
            let rhsChunkID = sanitizeProvenanceField(
                rhs.chunkId,
                fallback: "unknown-chunk",
                maxLength: promptCompressionPolicy.maxProvenanceFieldChars
            )
            if lhsChunkID != rhsChunkID {
                return lhsChunkID < rhsChunkID
            }

            let lhsSource = sourceIdentifier(for: lhs)
            let rhsSource = sourceIdentifier(for: rhs)
            if lhsSource != rhsSource {
                return lhsSource < rhsSource
            }

            if lhs.content != rhs.content {
                return lhs.content < rhs.content
            }

            let lhsMetadata = lhs.metadata ?? ""
            let rhsMetadata = rhs.metadata ?? ""
            if lhsMetadata != rhsMetadata {
                return lhsMetadata < rhsMetadata
            }

            return lhs.createdAt < rhs.createdAt
        }
    }

    private func assembleContextSection(_ context: [SearchResult]) -> String {
        let rawChars = context.reduce(0) { $0 + $1.content.count }
        guard rawChars > promptCompressionPolicy.softContextCharLimit else {
            return legacyContextSection(context)
        }

        let cappedContext = Array(context.prefix(promptCompressionPolicy.maxDocuments))
        let perDocumentBudget = max(
            promptCompressionPolicy.minExcerptChars,
            min(
                promptCompressionPolicy.maxExcerptChars,
                promptCompressionPolicy.hardContextCharLimit / max(1, cappedContext.count)
            )
        )

        var compressedSection = "Relevant Context:\n\n"
        var remainingBudget = promptCompressionPolicy.hardContextCharLimit
        var usedBudget = 0
        var includedDocuments = 0

        for (index, result) in cappedContext.enumerated() {
            let reference = makeReferenceLine(for: result, index: index)
            let targetBudget = index < promptCompressionPolicy.priorityDocuments
                ? min(promptCompressionPolicy.maxExcerptChars, perDocumentBudget * 2)
                : perDocumentBudget
            let availableForContent = max(
                0,
                remainingBudget - reference.count - promptCompressionPolicy.referenceBlockOverheadChars
            )

            guard availableForContent >= promptCompressionPolicy.minExcerptChars else { continue }

            let content = compactContent(result.content, maxChars: min(targetBudget, availableForContent))
            let block = "\(reference)\n\(content)\n\n"
            guard block.count <= remainingBudget else { continue }

            compressedSection += block
            remainingBudget -= block.count
            usedBudget += block.count
            includedDocuments += 1
        }

        let droppedDocuments = max(0, context.count - includedDocuments)
        compressedSection += "[Context compression applied: original_chars=\(rawChars), compressed_chars=\(usedBudget), included_docs=\(includedDocuments), dropped_docs=\(droppedDocuments)]\n\n"
        return compressedSection
    }

    private func legacyContextSection(_ context: [SearchResult]) -> String {
        var section = "Relevant Context:\n\n"
        for (index, result) in context.enumerated() {
            section += "[\(index + 1)] \(result.content)\n\n"
        }
        return section
    }

    private func makeReferenceLine(for result: SearchResult, index: Int) -> String {
        let source = sourceIdentifier(for: result)
        let chunkID = sanitizeProvenanceField(
            result.chunkId,
            fallback: "unknown-chunk",
            maxLength: promptCompressionPolicy.maxProvenanceFieldChars
        )
        let similarity = String(
            format: "%.4f",
            locale: Locale(identifier: "en_US_POSIX"),
            Double(normalizedSimilarity(result.similarity))
        )
        return "[\(index + 1)] source=\(source) chunk_id=\(chunkID) similarity=\(similarity)"
    }

    private func sourceIdentifier(for result: SearchResult) -> String {
        let metadata = decodeMetadata(result.metadata)
        let rawSource =
            metadata["source_id"] ??
            metadata["path"] ??
            metadata["file_path"] ??
            metadata["source"]
        return sanitizeProvenanceField(
            rawSource,
            fallback: "unknown",
            maxLength: promptCompressionPolicy.maxProvenanceFieldChars
        )
    }

    private func decodeMetadata(_ metadata: String?) -> [String: String] {
        guard
            let metadata,
            let data = metadata.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }

        var decoded: [String: String] = [:]
        decoded.reserveCapacity(json.count)
        for (key, value) in json {
            decoded[key] = String(describing: value)
        }
        return decoded
    }

    private func compactContent(_ content: String, maxChars: Int) -> String {
        guard content.count > maxChars else { return content }
        guard maxChars > 48 else { return String(content.prefix(maxChars)) }

        let marker = "\n...[compacted]...\n"
        let markerLength = marker.count
        guard maxChars > markerLength + 12 else {
            return String(content.prefix(maxChars))
        }

        let headLength = Int(Double(maxChars - markerLength) * 0.72)
        let tailLength = maxChars - markerLength - headLength

        let head = content.prefix(max(0, headLength))
        let tail = content.suffix(max(0, tailLength))
        return "\(head)\(marker)\(tail)"
    }

    private func normalizedSimilarity(_ similarity: Float) -> Float {
        similarity.isFinite ? similarity : 0
    }

    private func sanitizeProvenanceField(_ value: String?, fallback: String, maxLength: Int) -> String {
        ContextSanitizer.sanitizeProvenanceField(
            value,
            fallback: fallback,
            maxLength: maxLength
        )
    }

    private func chunkText(_ text: String, chunkSize: Int, overlap: Int) async -> [String] {
        guard !text.isEmpty else { return [] }
        
        // Convert to UTF-8 data for byte-level chunking
        let data = Data(text.utf8)
        
        // Compute average bytes per character for this text
        let avgBytesPerChar = max(1, data.count / text.count)
        
        // Convert character-based chunkSize to byte-based target size
        let targetBytes = chunkSize * avgBytesPerChar
        
        // Ensure reasonable bounds for chunk sizes
        let minBytes = max(64, targetBytes / 4)
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
            var baseChunks: [String] = []
            for chunk in chunkData {
                if let chunkString = String(data: chunk, encoding: .utf8) {
                    let trimmed = chunkString.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        baseChunks.append(trimmed)
                    }
                } else {
                    // UTF-8 conversion failed, fall back to original word-based chunking
                    return fallbackChunkText(text, chunkSize: chunkSize, overlap: overlap)
                }
            }
            
            if baseChunks.isEmpty {
                return [text]
            }
            
            // Apply overlap if requested
            if overlap > 0 {
                return applyOverlap(to: baseChunks, overlapChars: overlap, originalText: text)
            }
            
            return baseChunks
            
        } catch {
            // Capsule failed, fall back to original word-based chunking
            return fallbackChunkText(text, chunkSize: chunkSize, overlap: overlap)
        }
    }
    
    /// Original word-based chunking method kept as fallback
    private func fallbackChunkText(_ text: String, chunkSize: Int, overlap: Int) -> [String] {
        let words = ContextTokenizer.words(in: text)
        var chunks: [String] = []
        var currentIndex = 0

        while currentIndex < words.count {
            let endIndex = min(currentIndex + chunkSize, words.count)
            let chunk = words[currentIndex..<endIndex].joined(separator: " ")
            chunks.append(chunk)

            currentIndex += chunkSize - overlap

            if currentIndex >= words.count {
                break
            }
        }

        return chunks.isEmpty ? [text] : chunks
    }
    
    /// Apply overlapping windows to base chunks
    private func applyOverlap(to baseChunks: [String], overlapChars: Int, originalText: String) -> [String] {
        guard baseChunks.count > 1 else { return baseChunks }
        
        var overlappingChunks: [String] = []
        let text = originalText as NSString
        
        // Find start positions of each base chunk in the original text
        var positions: [Int] = []
        var currentPos = 0
        for chunk in baseChunks {
            let range = text.range(of: chunk, options: [], range: NSRange(location: currentPos, length: text.length - currentPos))
            if range.location != NSNotFound {
                positions.append(range.location)
                currentPos = range.location + range.length
            } else {
                // Fallback: can't find positions, return base chunks without overlap
                return baseChunks
            }
        }
        positions.append(text.length) // Add end position for easier calculation
        
        // Create overlapping windows
        for i in 0..<baseChunks.count {
            let start = positions[i]
            let end = min(positions[i + 1] + overlapChars, text.length)
            if end > start {
                let chunkRange = NSRange(location: start, length: end - start)
                let chunk = text.substring(with: chunkRange)
                overlappingChunks.append(chunk)
            } else {
                overlappingChunks.append(baseChunks[i])
            }
        }
        
        return overlappingChunks
    }

    public func clearStore() async throws {
        try await vectorStore.clear()
    }
}

private struct PromptCompressionPolicy {
    let softContextCharLimit: Int
    let hardContextCharLimit: Int
    let minExcerptChars: Int
    let maxExcerptChars: Int
    let priorityDocuments: Int
    let maxDocuments: Int
    let maxProvenanceFieldChars: Int
    let referenceBlockOverheadChars: Int

    static let `default` = PromptCompressionPolicy(
        softContextCharLimit: 12_000,
        hardContextCharLimit: 18_000,
        minExcerptChars: 220,
        maxExcerptChars: 1_400,
        priorityDocuments: 3,
        maxDocuments: 12,
        maxProvenanceFieldChars: 240,
        referenceBlockOverheadChars: 3
    )
}
