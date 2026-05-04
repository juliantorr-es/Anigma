# Anigma Doctrine Gap Analysis

## Anigma vs. ECS Concept Mapping
| Anigma Concept | Unity ECS Equivalent | Note |
|---|---|---|
| **Identity/Key** | Entity | Anigma uses UUIDs/keys, not just dense integers, to support distributed governance. |
| **Portable Data Record** | Component | Pure data, no behavior, no native handles. |
| **Governed Executor** | System | Anigma executors produce receipts and respect materialization gates. |
| **Schema/Layout** | Archetype | The specific combination of data fields. |
| **Binary Atlas / Page** | Chunk | Cache-aligned contiguous memory block for SoA iteration. |

*Note: Anigma concepts like "Receipts", "Authorities", and "Governance Gates" do not have direct ECS equivalents because they serve security and auditability, not just performance.*

## Required Terminology Definitions

1. **Data-Oriented Architecture**:
   - *Source*: Unity DOTS.
   - *Anigma Interpretation*: Designing data structures for memory locality and cache efficiency rather than object-oriented encapsulation.
   - *Allowed Claim*: "Data-oriented payload."

2. **ECS-Inspired**:
   - *Source*: Unity Entities.
   - *Anigma Interpretation*: Separating data (components) from logic (executors) and using contiguous arrays, but without adopting a full game-engine entity lifecycle.
   - *Allowed Claim*: "ECS-inspired data-oriented runtime."
   - *Forbidden*: "Full ECS" (unless strictly implemented).

3. **Zero-Copy**:
   - *Source*: Metal `bytesNoCopy`.
   - *Anigma Interpretation*: Data is accessed across a boundary without materializing a new allocation.
   - *Allowed Claim*: "Zero-copy proven" (requires runtime instrumentation/receipt).
   - *Forbidden*: Casual use of "zero-copy" without evidence.

4. **Copy-Minimized**:
   - *Anigma Interpretation*: Architecture reduces unnecessary copies but does not strictly guarantee zero-copy at the hardware level.
   - *Allowed Claim*: "Copy-minimized dataflow" (safer default).

5. **Hardware-Resident**:
   - *Source*: Metal `MTLStorageMode.private`.
   - *Anigma Interpretation*: Data remains exclusively in accelerator memory (e.g., VRAM).

6. **Portable Component Contract**:
   - *Anigma Interpretation*: Module that defines data shapes but has no dependencies on native executors (e.g., Metal, CUDA).

## Decision Matrix

| Claim | Official Support | Source | Anigma Interpretation | Required Evidence | Doctrine Language |
|---|---|---|---|---|---|
| ECS stores same-archetype component data together in chunks | Yes | Unity Docs | Anigma uses Binary Atlas for hot data to mimic this. | Profiling memory access | "ECS-inspired chunked storage" |
| Chunk storage improves locality / enables data-oriented processing | Yes | Unity Docs | Primary reason for transitioning from row-based DB blobs. | Cache miss profiling | "Data-oriented locality" |
| Unity chunks are 16 KiB archetype blocks | Yes | Unity Docs | Anigma chunks may differ in size but follow the principle. | N/A | N/A |
| Apple Metal can wrap existing memory with bytesNoCopy | Yes | Apple Metal Docs | True zero-copy pathway for Apple Silicon. | `bytesNoCopy` usage receipt | "Zero-copy Metal boundary" |
| Metal shared storage is not the same as proven end-to-end zero-copy | Yes | Apple Metal Docs | Shared storage just means accessible; copies can still occur. | Materialization gate trace | "Shared memory access" |
| Zero-copy requires proof | N/A | Anigma Doctrine | Prevents overclaiming performance. | Instrumentation receipt | "Do not claim zero-copy without proof." |
| Copy-minimized is safer default language | N/A | Anigma Doctrine | Accurate representation of standard optimized paths. | Code review / design | "Prefer copy-minimized unless proven." |
| Anigma component contracts must be portable | N/A | Anigma Doctrine | Prevents vendor lock-in. | `validate_tiers.py` graph check | "Contracts must not expose native handles." |
| Native executor buffers must not leak into contract types | N/A | Anigma Doctrine | Maintains separation of concerns. | Architecture graph tests | "Native linker settings owned by specific targets." |
| Sidecar IPC payloads require receipts | N/A | Anigma Doctrine | Ensures governance over out-of-process work. | IPC Receipt Schema | "Sidecar-owned buffers require IPC receipts." |
| Package graph boundaries enforce native containment | Yes | SwiftPM Docs | Structural enforcement of portable contracts. | `swift package show-dependencies` | "Strict target containment for native executors." |