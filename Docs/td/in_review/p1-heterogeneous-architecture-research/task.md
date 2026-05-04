# td-heterogeneous-architecture-research - Research heterogeneous saturated architecture principles against official sources and Context7

> **Status**: In Review  
> **Type**: Task  
> **Priority**: P1  
> **Lane**: architecture-research

## Purpose
Validate, refine, and source-ground Anigma’s heterogeneous saturated architecture doctrine against official sources for Apple Silicon/Metal, NVIDIA CUDA, AMD ROCm, SwiftPM/tooling boundaries, Unity ECS/DOTS, and Context7-assisted documentation retrieval.

## Core question
How should Anigma’s heterogeneous saturated architecture doctrine incorporate ECS/data-oriented principles, especially chunked storage, data locality, component/data separation, zero-copy or copy-minimized execution, governed sidecars, and hardware-resident execution? Which parts of Anigma’s doctrine are directly supported by official hardware/tooling sources, which are Anigma-specific design interpretations, and which need softer language or follow-up research?

## Working definition to test
“Heterogeneous saturated architecture” means Anigma should maximize use of available heterogeneous compute and memory substrates — CPU, GPU, Neural Engine where available, media engines, native accelerators, sidecars, and storage/memory-mapped IO — while preserving:
- portable contract surfaces
- native executor specialization
- zero-copy or copy-minimized dataflow
- explicit evidence receipts
- governed fallback paths
- architecture graph hygiene
- no hidden linker/runtime contamination

## Initial source hierarchy
1. **Primary evidence:**
   - official Apple Developer docs/videos
   - official NVIDIA CUDA docs
   - official AMD ROCm docs
   - official Swift/SwiftPM docs
   - official Unity ECS / DOTS docs
   - local upstream source checkouts where applicable

2. **Corroborating evidence:**
   - Context7 retrieved documentation/context
   - generated documentation summaries
   - third-party explanatory sources only when official docs are insufficient

3. **Anigma-owned output:**
   - doctrine language
   - architecture rules
   - proof artifacts
   - normalized receipts/schemas

**Important rule:** Context7 is a corroborating retrieval layer, not the final authority. Official docs and source are primary.

## Official source anchors to consult

