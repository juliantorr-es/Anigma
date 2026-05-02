//
//  DaemonArtifactAuthority.swift
//  AnigmaDaemonCore
//

import Foundation
import AnigmaCore
import AnigmaPrimitives
import StorageCore

/// Adapter for VaultAuthority to conform to ArtifactAuthority.
public actor DaemonArtifactAuthority: ArtifactAuthority {
    private let vault: VaultAuthority
    
    public init(vault: VaultAuthority) {
        self.vault = vault
    }
    
    public func store(
        _ artifact: AnigmaCore.Artifact,
        context: AnigmaCore.ExecutionContext
    ) async throws -> (id: AnigmaCore.ArtifactID, receipt: AnigmaCore.CoreReceipt) {
        let vaultKind = VaultArtifactKind(rawValue: artifact.metadata["kind"] ?? "") ?? .original
        
        let ref = try await vault.ingest(
            data: artifact.content ?? Data(),
            kind: vaultKind,
            mime: artifact.mimeType,
            actorId: context.principal.id
        )

        let artifactId = AnigmaCore.ArtifactID(hash: ref.hashHex)
        
        // Create a mock receipt for now, ideally we'd link to execution evidence
        let receipt = AnigmaCore.CoreReceipt(
            operationType: "artifact.store",
            principal: context.principal,
            outcome: .success,
            summary: "STORED",
            metadata: ["artifact_hash": ref.hashHex],
            contentHash: ref.hashHex
        )
        
        return (artifactId, receipt)
    }
    
    public func retrieve(
        _ id: ArtifactID,
        principal: AnigmaCore.Principal
    ) async throws -> AnigmaCore.Artifact {
        let data = try await vault.open(
            hash: id.hash,
            actorId: principal.id
        )
        
        // In a real implementation, we'd fetch metadata from indexStore
        // For now, return basic artifact
        return AnigmaCore.Artifact(
            id: id,
            mimeType: "application/octet-stream",
            size: Int64(data.count),
            metadata: [:],
            content: data
        )
    }
    
    public func list(
        filter: AnigmaCore.ArtifactFilter,
        principal: AnigmaCore.Principal
    ) async throws -> [AnigmaCore.ArtifactMetadata] {
        let refs = try await vault.listArtifacts(actorId: principal.id)
        
        return refs.map { ref in
            AnigmaCore.ArtifactMetadata(
                id: AnigmaCore.ArtifactID(hash: ref.hashHex),
                mimeType: ref.mime,
                size: Int64(ref.byteLen),
                createdAt: ref.createdAt,
                tags: [],
                metadata: [:]
            )
        }
    }
    
    public func delete(
        _ id: ArtifactID,
        context: AnigmaCore.ExecutionContext
    ) async throws -> AnigmaCore.CoreReceipt {
        // VaultAuthority doesn't have a simple delete by hash yet (only GC)
        // For now, throw error
        throw SecretAuthorityError.unhandledError(status: -1)
    }
}
