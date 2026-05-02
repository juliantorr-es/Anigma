# 14: Daemon/Sidecar IPC: Technical Detail

## Control Plane (AnyCodable)
- Used for configuration, registry, and audit signaling.
- Compliance: Must conform to `AnyCodable` for serialization.

## Data Plane (Zero-Copy)
- **CRITICAL**: Do NOT serialize heavy media/tensors via Codable.
- **Payload**: Must be an opaque `SurfaceToken` or `SHMBufferHandle`.
- **Enforcement**: Agents must prove zero-copy continuity via `ZeroCopyProof`. Serialization of frames in the hot path is a P0 architectural defect.
