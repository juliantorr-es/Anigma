# ADR-0016: PDF Page Atlas Execution Substrate

> **Status:** Proposed
> **Date:** 2026-04-20
> **Supersedes:** None
> **Superseded by:** None
> **TD:** `td-d5a219`

---

## Context

Anigma needs fast PDF viewing, search, selection, annotation overlays, and tile-based zoom/scroll rendering without pretending that PDF is a simple GPU-native vector format.

PDFium already provides the compatibility surface Anigma needs for PDF parsing, page loading, font and format edge cases, text extraction, annotation discovery, progressive rendering, and CPU fallback rendering. Metal should own the steady-state render path once page truth has been extracted and normalized.

The architecture needs a post-parse execution substrate:

- cold source: raw PDF bytes
- truth oracle: PDFium
- hot page data: mmap-friendly atlas sections
- executable work: bounded tile render missions
- steady-state pixels: Metal

This ADR records the **PDF Page Atlas** design.

---

## Decision

Introduce **PDF Page Atlas** as a post-parse, memory-mappable page substrate for PDF viewing and interaction. It is not a PDF replacement format. It is the sealed, hot representation emitted after PDFium has parsed the source document.

Internal thesis:

```text
PDFium is the parser and truth oracle.
Page Atlas is the execution substrate.
Tile missions are executable work.
Metal is the steady-state renderer.
```

Operational law:

```text
Raw PDF is cold truth.
Page Atlas is hot, sealed page truth.
PDFium wakes for ingest, fallback, and validation.
Metal owns interactive steady-state pixels.
```

### Page Artifacts

Each page atlas emits four durable artifact families:

1. **PageManifest**
   - page id
   - source PDF hash
   - page boxes
   - rotation
   - version
   - compatibility flags
   - section directory hash
   - build receipt hash

2. **TextAtlas**
   - UTF payload
   - fixed-size character records
   - text run records
   - reading order metadata
   - line/block/cluster ids
   - spatial bins for hit-testing, selection, hover, search, and highlights

3. **DrawAtlas**
   - normalized draw operation lanes
   - path segment Structure-of-Arrays lanes
   - style and transform tables
   - glyph run references
   - image references and deferred decode policy
   - clip and transparency group records

4. **TilePlan**
   - stable page-space tile decomposition
   - zoom bands
   - dependency spans into text, path, glyph, image, and overlay lanes
   - render mission inputs

Runtime cache state must remain separate from durable page truth. A `TileCacheState` or equivalent runtime layer may track residency, priority, last-used frame, and GPU resource handles, but those fields are not canonical atlas facts.

### File Layout

The atlas file is binary, memory-mappable, offset-based, and sectioned.

Required rules:

- fixed 4 KB header page
- no raw pointers
- all cross-references use offsets, lengths, section ids, and element counts
- section directory entries include kind, offset, length, count, alignment, codec, and hash/checksum
- sections are at least 64-byte aligned
- large numeric lanes may be 4 KB aligned for mmap and shared-page behavior
- sealed atlas files are immutable
- mutable overlays live in separate epoch/versioned stores

Representative section kinds:

- `TEXT_UTF8`
- `TEXT_CHARS`
- `TEXT_RUNS`
- `TEXT_SPATIAL_BINS`
- `GLYPH_RUNS`
- `DRAW_OPS`
- `PATHS`
- `PATH_SEGMENTS`
- `STYLES`
- `TRANSFORMS`
- `IMAGES`
- `IMAGE_REFS`
- `CLIP_STACKS`
- `TRANSPARENCY_GROUPS`
- `ANNOTS`
- `LINKS`
- `TILE_PLAN`
- `VALIDATION_RECEIPTS`

### TextAtlas

Build TextAtlas first. It provides immediate product value before full GPU-native page replay exists.

Character records should preserve PDFium-derived coordinate truth and selection reconstruction metadata:

- `char_index`
- `source_char_index`
- `utf_offset`
- `utf_length`
- `unicode_scalar_start`
- `cluster_id`
- `run_id`
- `line_id`
- `block_id`
- `reading_order`
- `pdf_user_box`
- `normalized_page_box`
- `origin`
- `baseline`
- `selection_affinity`
- `flags`

Required flags include:

- whitespace
- line break
- ligature member
- synthetic space
- RTL
- vertical text
- hidden
- generated
- extraction uncertain

Text runs group contiguous characters that share font/style/transform metadata.

