//
//  RetrievalService.swift
//  HarmoniaModule
//
//  [Brief description of file purpose]
//

import AnigmaCore
import Foundation
import DatabaseCore
import CryptoKit

public final class RetrievalService: Sendable {
    private let db: any DatabaseExecutor
    private let policyGate: PolicyGate
    private let evidence: GovernedEvidenceRecorder
    private let loopBreaker: ToolCallLoopBreaker
    private let embedder: EmbeddingQueryProvider?

    public init(
        db: any DatabaseExecutor,
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
