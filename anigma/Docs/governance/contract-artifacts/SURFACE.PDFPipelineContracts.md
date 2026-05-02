# SURFACE.PDFPipelineContracts

## Surface Definition

**Surface Name**: PDFPipelineContracts  
**Authority Boundary**: Core Governance Layer (AnigmaCore)<br>
**Implementation Location**: `Sources/AnigmaCore/Pipeline/Contracts/` (PDFIngestContract, PDFSegmentContract, PDFExtractContract)  
**Lease Required**: No – contracts live inside the core runtime surface and are governed by PipelineRunner’s job queue.

## Surface API

### Contracts
- `PDFIngestContract`: Accepts `PDFIngestInput` (file path), reads the PDF bytes, extracts page count, and emits `PDFBlobArtifact` containing the raw bytes plus metadata.
- `PDFSegmentContract`: Reads `PDFBlobArtifact.rawData`, materializes per-page `PDFPageRegion` entries with actual bounding boxes, and surfaces `PDFRegionMap`.
- `PDFExtractContract`: Reads the same blob bytes, reuses the page regions, and emits `PDFExtractionOutput` with real extracted text per region.

### Data Surface
- `PDFBlobArtifact`: Now carries `(blobID, pageCount, rawData: Data)` so downstream contracts have deterministic byte access.
- Evidence references emitted by segmentation/extraction link back to the original blob (`sourceArtifactID = blobID`) and include `BoundingBoxRef` metadata.

## Concurrency Model

- All contracts execute inside the `PipelineRunner` actor; PDF parsing happens synchronously inside each contract’s `execute` call.
- `PDFProcessing` confines `PDFKit`/`CGPDFDocument` usage to the calling task and never shares references across tasks, so the contracts remain Sendable.
- The pipeline runner still enforces `strict-concurrency=complete` on `AnigmaCore`.

## Stop Conditions

- Ingest fails with `contract.ingest.invalid_document` when the input file cannot be read or parsed.
- Segmentation fails with `contract.segment.invalid_document` or `contract.segment.page_count_mismatch` if the bytes disagree with the stored metadata.
- Extraction fails with `contract.extract.invalid_document` when the region map cannot be replayed against the PDF bytes.
- Any failure immediately halts that contract run and surfaces `ContractExecutionError` to the job queue for retry/quarantine logic.

## Acceptance Tests

1. Run the PDF pipeline with the new fixture (`Tests/AnigmaCoreTests/Fixtures/sample.pdf`) and assert:
   - `PDFIngestContract` produces a `PDFBlobArtifact` with the fixture’s page count and stored raw bytes.
   - `PDFSegmentContract` emits one `PDFPageRegion` with a `BoundingBoxRef` that matches the page’s media box.
   - `PDFExtractContract` returns at least one `PDFExtractedItem` whose `content` contains “Hello PDF”.
2. PipelineRunner tests must continue to succeed using the seeded artifact (raw bytes + deterministically generated IDs).
3. `PDFQAResult` still validates the evidence references emitted by segmentation/extraction.

## Migration Plan

1. Update any ingest workflows (CLI, PipelineModule helpers) to call `PDFIngestContract` as-is because it now embeds the raw bytes automatically.
2. Downstream consumers remain unaffected: segmentation/extraction read `rawData` from `PDFBlobArtifact` but nothing exposes the extra field externally.
3. Evidence logs now include `segmentation-<page>` and `extracted-text-<region>` notes for audit trails.
4. Run `Scripts/discover-diagnostics.sh` and `Scripts/validate-target.sh AnigmaCore` to ensure new logic compiles cleanly.

---

**Contract Status**: ACTIVE  
**Last Updated**: 2025-12-19  
**Authority**: Core Governance Layer
