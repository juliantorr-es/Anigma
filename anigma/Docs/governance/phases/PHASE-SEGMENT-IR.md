# PHASE: SegmentIR Implementation

> **Phase ID:** `PHASE-SEGMENT-IR`  
> **Status:** Planning  
> **ADR Reference:** ADR-0012-SEGMENT-IR-MULTIMODAL  
> **Owner:** Core Platform  
> **Created:** 2026-01-07

---

## Overview

This phase contract defines the staged implementation of SegmentIR—the universal multimodal content representation for Anigma. All ML operations (embeddings, search, QA, transcription, knowledge graphs) will be rebuilt on this foundation.

---

## Phase 0: Schema Lock

**Objective:** Define and commit all SegmentIR types with no implementation.

### Deliverables

| Artifact | Path | Status |
|----------|------|--------|
| ADR | `Docs/ADR/ADR-0012-SEGMENT-IR-MULTIMODAL.md` | ✅ Complete |
| Phase Contract | `Docs/governance/phases/PHASE-SEGMENT-IR.md` | ✅ Complete |
| Segment Types | `Sources/ContextumModule/IR/Segment.swift` | ⏳ Pending |
| Provenance Types | `Sources/ContextumModule/IR/SegmentProvenance.swift` | ⏳ Pending |
| Artifact Types | `Sources/ContextumModule/IR/SegmentArtifact.swift` | ⏳ Pending |
| Relation Types | `Sources/ContextumModule/IR/SegmentRelation.swift` | ⏳ Pending |
| Index Protocol | `Sources/ContextumModule/IR/SegmentIndex.swift` | ⏳ Pending |
| Contract Exports | `ContractsCore/SegmentIRContracts.swift` | ⏳ Pending |

### Acceptance Criteria

- [ ] All types compile without errors
- [ ] Types are `Codable`, `Hashable`, `Sendable`
- [ ] Deterministic serialization verified (JCS for JSON encoding)
- [ ] Re-exports available in `ContractsCore`
- [ ] Unit tests for serialization round-trip

### Validation

```bash
./Scripts/harmonia.sh swift6 --packages ContextumModule ContractsCore
```

---

## Phase 1: Document Vertical

**Objective:** PDF → Segments → Embeddings → Search → QA with clickable citations.

### Deliverables

| Artifact | Path | Status |
|----------|------|--------|
| PDF Intake Executor | `Sources/ContextumModule/Execution/PDFIntakeExecutor.swift` | ⏳ Pending |
| Segment Embedding Executor | `Sources/ContextumModule/Execution/SegmentEmbeddingExecutor.swift` | ⏳ Pending |
| Segment Index (SQLite) | `Sources/ContextumModule/Database/SegmentStore.swift` | ⏳ Pending |
| Hybrid Search (Segment) | `Sources/ContextumModule/Systems/SegmentSearchSystem.swift` | ⏳ Pending |
| Document QA Executor | `Sources/ContextumModule/Execution/DocumentQAExecutor.swift` | ⏳ Pending |
| Citation UI Component | `Sources/AnigmaAppMac/Components/CitationHighlightView.swift` | ⏳ Pending |

### Contracts Implemented

```
DocumentIntakeContract
EmbedSegmentsContract  
DocumentQAContract
```

### Acceptance Criteria

- [ ] Import PDF produces `Segment` array with `DocumentAnchor` provenance
- [ ] Each page block has bounding box coordinates
- [ ] Embeddings stored as `SegmentArtifact` with model provenance
- [ ] Search returns `(Segment, score)` tuples
- [ ] QA response includes `citedSegments: [SegmentID]`
- [ ] UI can highlight exact region on page from segment provenance
- [ ] All operations produce receipts with input/output hashes

### Demo Scenario

```
1. Import PDF document
2. Search "budget allocation"
3. Click result → PDF viewer scrolls to page, highlights exact paragraph
4. Ask "What was the 2025 budget?"
5. Answer includes [1] citation
6. Click [1] → highlights source paragraph
```

### Validation

```bash
./Scripts/harmonia-surface.sh segment-document-flow
```

---

## Phase 2: Audio Vertical

**Objective:** Audio → Timestamp Segments → Transcript → Embeddings → Search with playback positioning.

