# Governed Workflow: Saturated Autonomy

## Status: 🔄 RENOVATION IN PROGRESS
Integrating **Pre-Signed Missions** and **In-Kernel Evidence** into the Governed Workflow.

## Overview
Anigma implements a governed patch system based on **receipt-based validation** and **phase contracts**. To support the **Hardware Saturation Strategy**, the workflow is evolving from real-time CPU-bound coordination to **Saturated Autonomy**, where governance is pre-evaluated and evidence is generated directly by the hardware.

---

## 1. Core Principles of Saturated Governance

1. **Pre-Signed Missions** - Governance evaluation happens *before* a mission starts. Tier 1 issues a signed **Mission Descriptor** that the DSL executes autonomously.
2. **In-Kernel Evidence** - Hardware-saturated missions generate their own evidence heartbeats (SIMD-Blake3) to eliminate the "Evidence Wall" (CPU hashing tax).
3. **Receipt Chain Integrity** - All missions link to the previous mission's receipt, maintaining a tamper-evident spine across the hardware/software boundary.
4. **Governed Memory Atlas** - Memory access is governed via **Pre-Signed Ranges**, ensuring DSLs can only read/write to authorized binary atlases.

---

## 2. The Saturated Patch Workflow

### Step 1: Mission Proposal
When an agent (like Gemini) proposes a change, it must now define the **DSL Saturation Impact**:
- **Wall Elimination**: Identify which of the six walls the patch targets.
- **Data Layout**: Ensure new components follow the **SoA (Structure-of-Arrays)** standard.

### Step 2: Pre-Launch Validation
`validate_patch` now includes **Saturation Gating**:
- **Check**: Does this patch introduce synchronous waits in a DSL? (Forbidden)
- **Check**: Does this patch violate Data-Oriented Design rules? (Warning)
- **Check**: Is the **Mission Descriptor** format compliant with Tier 1 signing?

---

## 3. High-Performance Build & Validation

**Always use the Saturated harmonia wrapper:**

```bash
# Build with Saturation Lane optimizations
Scripts/harmonia.sh saturated-build

# Run evidence validation (verifies SIMD-Blake3 heartbeats)
Scripts/harmonia.sh evidence-check
```

---

## 4. Phase Contracts: Saturation Requirements

Every phase contract must now include a **Hardware Saturation Section**:
- **Authority Boundary**: Define the **Memory Atlas ranges** the DSL mission is allowed to map.
- **Saturation Target**: Define the target hardware (GPU, ANE, or Multi-Lane).
- **Efficiency Target**: Define the **Intelligence-per-Watt (Ops/Joule)** baseline for the phase.

---

## 5. Renovation Roadmap
- **Phase 1**: Update `governance.md` to support **Mission Descriptor Signing**.
- **Phase 2**: Port the **EvidenceAuthority** to support in-kernel heartbeat ingestion.
- **Phase 3**: Implement **Pre-Signed Memory Maps** in the DSLMemoryBridge.

---

**This workflow ensures every change is: INSPECTED → PRE-SIGNED → SATURATED → RECORDED with zero coordination overhead.**
