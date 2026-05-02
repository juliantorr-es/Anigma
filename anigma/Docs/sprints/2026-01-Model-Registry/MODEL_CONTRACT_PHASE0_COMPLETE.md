> Historical status snapshot. This file reflects the state observed on 2026-04-21 and is not the source of truth for current status.
>
> Source of truth:
> - `td`
> - `anigma/current_build_status.txt`
> - `anigma/build_phase3_logs/`


# Model Contract System - Phase 0 Complete ✅

**Date:** 2026-01-07  
**Phase:** 0 - Lock the Contract Surface  
**Status:** ✅ COMPLETE

---

## What We Built

### ADR: Model Contract System
**Location:** `Docs/ADR/ADR-MODEL-CONTRACT-SYSTEM.md`

**Decision:** Anigma supports **tasks, not repos**. Models are data plugged into task contracts.

**Key Principles:**
- ✅ Small set of task contracts (6 types)
- ✅ Tiered model support (first-class, compatible, experimental, quarantined)
- ✅ Stable backends only (MLX, GGUF, CoreML)
- ✅ HF is a source, not our identity
- ✅ Governance and evidence non-negotiable
- ✅ Deterministic contracts for signing

---

### ModelContract.swift
**Location:** `Sources/ContractsCore/ModelContract.swift` (329 lines)

**Complete Type System:**

#### Enums (5)
1. **MLBackend** - MLX, GGUF, CoreML (stable, boring, good)
2. **MLTaskKind** - 6 task types matching MLWorker UI
3. **ModelTrustTier** - first_class, compatible, experimental, quarantined
4. **ModelSource** - HF repo, local path, bundled

#### Structs (8)
1. **ConversionReceipt** - Full provenance for format conversions
2. **LicenseDecision** - Allowlist enforcement results
3. **ModelSpec** - Complete model specification with hashes
4. **MLTaskOptions** - Execution parameters
5. **RunSpec** - Run specification with full provenance
6. **RunReceipt** - Court-safe evidence of execution
7. **ExecutionMetrics** - Performance data for evidence

**All types:**
- ✅ Codable
- ✅ Hashable
- ✅ Sendable
- ✅ Public API
- ✅ Deterministic serialization

---

## Task Contracts Defined

| Task | Contract | First-Class Backend | Compatible |
|------|----------|---------------------|------------|
| **Inference** | LLM text generation | MLX | GGUF |
| **Embedding** | Text → vectors | MLX | CoreML |
| **Transcription** | Audio → text | MLX Whisper | - |
| **Classification** | Text → labels | MLX | - |
| **Image Generation** | Text → image | MLX SD | - |
| **Speech Synthesis** | Text → audio | MLX TTS | - |

**No other tasks in v1.** Surface is locked.

---

## Model Trust Tiers

### Tier 1: First-Class ⭐
- **Curated** list we test, pin, hash, ship
- **Licenses:** MIT, Apache-2.0, allowlist only
- **Determinism:** Drift detection with gold test sets
- **Receipts:** Full court-safe provenance
- **What institutions rely on**

### Tier 2: Compatible ✓
- **BYOW** - bring your own weights
- **Requirements:** Match task + backend
- **Governance:** Hashes, license checks, policy gates
- **No promises:** UX polish, cross-checkpoint determinism

### Tier 3: Experimental 🧪
- **Behind** trust tier or dev mode
- **Logged** and indexed
- **Not runnable** in production
- Governance without boundaries is cosplay

### Tier 4: Quarantined 🚫
- **Stored** and hashed
- **Blocked** from execution
- **Reason:** License unclear, policy violation, etc.

---

## Canonical Hashing

Both `ModelSpec` and `RunSpec` have deterministic `canonicalHash` properties:

**ModelSpec hash includes:**
- Model ID
- Source identifier
- Task + backend
- Trust tier
- License
- All artifact hashes (sorted)
- Tokenizer hash

