# SURFACE.DiaplasionFullCapability

## Surface Definition

**Surface Name**: DiaplasionFullCapability  
**Authority Boundary**: Capability Modules  
**Implementation Location**: DiaplasionModule (Components/Systems/Pipelines), DiaplasionPipeline, AccessumFlow  
**Lease Required**: Yes - active lease required before cross-module changes

## Surface API

### ECS Inputs
- Entity must include FileComponent (path or URI) or an equivalent text attachment component.
- Entity must include TransformRequestComponent with targetFormats and status.

### Canonical ECS Outputs
- DocumentSourceComponent
- IngestedDocumentComponent (or a text-derived equivalent for non-OCR sources)
- OCRResultComponent (for OCR-required sources or text normalization)
- ChunkedTextComponent
- AccessibleOutputComponent (with OutputReference entries per format)

### Workflow Surface
- DiaplasionModule.register(world:registry:runner:) registers all systems and workflows.
- DiaplasionJobType values are the only supported jobTypeIds.
- DocumentToEPUB, DocumentToBraille, DocumentToAudio, OCROnly, MultiFormat are the canonical workflows.

## Supported Inputs
- PDF
- Images: PNG, JPEG, TIFF, GIF, BMP, HEIC
- DOCX
- RTF
- HTML
- Plain text (TXT)

## Supported Outputs
- epub: reflowable EPUB 3 package
- epubFixedLayout: fixed-layout EPUB package
- brailleReady: BRF and/or PEF
- audioReady: SSML + chapter manifest + optional plain text
- structuredHTML: semantic HTML export
- largePrint: large-print PDF
- taggedPDF: tagged PDF with accessibility metadata

## Concurrency Model
- All public components are Sendable.
- Mutable caches or temp state are actor-isolated.
- No global mutable singletons outside actor boundaries.

## Stop Conditions
- Missing input path or unsupported format adds error component and sets TransformStatus.failed.
- OCR failure adds error component and retry schedule; QA still runs when possible.
- Export failures never produce partial outputs without error metadata.

## Acceptance Tests
- Ingest parity tests for each input format into canonical components.
- Export parity tests for each OutputFormat with OutputReference and hashes.
- CLI vs AccessumFlow parity test using the same fixture.
- OCR error handling test with structured error components and retry rules.

## Migration Plan
1. Align ingestion for docx, rtf, html, txt into canonical components.
2. Replace DiaplasionPipeline placeholder artifacts with ECS workflow outputs.
3. Update AccessumFlow to invoke the same workflows and consume AccessibleOutputComponent.
4. Add tests, close or defer TechDebt items with dates and criteria.

## Evidence Hooks
- OutputReference must include hash, fileSize, and pipeline version.
- DiaplasionTrace must record input hash and output hashes for parity.

---

**Contract Status**: ACTIVE  
**Last Updated**: 2025-01-16  
**Authority**: Capability Modules
