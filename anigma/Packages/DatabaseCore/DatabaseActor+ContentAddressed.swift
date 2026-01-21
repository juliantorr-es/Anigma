//
//  DatabaseActor+ContentAddressed.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import Foundation

/// Extension on DatabaseActor to provide convenient content-addressed operations.
public extension DatabaseActor {

    /// Create or get a content-addressed store using this database.
    func makeContentAddressedStore() async throws -> ContentAddressedStore {
        return try await ContentAddressedStore(database: self)
    }

    /// Store content-addressable object and create reference.
    func storeContent<T: ContentAddressable>(
        _ content: T,
        parentKey: String,
        parentType: String,
        metadata: Data? = nil
    ) async throws -> (hash: String, referenceID: String) {
        let store = try await makeContentAddressedStore()
        let hashedBlob = try content.toHashedBlob()

        // Store artifact
        let artifact = hashedBlob.toContentAddressedArtifact()
        let storedArtifact = try await store.storeArtifact(artifact)

        // Create reference
        let reference = hashedBlob.toReference(
            parentKey: parentKey,
            parentType: parentType,
            metadata: metadata
        )
        _ = try await store.createReference(reference)

        return (storedArtifact.contentHash, reference.referenceID)
    }

    /// Store raw data as content-addressed artifact.
    func storeContent(
        data: Data,
        parentKey: String,
        parentType: String,
        metadata: Data? = nil
    ) async throws -> (hash: String, referenceID: String) {
        let store = try await makeContentAddressedStore()
        let hash = ContentHashing.computeSHA256(data)

        // Store artifact
        let artifact = ContentAddressedArtifact(
            contentHash: hash,
            hashAlgorithm: ContentHashing.defaultAlgorithm,
            payload: data,
            payloadSize: data.count,
            isCompressed: false,
            firstSeenAt: Date(),
            referenceCount: 1
        )
        let storedArtifact = try await store.storeArtifact(artifact)

        // Create reference
        let reference = ArtifactReference(
            referenceID: UUID().uuidString,
            contentHash: hash,
            parentKey: parentKey,
            parentType: parentType,
            createdAt: Date(),
            metadata: metadata
        )
        _ = try await store.createReference(reference)

        return (storedArtifact.contentHash, reference.referenceID)
    }

    /// Store file as content-addressed artifact.
    func storeFile(
        url: URL,
        parentKey: String,
        parentType: String,
        metadata: Data? = nil
    ) async throws -> (hash: String, referenceID: String) {
        let store = try await makeContentAddressedStore()
        let hash = try StreamHashing.computeFileHash(url: url)

        // In a real implementation, we'd stream the file content
        let data = try Data(contentsOf: url)

        // Store artifact
        let artifact = ContentAddressedArtifact(
            contentHash: hash,
            hashAlgorithm: ContentHashing.defaultAlgorithm,
            payload: data,
            payloadSize: data.count,
            isCompressed: false,
            firstSeenAt: Date(),
            referenceCount: 1
        )
        let storedArtifact = try await store.storeArtifact(artifact)

        // Create reference
        let reference = ArtifactReference(
            referenceID: UUID().uuidString,
            contentHash: hash,
            parentKey: parentKey,
            parentType: parentType,
            createdAt: Date(),
            metadata: metadata
        )
        _ = try await store.createReference(reference)

        return (storedArtifact.contentHash, reference.referenceID)
    }

    /// Retrieve content-addressed artifact by hash.
    func getContent(byHash hash: String) async throws -> Data? {
        let store = try await makeContentAddressedStore()
        guard let artifact = try await store.getArtifact(byHash: hash) else {
            return nil
        }
        return artifact.payload
    }

    /// Check if content exists by hash.
    func hasContent(withHash hash: String) async throws -> Bool {
        let store = try await makeContentAddressedStore()
        let artifact = try await store.getArtifact(byHash: hash)
        return artifact != nil
    }

    /// Get deduplication statistics.
    func getDeduplicationStats() async throws -> (artifacts: Int, references: Int, avgRefsPerArtifact: Double) {
        let store = try await makeContentAddressedStore()
        let result = try await store.getDeduplicationStats()
        return (
            artifacts: result.totalArtifacts,
            references: result.totalReferences,
            avgRefsPerArtifact: result.averageRefsPerArtifact
        )
    }
}
