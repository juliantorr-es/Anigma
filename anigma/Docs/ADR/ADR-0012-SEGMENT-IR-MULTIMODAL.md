# ADR-0012: SegmentIR — Multimodal Content Intermediate Representation

> **Status:** Accepted  
> **Date:** 2026-01-07  
> **Supersedes:** None  
> **Superseded by:** None  
> **Phase Contract:** This ADR establishes the foundational IR for all ML operations in Anigma.

---

## Context

Anigma's ML capabilities—perception, understanding, retrieval, generation, and transformation—currently lack a unified substrate. Each feature (embeddings, search, QA, transcription) invents its own data model for "pieces of content":

- `ChunkComponent` handles text chunks with byte ranges
- `EmbeddingComponent` stores vectors attached to chunk hashes
- Audio/video/image intake have no shared representation

This leads to:

1. **Siloed implementations** — Each modality (PDF, audio, video) requires separate models
2. **Broken citations** — No way to trace an answer back to exact source coordinates
3. **No composability** — Can't run "summarize extracted entities from video transcript" without custom glue
4. **Graph fragmentation** — Knowledge graphs can't link across modalities
5. **Receipt gaps** — Evidence chain can't anchor to specific content regions

The solution is a **canonical SegmentIR**: one representation for "a piece of a thing" that works across all modalities, with provenance, artifact attachment, and graph edges.

---

## Decision

### Core Principle: Segments Are The Universal Substrate

Every piece of content in Anigma becomes **Segments**. Segments have:

1. **Stable IDs** — Content-addressable (hash-based) with optional user aliases
2. **Provenance anchors** — Exact source coordinates (page+box, timestamp range, image region)
3. **Artifact slots** — Derived data (embeddings, transcripts, captions, entities) attached by segment ID
4. **Graph edges** — Relations to other segments (mentions, co-retrieval, same-as, supports)
5. **Receipt chains** — Every transformation produces evidence tied to segment IDs

**Everything becomes "artifacts attached to segments."**

---

## Type Schemas

All types defined in `ContextumModule/IR/` with re-exports in `ContractsCore`.

### 1. Segment — The Core IR Type

```swift
/// A canonical unit of content with stable identity and provenance.
/// Works across all modalities: text, audio, video, images, documents.
public struct Segment: Codable, Hashable, Sendable, Identifiable {
    /// Stable, content-addressable identifier (SHA256 of canonical form)
    public let id: SegmentID
    
    /// Source artifact this segment was extracted from
    public let sourceHash: String
    
    /// Where in the source this segment lives
    public let provenance: SegmentProvenance
    
    /// Primary modality of this segment
    public let modality: SegmentModality
    
    /// Optional text content (may be OCR'd, transcribed, or native)
    public let text: String?
    
    /// Confidence score if content was extracted (OCR, ASR, etc.)
    public let extractionConfidence: Double?
    
    /// Language code (ISO 639-1) if detected
    public let language: String?
    
    /// When this segment was created
    public let createdAt: Date
    
    /// Receipt ID of the extraction operation that created this segment
    public let extractionReceiptID: String
}

public struct SegmentID: Codable, Hashable, Sendable, RawRepresentable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    
    /// Create from content hash
    public static func fromHash(_ hash: String) -> SegmentID {
        SegmentID(rawValue: "seg_\(hash.prefix(16))")
    }
}

public enum SegmentModality: String, Codable, Sendable, CaseIterable {
    case text         // Native text, extracted text chunks
    case document     // PDF page, document region with layout
    case audio        // Audio time range
    case video        // Video time range (may have audio + visual)
    case image        // Image region, figure, diagram
    case table        // Extracted table structure
    case figure       // Diagram, chart, illustration
}
```

### 2. SegmentProvenance — Source Coordinates

