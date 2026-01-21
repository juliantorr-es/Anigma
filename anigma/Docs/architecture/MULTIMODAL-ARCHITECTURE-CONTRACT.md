# Anigma Multimodal Architecture: SegmentIR Implementation Contract

> **Document Type:** Implementation Contract  
> **Date:** 2026-01-07  
> **Status:** Approved for Implementation  
> **Governance Refs:** ADR-0012, PHASE-SEGMENT-IR

---

## Executive Summary

Anigma's ML capabilities—perception, understanding, retrieval, generation, and transformation—will be unified under a single substrate: **SegmentIR**. This document is the binding contract for implementation.

### The Core Insight

Every Hugging Face task category maps to one of five primitives:

| Primitive | What It Does | Anigma Features |
|-----------|-------------|-----------------|
| **Perception** | Raw input → structured representation | OCR, layout analysis, table extraction, figure detection, ASR, VAD |
| **Understanding** | Structured input → meaning | Summarization, translation, classification, entity extraction, intent |
| **Retrieval** | Query → ranked results | Embeddings, vector search, reranking, deduplication, semantic search |
| **Generation** | Prompt → new content | Text generation, image captioning, alt-text, simplified summaries |
| **Transformation** | Pipeline glue | Format conversion, cleanup, normalization, segment merging |

### The Architecture Decision

Instead of implementing 47 separate tasks, Anigma implements:

1. **One IR (SegmentIR)** — Universal representation for content pieces
2. **One Index** — Stores segments, artifacts, relations
3. **N Contracts** — Typed operations that consume/produce segments
4. **M Executors** — Implementations of contracts using MLWorker

**Everything becomes "artifacts attached to segments."**

---

## What We're Building

### Document Intake & Understanding

**Capability:** Turn PDFs, images, and documents into searchable, citable segments.

| Feature | Contract | Models | Phase |
|---------|----------|--------|-------|
| OCR + Layout | `DocumentIntakeContract` | Tesseract, DocTR, MLX | 1 |
| Table Extraction | `DocumentIntakeContract` | Table Transformer | 1 |
| Figure Detection | `DocumentIntakeContract` | YOLO-Doc | 1 |
| Reading Order | `DocumentIntakeContract` | LayoutLM | 1 |

**User Story:** Import PDF → search → click result → see exact highlighted region on page.

---

### Doc QA with Citations

**Capability:** Ask questions, get answers grounded in your files with clickable citations.

| Feature | Contract | Models | Phase |
|---------|----------|--------|-------|
| Retrieval | `EmbedSegmentsContract` | E5, BGE, GTE | 1 |
| Reranking | `RerankContract` | Cohere reranker, BGE-reranker | 1 |
| QA Generation | `DocumentQAContract` | Llama, Mistral, Phi | 1 |

**User Story:** Ask "What was the 2025 budget?" → Get answer with `[1][2]` citations → Click to jump to source.

**Critical Constraint:** If retrieval confidence < threshold, answer is "Insufficient evidence in your documents" — no hallucinated filler.

---

### Embeddings & Retrieval (Text, Image, Audio, Video)

**Capability:** Unified semantic search across all modalities.

| Feature | Contract | Models | Phase |
|---------|----------|--------|-------|
| Text Embeddings | `EmbedSegmentsContract` | E5, BGE, GTE | 1 |
| Image Embeddings | `EmbedSegmentsContract` | CLIP, SigLIP | 2 |
| Audio Embeddings | `EmbedSegmentsContract` | CLAP, Wav2Vec | 3 |
| Video Embeddings | `EmbedSegmentsContract` | X-CLIP, ImageBind | 3 |

**User Story:** Search "that chart with the red line" → Find image in document, audio mention, video frame.

---

### Audio Intake with Diarization

**Capability:** Turn audio into searchable, timestamped transcripts with speaker labels.

