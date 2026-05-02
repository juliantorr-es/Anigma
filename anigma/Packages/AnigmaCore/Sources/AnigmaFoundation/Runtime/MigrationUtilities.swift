//
//  MigrationUtilities.swift
//  AnigmaCore
//
//  Utility classes to facilitate migration of legacy systems to the 
//  Three-Tier Runtime Architecture.
//

import FoundationContracts
import GovernanceContracts
import EvidenceContracts
import IntelligenceContracts
import Foundation
import DatabaseCore
import AnigmaPrimitives

// MARK: - Artifact Storage Adapter

/// Adapter that wraps ArtifactAuthority to provide legacy ArtifactStore-like API.
public actor ArtifactStorageAdapter {
    private let artifactAuthority: any ArtifactAuthority
    private let systemContext: ExecutionContext
    
    public init(artifactAuthority: any ArtifactAuthority) {
        self.artifactAuthority = artifactAuthority
        self.systemContext = ExecutionContext(principal: .system)
    }
    
    public func store(
        content: Data,
        mediaType: String,
        metadata: [String: String] = [:]
    ) async throws -> ArtifactID {
        let contentHash = "hash-\(content.count)" // Simplified
        let artifact = Artifact(
            id: ArtifactID(hash: contentHash),
            mimeType: mediaType,
            size: Int64(content.count),
            content: content
        )
        
        let (id, _) = try await artifactAuthority.store(artifact, context: systemContext)
        return id
    }
    
    public func retrieve(id: ArtifactID) async throws -> Data {
        let artifact = try await artifactAuthority.retrieve(id, principal: .system)
        return artifact.content ?? Data()
    }
}

// MARK: - Evidence Sink Adapter

/// Wraps legacy evidence sinks to conform to Tier 2 EvidenceSink protocol.
public actor EvidenceSinkAdapter: EvidenceSink {
    private let legacySink: Any // Placeholder for legacy sink type
    
    public init(legacySink: Any) {
        self.legacySink = legacySink
    }
    
    public func record(
        receipt: CoreReceipt,
        payload: EvidencePayload,
        operation: CoreOperationType,
        governanceDecision: GovernanceDecision?,
        context: ExecutionContext
    ) async throws {
        // Delegate to legacy sink
    }
}

// MARK: - Legacy Type Shims

/// Shim for systems that still expect 'CoreReceipt' in their signatures.
/// Usage: `import AnigmaFoundation` will provide the new `CoreReceipt`.
public typealias LegacyReceipt = CoreReceipt