### Deliverables

| Artifact | Path | Status |
|----------|------|--------|
| Audio Intake Executor | `Sources/ContextumModule/Execution/AudioIntakeExecutor.swift` | ⏳ Pending |
| Transcription Executor | `Sources/ContextumModule/Execution/TranscriptionExecutor.swift` | ⏳ Pending |
| Audio Segment Store | `Sources/ContextumModule/Database/AudioSegmentStore.swift` | ⏳ Pending |
| Temporal Search | `Sources/ContextumModule/Systems/TemporalSearchSystem.swift` | ⏳ Pending |
| Audio Player Integration | `Sources/AnigmaAppMac/Components/AudioSegmentPlayer.swift` | ⏳ Pending |

### Contracts Implemented

```
AudioIntakeContract
TranscribeContract
```

### Acceptance Criteria

- [ ] Audio produces `Segment` array with `TemporalAnchor` provenance
- [ ] Transcript attached as `SegmentArtifact` with confidence scores
- [ ] Search returns timestamp segments
- [ ] Click result → audio player seeks to timestamp
- [ ] Transcript view highlights matching segments during playback

### Demo Scenario

```
1. Import podcast/meeting audio
2. Search "action items"
3. Click result → audio plays from that timestamp
4. Transcript highlights current segment
5. Can navigate by clicking transcript segments
```

### Validation

```bash
./Scripts/harmonia-surface.sh segment-audio-flow
```

---

## Phase 3: Diarization + Video

**Objective:** Speaker labels, video transcription, frame captioning, unified multimodal search.

### Deliverables

| Artifact | Path | Status |
|----------|------|--------|
| Diarization Executor | `Sources/ContextumModule/Execution/DiarizationExecutor.swift` | ⏳ Pending |
| Video Intake Executor | `Sources/ContextumModule/Execution/VideoIntakeExecutor.swift` | ⏳ Pending |
| Frame Captioning Executor | `Sources/ContextumModule/Execution/FrameCaptioningExecutor.swift` | ⏳ Pending |
| Speaker Embedding Store | `Sources/ContextumModule/Database/SpeakerStore.swift` | ⏳ Pending |
| Multimodal Search Merge | `Sources/ContextumModule/Systems/MultimodalSearchSystem.swift` | ⏳ Pending |

### Contracts Implemented

```
DiarizationContract
VideoCaptionContract
```

### Acceptance Criteria

- [ ] Diarization attaches speaker label artifacts to audio segments
- [ ] Video splits into audio segments + frame segments
- [ ] Frame captions attached as artifacts
- [ ] Unified search merges transcript + visual matches
- [ ] Speaker-filtered search works ("find where Alice said budget")

### Demo Scenario

```
1. Import meeting video
2. Search "quarterly results" 
3. Results from: transcript mentions, slide with "Q3 Results" caption
4. Filter by speaker: "Alice"
5. Click result → video seeks to timestamp
6. See speaker label in timeline
```

### Validation

```bash
./Scripts/harmonia-surface.sh segment-video-flow
```

---

## Phase 4: Knowledge Graph

**Objective:** Entities → Graph → Explorer UI with cross-document linking.

### Deliverables

| Artifact | Path | Status |
|----------|------|--------|
| Entity Extraction Executor | `Sources/ContextumModule/Execution/EntityExtractionExecutor.swift` | ⏳ Pending |
| Entity Resolution Executor | `Sources/ContextumModule/Execution/EntityResolutionExecutor.swift` | ⏳ Pending |
| Co-Retrieval Tracker | `Sources/ContextumModule/Systems/CoRetrievalTracker.swift` | ⏳ Pending |
| Graph Store | `Sources/ContextumModule/Database/GraphStore.swift` | ⏳ Pending |
| Graph Explorer UI | `Sources/AnigmaAppMac/Surfaces/GraphExplorerView.swift` | ⏳ Pending |

### Contracts Implemented

```
ExtractEntitiesContract
ResolveEntitiesContract
```

### Acceptance Criteria

- [ ] Entities extracted with span positions in segment text
- [ ] Mention relations link segments to entity nodes
- [ ] Same-as relations cluster equivalent entities
- [ ] Co-retrieval frequency becomes edge weight
- [ ] Graph explorer shows entity → mentions → related entities
- [ ] Timeline view of entity mentions across documents

