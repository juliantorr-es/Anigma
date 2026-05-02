# Design: Unified Media Substrate (UMS)

## Overview
The Unified Media Substrate (UMS) is the next-generation media orchestration layer for Anigma, designed to move beyond the current "executor-per-contract" model toward a hardware-saturated, lane-based architecture.

## Design Goals
1.  **Hardware Saturation**: Enable concurrent, multi-lane saturation of CPU (Accelerate/DSP), GPU (Metal), and ANE (CoreML) for heavy media workloads.
2.  **Zero-Copy Pipelines**: Maintain GPU-resident memory surfaces from capture through transform to inference, eliminating CPU-RAM roundtrips.
3.  **Backpressure Management**: Graceful degradation under high load via unified request queuing and lane scheduling.
4.  **Tier 2 Orchestration**: Centralize media authority in a new `SaturationSubstrate` actor that acts as the data-plane counterpart to the current `MediaSubstrateOrchestrator` (control-plane).

## Core Concepts

### 1. Saturation Lanes
Defined as specialized processing pipelines with fixed hardware affinity:
- **`MediaCaptureLane`**: Camera/Microphone/Screen.
- **`MediaDecodeLane`**: Hardware-accelerated decoding (VideoToolbox).
- **`MediaTransformLane`**: GPU-accelerated scaling, color conversion, and shader-based effects (Metal).
- **`MediaInferenceLane`**: ANE/GPU-accelerated inference.

### 2. Unified Surface Protocol
Standardize how memory is passed between lanes.
- `MediaSurface`: Wrapper for `CVPixelBuffer` or `MTLTexture` with intrinsic zero-copy support.

### 3. Saturation Substrate Actor
A new `SaturationSubstrate` that manages the `laneRegistry`.
- Replaces individual `MediaBackendRegistry` lookups.
- Implements lane-aware load balancing.

## Architectural Changes
- **Deprecate**: Direct contract-to-executor dispatch.
- **Introduce**: Contract-to-lane routing, where lanes are composed of chaining `Saturable` executor nodes.
- **Interface**:
  ```swift
  public protocol Saturable: Sendable {
      var lane: MediaLane { get }
      func process(surface: MediaSurface, contract: any MediaContract) async throws -> MediaSurface
  }
  ```

## Next Steps
1.  Define `MediaLane` and `MediaSurface` primitive types.
2.  Implement `SaturationSubstrate` foundation in `MediaCore`.
3.  Migrate `MetalTransformExecutor` to implement the `Saturable` interface.
