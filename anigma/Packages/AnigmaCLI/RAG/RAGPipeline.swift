import Foundation

/// Compatibility wrapper that preserves the older RAG API while routing through
/// the PostgreSQL-backed vector pipeline.
@available(macOS 13.0, *)
public actor RAGPipeline {
    private let vectorPipeline: VectorRAGPipeline

    public init(dbPath: String, chunkSize: Int = 512, overlapSize: Int = 128) {
        self.vectorPipeline = VectorRAGPipeline(
            dbPath: dbPath,
            chunkSize: chunkSize,
            overlapSize: overlapSize,
            embeddingProvider: nil
        )
    }

    public func initialize() async throws {
        try await vectorPipeline.initialize()
    }

    public func chunkFile(path: String, content: String, language: String) async throws -> [CodeChunk] {
        try await vectorPipeline.chunkFile(path: path, content: content, language: language)
    }

    public func indexChunks(_ chunks: [CodeChunk]) async throws {
        try await vectorPipeline.indexChunks(chunks)
    }

    public func search(query: String, limit: Int = 5, useVector: Bool = true) async throws -> [SearchResult] {
        try await vectorPipeline.search(query: query, limit: limit, useVector: useVector)
    }
}

public typealias RAGError = VectorRAGError
