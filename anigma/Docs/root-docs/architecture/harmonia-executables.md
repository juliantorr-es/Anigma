# Harmonia Executables: Saturated Mission Kernels

## Status: 🔄 RENOVATION IN PROGRESS
Consolidating Harmonia executables as **Saturated Mission Submission Kernels**.

## Overview
Anigma’s Harmonia subsystem is exposed through multiple executables (CLI, Daemon, MCP). To achieve theoretical peak intelligence, these executables are being consolidated around a single **Saturated Mission Engine** (`HarmoniaV2Surface`).

---

## 1. The Harmonia Executable Boundary

| Executable | Role | Saturated Responsibility |
| :--- | :--- | :--- |
| **`harmonia` CLI** | **Submission Kernel** | Prepares Pre-Signed Missions from the command line. |
| **`anigmad` Daemon** | **Service Kernel** | Manages the Saturated Command Queue and Atlas mounting for long-running jobs. |
| **`anigma-mcp`** | **Bridge Kernel** | Connects external tools (like IDEs) to the Saturated Mission Engine. |

---

## 2. Consolidating the Saturated Core

To eliminate the **Coordination Wall**, all Harmonia executables import the `HarmoniaRuntime` (Tier 2), which provides the **Saturated Execution** facade.

- **`HarmoniaV2Surface`**: The primary API for submitting autonomous hardware missions.
- **`HarmoniaV2Inference`**: The **Inference Megakernel** implementation.
- **`HarmoniaV2Memory`**: The **Search Megakernel** and **Binary Atlas** mapping engine.

---

## 3. The Executable Roadmap (Saturated V3)

### Phase 1: Façade Consolidation (Complete)
- [x] **`HarmoniaRuntime`**: A single-file façade re-exporting `HarmoniaV2Surface`.
- [x] **`HarmoniaV2CLIKernel`**: Isolated target for testable CLI logic.

### Phase 2: Saturated Mission Wiring (In Progress)
- [ ] **`LocalAppClient`**: Wiring the CLI and Daemon to the **Saturated Inference DSL**.
- [ ] **`AtlasAuthority`**: Implementing governed mounting of `.atlas` files in all executables.

### Phase 3: Autonomous Orchestration (P2)
- [ ] **`NexusDSL`**: Enabling cross-executable (Daemon-to-CLI) saturated evidence sync.

---

## 4. Why the Consolidation?

1. **Zero-Bubble IPC**: By sharing the **Saturated Command Queue** and **Unified Memory Ring**, multiple executables can coordinate with <10μs latency.
2. **Unified Governance**: All executables utilize the same **Pre-Signed Mission** handshake from Tier 1.
3. **Hardware Sovereignty**: Any executable can submit a mission, but the hardware (GPU/ANE) remains the ultimate authority for execution and evidence.

---

**Anigma executables are the "Launch Control" for Saturated Autonomy.**
