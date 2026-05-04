# Heterogeneous Saturated Architecture Doctrine

**Status**: Active  
**Applies to**: All Anigma runtime targets, executors, and capability modules.

## 1. Core Principles
"Heterogeneous saturated architecture" dictates that Anigma maximizes the use of available compute and memory substrates (CPU, GPU, ANE, Sidecars) while maintaining strict governance, portable contracts, and zero-copy/copy-minimized dataflows.

## 2. ECS-Inspired Data-Oriented Runtime
Anigma employs an **ECS-inspired data-oriented runtime**.
- **Terminology**: Use "ECS-inspired" or "data-oriented". Do not claim a "Full ECS" as Anigma's core loop prioritizes governance and evidence over pure game-engine loop semantics.
- **Components**: Components are **portable data records**. They must be pure data structures and must **not** contain native hardware handles (e.g., `MTLBuffer`, CUDA pointers).
- **Executors**: Logic resides in Governed Executors (analogous to ECS Systems), which produce execution receipts.

## 3. Zero-Copy vs. Copy-Minimized
- **Copy-Minimized Default**: Prefer the term "copy-minimized" to describe efficient dataflow designs.
- **Zero-Copy Evidence**: **Do not claim "zero-copy" without proof.** A zero-copy claim requires an explicit materialization gate trace or an executor receipt proving that data crossed a boundary (e.g., via `makeBuffer(bytesNoCopy:)` or IPC shared memory) without allocating a new buffer.
- **Hardware-Resident**: Use this term when data is explicitly kept in accelerator-only memory (e.g., `MTLStorageMode.private` or dedicated VRAM).

## 4. Package Graph and Native Containment
- **Portable Contracts**: Modules defining data shapes, interfaces, and schemas must have **zero** dependencies on native execution frameworks (Metal, ROCm, CUDA, PDFium).
- **Native Executors**: Hardware-specific APIs and linker flags must be strictly confined to isolated executor targets or out-of-process sidecars.
- **Sidecar Isolation**: Sidecar-owned buffers and out-of-process execution require explicit sidecar readiness checks and IPC evidence receipts.

## 5. Governed Fallbacks
Every heterogeneous lane (e.g., an MPSGraph inference executor) must define an explicit, governed fallback path (e.g., a CPU-based implementation). When acceleration is unavailable, the fallback executes and emits a receipt documenting the degraded state.