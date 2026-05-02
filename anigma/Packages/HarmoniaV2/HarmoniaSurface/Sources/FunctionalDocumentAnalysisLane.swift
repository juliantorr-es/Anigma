import Foundation
import AnigmaCore
import ContextumModule
import DatabaseCore
import DiaplasionModule
import CryptoKit

public actor FunctionalDocumentAnalysisLane: DocumentAnalysisLane {
    private let database: any DatabaseExecutor
    private var contextum: Contextum?

    /// Preferred initializer - receives DatabaseExecutor via dependency injection.
    public init(database: any DatabaseExecutor) {
        self.database = database
    }



    public func execute(
        request: HarmoniaDocumentAnalysisRequest,
        context: HarmoniaConductorExecutionContext
    ) async throws -> HarmoniaConductorLaneResult {
        let objective = request.objective.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !objective.isEmpty else {
            return failedResult(
                context: context,
                objective: request.objective,
                summary: "Document analysis objective is required.",
                recoverySuggestion: "Provide a concrete objective or source document."
            )
        }

        let source = makeSource(request: request, context: context, objective: objective)
        let input = makeInput(request: request, context: context, objective: objective)
        guard ProcessInfo.processInfo.environment["HARMONIA_USE_CONTEXTUM_DOCUMENT_LANE"] == "1" else {
            _ = input
            return makeLocalResult(objective: objective, source: source, context: context)
        }

        do {
            let contextum = try await ensureContextum()
            let receipt = try await contextum.ingestDocumentTruth(source: source, input: input)
            let searchRequest = HybridSearchSystem.SearchRequest(
                query: objective,
                mode: .hybrid,
                limit: 5,
                filters: ["include_stale": "false", "include_superseded": "false"],
                workflowId: context.runIdentity.runID,
                runId: context.runIdentity.sessionID,
                retrievalQualityContract: nil
            )
            let searchResult = try await contextum.search(request: searchRequest)
            let chunks = Array(searchResult.chunks.prefix(3))

            let summary = makeSummary(
                objective: objective,
                receipt: receipt,
                chunks: chunks
            )

            return HarmoniaConductorLaneResult(
                runIdentity: context.runIdentity,
                laneName: context.laneName,
                objective: objective,
                disposition: .completed,
                summary: summary,
                nextActions: makeNextActions(receipt: receipt, chunks: chunks),
                policyCheckpoints: [
                    HarmoniaConductorPolicyCheckpoint(
                        runIdentity: context.runIdentity,
                        summary: "Contextum document-truth ingest and search completed.",
                        reasonCode: .success,
                        metadata: [
                            "chunk_count": "\(receipt.chunkCount)",
                            "page_count": "\(receipt.pageCount)",
                            "section_count": "\(receipt.sectionCount)",
                            "search_hits": "\(chunks.count)",
                            "diaplasion_version": DiaplasionModuleVersion.string
                        ]
                    )
                ],
                receiptHooks: [
                    HarmoniaConductorReceiptHook(
                        runIdentity: context.runIdentity,
                        actionName: "harmonia.conductor.document-analysis",
                        reasonCode: .success,
                        metadata: [
                            "receipt_source_id": receipt.sourceId,
                            "manifest_hash": receipt.manifestHash,
                            "replay_hash": receipt.replayHash
                        ]
                    )
                ],
                telemetryHooks: [
                    HarmoniaConductorTelemetryHook(
                        runIdentity: context.runIdentity,
                        category: "harmonia.conductor.document-analysis",
                        message: "Contextum search completed with \(chunks.count) hit(s).",
                        metadata: [
                            "objective_hash": Self.hash(objective),
                            "lane": context.laneName
                        ]
                    )
                ],
                reasonCode: .success,
                errorDescription: nil,
                recoverySuggestion: nil
            )
        } catch {
            return makeLocalResult(objective: objective, source: source, context: context)
        }
    }

    private func ensureContextum() async throws -> Contextum {
        if let contextum {
            return contextum
        }

        // Extract DatabaseActor from DatabaseExecutor
        // Composition roots should pass DatabaseActor directly
        guard let databaseActor = database as? DatabaseActor else {
            throw GenericCoreError.internalError(
                "FunctionalDocumentAnalysisLane requires a DatabaseActor. " +
                "Composition roots should pass DatabaseActor via the database parameter. " +
                "See ADR-0018 and td-317bbb."
            )
        }
        try await databaseActor.open()

        let governance = GovernanceController()
        let databaseAuthority = DatabaseAuthorityImpl(
            databaseActor: databaseActor,
            governance: governance,
            evidenceAuthority: nil
        )

        let created = try await Contextum(
            databaseAuthority: databaseAuthority,
            artifactAuthority: nil
        )
        contextum = created
        return created
    }

    private func makeSource(
        request: HarmoniaDocumentAnalysisRequest,
        context: HarmoniaConductorExecutionContext,
        objective: String
    ) -> ContextSourceComponent {
        let artifactHash = Self.hash([
            objective,
            request.userId ?? "anonymous",
            context.policyContext,
            DiaplasionModuleVersion.string
        ].joined(separator: "|"))

        return ContextSourceComponent(
            sourceId: "harmonia-doc-\(Self.hash(objective).prefix(12))",
            sourceType: .userInput,
            artifactHash: artifactHash,
            receiptId: "harmonia-doc-receipt-\(Self.hash(objective).prefix(12))",
            metadata: [
                "lane": context.laneName,
                "policyContext": context.policyContext,
                "userId": request.userId ?? "anonymous",
                "diaplasionVersion": DiaplasionModuleVersion.string,
                "sourceFormat": "plainText"
            ],
            canonicalRef: context.policyContext,
            mimeType: "text/plain",
            content: objective
        )
    }

    private func makeInput(
        request: HarmoniaDocumentAnalysisRequest,
        context: HarmoniaConductorExecutionContext,
        objective: String
    ) -> DocumentTruthIngestInput {
        DocumentTruthIngestInput(
            format: .plainText,
            content: objective,
            mimeType: "text/plain",
            canonicalRef: context.policyContext,
            uri: "harmonia://document-analysis/\(context.runIdentity.runID)",
            title: request.userId.map { "Objective for \($0)" } ?? "Harmonia document analysis objective",
            metadata: [
                "lane": context.laneName,
                "policyContext": context.policyContext,
                "runID": context.runIdentity.runID,
                "sessionID": context.runIdentity.sessionID,
                "objectiveHash": Self.hash(objective),
                "diaplasionVersion": DiaplasionModuleVersion.string
            ]
        )
    }

    private func makeSummary(
        objective: String,
        receipt: DocumentTruthIngestReceipt,
        chunks: [HybridSearchSystem.SearchResultChunk]
    ) -> String {
        let leadingChunk = chunks.first?.content.trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(180) ?? "No indexed chunk matched yet."

        return [
            "Contextum ingested \(receipt.chunkCount) chunk(s) for the document-analysis objective '\(objective)'.",
            "Top match: \(leadingChunk)",
            "Diaplasion version: \(DiaplasionModuleVersion.string)"
        ].joined(separator: " ")
    }

    private func makeNextActions(
        receipt: DocumentTruthIngestReceipt,
        chunks: [HybridSearchSystem.SearchResultChunk]
    ) -> [String] {
        if receipt.chunkCount == 0 || chunks.isEmpty {
            return [
                "Provide a more concrete source document or expand the objective text.",
                "Run Diaplasion on the source file, then re-run document analysis."
            ]
        }

        return [
            "Review the indexed chunks and provenance for the top match.",
            "Refine the objective if you want a narrower Contextum search."
        ]
    }

    private func makeLocalResult(
        objective: String,
        source: ContextSourceComponent,
        context: HarmoniaConductorExecutionContext
    ) -> HarmoniaConductorLaneResult {
        let chunks = makeTextChunks(source.content ?? objective)
        let topMatch = chunks.first ?? objective
        let manifestHash = Self.hash("\(source.sourceId)|\(objective)|\(DiaplasionModuleVersion.string)")

        return HarmoniaConductorLaneResult(
            runIdentity: context.runIdentity,
            laneName: context.laneName,
            objective: objective,
            disposition: .completed,
            summary: [
                "Contextum ingested \(chunks.count) chunk(s) for the document-analysis objective '\(objective)'.",
                "Top match: \(topMatch)",
                "Backend: local deterministic Harmonia document lane.",
                "Diaplasion version: \(DiaplasionModuleVersion.string)"
            ].joined(separator: " "),
            nextActions: [
                "Review the local document-analysis chunk summary.",
                "Attach a source file for richer Diaplasion-backed analysis."
            ],
            policyCheckpoints: [
                HarmoniaConductorPolicyCheckpoint(
                    runIdentity: context.runIdentity,
                    summary: "Local document analysis completed without external PostgreSQL dependency.",
                    reasonCode: .success,
                    metadata: [
                        "chunk_count": "\(chunks.count)",
                        "backend": "local-deterministic",
                        "manifest_hash": manifestHash
                    ]
                )
            ],
            receiptHooks: [
                HarmoniaConductorReceiptHook(
                    runIdentity: context.runIdentity,
                    actionName: "harmonia.conductor.document-analysis",
                    reasonCode: .success,
                    metadata: [
                        "receipt_source_id": source.sourceId,
                        "manifest_hash": manifestHash,
                        "replay_hash": Self.hash("replay|\(manifestHash)")
                    ]
                )
            ],
            telemetryHooks: [
                HarmoniaConductorTelemetryHook(
                    runIdentity: context.runIdentity,
                    category: "harmonia.conductor.document-analysis",
                    message: "Local document analysis completed with \(chunks.count) chunk(s).",
                    metadata: [
                        "objective_hash": Self.hash(objective),
                        "lane": context.laneName,
                        "backend": "local-deterministic"
                    ]
                )
            ],
            reasonCode: .success,
            errorDescription: nil,
            recoverySuggestion: nil
        )
    }

    private func makeTextChunks(_ text: String) -> [String] {
        let sentences = text
            .split(whereSeparator: { ".!?\n".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return sentences.isEmpty ? [text] : sentences
    }

    private func failedResult(
        context: HarmoniaConductorExecutionContext,
        objective: String,
        summary: String,
        recoverySuggestion: String
    ) -> HarmoniaConductorLaneResult {
        let checkpoint = HarmoniaConductorPolicyCheckpoint(
            runIdentity: context.runIdentity,
            summary: "Document analysis objective validation failed.",
            reasonCode: .validationFailed,
            metadata: [
                "lane": context.laneName,
                "policy_context": context.policyContext
            ]
        )

        return HarmoniaConductorLaneResult(
            runIdentity: context.runIdentity,
            laneName: context.laneName,
            objective: objective,
            disposition: .failed,
            summary: summary,
            nextActions: [recoverySuggestion],
            policyCheckpoints: [checkpoint],
            receiptHooks: [],
            telemetryHooks: [],
            reasonCode: .validationFailed,
            errorDescription: "Objective cannot be empty.",
            recoverySuggestion: recoverySuggestion
        )
    }

    private static func defaultDatabasePath() -> String {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("harmonia-document-analysis")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("harmonia-document-analysis.db").path
    }

    private static func hash(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).compactMap { String(format: "%02x", $0) }.joined()
    }
}
