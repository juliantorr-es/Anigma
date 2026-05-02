import Foundation

public struct RawChunk: Sendable, Codable {
    public var id: String
    public var content: String

    public init(id: String, content: String) {
        self.id = id
        self.content = content
    }
}

public struct NormalizedChunk: Sendable, Codable {
    public var id: String
    public var normalizedContent: String

    public init(id: String, normalizedContent: String) {
        self.id = id
        self.normalizedContent = normalizedContent
    }
}

public struct ChunkSet: Sendable, Codable {
    public var chunks: [NormalizedChunk]
    public var createdAt: Date

    public init(chunks: [NormalizedChunk], createdAt: Date = Date()) {
        self.chunks = chunks
        self.createdAt = createdAt
    }
}

public struct ChunkNormalizerConfig: Sendable, Codable {
    public static let `default` = ChunkNormalizerConfig()
    public init() {}
}

public actor ChunkNormalizerCapsule {
    public init(config: ChunkNormalizerConfig = .default) throws {
        _ = config
    }

    public func normalize(
        chunks: [RawChunk],
        strictMode: Bool = true
    ) async throws -> ChunkSet {
        _ = strictMode
        let normalized = chunks.map { chunk in
            NormalizedChunk(id: chunk.id, normalizedContent: chunk.content)
        }
        return ChunkSet(chunks: normalized)
    }
}
