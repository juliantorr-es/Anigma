# Saturated Testing & Verification

## Status: 🔄 RENOVATION IN PROGRESS
Transitioning from **Functional Unit Tests** to **Saturated Evidence Verification**.

## Overview
Anigma’s testing strategy is built on **Radical Verification**. We don't just test if a function "returns the right value"; we verify that the **Hardware Mission** behaved autonomously and generated a valid **Evidence Spine**.

---

## 1. Testing the Mission Autonomy

Every hardware mission (e.g., `SearchMegakernel`) must be tested for **Saturation Gating**.

### A. The Coordination Test
**Objective**: Ensure the mission runs to completion without CPU round-trips.
- **Verification**: Use the Metal Debugger to confirm a single, continuous compute dispatch with no "Bubbles."
- **Failure**: If the CPU `waits` for the GPU in the middle of a reasoning loop, the test fails.

### B. The Governance Test
**Objective**: Ensure the mission respects the **Pre-Signed Mission Descriptor**.
- **Verification**: Pass a "Tampered" descriptor to the kernel.
- **Success**: The kernel must terminate via the **Hardware KillSwitch** or return an "Authorization Breach" receipt.

---

## 2. Evidence Verification (SIMD-Blake3)

We test the integrity of the **Saturated Spine** by comparing hardware heartbeats with CPU-calculated Merkle roots.

1. **Mission Execution**: The GPU runs the mission and writes heartbeats to the **Saturated Logging Ring**.
2. **Spine Ingestion**: Tier 2 (`EvidenceAuthority`) consumes the ring.
3. **Audit Verification**: The test suite runs a **Forensics DSL** scan over the Evidence Atlas to verify the cryptographic chain is unbroken.

---

## 3. Regression Guardrail Suite

Run the automated saturation gates before every commit:
```bash
# Verify no coordination or serialization regressions
Scripts/harmonia.sh saturation-check

# Verify all missions generate valid heartbeats
Scripts/harmonia.sh evidence-check
```

---

## 4. Performance Benchmarking (Saturated Baseline)

We measure **Intelligence-per-Watt (Ops/J)** and **Tokens/Second** as primary test metrics.
- **Pass Criteria**: Performance must be within 15% of the **Saturated Peak Baseline** for the current device (e.g., 45 tok/s on M2 Max).

---

## 5. Multi-Instance Testing (Nexus DSL)

Testing the **Nexus DSL** involves verifying the **Multi-Instance Treaty**.
1. **Scenario**: Join a "Shadow Organization" (Mock Institutional Anchor).
2. **Handshake**: Verify the **Shared Mission Descriptor** is correctly signed by both Tier 1 authorities.
3. **Sovereignty Check**: Confirm that the local **Personal Atlas** is never mapped into the Org's remote address space.

---

**In Anigma, "Tested" means "Hardware-Verified."**
