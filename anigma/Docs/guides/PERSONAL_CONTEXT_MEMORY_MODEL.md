# Personal Context As An Evolving Memory System

This document models Anigma's personal context database as an evolving memory system rather than a static retrieval corpus.

`td` remains the source of truth for implementation order and current status. This document defines the target behavior and the design constraints implied by current research and platform practice.

## Why This Model

The relevant literature is converging on a few consistent lessons:

- long-term memory systems fail when they only store chunks and embeddings
- retrieval quality depends as much on indexing, update handling, and reading strategy as on ingestion
- preserving ground truth beats aggressive lossy extraction
- memory must support updates, conflict detection, temporal reasoning, and abstention
- strong systems separate working context, episodic memory, and higher-level profile memory

These points show up repeatedly in the following sources:

- Stanford's *Generative Agents* ([arXiv, April 2023](https://arxiv.org/abs/2304.03442))
- Microsoft's *LongMem* ([arXiv, June 2023](https://arxiv.org/abs/2306.07174))
- UC Berkeley's *MemGPT* ([arXiv, October 2023](https://arxiv.org/abs/2310.08560))
- *LongMemEval* benchmark ([arXiv, October 2024; revised March 2025](https://arxiv.org/abs/2410.10813))
- *MemInsight* ([arXiv, March 2025; revised July 2025](https://arxiv.org/abs/2503.21760))
- *E-mem* ([arXiv, January 2026](https://arxiv.org/abs/2601.21714))
- *MemMachine* ([arXiv, April 6, 2026](https://arxiv.org/abs/2604.04853))
- Anthropic memory docs ([docs](https://docs.anthropic.com/en/docs/claude-code/memory))
- OpenAI's in-house data-agent context architecture ([OpenAI, February 2026](https://openai.com/index/inside-our-in-house-data-agent/))

## Research Signals

### 1. Memory should preserve episodes, not only extracted facts

*Generative Agents* stores a running record of experiences, reflects over them, and retrieves dynamically for planning. *MemMachine* goes further and argues for a ground-truth-preserving design that stores whole episodes and reduces lossy extraction.

Implication for Anigma:

- the personal context system should retain canonical source episodes and source lineage
- summaries and profile facts should be derived layers, not the only retained memory

### 2. Memory needs tiers

*MemGPT* and Anthropic's context-management design both separate active context from longer-lived memory. *MemMachine* explicitly separates short-term, episodic, and profile memory.

Implication for Anigma:

- one storage class is not enough
- "context window", "search corpus", and "user memory" should not be treated as the same thing

### 3. Updates and temporal reasoning are core requirements

*LongMemEval* explicitly tests information extraction, multi-session reasoning, temporal reasoning, knowledge updates, and abstention. That is a strong signal that a useful memory system must handle change and uncertainty, not just retrieval.

Implication for Anigma:

- the system must represent supersession, freshness, and conflicts
- it must know when not to answer confidently from stale or ambiguous memory

### 4. Retrieval-stage quality matters more than chunking tweaks

*MemMachine* reports that retrieval-stage improvements contributed more than ingestion-stage chunking changes on long-term memory benchmarks. *LongMemEval* also highlights indexing, retrieval, and reading as separate design stages.

Implication for Anigma:

- chunking quality matters, but it is not the main differentiator
- query decomposition, time-aware query expansion, evidence packaging, and context formatting are first-class design concerns

### 5. Memory must be updateable without going stale

*LongMem* argues for a decoupled memory design that can cache and update long-term context without suffering from memory staleness.

Implication for Anigma:

- memory records need canonical identity and update semantics
- the system should not force full re-embedding or duplicate-source sprawl for every small source change

### 6. Session decomposition matters

*LongMemEval* highlights value granularity, session decomposition, and time-aware query expansion as important contributors to long-memory performance.

Implication for Anigma:

- episodic memory should preserve event and session boundaries, not only chunk boundaries
- retrieval should be able to reconstruct the relevant time slice before ranking semantic matches
- ingestion and replay should preserve enough structure to answer temporal questions accurately

### 7. Semantic augmentation is useful if it stays explicitly derived

*MemInsight* shows gains from augmenting history with semantic memory structures instead of relying only on raw retrieval.

Implication for Anigma:

- the system should support derived augmentation artifacts such as aliases, relationship hints, and retrieval helpers
- those artifacts should remain evidence-backed helpers layered above source truth
- profile memory and retrieval hints should be promoted from repeated evidence rather than silently becoming canonical truth

### 8. Episodic context reconstruction is stronger than destructive preprocessing

*E-mem* argues that compressing sequential experience into pre-defined structures can destroy context needed for deep reasoning, and instead favors episodic context reconstruction.

Implication for Anigma:

- Contextum should preserve enough raw episode structure to rebuild coherent evidence packets
- "fetch top K chunks" is not enough for high-quality memory use
- the system should be able to reconstruct an episode around the fact, not only the fact itself

### 9. Memory is one layer inside a broader context stack

OpenAI's in-house data-agent writeup describes a layered context stack including grounding metadata, annotations, enriched data, memory, and runtime context.

Implication for Anigma:

- memory quality should be judged partly by how well it participates in context assembly
- personal context retrieval should be packaged alongside source metadata and live task/runtime context
- memory cannot be the whole grounding story by itself

## What A Personal Context Database Actually Is

An effective personal context database is not:

- just a vector store
- just a search index
- just a document warehouse
- just conversation history

It is a memory system that continuously reconciles five things:

1. source truth
2. episodic experience
3. derived understanding
4. current relevance
5. safe uncertainty

## Target Memory Layers

### 1. Source Layer

This is the canonical ground-truth layer.

It should store:

- source identity
- canonical reference
- current content hash
- revision number
- discovered, last-seen, and stale timestamps
- raw or normalized artifact references
- provenance receipts

This layer should answer:

- what was ingested
- where it came from
- what version it is
- whether it is still current

Anigma already has strong primitives for this in [ContextSourceComponent.swift](/Users/user/Developer/GitHub/Anigma_clean/anigma/Sources/ContextumModule/Components/ContextSourceComponent.swift).

### 2. Episodic Layer

This stores full retrieval-usable episodes rather than only distilled facts.

Examples:

- document sections and chunks with lineage
- conversation turns
- tool outputs
- connector snapshots
- ingestion events and replay contexts

This layer should preserve:

- surrounding context
- temporal ordering
- evidence heads
- replayability
- event or session boundaries
- enough local structure to reconstruct the originating episode

Anigma already gestures in this direction through [DocumentTruthIngestLane.swift](/Users/user/Developer/GitHub/Anigma_clean/anigma/Sources/ContextumModule/Systems/DocumentTruthIngestLane.swift) and [ContextumDatabase.swift](/Users/user/Developer/GitHub/Anigma_clean/anigma/Sources/ContextumModule/Database/ContextumDatabase.swift).

### 3. Semantic Retrieval Layer

This is the query-serving layer for search and recall.

It should contain:

- lexical indexes
- embeddings
- chunk-level metadata
- time, source-type, and trust signals
- retrieval packaging rules
- time-aware query expansion rules
- derived augmentation hints that improve retrieval without replacing source truth

This layer should optimize:

- recall
- relevance
- freshness-aware filtering
- evidence bundling for the reader model
- episode reconstruction quality
- temporal slicing quality

It should not be treated as the source of truth.

### 4. Profile Layer

This is the durable user or workspace model inferred from repeated evidence.

Examples:

- recurring preferences
- stable entities and relationships
- trusted sources
- projects, people, places, systems
- persistent goals and habits

This layer should be:

- evidence-backed
- updateable
- conflict-aware
- lower write frequency than episodic memory

Nothing in the current repo looks fully mature here yet. This is a major missing capability if the goal is a strong personal context system rather than a search engine.

### 5. Working Context Layer

This is the active context assembled per task.

It should be built from:

- current task state
- recent interaction state
- retrieved episodic evidence
- relevant profile facts
- freshness and conflict checks

This follows the same practical split seen in *MemGPT* and Anthropic's context-management work: persistent memory exists outside the active prompt and must be selectively loaded.

## Additional 2026-04-10 Design Consequences

These newer findings sharpen the implementation target in four ways.

### A. Contextum should model event and session boundaries explicitly

Conversations, connector sync windows, document revisions, and tool runs should be treated as identifiable episodic units.

That means:

- chunk storage alone is insufficient
- retrieval should be able to ask for the right episode before or alongside the right chunk
- memory evaluation should test episode selection quality, not just fragment recall

### B. Retrieval packaging should be treated as a first-class memory product

The useful output of a mature memory system is not only ranked chunks. It is a structured evidence packet.

That packet should be able to include:

- source-truth pointers
- episode slices
- freshness and conflict markers
- profile priors
- abstention or uncertainty markers

### C. Memory writes should support governed augmentation

The system should deliberately support derived augmentation artifacts such as:

- alternate retrieval keys
- entity aliases
- relationship hints
- task-local memory summaries

These should remain explicitly derived and evidence-backed.

### D. Evaluation should test reconstruction, not only recall

Anigma-specific memory evaluation should include:

- episode-boundary selection
- temporal slicing correctness
- usefulness of reconstructed local context
- usefulness of semantic augmentation without false certainty

## Required Behaviors

### Freshness And Supersession

Every source should support:

- canonical identity
- version history
- latest-known revision
- stale marking
- explicit supersedes/superseded-by relationships

Without this, the system cannot answer "what is true now" for personal data.

#### Concrete contract (td-7d94ee)

This section is the implementation contract for Contextum source freshness and supersession.

##### 1) Canonical source identity

- `sourceId` is the revision-row identity in `contextum_sources.source_id`.
- `canonicalEntityId` is the durable identity lane for a logical source across replacements.
- `canonicalRef` is the logical source key (file URI/path/thread ref) used to resolve which identity lane a new observation belongs to.
- `artifactHash` is the content-addressed hash for the ingested artifact snapshot.
- `currentHash` is the latest-known content hash carried by the stored revision row.

Identity decision rule:
- if `canonicalRef` + `sourceType` matches an active row, ingestion resolves to that row's `canonicalEntityId`.
- if `currentHash` changed, ingestion writes a replacement row and supersedes the prior active row.
- if `currentHash` is unchanged, ingestion refreshes the active row instead of creating a replacement.
- if no active match exists, ingestion creates a new identity lane.

##### 2) Revision history and timeline

- `revision` is a monotonic integer (`>= 1`) per canonical lane.
- `discoveredAt` is first seen timestamp for lane creation.
- `lastSeenAt` is most recent successful observation timestamp.
- `staleAt` marks when evidence should be treated as stale for default retrieval.

Normalization and guardrails:
- `revision` is normalized to at least `1`.
- `lastSeenAt` is normalized to `>= discoveredAt`.
- `staleAt` is normalized to `>= lastSeenAt` when present.

##### 3) Supersession semantics

- `supersedesSourceId`: this source revision explicitly supersedes another source row.
- `supersededBySourceId`: this source row is no longer current and points to the winning source row.
- `supersessionRootSourceId`: anchor row for this replacement chain.
- `supersessionDepth`: zero-based replacement depth from the root row.

Supersession invariant:
- at most one active row is considered current for a canonical lane in default retrieval (`supersededBySourceId IS NULL`).

##### 4) Conflict handling semantics

- `conflictStatus` is one of:
  - `none`: no known conflict
  - `unresolved`: conflicting evidence exists and has not been reconciled
  - `resolved`: conflict was observed and resolved by reconciliation

Conflict policy:
- unresolved conflicts are represented explicitly instead of silently overwritten.
- retrieval can include or exclude unresolved conflicts via filter knobs.

##### 5) Reingestion policy semantics

- `reingestionPolicy` is one of:
  - `onHashChange` (default): reingest when observed content hash differs from `currentHash`
  - `periodic`: reingest based on scheduler TTL/cadence
  - `manual`: only reingest via explicit operator/user trigger
  - `always`: force reingest every observation

##### 6) Retrieval default behavior

Default Contextum retrieval policy is freshness-first:
- exclude stale sources (`staleAt <= now`)
- exclude superseded sources (`supersededBySourceId != nil`)
- include conflicted sources by default unless caller opts out

`HybridSearchSystem.SearchRequest.filters` knobs:
- `include_stale=true|false`
- `include_superseded=true|false`
- `include_conflicted=true|false`

##### 7) Mapping: contract fields to code surfaces

- Type contract:
  - `Sources/ContextumModule/Components/ContextSourceComponent.swift`
    - `canonicalRef`, `canonicalEntityId`, `currentHash`, `revision`, `discoveredAt`, `lastSeenAt`, `staleAt`
    - `supersedesSourceId`, `supersededBySourceId`, `supersessionRootSourceId`, `supersessionDepth`
    - `conflictStatus`, `reingestionPolicy`
- DB schema + views:
  - `Sources/ContextumModule/Database/ContextumDatabase+Migration.swift`
    - `contextum_sources` canonical entity + supersession lineage columns and `context_sources` / `context_source_graph` projections
- Source persistence:
  - `Sources/ContextumModule/Database/ContextumDatabase+Sources.swift`
    - `upsertResolvedSource` lane resolution (`canonicalRef` + `sourceType`) and supersession edge wiring
    - row decode/encode, source hash/evidence hash materialization
- Ingest propagation:
  - `Sources/ContextumModule/Systems/DocumentTruthIngestLane.swift`
    - carries contract fields and consumes resolved source ID for chunk/source linkage
  - `Sources/ContextumModule/Systems/IngestNormalizeSystem.swift`
    - persists resolved source rows before chunk insert so ingestion chunks inherit canonical identity
- Retrieval filters:
  - `Sources/ContextumModule/Database/ContextumDatabase.swift`
    - `SourceSelectionPolicy`, freshness/supersession/conflict predicates in retrieval SQL
  - `Sources/ContextumModule/Systems/HybridSearchSystem.swift`
    - request filter parsing and propagation to DB search/content fetch.

### Conflict Detection

The system must represent conflicting evidence rather than flattening it too early.

Examples:

- two addresses for the same person
- an outdated policy versus the current revision
- a preference that changed over time

Profile updates should require conflict-aware consolidation, not blind overwrite.

### Abstention

If the system cannot find current evidence, it should say so.

*LongMemEval* treats abstention as a core memory capability. This matters for a personal context system because stale confidence is worse than partial recall.

### Retrieval Packaging

The reader should rarely get isolated top-k chunks only.

It should receive:

- nucleus chunks
- local neighbors
- source metadata
- timestamps
- revision context
- confidence and freshness signals

This aligns with the "contextualized retrieval" result in *MemMachine*.

### Reflection And Consolidation

The system should periodically distill episodic evidence into:

- candidate profile facts
- source graph links
- project summaries
- change events

But these reflections must remain linked back to the underlying evidence. They are derived memory, not replacement memory.

## What This Means For Anigma

## Strengths Already Present

- source identity, canonical refs, current hashes, revisions, and timestamps in [ContextSourceComponent.swift](/Users/user/Developer/GitHub/Anigma_clean/anigma/Sources/ContextumModule/Components/ContextSourceComponent.swift)
- document replay and lineage in [DocumentTruthIngestLane.swift](/Users/user/Developer/GitHub/Anigma_clean/anigma/Sources/ContextumModule/Systems/DocumentTruthIngestLane.swift)
- chunk provenance and replay context in [ContextumDatabase.swift](/Users/user/Developer/GitHub/Anigma_clean/anigma/Sources/ContextumModule/Database/ContextumDatabase.swift)
- idempotency scaffolding in [IdempotencyGuard.swift](/Users/user/Developer/GitHub/Anigma_clean/anigma/Sources/ContextumModule/Systems/IdempotencyGuard.swift)
- artifact/provenance mindset across Contextum and ArtifactStore

## Major Gaps

### 1. The user-facing ingestion path is not fully real yet

The app still triggers simulated `source_ingest` behavior in:

- [SourceConnectionWizard.swift](/Users/user/Developer/GitHub/Anigma_clean/anigma/Sources/AnigmaAppMac/Surfaces/SourceConnectionWizard.swift)
- [JobManager.swift](/Users/user/Developer/GitHub/Anigma_clean/anigma/Sources/AnigmaAppMac/Managers/JobManager.swift)

That means the personal-context contract is ahead of actual execution.

### 2. Profile memory is under-specified

There is strong support for sources and chunks, but not yet a clearly governed layer for:

- durable user preferences
- evolving beliefs or facts
- trusted-source weighting
- project-level summaries with evidence back-links

### 3. Freshness policy is not yet the center of the design

The fields exist, but the repo does not yet show a mature end-to-end reconciliation policy for:

- re-crawl
- stale detection
- supersession
- conflict handling
- deletion and retention semantics for derived memories

### 4. Retrieval ranking is still more corpus-centric than personal-memory-centric

Current retrieval looks primarily lexical, semantic, and spatial. It does not yet obviously optimize for:

- recency
- source trust
- repeated usefulness
- personal salience
- stable entity or project affinity

### 5. Evaluation is missing the right target

If the goal is a personal context database, evaluation should include:

- knowledge updates
- temporal reasoning
- stale-memory abstention
- profile consistency
- retrieval usefulness for real user tasks

`LongMemEval` is a useful anchor, but it should not be the only metric.

## Proposed Anigma Model

Anigma should model personal context as four coupled loops:

### Loop 1: Observe

- ingest source artifacts
- normalize
- chunk
- embed
- attach provenance
- update source freshness metadata

### Loop 2: Reconcile

- match canonical identities
- detect new revisions
- mark superseded or stale records
- detect conflicts
- queue re-embedding or profile refresh only where needed

### Loop 3: Recall

- route query to the right memory layer
- retrieve nucleus evidence plus local context
- filter by freshness and trust
- package evidence for the reader
- abstain when evidence is missing or stale

### Loop 4: Reflect

- promote repeated evidence into profile memory
- update project and person summaries
- learn source usefulness and retrieval priors
- keep every derived assertion linked to its underlying evidence

## Design Rules

1. Source truth outranks summaries.
2. Episodic memory outranks profile memory when they conflict.
3. Freshness outranks similarity when the question is time-sensitive.
4. Retrieval should prefer evidence packets, not isolated chunks.
5. Every durable profile fact should be traceable to supporting evidence.
6. The system should be able to answer "what changed?" as well as "what do you know?"
7. The system should be able to abstain when it cannot prove currentness.

## Immediate Product Implications

The next meaningful steps are:

- replace simulated `source_ingest` with real Contextum execution
- operationalize this source freshness and supersession contract in ingestion connectors and reconciliation workers
- add an explicit profile-memory layer on top of source and episodic memory
- make retrieval ranking time-aware and source-aware
- build evaluations around update handling, temporal reasoning, and abstention

## Bottom Line

The current repo is already stronger on provenance than most memory systems described in the literature. That is an advantage.

What it still lacks is the full behavioral model of a personal context database as an evolving memory system:

- source truth
- episodic retention
- profile consolidation
- freshness and conflict handling
- abstaining safely under uncertainty

That is the right design target for Contextum and ingestion moving forward.