| Feature | Contract | Models | Phase |
|---------|----------|--------|-------|
| Speech Recognition | `TranscribeContract` | Whisper MLX | 2 |
| Voice Activity | `TranscribeContract` | Silero-VAD | 2 |
| Diarization | `DiarizationContract` | Pyannote, Whisper-diarize | 3 |
| Speaker ID | `SpeakerIdentifyContract` | Speaker embeddings | 4 |

**User Story:** Import meeting → Search "action items" → Click → Audio plays from timestamp → See speaker name.

---

### Video Captioning & Transcription

**Capability:** Turn videos into searchable content (spoken + visual).

| Feature | Contract | Models | Phase |
|---------|----------|--------|-------|
| Audio Extraction | `VideoIntakeContract` | FFmpeg | 3 |
| Frame Sampling | `VideoIntakeContract` | Scene detection | 3 |
| Frame Captioning | `VideoCaptionContract` | LLaVA, BLIP-2 | 3 |
| Unified Search | `MultimodalSearchContract` | Merge strategy | 3 |

**User Story:** Search my videos → Find by what was said AND what was shown → Click → Video jumps to timestamp.

---

### Speech Output (TTS)

**Capability:** Read documents aloud for accessibility and hands-free workflows.

| Feature | Contract | Models | Phase |
|---------|----------|--------|-------|
| Text-to-Speech | `SynthesizeSpeechContract` | MLX TTS, Piper | 5 |
| Voice Selection | `SynthesizeSpeechContract` | Voice embeddings | 5 |

**User Story:** Select paragraph → "Read aloud" → Hear natural speech.

---

### NLP Transforms

**Capability:** Translate, summarize, classify, extract, redact.

| Feature | Contract | Models | Phase |
|---------|----------|--------|-------|
| Translation | `TranslateContract` | NLLB, Madlad | 5 |
| Summarization | `SummarizeContract` | Llama, Mistral | 5 |
| Classification | `ClassifyContract` | SetFit, BERT | 5 |
| Entity Extraction | `ExtractEntitiesContract` | SpaCy, GLiNER | 4 |
| Redaction | `RedactContract` | NER + Rules | 5 |

**User Story:** Select documents → "Summarize" → Get summary with links to supporting sections.

---

### Knowledge Graph

**Capability:** See entities, relationships, and connections across your entire corpus.

| Feature | Contract | Models | Phase |
|---------|----------|--------|-------|
| Entity Extraction | `ExtractEntitiesContract` | GLiNER, SpaCy | 4 |
| Entity Resolution | `ResolveEntitiesContract` | SentenceTransformers | 4 |
| Relation Extraction | `ExtractRelationsContract` | REBEL, LLM | 4+ |
| Co-Retrieval Links | Automatic | Query patterns | 4 |

**User Story:** Click "Alice Chen" → See all mentions → See related entities → See timeline → Click mention → Jump to source.

---

## Implementation Phases

```
Phase 0: Schema Lock (1 week)
├── Define Segment, SegmentArtifact, SegmentRelation types
├── Define SegmentIndex protocol
└── ADR + Phase contract approved

Phase 1: Document Vertical (3-4 weeks)
├── PDF intake → Segment array with bounding boxes
├── Text embeddings → SegmentArtifact
├── Hybrid search returning Segments
├── Doc QA with cited segment IDs
└── Citation highlight UI

Phase 2: Audio Vertical (2-3 weeks)
├── Audio intake → timestamp segments
├── ASR transcription → text artifacts
├── Audio search → timestamp results
└── Playback seek integration

Phase 3: Diarization + Video (3-4 weeks)
├── Speaker diarization → label artifacts
├── Video intake → audio + frame segments
├── Frame captioning → caption artifacts
└── Unified multimodal search

Phase 4: Knowledge Graph (3-4 weeks)
├── Entity extraction → entity artifacts + mention edges
├── Entity resolution → same-as edges
├── Co-retrieval tracking → weighted edges
└── Graph explorer UI

Phase 5: NLP Transforms (2-3 weeks)
├── Translation with parallel text links
├── Summarization with supporting segment links
├── Classification/tagging
└── Redaction with policy gates
```

