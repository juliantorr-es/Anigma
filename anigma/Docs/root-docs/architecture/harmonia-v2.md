# Harmonia V3: Saturated Tool Execution

## Status: 🔄 RENOVATION IN PROGRESS
Transitioning from **Modular Actor-Bound Dispatch** to **Autonomous Saturated Missions**.

## Overview
Harmonia V3 represents the shift from a "Coordinated Assistant" to a "Saturated Agent." In V3, tool execution and inference are decoupled from the Swift Actor coordination space and moved into autonomous **Hardware Saturation Lanes (DSLs)**.

---

## 1. Architectural Pivot: The Six Walls

Harmonia V3 explicitly identifies and eliminates the architectural walls that hinder agentic performance:

| Wall | Bottleneck | V3 Elimination Strategy |
| :--- | :--- | :--- |
| **Coordination Tax** | Swift-to-Metal latency | **Fused Tool Megakernels** |
| **Governance Wall** | Policy-check latency | **Pre-Signed Mission Descriptors** |
| **Evidence Wall** | CPU hashing tax | **In-Kernel SIMD-Blake3 Heartbeats** |
| **Scheduling Wall** | Actor dispatch jitter | **Shared-Memory Job Queues** |
| **Serialization Wall** | DTO encoding/decoding | **GPU-Native (SoA) Contract Layer** |

---

## 2. The Saturated Dispatch Model

### Legacy (V2): Coordinated Dispatch
1. **HarmoniaActor**: Identifies tool requirement.
2. **GovernanceController**: Evaluates policy (Wait).
3. **ExecutionAuthority**: Dispatches job (Wait).
4. **ToolCapsule**: Executes and returns result (Wait).
5. **EvidenceAuthority**: Records receipt (Wait).

### Target (V3): Saturated Mission
1. **HarmoniaMissionBuilder**: Constructs a **Pre-Signed Mission Descriptor** (includes Tool weights + Signed Policy).
2. **SaturationLane**: Dispatches mission to GPU/ANE.
3. **Autonomous Execution**:
    - GPU runs inference megakernel.
    - GPU executes tool logic within the same memory-mapped atlas.
    - GPU writes SIMD-Blake3 heartbeats directly to EvidenceAuthority buffer.
4. **Async Handoff**: Swift consumes the result and evidence heartbeats *after* the mission completes.

---

## 3. Speculative Coding: DFlash & DDTree

Harmonia V3 integrates the Luce-inspired **DFlash** strategy for real-time coding assistance:
- **Speculative Drafting**: A small (0.8B) model proposes code blocks.
- **Tree Verification (DDTree)**: The Megakernel verifies the tree of proposals in a single parallel pass.
- **Result**: 3.5x - 5x faster code generation compared to standard V2 sequential decoding.

---

## 4. Module Split (Contracts vs. Runtime)

To maintain build stability while implementing these high-performance changes, the module is split:

### HarmoniaV3Contracts
- **DTOs**: SoA-aligned data transfer objects.
- **Protocols**: Define the **Mission Contract** instead of individual function calls.
- **Zero-Copy Types**: Types that map directly to GPU memory layouts.

### HarmoniaV3Surface
- **Mission Controller**: Manages the life cycle of Saturated Missions.
- **DSL Bridge**: Orchestrates weight mapping and buffer allocation.
- **Governance Hook**: Interfaces with Tier 1 for pre-signing mission descriptors.

---

## 5. Renovation Roadmap
- **Step 1**: Finalize the **SoA-aligned DTOs** in `HarmoniaV3Contracts`.
- **Step 2**: Implement the **Pre-Signed Mission** handshake in Tier 1.
- **Step 3**: Port the **Search/Retrieval Megakernel** to the Harmonia Saturation Lane.
- **Step 4**: Integrate **DDTree Speculative Decoding**.