### Unity ECS / DOTS:
- **Unity Entities / DOTS:** Unity describes DOTS/ECS as a data-oriented architecture for performance and control. Use this as the primary official ECS/data-oriented source. ([docs.unity3d.com](https://docs.unity3d.com/Packages/com.unity.entities@1.0/manual/index.html), [unity.com](https://unity.com/dots))
- **Unity ECS Chunk Storage:** EntityManager organizes entities by archetype, and components with the same archetype are stored together in chunks. Use this for Anigma’s chunk/SoA/data-locality research. ([docs.unity3d.com](https://docs.unity3d.com/Packages/com.unity.entities@0.1/manual/ecs_components.html))
- **Unity Archetype Chunks:** Unity’s Entities docs describe chunks as 16 KiB blocks holding entities with the same archetype. Use this to compare with Anigma’s planned chunk/block/cache-aligned storage. ([docs.unity3d.com](https://docs.unity3d.com/Packages/com.unity.entities@1.0/manual/concepts-archetypes.html))

### Apple / Metal / Apple Silicon:
- **Metal zero-copy boundaries:** Apple documents `makeBuffer(bytesNoCopy:length:options:deallocator:)` as creating a Metal buffer that wraps an existing contiguous memory allocation. Use this as an official source for no-copy buffer wrapping, with the caveat that not every use of shared memory proves end-to-end zero-copy. ([developer.apple.com](https://developer.apple.com/documentation/metal/mtldevice/makebuffer(bytesnocopy:length:options:deallocator:)))
- **Metal `MTLBuffer` APIs:** Distinguish copied buffer creation from no-copy buffer wrapping. ([developer.apple.com](https://developer.apple.com/documentation/Metal/MTLBuffer))
- **Metal resource storage modes and Apple GPU memory behavior.** Apple documents `MTLStorageMode.shared` as system memory accessible by both CPU and GPU, and as the default for Apple silicon GPUs. Use this to evaluate Anigma’s zero-copy/copy-minimized claims.
- **Apple Silicon system architecture.** Apple describes Apple silicon Macs as using unified memory architecture for CPU and GPU tasks, with performance benefits through Metal and Accelerate.
- **Metal overview.** Apple describes Metal as a low-overhead graphics/compute API with direct control over GPU work and tight Apple silicon integration.
- **Metal Performance Shaders / MPSGraph.** Apple describes MPSGraph as a compute engine for multidimensional graphs covering linear algebra, ML, computer vision, and image processing.

### NVIDIA CUDA:
- **CUDA Programming Guide.** NVIDIA describes CUDA as a parallel computing platform/programming model for GPU execution and provides official guidance on architecture, programming model, language extensions, and performance.
- **CUDA Unified Memory.** NVIDIA documents multiple paradigms of unified memory programming and managed memory behavior. Use this to compare Apple unified memory with discrete GPU managed/unified memory semantics.

### AMD ROCm:
- **ROCm official docs.** AMD describes ROCm as an open software platform optimized for HPC/AI workloads on AMD GPUs, supporting tools/APIs from low-level kernel work to application frameworks.
- **ROCm programming guide.** AMD describes ROCm as supporting heterogeneous programs running on CPUs and AMD GPUs, with HIP and OpenCL among supported interfaces.

### Swift tooling / graph hygiene:
- **SwiftPM target/product model.** SwiftPM targets are build/module/test-suite units, while products expose libraries/executables assembled from targets. Use this to relate hardware saturation to package graph containment and executor isolation.
- **SwiftPM JSON outputs already used by Anigma:**
  - `swift package describe --type json`
  - `swift package show-dependencies --format json`

### Context7:
Query Context7 for current documentation/context for:
- Unity Entities archetypes chunks components systems
- Unity DOTS data-oriented ECS
- Metal MTLBuffer bytesNoCopy
- Metal storage modes shared private managed
- SwiftPM target product graph boundaries
- Optional: SwiftSyntax if validator strategy is discussed

## Research deliverables

1. **Main research doc:**
   `Docs/research/heterogeneous-saturated-architecture/README.md`
2. **Detailed research docs:**
   - `Docs/research/heterogeneous-saturated-architecture/apple-silicon-metal.md`
   - `Docs/research/heterogeneous-saturated-architecture/cuda-unified-memory.md`
   - `Docs/research/heterogeneous-saturated-architecture/rocm-heterogeneous-compute.md`
   - `Docs/research/heterogeneous-saturated-architecture/ecs-data-oriented-zero-copy.md`
   - `Docs/research/heterogeneous-saturated-architecture/swiftpm-tooling-boundaries.md`
   - `Docs/research/heterogeneous-saturated-architecture/context7-corroboration.md`
   - `Docs/research/heterogeneous-saturated-architecture/anigma-doctrine-gap-analysis.md`
3. **Doctrine update proposal:**
   `Docs/governance/HETEROGENEOUS_SATURATED_ARCHITECTURE_DOCTRINE.md`
4. **Proof artifact:**
   `Docs/proofs/heterogeneous-saturated-architecture-research.md`

## ECS/data-oriented research questions
1. What does official Unity ECS/DOTS documentation say about entities, components, systems, archetypes, and chunks?
2. How does chunked archetype storage improve data locality?
3. How should Anigma define ECS-like data ownership without copying Unity’s game-engine-specific model blindly?
4. Which Anigma concepts map to ECS concepts? (Entity, Component, System, Archetype, Chunk, Query, World, Command buffer, Job/executor)
5. Which Anigma concepts should NOT be called ECS because they are governance/evidence concepts instead?
6. How should Anigma distinguish: contract data, runtime component data, evidence/receipt data, executor-local native buffers, sidecar-owned state?
7. What does “zero-copy ECS” mean?
8. When should Anigma use the weaker term “copy-minimized ECS” instead?
9. How should Anigma prove that data stayed in chunked/SoA/native-buffer form?
10. What receipts should be emitted when ECS data is transformed, moved, copied, compacted, or materialized?
11. How should ECS chunks relate to: mmap regions, Metal buffers, Arrow-like columnar buffers, GPU/native buffers, sidecar IPC payloads?
12. How should Anigma handle component schema evolution?
13. How should Anigma prevent native executor details from leaking into portable component contracts?
14. What graph rules prevent ECS components from depending on native executors?
15. What is the minimum viable Anigma ECS doctrine after research?

## Required terminology definitions
Define each term with official source support, Anigma interpretation, allowed claim language, forbidden overclaim language, and required evidence:
- data-oriented architecture
- ECS
- entity
- component
- system
- archetype
- chunk
- SoA / structure-of-arrays
- data locality
- zero-copy
- copy-minimized
- hardware-resident
- chunk-resident
- native executor
- portable component contract
- materialization gate
- sidecar-owned buffer
- evidence receipt

## Decision matrix
| Claim | Official Support | Source | Anigma Interpretation | Required Evidence | Doctrine Language |
|---|---|---|---|---|---|
| ECS stores same-archetype component data together in chunks | | | | | |
| Chunk storage improves locality / enables data-oriented processing | | | | | |
| Unity chunks are 16 KiB archetype blocks | | | | | |
| Apple Metal can wrap existing memory with bytesNoCopy | | | | | |
| Metal shared storage is not the same as proven end-to-end zero-copy | | | | | |
| zero-copy requires proof | | | | | |
| copy-minimized is safer default language | | | | | |
| Anigma component contracts must be portable | | | | | |
| native executor buffers must not leak into contract types | | | | | |
| sidecar IPC payloads require receipts | | | | | |
| package graph boundaries enforce native containment | | | | | |

## Anigma-specific doctrine questions
1. Should Anigma use ECS terminology directly or say “ECS-inspired data-oriented runtime”?
2. Should Anigma components be pure value records?
3. Should components be Codable/Sendable/PayloadReference-compliant?
4. Should component storage be archetype/chunk-based?
5. Should chunks be aligned to hardware/cache/GPU needs?
6. Should chunks produce receipts when copied/materialized?
7. Should systems be governed executors?
8. Should systems be allowed to call sidecars directly, or only through authorities?
9. Should native buffers be represented by references instead of public handles?
10. What does “zero-copy proven” require?

## Required Anigma doctrine outcomes
The draft doctrine must include rules like:
- Prefer “ECS-inspired data-oriented runtime” unless the design actually implements ECS semantics.
- Components are portable data records; they must not contain native handles.
- Native executor state must be referenced through portable references.
- Chunk ownership and materialization must be receipt-producing.
- Do not claim zero-copy without proof.
- Prefer copy-minimized unless instrumentation proves zero-copy.
- Package graph rules must keep native executors out of contract modules.
- Sidecar-owned buffers require sidecar readiness and IPC receipts.
- Data movement across contract/runtime/native boundaries must be classified:
  - no-copy wrap
  - shared-memory access
  - copy-minimized transform
  - materialized copy
  - sidecar transfer
  - unknown/unverified

## Source discipline
For every substantive claim, record:
- source type: official docs, official source, Context7, third-party
- URL or repo path
- commit hash if source-derived
- file/symbol if source-derived
- confidence level
- whether the claim is:
  - directly supported
  - inferred
  - Anigma-specific doctrine
  - speculative/future research

## Context7 instructions
Query Context7 for:
- Unity Entities archetypes chunks components systems
- Unity DOTS data-oriented ECS
- Metal MTLBuffer bytesNoCopy
- Metal storage modes shared private managed
- SwiftPM target product graph boundaries
- Optional: SwiftSyntax if validator strategy is discussed

In `context7-corroboration.md` record:
- query
- retrieved library/repo/topic
- what it corroborated
- what it did not prove
- whether official docs or source were still primary

Do not commit API keys or generated scripts containing secrets.

## Validation
- No production Swift code changes.
- No Package.swift changes.
- No new dependencies.
- YAML parses if task manifests are updated.
- No root-level review/handoff files.
- Context7 marked corroborating only.
- Official/vendor sources marked primary.
- Anigma interpretation separated from source claims.

## Acceptance criteria
- ECS/data-oriented zero-copy research is added to the heterogeneous architecture TD.
- Official sources are cited for ECS chunks/archetypes and Metal no-copy/shared-memory boundaries.
- Context7 corroboration is documented but not treated as doctrine authority.
- Doctrine proposal distinguishes zero-copy from copy-minimized.
- Doctrine proposal distinguishes ECS-inspired from full ECS.
- Research defines evidence required to prove zero-copy/chunk-resident/hardware-resident claims.
- Research creates follow-up TDs for:
  1. ECS component contract schema prototype
  2. chunk/SoA storage receipt schema
  3. zero-copy materialization gate instrumentation
  4. native executor buffer-reference contract
  5. package graph validator for native executor leakage