```swift
/// Exact location in source content where this segment lives.
/// Enables citations, highlights, and playback positioning.
public struct SegmentProvenance: Codable, Hashable, Sendable {
    /// Type of provenance anchor
    public let anchor: ProvenanceAnchor
    
    /// Original source file hash
    public let sourceFileHash: String
    
    /// MIME type of source
    public let sourceMIME: String
}

public enum ProvenanceAnchor: Codable, Hashable, Sendable {
    /// Document: page number and bounding box
    case document(DocumentAnchor)
    
    /// Audio/Video: time range in seconds
    case temporal(TemporalAnchor)
    
    /// Image: pixel region
    case region(RegionAnchor)
    
    /// Text: byte or character range in source
    case textSpan(TextSpanAnchor)
    
    /// Composite: multiple anchors (e.g., video = temporal + visual)
    case composite([ProvenanceAnchor])
}

public struct DocumentAnchor: Codable, Hashable, Sendable {
    public let pageNumber: Int          // 1-indexed
    public let boundingBox: BoundingBox // Normalized 0-1 coordinates
    public let readingOrder: Int?       // Position in reading flow
    public let blockType: BlockType?    // Paragraph, heading, table, figure, etc.
}

public struct BoundingBox: Codable, Hashable, Sendable {
    public let x: Double      // Left edge, 0-1
    public let y: Double      // Top edge, 0-1
    public let width: Double  // 0-1
    public let height: Double // 0-1
}

public enum BlockType: String, Codable, Sendable {
    case paragraph, heading, listItem, table, tableCell
    case figure, figureCaption, header, footer, footnote
}

public struct TemporalAnchor: Codable, Hashable, Sendable {
    public let startSeconds: Double
    public let endSeconds: Double
    public let speakerLabel: String?  // From diarization
    public let channel: Int?          // For multi-channel audio
}

public struct RegionAnchor: Codable, Hashable, Sendable {
    public let x: Int           // Pixel coordinates
    public let y: Int
    public let width: Int
    public let height: Int
    public let sourceWidth: Int  // Original image dimensions
    public let sourceHeight: Int
}

public struct TextSpanAnchor: Codable, Hashable, Sendable {
    public let byteStart: Int
    public let byteEnd: Int
    public let characterStart: Int?
    public let characterEnd: Int?
    public let lineNumber: Int?
}
```

### 3. SegmentArtifact — Derived Data Attached to Segments

```swift
/// Any derived artifact attached to a segment.
/// Embeddings, transcripts, captions, entities, annotations, etc.
public struct SegmentArtifact: Codable, Hashable, Sendable, Identifiable {
    public let id: ArtifactID
    public let segmentID: SegmentID
    public let kind: ArtifactKind
    public let payload: ArtifactPayload
    public let modelSpec: ModelSpec?       // Model that produced this, if ML-derived
    public let receiptID: String           // Receipt proving this artifact's creation
    public let createdAt: Date
}

public struct ArtifactID: Codable, Hashable, Sendable, RawRepresentable {
    public let rawValue: String
}

public enum ArtifactKind: String, Codable, Sendable {
    // Embeddings
    case textEmbedding
    case imageEmbedding
    case audioEmbedding
    case videoEmbedding
    case multimodalEmbedding
    
    // Text artifacts
    case transcript        // ASR output
    case caption           // Image/video captioning
    case ocrText           // OCR extraction
    case translation       // Translated text
    case summary           // Summarization output
    
    // Structured extraction
    case entities          // Named entities
    case tableStructure    // Parsed table rows/cols
    case layoutAnalysis    // Document layout
    
    // Annotations
    case speakerLabel      // Diarization
    case classification    // Text/image classification
    case redaction         // Redaction markers
    case userAnnotation    // Human annotation
}

public enum ArtifactPayload: Codable, Hashable, Sendable {
    /// Vector embedding
    case embedding(EmbeddingPayload)
    
    /// Text-based artifact (transcript, caption, summary, etc.)
    case text(TextPayload)
    
    /// Extracted entities
    case entities(EntityPayload)
    
    /// Structured table
    case table(TablePayload)
    
    /// Generic JSON for extensibility
    case json(Data)
}

public struct EmbeddingPayload: Codable, Hashable, Sendable {
    public let vector: [Float]
    public let dimensions: Int
    public let modelID: String
    public let modelHash: String
    public let normalizedL2: Bool
}

public struct TextPayload: Codable, Hashable, Sendable {
    public let text: String
    public let confidence: Double?
    public let language: String?
    /// For translations: source language
    public let sourceLanguage: String?
    /// For summaries: compression ratio
    public let compressionRatio: Double?
}

public struct EntityPayload: Codable, Hashable, Sendable {
    public let entities: [ExtractedEntity]
}

public struct ExtractedEntity: Codable, Hashable, Sendable {
    public let text: String
    public let label: String           // PERSON, ORG, DATE, etc.
    public let confidence: Double
    public let spanStart: Int          // Character offset in segment text
    public let spanEnd: Int
    public let resolvedID: String?     // Linked entity ID if resolved
}

public struct TablePayload: Codable, Hashable, Sendable {
    public let rows: [[TableCell]]
    public let headerRowCount: Int
    public let headerColCount: Int
}

public struct TableCell: Codable, Hashable, Sendable {
    public let text: String
    public let rowSpan: Int
    public let colSpan: Int
    public let isHeader: Bool
}
```

