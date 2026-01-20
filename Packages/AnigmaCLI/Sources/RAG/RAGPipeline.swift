//
//  RAGPipeline.swift
//  AnigmaCLI
//
//  Retrieval-Augmented Generation pipeline for context-aware responses.
//

import Foundation

public enum RAGError: Error {
    case embeddingFailed(String)
    case searchFailed(String)
    case generationFailed(String)
    case noContext
}

public struct RAGContext {
    public let query: String
    public let retrievedDocuments: [VectorDocument]
    public let formattedContext: String

    public init(query: String, documents: [VectorDocument]) {
        self.query = query
        self.retrievedDocuments = documents
        self.formattedContext = Self.formatContext(documents: documents)
    }

    private static func formatContext(documents: [VectorDocument]) -> String {
        guard !documents.isEmpty else { return "" }

        var formatted = "# Retrieved Context\n\n"

        for (idx, doc) in documents.enumerated() {
            formatted += "## Document \(idx + 1)\n"
            if !doc.metadata.isEmpty {
                formatted += "Metadata: \(doc.metadata)\n"
            }
            formatted += "\n\(doc.content)\n\n"
        }

        return formatted
    }
}

public struct RAGConfig {
    public let topK: Int
    public let similarityThreshold: Float?
    public let contextWindowSize: Int
    public let useHybridSearch: Bool
    public let vectorWeight: Float

    public init(
        topK: Int = 5,
        similarityThreshold: Float? = 0.7,
        contextWindowSize: Int = 4096,
        useHybridSearch: Bool = true,
        vectorWeight: Float = 0.7
    ) {
        self.topK = topK
        self.similarityThreshold = similarityThreshold
        self.contextWindowSize = contextWindowSize
        self.useHybridSearch = useHybridSearch
        self.vectorWeight = vectorWeight
    }

    public static let `default` = RAGConfig()
}

public actor RAGPipeline {
    private let vectorStore: VectorStore
    private let embeddingProvider: EmbeddingProvider
    private let config: RAGConfig

    public init(
        vectorStore: VectorStore,
        embeddingProvider: EmbeddingProvider,
        config: RAGConfig = .default
    ) {
        self.vectorStore = vectorStore
        self.embeddingProvider = embeddingProvider
        self.config = config
    }

    public func indexDocument(
        id: String,
        content: String,
        metadata: [String: String] = [:]
    ) async throws {
        let embedding = try await embeddingProvider.embed(text: content)

        let document = VectorDocument(
            id: id,
            content: content,
            metadata: metadata,
            embedding: embedding
        )

        try await vectorStore.insert(document: document)
    }

    public func indexDocuments(_ documents: [(id: String, content: String, metadata: [String: String])]) async throws {
        var vectorDocuments: [VectorDocument] = []

        let contents = documents.map { $0.content }
        let embeddings = try await embeddingProvider.embedBatch(texts: contents)

        for (idx, doc) in documents.enumerated() {
            let vectorDoc = VectorDocument(
                id: doc.id,
                content: doc.content,
                metadata: doc.metadata,
                embedding: embeddings[idx]
            )
            vectorDocuments.append(vectorDoc)
        }

        try await vectorStore.insertBatch(documents: vectorDocuments)
    }

    public func indexCodebase(rootPath: String, fileExtensions: [String] = [".swift", ".md"]) async throws {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(atPath: rootPath)

        var documents: [(id: String, content: String, metadata: [String: String])] = []

        while let file = enumerator?.nextObject() as? String {
            let filePath = (rootPath as NSString).appendingPathComponent(file)
            let fileURL = URL(fileURLWithPath: filePath)

            guard fileExtensions.contains(fileURL.pathExtension.lowercased()) else {
                continue
            }

            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }

            guard content.count > 100 else {
                continue
            }

            let metadata: [String: String] = [
                "path": file,
                "extension": fileURL.pathExtension,
                "type": "code"
            ]

            documents.append((id: file, content: content, metadata: metadata))

            if documents.count >= 50 {
                try await indexDocuments(documents)
                documents.removeAll()
            }
        }

        if !documents.isEmpty {
            try await indexDocuments(documents)
        }
    }

    public func retrieve(query: String) async throws -> RAGContext {
        let queryEmbedding = try await embeddingProvider.embed(text: query)

        let results: [SearchResult]
        if config.useHybridSearch {
            results = try await vectorStore.hybridSearch(
                query: query,
                embedding: queryEmbedding,
                limit: config.topK,
                vectorWeight: config.vectorWeight
            )
        } else {
            results = try await vectorStore.search(
                embedding: queryEmbedding,
                limit: config.topK,
                threshold: config.similarityThreshold
            )
        }

        guard !results.isEmpty else {
            throw RAGError.noContext
        }

        let documents = results.map { $0.document }
        return RAGContext(query: query, documents: documents)
    }

    public func generateWithContext(
        query: String,
        chatProvider: ChatProvider,
        systemPrompt: String? = nil
    ) async throws -> String {
        let context = try await retrieve(query: query)

        let enhancedPrompt = buildPrompt(
            query: query,
            context: context,
            systemPrompt: systemPrompt
        )

        let response = try await chatProvider.chat(
            messages: [
                ChatMessage(role: .system, content: systemPrompt ?? defaultSystemPrompt),
                ChatMessage(role: .user, content: enhancedPrompt)
            ],
            options: ChatOptions()
        )

        return response.content
    }

    public func streamGenerateWithContext(
        query: String,
        chatProvider: ChatProvider,
        systemPrompt: String? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        let context = try await retrieve(query: query)

        let enhancedPrompt = buildPrompt(
            query: query,
            context: context,
            systemPrompt: systemPrompt
        )

        return try await chatProvider.streamChat(
            messages: [
                ChatMessage(role: .system, content: systemPrompt ?? defaultSystemPrompt),
                ChatMessage(role: .user, content: enhancedPrompt)
            ],
            options: ChatOptions()
        )
    }

    private func buildPrompt(query: String, context: RAGContext, systemPrompt: String?) -> String {
        var prompt = ""

        if !context.formattedContext.isEmpty {
            prompt += context.formattedContext
            prompt += "\n---\n\n"
        }

        prompt += "User Query: \(query)\n\n"
        prompt += "Please provide a comprehensive answer based on the context above."

        return prompt
    }

    private var defaultSystemPrompt: String {
        """
        You are a helpful AI assistant with access to a knowledge base.
        Use the provided context to answer questions accurately.
        If the context doesn't contain relevant information, say so clearly.
        Always cite which documents you're referencing when possible.
        """
    }

    public func getStats() async throws -> RAGStats {
        let totalDocs = try await vectorStore.count()
        return RAGStats(totalDocuments: totalDocs)
    }

    public func clear() async throws {
        try await vectorStore.clear()
    }
}

public struct RAGStats {
    public let totalDocuments: Int
}
