> **⚠️ HISTORICAL RESEARCH RECORD**  
> This document belongs to the legacy 'Coordination-Bound' research phase. It remains for historical context only. All new development follows the **Saturated Autonomous** architecture (See `Docs/architecture/README.md`).


# Architectural Gap: Global Batching and Lane Scheduling

**Gap ID:** global-batching-lanes  
**Severity:** High  
**Scope:** Compute routing and hardware saturation

## Gap statement

The current research describes concurrency well, but not enough for high hardware saturation. Harmonia V3 needs a global batching layer and lane scheduler so the CPU can keep the GPU/ANE busy instead of merely coordinating tasks one at a time.

## Research evidence

### Industry standards
- **Apple Core ML:** models run on CPU, GPU, and Neural Engine; the framework is optimized for on-device performance and lower memory footprint.
- **Apple Metal Performance Shaders:** provides highly optimized data-parallel primitives tuned for GPU family characteristics.
- **Reactive Streams:** bounded, non-blocking backpressure is needed to safely move work across async boundaries.

### Official documentation
- **Core ML docs:** batch providers exist, and the framework explicitly supports CPU/GPU/ANE execution with on-device optimization.
- **Metal Performance Shaders docs:** emphasizes data-parallel kernels and optimized compute paths on Metal GPUs.

### Repo research
- `Hardware_Saturation_Strategies.md` recommends lane scheduling, batching triggers, and backpressure.
- `High_Performance_Inference.md` recommends control-plane/data-plane separation and speculative execution lanes.

## Why it matters

A fast control plane does not guarantee a saturated data plane. Without global batching:

- GPU launch overhead dominates small jobs
- similar work is dispatched separately instead of coalesced
- ANE/GPU resources sit idle between requests

## Recommended architectural response

Create a **Global Batch Orchestrator** that:

- groups compatible work across authorities
- batches by hardware affinity and payload type
- preserves ordering where required
- separates control, inference, perception, and native fallback lanes

Suggested lanes:

| Lane | Target | Examples |
|---|---|---|
| Control | CPU | governance, receipts, routing |
| Inference | GPU | embeddings, generation, attention |
| Perception | ANE | OCR, block detection, lightweight vision |
| Native | C++ SIMD | fallback and deterministic paths |

## Design constraints

- Batching windows must be short enough to preserve responsiveness.
- Lane priority must be explicit.
- Batch coalescing must not violate tenant isolation.

## Acceptance criteria

- Work items can be routed by lane and affinity.
- Similar jobs can be co-batched across workflows.
- Saturation metrics exist for each lane.
- The scheduler can explain why a job was delayed or batched.