### 4. SegmentRelation — Graph Edges

```swift
/// A directed edge between segments for knowledge graph construction.
public struct SegmentRelation: Codable, Hashable, Sendable, Identifiable {
    public let id: RelationID
    public let sourceSegmentID: SegmentID
    public let targetSegmentID: SegmentID
    public let kind: RelationKind
    public let weight: Double?          // For weighted edges (co-retrieval frequency, etc.)
    public let metadata: [String: String]
    public let receiptID: String?       // If derived by ML
    public let createdAt: Date
}

public struct RelationID: Codable, Hashable, Sendable, RawRepresentable {
    public let rawValue: String
}

public enum RelationKind: String, Codable, Sendable {
    // Provenance relations
    case extractedFrom       // Segment extracted from another segment/document
    case derivedFrom         // Summary/translation derived from source
    case versionOf           // Same content, different version
    
    // Semantic relations
    case mentions            // Segment mentions an entity (target = entity segment)
    case sameAs              // Entity resolution: same real-world entity
    case relatedTo           // Semantic similarity link
    case supports            // Evidence: this segment supports a claim
    case contradicts         // Evidence: this segment contradicts a claim
    
    // Retrieval relations
    case coRetrieved         // Frequently retrieved together
    case answeredBy          // QA: question segment answered by this segment
    case citedBy             // This segment cited by another
    
    // Structural relations
    case follows             // Reading order / temporal sequence
    case contains            // Parent-child (page contains paragraphs)
    case crossReferences     // Explicit cross-reference
}
```

### 5. SegmentIndex — Query Interface

```swift
/// The segment index provides query capabilities across all segments.
public protocol SegmentIndex: Sendable {
    /// Store a new segment
    func insert(_ segment: Segment) async throws
    
    /// Attach an artifact to a segment
    func attach(_ artifact: SegmentArtifact) async throws
    
    /// Create a relation between segments
    func relate(_ relation: SegmentRelation) async throws
    
    /// Query segments by provenance (e.g., all segments from page 5)
    func query(sourceHash: String, anchor: ProvenanceAnchor?) async throws -> [Segment]
    
    /// Query artifacts for a segment
    func artifacts(segmentID: SegmentID, kind: ArtifactKind?) async throws -> [SegmentArtifact]
    
    /// Vector search across embeddings
    func vectorSearch(
        query: [Float],
        modality: SegmentModality?,
        limit: Int,
        threshold: Double?
    ) async throws -> [(Segment, Double)]
    
    /// Graph traversal from a segment
    func neighbors(
        segmentID: SegmentID,
        relationKinds: [RelationKind]?,
        direction: TraversalDirection,
        depth: Int
    ) async throws -> [SegmentRelation]
    
    /// Full-text search with segment provenance
    func textSearch(query: String, limit: Int) async throws -> [(Segment, Double)]
}

public enum TraversalDirection: String, Codable, Sendable {
    case outgoing, incoming, both
}
```

---

## Task Contracts Built On SegmentIR

With SegmentIR as the foundation, all ML operations become **contracts that consume and produce segments/artifacts**:

### Document Intake Contract

```swift
public struct DocumentIntakeContract: TaskContract {
    static let taskKind = "document.intake"
    
    public struct Input: Codable {
        let sourceFileHash: String
        let sourceMIME: String
        let options: IntakeOptions
    }
    
    public struct Output: Codable {
        let segments: [Segment]          // Page segments, text blocks, etc.
        let artifacts: [SegmentArtifact] // OCR text, layout analysis
        let relations: [SegmentRelation] // Reading order, contains
        let receiptID: String
    }
    
    public struct IntakeOptions: Codable {
        let performOCR: Bool
        let extractTables: Bool
        let extractFigures: Bool
        let detectLanguage: Bool
    }
}
```

### Embedding Contract

```swift
public struct EmbedSegmentsContract: TaskContract {
    static let taskKind = "segments.embed"
    
    public struct Input: Codable {
        let segmentIDs: [SegmentID]
        let modelSpec: ModelSpec
        let modality: SegmentModality
    }
    
    public struct Output: Codable {
        let artifacts: [SegmentArtifact]  // Embedding artifacts
        let receiptID: String
    }
}
```

