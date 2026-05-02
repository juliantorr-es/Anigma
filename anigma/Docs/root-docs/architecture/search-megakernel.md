# Search Megakernel: Saturated Architecture

## Status: 🔄 RENOVATION IN PROGRESS
Transitioning from **Fused Modular** to **Saturated Autonomous** execution.

## Overview
The **Search Megakernel** is a hardware-saturated Metal compute shader that executes the entire semantic search pipeline—from vector similarity to Top-K ranking—within a single **Pre-Signed Mission**. It eliminates the **Coordination Wall** and the **Top-K Bubble** by moving all ranking logic out of the CPU and into the GPU.

---

## 1. The Saturated Search Mission

To eliminate the **Governance Wall**, the Search Megakernel operates as a **Pre-Signed Mission**:
1.  **Mission Descriptor**: Tier 1 signs a descriptor defining the `AtlasID`, `AtlasRange` (Search Space), `QueryVector`, and `TopK` limit.
2.  **Autonomous Dispatch**: The CPU (Tier 2) dispatches the mission and goes to sleep.
3.  **In-Kernel Enforcement**: The Megakernel checks the `KillBit` at the start of every search tile.

---

## 2. Fused Pipeline: SIMD-to-Heartbeat

The Megakernel fuses the following stages into a single hardware loop:

### A. SIMD Similarity (The Hot Lane)
Threads within a SIMD-group (32 threads) compute dot products using `simd_shuffle` and `simd_sum`.
- **Optimization**: 100% memory coalescing via **Binary Atlas (SoA)** access.

### B. Threadgroup Parallel Selection (The Top-K Filter)
Instead of a global sort, we use a **Threadgroup-Local Max-Heap** in SRAM.
1. Each threadgroup (512-1024 threads) computes a local Top-K.
2. Selection happens in **Threadgroup Shared Memory**, which is 10x faster than Unified RAM.

### C. In-Kernel Evidence (The Saturated Spine)
- **Heartbeat Generation**: The Megakernel computes a rolling **SIMD-Blake3** hash of the search results as they are written.
- **Persistence**: The hash is written directly to the **Saturated Logging Ring** in Unified Memory.

---

## 3. The DSL Memory Bridge Integration

To eliminate the **Serialization Wall**, the Search Megakernel consumes data directly from the **Binary Atlas (.atlas)**.
- **Zero-Copy**: The `DSLMemoryBridge` maps the `.atlas` file into the GPU's address space.
- **Alignment**: Vectors are 128-byte aligned for peak SIMD throughput.

---

## 4. Performance Metrics (Saturated)

| Metric | Modular (Current) | Saturated Megakernel | Gain |
| :--- | :--- | :--- | :--- |
| **CPU Coordination** | ~300μs (Wait/Sort) | **<10μs (Async)** | **30x** |
| **Search Throughput** | ~2,000 docs/ms | **~10,000+ docs/ms** | **5x** |
| **Evidence Tax** | ~2ms (CPU Hash) | **<50μs (In-Kernel)** | **40x** |
| **Memory Bandwidth** | ~30% (AoS) | **~100% (SoA Atlas)** | **3.3x** |

---

## 5. Implementation Roadmap (Phase 1)
1. **Kernel Draft**: Create `SearchMegakernel.metal` with fused similarity, threadgroup reduction, and **SIMD-Blake3 heartbeats**.
2. **Atlas Driver**: Implement the **Binary Atlas** loader to feed the Megakernel from `.atlas` files.
3. **Mission Handshake**: Update the `PlatformRuntime` to sign the **Search Mission Descriptor**.
4. **Validation**: Verify the **In-Kernel Evidence** matches the CPU-calculated Merkle root.
