// HarmoniaMemory - Storage & Retrieval
// Memory capabilities: Vector retrieval, context management, session storage
// Version: 0.2.0-migration

import Foundation
import HarmoniaV2Core
import AnigmaFoundation

// MARK: - Public API

/// Memory manager for retrieval and context
public actor MemoryManager {
    private let registry: ModuleRegistry
    private let store: (any MemoryStore)?
    
    /// Initialize with optional storage backend.
    /// If store is nil, operations throw notImplemented (for testing/stubs).
    public init(registry: ModuleRegistry = ModuleRegistry(), store: (any MemoryStore)? = nil) {
        self.registry = registry
        self.store = store
        Task { await registry.register(module: "HarmoniaMemory") }
    }

    public var isConfigured: Bool {
        store != nil
    }

    public func backendConfigurationState() -> String {
        store == nil ? "NOT_CONFIGURED" : "CONFIGURED"
    }
    
    /// Store memory item through governed storage authority
    public func store(_ item: ShortTermMemory) async throws -> String {
        guard let store = store else {
            throw MemoryStoreError.invalidConfiguration("MemoryManager.store() - not configured with a storage backend")
        }
        
        // Convert ShortTermMemory to storage format
        let metadata: [String: String] = [
            "tenantId": item.tenantId,
            "sessionId": item.sessionId,
            "memoryType": item.memoryType.rawValue,
            "contentType": item.contentType.rawValue,
            "source": item.source.rawValue,
            "sensitivity": item.sensitivity.rawValue
        ]
        
        // For MVP, store content as string (later: preserve Data encoding)
        let contentString = String(data: item.content, encoding: .utf8) ?? ""
        
        // Store returns the ID
        return try await store.store(
            content: contentString,
            metadata: metadata,
            embedding: nil  // TODO: Wire embedding generation
        )
    }
    
    /// Retrieve memory items matching query
    public func retrieve(matching query: MemoryQuery) async throws -> [ShortTermMemory] {
        guard let store = store else {
            throw MemoryStoreError.invalidConfiguration("MemoryManager.retrieve() - not configured with a storage backend")
        }
        
        let records = try await store.retrieve(
            sessionId: query.sessionId,
            tenantId: query.tenantId,
            limit: query.limit
        )
        
        // Convert stored records back to ShortTermMemory
        return try records.compactMap { record in
            guard let tenantId = record.metadata["tenantId"],
                  let sessionId = record.metadata["sessionId"],
                  let contentTypeRaw = record.metadata["contentType"],
                  let contentType = ShortTermContentType(rawValue: contentTypeRaw),
                  let sourceRaw = record.metadata["source"],
                  let source = ShortTermSource(rawValue: sourceRaw) else {
                return nil
            }
            
            let sensitivity = record.metadata["sensitivity"]
                .flatMap { DataSensitivity(rawValue: $0) } ?? .internal_
            
            let content = record.content.data(using: .utf8) ?? Data()
            
            return ShortTermMemory(
                id: record.id,
                tenantId: tenantId,
                sessionId: sessionId,
                contentType: contentType,
                content: content,
                source: source,
                sensitivity: sensitivity
            )
        }
    }
    
    /// Perform vector similarity search
    public func searchSimilar(
        to embedding: [Float],
        embeddingModel: String? = nil,
        projectId: String,
        limit: Int = 10,
        threshold: Float? = 0.7,
        scanLimit: Int? = nil
    ) async throws -> [VectorSearchResult] {
        guard let store = store else {
            throw MemoryStoreError.invalidConfiguration("MemoryManager.searchSimilar() - not configured with a storage backend")
        }
        
        let results = try await store.searchSimilar(
            embedding: embedding,
            embeddingModel: embeddingModel,
            projectId: projectId,
            limit: limit,
            threshold: threshold,
            scanLimit: scanLimit
        )
        
        // Convert to VectorSearchResult
        return results.map { result in
            let item = VectorMemoryItem(
                id: result.record.id,
                embedding: result.record.embedding ?? [],
                text: result.record.content,
                metadata: result.record.metadata
            )
            return VectorSearchResult(
                item: item,
                similarity: result.similarity,
                rank: result.rank
            )
        }
    }
}

// MARK: - Legacy Compatibility (Deprecated)

@available(*, deprecated, message: "Use ShortTermMemory, LongTermMemory, or VectorMemoryItem instead")
public struct MemoryItem: Sendable, Identifiable {
    public let id: String
    public let content: String
    public let embedding: [Float]?
    public let timestamp: Date
    public let tier: MemoryTier
    
    public init(id: String, content: String, embedding: [Float]? = nil, timestamp: Date = Date(), tier: MemoryTier) {
        self.id = id
        self.content = content
        self.embedding = embedding
        self.timestamp = timestamp
        self.tier = tier
    }
}

@available(*, deprecated, renamed: "MemoryType")
public enum MemoryTier: String, Sendable {
    case shortTerm   // Recent, in-memory
    case longTerm    // Persisted, frequently accessed
    case persistent  // Archived, rarely accessed
}

@available(*, deprecated, renamed: "VectorSearchResult")
public struct RetrievalResult: Sendable {
    public let items: [MemoryItem]
    public let scores: [Double]
    public let totalCount: Int
    
    public init(items: [MemoryItem], scores: [Double], totalCount: Int) {
        self.items = items
        self.scores = scores
        self.totalCount = totalCount
    }
}
