# World-Class Document Processor: Analysis & Roadmap

**Date**: 2026-01-13  
**Author**: opencode  
**Status**: Draft for implementation

## Executive Summary

Anigma's current document-processing foundation is robust but incomplete for world-class academia, research, professional, and everyday use. This analysis identifies strengths, gaps, and proposes a phased implementation plan leveraging the existing ECS architecture, capsule strategy, and SegmentIR vision to create a unified, high-performance document intelligence platform.

## 1. Current State Analysis

### 1.1 Core Modules & Capabilities

| Module | Responsibility | Maturity | Notes |
|--------|---------------|----------|-------|
| **DiaplasionModule** | Ingestion → OCR → chunking → accessible export (EPUB, Braille, audio). | ✅ Phase‑2 complete | Uses Apple Vision OCR; supports PDF, images, DOCX, RTF, HTML. |
| **DocumentRenderKit** | Native C‑bridge for high‑performance document rendering. | ✅ Golden (level 5) | Interfaces with `anigma_render.h`. |
| **PDFCapability** (CapabilityCore) | Rendering, text extraction, metadata, merge/split/rotate. | ✅ Protocol defined | PlatformCore implementations exist. |
| **TextShapingCapability** | Font‑based text shaping. | ✅ Protocol defined | Native shim likely needed. |
| **VectorumModule** | Deterministic & MLX‑backed embedding computation, semantic search. | ✅ Core infrastructure | MLX backend stub; deterministic engine works. |
| **AnigmaCore/Pipeline** | AI nodes: DocumentChunker, RAGQuery, Summarize, TextGeneration, Chat. | ✅ Node definitions | Inference via MLWorker; ready for extension. |
| **AccessumModule** | Client‑side OCR/TTS workflows, cloud sync. | ✅ Operator‑shell complete | User‑facing workflows for accessibility. |
| **HarmoniaModule** | Document‑unit database, embeddings, retrieval, tamper‑evidence. | ✅ Deterministic surface complete | SQLite + FTS5 + vector storage. |
| **CathedralModule** | Chain‑of‑custody, audit trails, evidence signing. | ✅ Evidence protocol unified | Forensic‑grade provenance. |
| **ContextumModule** | Indexing, search, retrieval. | ✅ Database layer | Integrated with Vectorum. |
| **CodexModule** | Knowledge and documentation domain. | ✅ Core defined | Can host citation, reference management. |

### 1.2 Strengths

- **ECS‑based pipelines** – Flexible, composable transformation chains (ingest→OCR→chunk→export).
- **Local‑first & privacy‑preserving** – No cloud dependency; all processing on‑device.
- **Accessibility built‑in** – Diaplasion produces EPUB, Braille, and audio‑ready outputs.
- **Provenance & governance** – Cathedral/Harmonia enforce tamper‑evidence, contract‑based execution, audit trails.
- **Semantic search ready** – Vectorum + SQLite FTS5 + vector storage enable RAG.
- **Performance budgets** – Defined targets for OCR, import, embedding (Docs/guides/PerformanceBudgets.md).
- **SegmentIR vision** – Already designed contract‑based multimodal understanding (OCR, layout, table extraction, QA with citations) in `Docs/architecture/MULTIMODAL‑ARCHITECTURE‑CONTRACT.md`.
- **Capsule strategy** – “Swift governs, C++ computes” architecture with TextChunkingCapsule, VectorCapsule, RankFusionCapsule implemented; subsequent capsules planned (LayoutEngine, Compression, TextPipeline, MediaFingerprint).

### 1.3 Limitations & Gaps

| Category | Missing/Weak |
|----------|--------------|
| **Format support** | PPTX, XLSX, ODT, Markdown, LaTeX, plain‑text email, EPub ingestion (currently only export). |
| **Layout analysis** | Table extraction, figure detection, reading‑order recovery, equation recognition, bounding‑box extraction. |
| **Citation/reference** | No extraction, linking to bibliographic DBs (CrossRef, PubMed), or reference‑manager integration (Zotero, Mendeley). |
| **Collaboration** | No annotations, comments, shared editing, or version‑tracking. |
| **Scalability** | Single‑node; no distributed indexing for corpora >10k documents. |
| **Multi‑language OCR** | Limited to Apple Vision’s language set; no handwritten‑text recognition. |
| **Research‑tool integration** | No hooks for Zotero, Overleaf, LaTeX compilers. |
| **Cross‑platform** | macOS‑only; no iOS, web, or Windows clients. |
| **UI maturity** | Early‑stage document library and reading experience. |
| **Advanced AI** | No fine‑tuned models for domain‑specific tasks (legal, medical, scientific). |
| **Real‑time collaboration** | No WebRTC or CRDT‑based sync for concurrent editing. |

