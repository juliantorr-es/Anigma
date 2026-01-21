//
//  PDFSegmentContract.swift
//  AnigmaCore
//
//  Contract definition for PDFSegmentContract in AnigmaCore.
//

import ContractsCore
import Foundation

/// Region identified on a PDF page.
public struct PDFPageRegion: Codable, Sendable, Hashable {
    public let id: String
    public let pageIndex: Int
    public let boundingBox: BoundingBoxRef
    public let sourceBlobID: String

    public init(id: String, pageIndex: Int, boundingBox: BoundingBoxRef, sourceBlobID: String) {
        self.id = id
        self.pageIndex = pageIndex
        self.boundingBox = boundingBox
        self.sourceBlobID = sourceBlobID
    }
}

/// Deterministic region map produced by segmentation.
public struct PDFRegionMap: Codable, Sendable {
    public let blob: PDFBlobArtifact
    public let regions: [PDFPageRegion]

    public init(blob: PDFBlobArtifact, regions: [PDFPageRegion]) {
        self.blob = blob
        self.regions = regions
    }
}

/// Segmentation contract that produces one region per page deterministically.
public enum PDFSegmentContract: ContractSpec {
    public static let id = ContractID(name: "pipeline.pdf.segment", major: 1, minor: 0, schemaHash: "v1.0")
    public static let inputSchemaVersion = 1
    public static let outputSchemaVersion = 1

    public static func validate(output: ArtifactEnvelope<PDFRegionMap>) throws {
        guard !output.payload.regions.isEmpty else {
            throw ContractValidationError.invalidSchema(
                code: "pdf.segment.empty_regions",
                message: "No regions produced during segmentation"
            )
        }

        let pageCount = output.payload.blob.pageCount
        if output.payload.regions.count != pageCount {
            throw ContractValidationError.invalidSchema(
                code: "pdf.segment.region_count_mismatch",
                message: "Expected \(pageCount) regions, got \(output.payload.regions.count)"
            )
        }

        let ids = Set(output.payload.regions.map(\.id))
        if ids.count != output.payload.regions.count {
            throw ContractValidationError.invalidSchema(
                code: "pdf.segment.duplicate_region_ids",
                message: "Duplicate region identifiers detected"
            )
        }
    }

    public static func execute(
        input: ArtifactEnvelope<PDFBlobArtifact>,
        ctx: ContractContext
    ) async throws -> ArtifactEnvelope<PDFRegionMap> {
        let parser: PDFProcessing
        do {
            parser = try PDFProcessing(data: input.payload.rawData)
        } catch {
            throw ContractExecutionError.underlying(
                code: "pdf.segment.invalid_document",
                message: "Unable to parse PDF for segmentation: \(error.localizedDescription)"
            )
        }

        let pageCount = parser.pageCount
        guard pageCount == input.payload.pageCount else {
            throw ContractExecutionError.underlying(
                code: "pdf.segment.page_count_mismatch",
                message: "Document contains \(pageCount) pages but blob reports \(input.payload.pageCount)"
            )
        }

        var regions: [PDFPageRegion] = []
        for index in 0..<pageCount {
            let boundingBox = try parser.boundingBox(forPage: index)
            regions.append(
                PDFPageRegion(
                    id: "\(input.payload.blobID)-page-\(index)",
                    pageIndex: index,
                    boundingBox: boundingBox,
                    sourceBlobID: input.payload.blobID
                )
            )
        }

        let evidenceRefs = regions.map { region in
            EvidenceRef(
                kind: .span,
                contentHash: nil,
                sourceArtifactID: region.sourceBlobID,
                page: region.pageIndex,
                boundingBox: region.boundingBox,
                note: "segmentation-\(region.pageIndex)"
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

        let map = PDFRegionMap(blob: input.payload, regions: regions)
        return ArtifactEnvelope(
            schemaVersion: outputSchemaVersion,
            payload: map,
            evidenceRefs: evidenceRefs,
            metrics: metrics,
            receipt: receipt
        )
    }
}
