//
//  DevelopumHistoryService.swift
//  DevelopumModule
//
//  Service for tracking and analyzing chunk-based document history.
//

import Foundation
import AnigmaCore

public actor DevelopumHistoryService {
    private let databaseService: DevelopumDatabaseService
    
    public init(databaseService: DevelopumDatabaseService) {
        self.databaseService = databaseService
    }
    
    /// Returns the history of a virtual document.
    public func getDocumentHistory(repoId: UUID, filePath: String) async throws -> [VirtualDocumentRecord] {
        return try await databaseService.getVirtualDocumentHistory(repoId: repoId, filePath: filePath)
    }
    
    /// Traces the genealogy of a chunk at a specific index.
    /// Returns the sequence of chunks that occupied this index over time.
    public func traceChunkGenealogy(repoId: UUID, filePath: String, chunkIndex: Int) async throws -> [ChunkHistoryNode] {
        let history = try await getDocumentHistory(repoId: repoId, filePath: filePath)
        
        return history.compactMap { doc -> ChunkHistoryNode? in
            guard chunkIndex < doc.chunks.count else { return nil }
            return ChunkHistoryNode(
                versionId: doc.id,
                timestamp: doc.lastModified,
                chunkHash: doc.chunks[chunkIndex],
                chunkIndex: chunkIndex // Assuming simple index tracking for now
            )
        }
    }
    
    /// Finds the first version where a specific chunk hash appeared in the document.
    public func blameChunk(repoId: UUID, filePath: String, chunkHash: String) async throws -> VirtualDocumentRecord? {
        let history = try await getDocumentHistory(repoId: repoId, filePath: filePath)
        
        // Walk backwards from oldest to newest
        for doc in history.reversed() {
            if doc.chunks.contains(chunkHash) {
                return doc
            }
        }
        return nil
    }
}

public struct ChunkHistoryNode: Sendable {
    public let versionId: UUID
    public let timestamp: Date
    public let chunkHash: String
    public let chunkIndex: Int
    
    public init(versionId: UUID, timestamp: Date, chunkHash: String, chunkIndex: Int) {
        self.versionId = versionId
        self.timestamp = timestamp
        self.chunkHash = chunkHash
        self.chunkIndex = chunkIndex
    }
}