### Transcription Contract

```swift
public struct TranscribeContract: TaskContract {
    static let taskKind = "audio.transcribe"
    
    public struct Input: Codable {
        let sourceFileHash: String
        let modelSpec: ModelSpec
        let options: TranscriptionOptions
    }
    
    public struct Output: Codable {
        let segments: [Segment]           // Timestamp segments
        let artifacts: [SegmentArtifact]  // Transcript text artifacts
        let receiptID: String
    }
    
    public struct TranscriptionOptions: Codable {
        let language: String?
        let enableDiarization: Bool
        let enableVAD: Bool
    }
}
```

### Document QA Contract

```swift
public struct DocumentQAContract: TaskContract {
    static let taskKind = "qa.document"
    
    public struct Input: Codable {
        let question: String
        let scopeSegmentIDs: [SegmentID]?  // Limit to these segments
        let retrievalLimit: Int
        let modelSpec: ModelSpec
    }
    
    public struct Output: Codable {
        let answer: String
        let citedSegments: [SegmentID]     // Grounded citations!
        let confidence: Double
        let retrievalReceiptID: String     // Receipt for retrieval step
        let answerReceiptID: String        // Receipt for generation step
    }
}
```

### Entity Extraction Contract

```swift
public struct ExtractEntitiesContract: TaskContract {
    static let taskKind = "nlp.entities"
    
    public struct Input: Codable {
        let segmentIDs: [SegmentID]
        let modelSpec: ModelSpec
        let entityTypes: [String]?  // Filter to specific types
    }
    
    public struct Output: Codable {
        let artifacts: [SegmentArtifact]   // Entity payloads
        let relations: [SegmentRelation]   // Mentions edges
        let receiptID: String
    }
}
```

---

## Implementation Phases

### Phase 0: Schema Lock ✓ (This ADR)

- Define `Segment`, `SegmentProvenance`, `SegmentArtifact`, `SegmentRelation` types
- Define `SegmentIndex` protocol
- No implementation yet — just contracts

### Phase 1: Document Vertical (MVP)

**Goal:** PDF → Segments → Embeddings → Search → QA with citations

**Deliverables:**
1. `PDFIntakeExecutor` producing `Segment` array with `DocumentAnchor` provenance
2. `SegmentEmbeddingExecutor` producing `SegmentArtifact` embeddings
3. `SegmentIndex` implementation with vector search
4. `HybridSearchSystem` refactored to return `Segment` results with exact citations
5. `DocumentQAExecutor` with grounded citations

**Success Criteria:**
- Import PDF → click search result → highlight exact region on page
- QA answer includes clickable `[1]` citations jumping to source

### Phase 2: Audio Vertical

**Goal:** Audio → Timestamp Segments → Transcript → Embeddings → Search

**Deliverables:**
1. `AudioIntakeExecutor` producing `Segment` array with `TemporalAnchor` provenance
2. `TranscriptionExecutor` attaching transcript `SegmentArtifact`
3. Audio search returning timestamp segments
4. Playback jump-to-timestamp on click

**Success Criteria:**
- Import audio → search → click result → audio player jumps to timestamp
- Transcript view highlights matching segments

### Phase 3: Diarization + Video

**Goal:** Speaker labels, video transcription, frame captioning

**Deliverables:**
1. `DiarizationExecutor` attaching speaker label artifacts
2. `VideoIntakeExecutor` splitting audio + sampled frames
3. `FrameCaptioningExecutor` for visual captions
4. Unified video search (transcript + visual)

**Success Criteria:**
- Video search by spoken words AND by visual content
- Speaker-filtered search ("find where Alice talked about budgets")

### Phase 4: Knowledge Graph

**Goal:** Entities → Graph → Explorer UI

**Deliverables:**
1. `EntityExtractionExecutor` producing entity artifacts + mention relations
2. `EntityResolutionExecutor` producing same-as relations
3. `CoRetrievalTracker` producing co-retrieval relations
4. Graph query API on `SegmentIndex`
5. Graph explorer UI surface

**Success Criteria:**
- Click entity → see all mentions across documents
- See related entities by co-occurrence
- Timeline view of entity mentions

### Phase 5: NLP Transforms

**Goal:** Translation, summarization, classification, redaction

**Deliverables:**
1. `TranslationExecutor` producing translated text artifacts
2. `SummarizationExecutor` with compression ratio and supporting segment links
3. `ClassificationExecutor` for routing/tagging
4. `RedactionExecutor` with policy-gated markers

