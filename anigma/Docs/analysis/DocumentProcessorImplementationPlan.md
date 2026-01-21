# Document Processor Implementation Plan

**Date**: 2026-01-13  
**Author**: opencode  
**Status**: Active

## Overview

This document outlines the sequential implementation tasks to elevate Anigma to a world‑class document processor for academia, research, professionals, and everyday users. The plan is organized into phases, each building on the previous, with clear deliverables and success criteria.

## Phase 0: Foundation & Cleanup (Week 1)

**Goal**: Ensure the existing codebase is ready for extension; complete Ticket 001.

| Task ID | Description | Module | Est. Time | Dependencies |
|---------|-------------|--------|-----------|--------------|
| 0.1 | **Refactor PDF import workflow** to use `OperationResult` envelope with real progress phases (0% accepted, 25% bytes read, 50% parsed pages, 75% OCR/index, 100% committed). | `AnigmaAppMac` (PDFImportJob) | 2 days | Ticket 001 |
| 0.2 | **Integrate TextChunkingCapsule** into `CLIIndexManager` and `ContextumModule` indexing pipeline. | `ContextumModule`, `TextChunkingCapsule` | 1 day | Capsule must be built |
| 0.3 | **Set up CI golden‑corpus tests** for LayoutEngineCapsule and ChunkingCapsule. | `Scripts/` | 1 day | Capsule specs |
| 0.4 | **Create detailed specification** for each Phase‑1 capsule (LayoutEngine, Compression, TextPipeline). | `Docs/Capsules/` | 1 day | Existing plan |

## Phase 1: Format Support & Basic Extraction (Month 1–3)

**Goal**: Extend format support, improve OCR accuracy, add table extraction, and basic citation extraction.

| Task ID | Description | Module | Est. Time | Dependencies |
|---------|-------------|--------|-----------|--------------|
| 1.1 | **Extend format parsers**: Add SwiftPM wrappers for Apache POI (Office), CommonMark, LaTeX‑parsing libraries. | New `FormatKit` module | 1 week | Research libraries |
| 1.2 | **Improve OCR**: Integrate Tesseract via capsule for multi‑language support; add handwritten‑text detection (Apple PencilKit). | `DiaplasionModule` | 2 weeks | Tesseract C API |
| 1.3 | **Implement LayoutEngineCapsule**: Extend CPDFium wrapper to expose bounding boxes, font metrics, spatial index, column detection. | `Native/Shims/` | 3 weeks | CPDFium existing |
| 1.4 | **Add table extraction** as part of LayoutEngineCapsule (Table‑Transformer model inference). | `LayoutEngineCapsule` | 1 week | ONNX Runtime integration |
| 1.5 | **Basic citation extraction**: Regex‑based extraction + CrossRef API lookup; store as `CitationComponent`. | `CodexModule` | 1 week | CrossRef API key |
| 1.6 | **Enhance AI nodes**: Wire `Summarize`, `RAGQuery` nodes to MLWorker (MLX/llama.cpp backends). | `AnigmaCore/Pipeline` | 1 week | MLWorker integration |
| 1.7 | **Polish UI**: Document library, reading view, search results with snippets. | `AnigmaAppMac` | 2 weeks | Design assets |

## Phase 2: SegmentIR Realization (Month 4–12)

**Goal**: Implement the multimodal SegmentIR contracts, enabling advanced document understanding and collaboration.

| Task ID | Description | Module | Est. Time | Dependencies |
|---------|-------------|--------|-----------|--------------|
| 2.1 | **Implement SegmentIR contracts**: OCR+layout, figure detection, reading‑order, QA with citations per `MULTIMODAL‑ARCHITECTURE‑CONTRACT.md`. | New `SegmentIRModule` | 4 weeks | LayoutEngineCapsule |
| 2.2 | **Collaboration features**: Annotation/comment components; sync via ConexusModule contacts. | `ConexusModule` + new `AnnotationComponent` | 3 weeks | CRDT research |
| 2.3 | **Research‑tool integration**: Zotero API client, Overleaf sync, LaTeX compilation service. | `CodexModule` | 2 weeks | API authentication |
| 2.4 | **Advanced citation management**: Bibliography generation, style‑formatted references, citation‑graph visualization. | `CodexModule` | 2 weeks | Citation‑style‑language |
| 2.5 | **Cross‑platform**: Share SwiftUI code for iOS; explore SwiftWasm for web preview. | `AnigmaAppMac` | 4 weeks | iOS deployment setup |
| 2.6 | **Scalability**: SQLite replication for distributed indexing; incremental updates. | `DatabaseCore` | 2 weeks | SQLite expertise |
| 2.7 | **LayoutEngineCapsule integration**: Replace Apple Vision bounding‑box extraction with layout capsule. | `DiaplasionModule` | 1 week | Capsule ready |

