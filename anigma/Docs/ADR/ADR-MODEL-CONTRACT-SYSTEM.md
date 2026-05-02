> **⚠️ SATURATED REVIEW PENDING**  
> This ADR is pending review for compatibility with the **Saturated Autonomous** architecture. Use with caution.

# ADR: Model Contract System - Tasks Not Repos

**Date:** 2026-01-07  
**Status:** Accepted  
**Decision:** Anigma supports **task contracts**, not arbitrary model repositories

---

## Context

Hugging Face hosts 2.4M+ models across every modality and format imaginable. Supporting "most HF models" would turn Anigma into a model babysitting service, violating our core constraints:

- **Local-first MLX** as primary execution path
- **Strict governance** with policy gates
- **Deterministic receipts** for court-safe evidence
- **No Python/Node runtime duct tape** in the repo

The right approach: support a **small set of task contracts + backends**, then treat models as **data plugged into those contracts**.

---

## Decision

### 1. Task Contracts Are The Product Surface

Anigma supports **6 task types** (matching current MLWorker UI):

| Task | Contract | First-Class Backend | Compatible Backends |
|------|----------|---------------------|---------------------|
| **Inference** | LLM text generation | MLX | GGUF (llama.cpp) |
| **Embedding** | Text → vectors | MLX | CoreML (small models) |
| **Transcription** | Audio → text | MLX Whisper | - |
| **Classification** | Text → labels | MLX | - |
| **Image Generation** | Text → image | MLX Stable Diffusion | - |
| **Speech Synthesis** | Text → audio | MLX TTS | - |

**No other tasks in v1.** Each task gets a strict `ModelSpec` and `RunSpec` schema.

---

### 2. Model Support Is Tiered

**Tier 1: First-Class Models**
- Curated list we test, pin, hash, and ship
- Clear licenses (MIT, Apache-2.0, allowlist only)
- Deterministic outputs with drift detection
- Full court-safe receipts
- **This is what institutions rely on**

**Tier 2: Compatible Models**
- "Bring your own weights" matching supported task + backend
- Recorded hashes, license checks, policy gates
- **No UX polish promises**
- **No cross-checkpoint determinism guarantees**

**Tier 3: Experimental**
- Behind trust tier or dev mode
- Logged and indexed but not production-runnable
- **Governance without boundaries is cosplay**

---

### 3. Backends Are Stable and Boring (Good)

**Boring is good.** We implement backends that are:
- Stable across versions
- Deterministic where possible
- Capable of emitting receipts (model hash, input hash, output hash, run params)

**First-Class:** MLX (Apple Silicon, our differentiator)  
**Compatible:** GGUF (llama.cpp for wide LLM coverage)  
**Future:** CoreML (when it fits), stable graph formats

**Not supported:** Arbitrary Transformers repos, custom pipelines, "works on my machine" checkpoints

---

### 4. Hugging Face Is A Source, Not A Standard

HF is where we **fetch models**, not what we **become**.

**HF Source Adapter does 3 jobs:**
1. **Fetch** - Download snapshots + LFS, store in Anigma artifact store, record hashes
2. **Verify** - SHA256 everything, pin revision, mark mutable repos as non-reproducible
3. **Describe** - Parse metadata to infer task compatibility (GGUF → llama, MLX-ready → MLX, etc.)

**What it does NOT do:**
- Promise to run every model
- Import Python preprocessing pipelines
- Absorb tokenizer/precision/safety quirks into our support queue

---

### 5. Governance and Evidence Are Non-Negotiable

Every model operation produces a **receipt**:
- Model identity (repo + revision OR local path)
- Content hashes (weights, tokenizer, config)
- License decision (allowlist pass/fail)
- Policy decision (per data classification)
- Conversion receipt (if applicable)

Every run produces a **receipt**:
- Model hash
- Input hash
- Output hash
- Run spec (params, seed, backend version)
- Policy decision

**Court-safe ML integration requires exactly this.** No shortcuts.

---

### 6. ModelSpec and RunSpec Are Canonical

All contracts defined in `ContractsCore`:

```swift
struct ModelSpec: Codable, Hashable {
    let id: String              // HF repo OR local path
    let revision: String?        // Pinned commit
    let task: MLTaskKind
    let backend: MLBackend       // MLX, GGUF, CoreML
    let license: String
    let artifactHashes: [String: String]  // file → sha256
    let tokenizerHash: String?
    let conversionReceipt: ConversionReceipt?
}

struct RunSpec: Codable, Hashable {
    let modelHash: String
    let inputHash: String
    let params: MLTaskOptions
    let seed: Int?
    let backendVersion: String
}

struct ConversionReceipt: Codable, Hashable {
    let inputHashes: [String: String]
    let toolId: String
    let toolVersion: String
    let outputHashes: [String: String]
    let quantization: String?
}
```

**Deterministic serialization for signing.**

---

## Implementation Phases

### Phase 0: Lock the contract surface ✅
- **This ADR**
- ModelSpec, RunSpec schemas in ContractsCore

### Phase 1: Model Registry
- Durable, queryable registry of installed models
- Tracks: id, source, license, hashes, backend compatibility
- **Not a UI nicety - the object governance points at**

### Phase 2: HF Source Adapter
- Fetch, verify, describe (3 jobs only)
- Store in Anigma artifact store
- Treat "download weights from internet" as **privileged capability** with receipt

### Phase 3: Conversion Pipelines
- GGUF (already compatible)
- HF → MLX (for Apple Silicon first-class path)
- Emit conversion receipts with full provenance
- **Only for formats we can govern and reproduce**

### Phase 4: Governance + Licensing Gates
- License allowlist enforcement at import time
- Quarantine uncertain models (stored, hashed, not runnable)
- Policy gates based on data classification
- **Reuse existing policy-driven governance spine**

### Phase 5: UX That Doesn't Lie
- "Models" section in Build mode
- Show: installed models, source, trust tier, runnable tasks, storage
- HF repo preview: what Anigma believes it is, engines that can run it, conversions required
- **If not runnable, say why**: unsupported format, license blocked, missing files, unpinned revision

### Phase 6: Determinism + Drift Detection
- Baseline tests per first-class model
- Gold set of prompts + expected hashed outputs
- Fail build if output drifts beyond tolerance
- **Stop "works on my laptop" from becoming "breaks in front of user"**

### Phase 7: Expand Via Backends, Not Hacks
- Add new execution lanes (CoreML, etc.)
- Must provide deterministic receipts + stable versioning
- **No per-model special cases**

---

## What To Implement First

**Unblocking win:** Model registry + HF fetch/verify/describe for:
- GGUF text generation (llama.cpp)
- One embedding family (MLX)

This gives credible "HF support" story without promising the impossible, matches current MLWorker engine structure.

**Everything else is expansion.**

---

## What We Will NOT Do

❌ Promise to "support most HF models"  
❌ Import arbitrary Transformers pipelines  
❌ Add Python/Node runtime to the repo  
❌ Special-case individual model repos  
❌ Support mutable checkpoints in production  
❌ Skip license/policy gates "for convenience"  
❌ Pretend non-deterministic backends are court-safe  

---

## Constraints

**From Constitution & Governance:**
- Local-first execution
- License allowlist (MIT, Apache-2.0, explicit approval)
- Data classification tiers
- Policy-driven gates
- Full audit trails

**From Evidence Requirements:**
- Model hash, input hash, output hash
- Signed provenance
- Reproducible run spec
- Drift detection

**From Architecture:**
- MLX-first for Apple Silicon
- No runtime duct tape
- Capability-based security
- Deterministic contracts

---

## Success Criteria

✅ User can paste HF repo id, see compatibility preview  
✅ Compatible models are imported with hashes + license check  
✅ Every run produces court-safe receipt (model, input, output, params)  
✅ First-class models have drift detection tests  
✅ Unsupported formats are clearly marked, not silently broken  
✅ No Python/Node in the Anigma repo  
✅ All model operations gated by policy  

---

## Why This Matters

**The moment we say "we support most HF models," we implicitly promise:**
- Tokenizers, preprocessing, precision quirks = our support queue
- Every model-specific bug = our responsibility
- "It broke" becomes "why is Anigma broken"

**That's how products die, slowly and expensively.**

**Instead:** Stable task contracts + stable backends + clear tiering.  
**Result:** Broad HF reach without absorbing HF chaos into product surface.

---

**Decision:** Support tasks, not repos. HF is a source, not our identity.

**Status:** Accepted  
**Next:** Implement Phase 0 schemas in ContractsCore
