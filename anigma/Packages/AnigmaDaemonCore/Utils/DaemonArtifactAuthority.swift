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
        _ artifact: Artifact,
        context: ExecutionContext
    ) async throws -> (id: ArtifactID, receipt: Receipt) {
        let vaultKind: VaultArtifactKind = switch artifact.kind {
        case .original: .original
        case .derived: .derived
        case .metadata: .metadata
        case .receipt: .receipt
        }
        
        let ref = try await vault.ingest(
            data: artifact.content ?? Data(),
            kind: vaultKind,
            mime: artifact.mimeType,
            actorId: context.principal.identifier
        )
        
        let artifactId = ArtifactID(hash: ref.sha256Hex)
        
        // Create a mock receipt for now, ideally we'd link to execution evidence
        let receipt = Receipt(
            receiptID: UUID().uuidString,
            actionName: "artifact.store",
            authority: "DaemonArtifactAuthority",
            decision: .allowed,
            reasonCode: "STORED",
            timestamp: Date()
        )
        
        return (artifactId, receipt)
    }
    
    public func retrieve(
        _ id: ArtifactID,
        principal: Principal
    ) async throws -> Artifact {
        let data = try await vault.open(
            hash: id.hash,
            actorId: principal.identifier
        )
        
        // In a real implementation, we'd fetch metadata from indexStore
        // For now, return basic artifact
        return Artifact(
            id: id,
            kind: .original,
            mimeType: "application/octet-stream",
            content: data,
            timestamp: Date()
        )
    }
    
    public func list(
        filter: ArtifactFilter,
        principal: Principal
    ) async throws -> [ArtifactMetadata] {
        let refs = try await vault.listArtifacts(actorId: principal.identifier)
        
        return refs.map { ref in
            ArtifactMetadata(
                id: ArtifactID(hash: ref.sha256Hex),
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
        context: ExecutionContext
    ) async throws -> Receipt {
        // VaultAuthority doesn't have a simple delete by hash yet (only GC)
        // For now, throw error
        throw SecretAuthorityError.unhandledError(status: -1)
    }
}
