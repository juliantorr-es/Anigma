//
//  RetrievalService.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

import Foundation
import HarmoniaCore
import AnigmaPrimitives
import InferenceCore
import AnigmaCore
@preconcurrency import Foundation
import DatabaseCore
@preconcurrency import CryptoKit

public final class RetrievalService: Sendable {
    private let db: any DatabaseAuthority
    private let policyGate: PolicyGate
    private let evidence: GovernedEvidenceRecorder
    private let loopBreaker: ToolCallLoopBreaker
    private let embedder: EmbeddingQueryProvider?

    public init(
        db: any DatabaseAuthority,
        policyGate: PolicyGate,
        evidence: GovernedEvidenceRecorder,
        loopBreaker: ToolCallLoopBreaker,
        embedder: EmbeddingQueryProvider?
    ) {
        self.db = db
        self.policyGate = policyGate
        self.evidence = evidence
        self.loopBreaker = loopBreaker
        self.embedder = embedder
    }

    public func retrieve(_ request: RetrievalRequest) async throws -> [RetrievalHit] {
        let query = HybridRetrieveQuery(db: db, embedder: embedder)
        return try await query.run(request)
    }
}
