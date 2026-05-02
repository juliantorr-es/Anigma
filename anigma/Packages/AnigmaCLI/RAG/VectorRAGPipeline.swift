import Foundation
import AnigmaCLIDatabase

private typealias StoredSearchResult = AnigmaCLIDatabase.SearchResult

/// PostgreSQL-backed RAG pipeline with vector embedding support.
@available(macOS 13.0, *)
public actor VectorRAGPipeline {
    private let dbPath: String
    private var vectorStore: CLIVectorStore?
    private let chunkSize: Int
    private let overlapSize: Int
    private let embeddingProvider: EmbeddingProviderProtocol?

    public init(
        dbPath: String,
        chunkSize: Int = 512,
        overlapSize: Int = 128,
        embeddingProvider: EmbeddingProviderProtocol? = nil
    ) {
        self.dbPath = dbPath
        self.chunkSize = chunkSize
        self.overlapSize = overlapSize
        self.embeddingProvider = embeddingProvider
    }

    public func initialize() async throws {
        if vectorStore == nil {
            vectorStore = try await CLIVectorStore(dbPath: dbPath)
        }
    }

    public func chunkFile(path: String, content: String, language: String) async throws -> [CodeChunk] {
        let lines = content.components(separatedBy: .newlines)
        var chunks: [CodeChunk] = []
        var currentChunk: [String] = []
        var startLine = 1

        for (index, line) in lines.enumerated() {
            currentChunk.append(line)

            if currentChunk.count >= chunkSize {
                let chunkContent = currentChunk.joined(separator: "\n")
                chunks.append(CodeChunk(
                    filePath: path,
                    content: chunkContent,
                    startLine: startLine,
                    endLine: index + 1,
                    language: language,
                    chunkType: detectChunkType(content: chunkContent)
                ))

                let overlap = min(overlapSize, currentChunk.count)
                currentChunk = Array(currentChunk.suffix(overlap))
                startLine = max(1, index + 1 - overlap)
            }
        }

        if !currentChunk.isEmpty {
            let chunkContent = currentChunk.joined(separator: "\n")
            chunks.append(CodeChunk(
                filePath: path,
                content: chunkContent,
                startLine: startLine,
                endLine: lines.count,
                language: language,
                chunkType: detectChunkType(content: chunkContent)
            ))
        }

        return chunks
    }

    public func indexChunks(_ chunks: [CodeChunk]) async throws {
        guard let vectorStore else {
            throw VectorRAGError.databaseError("Vector store not initialized")
        }

        for chunk in chunks {
            let chunkKey = makeChunkKey(chunk)
            let metadata = encodeMetadata([
                "file_path": chunk.filePath,
                "start_line": String(chunk.startLine),
                "end_line": String(chunk.endLine),
                "language": chunk.language,
                "chunk_type": chunk.chunkType
            ])

            if let provider = embeddingProvider {
                let embedding = try await provider.generateEmbedding(text: chunk.content)
                try await vectorStore.store(
                    chunkId: chunkKey,
                    content: chunk.content,
                    vector: embedding,
                    metadata: metadata
                )
            } else {
                // Keep the chunk searchable even without embeddings.
                try await vectorStore.store(
                    chunkId: chunkKey,
                    content: chunk.content,
                    vector: Array(repeating: 0, count: 384),
                    metadata: metadata
                )
            }
        }
    }

    public func search(query: String, limit: Int = 5, useVector: Bool = true) async throws -> [SearchResult] {
        guard let vectorStore else {
            throw VectorRAGError.databaseError("Vector store not initialized")
        }

        if useVector, let provider = embeddingProvider {
            return try await searchHybrid(query: query, limit: limit, provider: provider, vectorStore: vectorStore)
        } else {
            let textResults = try await vectorStore.searchText(query, limit: limit)
            return textResults.compactMap { makeSearchResult(from: $0, source: .fts) }
        }
    }

    private func searchHybrid(
        query: String,
        limit: Int,
        provider: EmbeddingProviderProtocol,
        vectorStore: CLIVectorStore
    ) async throws -> [SearchResult] {
        let ftsResults = try await vectorStore.searchText(query, limit: limit * 2)
        let queryEmbedding = try await provider.generateEmbedding(text: query)
        let vectorResults = try await vectorStore.searchVector(queryEmbedding, limit: limit * 2)

        var merged: [String: SearchResult] = [:]

        for result in ftsResults {
            if let local = makeSearchResult(from: result, source: .fts) {
                merged[result.chunkId] = local
            }
        }

        for result in vectorResults {
            if var local = makeSearchResult(from: result, source: .vector) {
                if var existing = merged[result.chunkId] {
                    existing.score = (existing.score + local.score) / 2.0
                    existing.source = .hybrid
                    merged[result.chunkId] = existing
                } else {
                    local.source = .vector
                    merged[result.chunkId] = local
                }
            }
        }

        return Array(merged.values)
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    private func detectChunkType(content: String) -> String {
        if content.contains("func ") || content.contains("def ") { return "function" }
        if content.contains("class ") || content.contains("struct ") { return "type" }
        if content.contains("import ") { return "import" }
        if content.contains("//") || content.contains("/*") { return "comment" }
        return "code"
    }

    private func makeSearchResult(from result: StoredSearchResult, source: SearchSource) -> SearchResult? {
        let metadata = decodeMetadata(result.metadata)
        let filePath = metadata["file_path"] ?? "unknown"
        let startLine = metadata["start_line"].flatMap(Int.init) ?? 0
        let endLine = metadata["end_line"].flatMap(Int.init) ?? 0
        let language = metadata["language"] ?? ""
        let chunkType = metadata["chunk_type"] ?? "code"

        return SearchResult(
            chunkId: stableChunkID(result.chunkId),
            filePath: filePath,
            content: result.content,
            startLine: startLine,
            endLine: endLine,
            language: language,
            chunkType: chunkType,
            score: Double(result.similarity),
            source: source
        )
    }

    private func decodeMetadata(_ metadata: String?) -> [String: String] {
        guard
            let metadata,
            let data = metadata.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }

        var output: [String: String] = [:]
        for (key, value) in object {
            output[key] = String(describing: value)
        }
        return output
    }

    private func encodeMetadata(_ metadata: [String: String]) -> String {
        guard let data = try? JSONEncoder().encode(metadata),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private func makeChunkKey(_ chunk: CodeChunk) -> String {
        "\(chunk.filePath)#\(chunk.startLine)-\(chunk.endLine)#\(chunk.chunkType)"
    }

    private func stableChunkID(_ key: String) -> Int64 {
        var hash: UInt64 = 1469598103934665603
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return Int64(bitPattern: hash)
    }
}

public protocol EmbeddingProviderProtocol: Sendable {
    func generateEmbedding(text: String) async throws -> [Float]
}

public struct CodeChunk: Sendable {
    public let filePath: String
    public let content: String
    public let startLine: Int
    public let endLine: Int
    public let language: String
    public let chunkType: String

    public init(filePath: String, content: String, startLine: Int, endLine: Int, language: String, chunkType: String) {
        self.filePath = filePath
        self.content = content
        self.startLine = startLine
        self.endLine = endLine
        self.language = language
        self.chunkType = chunkType
    }
}

public struct SearchResult: Sendable {
    public let chunkId: Int64
    public let filePath: String
    public let content: String
    public let startLine: Int
    public let endLine: Int
    public let language: String
    public let chunkType: String
    public var score: Double
    public var source: SearchSource
}

public enum SearchSource: Sendable {
    case fts
    case vector
    case hybrid
}

public enum VectorRAGError: Error, CustomStringConvertible {
    case databaseError(String)
    case embeddingError(String)
    case invalidQuery(String)

    public var description: String {
        switch self {
        case .databaseError(let msg): return "Database error: \(msg)"
        case .embeddingError(let msg): return "Embedding error: \(msg)"
        case .invalidQuery(let msg): return "Invalid query: \(msg)"
        }
    }
}