## 2. C++ Compute Capsule Acceleration Analysis

The “Swift governs, C++ computes” architecture can dramatically accelerate critical document‑processing tasks. Below is an assessment of which tasks would benefit from native C++ capsules, based on the existing capsule plan (`Docs/SubsequentCapsulesPlan.md`).

### 2.1 High‑Impact Capsules (Already Planned)

| Capsule | Document Task | Acceleration Benefit | Priority |
|---------|---------------|----------------------|----------|
| **LayoutEngineCapsule** | PDF layout analysis, bounding‑box extraction, column detection, table recognition. | 5–10× speedup vs. Swift‑side post‑processing; enables precise citation linking. | High |
| **ChunkingCapsule** | Content‑defined chunking (CDC) for RAG indexing. | 10–100× speedup for >1 MB documents; improves chunk quality. | High |
| **CompressionCapsule** | Artifact storage, receipt serialization, network transfer. | 2–5× speedup; reduces storage footprint. | Medium |
| **TextPipelineCapsule** | Unicode normalization (NFKC), grapheme clustering, locale‑aware segmentation. | 3–10× speedup for heavy Unicode workloads; essential for multilingual text. | Medium |
| **MediaFingerprintCapsule** | Perceptual hashing for image/audio/video deduplication. | 10–50× speedup vs. Swift‑side decoding. | Low |

### 2.2 Additional Capsule Opportunities

| Task | Potential Capsule | Rationale |
|------|------------------|-----------|
| **Table extraction** | Extend LayoutEngineCapsule or create TableExtractionCapsule. | Table‑Transformer models are C++‑friendly; can run inference via ONNX Runtime. |
| **Equation recognition** | MathOCR Capsule | Integrate LaTeX‑OCR models (e.g., Pix2Text) for STEM documents. |
| **Citation parsing** | CitationExtractionCapsule | Regex + NLP in C++ for speed; could call external APIs (CrossRef). |
| **Reference matching** | ReferenceResolutionCapsule | Fuzzy matching against bibliographic databases. |
| **Document diffing** | DiffCapsule | Use difflib or libdiff for fast comparison of text versions. |
| **Image preprocessing** | ImageEnhancementCapsule | Deskew, denoise, binarization for improved OCR accuracy. |

### 2.3 Integration Points

- **LayoutEngineCapsule** → `PDFiumProvider`, `DocumentRenderKit`, `ContextumModule` indexing pipeline.
- **ChunkingCapsule** → `CLIIndexManager`, `ContextumModule` auto‑indexing workflow.
- **TextPipelineCapsule** → `ContextumModule` text preprocessing, `DiaplasionPipeline` normalization.
- **CompressionCapsule** → `CompressionKit`, receipt serialization, artifact storage.
- **MediaFingerprintCapsule** → `ArtifactStoreModule` deduplication, `ObservatoriumModule` media analysis.

## 3. User‑Group Needs Assessment

### 3.1 Academia & Research

| Need | Current Gap | Priority |
|------|-------------|----------|
| **Citation extraction** | No automated extraction from PDFs. | High |
| **Reference management** | No integration with Zotero, Mendeley, EndNote. | High |
| **LaTeX support** | Cannot parse `.tex` files or compile to PDF. | High |
| **Annotation & highlighting** | No ability to annotate PDFs with notes, highlights. | Medium |
| **Version control** | No Git‑like tracking of document revisions. | Medium |
| **Collaborative editing** | No real‑time co‑authoring. | Medium |
| **Semantic search across papers** | Basic RAG exists but lacks citation‑aware retrieval. | High |
| **Conference/journal templates** | No automated formatting. | Low |

### 3.2 Professionals (Legal, Medical, Corporate)