Spatial bins map page regions to compact character posting lists for:

- selection hit-test
- hover lookup
- nearest character search
- highlight painting
- link and annotation geometry joins

### Annotation Atlas

Annotation and link records remain separate from raw draw replay.

Per annotation:

- subtype
- bounds
- quadpoints when available
- appearance reference
- interaction flags
- destination or URI
- z-order bucket
- accessibility metadata
- source object reference

Rationale: annotations have product semantics: hover, click, edit handles, external actions, accessibility, and policy. They must not be buried in the same hot lane as static path replay.

### DrawAtlas

DrawAtlas stores GPU-replayable visual instructions as Structure-of-Arrays lanes, not object graphs.

Representative draw operation record:

- op type
- style id
- transform id
- payload offset
- payload count
- bounds ref
- clip stack ref
- compatibility flags

Representative operation types:

- fill path
- stroke path
- draw image
- draw glyph run
- begin clip
- end clip
- begin transparency group
- end transparency group

Page-level capability flags must be explicit:

- `gpu_replay_complete`
- `requires_pdfium_base`
- `has_unsupported_blend`
- `has_complex_clip`
- `has_type3_font`
- `has_overprint`
- `has_soft_mask`
- `has_pattern_shading`

These flags let the renderer choose GPU replay, hybrid replay, or PDFium fallback per page or tile.

### Tile Missions

The scheduler must not submit vague "draw page" work. It submits bounded render missions.

Mission shape:

```text
RenderTileMission =
  page manifest hash
  atlas receipt hash
  page id
  zoom band
  tile rect
  dependency spans
  overlay epoch
  output target
  resource budget
  fallback policy
  validation mode
```

Mission payloads reference atlas spans. They do not copy page payload data.

This maps PDF rendering into Anigma's hardware-saturated execution model: bounded work, explicit dependencies, receiptable inputs, policy gates, and verifier lanes.

### Metal Memory Policy

The memory rule is:

```text
Never copy by accident.
Copy once on purpose when GPU residency is the win.
```

Use shared or `bytesNoCopy`-style wrapping for:

- small control data
- visible range indices
- tile manifests
- interaction buffers
- frequently updated overlay data

Use private Metal resources for:

- large static path payloads
- tessellated geometry
- decoded image textures
- long-lived GPU-only page assets

Atlas mmap sections are immutable source truth. GPU caches are derived runtime state.

---

## V1 Scope

Do not make v1 depend on perfect native PDF vector replay.

V1 should deliver:

- PageManifest
- TextAtlas
- Annotation Atlas
- TilePlan
- PDFium-backed raster tile fallback
- Metal tile compositor
- Metal overlay renderer for selection, highlights, links, and annotations
- validation harness comparing PDFium reference output against Metal/hybrid output

DrawAtlas should be incremental:

1. glyph and text overlay lanes
2. image references and proxy thumbnails
3. simple path spans
4. clipped path regions
5. transparency groups and exotic blend modes

This gives immediate viewer wins while keeping full PDF graphics replay as an acceleration path, not a v1 existential dependency.

---

## Validation

Native rendering must be evidence-driven.

For sampled pages or tiles:

1. render PDFium CPU reference
2. render atlas plus Metal or hybrid path
3. diff outputs with tolerance profile
4. classify mismatch
5. store validation receipt

Mismatch classes:

- glyph placement drift
- clip mismatch
- blend mismatch
- image decode mismatch
- annotation appearance mismatch
- coordinate transform mismatch
- fallback divergence

Validation state should be explicit:

- unvalidated
- CPU reference only
- GPU sampled validated
- GPU fully validated
- fallback required

---

## Rationale

This boundary matches tool reality.

PDFium is good at compatibility, parsing, text extraction, annotation discovery, and CPU rendering. Metal is good at predictable, repeated, bounded rendering and compositing work once data is already normalized. Page Atlas bridges those worlds without making either layer own the wrong job.

The design also matches Anigma's existing architectural direction:

- Binary Atlas / mmap over repeated JSON/object transforms
- Structure-of-Arrays for hot numeric lanes
- mission descriptors for bounded accelerated work
- evidence receipts and verifier lanes for correctness
- immutable truth artifacts with mutable overlays separated by epoch

### Alternatives Considered

1. **PDFium-only runtime rendering**
   - Simpler compatibility story.
   - Leaves scroll/zoom/overlay performance tied to CPU rendering and per-frame library calls.