---

## Model Strategy

### Tier 1: First-Class (Tested, Pinned, Deterministic)

| Task | Model | Backend | License |
|------|-------|---------|---------|
| Text Embedding | `BAAI/bge-base-en-v1.5` | MLX | MIT |
| ASR | `openai/whisper-large-v3` | MLX | MIT |
| Text Generation | `microsoft/Phi-3-mini-4k-instruct` | MLX | MIT |
| Image Caption | `Salesforce/blip-image-captioning-base` | MLX | BSD |

### Tier 2: Compatible (User brings, we run)

Any model matching our backend + contract, recorded in registry with hashes.

### Tier 3: Experimental (Logged, not production)

Behind trust tier, for evaluation only.

---

## Non-Goals (Explicitly Out of Scope)

| Category | Why Not |
|----------|---------|
| Video Generation | Compute/storage explosion, separate product lane |
| 3D/Point Cloud | Not core to document understanding |
| Reinforcement Learning | Research lab feature, not user feature |
| Graph ML | We use graphs for data, not as ML task |
| "Any-to-Any" | Undefined interfaces are governance failures |
| Arbitrary HF pipelines | Compatibility layer, not product surface |

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Citation accuracy | >95% grounded | QA eval set |
| Search latency (10k segments) | <200ms | p95 benchmark |
| OCR accuracy | >98% on clean docs | FUNSD eval |
| ASR WER | <10% | LibriSpeech test |
| Entity F1 | >0.85 | CoNLL eval |
| Diarization error | <20% | AMI eval |
| User task completion | >90% | UX study |

---

## Governance Alignment

### From Constitution

- ✅ Local-first: All operations run on-device
- ✅ Evidence: Every artifact has receipt with model/input/output hashes
- ✅ Policy gates: Sensitive operations (redaction, entity extraction) capability-gated

### From ADR-MODEL-CONTRACT-SYSTEM

- ✅ Task contracts, not arbitrary repos
- ✅ Tiered model support
- ✅ ModelSpec + RunSpec for every operation

### From Cathedral Invariants

- ✅ Receipts chain back to source provenance
- ✅ Deterministic serialization (JCS)
- ✅ No operation without evidence

---

## File Locations

```
Sources/ContextumModule/
├── IR/
│   ├── Segment.swift           # Core segment type
│   ├── SegmentProvenance.swift # Anchor types
│   ├── SegmentArtifact.swift   # Artifact attachments
│   ├── SegmentRelation.swift   # Graph edges
│   └── SegmentIndex.swift      # Query protocol
├── Execution/
│   ├── PDFIntakeExecutor.swift
│   ├── SegmentEmbeddingExecutor.swift
│   ├── TranscriptionExecutor.swift
│   ├── DiarizationExecutor.swift
│   ├── DocumentQAExecutor.swift
│   ├── EntityExtractionExecutor.swift
│   └── ...
├── Database/
│   ├── SegmentStore.swift
│   ├── GraphStore.swift
│   └── ...
└── Systems/
    ├── SegmentSearchSystem.swift
    ├── MultimodalSearchSystem.swift
    └── ...

Docs/
├── ADR/
│   └── ADR-0012-SEGMENT-IR-MULTIMODAL.md
└── governance/phases/
    └── PHASE-SEGMENT-IR.md
```

---

## Next Steps

1. **Immediate:** Implement Phase 0 types in `Sources/ContextumModule/IR/`
2. **This sprint:** Review and approve ADR-0012
3. **Next sprint:** Begin Phase 1 document vertical

---

**This document is the binding implementation contract for Anigma's multimodal capabilities.**

**Approval:** Pending  
**Owner:** Core Platform  
**Review Date:** 2026-01-14
