# Phase 3 Roadmap: The Hardware Saturation Era

## Status: 🔄 RENOVATION IN PROGRESS
Pivoting Phase 3 to establish the **Hardware Saturation Lane** as the primary capability driver.

## Overview
Phase 3 transitions Anigma from a "Stable Prototype" to a **Saturated Cognitive Assistant**. The primary objective is to achieve theoretical peak throughput on Apple Silicon while maintaining radical institutional transparency.

---

## 1. Core Pillar: The Hardware Saturation Lane

Phase 3 is built upon the **Decoupled Saturation Lane (DSL)** architecture.

### Milestone 1: The Search Megakernel Prototype (Phase 3.1)
- **Objective**: Fuse Similarity and Top-K Selection into a single Metal compute shader.
- **Success Criteria**: 5x throughput gain in semantic retrieval; elimination of the Top-K bubble.

### Milestone 2: DSL Memory Bridge & Atlas Mapping (Phase 3.2)
- **Objective**: Implement governed `mmap` views for Binary Atlases (.atlas files).
- **Success Criteria**: Zero-copy flow from Disk to GPU; elimination of the Serialization Wall.

### Milestone 3: Saturated Autonomous Missions (Phase 3.3)
- **Objective**: Implement Metal Indirect Command Buffers (ICBs) and Pre-Signed Mission handshakes.
- **Success Criteria**: GPU executes 64-layer inference with zero CPU interrupts.

---

## 2. Invariants to Maintain

### 1. The "Saturation First" Rule
All new features in Phase 3 must demonstrate a **Coordination Tax Audit**. Any process exceeding 100μs of synchronous CPU-GPU wait time must be redesigned as a DSL mission.

### 2. Pure SoA Storage
The `DatabaseAuthority` in Phase 3 will serve strictly as a metadata provider. All heavy inference data must live in SoA-aligned **Binary Atlases**.

### 3. In-Kernel Evidence (SIMD-Blake3)
No Phase 3 module is considered "High-Assurance" until it generates hardware-native heartbeats.

---

## 3. Implementation Timeline (Renovated)

| Milestone | Target | Focus | Primary Wall |
| :--- | :--- | :--- | :--- |
| **P3.1** | **Search Megakernel** | Retrieval Speed | Coordination Tax |
| **P3.2** | **Atlas Bridge** | Persistence Speed | Serialization Wall |
| **P3.3** | **Pre-Signed Handshake** | Governance Speed | Governance Wall |
| **P3.4** | **In-Kernel Evidence** | Audit Speed | Evidence Wall |
| **P3.5** | **Predictive Paging** | I/O Speed | I/O Wall |

---

## 4. Renovation Impact on Existing Tasks

- **`td-40d410` (Truth Storage)**: Now a prerequisite for Phase 3.2.
- **`td-333894` (Harmonia Migration)**: Aligned with Phase 3.3 autonomous missions.
- **`td-90f13b` (ECS Scheduler)**: Aligned with Milestone 3 for shared-memory queues.

---

## 5. Success Metrics (Phase 3 End-State)

✅ **Performance**: >45 tokens/sec for local LLM inference.
✅ **Efficiency**: >1.87 tok/J on consumer hardware (Lucebox standard).
✅ **Governance**: Zero-latency policy enforcement via Pre-Signed Missions.
✅ **Transparency**: 100% auditable evidence spine via in-kernel heartbeats.