2. **Full native PDF renderer first**
   - Attractive steady-state target.
   - High risk because full PDF graphics semantics are broad and pathological.
   - Delays useful search, selection, annotation, and tile scheduling wins.

3. **Pre-rasterize all zoom levels**
   - Simple renderer.
   - Explodes storage and still performs badly for arbitrary zoom, annotations, edits, and high-DPI displays.

4. **Hybrid Page Atlas v1**
   - Uses PDFium for truth and fallback.
   - Uses Metal where the data is already safe and normalized.
   - Lets DrawAtlas mature incrementally.
   - Selected.

---

## Consequences

### Positive

- Fast text search, selection, hit-testing, highlighting, and link discovery can land before full GPU replay.
- PDFium compatibility remains available.
- Metal work becomes bounded tile missions instead of unbounded page rendering.
- Atlas files can be memory-mapped and shared across viewer subsystems.
- Validation receipts make renderer correctness inspectable.

### Negative

- DrawAtlas extraction remains hard and may require PDFium integration beyond basic public render APIs.
- Multiple representations exist: raw PDF, sealed atlas, overlay epochs, GPU residency cache.
- Validation infrastructure is required early.
- Capability flags and fallback paths must be maintained carefully.

### Neutral

- Runtime cache policy moves outside durable atlas truth.
- Full fallback pixels are optional debug/preview artifacts, not required page truth.
- Mutable annotation edits are modeled as overlay epochs until committed back through document workflows.

---

## Ownership

### What This Owns

- Post-parse PDF page execution layout.
- PageManifest, TextAtlas, Annotation Atlas, DrawAtlas, and TilePlan schemas.
- Memory-mapped page atlas file layout and section directory rules.
- Tile mission input shape for PDF rendering.
- PDF-specific validation receipts and mismatch classes.

### What This Does Not Own

- PDF parsing compatibility; PDFium remains truth oracle.
- Relational registry/query authority; PostgreSQL stores references, manifests, and receipts.
- General document truth model semantics outside page execution.
- Mutable product annotation workflows except as overlay epochs.
- GPU residency cache state; runtime cache layers own residency and eviction.

---

## Runtime Budget

Each implementation must declare:

- max mmap atlas bytes per page/document
- max visible tile bytes
- max decoded image texture bytes
- max private Metal buffer bytes
- tile mission latency budget
- PDFium fallback latency budget
- validation sample rate
- cache eviction policy

Large static GPU resources should move to private Metal storage only when profiling or residency policy justifies the copy.

---

## Failure Behavior

- Unsupported draw feature: mark page/tile with compatibility flag and use PDFium fallback or hybrid rendering.
- Validation mismatch: classify mismatch, retain receipt, and demote affected page/tile from full GPU replay.
- Atlas hash mismatch: refuse mmap use and rebuild from source PDF.
- Missing image/font dependency: render fallback tile and record degraded capability.
- Memory pressure: evict runtime tile/GPU caches before invalidating sealed atlas truth.

---

## Verification

Before acceptance, this ADR requires:

- TextAtlas hit-test/selection fixtures
- annotation/link geometry fixtures
- mmap section reader tests
- PDFium reference render comparison harness
- Metal/hybrid tile diff tests with mismatch classes
- memory budget test for visible tile set and decoded image residency

---

## Migration

Near-term implementation order:

1. Define page atlas binary header, section directory, and receipt schema.
2. Implement TextAtlas ingest from PDFium text APIs.
3. Implement Annotation Atlas ingest from PDFium annotation APIs.
4. Implement TilePlan and PDFium-backed raster tile fallback.
5. Implement Metal tile compositor and overlay renderer.
6. Add validation harness and mismatch classification.
7. Add DrawAtlas lanes incrementally behind capability flags.

Package ownership should begin near `DocumentIRKit` and `DocumentRenderKit`, with PDFium-specific ingest isolated behind a provider boundary. Foundation APIs must remain narrow: atlas readers should expose typed views over lanes, not broad mutable model objects.

---

## References

- Related TD issue: `td-d5a219`
- Related architecture: `Docs/architecture/document-truth-model.md`
- Related packages: `Packages/DocumentIRKit`, `Packages/DocumentRenderKit`
- Related ADR: `ADR-0014: Tiered Truth Storage`
- Related ADR: `ADR-0004: Module Boundaries`
