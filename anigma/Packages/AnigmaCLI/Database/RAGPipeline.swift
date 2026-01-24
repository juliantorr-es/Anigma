import Foundation
import AnigmaCLICore
import TextChunkingCapsule
import AnigmaNativeShims

/// RAG (Retrieval-Augmented Generation) Pipeline  
public actor RAGPipeline {
    private let vectorStore: CLIVectorStore
    private let embeddingProvider: any EmbeddingProvider
    private let chunkSize: Int
    private let chunkOverlap: Int

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

        return Array(mergedResults.values)
            .sorted { $0.similarity > $1.similarity }
            .prefix(topK)
            .map { $0 }
    }

    public func buildPrompt(
        query: String,
        context: [SearchResult],
        systemPrompt: String? = nil
    ) -> String {
        var prompt = ""

        if let systemPrompt = systemPrompt {
            prompt += systemPrompt + "\n\n"
        }

        if !context.isEmpty {
            prompt += "Relevant Context:\n\n"
            for (index, result) in context.enumerated() {
                prompt += "[\(index + 1)] \(result.content)\n\n"
            }
            prompt += "---\n\n"
        }

        prompt += "Query: \(query)\n\n"
        prompt += "Please provide a response based on the context above."

        return prompt
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
        let words = text.split(separator: " ").map { String($0) }
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
