//
//  PDFExtractContract.swift
//  AnigmaCore
//
//  Contract definition for PDFExtractContract in AnigmaCore.
//

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import FoundationContracts
import EvidenceContracts
import Foundation
/// Extracted text item linked to a region.
public struct PDFExtractedItem: Codable, Sendable, Hashable {
    public let regionID: String
    public let kind: String
    public let content: String

    public init(regionID: String, kind: String, content: String) {
        self.regionID = regionID
        self.kind = kind
        self.content = content
    }
}

/// Extraction output containing regions and extracted items.
public struct PDFExtractionOutput: Codable, Sendable {
    public let regions: [PDFPageRegion]
    public let items: [PDFExtractedItem]

    public init(regions: [PDFPageRegion], items: [PDFExtractedItem]) {
        self.regions = regions
        self.items = items
    }
}

/// Deterministic extractor that emits placeholder content for each region.
public enum PDFExtractContract: ContractSpec {
    public static let id = ContractID(name: "pipeline.pdf.extract", major: 1, minor: 0, schemaHash: "v1.0")
    public static let inputSchemaVersion = 1
    public static let outputSchemaVersion = 1

    public static func validate(output: ArtifactEnvelope<PDFExtractionOutput>) throws {
        guard !output.payload.items.isEmpty else {
            throw ContractValidationError.invalidSchema(
                code: "pdf.extract.empty_items",
                message: "Extractor produced no items"
            )
        }

        let regionIDs = Set(output.payload.regions.map(\.id))
        for item in output.payload.items {
            if !regionIDs.contains(item.regionID) {
                throw ContractValidationError.invalidSchema(
                    code: "pdf.extract.orphan_item",
                    message: "Item references unknown region \(item.regionID)"
                )
            }
        }
    }

    public static func execute(
        input: ArtifactEnvelope<PDFRegionMap>,
        ctx: ContractContext
    ) async throws -> ArtifactEnvelope<PDFExtractionOutput> {
        let parser: PDFProcessing
        do {
            parser = try PDFProcessing(data: input.payload.blob.rawData)
        } catch {
            throw ContractExecutionError.underlying(
                code: "pdf.extract.invalid_document",
                message: "Unable to load PDF for extraction: \(error.localizedDescription)"
            )
        }

        let items = input.payload.regions.map { region -> PDFExtractedItem in
            let text: String
            do {
                text = try parser.text(forPage: region.pageIndex)
            } catch {
                text = ""
            }

            return PDFExtractedItem(
                regionID: region.id,
                kind: "text",
                content: text
            )
        }

        let evidenceRefs = input.payload.regions.map { region in
            EvidenceRef(
                kind: .span,
                contentHash: nil,
                sourceArtifactID: region.sourceBlobID,
                page: region.pageIndex,
                boundingBox: region.boundingBox,
                note: "extracted-text-\(region.id)"
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
            evidenceRefs: evidenceRefs,
            metrics: metrics
        )

        let payload = PDFExtractionOutput(regions: input.payload.regions, items: items)
        return ArtifactEnvelope(
            schemaVersion: outputSchemaVersion,
            payload: payload,
            evidenceRefs: evidenceRefs,
            metrics: metrics,
            receipt: receipt
        )
    }
}