| Need | Current Gap | Priority |
|------|-------------|----------|
| **Document automation** | No templating, mail‑merge, batch processing. | High |
| **Contract analysis** | No clause extraction, risk detection, red‑flag identification. | High |
| **Data extraction** | No OCR‑to‑structured‑data (forms, invoices). | High |
| **Compliance tracking** | Basic provenance exists; need regulatory‑specific reports. | Medium |
| **Redaction** | No automated PII detection and redaction. | Medium |
| **Electronic signatures** | No integration with DocuSign, Adobe Sign. | Low |
| **Workflow orchestration** | No visual pipeline builder for document processing. | Medium |

### 3.3 Everyday Users

| Need | Current Gap | Priority |
|------|-------------|----------|
| **Simplicity** | UI is developer‑focused; lacks intuitive document library. | High |
| **Quick scanning** | No “scan‑to‑PDF” with mobile camera. | High |
| **Sharing** | No easy export to Google Drive, Dropbox, email. | Medium |
| **Accessibility** | Strong foundation (Diaplasion); need better TTS controls. | Medium |
| **Offline reading** | Basic; need progressive loading for large documents. | Low |
| **Cross‑device sync** | CloudSyncSystem exists but not polished. | Medium |
| **Personal organization** | No folders, tags, smart collections. | Medium |

## 4. World‑Class Promotion Plan

### 4.1 Guiding Principles

1. **Leverage existing architecture** – Extend ECS components, use capsule acceleration, follow contract‑based design (SegmentIR).
2. **Incremental delivery** – Each phase delivers usable value to a specific user group.
3. **Determinism & provenance** – Maintain forensic‑grade audit trails for all transformations.
4. **Accessibility by default** – All new features must produce accessible outputs (EPUB, Braille, audio).
5. **Local‑first** – Keep data on‑device; cloud optional for sync and collaboration.

### 4.2 Phase 1: Foundation Extension (6 months)

**Goal**: Close critical gaps in format support, OCR accuracy, and basic citation extraction.

| Task | Module | Description |
|------|--------|-------------|
| 1.1 **Extend format parsers** | New `FormatKit` module | Add SwiftPM wrappers for Apache POI (Office), CommonMark, LaTeX‑parsing libraries. |
| 1.2 **Improve OCR** | DiaplasionModule | Integrate Tesseract via capsule for multi‑language support; add handwritten‑text detection (Apple PencilKit). |
| 1.3 **Table extraction** | LayoutEngineCapsule | Implement Table‑Transformer model inference (C++); output as `TableComponent`. |
| 1.4 **Basic citation extraction** | CodexModule | Regex‑based extraction + CrossRef API lookup; store as `CitationComponent`. |
| 1.5 **Enhance AI nodes** | AnigmaCore/Pipeline | Wire `Summarize`, `RAGQuery` nodes to MLWorker (MLX/llama.cpp backends). |
| 1.6 **Polish UI** | AnigmaAppMac | Document library, reading view, search results with snippets. |
| 1.7 **Integrate TextChunkingCapsule** | ContextumModule | Replace Swift chunking with CDC capsule for indexing. |

### 4.3 Phase 2: SegmentIR Realization (1 year)

**Goal**: Implement the multimodal SegmentIR contracts, enabling advanced document understanding.

| Task | Module | Description |
|------|--------|-------------|
| 2.1 **Implement SegmentIR contracts** | New `SegmentIRModule` | OCR+layout, figure detection, reading‑order, QA with citations per `MULTIMODAL‑ARCHITECTURE‑CONTRACT.md`. |
| 2.2 **Collaboration features** | ConexusModule + new `AnnotationComponent` | Annotation/comment components; sync via ConexusModule contacts. |
| 2.3 **Research‑tool integration** | CodexModule | Zotero API client, Overleaf sync, LaTeX compilation service. |
| 2.4 **Advanced citation management** | CodexModule | Bibliography generation, style‑formatted references, citation‑graph visualization. |
| 2.5 **Cross‑platform** | Share SwiftUI code for iOS; explore SwiftWasm for web preview. |
| 2.6 **Scalability** | DatabaseCore | SQLite replication for distributed indexing; incremental updates. |
| 2.7 **LayoutEngineCapsule integration** | DiaplasionModule | Replace Apple Vision bounding‑box extraction with layout capsule. |

