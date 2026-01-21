//
//  ContentHashing.swift
//  DatabaseCore
//
//  [Brief description of file purpose]
//

import CryptoKit
import Foundation

/// Utility for computing content-addressed hashes with consistent algorithms and versions.
public enum ContentHashing {

    /// Compute SHA256 hash of the provided data.
    public static func computeSHA256(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Compute SHA256 hash of the provided string encoded as UTF-8.
    public static func computeSHA256(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else {
            fatalError("Failed to encode string as UTF-8")
        }
        return computeSHA256(data)
    }

    /// Verify that the data matches the expected hash.
    public static func verifyHash(_ data: Data, matches expectedHash: String) -> Bool {
        let computedHash = computeSHA256(data)
        return computedHash == expectedHash.lowercased()
    }

    /// The default hash algorithm with version identifier.
    public static let defaultAlgorithm = "sha256:1"

    /// A content-addressable blob with its precomputed hash.
    public struct HashedBlob: Sendable {
        public let content: Data
        public let contentHash: String
        public let algorithm: String

        public init(content: Data, contentHash: String? = nil, algorithm: String? = nil) {
            self.content = content
            self.algorithm = algorithm ?? ContentHashing.defaultAlgorithm
            self.contentHash = contentHash ?? computeSHA256(content)
        }

        /// Convenience initializer for string content.
        public init(string: String, contentHash: String? = nil, algorithm: String? = nil) {
            guard let data = string.data(using: .utf8) else {
                fatalError("Failed to encode string as UTF-8")
            }
            self.init(content: data, contentHash: contentHash, algorithm: algorithm)
        }

        /// Create a content-addressed artifact from this blob.
        public func toContentAddressedArtifact(
            isCompressed: Bool = false,
            firstSeenAt: Date = Date(),
            referenceCount: Int = 1
        ) -> ContentAddressedArtifact {
            return ContentAddressedArtifact(
                contentHash: contentHash,
                hashAlgorithm: algorithm,
                payload: content,
                payloadSize: content.count,
                isCompressed: isCompressed,
                firstSeenAt: firstSeenAt,
                referenceCount: referenceCount
            )
        }

        /// Create a reference to this content-addressed artifact.
        public func toReference(
            parentKey: String,
            parentType: String,
            createdAt: Date = Date(),
            metadata: Data? = nil,
            referenceID: String? = nil
        ) -> ArtifactReference {
            return ArtifactReference(
                referenceID: referenceID ?? UUID().uuidString,
                contentHash: contentHash,
                parentKey: parentKey,
                parentType: parentType,
                createdAt: createdAt,
                metadata: metadata
            )
        }
    }
}

/// Protocol for types that can be converted to content-addressed storage.
public protocol ContentAddressable {
    /// Convert this value to a hashed blob for storage.
    func toHashedBlob() throws -> ContentHashing.HashedBlob
}

/// Extension for common types implement ContentAddressable.
extension String: ContentAddressable {
    public func toHashedBlob() throws -> ContentHashing.HashedBlob {
        return ContentHashing.HashedBlob(string: self)
    }
}

extension Data: ContentAddressable {
    public func toHashedBlob() throws -> ContentHashing.HashedBlob {
        return ContentHashing.HashedBlob(content: self)
    }
}

extension Array: ContentAddressable where Element: Encodable {
    public func toHashedBlob() throws -> ContentHashing.HashedBlob {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(self)
        return ContentHashing.HashedBlob(content: data)
    }
}

/// Utility actor for streaming large content to compute hash without loading everything into memory.
public actor StreamHashing {

    /// Compute SHA256 hash of a file's content.
    public static func computeFileHash(url: URL) throws -> String {
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }

        var hasher = SHA256()
        while true {
            let chunk = fileHandle.readData(ofLength: 1024 * 1024) // 1MB chunks
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }

        let hash = hasher.finalize()
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Stream content to compute hash while persisting the blob.
    public static func storeAndHash(
        _ input: URL,
        to store: ContentAddressedStore,
        parentKey: String,
        parentType: String
    ) async throws -> (artifact: ContentAddressedArtifact, reference: ArtifactReference) {
        let hash = try computeFileHash(url: input)

        // Read the full file content (in production, could use streaming)
        let data = try Data(contentsOf: input)

        // Create content-addressed artifact
        let artifact = ContentAddressedArtifact(
            contentHash: hash,
            hashAlgorithm: ContentHashing.defaultAlgorithm,
            payload: data,
            payloadSize: data.count,
            isCompressed: false,
            firstSeenAt: Date(),
            referenceCount: 0 // Will be incremented when reference is created
        )

        // Store artifact
        let storedArtifact = try await store.storeArtifact(artifact)

        // Create reference
        let reference = ArtifactReference(
            referenceID: UUID().uuidString,
            contentHash: hash,
            parentKey: parentKey,
            parentType: parentType,
            createdAt: Date(),
            metadata: nil
        )

        let storedReference = try await store.createReference(reference)

        return (storedArtifact, storedReference)
    }
}