---

## Constraints

### From Constitution & Governance

- **Local-first:** All segment operations run on-device
- **Evidence chains:** Every artifact has a receipt linking to model + input + output hashes
- **Policy gates:** Redaction, translation, and entity extraction are capability-gated
- **Provenance is mandatory:** No segment without source coordinates

### From ADR-MODEL-CONTRACT-SYSTEM

- Models are tiered (first-class, compatible, experimental)
- Every ML operation uses `ModelSpec` + `RunSpec`
- Receipts are court-safe (model hash, input hash, output hash)

### From Current Architecture

- SegmentIR types live in `ContextumModule/IR/`
- Contracts re-exported via `ContractsCore`
- Executors are actors in `ContextumModule/Execution/`
- UI surfaces consume `Segment` directly for citations

---

## Migration

### ChunkComponent → Segment

`ChunkComponent` becomes a convenience constructor for `Segment` with `textSpan` provenance:

```swift
extension Segment {
    init(fromChunk chunk: ChunkComponent) {
        self.init(
            id: SegmentID.fromHash(chunk.contentHash),
            sourceHash: chunk.sourceId,
            provenance: SegmentProvenance(
                anchor: .textSpan(TextSpanAnchor(
                    byteStart: chunk.byteRange.lowerBound,
                    byteEnd: chunk.byteRange.upperBound,
                    characterStart: nil,
                    characterEnd: nil,
                    lineNumber: nil
                )),
                sourceFileHash: chunk.contentHash,
                sourceMIME: "text/plain"
            ),
            modality: .text,
            text: chunk.content,
            extractionConfidence: nil,
            language: nil,
            createdAt: chunk.timestamp,
            extractionReceiptID: "legacy-chunk-\(chunk.chunkId)"
        )
    }
}
```

### EmbeddingComponent → SegmentArtifact

`EmbeddingComponent` becomes a `SegmentArtifact` with `textEmbedding` kind:

```swift
extension SegmentArtifact {
    init(fromEmbedding embedding: EmbeddingComponent, segmentID: SegmentID) {
        self.init(
            id: ArtifactID(rawValue: embedding.embeddingId),
            segmentID: segmentID,
            kind: .textEmbedding,
            payload: .embedding(EmbeddingPayload(
                vector: embedding.vector,
                dimensions: embedding.vectorDimensions,
                modelID: embedding.modelId,
                modelHash: embedding.modelHash,
                normalizedL2: false
            )),
            modelSpec: nil,  // Populate from registry
            receiptID: embedding.receiptId,
            createdAt: embedding.timestamp
        )
    }
}
```

### Deprecation Timeline

1. **Immediate:** New code uses `Segment` + `SegmentArtifact`
2. **Phase 1 complete:** All PDF flows use SegmentIR
3. **Phase 2 complete:** All audio flows use SegmentIR
4. **Phase 3 complete:** `ChunkComponent` and `EmbeddingComponent` marked deprecated
5. **v2.0:** Legacy types removed

---

## Success Criteria

✅ One `Segment` type handles PDF pages, audio ranges, video frames, image regions  
✅ Citations are clickable and jump to exact source locations  
✅ Embeddings, transcripts, captions, entities all attach to segment IDs  
✅ Knowledge graph built from segment relations  
✅ Every artifact has receipt proving its provenance  
✅ Search returns segments with scores, not raw text blobs  
✅ QA refuses to answer when retrieval confidence is low  
✅ Legacy migration path exists for existing chunks/embeddings  

---

## What We Will NOT Do

❌ Separate data models per modality  
❌ Citations as string matching (must be segment ID anchored)  
❌ Embeddings without model provenance  
❌ Artifacts without receipts  
❌ Graph edges without traceable source  
❌ "Any-to-any" without defined contracts  

---

## References

- ADR-MODEL-CONTRACT-SYSTEM: Model tiering and task contracts
- `ContextumModule/Components/ChunkComponent.swift`: Legacy chunk type
- `ContextumModule/Components/EmbeddingComponent.swift`: Legacy embedding type
- `ContextumModule/Execution/MLWorkerEmbeddingExecutor.swift`: Current embedding flow

---

**Decision:** SegmentIR is the universal substrate for all Anigma ML operations.

**Status:** Accepted  
**Next:** Implement Phase 0 types in `ContextumModule/IR/`