### 4.4 Phase 3: Ecosystem & Intelligence (2+ years)

**Goal**: Build a plugin ecosystem, federated sharing, and domain‑specific AI.

| Task | Module | Description |
|------|--------|-------------|
| 3.1 **Plugin ecosystem** | New `PluginRuntime` | Allow third‑party document processors (e.g., legal‑document analyzers). |
| 3.2 **Multimodal embeddings** | VectorumModule | CLIP for image‑text, Whisper for audio, unified retrieval. |
| 3.3 **Federated sharing** | ConexusModule | End‑to‑end encrypted collaboration across institutions. |
| 3.4 **Enterprise features** | HarmoniaModule | SSO, granular retention policies, compliance reporting. |
| 3.5 **Community marketplace** | New `MarketplaceModule` | Templates, pre‑trained models, workflow recipes. |
| 3.6 **Domain‑specific fine‑tuning** | MLWorkerExecutable | Fine‑tune models on user data (with privacy guarantees). |
| 3.7 **Real‑time collaboration** | CRDT‑based sync, WebRTC for live co‑editing. |

## 5. Implementation Sequence

### 5.1 Immediate Next Steps (Week 1–2)

1. **Create detailed specification** for each Phase‑1 task.
2. **Set up CI golden‑corpus tests** for LayoutEngineCapsule and ChunkingCapsule.
3. **Refactor PDF import workflow** to use OperationResult envelope (Ticket 001).
4. **Integrate TextChunkingCapsule** into `CLIIndexManager`.

### 5.2 Short‑Term (Month 1–3)

1. **Implement LayoutEngineCapsule** (C++ extension of CPDFium wrapper).
2. **Add table extraction** as part of layout capsule.
3. **Extend format parsers** for Office, Markdown, LaTeX.
4. **Build citation extraction** (regex + CrossRef API).

### 5.3 Medium‑Term (Month 4–12)

1. **Implement SegmentIR contracts** (OCR+layout, figure detection, QA with citations).
2. **Develop collaboration features** (annotations, comments).
3. **Integrate Zotero API** and LaTeX compilation.
4. **Cross‑platform UI** (iOS, web).

### 5.4 Long‑Term (Year 2+)

1. **Plugin system** and marketplace.
2. **Federated sharing** and enterprise features.
3. **Domain‑specific AI fine‑tuning**.

## 6. Success Metrics

| Metric | Target |
|--------|--------|
| **Format support** | 20+ document formats (PDF, DOCX, PPTX, XLSX, ODT, LaTeX, Markdown, HTML, EPUB). |
| **OCR accuracy** | >98% on clean docs, >90% on scanned docs (FUNSD eval). |
| **Citation extraction recall** | >85% on academic PDFs. |
| **Table extraction F1** | >0.9 on standard benchmarks (ICDAR‑2013). |
| **Indexing speed** | 1,000 pages/minute on M2 Mac. |
| **RAG answer quality** | Human‑rated >4/5 for correctness and citation accuracy. |
| **Accessibility compliance** | WCAG 2.1 AA for all output formats. |
| **User satisfaction** | NPS >50 among academia, professionals, everyday users. |

## 7. Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| **Dependency complexity** (ICU, FFmpeg, etc.) | Feature‑flag capsules; fallback to Swift implementations. |
| **Performance regressions** | Rigorous benchmarking; capsule telemetry monitoring. |
| **UI/UX immaturity** | User testing with target groups; iterative design. |
| **Scalability limits** | Incremental indexing; SQLite replication. |
| **Security vulnerabilities** | Regular audits; capsule memory‑safety validation (ASAN). |
| **Community adoption** | Open‑source with clear contribution guidelines; showcase use cases. |

## 8. Conclusion

Anigma is uniquely positioned to become a world‑class document processor due to its strong architectural foundations (ECS, local‑first, provenance, capsules). By executing the phased plan above—focusing first on foundational extensions, then realizing the SegmentIR vision, and finally building an ecosystem—we can deliver exceptional value to academia, professionals, and everyday users while maintaining the system’s core principles of privacy, accessibility, and determinism.

**Next Action**: Create detailed specifications for Phase‑1 tasks and begin implementation.