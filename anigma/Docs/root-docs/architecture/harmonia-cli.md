# Harmonia CLI: Saturated Mission Interface

## Status: 🔄 RENOVATION IN PROGRESS
Pivoting the CLI from **Command Dispatch** to **Mission Submission**.

## Overview
The `harmonia` CLI is the high-performance command-line interface for the Saturated Cognitive Assistant. In the new architecture, the CLI serves as a **Submission Kernel** that prepares **Pre-Signed Missions** for autonomous hardware execution.

---

## 1. From Commands to Missions

Legacy CLI commands (`infer`, `memo-add`) were synchronous and coordinated by the CPU. The Saturated CLI shifts to:
1.  **Preparation**: The CLI kernel builds a **Mission Descriptor** (Input Atlas, Query, Governance Policy).
2.  **Submission**: The descriptor is sent to the `PlatformRuntime` (Tier 2).
3.  **Autonomous Execution**: The hardware executes the mission. The CLI receives **Streaming Hardware Heartbeats** (SIMD-Blake3) to prove progress in real-time.

---

## 2. CLI Mission Scenarios

### A. Saturated Search (`harmonia search`)
- **Action**: Dispatches a **Search Megakernel** mission.
- **Verification**: The CLI displays the cryptographic hash of the results verified against the Institutional Merkle Root.

### B. Saturated Inference (`harmonia infer`)
- **Action**: Dispatches a **Saturated Reasoning** mission.
- **Benefit**: Zero-latency streaming of tokens directly from the GPU unified-memory ring.

### C. Evidence Verification (`harmonia evidence`)
- **Action**: Runs the **Forensics DSL** Megakernel to verify the local Evidence Spine at theoretical peak speed.

---

## 3. The CLI Governance Integration

The CLI is "Saturation-Aware":
- **Gated Missions**: High-stakes commands (e.g., `harmonia patch`) require a signed **Governed Mission Descriptor** from Tier 1.
- **Evidence Proof**: Every CLI output is accompanied by a **Hardware Receipt**, ensuring the user knows the exact provenance of the AI output.

---

## 4. Renovation Status (Harmonia CLI V3)

- [x] **CLI Kernel Isolation**: `HarmoniaV2CLIKernel` target compiles cleanly.
- [ ] **Saturated Command Migration**: Porting `InferCommand` to utilize Pre-Signed Missions.
- [ ] **Heartbeat Streaming**: Implementing the `UnifiedLoggingRing` consumer for real-time progress.
- [ ] **Evidence Integration**: Wiring the SIMD-Blake3 verification engine to the CLI.

---

**The `harmonia` CLI is the cockpit for Saturated Autonomy.**
