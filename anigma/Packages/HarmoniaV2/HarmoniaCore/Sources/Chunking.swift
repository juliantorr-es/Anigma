// HarmoniaCore - Chunking & Code Processing
// Version: 0.1.0
//
// Types and utilities for code chunking and retrieval.

import Foundation
import CryptoKit

// MARK: - Types

/// A chunk of code or text to be indexed.
public struct Chunk: Sendable, Codable {
    public let content: String
    public let filePath: String
    public let startLine: Int
    public let endLine: Int
    public let contentHash: String
    public let projectId: String
    
    public init(content: String, filePath: String, startLine: Int, endLine: Int, projectId: String) {
        self.content = content
        self.filePath = filePath
        self.startLine = startLine
        self.endLine = endLine
        self.projectId = projectId
        self.contentHash = Chunk.computeHash(content)
    }
    
    private static func computeHash(_ content: String) -> String {
        let data = content.data(using: .utf8) ?? Data()
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

/// A stored chunk record returned from retrieval.
public struct StoredChunkRecord: Sendable, Codable {
    public let id: String
    public let chunk: Chunk
    public let embedding: [Float]?
    public let embeddingModel: String?
    public let createdAt: Date
    
    public init(id: String, chunk: Chunk, embedding: [Float]?, embeddingModel: String? = nil, createdAt: Date) {
        self.id = id
        self.chunk = chunk
        self.embedding = embedding
        self.embeddingModel = embeddingModel
        self.createdAt = createdAt
    }
}

/// Result from chunk similarity search.
public struct SimilarChunkResult: Sendable, Codable {
    public let record: StoredChunkRecord
    public let similarity: Float
    public let rank: Int
    
    public init(record: StoredChunkRecord, similarity: Float, rank: Int) {
        self.record = record
        self.similarity = similarity
        self.rank = rank
    }
}

// MARK: - Protocols

/// Protocol for chunk storage operations.
public protocol ChunkStore: Actor {
    /// Store a chunk record.
    /// - Returns: Unique identifier for the stored record
    func store(chunk: Chunk, embedding: [Float]?, embeddingModel: String?) async throws -> String
    
    /// Perform vector similarity search for chunks.
    func searchSimilar(embedding: [Float], embeddingModel: String?, projectId: String, limit: Int, threshold: Float?, scanLimit: Int?) async throws -> [SimilarChunkResult]
}

// MARK: - Chunker Utility

/// Deterministic content chunker.
public enum Chunker {
    public struct Config {
        public let maxLines: Int
        public let overlapLines: Int
        
        public init(maxLines: Int = 50, overlapLines: Int = 0) {
            self.maxLines = maxLines
            self.overlapLines = overlapLines
        }
    }
    
    /// Split text into chunks.
    public static func chunk(
        content: String,
        filePath: String,
        projectId: String,
        config: Config = Config()
    ) -> [Chunk] {
        let lines = content.components(separatedBy: .newlines)
        var chunks: [Chunk] = []
        
        guard !lines.isEmpty else { return [] }
        
        var currentIndex = 0
        
        while currentIndex < lines.count {
            let endIndex = min(currentIndex + config.maxLines, lines.count)
            let chunkLines = lines[currentIndex..<endIndex]
            let chunkContent = chunkLines.joined(separator: "\n")
            
            // 1-based line numbers
            let startLine = currentIndex + 1
            let endLine = endIndex
            
            if !chunkContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let chunk = Chunk(
                    content: chunkContent,
                    filePath: filePath,
                    startLine: startLine,
                    endLine: endLine,
                    projectId: projectId
                )
                chunks.append(chunk)
            }
            
            // Advance
            let step = max(1, config.maxLines - config.overlapLines)
            currentIndex += step
            
            // Prevent infinite loop if step is 0 (should not happen with max(1, ...))
            if currentIndex >= lines.count { break }
        }
        
        return chunks
    }
}
