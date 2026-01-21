//
//  RetrievalModels.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

public enum RetrievalMode: String, Sendable, Codable {
    case lexical
    case vector
    case hybrid
}

public struct RetrievalRequest: Sendable, Codable {
    public let query: String
    public let mode: RetrievalMode
    public let limit: Int
    public let pathPrefix: String?
    public let modelID: String?

    public init(
        query: String,
        mode: RetrievalMode = .hybrid,
        limit: Int = 20,
        pathPrefix: String? = nil,
        modelID: String? = nil
    ) {
        self.query = query
        self.mode = mode
        self.limit = limit
        self.pathPrefix = pathPrefix
        self.modelID = modelID
    }
}

public enum RetrievalSource: String, Sendable, Codable {
    case fts
    case embedding
    case merged
}

public struct RetrievalHit: Sendable, Codable, Equatable {
    public let chunkID: String
    public let sourcePath: String
    public let sectionTitle: String
    public let contentHashSHA256: String
    public let score: Double
    public let source: RetrievalSource
}

public enum RetrievalError: Error, Sendable {
    case invalidLimit
    case missingModelID
    case missingEmbeddingQueryVector
}
