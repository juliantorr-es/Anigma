//
//  PDFLayoutExtractContract.swift
//  PDFLayoutExtract
//
//  Contract definition for PDFLayoutExtractContract.
//  This contract performs layout extraction using LayoutEngineCapsule.
//  It depends on LayoutEngineContracts for portable types and LayoutEngineCapsule for execution.

import AnigmaFoundation
import AnigmaGovernance
import AnigmaJobs
import AnigmaPrimitives
import InferenceCore
import LayoutEngineCapsule
import LayoutEngineContracts
import FoundationContracts
import EvidenceContracts
import Foundation

/// Deterministic layout extractor that uses LayoutEngineCapsule.
public enum PDFLayoutExtractContract: ContractSpec {
    public static let id = ContractID(name: "pipeline.pdf.layout_extract", major: 1, minor: 0, schemaHash: "v1.0")
    public static let inputSchemaVersion = 1
    public static let outputSchemaVersion = 1
    
    public static func validate(output: ArtifactEnvelope<PDFLayoutOutput>) throws {
        guard !output.payload.pages.isEmpty else {
            throw ContractValidationError.invalidSchema(
                code: "pdf.layout_extract.empty_pages",
                message: "Layout extractor produced no pages"
            )
        }
        
        for (idx, page) in output.payload.pages.enumerated() {
            if page.segments.isEmpty && page.tables.isEmpty && page.figures.isEmpty && page.images.isEmpty {
                throw ContractValidationError.invalidSchema(
                    code: "pdf.layout_extract.empty_page",
                    message: "Page \(idx) contains no segments, tables, figures, or images"
                )
            }
        }
    }
    
    public static func execute(
        input: ArtifactEnvelope<PDFBlobArtifact>,
        ctx: ContractContext
    ) async throws -> ArtifactEnvelope<PDFLayoutOutput> {
        let startTime = Date()
        let config = LayoutEngineConfig(determinismTier: 1)
        let pageLayouts: [PageLayout]
        do {
            pageLayouts = try LayoutEngineCapsuleWrapper.analyzePDF(input.payload.rawData, config: config)
        } catch {
            throw ContractExecutionError.underlying(
                code: "pdf.layout_extract.capsule_error",
                message: "Layout engine capsule failed: \(error.localizedDescription)"
            )
        }
        
        let pages = pageLayouts.map { pageLayout in
            PDFPageLayout(
                pageIndex: pageLayout.pageIndex,
                segments: pageLayout.segments.map { segment in
                    PDFLayoutSegment(
                        boundingBox: BoundingBoxRef(
                            x: segment.bbox.left,
                            y: segment.bbox.top,
                            width: segment.bbox.right - segment.bbox.left,
                            height: segment.bbox.bottom - segment.bbox.top
                        ),
                        text: segment.text,
                        fontName: segment.fontName,
                        fontSize: segment.fontSize,
                        fontFlags: segment.fontFlags,
                        colorRGB: segment.colorRGB
                    )
                },
                tables: pageLayout.tableBBoxes.map { bbox in
                    PDFLayoutTable(
                        boundingBox: BoundingBoxRef(
                            x: bbox.left,
                            y: bbox.top,
                            width: bbox.right - bbox.left,
                            height: bbox.bottom - bbox.top
                        )
                    )
                },
                figures: pageLayout.figureBBoxes.map { bbox in
                    PDFLayoutFigure(
                        boundingBox: BoundingBoxRef(
                            x: bbox.left,
                            y: bbox.top,
                            width: bbox.right - bbox.left,
                            height: bbox.bottom - bbox.top
                        )
                    )
                },
                images: pageLayout.images.map { image in
                    PDFLayoutImage(
                        boundingBox: BoundingBoxRef(
                            x: image.bbox.left,
                            y: image.bbox.top,
                            width: image.bbox.right - image.bbox.left,
                            height: image.bbox.bottom - image.bbox.top
                        ),
                        rawData: image.rawData,
                        width: image.width,
                        height: image.height,
                        horizontalDPI: image.horizontalDPI,
                        verticalDPI: image.verticalDPI,
                        bitsPerPixel: image.bitsPerPixel,
                        colorspace: image.colorspace,
                        filter: image.filter
                    )
                }
            )
        }
        
        let output = PDFLayoutOutput(blobID: input.payload.blobID, pages: pages)
        
        // Generate evidence references for each segment, table, figure, and image
        var evidenceRefs: [EvidenceRef] = []
        for page in pages {
            let pageIndex = Int(page.pageIndex)
            for segment in page.segments {
                evidenceRefs.append(
                    EvidenceRef(
                        kind: .span,
                        contentHash: nil,
                        sourceArtifactID: input.payload.blobID,
                        page: pageIndex,
                        boundingBox: segment.boundingBox,
                        note: "layout-segment-\(segment.text.prefix(20))"
                    )
                )
            }
            for table in page.tables {
                evidenceRefs.append(
                    EvidenceRef(
                        kind: .span,
                        contentHash: nil,
                        sourceArtifactID: input.payload.blobID,
                        page: pageIndex,
                        boundingBox: table.boundingBox,
                        note: "layout-table"
                    )
                )
            }
            for figure in page.figures {
                evidenceRefs.append(
                    EvidenceRef(
                        kind: .span,
                        contentHash: nil,
                        sourceArtifactID: input.payload.blobID,
                        page: pageIndex,
                        boundingBox: figure.boundingBox,
                        note: "layout-figure"
                    )
                )
            }
            for image in page.images {
                evidenceRefs.append(
                    EvidenceRef(
                        kind: .blob,
                        contentHash: nil,
                        sourceArtifactID: input.payload.blobID,
                        page: pageIndex,
                        boundingBox: image.boundingBox,
                        note: "layout-image"
                    )
                )
            }
        }
        
        let endTime = Date()
        let wallTimeMs = Int64(endTime.timeIntervalSince(startTime) * 1000)
        let metrics = ExecutionMetrics(
            wallTimeMs: wallTimeMs,
            cpuTimeMs: nil,
            promptTokens: nil,
            completionTokens: nil,
            totalTokens: nil,
            toolCallCount: 0,
            retryCount: 0,
            executor: ctx.executorIdentity,
            cacheHit: false
        )
        
        let receipt = ContractReceipt.placeholder(
            contractID: Self.id,
            runID: ctx.runID,
            sessionID: ctx.sessionID,
            status: .satisfied,
            startedAt: startTime,
            endedAt: endTime,
            inputRefs: [],
            outputRefs: [],
            evidenceRefs: evidenceRefs,
            metrics: metrics
        )
        
        return ArtifactEnvelope(
            schemaVersion: outputSchemaVersion,
            payload: output,
            evidenceRefs: evidenceRefs,
            metrics: metrics,
            receipt: receipt
        )
    }
}