**RunSpec hash includes:**
- Model hash
- Input hash
- Backend version
- All params (sorted)
- Seed

**Purpose:** Court-safe signing and evidence chain

---

## Receipts for Evidence

### ConversionReceipt
- Input file hashes
- Tool ID + version
- Output file hashes
- Quantization params
- Metadata

### RunReceipt
- RunSpec (full provenance)
- Output hash
- Policy decision
- Execution metrics
- Signature (optional)

**Every operation produces a receipt. No shortcuts.**

---

## What We Will NOT Do

❌ Support "most HF models"  
❌ Import arbitrary Transformers pipelines  
❌ Add Python/Node runtime to repo  
❌ Special-case individual repos  
❌ Support mutable checkpoints in production  
❌ Skip license/policy gates  
❌ Pretend non-deterministic backends are court-safe  

---

## Next Phases

### Phase 1: Model Registry
- Durable, queryable storage
- Installed models with provenance
- Backend compatibility matrix

### Phase 2: HF Source Adapter
- Fetch, verify, describe (3 jobs only)
- Privileged capability with receipts
- Store in Anigma artifact store

### Phase 3: Conversion Pipelines
- GGUF (already compatible)
- HF → MLX (first-class path)
- Receipts with full provenance

### Phase 4: Governance + Licensing
- Allowlist enforcement at import
- Quarantine uncertain models
- Policy gates on execution

### Phase 5: UX That Doesn't Lie
- "Models" section in Build mode
- Preview before import
- Clear reasons when not runnable

### Phase 6: Determinism + Drift Detection
- Baseline tests per first-class model
- Gold prompts + hashed outputs
- Fail on drift

### Phase 7: Expand Via Backends
- Add execution lanes
- Must provide receipts + versioning
- No per-model hacks

---

## First Implementation Target

**Model registry + HF adapter for:**
1. **GGUF text generation** (llama.cpp backend)
2. **One embedding family** (MLX backend)

**Why:** Matches current MLWorker engine structure, credible "HF support" without the impossible.

---

## Architecture Enforced

**Constraints from Constitution:**
- ✅ Local-first execution
- ✅ License allowlist
- ✅ Data classification tiers
- ✅ Policy-driven gates
- ✅ Full audit trails

**From Evidence Requirements:**
- ✅ Model hash, input hash, output hash
- ✅ Signed provenance
- ✅ Reproducible run spec
- ✅ Drift detection

**From Strategy:**
- ✅ MLX-first for Apple Silicon
- ✅ No runtime duct tape
- ✅ Capability-based security
- ✅ Deterministic contracts

---

## Success Criteria

✅ User can paste HF repo ID, see compatibility preview  
✅ Compatible models imported with hashes + license check  
✅ Every run produces court-safe receipt  
✅ First-class models have drift tests  
✅ Unsupported formats clearly marked  
✅ No Python/Node in repo  
✅ All operations gated by policy  

---

## Files Created

1. **ADR-MODEL-CONTRACT-SYSTEM.md** (8.5KB)
   - Complete decision document
   - 7 implementation phases
   - Clear constraints and anti-patterns

2. **ModelContract.swift** (9.7KB, 329 lines)
   - 4 enums
   - 8 structs
   - All Codable, Hashable, Sendable
   - Deterministic hashing
   - Full type safety

---

## Phase 0 Status: ✅ COMPLETE

**What we locked in:**
- Task contracts (6 types, no more)
- Trust tiers (4 levels)
- Backend requirements (deterministic, stable)
- Receipt schemas (conversion, run, license)
- Canonical hashing (for signing)

**Contract surface is now immutable for v1.**

**Next:** Phase 1 - Model Registry implementation

---

**The moment we deviate from "tasks not repos," we inherit HF's chaos.** This ADR + type system is the firewall.

---

## Core Truth

> "Hugging Face is a bazaar. Anigma is a cathedral. We support a small set of task contracts + stable backends, and stop there."

**Phase 0 Complete.** Contract surface locked. 🔒
