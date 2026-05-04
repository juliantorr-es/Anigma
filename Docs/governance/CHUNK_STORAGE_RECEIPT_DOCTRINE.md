# Chunk Storage Receipt Doctrine

**Status**: Active  
**Applies to**: All Anigma runtime targets, executors, capability modules, and sidecars managing ECS-inspired chunk storage.

## 1. Core Principles
The `chunk-storage-receipt.schema.json` is the canonical schema for proving data layout, materialization events, and zero-copy/copy-minimized claims within Anigma's heterogeneous saturated architecture. It prevents "hand-waving" performance claims by requiring explicit evidence of data movement and layout before operations are allowed.

## 2. Zero-Copy Claims and Proofs
- **Zero-Copy Forbiddance**: You **MUST NOT** claim a data transfer or operation is "zero-copy" unless it produces a chunk storage receipt where `movement_classification` is `zero_copy_proven` or `no_copy_wrap`.
- **Proof Method Requirement**: A `movement_classification` of `zero_copy_proven` or `no_copy_wrap` **MUST** be backed by a specific `proof_method`, such as a `materialization_gate` trace, `allocator_receipt`, or `executor_receipt`.
- **Default Optimization Claim**: If zero-copy cannot be instrumentally proven, the design must default to claiming `copy_minimized`.

## 3. Portable Contracts
- **No Native Handles**: The receipt schema and the component definitions it tracks must not expose native hardware handles (e.g., Metal `MTLBuffer` pointers, CUDA memory addresses).
- **Domain Classification**: Use the `memory_domain` enum (`cpu`, `shared_cpu_gpu`, `gpu_private`, `mmap`, `sidecar`) to represent hardware-resident or shared states portably.
- **Layout Validation**: The receipt must track if data resides in a contiguous Structure of Arrays (`soa`), Array of Structures (`aos`), or `native_buffer`.

## 4. Fallbacks and Governance
- **Governed Fallbacks**: When a native accelerator or zero-copy path fails and falls back to a materialized copy or CPU execution, the receipt must populate the `fallback_reason` field and adjust the `movement_classification` to `materialized_copy`.
- **Sidecar Isolation**: Data moved to or from sidecar processes must emit a receipt with `movement_classification` as `sidecar_transfer` and the `memory_domain` as `sidecar`.