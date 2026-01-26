import Foundation
import CryptoKit
import CapsuleCore
import AnigmaNativeShims
import TextChunkingCapsule

public actor ChunkingSystem {
    private let database: ContextumDatabase
    private let maxChunkSize: Int
    private let overlapSize: Int

    public init(database: ContextumDatabase, maxChunkSize: Int = 512, overlapSize: Int = 50) {
        self.database = database
        self.maxChunkSize = maxChunkSize
        self.overlapSize = overlapSize
    }

    public func process(sourceId: String, content: String) async throws -> [ChunkComponent] {
        let chunks = await chunkText(content)
        var components: [ChunkComponent] = []

        for (index, chunkContent) in chunks.enumerated() {
            let chunkData = Data(chunkContent.utf8)
            let hash = SHA256.hash(data: chunkData)
            let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()

            let component = ChunkComponent(
                chunkId: UUID().uuidString,
                sourceId: sourceId,
                contentHash: hashString,
                chunkIndex: index,
                totalChunks: chunks.count,
                byteRange: 0..<chunkData.count,
                tokenCount: nil
            )

            try await database.insertChunk(component, content: chunkContent)
            components.append(component)
        }

        let event = TelemetryEventComponent(
            eventId: UUID().uuidString,
            eventType: .chunk,
            outcome: .success
        )
        try await database.insertEvent(event)

        return components
    }

    private func chunkText(_ text: String) async -> [String] {
        guard !text.isEmpty else { return [] }
        
        // Create configuration based on character-based maxChunkSize
        let targetBytes = Int(Double(maxChunkSize) * 1.5)
        let config = TextChunkingConfig(
            targetChunkSize: targetBytes,
            minChunkSize: max(64, targetBytes / 4),
            maxChunkSize: min(targetBytes * 2, 16384)
        )
        
        do {
            let capsule = try TextChunkingCapsule(config: config)
            let stringChunks = try await capsule.chunk(text)
            
            // Apply overlapping if needed (overlapSize > 0)
            if overlapSize > 0 && stringChunks.count > 1 {
                return applyOverlap(to: stringChunks)
            }
            
            return stringChunks.isEmpty ? [text] : stringChunks
            
        } catch {
            // Fall back to original chunking method if capsule fails
            return fallbackChunkText(text)
        }
    }
    
    /// Original line-based chunking method kept as fallback
    private func fallbackChunkText(_ text: String) -> [String] {
        var chunks: [String] = []
        let lines = text.components(separatedBy: .newlines)
        var currentChunk = ""

        for line in lines {
            if (currentChunk + line).count > maxChunkSize, !currentChunk.isEmpty {
                chunks.append(currentChunk)
                currentChunk = String(currentChunk.suffix(overlapSize))
            }
            currentChunk += line + "\n"
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }

        return chunks.isEmpty ? [text] : chunks
    }
    
    /// Apply overlapping to chunks by extending chunk boundaries
    private func applyOverlap(to chunks: [String]) -> [String] {
        guard chunks.count > 1 else { return chunks }
        
        var overlappedChunks: [String] = []
        
        for i in 0..<chunks.count {
            var chunk = chunks[i]
            
            // Add overlap from previous chunk (except first chunk)
            if i > 0 {
                let previousChunk = chunks[i - 1]
                let overlapStart = max(0, previousChunk.count - overlapSize)
                let overlapText = String(previousChunk.suffix(from: previousChunk.index(previousChunk.startIndex, offsetBy: overlapStart)))
                chunk = overlapText + chunk
            }
            
            // Add overlap to next chunk (except last chunk)
            if i < chunks.count - 1 {
                let nextChunk = chunks[i + 1]
                let overlapEnd = min(overlapSize, nextChunk.count)
                let overlapText = String(nextChunk.prefix(overlapEnd))
                chunk = chunk + overlapText
            }
            
            overlappedChunks.append(chunk)
        }
        
        return overlappedChunks
    }
}
