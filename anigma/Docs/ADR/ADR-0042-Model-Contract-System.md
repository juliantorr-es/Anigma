> **⚠️ SATURATED REVIEW PENDING**  
> This ADR is pending review for compatibility with the **Saturated Autonomous** architecture. Use with caution.

# ADR-0042: Model Contract System - Support Tasks, Not Repos

**Status**: Accepted  
**Date**: 2026-01-07  
**Deciders**: Architecture, Governance, Product

## Context

Anigma must support local ML execution with court-safe provenance, deterministic receipts, and strict governance—without becoming a "model babysitting service" that promises compatibility with 2.4M+ Hugging Face repos across incompatible formats, custom pipelines, and "works on my machine" checkpoints.

The product differentiator is **governed, local-first ML with evidence integrity**, not "we run everything."

## Decision

**Anigma supports tasks, not random model repos.**

### Core Principle

Models are **data** plugged into **task contracts**. We define a small, stable set of task types with strict ModelSpec/RunSpec contracts, implement backends that provide deterministic receipts, and tier support to avoid absorbing ecosystem chaos.

### Hard Constraints

1. **MLX-first** - Apple Silicon is the first-class path
2. **Local-first** - No Python/Node runtime duct tape in repo
3. **License allowlist** - Enforced at import time, not runtime
4. **Full provenance** - Model hash + input hash + output hash + policy decision + signed receipts
5. **No "trust me bro"** - Every run records model identity and backend version

### Supported Task Contracts (v1)

Matching existing MLWorker UI surface:

- **inference** - Text generation (LLM chat)
- **embedding** - Vector encoding
- **transcription** - Speech-to-text (ASR)
- **classification** - Text/image classification
- **imageGeneration** - Diffusion/generation
- **speechSynthesis** - TTS

Each task has a canonical `ModelSpec` + `RunSpec` schema with deterministic serialization for signing.

### Supported Backends (v1)

- **MLX** (first-class) - Apple Silicon optimized, our strategy narrative
- **GGUF** (compatibility lane) - Wide LLM coverage via llama.cpp
- **CoreML** (constrained) - Small models when format fits

Backends that can't provide deterministic receipts stay in `experimental` tier.

### Trust Tiers

Models are classified at import, not execution:

- **first_class** - Curated list, tested, shipped with guarantees
- **compatible** - BYOW, runs after hash/license verification, no UX polish promises
- **experimental** - Indexed but not production-runnable, dev mode only
- **quarantined** - Stored, hashed, execution blocked

### HuggingFace Support Strategy

HF is a **source adapter**, not a compatibility layer. We implement:

1. **Fetch** - Download snapshots + LFS blobs → Anigma artifact store, record hashes
2. **Verify** - SHA256 all files, pin revision, mark non-reproducible if mutable
3. **Describe** - Parse metadata, infer task, classify format compatibility

**We do not promise to run every HF model.** We promise to ingest and classify safely.

### Conversion Pipelines

Conversions only for formats that fit constraints:

- Every conversion emits artifact + **conversion receipt** with input hashes, tool id/version, output hashes, quantization params
- HF→MLX for supported model families
- HF→GGUF where applicable
- Diffusion/custom pipelines stay behind "supported families only" until we have deterministic conversions

### Governance Integration

- License gate runs at **import time**, not after-the-fact
- Policy engine gates execution based on data classification
- All decisions logged with model provenance
- Uncertain licenses → quarantine tier

## Consequences

### Positive

- **Scalable product surface** - Expand by adding backends, not model-by-model hacks
- **Court-safe evidence** - "This output came from these bytes" with full hash chain
- **No support queue explosion** - Unsupported formats fail early with clear reasons
- **Governance enforced** - License/policy decisions are durable and auditable

### Negative

- **Not "everything works"** - Users may hit unsupported models
- **Upfront conversion cost** - Some models require pipeline runs before execution
- **Tier discipline required** - Must resist pressure to promote experimental models

### Mitigations

- Clear UX that shows compatibility status and reasons for blocks
- First-class model catalog ships with tested, pinned weights
- Conversion jobs run as governed capabilities with progress UI

## Implementation Phases

**Phase 0**: Lock contract surface (ModelSpec/RunSpec schemas) ✅  
**Phase 1**: Model Registry persistence + AppStore integration  
**Phase 2**: HuggingFace Source Adapter (fetch/verify/describe)  
**Phase 3**: Conversion pipelines (MLX, GGUF)  
**Phase 4**: Governance + license gates  
**Phase 5**: Models UI (registry browser, import flow, status)  
**Phase 6**: Determinism harness (golden prompts, drift detection)  
**Phase 7**: Backend expansion scaffolding  

## References

- Existing: `ModelContract.swift`, `ModelRegistry.swift` (ContractsCore)
- Existing: `MLWorkerContracts.swift` (task + engine types)
- Existing: MLWorker UI integration (status, tasks, monitoring)
- Related: Evidence checklist, court-safe ML integration docs
- Related: Constitution (license allowlists, deployment constraints)
