//
//  PDFQACheckContract.swift
//  AnigmaCore
//
//  Contract definition for PDFQACheckContract in AnigmaCore.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import FoundationContracts
import EvidenceContracts
import Foundation

/// QA flag surfaced by the PDF QA contract.
public struct PDFQAFlag: Codable, Sendable, Hashable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

/// QA result containing any flags.
public struct PDFQAResult: Codable, Sendable {
    public let flags: [PDFQAFlag]

    public init(flags: [PDFQAFlag]) {
        self.flags = flags
    }
}

/// QA contract that checks extraction invariants and emits deterministic flags.
public enum PDFQACheckContract: ContractSpec {
    public static let id = ContractID(name: "pipeline.pdf.qa", major: 1, minor: 0, schemaHash: "v1.0")
    public static let inputSchemaVersion = 1
    public static let outputSchemaVersion = 1

    public static func validate(output: ArtifactEnvelope<PDFQAResult>) throws {
        // Always valid; QA result is allowed to be empty or contain flags.
    }

    public static func execute(
        input: ArtifactEnvelope<PDFExtractionOutput>,
        ctx: ContractContext
    ) async throws -> ArtifactEnvelope<PDFQAResult> {
        var flags: [PDFQAFlag] = []

        let regionIDs = Set(input.payload.regions.map(\.id))
        if input.evidenceRefs.isEmpty {
            flags.append(PDFQAFlag(code: "pdf.qa.missing_evidence", message: "No evidence references in extraction output"))
        }

        for item in input.payload.items where !regionIDs.contains(item.regionID) {
            flags.append(PDFQAFlag(code: "pdf.qa.orphan_item", message: "Item without matching region: \(item.regionID)"))
        }

        if input.payload.items.count != input.payload.regions.count {
            flags.append(
                PDFQAFlag(
                    code: "pdf.qa.count_mismatch",
                    message: "Expected \(input.payload.regions.count) items, got \(input.payload.items.count)"
                )
            )
        }

        let metrics = ExecutionMetrics(
            wallTimeMs: 0,
            toolCallCount: 0,
            retryCount: 0,
            executor: ctx.executorIdentity
        )

        let receipt = ContractReceipt.placeholder(
            contractID: Self.id,
            runID: ctx.runID,
            sessionID: ctx.sessionID,
            status: .satisfied,
            startedAt: Date(),
            endedAt: Date(),
            inputRefs: [],
            outputRefs: [],
            evidenceRefs: input.evidenceRefs,
            metrics: metrics
        )

        let result = PDFQAResult(flags: flags)
        return ArtifactEnvelope(
            schemaVersion: outputSchemaVersion,
            payload: result,
            evidenceRefs: input.evidenceRefs,
            metrics: metrics,
            receipt: receipt
        )
    }
}
