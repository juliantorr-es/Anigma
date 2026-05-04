//
//  PDFIngestContract.swift
//  AnigmaCore
//
//  Contract definition for PDFIngestContract in AnigmaCore.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import LayoutEngineContracts
import FoundationContracts
import EvidenceContracts
import Foundation

/// Represents a raw PDF blob for ingestion into the pipeline.
public struct PDFIngestInput: Codable, Sendable {
    public let filePath: String // Path to the PDF file
    // Potentially add rawData: Data? for in-memory PDFs
}

/// Contract for ingesting a PDF file and creating a PDFBlobArtifact.
public enum PDFIngestContract: SaturatedContractSpec {
    public static let id = ContractID(name: "pipeline.pdf.ingest", major: 1, minor: 0, schemaHash: "v1.0")
    public typealias Input = PDFIngestInput
    public typealias Output = PDFBlobArtifact
    public static let inputSchemaVersion = 1
    public static let outputSchemaVersion = 1
    public static var preferredLane: HardwareLane { .evidence }

    public static func validate(output: PDFBlobArtifact) throws {
        guard !output.blobID.isEmpty else {
            throw ContractValidationError.invalidSchema(code: "pdf.ingest.empty_id", message: "PDF blob ID cannot be empty.")
        }
        guard output.pageCount > 0 else {
            throw ContractValidationError.invalidSchema(code: "pdf.ingest.invalid_page_count", message: "PDF page count must be greater than 0.")
        }
    }

    public static func execute(input: ArtifactEnvelope<PDFIngestInput>, ctx: ContractContext) async throws -> ArtifactEnvelope<PDFBlobArtifact> {
        let filePath = input.payload.filePath
        let fileURL = URL(fileURLWithPath: filePath)
        let data = try Data(contentsOf: fileURL)

        let parser: PDFProcessing
        do {
            parser = try PDFProcessing(data: data)
        } catch {
            throw ContractExecutionError.underlying(
                code: "pdf.ingest.invalid_document",
                message: "Failed to parse PDF data: \(error.localizedDescription)"
            )
        }

        let pageCount = parser.pageCount
        let blobID = ContractKeyDerivation.blake3Hex(data)
        let payload = PDFBlobArtifact(blobID: blobID, pageCount: pageCount, rawData: data)
        let metrics = ExecutionMetrics(
            wallTimeMs: 10, // Simulated execution time
            toolCallCount: 0,
            executor: ctx.executorIdentity
        )
        let receipt = ContractReceipt.placeholder(
            contractID: id,
            runID: ctx.runID,
            sessionID: ctx.sessionID,
            status: .satisfied,
            startedAt: Date(),
            endedAt: Date(),
            metrics: metrics
        )

        return ArtifactEnvelope(
            schemaVersion: outputSchemaVersion,
            payload: payload,
            evidenceRefs: [], // No specific evidence for ingest yet
            metrics: metrics,
            receipt: receipt
        )
    }
}