### Demo Scenario

```
1. Import 10 documents mentioning "Alice Chen"
2. Open Graph Explorer
3. Search "Alice Chen" → see entity node
4. Expand → see all 23 mentions across documents
5. See related entities: "Acme Corp", "Q3 Budget", "Board Meeting"
6. Click mention → jump to source segment with highlight
7. Timeline shows mentions by date
```

### Validation

```bash
./Scripts/harmonia-surface.sh segment-graph-flow
```

---

## Phase 5: NLP Transforms

**Objective:** Translation, summarization, classification, redaction as segment-based transforms.

### Deliverables

| Artifact | Path | Status |
|----------|------|--------|
| Translation Executor | `Sources/ContextumModule/Execution/TranslationExecutor.swift` | ⏳ Pending |
| Summarization Executor | `Sources/ContextumModule/Execution/SummarizationExecutor.swift` | ⏳ Pending |
| Classification Executor | `Sources/ContextumModule/Execution/ClassificationExecutor.swift` | ⏳ Pending |
| Redaction Executor | `Sources/ContextumModule/Execution/RedactionExecutor.swift` | ⏳ Pending |

### Contracts Implemented

```
TranslateContract
SummarizeContract
ClassifyContract
RedactContract
```

### Acceptance Criteria

- [ ] Translation produces parallel text artifacts linked to source
- [ ] Summarization includes supporting segment links
- [ ] Classification applies labels/categories to segments
- [ ] Redaction is policy-gated and reversible in evidence store
- [ ] All transforms produce receipts with model provenance

---

## Dependencies

### Required Before Phase 0

- [x] ADR-MODEL-CONTRACT-SYSTEM approved
- [x] MLWorker execution infrastructure
- [x] Receipt/evidence spine operational

### Required Before Phase 1

- [ ] Phase 0 complete (types committed)
- [ ] PDF rendering infrastructure (existing)
- [ ] Vector index implementation (FAISS/HNSW or builtin)

### Required Before Phase 2

- [ ] Phase 1 complete
- [ ] Whisper MLX backend operational
- [ ] Audio player component

### Required Before Phase 3

- [ ] Phase 2 complete
- [ ] Diarization model integrated
- [ ] Video player component

### Required Before Phase 4

- [ ] Phase 3 complete (entities exist)
- [ ] Graph database infrastructure

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Vector index performance | Benchmark early, consider SQLite-vec or external index |
| OCR accuracy variance | Store confidence, allow manual correction as artifact |
| Diarization instability | Keep probabilistic, support manual speaker labeling |
| Graph query complexity | Start with simple traversals, add advanced queries later |
| Migration disruption | Keep legacy adapters until Phase 4 complete |

---

## Governance Checkpoints

### Phase Gate: 0 → 1

- [ ] All types compile and serialize correctly
- [ ] ADR approved by governance
- [ ] No blocking feedback from review

### Phase Gate: 1 → 2

- [ ] Document vertical demo passes
- [ ] Citation UI works end-to-end
- [ ] Performance budget met (<2s search)

### Phase Gate: 2 → 3

- [ ] Audio vertical demo passes
- [ ] Transcript + playback sync works
- [ ] No regressions in document flow

### Phase Gate: 3 → 4

- [ ] Video vertical demo passes
- [ ] Diarization accuracy acceptable (>80% on test set)
- [ ] Multimodal search merges correctly

### Phase Gate: 4 → 5

- [ ] Graph explorer demo passes
- [ ] Entity resolution working
- [ ] Co-retrieval edges populate

---

## Metrics

| Metric | Target | Phase |
|--------|--------|-------|
| PDF segment extraction time | <500ms/page | 1 |
| Embedding throughput | >100 segments/sec | 1 |
| Search latency (10k segments) | <200ms | 1 |
| QA citation accuracy | >95% grounded | 1 |
| ASR word error rate | <10% | 2 |
| Diarization accuracy | >80% | 3 |
| Entity F1 score | >0.85 | 4 |
| Graph query time (3-hop) | <500ms | 4 |

---

**Phase Status:** Planning  
**Next Action:** Implement Phase 0 types in `Sources/ContextumModule/IR/`
