# Anigma Saturated Architecture: Alignment Assessment Matrix

This matrix identifies the alignment gaps between the legacy "Coordination-Bound" documentation and the new "Saturated Autonomous" architectural baseline.

## 1. Core Alignment Matrix

| Document / Area | Status | Alignment Gap | Research Needed? | Action |
| :--- | :--- | :--- | :--- | :--- |
| **Anigma Constitution** (`AnigmaConstitution.md`) | **Drifted** | Mentions "Job/Workflow" as the primary model. Needs to pivot to "Saturated Mission" and "Hardware Autonomy". | No | Renovate (Immediate) |
| **ADR Index** (`Docs/ADR/`) | **Drifted** | ADR-0002 (Job Model) and ADR-0010 (Execution) are now technically superseded by Saturated Missions. | No | Flag as Legacy |
| **Module Docs** (`Docs/architecture/modules/`) | **Drifted** | Most modules (e.g., `harmoniamodule.md`, `diaplasionmodule.md`) still describe "Actor-bound systems". | **Yes** (Saturated mapping for each domain) | Renovate (Batch) |
| **Governance & Identity** (`Docs/governance/`) | **Drifted** | Focuses on real-time Swift checks. Needs to define "Pre-Signed Mission" handshakes and "Token of Authority". | **Yes** (Mission signing schema) | Renovate (Strategic) |
| **Research Base** (`Docs/research/`) | **Legacy** | 50+ files of deep "Coordination" research. Useful for historical context but obsolete for hot-path design. | No | Mark as Historical |
| **ML-Worker / Inference** (`guides/ml-worker/`) | **Drifted** | Assumes modular MLX calls. Needs to pivot to "Inference Megakernel" and "KV-Cache Saturation". | **Yes** (Metal-MLX Fusion) | Renovate |
| **Evidence / Cathedral** (`guides/cathedral/`) | **Drifted** | Describes CPU-bound receipt generation. Needs "In-Kernel Heartbeat" pivot. | No | Renovate |
| **Troubleshooting** (`troubleshooting/`) | **Stub** | Lacks diagnostics for "Saturation Gaps", "Thermal Jitter", or "Atlas Alignment Errors". | **Yes** (Saturated Debugging) | Expand |
| **Agent Contracts** (`LLM/AGENT-CONTRACT.md`) | **Drifted** | Contracts focus on output quality, not "Saturation Impact" or "DSL-Safe Code". | **Yes** (DSL-Safe Handshakes) | Renovate |

---

## 2. Research Requirements for High-Quality Alignment

The following topics require "Research Turns" before the documentation can reach the new "Saturated" quality standard:

### A. Mission Descriptor Schema (Governance Research)
- **Goal**: Define the exact binary format of a signed "Mission Descriptor."
- **Scope**: Must include Time Budget, Memory Atlas Ranges, Capability Bits, and Principal Signatures.
- **Impact**: Unblocks the renovation of `security.md` and `AnigmaConstitution.md`.

### B. In-Kernel Heartbeat Protocol (Observability Research)
- **Goal**: Define the SIMD-Blake3 heartbeat ring structure.
- **Scope**: How the GPU writes heartbeats to unified memory without blocking the compute pipeline.
- **Impact**: Unblocks the renovation of `logging.md` and `cathedralmodule.md`.

### C. Binary Atlas Linking (Storage Research)
- **Goal**: Establish the "Pointer-to-Atlas" standard for SQL-to-Binary linkage.
- **Scope**: How `atlas_id` and `atlas_offset` are managed during compaction and re-indexing.
- **Impact**: Unblocks the renovation of `database-architecture.md` and `schema.md`.

### D. Nexus Multi-Instance Handshake (Networking Research)
- **Goal**: Define the "Mission Treaty" handshake between two sovereign instances.
- **Scope**: Zero-knowledge proof exchange for hardware heartbeats.
- **Impact**: Unblocks `networking.md` and `sovereign-multi-tenancy.md`.

---

## 3. Immediate Action Plan

1. **Renovate Constitution**: Rewrite `AnigmaConstitution.md` to canonize Saturated Autonomy as the primary model.
2. **Tag Legacy ADRs**: Add "Superseded by Saturated Architecture" headers to legacy design records.
3. **Execute Research Turns**: Initiate the 4 research tracks above to prepare the next wave of high-quality renovation.
4. **Batch Module Update**: Use the "Saturated Mapping" pattern to renovate the 40+ module files.
