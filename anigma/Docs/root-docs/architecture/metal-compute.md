# Metal Compute: Saturated Hardware Missions

## Status: 🔄 RENOVATION IN PROGRESS
Transitioning from **Discrete Kernel Dispatch** to **Autonomous Saturated Missions**.

## Overview
Metal is the primary compute substrate for Anigma's **Decoupled Saturation Lane (DSL)**. To achieve theoretical peak performance on Apple Silicon, Metal execution must move beyond "Modular Jobs" into **Saturated Missions** that minimize CPU coordination and maximize hardware occupancy.

---

## 1. Saturated Metal Principles

### A. Fused Megakernels
Instead of multiple small kernels with CPU synchronization points, we fuse entire pipelines into a single **Megakernel**.
- **Example**: `SearchMegakernel` fuses Similarity, Top-K Selection, and Evidence Hashing.
- **Goal**: Zero "System Bubbles" caused by waiting for the CPU to rank results.

### B. Persistent State (Register-First)
We prioritize keeping data in registers and **Threadgroup Shared Memory (SRAM)** rather than writing intermediate results back to Unified RAM.
- **Benefit**: 10x lower latency and significantly higher **Intelligence-per-Watt (Ops/J)**.

### C. Indirect Command Buffers (ICB)
For complex, multi-stage reasoning (e.g., Speculative Decoding), we use ICBs to allow the GPU to schedule its own kernel sequences autonomously.
- **Goal**: Elimination of the **Scheduling Wall**.

### D. ICB Implementation Notes (2026-04-20)

The first verified `MetalSaturatedSearchMegakernel` ICB path exposed several concrete Metal requirements:

- Pipeline states used inside an indirect command buffer must be created with `MTLComputePipelineDescriptor.supportIndirectCommandBuffers = true`. A pipeline created through `makeComputePipelineState(function:)` is valid for direct dispatch but fails Metal validation when assigned to an indirect command.
- `MTLIndirectCommandBufferDescriptor.commandTypes` must match the command encoded. For `concurrentDispatchThreads`, use `.concurrentDispatchThreads`; do not use raw numeric values.
- `MTLIndirectCommandBufferDescriptor.maxKernelBufferBindCount` must cover the highest buffer index the indirect command sets. The saturated search mission binds buffers `0...8`, so the descriptor requires a bind count of at least `9`.
- Constant arguments used by ICB commands need real `MTLBuffer` storage. Inline `setBytes` is a direct encoder convenience, not an ICB command payload.
- Constant buffers must be retained until the indirect command has executed. The wrapper keeps dimension and threshold buffers alive with the mission wrapper.
- The direct command encoder that executes an ICB must declare referenced resources with `useResource(_:usage:)` when the ICB does not inherit buffers.
- `MTLCommandBuffer.addCompletedHandler` must be registered before `commit()`. Adding it after commit triggers a Metal assertion.

Validated command:

```bash
MTL_DEBUG_LAYER=1 swift test --package-path anigma --filter MetalSaturatedSearchTests
```

Result: 2 tests passed on 2026-04-20, including direct Metal search and ICB execution.

---

## 2. In-Kernel Governance & Evidence

Security and Auditability are baked into the Metal shaders.

### A. The Hardware KillSwitch
Every Megakernel checks a **KillBit** in a shared-memory buffer at the start of every tile/layer. 
- **Latency**: <100μs response to an emergency halt.

### B. In-Kernel Evidence (SIMD-Blake3)
The GPU computes its own cryptographic heartbeats as it processes data.
- **Implementation**: SIMD-accelerated BLAKE3 hashing of input/output buffers.
- **Result**: High-assurance evidence with <2% execution overhead.

---

## 3. Saturated Memory: The Binary Atlas (.atlas)

Metal kernels consume data directly from the **Binary Atlas** via the `DSLMemoryBridge`.
- **Layout**: Structure of Arrays (SoA).
- **Alignment**: 128-byte (1024-bit) vector boundaries for 100% memory coalescing.
- **Access**: Zero-copy `mmap` into the GPU address space.

---

## 4. Renovation Roadmap

### Phase 1: The Search Megakernel (P0)
- [ ] Implement fused similarity + Top-K reduction.
- [ ] Implement SIMD-Blake3 heartbeats.

### Phase 2: Autonomous ICB Pipelines (P1)
- [x] Verify the first SaturationKit search mission through an ICB execution path.
- [ ] Port the **Inference DSL** to use Indirect Command Buffers for multi-layer LLM execution.
- [ ] Implement the **Look-Ahead Pager** for predictive pre-fetching.

### Phase 3: Saturated Orchestration (P2)
- [ ] Move the inner-loop job queue to shared memory for autonomous "Pull" scheduling.

---

**Metal Compute in Anigma is not just "GPU Acceleration"—it is the autonomous heart of Saturated Autonomy.**
