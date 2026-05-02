# Saturated Extensions: The Plugin System Architecture

## Status: 🔄 RENOVATION IN PROGRESS
Transitioning from **Modular Runtime Plugins** to **Saturated Autonomous Extensions**.

## Overview
The Anigma **Plugin System** is the extensibility substrate of the platform. In the new architecture, it is being re-engineered to support **Saturated Autonomy**, where extensions operate as autonomous hardware missions rather than synchronous CPU-coordinated workers.

---

## 1. The Saturated Plugin Pipeline

To eliminate the **Coordination Wall**, the plugin system follows a three-stage pipeline:

1. **Mission Proposal**: An extension (e.g., Table Extraction) proposes a **Saturated Mission**.
2. **Pre-Signed Handshake**: Tier 1 Governance evaluates the proposal and issues a signed **Mission Descriptor**.
3. **Autonomous Dispatch**: Tier 2 Runtime dispatches the mission (Metal/C++/ANE) and monitors its **In-Kernel Heartbeats**.

---

## 2. Extension Architecture (The "Capsule" Evolution)

Extensions in Anigma are no longer just "code." They are **High-Assurance Packages** consisting of:
- **Hot Compute**: Fused Megakernels (Metal Shaders) for hardware saturation.
- **Warm Logic**: Swift/Native coordination for state management.
- **Pre-Signed Boundaries**: Memory-mapped atlas permissions defined in the mission descriptor.

---

## 3. The Static Plugin Boundary

To ensure system stability, Anigma uses a **Static Plugin Boundary** (Proven in `td-0a7afd`).
- **Feature Wiring**: Features (Harmonia, RLM, MCP) are decoupled from the kernel via **DaemonFeatureContracts**.
- **Explicit Composition**: The `PlatformRuntime` (Tier 2) explicitly bootstraps the kernel with the required features at startup.

---

## 4. Renovation Status per Category

| Category | Saturated Standard | Status |
| :--- | :--- | :--- |
| **Compute** | Fused Megakernels | 🏗️ Phase 1 |
| **Ingestion** | Saturated Rings (RDMA-style) | 🏗️ Phase 2 |
| **Retrieval** | Search Megakernel + Binary Atlas | ✅ Complete |
| **Governance** | Pre-Signed Mission Registry | ⏳ Blocked |

---

## 5. Renovation Roadmap
- **Phase 1**: Port all discrete capsules to the **Mission-Evidence** model.
- **Phase 2**: Implement the **Saturated Command Queue** for extension dispatch.
- **Phase 3**: Establish the **In-Kernel Evidence** standard for all external extensions.

---

**The Anigma Plugin System is the engine of Saturated Hardware Extensions.**
