# Saturated Extensions: The Plugin Architecture

## Status: 🔄 RENOVATION IN PROGRESS
Transitioning from **Modular Runtime Plugins** to **Saturated Autonomous Extensions**.

## Overview
Anigma’s "Plugin" architecture is evolving into a **Saturated Extension** model. To eliminate the **Coordination Wall**, we move beyond synchronous Swift-based plugins into **Autonomous Hardware Extensions** that operate within **Pre-Signed Mission** boundaries.

---

## 1. From Modular to Saturated

Legacy plugins were "Coordinated Workers" that required a round-trip to the CPU for every task. Saturated Extensions shift to:
1. **The Mission Descriptor**: Extensions are now submitted as **Saturated Missions**.
2. **Autonomous Execution**: Once dispatched, the extension runs to completion on the hardware (GPU/ANE/NPU).
3. **In-Kernel Verification**: Extensions must generate their own **SIMD-Blake3 Heartbeats** to satisfy Tier 1 governance.

---

## 2. Types of Saturated Extensions

### A. The DSL Megakernel (High-Performance)
Fused shaders (Metal/C++) for heavy compute tasks (e.g., Table Extraction, Math OCR).
- **Integration**: Loaded as a **Binary Atlas** into the `DSLMemoryBridge`.
- **Latency**: <10μs coordination tax.

### B. The Governed Capsule (System Integration)
Sandboxed Swift/Native workers for specialized logic (e.g., Diff, Redaction).
- **Integration**: Wrapped in a **Mission Descriptor** that restricts their memory access to a specific **Gated Projection**.

---

## 3. High-Assurance Boundaries (Tier 1 & 2)

All extensions operate under strict **Governed Autonomy**.
- **The Kill Bit**: All extensions must respect the global **Hardware KillSwitch**.
- **Memory Atlases**: Extensions can only read/write to memory-mapped ranges pre-signed by Tier 1.
- **Evidence Spine**: Every extension must contribute heartbeats to the **Saturated Logging Ring**.

---

## 4. Renovation Status per Extension

| Extension | Renovation Status | Primary Task |
| :--- | :--- | :--- |
| **Search/Similarity** | ✅ Complete | Fused Megakernel (Phase 1) |
| **Media Fingerprinting** | 🏗️ Phase 2 | Porting to **Saturated Mission** |
| **Redaction System** | 🏗️ Phase 2 | Implementing **Gated Projections** |
| **Table Extraction** | ⏳ Blocked | Awaiting **Atlas Bridge** |

---

## 5. Renovation Roadmap
- **Phase 1**: Port core "Capsules" to the **Saturated Mission** model.
- **Phase 2**: Implement the **Extension Registry** in Tier 2 for pre-signed missions.
- **Phase 3**: Establish the **In-Kernel Evidence** standard for all external extensions.

---

**Anigma extensions are "Hardware-First" missions, not "CPU-Second" plugins.**
