# Design: Saturated Logging & In-Kernel Evidence

## Status: 🏗️ RESEARCH DRAFT
Defining the **Saturated Logging Ring** and **SIMD-Blake3** heartbeat protocol.

## Overview
To eliminate the **Evidence Wall**, Anigma shifts from software-added hashing to **In-Kernel Evidence**. This design defines how Saturated Megakernels write non-repudiable heartbeats directly to a unified-memory ring buffer with sub-microsecond latency.

---

## 1. The Saturated Logging Ring (Unified Memory)

The ring buffer is a pre-allocated MTLBuffer in Unified Memory, shared between the DSL (Producer) and Tier 2 (Consumer).

### A. Ring Metadata (32 bytes)
- `ProducerIndex`: 4 bytes (Last written by GPU)
- `ConsumerIndex`: 4 bytes (Last read by CPU)
- `RingSize`: 4 bytes
- `StatusBits`: 4 bytes (Overflow flag, etc.)
- `Padding`: 16 bytes, reserved. Keeps the metadata header fixed at 32 bytes.

Implementation note, 2026-04-20: the Metal path uses 32-bit `atomic_uint` metadata instead of 64-bit atomics. This avoids Metal template and hardware-family compatibility failures seen with 64-bit atomic arithmetic while preserving the 32-byte metadata header. Ring capacity and unread counts use wrapping `UInt32` arithmetic; mission code must size rings so a live producer cannot outrun the 32-bit sequence window.

### B. Heartbeat Packet (64 bytes)
- `MissionID`: 16 bytes (UUID)
- `PacketType`: 4 bytes (Start, Heartbeat, End, Violation)
- `Sequence`: 4 bytes
- `PayloadHash`: 32 bytes (**SIMD-Blake3 Output**)
- `Timestamp`: 8 bytes (Hardware cycle count)

---

## 2. SIMD-Blake3: Zero-Tax Hashing

To minimize the "Hashing Tax," the DSL Megakernel uses a specialized **SIMD-Blake3** implementation.

1.  **State Threadgroup**: A small amount of Threadgroup Shared Memory (SRAM) is used to maintain the rolling Blake3 state.
2.  **Parallel Hashing**: Threads within a SIMD-group process chunks of input/output data in parallel.
3.  **Heartbeat Flush**: Every $N$ iterations (or $K$ tokens), the rolling state is finalized and flushed to the **Saturated Logging Ring** in a single atomic write.
4.  **Overhead**: Target overhead is **<2%** of total kernel execution time.

---

## 3. High-Assurance Evidence Chain (The Spine)

1.  **Chaining**: Each heartbeat packet hash includes the hash of the *previous* heartbeat in its payload.
2.  **Merkle Finalization**: When the mission ends, Tier 2 finalizes the chain into the **Evidence Spine** (Cathedral).
3.  **Tamper Detection**: If a heartbeat sequence is missing or the hash chain is broken, the `EvidenceAuthority` triggers an immediate **Institutional Breach** alert.

---

## 4. Hardware/Software Interaction

1.  **CPU (Tier 2)**: Monitors the `ProducerIndex`. When it advances, the CPU drains the ring in a large batch and writes the hashes to the **Evidence Atlas**.
2.  **GPU (DSL)**: Atomically advances the `ProducerIndex` after writing a heartbeat. If `ProducerIndex` reaches `ConsumerIndex - 1`, the kernel halts (Backpressure) or overwrites (based on mission priority).

### Implementation Findings (2026-04-20)

The first validated GPU producer path added these concrete rules:

- The Swift actor must write initial metadata into the shared `MTLBuffer` before handing it to the GPU. Without the initial `RingSize`, the shader can compute invalid slots or skip heartbeat writes.
- The Swift actor must import GPU-written metadata and packets before draining. The in-memory actor packet array is not updated automatically by Unified Memory writes.
- The GPU metadata and Swift metadata structs must stay ABI-identical: four 32-bit values plus 16 bytes of padding.
- Heartbeat packet decoding is intentionally strict. If a GPU-written packet does not contain a known packet type, drain skips that slot rather than manufacturing evidence.
- Tests for ICB execution must use the same 32-bit metadata layout as production shader code.

Validated commands:

```bash
MTL_DEBUG_LAYER=1 swift test --package-path anigma --filter MetalSaturatedSearchTests
swift test --package-path anigma --filter SaturatedLoggingRingTests
```

Result: Metal search and ICB telemetry passed 2 tests; logging ring behavior passed 5 tests on 2026-04-20.

---

## 5. Why This Protocol?

- **Zero Wait**: The GPU never waits for the CPU to acknowledge a log entry.
- **Cryptographic Speed**: Blake3 is designed for SIMD saturation.
- **Atomicity**: Prevents partial log entries from being ingested.

---

## 6. Next Steps for Implementation
1.  **Metal Port**: Port the Blake3 compression function to Metal Shaders.
2.  **Ring Controller**: Implement the `UnifiedLoggingRing` actor in `TelemetryCore`.
3.  **Testing**: Verify 100k heartbeats/second throughput on M2 hardware.

## 7. BLAKE3 Digest Tree Roadmap

The compression function alone is not a full BLAKE3 digest. Full evidence semantics require chunking, tree reduction, keyed/derive modes, official vectors, Metal digest parity, and migration away from the SHA-256 compatibility shim.

See [BLAKE3 Digest Tree Semantics Roadmap](./blake3-digest-tree-semantics.md). TD source of truth: `td-062215`.
