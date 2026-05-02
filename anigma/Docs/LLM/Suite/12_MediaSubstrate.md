# 12: Media Substrate (UMS): Implementation Deep-Dive

## Data Plane Orchestration
- **MediaLane**: A `String`-backed `Sendable` enum identifying hardware affinity.
- **Saturable Interface**: Nodes conform to `process(surface: MediaSurface, contract: any MediaContract) async throws -> MediaSurface`.
- **Zero-Copy Contract**: 
    - `MediaSurface` uses `CVPixelBuffer` or `MTLTexture`.
    - No implicit buffer copying allowed; the substrate tracks `ZeroCopyProof` via `FrameReference` handle exchange.

## SaturationSubstrate Mechanics
- **Orchestration**: `SaturationSubstrate` actor maintains a registry of `lanes` (e.g., `.transform`, `.inference`).
- **Fallback Policy**: If an executor for a lane is unavailable, the actor logs a `MaterializationEvent` to the governance ring and throws `MediaError.laneUnavailable`.
