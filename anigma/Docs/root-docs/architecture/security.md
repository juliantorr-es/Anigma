# Security Architecture: Governed Autonomy

## Status: 🔄 RENOVATION IN PROGRESS
Transitioning from **Real-time Actor Enforcement** to **Pre-Signed Saturated Missions**.

TD is the source of truth for live task status, blockers, dependency order, and review state. Privacy and regulated-decision constraints for this security model are canonicalized in `../../anigma/Docs/design/PRIVACY_COMPLIANCE_REGULATED_DECISIONING_SPINE.md`.

## Overview
Anigma’s security model is designed to provide high-assurance institutional AI without compromising hardware performance. To eliminate the **Governance Wall**, Anigma shifts from dynamic CPU-bound policy checks to a **Pre-Signed Mission** model, where the hardware executes within cryptographically signed boundaries.

---

## 1. Constitutional Governance (Tier 1)

Tier 1 remains the "Supreme Court" of Anigma, defining the pure logic for:
- **KillSwitch**: Emergency halt for all mutations and DSL dispatches.
- **WriteGate**: Structural validation of data modifications.
- **AccessController**: Role/Attribute-based permissions.

**The Saturated Pivot**: Tier 1 no longer just evaluates single actions. It now issues a **Signed Mission Descriptor**. This descriptor is a "Token of Authority" that allows a GPU/ANE mission to run autonomously for a specific duration or task.

---

## 2. Governed Enforcement (Tier 2)

The Tier 2 `PlatformRuntime` acts as the "Executive Branch," enforcing Tier 1 decisions.

### A. Pre-Signed Missions (Eliminating the Governance Wall)
Instead of the CPU checking "Is this token allowed?" 1,000 times per second:
1. **Request**: Tier 3 requests a DSL Mission (e.g., "Search 1M docs").
2. **Evaluation**: Tier 2 evaluates Tier 1 policies against the whole mission.
3. **Signing**: Tier 1 signs a **Mission Descriptor** (Hardware Lane, Atlas Memory Ranges, Time Budget).
4. **Autonomous Dispatch**: The mission is sent to the GPU. The GPU checks the descriptor internally (via Metal Shaders) and only returns to the CPU upon completion or violation.

### B. Governed Memory Map (GMM)
To eliminate the **Serialization Wall**, data flows via the `DSLMemoryBridge`.
- **Security Control**: Tier 2 uses `mmap` to map **Binary Atlases** into the GPU address space.
- **Enforcement**: Access to these maps is restricted to pre-signed missions. A "Search Mission" cannot read a "Secret Key Atlas."

### C. Hardware KillSwitch
The `KillSwitch` is now hardware-integrated.
- **The Kill Bit**: Tier 2 maintains a "Kill Bit" in a shared-memory buffer accessible to all active DSLs.
- **Saturated Response**: Metal kernels check this bit at the start of every "Layer Loop." If set, the mission terminates instantly at the hardware level, preventing "Compute Leaks."

### D. Privacy and Regulated Decision Admission
Mission signing must also evaluate privacy and regulated-decision metadata:
- sensitive missions require privacy class, allowed purpose, retention class, training/eval permission, and jurisdiction metadata
- external providers must be eligible for the data class and purpose
- missions that can substantially affect a person in regulated contexts require impact assessment, human oversight, explanation, and appeal metadata
- missing required privacy metadata is a signing failure, not a warning

---

## 3. High-Assurance Evidence (The Evidence Spine)

Security in Anigma is **Evidence-Based**. Every autonomous mission must generate non-repudiable proof of its behavior.

- **The Problem**: CPU-bound hashing (The Evidence Wall) kills performance.
- **The Solution**: **In-Kernel Evidence Generation**.
    - The DSL Megakernel computes its own rolling BLAKE3 hashes of input/output data.
    - These "Hardware Heartbeats" are written directly to a Tier 2-protected evidence buffer.
    - Result: High-assurance AI with zero coordination cost.
- **Privacy Constraint**: Heartbeats and receipts bind to descriptor hashes and redacted metadata. Raw sensitive payloads must remain in governed encrypted artifact stores and be referenced, not embedded, in immutable evidence.

---

## 4. Security Taxonomies
- **Mission Breach**: A hardware mission attempting to access memory outside its pre-signed atlas.
- **Thermal Jitter**: Saturated execution triggering thermal throttling (monitored by EnergyAuthority).
- **Spine Tampering**: Detection of gaps in the SIMD-Blake3 heartbeat chain.
