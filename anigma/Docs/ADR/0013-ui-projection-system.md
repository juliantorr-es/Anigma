# ADR-0013: UI Projection System

> **Status:** Proposed  
> **Date:** 2026-04-09  
> **Supersedes:** None  
> **Superseded by:** None

---

## Context

Anigma is built on a high-performance **Entity-Component-System (ECS)** core (`AnigmaCore`) using **Data-Oriented Design (DOD)** principles. This core prioritizes linear memory layout, CPU cache efficiency, and zero-copy Metal/ANE integration.

However, the macOS frontend is built with **SwiftUI**, which operates on an **Object-Oriented/Reactive** paradigm. SwiftUI relies on observation (`@Observable`, `@Published`) and a stable object graph to trigger view updates.

Directly binding SwiftUI to ECS components creates a fundamental **impedance mismatch**:
1. **Performance Friction:** Adding observation overhead to thousands of flat ECS components destroys the cache locality benefits of DOD.
2. **Threading Contention:** The ECS engine ticks at high frequencies (potentially 1000Hz+) on background threads, while SwiftUI must be updated on the Main Thread.
3. **Data Ownership:** ECS data is transient and "ticked," while SwiftUI expects durable objects with identity.

---

## Decision

We will implement a **Cross-Process UI Projection System**. Because the `anigmad` daemon now owns the ECS engine and all truth state, the UI can no longer read memory directly from the `World`. The `AnigmaApp` is strictly a thin-client **adapter**.

1. **Unidirectional Data Flow Across IPC:** Data flows from `anigmad ECS World` -> `JSON/XPC Payload` -> `AnigmaApp Projection Store` -> `SwiftUI View`.
2. **Selective Extraction:** The daemon queries the `World` for only the entities currently relevant to the user's view and serializes them as a "Projection".
3. **Main-Thread Synchronization:** At the end of an engine "tick", the daemon pushes the Projection payload over XPC/REST. The `AnigmaApp` receives this payload and deserializes it into an `@Observable` proxy on the Main Thread.
4. **Strict Isolation Seam:** The `AnigmaApp` module will have zero dependency on `AnigmaCore`, PostgreSQL, or CoreML. It only depends on the IPC projection contracts.

### Specialized Projection Tracks

While JSON/XPC is sufficient for lists and standard UI state, complex data visualizations (e.g., 3D node graphs, dense scatter plots, timelines) require specialized projection seams to prevent the thin client from becoming bloated.

1. **High-Density Pixel Projection (`IOSurface` Streaming):** For visuals exceeding JSON serialization budgets (e.g., 1,000,000-node graphs), `anigmad` renders the visualization directly into an `IOSurface` using Metal on the backend. The daemon passes the lightweight `IOSurfaceID` across the XPC boundary. The `AnigmaApp` binds this surface to a `MetalView` or `Layer`, displaying infinitely complex diagrams using ~0% CPU.
2. **Interactive Intent-Projection Loop:** For timelines or graphs requiring pan/zoom scrubbing, the UI **adapter** captures raw gestures (`DragGesture`, `MagnificationGesture`) and streams continuous intent payloads (`UserDidPan(x, y)`) to `anigmad`. The daemon calculates the new data bounds and streams back *only the clipped, visible slice* of the projection data. The UI never loads the full dataset into memory.

---

## Rationale

This pattern is standard in professional game engines (Unreal, Unity) where high-frequency simulation data must be rendered at a lower display frequency without blocking the math.

### Alternatives Considered

1. **Direct Observation**: Make `Component` classes conform to `Observable`.
    - *Cons*: Massive performance hit, breaks linear memory layout, high reference-counting overhead.
2. **Main-Thread Engine**: Run the ECS on the main thread.
    - *Cons*: Analysis of large document catalogs would freeze the UI ("beachballing").
3. **Manual Polling**: Have the UI timer poll the ECS state.
    - *Cons*: Race conditions, harder to manage state transitions.

---

## Consequences

### Positive

- **Extreme Performance:** The engine remains "linear" and SIMD-friendly.
- **Buttery Smooth UI:** The Main Thread is never blocked by heavy ingestion or analysis logic.
- **Headless Testing:** The core reasoning engine can be tested and verified without a UI.
- **Memory Efficiency:** We only pay the "observation tax" for data the user is actually looking at.

### Negative

- **Projection Boilerplate:** Requires writing "Extractors" that translate ECS components into UI models.
- **Latency Delay:** A sub-millisecond delay between engine state change and UI representation (acceptable for 60fps).

### Neutral

- Changes the developer workflow from "Bind data to View" to "Project state to Store."

---

## Migration

1. **Infrastructure:** Add `UIProjectionSystem` to `AnigmaCore`.
2. **Refactor Stores:** Update `AppStore` and `JobManager` to act as receivers for projections rather than owners of the raw state.
3. **DTO Extraction:** Move current OOP models in `SpineObjects.swift` to serve as the "Projection Targets" for the ECS data.

---

## References

- Related ADRs: [ADR-0001: Single ECS in AnigmaCore](./0001-single-ecs-in-anigmacore.md)
- Related code: `anigma/Packages/AnigmaCore/Sources/AnigmaCore/ECS/World.swift`
