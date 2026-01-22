import Foundation
import AnigmaCore
import AnigmaPrimitives
import CryptoKit

extension ContextumDatabase {
    /// Generate a stable chunk ID based on content and structural context.
    public func generateStableChunkId(
        docHash: String,
        anchor: String,
        offset: Int,
        length: Int,
        policyHash: String
    ) -> String {
        let input = "\(docHash):\(anchor):\(offset):\(length):\(policyHash)"
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Incremental Indexing: Check if a document section needs re-indexing.
    public func shouldReindex(docId: String, sectionAnchor: String, currentContentHash: String) async throws -> Bool {
        // Query the database for the last indexed hash of this section
        // Placeholder for real DB query
        return true
    }
    
    /// Update the index version for a document.
    public func updateDocumentIndexVersion(docId: String) async throws {
        // Increment document version and global index version
    }
}

public struct DocumentDigest: Sendable, Codable {
    public let docId: String
    public let structuralAnchors: [String: String] // anchor -> contentHash
    public let globalHash: String
}