## Phase 3: Ecosystem & Intelligence (Year 2+)

**Goal**: Build a plugin ecosystem, federated sharing, and domain‑specific AI.

| Task ID | Description | Module | Est. Time | Dependencies |
|---------|-------------|--------|-----------|--------------|
| 3.1 | **Plugin ecosystem**: Allow third‑party document processors (e.g., legal‑document analyzers). | New `PluginRuntime` | 8 weeks | Sandboxing, IPC |
| 3.2 | **Multimodal embeddings**: CLIP for image‑text, Whisper for audio, unified retrieval. | `VectorumModule` | 6 weeks | MLX‑CLIP, Whisper |
| 3.3 | **Federated sharing**: End‑to‑end encrypted collaboration across institutions. | `ConexusModule` | 10 weeks | Cryptography, networking |
| 3.4 | **Enterprise features**: SSO, granular retention policies, compliance reporting. | `HarmoniaModule` | 6 weeks | OAuth, audit frameworks |
| 3.5 | **Community marketplace**: Templates, pre‑trained models, workflow recipes. | New `MarketplaceModule` | 4 weeks | Web backend |
| 3.6 | **Domain‑specific fine‑tuning**: Fine‑tune models on user data (with privacy guarantees). | `MLWorkerExecutable` | 8 weeks | LoRA, PEFT |
| 3.7 | **Real‑time collaboration**: CRDT‑based sync, WebRTC for live co‑editing. | `ConexusModule` | 12 weeks | CRDT libraries |

## Immediate Next Steps (Week 1–2)

1. **Start with Task 0.1** (PDF import refactor) – this unblocks real progress reporting.
2. **Simultaneously** begin Task 0.2 (TextChunkingCapsule integration) – capsule is already built.
3. **Parallel** specification work (Task 0.4) for LayoutEngineCapsule.

## Success Metrics

Each phase will be measured against the following metrics:

| Metric | Phase 1 Target | Phase 2 Target | Phase 3 Target |
|--------|---------------|---------------|---------------|
| **Format support** | 10+ formats (PDF, DOCX, PPTX, XLSX, ODT, LaTeX, Markdown, HTML, EPUB, plain text) | 15+ formats | 20+ formats |
| **OCR accuracy** | >95% on clean docs | >98% on clean docs | >99% with domain‑fine‑tuning |
| **Citation extraction recall** | >80% on academic PDFs | >90% | >95% |
| **Table extraction F1** | >0.8 on ICDAR‑2013 | >0.9 | >0.95 |
| **Indexing speed** | 500 pages/minute | 1,000 pages/minute | 5,000 pages/minute (distributed) |
| **RAG answer quality** | Human‑rated >3/5 | >4/5 | >4.5/5 |
| **Accessibility compliance** | WCAG 2.1 A | WCAG 2.1 AA | WCAG 2.1 AAA |
| **User satisfaction (NPS)** | >30 | >50 | >70 |

## Risk Mitigation

- **Capsule dependency complexity**: Use feature flags; maintain Swift fallback implementations.
- **Performance regressions**: Continuous benchmarking; capsule telemetry monitoring.
- **UI/UX immaturity**: Regular user testing with target groups; iterative design.
- **Scalability limits**: Start with single‑node; later add replication.
- **Security vulnerabilities**: Regular audits; capsule memory‑safety validation (ASAN).
- **Community adoption**: Open‑source with clear contribution guidelines; showcase use cases.

## Conclusion

This plan provides a clear, sequential path to transform Anigma into a world‑class document processor. By focusing first on foundational extensions (format support, OCR, table extraction, citations), then realizing the SegmentIR vision (multimodal understanding, collaboration, research‑tool integration), and finally building an ecosystem (plugins, federated sharing, domain‑specific AI), we can deliver exceptional value while maintaining the system’s core principles of privacy, accessibility, and determinism.

**Next Action**: Begin Task 0.1 (PDF import refactor) and Task 0.2 (TextChunkingCapsule integration) concurrently.